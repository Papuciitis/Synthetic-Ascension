extends Node2D
class_name GroundSplatRenderer

## The world ground as one shader instead of stacked translucent rectangles
## (2026-09-27 world look pass).
##
## Floors used to be one region-repeated Sprite2D per chunk plus one per floor
## stamp, alpha-composited: every road, sidewalk and plaza read as a see-through
## rectangle, and every material boundary was a hard 64 px staircase. The same
## data - a base material per chunk, then the recorded stamps in z order - is
## now painted into small wrapped splat maps, one texel per cell, and
## ground_splat.gdshader draws organic edges from them: boundaries wander,
## corners round off, grass creeps over the paving with a lip shadow. Gameplay
## (walkability, keepout, walls) stays on the grid.
##
## Stamps at alpha >= 0.5 own their cells; lighter ones (the 0.12 mud chips)
## are stains blended over whatever is underneath. Every paint is a native
## Image.fill_rect on three 256 x 256 maps, so painting a chunk costs well under
## a millisecond.

const _WORLD_ART = preload("res://core/systems/world/WorldArt.gd")
const SHADER := preload("res://core/systems/world/ground/ground_splat.gdshader")
const _CITY_GROUND_CARE := preload("res://core/systems/world/ground/CityGroundCare.gd")
const _POLICY := preload("res://core/systems/world/ground/DistrictGroundPolicy.gd")

## Cells, wrapped. 256 cells = 8 chunks at 32 cells/chunk = 16384 px: larger than any streamed
## window, and the whole of Segment 1 fits without wrapping onto itself.
const MAP_SIZE := 256
const SLOTS := 8
const NOISE_PX := 128
## Stamps under this alpha are stains, not floors.
const STAIN_ALPHA := 0.5
## light_map R stores brightness / 2 so authored stamps may run above 1.
const BRIGHTNESS_SCALE := 0.5
## Ground occlusion (light_map A): blocker weights accumulated over a radius of
## two cells; this much accumulated weight reads as fully occluded.
const OCCLUSION_FULL := 2.4
const OCCLUSION_RADIUS := 2

var cell_px := 64
var cells_per_chunk := 32

## One-hot material coverage: slots 0-3 in _cover_a, 4-7 in _cover_b.
var _cover_a: Image
var _cover_b: Image
## R = brightness / 2, G = stain amount, B = local household care,
## A = ground openness (1 open sky; walls and props nearby lower it).
var _light: Image
var _cover_a_texture: ImageTexture
var _cover_b_texture: ImageTexture
var _light_texture: ImageTexture
## Authored worlds (Segment 1) stamp once, before the streamed chunks that
## carry the base ground exist; those stamps are kept here and laid back over
## each base as it arrives.
var _authored: Array[Image] = []
var _authored_mask: Image = null

var _slot_material := PackedInt32Array()
## Materials that found every slot taken and had to borrow one (tests).
var _slot_borrows := 0
## The district presentation (DistrictGroundPolicy.resolve); empty = legacy.
var _policy: Dictionary = {}
var _policy_family: StringName = &"__unset__"
var _material: ShaderMaterial
var _quad_texture: ImageTexture
var _quads: Dictionary = {}
var _dirty := false

static var _noise_texture: ImageTexture = null


func _init() -> void:
	name = "GroundSplat"
	z_index = -100
	_cover_a = _blank_map()
	_cover_b = _blank_map()
	_light = _blank_map()
	# Coverage carries a mip chain: the policy reads paved-to-paved edges from
	# a smoothed level (crisp kerbs that follow the street, not the cell steps).
	_cover_a_texture = ImageTexture.create_from_image(_mipmapped(_cover_a))
	_cover_b_texture = ImageTexture.create_from_image(_mipmapped(_cover_b))
	_light_texture = ImageTexture.create_from_image(_light)
	_slot_material.resize(SLOTS)
	_slot_material.fill(-1)
	var white := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	_quad_texture = ImageTexture.create_from_image(white)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("cover_a", _cover_a_texture)
	_material.set_shader_parameter("cover_b", _cover_b_texture)
	_material.set_shader_parameter("light_map", _light_texture)
	_material.set_shader_parameter("noise_tex", noise_texture())
	_material.set_shader_parameter("map_size", float(MAP_SIZE))
	if OS.is_debug_build() and OS.has_environment("SA_GROUND_DEBUG_VIEW"):
		_material.set_shader_parameter("debug_view", int(OS.get_environment("SA_GROUND_DEBUG_VIEW")))
	_push_role_uniforms()
	_push_slot_uniforms()


func configure(p_cell_px: int, p_cells_per_chunk: int) -> void:
	cell_px = maxi(1, p_cell_px)
	cells_per_chunk = maxi(1, p_cells_per_chunk)
	_material.set_shader_parameter("cell_px", float(cell_px))
	_material.set_shader_parameter("cared_lawn_layer",float(_WORLD_ART.GROUND_CARED_LAWN_INDEX))
	_material.set_shader_parameter("cared_lawn_repeat_px",float(_WORLD_ART.ground_repeat_world_px(_WORLD_ART.GROUND_CARED_LAWN_INDEX)))
	var materials := _WORLD_ART.ground_material_array()
	if materials != null:
		_material.set_shader_parameter("materials", materials)


## Per-material colour correction toward the reference look (warm grey-brown
## flagstones, mean ~(108, 99, 80)); the source civic brick is a pale beige.
static func material_tint(index: int) -> Color:
	match index:
		2:
			# Sidewalk bands: the road's own flagstones, a shade greyer.
			return Color(1.25, 1.16, 1.05)
		3:
			return Color(1.4, 1.3, 1.18)
		7:
			return Color(0.92, 0.85, 0.82)
		8:
			return Color(0.95, 0.88, 0.84)
		9:
			return Color(0.95, 0.9, 0.86)
	return Color.WHITE


## The texture layer a material draws with. Two source textures read badly as
## large areas and are drawn with a sibling instead (the generator's material
## ids, keepout and tests are unchanged): the round cobble sidewalk bands
## traced every road like a grey river, so they use the grey grade of the
## road's own flagstone pattern (ground_dirt_path_01 is the same pattern as
## civic brick); the flat grey stone tiles read as a blank slab, so plazas and
## interiors use the dark regular brick.
static func material_layer(index: int) -> int:
	match index:
		2:
			return 4
		3:
			return 6
	return index


func set_world_tint(tint: Color) -> void:
	_material.set_shader_parameter("world_tint", tint)


## Present the ground as `family`'s district (DistrictGroundPolicy). Cheap
## when unchanged, so callers may repeat it on every paint.
func set_ground_family(family: StringName) -> void:
	if family == _policy_family:
		return
	set_ground_policy(_POLICY.resolve(family))
	_policy_family = family


## Presentation only: material ownership, slots, organic soil edges and the
## stamped indoor/plaza/road hierarchy never change with the policy.
func set_ground_policy(policy: Dictionary) -> void:
	_policy = policy.duplicate(true)
	_policy_family = StringName(_policy.get("family", &"__unset__"))
	var enabled := bool(_policy.get("enabled", false))
	_material.set_shader_parameter("policy_enabled", enabled)
	_material.set_shader_parameter("seam_shadow", float(_policy.get("seam_shadow", 0.0)) if enabled else 0.12)
	_material.set_shader_parameter("lip_shadow", float(_policy.get("lip_shadow", 0.22)) if enabled else 0.36)
	if enabled and _material.get_shader_parameter("city_setts") == null:
		var kit := preload("res://scenes/world/buildings/CityBlockKit.gd")
		_material.set_shader_parameter("city_setts", kit._texture("worn_setts.png"))
		_material.set_shader_parameter("city_limestone", kit._texture("paving.png"))
	_push_role_uniforms()
	_push_slot_uniforms()


func ground_policy() -> Dictionary:
	return _policy.duplicate(true)


func ground_policy_enabled() -> bool:
	return bool(_policy.get("enabled", false))


func get_shader_material() -> ShaderMaterial:
	return _material


## Lay a chunk's base ground over its whole block, which also forgets any
## stamps a chunk MAP_SIZE / cells_per_chunk chunks away left in the wrapped map. Generated chunks
## paint their stamps after this; authored stamps are laid back on top here.
func set_chunk_base(coord: Vector2i, ground_index: int, brightness: float = 1.0) -> void:
	var block := Rect2i(coord * cells_per_chunk, Vector2i(cells_per_chunk, cells_per_chunk))
	_fill(block, ground_index, brightness, false)
	if _authored_mask != null:
		_for_wrapped_spans(block, func(span: Rect2i) -> void:
			_cover_a.blit_rect_mask(_authored[0], _authored_mask, span, span.position)
			_cover_b.blit_rect_mask(_authored[1], _authored_mask, span, span.position)
			_light.blit_rect_mask(_authored[2], _authored_mask, span, span.position)
		)
	_ensure_quad(coord)


## Paint one stamp, in global cells. Later paints replace earlier ones, so
## callers paint in z order. `authored` stamps survive the chunk bases that
## stream in after them.
func paint_rect(rect: Rect2i, ground_index: int, alpha: float, brightness: float = 1.0, authored: bool = false) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0 or ground_index < 0:
		return
	if authored and _authored_mask == null:
		_authored = [_blank_map(), _blank_map(), _blank_map()]
		_authored_mask = _blank_map()
	if alpha < STAIN_ALPHA:
		_stain(rect, ground_index, alpha, authored)
	else:
		_fill(rect, ground_index, brightness, authored)
	var first := Vector2i(floori(float(rect.position.x) / cells_per_chunk), floori(float(rect.position.y) / cells_per_chunk))
	var last := Vector2i(floori(float(rect.end.x - 1) / cells_per_chunk), floori(float(rect.end.y - 1) / cells_per_chunk))
	for cy in range(first.y, last.y + 1):
		for cx in range(first.x, last.x + 1):
			_ensure_quad(Vector2i(cx, cy))


## Every recorded floor stamp of a chunk, in z order (ties keep record order).
func paint_chunk_stamps(data: ChunkBuildData) -> void:
	var count := data.floor_stamp_count()
	if count <= 0:
		return
	var order: Array[int] = []
	for index in count:
		order.append(index)
	var packed := data.floor_rect_and_style
	order.sort_custom(func(a: int, b: int) -> bool:
		var za := packed[a * 6 + 5]
		var zb := packed[b * 6 + 5]
		return za < zb if za != zb else a < b
	)
	var origin := data.coord * cells_per_chunk
	for index in order:
		var offset := index * 6
		var rect := Rect2i(
			origin + Vector2i(packed[offset], packed[offset + 1]),
			Vector2i(packed[offset + 2], packed[offset + 3])
		)
		paint_rect(rect, packed[offset + 4], data.floor_alpha[index])


## Ground a household may tend: vegetation, bare earth and the built
## district's open hard surface. Roads, lanes, aprons, footways and floors
## never become lawn.
static func care_eligible_index(index: int) -> bool:
	return _WORLD_ART.is_overgrowth_ground(index) or index == 1 or index == 5 or index == _POLICY.DISTRICT_GROUND_INDEX


## One byte per chunk cell: 1 where care may draw (see care_eligible_index).
## Reads the chunk's coverage block once instead of probing every cell. On the
## district's hard surface a garden keeps a paved margin from the carriageway,
## lanes and door aprons (a cell touching one in its 8-neighbourhood is not
## tended), so lawns never run up to a kerb or a threshold; they may still
## touch a house floor or a footway. `region` (chunk-local cells) limits the
## work to where gardens can reach; cells outside it read as not eligible.
func care_eligibility(coord: Vector2i, region: Rect2i = Rect2i(0,0,1 << 20,1 << 20)) -> PackedByteArray:
	var n := cells_per_chunk
	var eligible := PackedByteArray()
	eligible.resize(n*n)
	region = region.intersection(Rect2i(0,0,n,n))
	if not region.has_area():
		return eligible
	var slot_kind := PackedByteArray()
	slot_kind.resize(SLOTS)
	for slot in SLOTS:
		var index := _slot_material[slot]
		if index < 0:
			continue
		if index == _POLICY.DISTRICT_GROUND_INDEX:
			slot_kind[slot] = 2
		elif care_eligible_index(index):
			slot_kind[slot] = 1
		elif _POLICY.role_for_index(index) in [_POLICY.ROLE_ROAD, _POLICY.ROLE_LANE]:
			slot_kind[slot] = 3
	var origin := Vector2i(posmod(coord.x*n,MAP_SIZE),posmod(coord.y*n,MAP_SIZE))
	if origin.x+n > MAP_SIZE or origin.y+n > MAP_SIZE:
		for y in range(region.position.y,region.end.y):
			for x in range(region.position.x,region.end.x):
				if care_eligible_index(material_at(coord*n+Vector2i(x,y))): eligible[y*n+x] = 1
		return eligible
	var block := Rect2i(origin,Vector2i(n,n))
	# Coverage is one-hot: each cell's RGBA word is 0 or exactly one channel at
	# 255, so comparing whole words replaces the per-channel scan.
	var a := _cover_a.get_region(block).get_data().to_int32_array()
	var b := _cover_b.get_region(block).get_data().to_int32_array()
	var words := PackedInt32Array()
	for channel in 4:
		var bytes := PackedByteArray([0,0,0,0])
		bytes[channel] = 255
		words.append(bytes.to_int32_array()[0])
	var w0 := words[0]
	var w1 := words[1]
	var w2 := words[2]
	var ka := [int(slot_kind[0]),int(slot_kind[1]),int(slot_kind[2]),int(slot_kind[3])]
	var kb := [int(slot_kind[4]),int(slot_kind[5]),int(slot_kind[6]),int(slot_kind[7])]
	# Street cells as an LA8 mask (the region plus a one-cell rim, so the
	# margin sees streets just outside it); its dilation is eight native blends.
	var street := PackedByteArray()
	street.resize(n*n*2)
	var has_street := false
	var district := PackedInt32Array()
	var scan := region.grow(1).intersection(Rect2i(0,0,n,n))
	for y in range(scan.position.y,scan.end.y):
		var inside_y := y >= region.position.y and y < region.end.y
		for x in range(scan.position.x,scan.end.x):
			var index := y*n+x
			var word := a[index]
			var kind := 0
			if word != 0:
				kind = ka[0] if word == w0 else (ka[1] if word == w1 else (ka[2] if word == w2 else ka[3]))
			else:
				word = b[index]
				if word != 0:
					kind = kb[0] if word == w0 else (kb[1] if word == w1 else (kb[2] if word == w2 else kb[3]))
			if kind == 3:
				street[index*2] = 255
				street[index*2+1] = 255
				has_street = true
			elif inside_y and x >= region.position.x and x < region.end.x:
				if kind == 1:
					eligible[index] = 1
				elif kind == 2:
					eligible[index] = 1
					district.append(index)
	if has_street and not district.is_empty():
		var mask := Image.create_from_data(n,n,false,Image.FORMAT_LA8,street)
		var near := mask.duplicate() as Image
		var whole := Rect2i(Vector2i.ZERO,Vector2i(n,n))
		for offset: Vector2i in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)]:
			near.blend_rect(mask,whole,offset)
		var near_bytes := near.get_data()
		for cell in district:
			if near_bytes[cell*2+1] > 127:
				eligible[cell] = 0
	return eligible


## Called after the chunk's floors. This changes only presentation (light-map
## blue) on cells a household may tend; lawn never requests a semantic
## material/coverage slot. `eligible` may be shared by every home of a chunk.
func paint_domestic_care(coord: Vector2i, spec: Dictionary, eligible: PackedByteArray = PackedByteArray()) -> void:
	var n := cells_per_chunk
	if eligible.size() != n*n:
		eligible = care_eligibility(coord)
	var origin := coord*n
	var weights := _CITY_GROUND_CARE.plan(coord,spec,cell_px,n,eligible)
	var window := _CITY_GROUND_CARE.window_of(spec,cell_px,n)
	for y in range(window.position.y,window.end.y):
		for x in range(window.position.x,window.end.x):
			var index := y*n+x
			if weights[index] == 0 or eligible[index] == 0:
				continue
			var amount := float(weights[index])/255.0
			var cell := origin+Vector2i(x,y)
			var at := Vector2i(posmod(cell.x,MAP_SIZE),posmod(cell.y,MAP_SIZE))
			var current := _light.get_pixelv(at)
			if amount <= current.b:
				continue
			current.b = amount
			_light.set_pixelv(at,current)
			_dirty = true


## A planted bed laid by the district itself (a plaza island): full care over
## the given chunk-local cells where the ground may be tended. Presentation
## only, idempotent (max-composite), cleared with the chunk base.
func paint_planting(coord: Vector2i, rect: Rect2i) -> void:
	var n := cells_per_chunk
	var local := rect.intersection(Rect2i(Vector2i.ZERO, Vector2i(n, n)))
	for y in range(local.position.y, local.end.y):
		for x in range(local.position.x, local.end.x):
			var cell := coord*n+Vector2i(x,y)
			if not care_eligible_index(material_at(cell)):
				continue
			var at := Vector2i(posmod(cell.x,MAP_SIZE),posmod(cell.y,MAP_SIZE))
			var current := _light.get_pixelv(at)
			if current.b >= 1.0:
				continue
			current.b = 1.0
			_light.set_pixelv(at,current)
			_dirty = true


## Loaded neighbours for the occlusion pass: a Callable(coord) returning
## {Vector2i offset (-1..1, -1..1): ChunkBuildData} for the streamed chunks
## around `coord` (ChunkManager sets it). Without it occlusion stays
## chunk-local, as bare renderers in tests expect.
var occlusion_neighbours: Callable = Callable()


## Broad ground occlusion in light-map alpha: every wall, window, solid and
## half-cover cell shades the open ground within two cells, so alleys, yards
## and wall feet darken while plazas stay open. Deterministic and presentation
## only. Seam-continuous: a chunk's pass gathers the blockers of its loaded
## neighbours within reach and rewrites its own cells plus a two-cell ring of
## each loaded neighbour, so a ramp runs across the chunk line instead of
## stopping at it. Every cell's final value is the exact sum over the loaded
## blockers within reach whatever order the chunks stream in (the last chunk
## to paint near a cell sees all the others), and a reload repaints the same
## bytes.
func paint_occlusion(coord: Vector2i, data: ChunkBuildData) -> void:
	var n := cells_per_chunk
	if data == null or data.cells_per_side != n:
		return
	if not _block_in_map(coord):
		return
	var neighbours: Dictionary = {}
	if occlusion_neighbours.is_valid():
		neighbours = occlusion_neighbours.call(coord)
	var pad := OCCLUSION_RADIUS
	# Cells rewritten: the chunk, plus the ring of each loaded neighbour. Their
	# blockers can lie one more radius out, and a blocker scatters one more
	# radius again, so the scratch grid spans the block grown by three radii
	# and the hot loop needs no bounds checks.
	var reach := pad if not neighbours.is_empty() else 0
	var margin := pad*3 if not neighbours.is_empty() else pad
	var stride := n+margin*2
	var shade := PackedFloat32Array()
	shade.resize(stride*stride)
	_ensure_occlusion_kernel(stride)
	# Sources in one fixed order of world position (row by row), so every cell
	# sums the same contributions in the same float order whichever chunk
	# paints it: the bytes are identical for any streaming order.
	for oy in range(-1,2):
		for ox in range(-1,2):
			var offset := Vector2i(ox,oy)
			var source: ChunkBuildData = data if offset == Vector2i.ZERO else neighbours.get(offset) as ChunkBuildData
			if source == null or source.cells_per_side != n:
				continue
			_scatter_occlusion(shade,stride,margin,offset*n,source,-pad*2,n+pad*2)
	var changed := false
	for oy in range(-1,2):
		for ox in range(-1,2):
			var offset := Vector2i(ox,oy)
			if offset != Vector2i.ZERO and not neighbours.has(offset):
				continue
			if offset != Vector2i.ZERO and not _block_in_map(coord+offset):
				continue
			# This chunk's part of the rewritten region, in its own cells.
			var part := Rect2i(Vector2i(-reach,-reach),Vector2i(n+reach*2,n+reach*2)).intersection(Rect2i(offset*n,Vector2i(n,n)))
			if not part.has_area():
				continue
			if _write_occlusion(coord,part,shade,stride,margin):
				changed = true
	if changed:
		_dirty = true


## Whether a chunk's block lies whole inside the wrapped maps (always, when
## cells_per_chunk divides MAP_SIZE).
func _block_in_map(coord: Vector2i) -> bool:
	var n := cells_per_chunk
	var origin := Vector2i(posmod(coord.x*n,MAP_SIZE),posmod(coord.y*n,MAP_SIZE))
	return origin.x+n <= MAP_SIZE and origin.y+n <= MAP_SIZE


## Add the blockers of `data` (a chunk whose cells start at `origin`, in the
## painting chunk's local cells) that lie in [lo, hi) of those local cells to
## the scratch grid.
func _scatter_occlusion(shade: PackedFloat32Array, stride: int, margin: int, origin: Vector2i, data: ChunkBuildData, lo: int, hi: int) -> void:
	var n := cells_per_chunk
	var offsets := _occlusion_offsets
	var weights := _occlusion_weights
	var taps := offsets.size()
	var kinds := data.blocker_kind_code
	var whole := origin == Vector2i.ZERO
	for index in data.occupied_indices():
		var code := int(kinds[index])
		if code == 0:
			continue
		var x := origin.x+(index % n)
		var y := origin.y+floori(float(index)/float(n))
		if not whole and (x < lo or y < lo or x >= hi or y >= hi):
			continue
		# Kinds + 1: SOLID_CELL, WALL, WINDOW carry full weight; fences and
		# half cover (crates, planters) cast a lighter contact shade.
		var weight := 1.0 if code <= 3 else 0.4
		var base := (y+margin)*stride+x+margin
		for k in taps:
			shade[base+offsets[k]] += weight*weights[k]


## Write the accumulated occlusion of `part` (painting-chunk local cells, all
## inside one chunk's block) into the light map's alpha. True if any changed.
func _write_occlusion(coord: Vector2i, part: Rect2i, shade: PackedFloat32Array, stride: int, margin: int) -> bool:
	var n := cells_per_chunk
	var at_chunk := Vector2i(floori(float(part.position.x)/float(n)),floori(float(part.position.y)/float(n)))
	var target := coord+at_chunk
	var origin := Vector2i(posmod(target.x*n,MAP_SIZE),posmod(target.y*n,MAP_SIZE))
	var local := part.position-at_chunk*n
	var map_rect := Rect2i(origin+local,part.size)
	var region := _light.get_region(map_rect)
	var bytes := region.get_data()
	var scale := 255.0/OCCLUSION_FULL
	var changed := false
	var index := 0
	for y in part.size.y:
		var padded := (part.position.y+y+margin)*stride+part.position.x+margin
		for x in part.size.x:
			var value := 255-mini(255,roundi(shade[padded+x]*scale))
			var at := index*4+3
			if bytes[at] != value:
				bytes[at] = value
				changed = true
			index += 1
	if changed:
		region.set_data(part.size.x,part.size.y,false,Image.FORMAT_RGBA8,bytes)
		_light.blit_rect(region,Rect2i(Vector2i.ZERO,part.size),map_rect.position)
	return changed


## Exact cell probe of the occlusion term (1 = open), for tests and evidence.
func openness_at(cell: Vector2i) -> float:
	return _light.get_pixel(posmod(cell.x,MAP_SIZE),posmod(cell.y,MAP_SIZE)).a


static var _occlusion_stride := -1
static var _occlusion_offsets := PackedInt32Array()
static var _occlusion_weights := PackedFloat32Array()


## The occlusion kernel as flat offsets into a padded grid of `stride` and
## their weights (built once per stride).
static func _ensure_occlusion_kernel(stride: int) -> void:
	if stride == _occlusion_stride:
		return
	_occlusion_stride = stride
	_occlusion_offsets = PackedInt32Array()
	_occlusion_weights = PackedFloat32Array()
	for dy in range(-OCCLUSION_RADIUS,OCCLUSION_RADIUS+1):
		for dx in range(-OCCLUSION_RADIUS,OCCLUSION_RADIUS+1):
			if dx == 0 and dy == 0:
				continue
			var offset := Vector2(dx,dy)
			var distance := offset.length()
			if distance > float(OCCLUSION_RADIUS)+0.5:
				continue
			# Ground on a blocker's shadow side (south-west, the projected sun
			# direction) is shaded more than ground on its lit side.
			var shadow_side := maxf(0.0, offset.normalized().dot(Vector2(-0.8214,0.5704)))
			_occlusion_offsets.append(dy*stride+dx)
			_occlusion_weights.append(clampf(1.0-(distance-0.6)/2.4,0.0,1.0)*(0.55+0.45*shadow_side))


## Paint a set of cell rects (global cells) with one base material, as part
## of a chunk's base (before its stamps). Used for the ragged margin where a
## built district gives way to wild ground.
func paint_base_rects(rects: Array[Rect2i], ground_index: int, brightness: float = 1.0) -> void:
	if ground_index < 0:
		return
	for rect in rects:
		if rect.size.x > 0 and rect.size.y > 0:
			_fill(rect, ground_index, brightness, false)


## Exact cell probes for native evidence and deterministic stream checks.
func care_at(cell: Vector2i) -> float:
	return _light.get_pixel(posmod(cell.x,MAP_SIZE),posmod(cell.y,MAP_SIZE)).b


func care_signature(coord: Vector2i) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(cells_per_chunk*cells_per_chunk)
	var origin := coord*cells_per_chunk
	for y in cells_per_chunk:
		for x in cells_per_chunk:
			var cell := origin+Vector2i(x,y)
			bytes[y*cells_per_chunk+x] = _light.get_pixel(posmod(cell.x,MAP_SIZE),posmod(cell.y,MAP_SIZE)).b8
	return bytes


func clear() -> void:
	for image in [_cover_a, _cover_b, _light]:
		(image as Image).fill(Color(0, 0, 0, 0))
	_authored.clear()
	_authored_mask = null
	_slot_material.fill(-1)
	_slot_borrows = 0
	_push_slot_uniforms()
	_dirty = true
	for quad in _quads.values():
		if is_instance_valid(quad):
			(quad as Node).queue_free()
	_quads.clear()


func quad_count() -> int:
	return _quads.size()


## Distinct semantic materials holding a slot, and how many paints had to
## borrow a slot because all eight were taken (tests: a district must fit).
func active_slot_materials() -> PackedInt32Array:
	var active := PackedInt32Array()
	for slot in SLOTS:
		if _slot_material[slot] >= 0:
			active.append(_slot_material[slot])
	return active


func slot_borrow_count() -> int:
	return _slot_borrows


## Ground material at a global cell (base or stamp), -1 where nothing is
## painted. For tests and probes.
func material_at(cell: Vector2i) -> int:
	var at := Vector2i(posmod(cell.x, MAP_SIZE), posmod(cell.y, MAP_SIZE))
	var a := _cover_a.get_pixelv(at)
	var b := _cover_b.get_pixelv(at)
	var values := [a.r, a.g, a.b, a.a, b.r, b.g, b.b, b.a]
	for slot in SLOTS:
		if float(values[slot]) > 0.5:
			return _slot_material[slot]
	return -1


func _process(_delta: float) -> void:
	flush()


## Upload changed maps (once per frame at most; also called by tests).
func flush() -> void:
	if not _dirty:
		return
	_dirty = false
	_cover_a_texture.update(_mipmapped(_cover_a))
	_cover_b_texture.update(_mipmapped(_cover_b))
	_light_texture.update(_light)


func _fill(rect: Rect2i, ground_index: int, brightness: float, authored: bool) -> void:
	var slot := _slot_for(ground_index)
	var a := Color(0, 0, 0, 0)
	var b := Color(0, 0, 0, 0)
	if slot < 4:
		a[slot] = 1.0
	else:
		b[slot - 4] = 1.0
	var light := Color(clampf(brightness * BRIGHTNESS_SCALE, 0.0, 1.0), 0.0, 0.0, 1.0)
	_for_wrapped_spans(rect, func(span: Rect2i) -> void:
		_cover_a.fill_rect(span, a)
		_cover_b.fill_rect(span, b)
		_light.fill_rect(span, light)
		if authored:
			_authored[0].fill_rect(span, a)
			_authored[1].fill_rect(span, b)
			_authored[2].fill_rect(span, light)
			_authored_mask.fill_rect(span, Color.WHITE)
	)
	_dirty = true


func _stain(rect: Rect2i, ground_index: int, alpha: float, authored: bool) -> void:
	# One stain material per world (in practice the mud chips); the first wins.
	if _material.get_shader_parameter("stain_layer") == null or not has_meta(&"_stain_set"):
		set_meta(&"_stain_set", true)
		_material.set_shader_parameter("stain_layer", float(ground_index))
		_material.set_shader_parameter("stain_repeat_px", float(_WORLD_ART.ground_repeat_world_px(ground_index)))
	var amount := clampf(alpha * 5.0, 0.0, 1.0)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var at := Vector2i(posmod(x, MAP_SIZE), posmod(y, MAP_SIZE))
			var current := _light.get_pixelv(at)
			current.g = maxf(current.g, amount)
			_light.set_pixelv(at, current)
			if authored:
				_authored[2].set_pixelv(at, current)
				_authored_mask.set_pixelv(at, Color.WHITE)
	_dirty = true


## The slot drawing `ground_index`. Slots are handed out first come; a ninth
## material borrows the slot of one like it (overgrowth or paving).
func _slot_for(ground_index: int) -> int:
	for slot in SLOTS:
		if _slot_material[slot] == ground_index:
			return slot
	for slot in SLOTS:
		if _slot_material[slot] < 0:
			_slot_material[slot] = ground_index
			_push_slot_uniforms()
			return slot
	_slot_borrows += 1
	var overgrowth := _WORLD_ART.is_overgrowth_ground(ground_index)
	for slot in SLOTS:
		if _WORLD_ART.is_overgrowth_ground(_slot_material[slot]) == overgrowth:
			return slot
	return SLOTS - 1


func _push_slot_uniforms() -> void:
	var layers := PackedFloat32Array()
	var indices := PackedFloat32Array()
	var repeats := PackedFloat32Array()
	var tints := PackedColorArray()
	var roles := PackedFloat32Array()
	var og := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var hard := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var road := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var lane := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var enabled := ground_policy_enabled()
	for slot in SLOTS:
		var ground_index := maxi(0, _slot_material[slot])
		var layer := material_layer(ground_index)
		indices.append(float(ground_index))
		layers.append(float(layer))
		repeats.append(float(_WORLD_ART.ground_repeat_world_px(layer)))
		tints.append(material_tint(ground_index))
		if _slot_material[slot] >= 0 and _WORLD_ART.is_overgrowth_ground(ground_index):
			og[slot] = 1.0
		var role := _POLICY.role_for_index(ground_index) if enabled and _slot_material[slot] >= 0 else _POLICY.ROLE_RAW
		roles.append(float(role))
		if _POLICY.is_paved_role(role):
			hard[slot] = 1.0
		if role == _POLICY.ROLE_ROAD:
			road[slot] = 1.0
		elif role == _POLICY.ROLE_LANE:
			lane[slot] = 1.0
	_material.set_shader_parameter("slot_layer", layers)
	_material.set_shader_parameter("slot_index", indices)
	_material.set_shader_parameter("slot_repeat_px", repeats)
	_material.set_shader_parameter("slot_tint", tints)
	_material.set_shader_parameter("slot_role", roles)
	_material.set_shader_parameter("overgrowth_a", Vector4(og[0], og[1], og[2], og[3]))
	_material.set_shader_parameter("overgrowth_b", Vector4(og[4], og[5], og[6], og[7]))
	_material.set_shader_parameter("hard_a", Vector4(hard[0], hard[1], hard[2], hard[3]))
	_material.set_shader_parameter("hard_b", Vector4(hard[4], hard[5], hard[6], hard[7]))
	_material.set_shader_parameter("road_a", Vector4(road[0], road[1], road[2], road[3]))
	_material.set_shader_parameter("road_b", Vector4(road[4], road[5], road[6], road[7]))
	_material.set_shader_parameter("lane_a", Vector4(lane[0], lane[1], lane[2], lane[3]))
	_material.set_shader_parameter("lane_b", Vector4(lane[4], lane[5], lane[6], lane[7]))


## The policy's per-role sources and grades (a disabled policy draws raw).
func _push_role_uniforms() -> void:
	var samples := PackedVector4Array()
	var mids := PackedColorArray()
	var tints := PackedColorArray()
	var roles: Dictionary = _policy.get("roles", {})
	for role in 8:
		var entry: Dictionary = roles.get(role, {})
		var source := int(entry.get("source", _POLICY.SOURCE_OWN))
		var repeat_px := maxf(16.0, float(entry.get("repeat_px", 384.0)))
		samples.append(Vector4(float(source), float(entry.get("layer", 0)), repeat_px, 1.0 if _POLICY.is_paved_role(role) else 0.0))
		mids.append(entry.get("mid", Color(0.5, 0.5, 0.5, 0.0)))
		tints.append(entry.get("tint", Color.WHITE))
	_material.set_shader_parameter("role_sample", samples)
	_material.set_shader_parameter("role_mid", mids)
	_material.set_shader_parameter("role_tint", tints)
	var enabled := ground_policy_enabled()
	_material.set_shader_parameter("kerb_strength", float(_policy.get("kerb", 0.0)) if enabled else 0.0)
	_material.set_shader_parameter("gutter_strength", float(_policy.get("gutter", 0.0)) if enabled else 0.0)
	_material.set_shader_parameter("joint_strength", float(_policy.get("joint", 0.0)) if enabled else 0.0)
	_material.set_shader_parameter("kerb_lod", float(_policy.get("kerb_lod", 1.0)))
	_material.set_shader_parameter("kerb_warp_cells", float(_policy.get("kerb_warp_cells", 0.1)))
	_material.set_shader_parameter("ao_strength", float(_policy.get("ao", 0.0)) if enabled else 0.0)
	_material.set_shader_parameter("lawn_mottle", float(_policy.get("lawn_mottle", 0.0)) if enabled else 0.0)
	_material.set_shader_parameter("paving_variation", float(_policy.get("paving_variation", 0.0)) if enabled else 0.0)
	_material.set_shader_parameter("paved_stain_strength", float(_policy.get("paved_stain_strength", 1.0)) if enabled else 1.0)
	_material.set_shader_parameter("wet_patches", float(_policy.get("wet_patches", 0.0)) if enabled else 0.0)
	var yard_patch: Dictionary = _policy.get("yard_patch", {}) if enabled else {}
	if yard_patch.is_empty():
		_material.set_shader_parameter("yard_patch", Vector4(-1.0, 0.0, 384.0, 0.5))
	else:
		_material.set_shader_parameter("yard_patch", Vector4(float(yard_patch.get("layer", -1)), float(yard_patch.get("coverage", 0.0)), float(yard_patch.get("repeat_px", 384.0)), float(yard_patch.get("weight", 0.5))))
		_material.set_shader_parameter("yard_patch_tint", yard_patch.get("tint", Color.WHITE))
		# The patch's quiet mid tone: the yard's a shade darker.
		var yard_mid: Color = ((roles.get(_POLICY.ROLE_YARD, {}) as Dictionary).get("mid", Color(0.5, 0.5, 0.5)) as Color) * 0.92
		_material.set_shader_parameter("yard_patch_mid", Color(yard_mid.r, yard_mid.g, yard_mid.b, 1.0))
	var verge_layer := int(_policy.get("verge_layer", -1)) if enabled else -1
	_material.set_shader_parameter("verge_layer", float(verge_layer))
	_material.set_shader_parameter("verge_strength", float(_policy.get("verge_strength", 0.0)) if enabled else 0.0)
	if verge_layer >= 0:
		_material.set_shader_parameter("verge_repeat_px", float(_WORLD_ART.ground_repeat_world_px(verge_layer)))


func _ensure_quad(coord: Vector2i) -> void:
	if _quads.has(coord):
		return
	var chunk_px := float(cells_per_chunk * cell_px)
	var quad := Sprite2D.new()
	quad.name = "GroundQuad_%d_%d" % [coord.x, coord.y]
	quad.texture = _quad_texture
	quad.centered = false
	quad.scale = Vector2(chunk_px, chunk_px) / Vector2(_quad_texture.get_size())
	quad.position = Vector2(coord) * chunk_px
	quad.material = _material
	add_child(quad)
	_quads[coord] = quad


## `rect` in global cells, split into the (up to four) spans it covers in the
## wrapped maps.
func _for_wrapped_spans(rect: Rect2i, action: Callable) -> void:
	var size := Vector2i(mini(rect.size.x, MAP_SIZE), mini(rect.size.y, MAP_SIZE))
	var x0 := posmod(rect.position.x, MAP_SIZE)
	var y0 := posmod(rect.position.y, MAP_SIZE)
	var xs: Array[Vector2i] = [Vector2i(x0, mini(size.x, MAP_SIZE - x0))]
	if size.x > MAP_SIZE - x0:
		xs.append(Vector2i(0, size.x - (MAP_SIZE - x0)))
	var ys: Array[Vector2i] = [Vector2i(y0, mini(size.y, MAP_SIZE - y0))]
	if size.y > MAP_SIZE - y0:
		ys.append(Vector2i(0, size.y - (MAP_SIZE - y0)))
	for span_y in ys:
		for span_x in xs:
			action.call(Rect2i(span_x.x, span_y.x, span_x.y, span_y.y))


static func _blank_map() -> Image:
	var image := Image.create(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return image


## A copy of a coverage map with its box-filtered mip chain (the paint maps
## themselves stay single-level so fill_rect edits remain exact).
static func _mipmapped(image: Image) -> Image:
	var copy := Image.create_from_data(image.get_width(), image.get_height(), false, image.get_format(), image.get_data())
	copy.generate_mipmaps()
	return copy


## Tileable RGBA noise for the shader: R, G = a low, broad warp field; B = a
## finer grain for the ragged edge; A = the stain cut. One fetch serves all.
static func noise_texture() -> ImageTexture:
	if _noise_texture != null:
		return _noise_texture
	_noise_texture = ImageTexture.create_from_image(noise_image())
	return _noise_texture


## The noise texture's RGBA8 image, built from scratch (noise_texture caches).
static func noise_image() -> Image:
	var specs := [
		[9173, 1.0 / 20.0, 2],
		[9304, 1.0 / 20.0, 2],
		[9435, 1.0 / 7.0, 3],
		[9566, 1.0 / 10.0, 2],
	]
	var channels: Array[Image] = []
	for spec in specs:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.seed = int(spec[0])
		noise.frequency = float(spec[1])
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = int(spec[2])
		channels.append(noise.get_seamless_image(NOISE_PX, NOISE_PX))
	var data := PackedByteArray()
	data.resize(NOISE_PX * NOISE_PX * 4)
	# get_seamless_image returns L8 planes: interleave their bytes directly.
	# The old per-pixel get_pixel(x, y).r8 loop (65,536 calls, the same
	# bytes) was most of a 160 ms first use (FPS audit 2026-10-04).
	var planes: Array[PackedByteArray] = []
	for channel_image in channels:
		if channel_image.get_format() != Image.FORMAT_L8 or channel_image.has_mipmaps() or channel_image.get_width() != NOISE_PX or channel_image.get_height() != NOISE_PX:
			planes.clear()
			break
		planes.append(channel_image.get_data())
	if planes.size() == 4:
		var pixel_count := NOISE_PX * NOISE_PX
		for channel in 4:
			var plane := planes[channel]
			for i in pixel_count:
				data[i * 4 + channel] = plane[i]
	else:
		for y in NOISE_PX:
			for x in NOISE_PX:
				var i := (y * NOISE_PX + x) * 4
				for channel in 4:
					data[i + channel] = channels[channel].get_pixel(x, y).r8
	return Image.create_from_data(NOISE_PX, NOISE_PX, false, Image.FORMAT_RGBA8, data)


static func release_static_caches() -> void:
	_noise_texture = null
