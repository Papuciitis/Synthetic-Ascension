extends Node
## Renders every planned chunk of an actual production district plan to a PNG
## cell map and prints street-relationship statistics, so layout changes can
## be judged against the plates without a display (2026-10-21 street pass).
##
## Run: <godot> --headless res://tools/dev/CityPlanMapProbe.tscn -- --segment=2
##   [--world-seed=16102026] [--theme=canal_services] [--continuity=on|off]
##   [--deco=0|1] --out=/abs/dir
## --theme scans seeds upward from --world-seed until the picker selects it,
## exactly like tools/dev/CitySegmentSurvey.
##
## Map colours: dark green = outside the district plan (wild terrain), olive =
## planned chunk ground, grey = floor stamps (lanes, paving, plazas; brighter
## for plazas), black = walls, blue = windows, orange = half cover, brick =
## original buildings, ochre = infill buildings, cyan = doors, magenta =
## recorded frontage passages. Chunk seams are drawn faint red.
##
## Statistics (stdout, CITY_PLAN_MAP json; also <out>/plan-map-*.json):
## - buildings, infill and attached groups (rects sharing >= 2 cells of wall,
##   across seams), isolated buildings (no other building within one cell);
## - frontage setbacks: per lane side, the distance from the lane edge to the
##   first building cell within 6 cells, the share of built columns whose
##   setback differs from the previous built column, and the values seen;
## - plazas: per plaza chunk its cell count, bounding box and fill ratio
##   (an octagon fills about 0.8 of its box, a square 1.0);
## - open land: unbuilt share of planned chunks next to unplanned ones (edge)
##   and of the others (core).

const COVER_FULL := preload("res://scenes/world/cover/CoverFull.tscn")
const COVER_WINDOW := preload("res://scenes/world/cover/CoverWindow.tscn")
const COVER_HALF := preload("res://scenes/world/cover/CoverHalf.tscn")
const DISTRICT := preload("res://core/systems/world/proc/chunkgen/ChunkGenDistrict.gd")
const CPC := 32
const PX := 3
const SETBACK_REACH := 6
## ChunkGenDistrict's semantic plaza roles.
const PLAZA_ROLES := [&"entry_court", &"landmark_plaza", &"wardstone_court", &"checkpoint", &"exploration_reward", &"primary_objective", &"miniboss_arena", &"boss_arena"]

var _segment := 2
var _seed := 16102026
var _theme_id := ""
var _continuity := true
var _deco := false
var _out_dir := "/tmp"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--segment="): _segment = maxi(2, int(arg.trim_prefix("--segment=")))
		elif arg.begins_with("--world-seed="): _seed = int(arg.trim_prefix("--world-seed="))
		elif arg.begins_with("--theme="): _theme_id = arg.trim_prefix("--theme=")
		elif arg.begins_with("--continuity="): _continuity = arg.trim_prefix("--continuity=") != "off"
		elif arg.begins_with("--deco="): _deco = arg.trim_prefix("--deco=") != "0"
		elif arg.begins_with("--out="): _out_dir = arg.trim_prefix("--out=")
	call_deferred(&"_run")


func _manager(theme: SegmentThemeData, plan: Dictionary) -> ChunkManager:
	var cm := ChunkManager.new()
	theme.apply_to_chunk_manager(cm)
	cm.world_seed = int(plan.seed)
	cm.generation_enabled = false
	# Floor stamps are recorded into the build data (no sprites, no splat).
	cm.ground_enabled = true
	cm.ground_splat_enabled = false
	cm.decals_enabled = false
	cm.deco_enabled = _deco
	cm.sites_enabled = false
	# SegmentProcBuilder._apply_urban_slice_defaults
	cm.parcels_chunk_chance = 0.95
	cm.parcels_chance_per_side = 0.80
	cm.parcels_max_per_side = 2
	cm.district_sidewalk_width_cells = 1
	cm.district_sidewalk_corner_pad_cells = 1
	cm.street_continuity_enabled = _continuity
	cm.cover_full_scene = COVER_FULL
	cm.cover_window_scene = COVER_WINDOW
	cm.cover_half_scene = COVER_HALF
	add_child(cm)
	cm._chunk_connectors = plan.connectors_by_chunk.duplicate()
	cm._chunk_role = plan.role_by_chunk.duplicate()
	cm._chunk_archetype = plan.archetype_by_chunk.duplicate()
	cm._chunk_urban_access = plan.urban_access_by_chunk.duplicate()
	cm._chunk_terrain = plan.terrain_by_chunk.duplicate()
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
			push_error("CityPlanMapProbe: no seed selects theme %s for segment %d" % [_theme_id, _segment])
			get_tree().quit(1)
			return
	Global.attempt_segment = _segment
	var theme := SegmentThemePicker.get_theme(_segment, seed_value)
	var plan := DistrictPlan.generate(_segment, seed_value, 2048, theme)
	var cm := _manager(theme, plan)
	var coords: Array[Vector2i] = []
	for coord: Vector2i in plan.role_by_chunk:
		coords.append(coord)
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := -lo
	for coord in coords:
		lo = Vector2i(mini(lo.x, coord.x), mini(lo.y, coord.y))
		hi = Vector2i(maxi(hi.x, coord.x), maxi(hi.y, coord.y))
	lo -= Vector2i.ONE
	hi += Vector2i.ONE
	var span := hi - lo + Vector2i.ONE
	var image := Image.create(span.x * CPC * PX, span.y * CPC * PX, false, Image.FORMAT_RGB8)
	image.fill(Color(0.13, 0.22, 0.12))
	var planned := {}
	for coord in coords:
		planned[coord] = true
	# Global cell -> 1 original building, 2 infill building.
	var building_cells := {}
	var buildings: Array[Dictionary] = []
	var blocked := {}
	var plaza_stats: Array = []
	var passages := 0
	var slit_cells := {}
	var slits := 0
	var lanes_by_coord := {}
	var identity := {}
	for coord in coords:
		cm._gen_coord = coord
		cm._chunk_blocked[coord] = []
		var data := ChunkBuildData.new(coord, CPC)
		cm._active_build_data = data
		var chunk := Node2D.new()
		chunk.position = Vector2(coord) * 2048
		cm.add_child(chunk)
		cm._generate_chunk(coord, chunk)
		cm._active_build_data = null
		var origin := (coord - lo) * CPC
		_fill(image, origin.x * PX, origin.y * PX, CPC * PX, CPC * PX, Color(0.30, 0.34, 0.22))
		var order: Array[int] = []
		for i in range(data.floor_stamp_count()):
			order.append(i)
		order.sort_custom(func(a: int, b: int) -> bool: return data.floor_rect_and_style[a * 6 + 5] < data.floor_rect_and_style[b * 6 + 5])
		for i in order:
			var o := i * 6
			var packed := data.floor_rect_and_style
			var z: int = packed[o + 5]
			var shade := 0.50 + 0.04 * float(packed[o + 4] % 5)
			var color := Color(shade, shade, shade * 0.97)
			if z >= -94:
				color = color.lightened(0.12)
			color = color.lerp(Color(0.30, 0.34, 0.22), clampf(1.0 - data.floor_alpha[i], 0.0, 1.0))
			_fill(image, (origin.x + packed[o]) * PX, (origin.y + packed[o + 1]) * PX, packed[o + 2] * PX, packed[o + 3] * PX, color)
		var plaza: Dictionary = chunk.get_meta(&"_proc_deco_clear_cells", {})
		var role := StringName(plan.role_by_chunk[coord])
		var archetype := StringName(plan.archetype_by_chunk.get(coord, &""))
		if not plaza.is_empty() and (role in PLAZA_ROLES or archetype in [&"plaza", &"arena", &"gate"]):
			var box := ChunkShapeGen.bounds_of(plaza)
			plaza_stats.append({"coord": [coord.x, coord.y], "role": String(role), "cells": plaza.size(), "box": [box.size.x, box.size.y],
				"fill": snappedf(float(plaza.size()) / float(maxi(1, box.size.x * box.size.y)), 0.01), "framed": chunk.has_meta(&"_proc_framed_square")})
		for kit: Node in chunk.get_children():
			if not kit.is_in_group(&"city_block_building"):
				continue
			var bounds: Rect2 = kit.get("bounds")
			var rect := Rect2i(Vector2i((bounds.position / 64.0).round()), Vector2i((bounds.size / 64.0).round()))
			var infill := bool(kit.get_meta(&"city_street_infill", false))
			var global_rect := Rect2i(coord * CPC + rect.position, rect.size)
			buildings.append({"rect": global_rect, "infill": infill, "coord": coord})
			for y in range(global_rect.position.y, global_rect.end.y):
				for x in range(global_rect.position.x, global_rect.end.x):
					building_cells[Vector2i(x, y)] = 2 if infill else 1
			_fill(image, (origin.x + rect.position.x) * PX, (origin.y + rect.position.y) * PX, rect.size.x * PX, rect.size.y * PX,
				Color(0.80, 0.58, 0.25) if infill else Color(0.66, 0.30, 0.20))
		for index in data.occupied_indices():
			var cell := data.cell_for_index(index)
			var kind := data.kind_at(cell)
			blocked[coord * CPC + cell] = true
			var color := Color(0.06, 0.05, 0.05)
			if kind == WorldBlockerGeometry.Kind.WINDOW:
				color = Color(0.25, 0.45, 0.95)
			elif kind == WorldBlockerGeometry.Kind.HALF_COVER:
				color = Color(0.95, 0.60, 0.20)
			_fill(image, (origin.x + cell.x) * PX, (origin.y + cell.y) * PX, PX, PX, color)
		for child: Node in chunk.get_children():
			if child is Marker2D and StringName(child.get_meta(&"spawn_socket_kind", &"")) == &"door":
				var cell := Vector2i(((child as Node2D).position / 64.0).floor())
				_fill(image, (origin.x + cell.x) * PX, (origin.y + cell.y) * PX, PX, PX, Color(0.2, 0.95, 0.95))
		for slit: Rect2i in chunk.get_meta(&"_proc_party_slits", []):
			slits += 1
			for y in range(slit.position.y, slit.end.y):
				slit_cells[coord * CPC + Vector2i(slit.position.x, y)] = true
		for passage: Rect2i in chunk.get_meta(&"_proc_frontage_passages", []):
			passages += 1
			_outline(image, (origin.x + passage.position.x) * PX, (origin.y + passage.position.y) * PX, passage.size.x * PX, passage.size.y * PX, Color(0.95, 0.2, 0.85))
		lanes_by_coord[coord] = _lanes(cm._content_gen, role, int(plan.connectors_by_chunk.get(coord, 0)), coord)
		identity[str(coord)] = _identity(chunk, data, role)
		cm._unregister_chunk_cells(coord)
		chunk.free()
	for x in range(1, span.x):
		_fill(image, x * CPC * PX, 0, 1, image.get_height(), Color(0.55, 0.18, 0.18))
	for y in range(1, span.y):
		_fill(image, 0, y * CPC * PX, image.get_width(), 1, Color(0.55, 0.18, 0.18))
	var stats := _stats(coords, planned, buildings, building_cells, lanes_by_coord, slit_cells)
	stats["party_slits"] = slits
	stats["segment"] = _segment
	stats["theme"] = String(theme.id)
	stats["plan_seed"] = int(plan.seed)
	stats["attempt_seed"] = seed_value
	stats["continuity"] = _continuity
	stats["deco"] = _deco
	stats["chunks"] = coords.size()
	stats["passages"] = passages
	stats["plazas"] = plaza_stats
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var stem := "%s/plan-map-seg%d-%s-%s" % [_out_dir, _segment, String(theme.id), "on" if _continuity else "off"]
	var err := image.save_png(stem + ".png")
	var file := FileAccess.open(stem + ".json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(stats, "  "))
		file.close()
	var identity_file := FileAccess.open(stem + "-identity.json", FileAccess.WRITE)
	if identity_file != null:
		identity_file.store_string(JSON.stringify(identity, " ", true))
		identity_file.close()
	print("CITY_PLAN_MAP ", JSON.stringify(stats))
	print("CityPlanMapProbe: seg=%d theme=%s chunks=%d -> %s.png (%s)" % [_segment, theme.id, coords.size(), stem, error_string(err)])
	cm.free()
	player.free()
	get_tree().quit(0 if err == OK else 1)


## Gameplay identity of one generated chunk: interiors (building id, rect,
## loot, security, objective, infill, exploration visit), loot spawners,
## spawn sockets, door markers, protected route cells and boss courts.
func _identity(chunk: Node2D, data: ChunkBuildData, role: StringName) -> Dictionary:
	var volumes: Array = []
	var loot: Array = []
	var sockets: Array = []
	var doors: Array = []
	for child: Node in chunk.get_children():
		if child is IndoorVolume:
			var volume := child as IndoorVolume
			var visit: Variant = volume.get(&"visit_counts_as_exploration")
			volumes.append([volume.building_id, [volume.cell_tl.x, volume.cell_tl.y], [volume.size_cells.x, volume.size_cells.y], volume.small_loot_chance,
				volume.exploration_loot_enabled, volume.local_encounter_enabled, volume.local_encounter_count, volume.secondary_objective_id,
				volume.has_meta(&"city_street_infill"), true if visit == null else bool(visit)])
		elif child is ExplorationLootSpawner:
			var spawner := child as ExplorationLootSpawner
			loot.append([spawner.loot_id, spawner.secondary_objective_id, [snappedf(spawner.position.x, 0.01), snappedf(spawner.position.y, 0.01)]])
		elif child is Marker2D:
			var kind := String(child.get_meta(&"spawn_socket_kind", &""))
			var position := [snappedf((child as Node2D).position.x, 0.01), snappedf((child as Node2D).position.y, 0.01)]
			if child.is_in_group(&"enemy_spawn_socket"):
				sockets.append([kind, position])
			if kind == "door":
				var dir: Variant = child.get_meta(&"door_dir") if child.has_meta(&"door_dir") else null
				doors.append([position, [dir.x, dir.y] if dir is Vector2i else null, child.is_in_group(&"enemy_spawn_socket")])
	volumes.sort()
	loot.sort()
	sockets.sort()
	doors.sort()
	var clear: Array = []
	for cell: Vector2i in chunk.get_meta(&"_proc_clear_cells", {}):
		clear.append(cell.y * CPC + cell.x)
	clear.sort()
	var blocked_clear := 0
	for index: int in clear:
		if data.kind_at(Vector2i(index % CPC, int(index / float(CPC)))) >= 0:
			blocked_clear += 1
	var boss: Variant = chunk.get_meta(&"_boss_arena_clear_rect") if chunk.has_meta(&"_boss_arena_clear_rect") else null
	return {"role": String(role), "volumes": volumes, "loot": loot, "sockets": sockets, "doors": doors,
		"clear_cells": clear, "blocked_clear_cells": blocked_clear,
		"boss_court": [boss.position.x, boss.position.y, boss.size.x, boss.size.y] if boss is Rect2i else null}


## Lane contract rects of a planned chunk (ChunkGenDistrict's lane geometry).
func _lanes(gen: ChunkGenImpl, role: StringName, mask: int, coord: Vector2i) -> Array[Rect2i]:
	var lane_w := 7
	match role:
		&"secondary_route": lane_w = 5
		&"service_lane", &"secondary_reward_building": lane_w = 3
		&"dangerous_alley", &"secondary_alley_cache": lane_w = 2
		&"checkpoint", &"exit_approach", &"gate": lane_w = 7
		&"primary_objective": lane_w = 6
		_: lane_w = DISTRICT._remapped_lane_width(gen.district_lane_width_cells)
	lane_w = clampi(lane_w, 2, CPC - 6)
	var y0 := clampi(gen._lane_center_for_row(coord.y, CPC) - int(lane_w / 2.0), 1, CPC - lane_w - 1)
	var x0 := clampi(gen._lane_center_for_col(coord.x, CPC) - int(lane_w / 2.0), 1, CPC - lane_w - 1)
	var lanes: Array[Rect2i] = [Rect2i(), Rect2i()]
	if mask & (2 | 8):
		var from := 0 if mask & 8 else x0
		var to := CPC if mask & 2 else x0 + lane_w
		lanes[0] = Rect2i(from, y0, to - from, lane_w)
	if mask & (1 | 4):
		var from := 0 if mask & 1 else y0
		var to := CPC if mask & 4 else y0 + lane_w
		lanes[1] = Rect2i(x0, from, lane_w, to - from)
	return lanes


func _stats(coords: Array[Vector2i], planned: Dictionary, buildings: Array[Dictionary], building_cells: Dictionary, lanes_by_coord: Dictionary, slit_cells: Dictionary) -> Dictionary:
	# Attached groups: union-find over rects sharing at least two cells of wall,
	# or standing one cell apart across a closed party slit.
	var parent: Array[int] = []
	for i in buildings.size():
		parent.append(i)
	var find := func(i: int) -> int:
		var at := i
		while parent[at] != at:
			at = parent[at]
		return at
	var isolated := 0
	var infill := 0
	for i in buildings.size():
		var a: Rect2i = buildings[i].rect
		if buildings[i].infill:
			infill += 1
		var near := false
		for j in buildings.size():
			if i == j:
				continue
			var b: Rect2i = buildings[j].rect
			if a.grow(1).intersects(b):
				near = true
			var shared := 0
			if a.end.x == b.position.x or b.end.x == a.position.x:
				shared = mini(a.end.y, b.end.y) - maxi(a.position.y, b.position.y)
			elif a.end.y == b.position.y or b.end.y == a.position.y:
				shared = mini(a.end.x, b.end.x) - maxi(a.position.x, b.position.x)
			if shared < 2 and a.end.x + 1 == b.position.x and slit_cells.has(Vector2i(a.end.x, maxi(a.position.y, b.position.y))):
				shared = 2
			if shared >= 2 and not a.intersects(b):
				var ra: int = find.call(i)
				var rb: int = find.call(j)
				if ra != rb:
					parent[ra] = rb
		if not near:
			isolated += 1
	var groups := {}
	for i in buildings.size():
		var root: int = find.call(i)
		groups[root] = int(groups.get(root, 0)) + 1
	var group_sizes: Array = groups.values()
	var free_standing := 0
	for i in buildings.size():
		if int(groups[find.call(i)]) == 1:
			free_standing += 1
	group_sizes.sort()
	# Corner-turning groups: a group whose members' rects are not all on one
	# row/column band, i.e. its union is not a straight strip.
	var corner_groups := 0
	var members := {}
	for i in buildings.size():
		var root: int = find.call(i)
		var list: Array = members.get(root, [])
		list.append(buildings[i].rect)
		members[root] = list
	for root: int in members:
		var list: Array = members[root]
		if list.size() < 2:
			continue
		var share_row := true
		var share_col := true
		var first: Rect2i = list[0]
		for rect: Rect2i in list:
			if rect.position.y != first.position.y and rect.end.y != first.end.y:
				share_row = false
			if rect.position.x != first.position.x and rect.end.x != first.end.x:
				share_col = false
		if not share_row and not share_col:
			corner_groups += 1
	# Frontage setbacks beside every lane side.
	var built_columns := 0
	var setback_steps := 0
	var setback_values := {}
	for coord: Vector2i in coords:
		var lanes: Array = lanes_by_coord[coord]
		for axis in 2:
			var lane: Rect2i = lanes[axis]
			if not lane.has_area():
				continue
			for side in [-1, 1]:
				var previous := -1
				var along := range(lane.position.x, lane.end.x) if axis == 0 else range(lane.position.y, lane.end.y)
				for t: int in along:
					var setback := -1
					for depth in range(0, SETBACK_REACH):
						var local := Vector2i(t, lane.position.y - 1 - depth if side < 0 else lane.end.y + depth) if axis == 0 else Vector2i(lane.position.x - 1 - depth if side < 0 else lane.end.x + depth, t)
						if building_cells.has(coord * CPC + local):
							setback = depth
							break
					if setback < 0:
						previous = -1
						continue
					built_columns += 1
					setback_values[setback] = int(setback_values.get(setback, 0)) + 1
					if previous >= 0 and previous != setback:
						setback_steps += 1
					previous = setback
	# Open land: unbuilt share of edge chunks (beside an unplanned chunk) and core chunks.
	var edge_cells := 0
	var edge_built := 0
	var core_cells := 0
	var core_built := 0
	for coord: Vector2i in coords:
		var edge := false
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not planned.has(coord + dir):
				edge = true
		var built := 0
		for y in CPC:
			for x in CPC:
				if building_cells.has(coord * CPC + Vector2i(x, y)):
					built += 1
		if edge:
			edge_cells += CPC * CPC
			edge_built += built
		else:
			core_cells += CPC * CPC
			core_built += built
	var keys: Array = setback_values.keys()
	keys.sort()
	var setback_hist := {}
	for key: int in keys:
		setback_hist[str(key)] = setback_values[key]
	return {
		"buildings": buildings.size(), "infill": infill, "isolated": isolated, "free_standing": free_standing,
		"groups": group_sizes.size(), "groups_of_3_plus": group_sizes.filter(func(n: int) -> bool: return n >= 3).size(),
		"largest_group": group_sizes.back() if not group_sizes.is_empty() else 0, "corner_groups": corner_groups,
		"frontage_columns": built_columns, "setback_step_share": snappedf(float(setback_steps) / float(maxi(1, built_columns)), 0.001),
		"setbacks": setback_hist,
		"edge_open_share": snappedf(1.0 - float(edge_built) / float(maxi(1, edge_cells)), 0.001),
		"core_open_share": snappedf(1.0 - float(core_built) / float(maxi(1, core_cells)), 0.001),
	}


func _fill(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	image.fill_rect(Rect2i(x, y, w, h).intersection(Rect2i(0, 0, image.get_width(), image.get_height())), color)


func _outline(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	_fill(image, x, y, w, 1, color)
	_fill(image, x, y + h - 1, w, 1, color)
	_fill(image, x, y, 1, h, color)
	_fill(image, x + w - 1, y, 1, h, color)
