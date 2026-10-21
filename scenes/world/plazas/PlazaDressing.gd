extends Node2D
## Plaza dressing drawn from a PlazaPresentation plan: edged planting beds on
## the plaza islands, the centrepiece (fountain, well or wall fountain), lamp
## pairs at road mouths, cypress accents in planter ends, benches along
## planters or the square's open edge, market stalls on north-edge planters,
## drain grates in the gutters and notice boards at civic entries.
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


func compose(plan: Dictionary, cell_px: int) -> void:
	_cell = cell_px
	for island: Dictionary in plan.get("islands", []):
		_bed(island)
	var centre: Dictionary = plan.get("centrepiece", {})
	if not centre.is_empty():
		_centrepiece(centre)
	for stall: Dictionary in plan.get("stalls", []):
		var cell: Vector2i = stall.cell
		# On a planter (blocked support) its base is the planter's front; on
		# the open edge row it stands at the back of the row.
		var foot_y := cell.y * _cell + (62 if bool(stall.get("ring", true)) else 40)
		_prop(&"market_stall", Vector2((cell.x + 1) * _cell, foot_y), 1.0, true)
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
	var region := sprite.region_rect
	var half := region.size * 0.5
	var projection := DEPTH.project_transform(sprite.transform, foot)
	var corners := [Vector2.ZERO, Vector2(region.size.x, 0.0), region.size, Vector2(0.0, region.size.y)]
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for corner: Vector2 in corners:
		points.append(projection * (corner - half))
		uv.append(region.position + corner)
	var shade := Polygon2D.new()
	shade.name = "Shadow_%d" % get_child_count()
	shade.polygon = points
	shade.uv = uv
	shade.texture = ATLAS
	shade.color = SHADOW_COLOR
	shade.z_index = SHADOW_Z
	shade.set_meta(&"city_sun_shadow", true)
	add_child(shade)


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
