extends Node2D
class_name RoofOverlay

## Three-quarter walls give a building its mass now, so the roof is a shade
## over the interior rather than a dark slab (was 0.62).
@export_range(0.0, 1.0, 0.01) var outside_alpha: float = 0.3
@export_range(0.0, 1.0, 0.01) var inside_alpha: float = 0.0
@export_range(0.05, 1.0, 0.01) var fade_time: float = 0.18
@export_range(0.0, 24.0, 1.0) var overhang_px: float = 8.0
@export_range(0.0, 12.0, 1.0) var front_edge_width_px: float = 6.0

## Textured roofs (2026-09-27 building pass, with the three-quarter walls):
## the design notes treat buildings as "large top-down obstacles" - a real
## roof over the whole footprint that fades away when the player walks in.
## It sits at wall-top height (lifted KIT_HEIGHT) and covers the walls' tops
## out to a small eave, so only the south façade's face shows below it (a
## roof framed inside the walls read as "a box with tiles in it"). Drawn
## above the walls, below the actors.
## User art (docs/art/2026-09-27-building-art.md R1-R4; originals in
## incoming/world/), cropped to their repeat period so they tile.
const ROOF_SLATE := preload("res://assets/world/roofs/roof_slate.png")
const ROOF_CLAY := preload("res://assets/world/roofs/roof_clay.png")
const ROOF_LEAD := preload("res://assets/world/roofs/roof_lead.png")
const ROOF_DAMAGE_SLATE := preload("res://assets/world/roofs/roof_damage_a.png")
const ROOF_DAMAGE_CLAY := preload("res://assets/world/roofs/roof_damage_b.png")
const ROOF_DAMAGE_MIXED := preload("res://assets/world/roofs/roof_damage_c.png")
## Share of slate and clay roofs that have fallen in somewhere.
const ROOF_DAMAGE_CHANCE := 0.35
## The damage sprites are stored at 2x.
const ROOF_DAMAGE_SCALE := 0.5
const ROOF_Z := -1
const ROOF_SHADER := preload("res://scenes/world/buildings/roof.gdshader")
## Texels per world pixel of the roof art (512 texels span 320 px, a slate
## row about 27 px).
const ROOF_TEXEL_SCALE := 1.6
## From the footprint's cell edge to the roof edge: the wall band's outer
## face is 16 px in (a 32 px band through the cell centre), and the eave
## overhangs it by 6 px.
const ROOF_INSET_PX := 10.0
## Depth of the eave's shadow on the façade below it.
const EAVE_SHADOW_PX := 9.0

@onready var _poly: Polygon2D = get_node("RoofPoly") as Polygon2D
@onready var _edge: Line2D = get_node("FrontEdge") as Line2D

var _inside_count: int = 0
## Entrances as {pos: chunk-local cell, dir: outward, width: cells}, the same
## records the facility carver cuts doors from. The roof is notched over each
## so a doorway reads from the street.
var _doors: Array = []
var _cell_px: int = 64
## The footprint outline this roof was configured with (before insets and
## door notches), in chunk-local pixels. Tests read the building's shape here.
var footprint_outline_px := PackedVector2Array()
var _tween: Tween


func configure(build_rect_cells: Rect2i, cell_size_px: int, door_dir: Vector2i, indoor_volume: Area2D, building_kind: StringName = &"row_house", visual_seed: int = 0, doors: Array = []) -> void:
	_doors = doors
	_cell_px = cell_size_px
	_apply_visual_variant(building_kind, visual_seed)
	# Build a simple roof silhouette that makes parcels read as "buildings" from the street.
	# This is intentionally cheap: just a dark polygon + a stronger façade edge.
	var tl := Vector2(build_rect_cells.position) * float(cell_size_px)
	var sz := Vector2(build_rect_cells.size) * float(cell_size_px)
	var o := float(overhang_px)

	# Slightly inset on the street-facing side so the door apron remains readable.
	var inset := float(maxi(0, int(front_edge_width_px / 2.0)))
	var in_n := 0.0
	var in_e := 0.0
	var in_s := 0.0
	var in_w := 0.0
	if door_dir == Vector2i(0, -1):
		in_n = inset
	elif door_dir == Vector2i(1, 0):
		in_e = inset
	elif door_dir == Vector2i(0, 1):
		in_s = inset
	elif door_dir == Vector2i(-1, 0):
		in_w = inset

	var p0 := tl + Vector2(-o + in_w, -o + in_n)
	var p1 := tl + Vector2(sz.x + o - in_e, -o + in_n)
	var p2 := tl + Vector2(sz.x + o - in_e, sz.y + o - in_s)
	var p3 := tl + Vector2(-o + in_w, sz.y + o - in_s)

	_poly.polygon = PackedVector2Array([p0, p1, p2, p3])
	_poly.z_index = -92
	footprint_outline_px = PackedVector2Array([tl, tl + Vector2(sz.x, 0.0), tl + sz, tl + Vector2(0.0, sz.y)])
	if textured_roofs():
		var inner := Rect2(tl, sz).grow(-ROOF_INSET_PX)
		_poly.polygon = PackedVector2Array([
			inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y),
		])
		_frame_textured_roof()

	# Strong front edge (façade line) along the street-facing side.
	_edge.clear_points()
	_edge.width = front_edge_width_px
	_edge.z_index = -91
	_edge.antialiased = true

	if door_dir == Vector2i(0, -1):
		_edge.add_point(p0)
		_edge.add_point(p1)
	elif door_dir == Vector2i(1, 0):
		_edge.add_point(p1)
		_edge.add_point(p2)
	elif door_dir == Vector2i(0, 1):
		_edge.add_point(p2)
		_edge.add_point(p3)
	else: # W
		_edge.add_point(p3)
		_edge.add_point(p0)

	_set_alpha(effective_outside_alpha())

	# Fade roof when the player enters the indoor volume.
	if indoor_volume != null:
		if not indoor_volume.body_entered.is_connected(_on_volume_body_entered):
			indoor_volume.body_entered.connect(_on_volume_body_entered)
		if not indoor_volume.body_exited.is_connected(_on_volume_body_exited):
			indoor_volume.body_exited.connect(_on_volume_body_exited)


## An irregular footprint's roof (Phase 3): the polygon is the footprint's
## authored outline; the façade edge runs along the given street-side span;
## fades listen to every sub-volume of the building through one counter, so
## crossing between overlapping volumes never flickers.
func configure_polygon(outline_px: PackedVector2Array, facade_from: Vector2, facade_to: Vector2, volumes: Array, building_kind: StringName = &"row_house", visual_seed: int = 0, doors: Array = [], cell_size_px: int = 64) -> void:
	_doors = doors
	_cell_px = cell_size_px
	_apply_visual_variant(building_kind, visual_seed)
	_poly.polygon = outline_px
	_poly.z_index = -92
	footprint_outline_px = outline_px
	if textured_roofs():
		_poly.polygon = _inset_outline(outline_px, ROOF_INSET_PX)
		_frame_textured_roof()
	_edge.clear_points()
	_edge.width = front_edge_width_px
	_edge.z_index = -91
	_edge.antialiased = true
	_edge.add_point(facade_from)
	_edge.add_point(facade_to)
	_set_alpha(effective_outside_alpha())
	for volume_variant in volumes:
		var volume := volume_variant as Area2D
		if volume == null:
			continue
		if not volume.body_entered.is_connected(_on_volume_body_entered):
			volume.body_entered.connect(_on_volume_body_entered)
		if not volume.body_exited.is_connected(_on_volume_body_exited):
			volume.body_exited.connect(_on_volume_body_exited)


## Shops read as clay, workshops and stores as lead, houses slate or clay.
static func _roof_texture_for(building_kind: StringName, rng: RandomNumberGenerator) -> Texture2D:
	var roll := rng.randf()
	match building_kind:
		&"shop":
			return ROOF_CLAY if roll < 0.7 else ROOF_SLATE
		&"workshop":
			return ROOF_LEAD if roll < 0.7 else ROOF_SLATE
		&"passage":
			return ROOF_SLATE
	return ROOF_SLATE if roll < 0.55 else ROOF_CLAY


static func textured_roofs() -> bool:
	return ChunkBlockVisualCatalog.three_quarter_walls


## Outside alpha: textured roofs are solid (the walls frame them); the legacy
## dark shade keeps its exported value.
func effective_outside_alpha() -> float:
	return 1.0 if textured_roofs() else outside_alpha


func _frame_textured_roof() -> void:
	_poly.position = Vector2(0.0, -ChunkBlockVisualCatalog.KIT_HEIGHT)
	_poly.z_index = ROOF_Z
	_edge.visible = false
	# A gable for four-cornered roofs (ridge along the long side), eaves only
	# for anything else.
	var poly := _poly.polygon
	var box := Rect2(poly[0], Vector2.ZERO) if poly.size() > 0 else Rect2()
	for p in poly:
		box = box.expand(p)
	var roof_material := ShaderMaterial.new()
	roof_material.shader = ROOF_SHADER
	roof_material.set_shader_parameter("bounds", Vector4(box.position.x, box.position.y, box.end.x, box.end.y))
	roof_material.set_shader_parameter("ridge_along_x", 1.0 if box.size.x >= box.size.y else 0.0)
	# Outlines carry collinear points; what matters is whether the roof fills
	# its box (a rectangle) or not (an L or a notch).
	var fills_box := box.get_area() > 0.0 and absf(_signed_area(poly)) >= box.get_area() * 0.97
	roof_material.set_shader_parameter("gable", 1.0 if fills_box else 0.0)
	_poly.material = roof_material
	poly = _notch_doors(poly)
	_poly.polygon = poly
	_add_eave_shadow(poly)
	_add_roof_damage(poly, box, fills_box)


## Cut the roof back over each doorway (the door cells plus the eave in front
## of them), so entrances show from outside instead of hiding under tiles.
func _notch_doors(poly: PackedVector2Array) -> PackedVector2Array:
	var cell := float(_cell_px)
	for door_value in _doors:
		var door := door_value as Dictionary
		if door == null or not door.has("pos") or not door.has("dir"):
			continue
		var pos: Vector2i = door["pos"]
		var dir: Vector2i = door["dir"]
		var width: int = int(door.get("width", 2))
		var perp := Vector2i(-dir.y, dir.x)
		var first := pos + perp * -(width >> 1)
		var last := first + perp * (width - 1)
		var cells := Rect2(Vector2(first) * cell, Vector2.ONE * cell).merge(Rect2(Vector2(last) * cell, Vector2.ONE * cell))
		# Reach past the eave on the outside; stop at the door cell inside.
		var outward := Vector2(dir) * (ROOF_INSET_PX + 24.0)
		var notch := cells.merge(Rect2(cells.position + outward, cells.size))
		var cut := Geometry2D.clip_polygons(poly, PackedVector2Array([
			notch.position, Vector2(notch.end.x, notch.position.y), notch.end, Vector2(notch.position.x, notch.end.y),
		]))
		var best := PackedVector2Array()
		var best_area := 0.0
		for candidate in cut:
			var piece := candidate as PackedVector2Array
			if Geometry2D.is_polygon_clockwise(piece) != Geometry2D.is_polygon_clockwise(poly):
				continue  # a hole, not an outline
			var area := absf(_signed_area(piece))
			if area > best_area:
				best_area = area
				best = piece
		if best.size() >= 3:
			poly = best
	return poly


## A soft shadow the eave throws onto the façade: a gradient strip under
## every south-facing roof edge. A child of the roof, so it fades with it.
func _add_eave_shadow(poly: PackedVector2Array) -> void:
	var old := _poly.get_node_or_null("EaveShadow")
	if old != null:
		old.queue_free()
	if poly.size() < 3:
		return
	var clockwise := _signed_area(poly) > 0.0  # y-down screen space
	var shadow := Node2D.new()
	shadow.name = "EaveShadow"
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var edge := b - a
		if edge.length() < 1.0:
			continue
		var outward := Vector2(edge.y, -edge.x).normalized() if clockwise else Vector2(-edge.y, edge.x).normalized()
		if outward.y < 0.7:
			continue
		var strip := Polygon2D.new()
		strip.polygon = PackedVector2Array([a, b, b + Vector2(0.0, EAVE_SHADOW_PX), a + Vector2(0.0, EAVE_SHADOW_PX)])
		strip.vertex_colors = PackedColorArray([
			Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0),
		])
		shadow.add_child(strip)
	_poly.add_child(shadow)


## Now and then a roof has fallen in: a hole in the matching material, placed
## wholly inside the roof, shaded like the slope it sits on. A child of the
## roof, so it lifts and fades with it.
func _add_roof_damage(poly: PackedVector2Array, box: Rect2, gabled: bool) -> void:
	for child in _poly.get_children():
		if child.name.begins_with("RoofDamage"):
			child.queue_free()
	var damage: Texture2D = null
	if _poly.texture == ROOF_SLATE:
		damage = ROOF_DAMAGE_SLATE
	elif _poly.texture == ROOF_CLAY:
		damage = ROOF_DAMAGE_CLAY
	if damage == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(box.position.x * 92821.0 + box.position.y * 68917.0 + box.size.x * 31.0)
	if rng.randf() >= ROOF_DAMAGE_CHANCE:
		return
	if rng.randf() < 0.3:
		damage = ROOF_DAMAGE_MIXED
	var half := Vector2(damage.get_size()) * ROOF_DAMAGE_SCALE * 0.5
	var inner := box.grow_individual(-half.x - 12.0, -half.y - 12.0, -half.x - 12.0, -half.y - 12.0)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return
	for _attempt in range(6):
		var at := inner.position + Vector2(rng.randf() * inner.size.x, rng.randf() * inner.size.y)
		var corners := [at - half, at + Vector2(half.x, -half.y), at + half, at + Vector2(-half.x, half.y)]
		var inside := true
		for corner in corners:
			if not Geometry2D.is_point_in_polygon(corner, poly):
				inside = false
				break
		if not inside:
			continue
		var hole := Sprite2D.new()
		hole.name = "RoofDamage"
		hole.texture = damage
		hole.scale = Vector2.ONE * ROOF_DAMAGE_SCALE
		hole.position = at
		hole.rotation = rng.randf_range(-0.35, 0.35)
		hole.flip_h = rng.randf() < 0.5
		# Match the gable's shading (roof.gdshader): the slope toward the
		# top-right light is lit - north of an E-W ridge, east of a N-S one.
		var shade := 1.0
		if gabled:
			var along_x := box.size.x >= box.size.y
			var t := (at.y - box.position.y) / box.size.y if along_x else (at.x - box.position.x) / box.size.x
			var lit := t < 0.42 if along_x else t > 0.5
			shade = 1.12 if lit else 0.72
		hole.modulate = Color(shade, shade, shade, 1.0) * _poly.color
		_poly.add_child(hole)
		return


static func _inset_outline(outline: PackedVector2Array, inset: float) -> PackedVector2Array:
	if outline.size() < 3:
		return outline
	var shrunk := Geometry2D.offset_polygon(outline, -inset, Geometry2D.JOIN_MITER)
	var best := PackedVector2Array()
	var best_area := 0.0
	for candidate in shrunk:
		var poly := candidate as PackedVector2Array
		var area := absf(_signed_area(poly))
		if area > best_area:
			best_area = area
			best = poly
	return best if best.size() >= 3 else outline


static func _signed_area(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	return area * 0.5


func _apply_visual_variant(building_kind: StringName, visual_seed: int) -> void:
	var base := Color(0.13, 0.14, 0.15, 1.0)
	match building_kind:
		&"shop":
			base = Color(0.12, 0.15, 0.14, 1.0)
		&"workshop":
			base = Color(0.18, 0.14, 0.11, 1.0)
		&"passage":
			base = Color(0.11, 0.12, 0.16, 1.0)
		_:
			base = Color(0.14, 0.14, 0.13, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = visual_seed
	var variation: float = rng.randf_range(-0.018, 0.018)
	base.r = clampf(base.r + variation, 0.04, 0.30)
	base.g = clampf(base.g + variation, 0.04, 0.30)
	base.b = clampf(base.b + variation, 0.04, 0.30)
	_poly.color = base
	_edge.default_color = base.darkened(0.32)
	if textured_roofs():
		_poly.texture = _roof_texture_for(building_kind, rng)
		_poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_poly.texture_scale = Vector2.ONE * ROOF_TEXEL_SCALE
		_poly.texture_offset = Vector2(rng.randf_range(0.0, 512.0), rng.randf_range(0.0, 512.0))
		var shade := 0.9 + variation * 3.0
		_poly.color = Color(shade, shade, shade, 1.0)
		if _poly.texture == ROOF_CLAY:
			# The clay art is hotter than the muted world; pull it toward brick.
			_poly.color *= Color(0.86, 0.8, 0.78, 1.0)
	# The walls' own faces are the façade now; a second dark line above them
	# read as a smudge.
	_edge.visible = not ChunkBlockVisualCatalog.three_quarter_walls


func _on_volume_body_entered(body: Node) -> void:
	if body != null and body.is_in_group(&"player"):
		_inside_count += 1
		_update_target()


func _on_volume_body_exited(body: Node) -> void:
	if body != null and body.is_in_group(&"player"):
		_inside_count = maxi(0, _inside_count - 1)
		_update_target()


func _update_target() -> void:
	var target := (inside_alpha if _inside_count > 0 else effective_outside_alpha())
	_fade_to(target)


func _fade_to(a: float) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_alpha, _poly.modulate.a, a, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_alpha(a: float) -> void:
	var aa := clampf(a, 0.0, 1.0)
	_poly.modulate = Color(1, 1, 1, aa)
	# Slightly stronger façade edge
	_edge.modulate = Color(1, 1, 1, clampf(aa * 1.15, 0.0, 1.0))
