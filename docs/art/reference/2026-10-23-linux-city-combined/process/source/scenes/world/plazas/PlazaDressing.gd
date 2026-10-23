extends Node2D
## Plaza dressing drawn from a PlazaPresentation plan: edged planting beds on
## the plaza islands, the centrepiece (fountain, well or wall fountain), lamp
## pairs at road mouths, cypress accents in planter ends, benches along
## planters or the square's open edge, market stalls (with a cluster of pots)
## on north-edge planters or the open north edge, drain grates in the gutters
## and notice boards at civic entries.
##
## Presentation only: this node owns no collision, encounters, rewards or
## random generator state; every position comes from the plan. The props all
## sample one small atlas (assets/world/plazas_v1/kit/plaza_props.png, built
## by tools/design/build_plaza_kit.py), so the tall ones registered with
## ForegroundSpriteCoverage add a single layer to WorldCover's alpha array.

const ATLAS := preload("res://assets/world/plazas_v1/kit/plaza_props.png")
const STONE := preload("res://assets/world/plazas_v1/kit/plaza_stone.png")
## One repeat of the cared lawn / earth ground at one texel per world px.
const LAWN := preload("res://assets/world/plazas_v1/kit/plaza_lawn.png")
const SOIL := preload("res://assets/world/plazas_v1/kit/plaza_soil.png")
const FOREGROUND := preload("res://core/systems/world/visibility/ForegroundSpriteCoverage.gd")
const KIT := preload("res://core/systems/world/chunks/PlazaEdgeKit.gd")
## Plaza pass 2: the props of working, ruined, damp and military squares
## (stacked goods, supplies, rubble, weeds, debris) in a second small atlas
## (tools/design/build_plaza_wear_kit.py). None is registered for actor
## cover, so WorldCover's shared alpha array never sees this texture.
# State textures come from PlazaEdgeKit. Instance refs keep an old visible
# chunk valid while the shared warm cache advances to the next segment.
const WORN_REGIONS := {
	&"barrels_group": Rect2(228, 8, 69, 67),
	&"crates_stack": Rect2(130, 8, 90, 71),
	&"floor_debris": Rect2(8, 90, 90, 56),
	&"handcart": Rect2(8, 8, 114, 74),
	&"rubble_heap": Rect2(195, 90, 126, 50),
	&"rubble_pile": Rect2(329, 90, 105, 37),
	&"sacks_pile": Rect2(106, 90, 81, 54),
	&"scaffold_crates": Rect2(305, 8, 120, 60),
	&"weeds_a": Rect2(8, 154, 39, 28),
	&"weeds_b": Rect2(55, 154, 45, 27),
	&"weeds_c": Rect2(442, 90, 45, 36),
}
## Painted goods sit a touch under the actors in value (as the frontage
## dressing's props); rubble and debris are pulled cooler, off the beige.
const WORN_TINT := Color(0.90, 0.90, 0.88)
const RUBBLE_TINT := Color(0.84, 0.85, 0.84)
const WEEDS := [&"weeds_a", &"weeds_b", &"weeds_c"]
## Island props on the existing half-cover cell, by maintenance state.
const ISLAND_PROPS := {
	KIT.STATE_WORKING: [&"crates_stack", &"barrels_group"],
	KIT.STATE_MILITARY: [&"crates_stack", &"sacks_pile"],
	KIT.STATE_RUINED: [&"rubble_heap"],
}
const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")

## Atlas texels per world px and regions (tools/design/build_plaza_kit.py).
const TEXELS := 1.5
const REGIONS := {
	&"bench_stone": Rect2(516, 215, 156, 39),
	&"box_shrub": Rect2(680, 215, 45, 31),
	&"cypress": Rect2(880, 8, 54, 150),
	&"drain_grate": Rect2(309, 215, 57, 54),
	&"lamp_post": Rect2(8, 8, 38, 199),
	&"lavender": Rect2(466, 215, 42, 42),
	&"market_stall": Rect2(103, 215, 198, 100),
	&"notice_board": Rect2(8, 215, 87, 132),
	&"olive_planter": Rect2(582, 8, 126, 157),
	&"plaza_fountain": Rect2(206, 8, 192, 188),
	&"pots_cluster": Rect2(374, 215, 84, 54),
	&"tree_planter": Rect2(54, 8, 144, 199),
	&"wall_fountain": Rect2(716, 8, 156, 154),
	&"well_stone": Rect2(406, 8, 168, 180),
}
## Draw order inside a chunk: ground decals and beds under the foliage and
## landmark, standing props just under actors and above the plaza edges.
const DRAIN_Z := -89
const BED_Z := -88
const KERB_Z := -87
const SHADOW_Z := -86
const BED_PLANT_Z := -84
const PROP_Z := -2
## Under the plaza edge pieces (WALL_Z -3): props north of a planter.
const BEHIND_EDGE_Z := -4
## A bed covers its island's cells plus the ground splat's edge warp (about
## 0.62 cell), so the stamped grass never shows outside the kerb.
const BED_GROW := 34.0
const BED_ROUTE_GROW := -6.0
const KERB_PX := 7.0
const SHADOW_COLOR := Color(0.06, 0.10, 0.13, 0.22)
const STONE_TINT := Color(0.93, 0.92, 0.89)
const GRASS_LIKE := [0, 10, 11, 12, 13]

var _cell := 64
var _state := 0
var _worn_atlas: Texture2D
var _worn_fill: Texture2D


func compose(plan: Dictionary, cell_px: int) -> void:
	_cell = cell_px
	_state = int(plan.get("state", KIT.STATE_TENDED))
	if _state != KIT.STATE_TENDED:
		_worn_atlas = KIT.dressing_texture(_state, &"worn_atlas")
	if _state == KIT.STATE_RUINED or _state == KIT.STATE_DAMP:
		_worn_fill = KIT.dressing_texture(_state, &"weeds_ground" if _state == KIT.STATE_RUINED else &"moss_soil")
	for island: Dictionary in plan.get("islands", []):
		if _state == KIT.STATE_TENDED:
			_bed(island)
		else:
			_worn_bed(island)
	for item: Dictionary in plan.get("edge_wear", []):
		_edge_wear(item)
	for item: Dictionary in plan.get("edge_goods", []):
		# Working clutter / supplies where a tended square would seat people:
		# the bench's own place, visual only, the same footprint.
		var cell: Vector2i = item.cell
		var foot := Vector2((cell.x + 1) * _cell, cell.y * _cell + 76)
		if bool(item.get("open", false)):
			foot.y = cell.y * _cell + (28 if int(item.side) > 0 else 52)
		elif int(item.get("side", 1)) < 0:
			foot.y = cell.y * _cell - 8
		var goods := _worn_prop(item.id, foot)
		if not bool(item.get("open", false)) and int(item.get("side", 1)) < 0:
			goods.z_index = BEHIND_EDGE_Z
	for item: Dictionary in plan.get("ring_props", []):
		# Goods, supplies or rubble over the ring cell's band (blocked).
		var cell: Vector2i = item.cell
		_worn_prop(item.id, Vector2((cell.x + 0.5) * _cell, cell.y * _cell + 42.0))
	for debris: Dictionary in plan.get("debris", []):
		var cell: Vector2i = debris.cell
		var sprite := _worn_sprite(&"floor_debris", Vector2((cell.x + 0.5) * _cell, (cell.y + 0.5) * _cell), 1.0)
		sprite.z_index = DRAIN_Z
		# Quiet ground under combat: flat, low, cool.
		sprite.modulate = Color(0.62, 0.62, 0.60, 0.5)
		sprite.set_meta(&"plaza_piece", &"floor_debris")
	var centre: Dictionary = plan.get("centrepiece", {})
	if not centre.is_empty():
		_centrepiece(centre)
	for stall: Dictionary in plan.get("stalls", []):
		var cell: Vector2i = stall.cell
		# On a planter (blocked support) its base is the planter's front; on
		# the open edge row it stands at the back of the row.
		var foot_y := cell.y * _cell + (62 if bool(stall.get("ring", true)) else 40)
		_prop(&"market_stall", Vector2((cell.x + 1) * _cell, foot_y), 1.0, true)
	for pots: Dictionary in plan.get("pots", []):
		var cell: Vector2i = pots.cell
		_prop(&"pots_cluster", Vector2((cell.x + 0.5) * _cell, cell.y * _cell + (60 if bool(pots.ring) else 40)), 1.0, false)
	for bench: Dictionary in plan.get("benches", []):
		var cell: Vector2i = bench.cell
		if bool(bench.get("open", false)):
			# On the square's own edge row, its back to the open ground.
			_prop(&"bench_stone", Vector2((cell.x + 1) * _cell, cell.y * _cell + (28 if int(bench.side) > 0 else 52)), 1.0, false)
		elif int(bench.get("side", 1)) > 0:
			# In front of a north-edge planter, just past its face.
			_prop(&"bench_stone", Vector2((cell.x + 1) * _cell, cell.y * _cell + 76), 1.0, false)
		else:
			# Behind a south-edge planter: drawn under the planter's band.
			var behind := _prop(&"bench_stone", Vector2((cell.x + 1) * _cell, cell.y * _cell - 8), 1.0, false)
			behind.z_index = BEHIND_EDGE_Z
	for lamp: Dictionary in plan.get("lamps", []):
		var cell: Vector2i = lamp.cell
		var toward: Vector2 = lamp.get("toward", Vector2.ZERO)
		_prop(&"lamp_post", Vector2((cell.x + 0.5) * _cell, cell.y * _cell + 48) + toward * 20.0, 1.0, true)
	for accent: Dictionary in plan.get("accents", []):
		# A clipped cypress standing in the planter's closed end.
		var cell: Vector2i = accent.cell
		_prop(&"cypress", Vector2((cell.x + 0.5) * _cell, cell.y * _cell + 40), 1.0, true)
	for drain: Dictionary in plan.get("drains", []):
		var cell: Vector2i = drain.cell
		var sprite := _sprite(&"drain_grate", Vector2((cell.x + 0.5) * _cell, (cell.y + 0.5) * _cell), 0.82)
		sprite.z_index = DRAIN_Z
		# Quiet ground: a grate set flush in the paving, not a marker.
		sprite.modulate = Color(0.58, 0.56, 0.52, 0.62)
		sprite.set_meta(&"plaza_piece", &"drain_grate")
	for board: Dictionary in plan.get("notice_boards", []):
		_prop(&"notice_board", board.foot, 1.0, true)


# ------------------------------------------------------------------ props --

## A standing prop whose ground contact (feet) is `foot`, in chunk-local px.
func _prop(id: StringName, foot: Vector2, size: float, cover: bool) -> Sprite2D:
	var region: Rect2 = REGIONS[id]
	var scale_value := size / TEXELS
	var at := foot - Vector2(0.0, region.size.y * scale_value * 0.5)
	var sprite := _sprite(id, at, size)
	sprite.z_index = PROP_Z
	sprite.set_meta(&"plaza_piece", id)
	sprite.set_meta(&"plaza_ground_contact", foot)
	if cover:
		FOREGROUND.register(sprite, foot)
	_shadow(sprite, foot)
	return sprite


func _sprite(id: StringName, at: Vector2, size: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "%s_%d" % [id, get_child_count()]
	sprite.texture = ATLAS
	sprite.region_enabled = true
	sprite.region_rect = REGIONS[id]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2.ONE * (size / TEXELS)
	sprite.position = at
	add_child(sprite)
	return sprite


## A soft projected ground shadow of the prop's silhouette, away from the
## fixed top-right light (WorldDepthStyle), like the city trees' shadows.
func _shadow(sprite: Sprite2D, foot: Vector2) -> void:
	_shadow_for(sprite, foot, ATLAS)


func _centrepiece(centre: Dictionary) -> void:
	var cells: Rect2i = centre.cells
	var kind: StringName = centre.kind
	var box := Rect2(Vector2(cells.position) * _cell, Vector2(cells.size) * _cell)
	match kind:
		&"wall_fountain":
			# Against the north planter: basin front on the ring cells' face.
			_prop(kind, Vector2(box.get_center().x, box.position.y + 62.0), 1.0, true)
		&"well_stone":
			_prop(kind, Vector2(box.get_center().x, box.end.y - 6.0), 1.0, true)
		_:
			_prop(kind, Vector2(box.get_center().x, box.end.y - 2.0), 1.0, true)


# ------------------------------------------------------------------- beds --

## An island becomes an edged planting bed: a dressed limestone kerb around a
## clipped lawn (grass islands) or planted earth (other islands), low planting
## along its inner edge, and a planter tree on the island's existing
## half-cover cell. The bed itself stays walkable, as the island was.
func _bed(island: Dictionary) -> void:
	var lawn := int(island.tex) in GRASS_LIKE
	var prop: Vector2i = island.prop
	if prop.x >= 0:
		var foot := Vector2((prop.x + 0.5) * _cell, (prop.y + 0.5) * _cell + 22.0)
		_prop(&"olive_planter" if lawn else &"tree_planter", foot, 1.0, true)
	var rect: Rect2i = island.get("bed", Rect2i())
	if not rect.has_area():
		return
	# Spread over the splat's warped grass edge, except toward the route,
	# where the kerb keeps to the bed's own cells.
	var sides := int(island.get("route_sides", 0))
	var area := Rect2(Vector2(rect.position) * _cell, Vector2(rect.size) * _cell).grow_individual(
		BED_ROUTE_GROW if sides & 8 else BED_GROW, BED_ROUTE_GROW if sides & 1 else BED_GROW,
		BED_ROUTE_GROW if sides & 2 else BED_GROW, BED_ROUTE_GROW if sides & 4 else BED_GROW)
	var inner := _chamfered(area, 12.0)
	var outer := _chamfered(area.grow(KERB_PX), 12.0 + KERB_PX * 0.4)
	var fill := Polygon2D.new()
	fill.name = "Bed_%d" % get_child_count()
	fill.polygon = inner
	fill.texture = LAWN if lawn else SOIL
	fill.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	fill.uv = _world_uv(inner, Vector2.ONE)
	fill.color = Color(0.74, 0.79, 0.68) if lawn else Color(0.60, 0.53, 0.45)
	fill.z_index = BED_Z
	fill.set_meta(&"plaza_piece", &"bed")
	add_child(fill)
	var kerb := Polygon2D.new()
	kerb.name = "Kerb_%d" % get_child_count()
	var points := PackedVector2Array()
	points.append_array(outer)
	points.append_array(inner)
	var count := inner.size()
	var quads: Array = []
	for i in count:
		var j := (i + 1) % count
		quads.append(PackedInt32Array([i, j, count + j, count + i]))
	kerb.polygon = points
	kerb.polygons = quads
	kerb.texture = STONE
	kerb.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	kerb.uv = _world_uv(points, STONE.get_size() / 64.0)
	# Lit north and east, shaded south and west: a kerb, not an outline.
	var colors := PackedColorArray()
	var centre := area.get_center()
	for point: Vector2 in points:
		var towards := (point - centre).normalized()
		var light := 1.0 + 0.10 * clampf(-towards.y + towards.x * 0.6, -1.0, 1.0)
		colors.append(Color(STONE_TINT.r * light, STONE_TINT.g * light, STONE_TINT.b * light))
	kerb.vertex_colors = colors
	kerb.z_index = KERB_Z
	kerb.set_meta(&"plaza_piece", &"kerb")
	add_child(kerb)
	# The kerb's south face: a thin shaded band where it drops to the paving.
	var face := Polygon2D.new()
	face.name = "KerbFace_%d" % get_child_count()
	var bottom := area.grow(KERB_PX).end.y
	face.polygon = PackedVector2Array([Vector2(area.position.x - KERB_PX * 0.6, bottom), Vector2(area.end.x + KERB_PX * 0.6, bottom), Vector2(area.end.x + KERB_PX * 0.2, bottom + 3.0), Vector2(area.position.x - KERB_PX * 0.2, bottom + 3.0)])
	face.color = Color(0.36, 0.34, 0.31, 0.75)
	face.z_index = KERB_Z
	add_child(face)
	# Low clipped planting along the inner north and side edges.
	var plant: StringName = &"box_shrub" if lawn else &"lavender"
	var step := 34.0
	var x := area.position.x + 20.0
	while x <= area.end.x - 20.0:
		_bed_plant(plant, Vector2(x, area.position.y + 20.0))
		x += step
	var y := area.position.y + 20.0 + step
	while y <= area.end.y - 24.0:
		_bed_plant(plant, Vector2(area.position.x + 15.0, y))
		_bed_plant(plant, Vector2(area.end.x - 15.0, y))
		y += step


func _bed_plant(id: StringName, foot: Vector2) -> void:
	var region: Rect2 = REGIONS[id]
	var sprite := _sprite(id, foot - Vector2(0.0, region.size.y * (0.9 / TEXELS) * 0.5), 0.9)
	sprite.z_index = BED_PLANT_Z
	sprite.set_meta(&"plaza_piece", id)


static func _chamfered(rect: Rect2, cut: float) -> PackedVector2Array:
	var c := minf(cut, minf(rect.size.x, rect.size.y) * 0.3)
	return PackedVector2Array([
		rect.position + Vector2(c, 0.0), Vector2(rect.end.x - c, rect.position.y),
		Vector2(rect.end.x, rect.position.y + c), Vector2(rect.end.x, rect.end.y - c),
		Vector2(rect.end.x - c, rect.end.y), Vector2(rect.position.x + c, rect.end.y),
		Vector2(rect.position.x, rect.end.y - c), Vector2(rect.position.x, rect.position.y + c),
	])


## Texture coordinates in world space, so beds and kerbs continue across
## chunks and never restart their pattern at a polygon edge.
func _world_uv(points: PackedVector2Array, texels_per_px: Vector2) -> PackedVector2Array:
	var parent := get_parent() as Node2D
	var origin: Vector2 = parent.position if parent != null else Vector2.ZERO
	var uv := PackedVector2Array()
	for point: Vector2 in points:
		uv.append((origin + point) * texels_per_px)
	return uv


# ------------------------------------------------------------- worn state --

func _worn_sprite(id: StringName, at: Vector2, size: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "%s_%d" % [id, get_child_count()]
	sprite.texture = _worn_atlas
	sprite.region_enabled = true
	sprite.region_rect = WORN_REGIONS[id]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2.ONE * (size / TEXELS)
	sprite.position = at
	add_child(sprite)
	return sprite


## A standing worn prop (goods, rubble) with its feet at `foot`: drawn just
## under the actors, with a soft ground shadow; never actor cover (short).
func _worn_prop(id: StringName, foot: Vector2) -> Sprite2D:
	var region: Rect2 = WORN_REGIONS[id]
	var sprite := _worn_sprite(id, foot - Vector2(0.0, region.size.y / TEXELS * 0.5), 1.0)
	sprite.z_index = PROP_Z
	sprite.modulate = RUBBLE_TINT if String(id).begins_with("rubble") else WORN_TINT
	sprite.set_meta(&"plaza_piece", id)
	sprite.set_meta(&"plaza_ground_contact", foot)
	var shade := _shadow_for(sprite, foot, sprite.texture)
	shade.color = Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, SHADOW_COLOR.a * 0.8)
	return sprite


func _shadow_for(sprite: Sprite2D, foot: Vector2, texture: Texture2D) -> Polygon2D:
	var region := sprite.region_rect
	var half := region.size * 0.5
	var projection := DEPTH.project_transform(sprite.transform, foot)
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for corner: Vector2 in [Vector2.ZERO, Vector2(region.size.x, 0.0), region.size, Vector2(0.0, region.size.y)]:
		points.append(projection * (corner - half))
		uv.append(region.position + corner)
	var shade := Polygon2D.new()
	shade.name = "Shadow_%d" % get_child_count()
	shade.polygon = points
	shade.uv = uv
	shade.texture = texture
	shade.color = SHADOW_COLOR
	shade.z_index = SHADOW_Z
	shade.set_meta(&"city_sun_shadow", true)
	add_child(shade)
	return shade


## An island in a working, ruined, damp or military square: no clipped bed.
## Working and military ground is bare packed earth without a garden rim;
## ruined beds keep sparse broken kerbstones; damp pockets are wet and mossy
## with unclipped weeds. The island's existing half-cover cell carries the
## state's prop (goods, supplies, a rubble heap, or the damp planter tree).
func _worn_bed(island: Dictionary) -> void:
	var prop: Vector2i = island.prop
	var seed_value := int(island.get("wear_seed", 0))
	if prop.x >= 0:
		var foot := Vector2((prop.x + 0.5) * _cell, (prop.y + 0.5) * _cell + 22.0)
		if ISLAND_PROPS.has(_state):
			var ids: Array = ISLAND_PROPS[_state]
			_worn_prop(ids[posmod(seed_value, ids.size())], foot)
		else:
			_prop(&"tree_planter", foot, 1.0, true)
	var rect: Rect2i = island.get("bed", Rect2i())
	if not rect.has_area():
		return
	var sides := int(island.get("route_sides", 0))
	var area := Rect2(Vector2(rect.position) * _cell, Vector2(rect.size) * _cell).grow_individual(
		BED_ROUTE_GROW if sides & 8 else BED_GROW, BED_ROUTE_GROW if sides & 1 else BED_GROW,
		BED_ROUTE_GROW if sides & 2 else BED_GROW, BED_ROUTE_GROW if sides & 4 else BED_GROW)
	var inner := _chamfered(area, 12.0) if _state == KIT.STATE_RUINED else _rough_patch(area, seed_value)
	var fill := Polygon2D.new()
	fill.name = "Bed_%d" % get_child_count()
	fill.polygon = inner
	fill.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	fill.uv = _world_uv(inner, Vector2.ONE)
	var kerb_tint := STONE_TINT
	var gap_share := 0.0
	match _state:
		KIT.STATE_WORKING:
			fill.texture = SOIL
			fill.color = Color(0.56, 0.54, 0.50)
		KIT.STATE_MILITARY:
			fill.texture = SOIL
			fill.color = Color(0.66, 0.63, 0.57)
		KIT.STATE_RUINED:
			fill.texture = _worn_fill
			fill.color = Color(0.70, 0.70, 0.64)
			kerb_tint = Color(0.80, 0.80, 0.77)
			gap_share = 0.68
		_:
			fill.texture = _worn_fill
			fill.color = Color(0.78, 0.82, 0.76)
	fill.z_index = BED_Z
	fill.set_meta(&"plaza_piece", &"bed")
	_feather_ground(fill, inner, 14.0)
	add_child(fill)
	if _state == KIT.STATE_RUINED:
		_worn_kerb(area, inner, kerb_tint, gap_share, seed_value)
	# Unclipped weeds scattered through neglected beds (none on bare ground).
	if _state == KIT.STATE_RUINED or _state == KIT.STATE_DAMP:
		var count := clampi(int(area.get_area() / 9000.0), 2, 5)
		for k in count:
			var h := _mix(seed_value, k + 11)
			var at := area.position + Vector2(18.0 + float(h % 1000) / 1000.0 * maxf(1.0, area.size.x - 36.0), 22.0 + float((h >> 10) % 1000) / 1000.0 * maxf(1.0, area.size.y - 40.0))
			var region: Rect2 = WORN_REGIONS[WEEDS[k % WEEDS.size()]]
			var weed := _worn_sprite(WEEDS[k % WEEDS.size()], at - Vector2(0.0, region.size.y / TEXELS * 0.45), 0.9)
			weed.z_index = BED_PLANT_Z
			weed.modulate = Color(0.86, 0.88, 0.80) if _state == KIT.STATE_RUINED else Color(0.80, 0.86, 0.80)
			weed.set_meta(&"plaza_piece", &"weeds")
	# A broken bed spills a little rubble where its kerb is gone.
	if _state == KIT.STATE_RUINED:
		var chip := _worn_sprite(&"rubble_pile", Vector2(area.position.x + area.size.x * (0.3 + float(_mix(seed_value, 5) % 400) / 1000.0), area.end.y - 4.0), 0.55)
		chip.z_index = BED_PLANT_Z
		chip.modulate = RUBBLE_TINT
		chip.set_meta(&"plaza_piece", &"rubble_chip")


## The bed's kerb as short stone segments; `gap_share` of them are missing
## (worn or broken kerbs). Segments are ~48 px, so a gap reads as a lost
## kerbstone, not an open side. Lit north/east, shaded south/west.
func _worn_kerb(area: Rect2, inner: PackedVector2Array, tint: Color, gap_share: float, seed_value: int) -> void:
	var outer := _chamfered(area.grow(KERB_PX), 12.0 + KERB_PX * 0.4)
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var quads: Array = []
	var centre := area.get_center()
	var count := inner.size()
	var segment := 0
	for i in count:
		var j := (i + 1) % count
		var pieces := maxi(1, ceili(inner[i].distance_to(inner[j]) / 48.0))
		for k in pieces:
			segment += 1
			if gap_share > 0.0 and float(_mix(seed_value, segment) % 1000) / 1000.0 < gap_share:
				continue
			var t0 := float(k) / float(pieces)
			var t1 := float(k + 1) / float(pieces)
			var base := points.size()
			for point: Vector2 in [inner[i].lerp(inner[j], t0), inner[i].lerp(inner[j], t1), outer[i].lerp(outer[j], t1), outer[i].lerp(outer[j], t0)]:
				points.append(point)
				var towards := (point - centre).normalized()
				var light := 1.0 + 0.10 * clampf(-towards.y + towards.x * 0.6, -1.0, 1.0)
				colors.append(Color(tint.r * light, tint.g * light, tint.b * light))
			quads.append(PackedInt32Array([base, base + 1, base + 2, base + 3]))
	if quads.is_empty():
		return
	var kerb := Polygon2D.new()
	kerb.name = "Kerb_%d" % get_child_count()
	kerb.polygon = points
	kerb.polygons = quads
	kerb.texture = STONE
	kerb.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	kerb.uv = _world_uv(points, STONE.get_size() / 64.0)
	kerb.vertex_colors = colors
	kerb.z_index = KERB_Z
	kerb.set_meta(&"plaza_piece", &"kerb")
	add_child(kerb)


## Low ground dressing only: use/exposure marks remain within their selected
## off-route cell and under actors. No oil is inferred without machinery.
func _edge_wear(item: Dictionary) -> void:
	var cell: Vector2i = item.cell
	var kind := StringName(item.kind)
	var seed_value := int(item.seed)
	var outward := Vector2(item.outward).limit_length(1.0)
	var at := (Vector2(cell) + Vector2.ONE * 0.5) * _cell + outward * 5.0
	if kind == &"rubble" or kind == &"weeds":
		var id := StringName(WEEDS[posmod(seed_value, WEEDS.size())]) if kind == &"weeds" else &"floor_debris"
		var sprite := _worn_sprite(id, at, 0.8 if kind == &"weeds" else 0.65)
		sprite.z_index = DRAIN_Z
		sprite.modulate = Color(0.77, 0.81, 0.71, 0.75) if kind == &"weeds" else Color(0.67, 0.68, 0.64, 0.58)
		sprite.set_meta(&"plaza_edge_wear", cell)
		sprite.set_meta(&"plaza_piece", &"edge_weeds" if kind == &"weeds" else &"edge_rubble")
		return
	var size := Vector2(48.0, 36.0) if absf(outward.y) > 0.0 else Vector2(36.0, 48.0)
	var patch := Polygon2D.new()
	patch.name = "EdgeWear_%d" % get_child_count()
	patch.texture = _worn_fill if kind == &"moss" or kind == &"weedy" else SOIL
	patch.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	patch.color = Color(0.72, 0.77, 0.66, 0.42) if kind == &"moss" else Color(0.69, 0.66, 0.57, 0.32)
	_feather_ground(patch, _rough_patch(Rect2(at - size * 0.5, size), seed_value), 9.0)
	patch.z_index = DRAIN_Z
	patch.set_meta(&"plaza_edge_wear", cell)
	patch.set_meta(&"plaza_piece", &"edge_ground")
	add_child(patch)


## Unequal open ground edges, kept within the existing island/edge area.
## These replace the repeated chamfered garden loop on useful or damp ground.
func _rough_patch(area: Rect2, seed_value: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var points := [Vector2(0.10, 0.04), Vector2(0.42, 0.0), Vector2(0.82, 0.06), Vector2(1.0, 0.22), Vector2(0.94, 0.58), Vector2(1.0, 0.86), Vector2(0.76, 0.98), Vector2(0.44, 0.94), Vector2(0.12, 1.0), Vector2(0.0, 0.76), Vector2(0.05, 0.43), Vector2(0.0, 0.18)]
	for i in points.size():
		var inward := float(_mix(seed_value, i + 31) % 60) / 1000.0
		var point: Vector2 = points[i]
		out.append(area.position + point.lerp(Vector2.ONE * 0.5, inward) * area.size)
	return out


## A narrow alpha feather softens source changes without another texture,
## shader, runtime image or sampling pass. Both rings stay inside the area.
func _feather_ground(fill: Polygon2D, outline: PackedVector2Array, inset: float) -> void:
	var centre := Vector2.ZERO
	for point: Vector2 in outline:
		centre += point
	centre /= float(outline.size())
	var points := outline.duplicate()
	var colors := PackedColorArray()
	for point: Vector2 in outline:
		colors.append(Color(1, 1, 1, 0))
		points.append(point.move_toward(centre, inset))
	for i in outline.size() + 1:
		colors.append(Color.WHITE)
	points.append(centre)
	var count := outline.size()
	var quads: Array = []
	for i in count:
		var j := (i + 1) % count
		quads.append(PackedInt32Array([i, j, count + j, count + i]))
		quads.append(PackedInt32Array([count + i, count + j, count * 2]))
	fill.polygon = points
	fill.polygons = quads
	fill.vertex_colors = colors
	fill.uv = _world_uv(points, Vector2.ONE)


static func _mix(seed_value: int, k: int) -> int:
	var h := int((seed_value ^ (k * 0x9E3779B9)) & 0x7FFFFFFF)
	return int((h * 1103515245 + 12345) & 0x7FFFFFFF)
