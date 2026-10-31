extends Node
## Renders the actual ground of a production district plan to a PNG cell map,
## coloured by DistrictGroundPolicy presentation role, so yard, court, apron
## and care shapes can be attributed without a display (2026-10-31 yard
## support pass). Chunks are built exactly as the game streams them
## (_create_chunk: base, generation, floor stamps, then the presentation
## pass); every cell is read back from the ground splat right after its
## chunk is built.
##
## Run: <godot> --headless res://tools/dev/CityGroundRoleMapProbe.tscn -- --segment=9
##   [--world-seed=16102026] [--theme=outer_wall] [--chunks=-2,-1;-1,-1] --out=/abs/dir
##
## Map colours follow ground_splat's debug_view 1: navy = road role (kerbed
## carriageway, courts 8), cyan = lane (aprons, passages), yellow = footway
## and floors, light grey = district yard (urban 6), green = lawn, brown =
## soil. Household care is a bright green inset scaled by its amount; court
## cells released to the yard by their use support are a white inset;
## buildings are dark brick, walls black, doors magenta, chunk seams red.
## Each floor stamp of the paved kinds is outlined in its own z colour.
##
## Census (stdout CITY_GROUND_ROLE_MAP json; also <out>/ground-roles-*.json):
## per floor-stamp kind (index and z) the stamp count, cells, and how many
## stamps are a full rectangle of four or more rows/columns; care pockets by
## bounding-box fill.

const COVER_FULL := preload("res://scenes/world/cover/CoverFull.tscn")
const COVER_WINDOW := preload("res://scenes/world/cover/CoverWindow.tscn")
const COVER_HALF := preload("res://scenes/world/cover/CoverHalf.tscn")
const _POLICY := preload("res://core/systems/world/ground/DistrictGroundPolicy.gd")
const CPC := 32
const PX := 6

const ROLE_COLORS := {
	0: Color(1.0, 0.0, 1.0),
	1: Color(0.15, 0.2, 0.55),
	2: Color(0.2, 0.75, 0.8),
	3: Color(0.95, 0.85, 0.3),
	4: Color(0.75, 0.75, 0.75),
	5: Color(0.2, 0.6, 0.2),
	6: Color(0.5, 0.33, 0.2),
}

var _segment := 9
var _seed := 16102026
var _theme_id := ""
var _only: Array[Vector2i] = []
var _out_dir := "/tmp"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--segment="): _segment = maxi(2, int(arg.trim_prefix("--segment=")))
		elif arg.begins_with("--world-seed="): _seed = int(arg.trim_prefix("--world-seed="))
		elif arg.begins_with("--theme="): _theme_id = arg.trim_prefix("--theme=")
		elif arg.begins_with("--out="): _out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--chunks="):
			for pair: String in arg.trim_prefix("--chunks=").split(";", false):
				var xy := pair.split(",")
				_only.append(Vector2i(int(xy[0]), int(xy[1])))
	call_deferred(&"_run")


func _manager(theme: SegmentThemeData, plan: Dictionary) -> ChunkManager:
	var cm := ChunkManager.new()
	theme.apply_to_chunk_manager(cm)
	cm.generation_enabled = false
	cm.ground_enabled = true
	cm.ground_splat_enabled = true
	cm.decals_enabled = false
	cm.deco_enabled = false
	cm.sites_enabled = false
	# SegmentProcBuilder._apply_urban_slice_defaults
	cm.parcels_chunk_chance = 0.95
	cm.parcels_chance_per_side = 0.80
	cm.parcels_max_per_side = 2
	cm.district_sidewalk_width_cells = 1
	cm.district_sidewalk_corner_pad_cells = 1
	cm.cover_full_scene = COVER_FULL
	cm.cover_window_scene = COVER_WINDOW
	cm.cover_half_scene = COVER_HALF
	add_child(cm)
	cm.set_process(false)
	cm.configure_procedural_world(int(plan.seed), plan.connectors_by_chunk, plan.urban_access_by_chunk, plan.role_by_chunk, plan.terrain_by_chunk, plan.archetype_by_chunk)
	return cm


func _run() -> void:
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	var seed_value := _seed
	if not _theme_id.is_empty():
		var found := false
		for step: int in 400:
			if String(SegmentThemePicker.get_theme(_segment, _seed + step).id) == _theme_id:
				seed_value = _seed + step
				found = true
				break
		if not found:
			push_error("CityGroundRoleMapProbe: no seed selects theme %s for segment %d" % [_theme_id, _segment])
			get_tree().quit(1)
			return
	Global.attempt_segment = _segment
	var theme := SegmentThemePicker.get_theme(_segment, seed_value)
	var plan := DistrictPlan.generate(_segment, seed_value, 2048, theme)
	var cm := _manager(theme, plan)
	var coords: Array[Vector2i] = []
	for coord: Vector2i in plan.role_by_chunk:
		if _only.is_empty() or _only.has(coord):
			coords.append(coord)
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := -lo
	for coord in coords:
		lo = Vector2i(mini(lo.x, coord.x), mini(lo.y, coord.y))
		hi = Vector2i(maxi(hi.x, coord.x), maxi(hi.y, coord.y))
	var span := hi - lo + Vector2i.ONE
	var image := Image.create(span.x * CPC * PX, span.y * CPC * PX, false, Image.FORMAT_RGB8)
	image.fill(Color(0.08, 0.10, 0.08))
	var stamp_kinds := {}
	var care_pockets: Array = []
	var chunk_roles := {}
	for coord in coords:
		var chunk: Node2D = cm._create_chunk(coord)
		cm._chunks[coord] = chunk
		var splat: GroundSplatRenderer = cm.get_ground_splat()
		var data := cm.get_chunk_build_data(coord)
		var origin := (coord - lo) * CPC
		var base := coord * CPC
		chunk_roles[str(coord)] = [String(plan.role_by_chunk.get(coord, &"")), String(plan.archetype_by_chunk.get(coord, &""))]
		var care_cells := {}
		for y in CPC:
			for x in CPC:
				var cell := base + Vector2i(x, y)
				var role := _POLICY.role_for_index(splat.material_at(cell))
				_fill(image, (origin.x + x) * PX, (origin.y + y) * PX, PX, PX, ROLE_COLORS.get(role, Color.MAGENTA))
				var support: float = splat.call(&"support_at", cell) if splat.has_method(&"support_at") else 1.0
				if support < 0.5:
					var inset := maxi(2, int(round(PX * (1.0 - support))))
					_fill(image, (origin.x + x) * PX + (PX - inset) / 2, (origin.y + y) * PX + (PX - inset) / 2, inset, inset, Color(1, 1, 1))
				var care := splat.care_at(cell)
				if care > 0.0:
					care_cells[Vector2i(x, y)] = care
					var size := maxi(1, int(round((PX - 2) * care)))
					_fill(image, (origin.x + x) * PX + 1, (origin.y + y) * PX + 1, size, size, Color(0.35, 1.0, 0.25))
		for pocket: Dictionary in _components(care_cells):
			care_pockets.append({"coord": [coord.x, coord.y], "cells": pocket.cells, "box": [pocket.box.size.x, pocket.box.size.y], "fill": snappedf(float(pocket.cells) / float(pocket.box.get_area()), 0.01)})
		for kit: Node in chunk.get_children():
			if not kit.is_in_group(&"city_block_building"):
				continue
			var bounds: Rect2 = kit.get("bounds")
			var rect := Rect2i(Vector2i((bounds.position / 64.0).round()), Vector2i((bounds.size / 64.0).round()))
			_shade(image, (origin.x + rect.position.x) * PX, (origin.y + rect.position.y) * PX, rect.size.x * PX, rect.size.y * PX, Color(0.40, 0.18, 0.13), 0.75)
		for index in data.occupied_indices():
			var cell := data.cell_for_index(index)
			_fill(image, (origin.x + cell.x) * PX, (origin.y + cell.y) * PX, PX, PX, Color(0.05, 0.04, 0.04))
		for child: Node in chunk.get_children():
			if child is Marker2D and StringName(child.get_meta(&"spawn_socket_kind", &"")) == &"door":
				var cell := Vector2i(((child as Node2D).position / 64.0).floor())
				_fill(image, (origin.x + cell.x) * PX + 1, (origin.y + cell.y) * PX + 1, PX - 2, PX - 2, Color(0.95, 0.15, 0.85))
		var packed := data.floor_rect_and_style
		for i in data.floor_stamp_count():
			var o := i * 6
			var index: int = packed[o + 4]
			if not _POLICY.is_paved_role(_POLICY.role_for_index(index)) or data.floor_alpha[i] < 0.5:
				continue
			var rect := Rect2i(packed[o], packed[o + 1], packed[o + 2], packed[o + 3])
			var key := "%d@%d" % [index, packed[o + 5]]
			var entry: Dictionary = stamp_kinds.get(key, {"index": index, "z": packed[o + 5], "stamps": 0, "cells": 0, "broad": 0, "largest": [0, 0]})
			entry.stamps += 1
			entry.cells += rect.get_area()
			if rect.size.x >= 4 and rect.size.y >= 4:
				entry.broad += 1
				_outline(image, (origin.x + rect.position.x) * PX, (origin.y + rect.position.y) * PX, rect.size.x * PX, rect.size.y * PX, _z_color(packed[o + 5]))
			if rect.get_area() > entry.largest[0] * entry.largest[1]:
				entry.largest = [rect.size.x, rect.size.y]
			stamp_kinds[key] = entry
	for x in range(1, span.x):
		_fill(image, x * CPC * PX, 0, 1, image.get_height(), Color(0.7, 0.15, 0.15))
	for y in range(1, span.y):
		_fill(image, 0, y * CPC * PX, image.get_width(), 1, Color(0.7, 0.15, 0.15))
	var stats := {
		"segment": _segment, "theme": String(theme.id), "district_family": String(theme.district_family),
		"attempt_seed": seed_value, "plan_seed": int(plan.seed), "chunks": coords.size(), "origin_chunk": [lo.x, lo.y],
		"chunk_roles": chunk_roles, "stamp_kinds": stamp_kinds, "care_pockets": care_pockets.size(),
		"square_care_pockets": care_pockets.filter(func(p: Dictionary) -> bool: return p.fill >= 0.99 and p.cells >= 4).size(),
		"care": care_pockets,
	}
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var stem := "%s/ground-roles-seg%d-%s" % [_out_dir, _segment, String(theme.id)]
	var err := image.save_png(stem + ".png")
	var file := FileAccess.open(stem + ".json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(stats, "  "))
		file.close()
	print("CITY_GROUND_ROLE_MAP ", JSON.stringify(stats))
	print("CityGroundRoleMapProbe: seg=%d theme=%s chunks=%d origin=%s -> %s.png (%s)" % [_segment, theme.id, coords.size(), lo, stem, error_string(err)])
	cm.free()
	player.free()
	get_tree().quit(0 if err == OK else 1)


## 4-connected components of a cell set: cell count and bounding box.
func _components(cells: Dictionary) -> Array[Dictionary]:
	var seen := {}
	var result: Array[Dictionary] = []
	for start: Vector2i in cells:
		if seen.has(start):
			continue
		var stack: Array[Vector2i] = [start]
		seen[start] = true
		var box := Rect2i(start, Vector2i.ONE)
		var count := 0
		while not stack.is_empty():
			var cell: Vector2i = stack.pop_back()
			count += 1
			box = box.merge(Rect2i(cell, Vector2i.ONE))
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = cell + step
				if cells.has(next) and not seen.has(next):
					seen[next] = true
					stack.append(next)
		result.append({"cells": count, "box": box})
	return result


static func _z_color(z: int) -> Color:
	var hue := fposmod(float(z) * 0.137, 1.0)
	return Color.from_hsv(hue, 0.9, 1.0)


static func _fill(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	var rect := Rect2i(x, y, w, h).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if rect.has_area():
		image.fill_rect(rect, color)


static func _shade(image: Image, x: int, y: int, w: int, h: int, color: Color, amount: float) -> void:
	var rect := Rect2i(x, y, w, h).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for py in range(rect.position.y, rect.end.y):
		for px in range(rect.position.x, rect.end.x):
			image.set_pixel(px, py, image.get_pixel(px, py).lerp(color, amount))


static func _outline(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	_fill(image, x, y, w, 1, color)
	_fill(image, x, y + h - 1, w, 1, color)
	_fill(image, x, y, 1, h, color)
	_fill(image, x + w - 1, y, 1, h, color)
