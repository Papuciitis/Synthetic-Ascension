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

## Cells, wrapped. 256 cells = 16 chunks = 16384 px: larger than any streamed
## window, and the whole of Segment 1 fits without wrapping onto itself.
const MAP_SIZE := 256
const SLOTS := 8
const NOISE_PX := 128
## Stamps under this alpha are stains, not floors.
const STAIN_ALPHA := 0.5
## light_map R stores brightness / 2 so authored stamps may run above 1.
const BRIGHTNESS_SCALE := 0.5

var cell_px := 64
var cells_per_chunk := 32

## One-hot material coverage: slots 0-3 in _cover_a, 4-7 in _cover_b.
var _cover_a: Image
var _cover_b: Image
## R = brightness / 2, G = stain amount.
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
	_cover_a_texture = ImageTexture.create_from_image(_cover_a)
	_cover_b_texture = ImageTexture.create_from_image(_cover_b)
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
	_push_slot_uniforms()


func configure(p_cell_px: int, p_cells_per_chunk: int) -> void:
	cell_px = maxi(1, p_cell_px)
	cells_per_chunk = maxi(1, p_cells_per_chunk)
	_material.set_shader_parameter("cell_px", float(cell_px))
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


func get_shader_material() -> ShaderMaterial:
	return _material


## Lay a chunk's base ground over its whole block, which also forgets any
## stamps a chunk 16 chunks away left in the wrapped map. Generated chunks
## paint their stamps after this; authored stamps are laid back on top here.
func set_chunk_base(coord: Vector2i, material: int, brightness: float = 1.0) -> void:
	var block := Rect2i(coord * cells_per_chunk, Vector2i(cells_per_chunk, cells_per_chunk))
	_fill(block, material, brightness, false)
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
func paint_rect(rect: Rect2i, material: int, alpha: float, brightness: float = 1.0, authored: bool = false) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0 or material < 0:
		return
	if authored and _authored_mask == null:
		_authored = [_blank_map(), _blank_map(), _blank_map()]
		_authored_mask = _blank_map()
	if alpha < STAIN_ALPHA:
		_stain(rect, material, alpha, authored)
	else:
		_fill(rect, material, brightness, authored)
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


func clear() -> void:
	for image in [_cover_a, _cover_b, _light]:
		(image as Image).fill(Color(0, 0, 0, 0))
	_authored.clear()
	_authored_mask = null
	_slot_material.fill(-1)
	_push_slot_uniforms()
	_dirty = true
	for quad in _quads.values():
		if is_instance_valid(quad):
			(quad as Node).queue_free()
	_quads.clear()


func quad_count() -> int:
	return _quads.size()


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
	_cover_a_texture.update(_cover_a)
	_cover_b_texture.update(_cover_b)
	_light_texture.update(_light)


func _fill(rect: Rect2i, material: int, brightness: float, authored: bool) -> void:
	var slot := _slot_for(material)
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


func _stain(rect: Rect2i, material: int, alpha: float, authored: bool) -> void:
	# One stain material per world (in practice the mud chips); the first wins.
	if _material.get_shader_parameter("stain_layer") == null or not has_meta(&"_stain_set"):
		set_meta(&"_stain_set", true)
		_material.set_shader_parameter("stain_layer", float(material))
		_material.set_shader_parameter("stain_repeat_px", float(_WORLD_ART.ground_repeat_world_px(material)))
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


## The slot drawing `material`. Slots are handed out first come; a ninth
## material borrows the slot of one like it (overgrowth or paving).
func _slot_for(material: int) -> int:
	for slot in SLOTS:
		if _slot_material[slot] == material:
			return slot
	for slot in SLOTS:
		if _slot_material[slot] < 0:
			_slot_material[slot] = material
			_push_slot_uniforms()
			return slot
	var overgrowth := _WORLD_ART.is_overgrowth_ground(material)
	for slot in SLOTS:
		if _WORLD_ART.is_overgrowth_ground(_slot_material[slot]) == overgrowth:
			return slot
	return SLOTS - 1


func _push_slot_uniforms() -> void:
	var layers := PackedFloat32Array()
	var repeats := PackedFloat32Array()
	var tints := PackedColorArray()
	var og := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for slot in SLOTS:
		var material := maxi(0, _slot_material[slot])
		var layer := material_layer(material)
		layers.append(float(layer))
		repeats.append(float(_WORLD_ART.ground_repeat_world_px(layer)))
		tints.append(material_tint(material))
		if _slot_material[slot] >= 0 and _WORLD_ART.is_overgrowth_ground(material):
			og[slot] = 1.0
	_material.set_shader_parameter("slot_layer", layers)
	_material.set_shader_parameter("slot_repeat_px", repeats)
	_material.set_shader_parameter("slot_tint", tints)
	_material.set_shader_parameter("overgrowth_a", Vector4(og[0], og[1], og[2], og[3]))
	_material.set_shader_parameter("overgrowth_b", Vector4(og[4], og[5], og[6], og[7]))


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


## Tileable RGBA noise for the shader: R, G = a low, broad warp field; B = a
## finer grain for the ragged edge; A = the stain cut. One fetch serves all.
static func noise_texture() -> ImageTexture:
	if _noise_texture != null:
		return _noise_texture
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
	for y in NOISE_PX:
		for x in NOISE_PX:
			var i := (y * NOISE_PX + x) * 4
			for channel in 4:
				data[i + channel] = channels[channel].get_pixel(x, y).r8
	var image := Image.create_from_data(NOISE_PX, NOISE_PX, false, Image.FORMAT_RGBA8, data)
	_noise_texture = ImageTexture.create_from_image(image)
	return _noise_texture


static func release_static_caches() -> void:
	_noise_texture = null
