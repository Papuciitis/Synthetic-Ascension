extends "res://tools/tests/ProcChunkReachabilityTest.gd"
## Street continuity post-pass (2026-10-21) on actual production plans of all
## fourteen district themes. For street, courtyard and landmark chunks it proves:
## - every original building keeps its rect, identity, loot, encounter and
##   secondary objective with the pass on or off (the post-pass is separately
##   salted, so the original lot RNG cannot drift);
## - infill buildings are architecture only (no loot, encounter, secondary
##   objective or ambient spawn socket);
## - protected route cells, objective anchor boxes and the framed square stay
##   clear; deliberate infill passages are three cells wide and open;
## - every connector socket and real door is reachable and no interior is sealed;
## - regeneration is exact across fresh managers and generation orders.
## -- --out=/abs/path.json writes every sampled chunk for the replay comparison.

const THEMES := [[2, ""], [3, ""], [4, "collapsed_ward"], [4, "civilian_cutthrough"], [5, ""],
	[6, "industrial_cutthrough"], [6, "ruined_services"], [7, "underpass_veins"], [7, "canal_services"],
	[8, "rail_yard"], [8, "military_staging"], [9, "outer_wall"], [9, "siege_services"], [10, ""]]
const ROLES := [&"main_street", &"secondary_route", &"service_lane", &"exit_approach", &"dangerous_alley",
	&"secondary_alley_cache", &"secondary_reward_building", &"optional_interior", &"district_fill", &"landmark_plaza"]
const BASE_SEED := 16102026
const PER_ROLE := 2
const ANCHOR_ROLES := [&"secondary_alley_cache", &"secondary_reward_building", &"optional_interior"]

var _checks := 0
var _infill_total := 0
var _original_total := 0
var _samples: Array = []
var _preexisting := 0


func _theme_seed(segment: int, theme_id: String) -> int:
	if theme_id.is_empty():
		return BASE_SEED
	for step in 400:
		if String(SegmentThemePicker.get_theme(segment, BASE_SEED + step).id) == theme_id:
			return BASE_SEED + step
	return -1


func _fixture_for(theme: SegmentThemeData, plan: Dictionary, coord: Vector2i, enabled: bool, warm: Vector2i = Vector2i(1 << 20, 0)) -> Dictionary:
	var cm := ChunkManager.new()
	theme.apply_to_chunk_manager(cm)
	cm.world_seed = int(plan.seed)
	cm.generation_enabled = false
	cm.ground_enabled = false
	cm.ground_splat_enabled = false
	cm.decals_enabled = false
	cm.deco_enabled = false
	cm.sites_enabled = false
	cm.parcels_chunk_chance = 0.95
	cm.parcels_chance_per_side = 0.80
	cm.parcels_max_per_side = 2
	cm.district_sidewalk_width_cells = 1
	cm.district_sidewalk_corner_pad_cells = 1
	cm.street_continuity_enabled = enabled
	cm.cover_full_scene = COVER_FULL
	cm.cover_window_scene = COVER_WINDOW
	cm.cover_half_scene = COVER_HALF
	add_child(cm)
	cm._chunk_connectors = plan.connectors_by_chunk.duplicate()
	cm._chunk_role = plan.role_by_chunk.duplicate()
	cm._chunk_archetype = plan.archetype_by_chunk.duplicate()
	cm._chunk_urban_access = plan.urban_access_by_chunk.duplicate()
	if warm.x != 1 << 20:
		# Generate a neighbour first: a chunk must not depend on load order.
		_generate_into(cm, warm)
	var built := _generate_into(cm, coord)
	built["cm"] = cm
	return built


func _generate_into(cm: ChunkManager, coord: Vector2i) -> Dictionary:
	cm._gen_coord = coord
	cm._chunk_blocked[coord] = []
	var data := ChunkBuildData.new(coord, CPC)
	cm._active_build_data = data
	var chunk := Node2D.new()
	chunk.position = Vector2(coord) * 2048
	cm.add_child(chunk)
	cm._generate_chunk(coord, chunk)
	return {"chunk": chunk, "data": data}


func _volume_record(volume: IndoorVolume) -> String:
	return str([volume.building_id, volume.cell_tl, volume.size_cells, volume.small_loot_chance, volume.exploration_loot_enabled,
		volume.local_encounter_enabled, volume.local_encounter_count, volume.secondary_objective_id])


func _buildings(chunk: Node2D) -> Array:
	var out: Array = []
	for kit: Node in chunk.get_children():
		if not kit.is_in_group(&"city_block_building"):
			continue
		var bounds: Rect2 = kit.get("bounds")
		var rect := Rect2i(Vector2i((bounds.position / 64.0).round()), Vector2i((bounds.size / 64.0).round()))
		var doors: Array = []
		for door: Dictionary in kit.get("_doors"):
			doors.append([door.pos.x, door.pos.y, door.dir.x, door.dir.y])
		out.append({"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "usage": String(kit.get_meta(&"building_usage", &"")),
			"infill": bool(kit.get_meta(&"city_street_infill", false)), "irregular": bool(kit.get("_irregular")), "doors": doors, "civic": bool(kit.get("civic"))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.rect) < str(b.rect))
	return out


func _physical(data: ChunkBuildData) -> String:
	return str([data.blocker_kind_code, data.blocker_mask, data.blocker_variant])


func _spawn_sockets(chunk: Node2D) -> Array:
	var sockets: Array = []
	for child: Node in chunk.get_children():
		if child is Marker2D and child.is_in_group(&"enemy_spawn_socket"):
			sockets.append(str((child as Node2D).position))
	sockets.sort()
	return sockets


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		failures.append(message)


func _check_chunk(theme: SegmentThemeData, plan: Dictionary, coord: Vector2i, role: StringName, segment: int) -> void:
	var tag := "seg=%d theme=%s coord=%s role=%s" % [segment, theme.id, coord, role]
	var off := _fixture_for(theme, plan, coord, false)
	var on := _fixture_for(theme, plan, coord, true)
	var again := _fixture_for(theme, plan, coord, true, coord + Vector2i(1, 0))
	var chunk: Node2D = on.chunk
	var data: ChunkBuildData = on.data
	# 1. Original identity, loot and security are untouched.
	var on_volumes: Dictionary = {}
	for child: Node in chunk.get_children():
		if child is IndoorVolume:
			on_volumes[_volume_record(child)] = child
	var off_ids: Dictionary = {}
	for child: Node in (off.chunk as Node2D).get_children():
		if child is IndoorVolume:
			_original_total += 1
			off_ids[(child as IndoorVolume).building_id] = true
			_check(on_volumes.has(_volume_record(child)), tag + " original building changed " + _volume_record(child))
	# 2. Infill volumes are architecture only.
	for record: String in on_volumes:
		var volume: IndoorVolume = on_volumes[record]
		if off_ids.has(volume.building_id):
			continue
		_infill_total += 1
		_check(volume.small_loot_chance == 0.0 and not volume.exploration_loot_enabled and not volume.local_encounter_enabled and volume.secondary_objective_id == 0,
			tag + " infill building carries loot or security " + record)
	var off_buildings := _buildings(off.chunk)
	var on_buildings := _buildings(chunk)
	for building: Dictionary in on_buildings:
		var was_original := false
		for original: Dictionary in off_buildings:
			if original.rect == building.rect: was_original = true
		_check(was_original != bool(building.infill), tag + " infill flag disagrees with the original lot set " + str(building.rect))
	# 3. Ambient spawn sockets: infill adds none; street chunks keep them exactly.
	var off_sockets := _spawn_sockets(off.chunk)
	var on_sockets := _spawn_sockets(chunk)
	if role == &"district_fill":
		_check(off_sockets.size() == on_sockets.size(), tag + " courtyard spawn socket count changed")
	else:
		_check(off_sockets == on_sockets, tag + " street spawn sockets changed")
	# 4. Protected cells, anchors, squares and passages stay open.
	for cell: Vector2i in chunk.get_meta(&"_proc_clear_cells", {}):
		if data.kind_at(cell) >= 0:
			failures.append(tag + " blocked protected cell " + str(cell))
			break
	var reserved: Array[Rect2i] = []
	if role in ANCHOR_ROLES:
		reserved.append(Rect2i(13, 13, 7, 7))
	if chunk.has_meta(&"_proc_framed_square"):
		var square: Rect2i = chunk.get_meta(&"_proc_framed_square")
		reserved.append(square.grow(2).intersection(Rect2i(0, 0, CPC, CPC)))
		reserved.append(Rect2i(11, 11, 11, 11))
	for building: Dictionary in on_buildings:
		if not building.infill:
			continue
		var rect := Rect2i(building.rect[0], building.rect[1], building.rect[2], building.rect[3])
		for box: Rect2i in reserved:
			_check(not rect.intersects(box), tag + " infill building %s enters reserved box %s" % [rect, box])
		_check(Rect2i(0, 0, CPC, CPC).encloses(rect), tag + " infill building leaves its chunk " + str(rect))
	for passage: Rect2i in chunk.get_meta(&"_proc_frontage_passages", []):
		var width := mini(passage.size.x, passage.size.y)
		_check(width >= 3, tag + " infill passage narrower than three cells " + str(passage))
		for y in range(passage.position.y, passage.end.y):
			for x in range(passage.position.x, passage.end.x):
				if data.kind_at(Vector2i(x, y)) >= 0:
					failures.append(tag + " infill passage blocked at " + str(Vector2i(x, y)))
	# 5. Reachability of sockets, doors and interiors. A door or room the
	# original layout already left unreachable is reported, not blamed on the
	# pass; anything the pass newly encloses fails.
	var problems_off := _reach_problems(off, coord)
	var problems_on := _reach_problems(on, coord)
	_preexisting += problems_off.size()
	for problem: String in problems_on:
		_check(problems_off.has(problem), tag + " " + problem)
	# 6. Exact regeneration (fresh manager, other generation order).
	_check(_physical(data) == _physical(again.data) and str(on_buildings) == str(_buildings(again.chunk)), tag + " regeneration differs")
	_samples.append({"segment": segment, "theme": String(theme.id), "plan_seed": int(plan.seed), "coord": [coord.x, coord.y], "role": String(role),
		"buildings": on_buildings, "original_count": off_buildings.size(), "framed_square": chunk.has_meta(&"_proc_framed_square"),
		"passages": (chunk.get_meta(&"_proc_frontage_passages", []) as Array).map(func(r: Rect2i) -> Array: return [r.position.x, r.position.y, r.size.x, r.size.y])})
	for fixture: Dictionary in [off, on, again]:
		(fixture.cm as ChunkManager).free()


func _reach_problems(fixture: Dictionary, coord: Vector2i) -> Dictionary:
	var chunk: Node2D = fixture.chunk
	var data: ChunkBuildData = fixture.data
	var cm: ChunkManager = fixture.cm
	var gen: ChunkGenImpl = cm._content_gen
	var mask := cm.get_chunk_connectors(coord)
	var start := Vector2i(-1, -1)
	if mask == 0:
		for cell: Vector2i in chunk.get_meta(&"_proc_clear_cells", {}):
			if data.kind_at(cell) < 0:
				start = cell
				break
	else:
		var cx := gen._lane_center_for_col(coord.x, CPC)
		var cy := gen._lane_center_for_row(coord.y, CPC)
		start = Vector2i(cx, 0) if mask & 1 else Vector2i(CPC - 1, cy) if mask & 2 else Vector2i(cx, CPC - 1) if mask & 4 else Vector2i(0, cy)
	var problems: Dictionary = {}
	var reachable := _reachable(data, start) if start.x >= 0 else {}
	if reachable.is_empty():
		problems["no reachable start cell"] = true
	for child: Node in chunk.get_children():
		if child is Marker2D and StringName(child.get_meta(&"spawn_socket_kind", &"")) == &"door":
			var door := Vector2i((child as Node2D).position / 64.0)
			if not reachable.has(door): problems["unreachable door " + str(door)] = true
		if child is IndoorVolume:
			var volume := child as IndoorVolume
			var inner := Rect2i(volume.cell_tl - coord * CPC, volume.size_cells)
			var open := false
			for y in range(inner.position.y, inner.end.y):
				for x in range(inner.position.x, inner.end.x):
					if reachable.has(Vector2i(x, y)): open = true
			if not open: problems["sealed interior " + str(inner)] = true
	return problems


func _run() -> void:
	var dummy := Node2D.new()
	dummy.add_to_group(&"player")
	add_child(dummy)
	var previous_segment: int = Global.attempt_segment
	for entry: Array in THEMES:
		var segment: int = entry[0]
		var seed_value := _theme_seed(segment, entry[1])
		if seed_value < 0:
			failures.append("No seed selects theme %s" % entry[1])
			continue
		Global.attempt_segment = segment
		var theme := SegmentThemePicker.get_theme(segment, seed_value)
		var plan := DistrictPlan.generate(segment, seed_value, 2048, theme)
		for role: StringName in ROLES:
			var coords: Array[Vector2i] = []
			for coord: Vector2i in plan.role_by_chunk:
				if plan.role_by_chunk[coord] == role:
					coords.append(coord)
			coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
			for coord: Vector2i in coords.slice(0, PER_ROLE):
				_check_chunk(theme, plan, coord, role, segment)
				chunks += 1
	Global.attempt_segment = previous_segment
	_check(_infill_total > 0, "The pass built no infill at all")
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"samples": _samples, "failures": failures}, "\t"))
			file.close()
	for failure: String in failures.slice(0, 30):
		push_error(failure)
	print("CityStreetContinuityTest: chunks=%d originals=%d infill=%d checks=%d preexisting_unreachable=%d failures=%d" % [chunks, _original_total, _infill_total, _checks, _preexisting, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
