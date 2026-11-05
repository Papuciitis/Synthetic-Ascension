extends "res://tools/tests/ProcChunkReachabilityTest.gd"
## Street continuity post-pass (2026-10-21) on actual production plans of all
## fourteen district themes. For street, courtyard and landmark chunks it proves:
## - every original building keeps its rect, identity, loot, encounter,
##   secondary objective and door sides with the pass on or off (the post-pass
##   is separately salted, so the original lot RNG cannot drift);
## - infill buildings are architecture only (no loot, encounter, secondary
##   objective, ambient spawn socket or exploration visit);
## - protected route cells, objective anchor boxes and the framed square stay
##   clear; deliberate infill passages are three cells wide and open;
## - every connector socket and real door is reachable and no interior is sealed;
## - regeneration is exact across fresh managers and generation orders.
## Whole plans (every planned chunk, pass off and on) prove the cross-chunk
## invariants a sample cannot see: no lane wall the infill builds or joins is
## longer than WALL_LIMIT, joined across chunk seams; no lane wall at all
## reaches WALL_NEVER; every door keeps the part of its apron inside its own
## chunk free of infill (a chunk cannot see its neighbour's doors; aprons that
## cross a seam are counted); recorded passages stay open after every later
## ring; original doors and spawn sockets are unchanged; per-chunk
## reachability as above.
## Medieval street pass (2026-10-21) on the same plans: courtyard ring doors
## face their court (no outward flip toward a back alley; a walk-through
## passage keeps its rear door); a framed square's open sides carry no frame
## house; infill segments stand on all three setback steps somewhere in every
## run, and each step's lots stay reachable like every other lot.
## -- --out=/abs/path.json writes every sampled chunk for the replay comparison.
## -- --deco=1 builds every fixture with the environment decoration and plaza
## dressing pass on (props, vegetation, centrepieces), so the reachability,
## protected-cell, passage and door-apron checks hold for final-dressed chunks.

const THEMES := [[2, ""], [3, ""], [4, "collapsed_ward"], [4, "civilian_cutthrough"], [5, ""],
	[6, "industrial_cutthrough"], [6, "ruined_services"], [7, "underpass_veins"], [7, "canal_services"],
	[8, "rail_yard"], [8, "military_staging"], [9, "outer_wall"], [9, "siege_services"], [10, ""]]
const ROLES := [&"main_street", &"secondary_route", &"service_lane", &"exit_approach", &"dangerous_alley",
	&"secondary_alley_cache", &"secondary_reward_building", &"optional_interior", &"district_fill", &"landmark_plaza"]
const BASE_SEED := 16102026
const PER_ROLE := 2
const ANCHOR_ROLES := [&"secondary_alley_cache", &"secondary_reward_building", &"optional_interior"]
## Lane walls: buildings within WALL_ROWS cells of a lane edge, 1-2 cell slits
## bridged, joined across chunks. Every infill lot keeps the walls it joins
## within SiteParcelsImpl.WALL_MAX and a lane's seam cells open, so no wall
## with infill exceeds it; original lots alone reach 27.
const WALL_ROWS := 4
const WALL_LIMIT := 24
const WALL_NEVER := 32
const DOOR_APRON := 4

var _checks := 0
var _infill_total := 0
var _original_total := 0
var _samples: Array = []
var _preexisting := 0
var _plan_chunks := 0
var _walls: Array[int] = []
var _infill_walls: Array[int] = []
var _plan_doors := 0
var _cross_seam_aprons := 0
var _deco := false
var _steps := {-1: 0, 0: 0, 1: 0}
var _court_doors := 0
var _framed := 0
var _framed_open_sides := 0


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
	cm.deco_enabled = _deco
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
	cm._chunk_terrain = plan.terrain_by_chunk.duplicate()
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
			"infill": bool(kit.get_meta(&"city_street_infill", false)), "irregular": bool(kit.get("_irregular")), "doors": doors, "civic": bool(kit.get("civic")),
			"step": int(kit.get_meta(&"frontage_step", 0))})
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
		_check(not volume.visit_counts_as_exploration, tag + " infill building counts as an exploration visit " + record)
	for record: String in on_volumes:
		if off_ids.has((on_volumes[record] as IndoorVolume).building_id):
			_check((on_volumes[record] as IndoorVolume).visit_counts_as_exploration, tag + " original building stopped counting as a visit " + record)
	var off_buildings := _buildings(off.chunk)
	var on_buildings := _buildings(chunk)
	for building: Dictionary in on_buildings:
		var original_doors: Variant = null
		for original: Dictionary in off_buildings:
			if original.rect == building.rect: original_doors = original.doors
		_check((original_doors != null) != bool(building.infill), tag + " infill flag disagrees with the original lot set " + str(building.rect))
		if original_doors != null:
			_check(original_doors == building.doors, tag + " original building's doors moved " + str(building.rect))
	# 3. Ambient spawn sockets: infill adds none and original doors keep their
	# side, so every chunk keeps them exactly.
	_check(_spawn_sockets(off.chunk) == _spawn_sockets(chunk), tag + " spawn sockets changed")
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


func _plan_manager(theme: SegmentThemeData, plan: Dictionary, enabled: bool) -> ChunkManager:
	var cm := ChunkManager.new()
	theme.apply_to_chunk_manager(cm)
	cm.world_seed = int(plan.seed)
	cm.generation_enabled = false
	cm.ground_enabled = false
	cm.ground_splat_enabled = false
	cm.decals_enabled = false
	cm.deco_enabled = _deco
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
	cm._chunk_terrain = plan.terrain_by_chunk.duplicate()
	return cm


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


## Every planned chunk with the pass off and on: per chunk the sample checks'
## physical invariants, then the cross-chunk walls and door aprons.
func _check_plan(theme: SegmentThemeData, plan: Dictionary, segment: int) -> void:
	var coords: Array[Vector2i] = []
	for coord: Vector2i in plan.role_by_chunk:
		coords.append(coord)
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var layouts: Array[Dictionary] = []
	for enabled: bool in [false, true]:
		var cm := _plan_manager(theme, plan, enabled)
		var layout := {}
		for coord: Vector2i in coords:
			var built := _generate_into(cm, coord)
			built["cm"] = cm
			var chunk: Node2D = built.chunk
			var data: ChunkBuildData = built.data
			var tag := "plan seg=%d theme=%s coord=%s role=%s" % [segment, theme.id, coord, plan.role_by_chunk[coord]]
			var record := {"buildings": _buildings(chunk), "sockets": _spawn_sockets(chunk), "problems": _reach_problems(built, coord),
				"lanes": _lanes(cm._content_gen, plan.role_by_chunk[coord], int(plan.connectors_by_chunk.get(coord, 0)), coord)}
			if enabled:
				for cell: Vector2i in chunk.get_meta(&"_proc_clear_cells", {}):
					if data.kind_at(cell) >= 0:
						failures.append(tag + " blocked protected cell " + str(cell))
						break
				for passage: Rect2i in chunk.get_meta(&"_proc_frontage_passages", []):
					_check(mini(passage.size.x, passage.size.y) >= 3, tag + " infill passage narrower than three cells " + str(passage))
					var open := true
					for y in range(passage.position.y, passage.end.y):
						for x in range(passage.position.x, passage.end.x):
							if data.kind_at(Vector2i(x, y)) >= 0: open = false
					_check(open, tag + " infill passage blocked " + str(passage))
				for child: Node in chunk.get_children():
					if child is IndoorVolume and child.has_meta(&"city_street_infill"):
						var volume := child as IndoorVolume
						_check(volume.small_loot_chance == 0.0 and not volume.exploration_loot_enabled and not volume.local_encounter_enabled and volume.secondary_objective_id == 0 and not volume.visit_counts_as_exploration,
							tag + " infill building carries loot, security or a visit " + str(volume.cell_tl))
				# Courtyard blocks are the connector-less district_fill chunks.
				var court_role: StringName = StringName(plan.role_by_chunk[coord]) if int(plan.connectors_by_chunk.get(coord, 0)) == 0 else &"street"
				_check_street_relationships(chunk, court_role, record.buildings, tag)
			layout[coord] = record
			cm._unregister_chunk_cells(coord)
			chunk.free()
			_plan_chunks += 1
		cm.free()
		layouts.append(layout)
	var off: Dictionary = layouts[0]
	var on: Dictionary = layouts[1]
	for coord: Vector2i in coords:
		var tag := "plan seg=%d theme=%s coord=%s role=%s" % [segment, theme.id, coord, plan.role_by_chunk[coord]]
		_check(off[coord].sockets == on[coord].sockets, tag + " spawn sockets changed")
		for building: Dictionary in on[coord].buildings:
			if building.infill:
				continue
			var kept := false
			for original: Dictionary in off[coord].buildings:
				if original.rect == building.rect and original.doors == building.doors and original.usage == building.usage: kept = true
			_check(kept, tag + " original building changed " + str(building.rect))
		_check(on[coord].buildings.filter(func(b: Dictionary) -> bool: return not b.infill).size() == off[coord].buildings.size(), tag + " original building count changed")
		for problem: String in on[coord].problems:
			_check(off[coord].problems.has(problem), tag + " " + problem)
	# Cross-chunk: buildings by global cell (true for infill).
	var cover := {}
	for coord: Vector2i in coords:
		for building: Dictionary in on[coord].buildings:
			var rect := Rect2i(building.rect[0], building.rect[1], building.rect[2], building.rect[3])
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					cover[coord * CPC + Vector2i(x, y)] = bool(building.infill)
	# Door aprons stay free of infill. A chunk sees only its own doors: an
	# apron reaching into the next chunk (the rear door of an original
	# walk-through passage on a courtyard's outer ring) is counted, not checked.
	for coord: Vector2i in coords:
		for building: Dictionary in on[coord].buildings:
			for door: Array in building.doors:
				_plan_doors += 1
				var local := Vector2i(door[0], door[1])
				var dir := Vector2i(door[2], door[3])
				var across := Vector2i(absi(dir.y), absi(dir.x))
				if not Rect2i(0, 0, CPC, CPC).has_point(local + dir * DOOR_APRON):
					_cross_seam_aprons += 1
					continue
				var at := coord * CPC + local
				for step in range(1, DOOR_APRON + 1):
					for side in range(-1, 2):
						var cell := at + dir * step + across * side
						_check(not bool(cover.get(cell, false)), "plan seg=%d theme=%s door %s of %s has infill in its apron at %s" % [segment, theme.id, at, str(building.rect), cell])
	# Lane walls joined across chunks.
	var lines := {}
	for coord: Vector2i in coords:
		var lanes: Array = on[coord].lanes
		for axis in 2:
			var lane: Rect2i = lanes[axis]
			if not lane.has_area():
				continue
			for side in [-1, 1]:
				var key := [axis, coord.y if axis == 0 else coord.x, side]
				var line: Dictionary = lines.get(key, {})
				var along := range(lane.position.x, lane.end.x) if axis == 0 else range(lane.position.y, lane.end.y)
				for t: int in along:
					var hit := 0
					for depth in range(1, WALL_ROWS + 1):
						var local := Vector2i(t, lane.position.y - depth if side < 0 else lane.end.y - 1 + depth) if axis == 0 else Vector2i(lane.position.x - depth if side < 0 else lane.end.x - 1 + depth, t)
						var cell := coord * CPC + local
						if cover.has(cell):
							hit = maxi(hit, 2 if bool(cover[cell]) else 1)
					line[(coord.x if axis == 0 else coord.y) * CPC + t] = hit
				lines[key] = line
	for key: Variant in lines:
		var line: Dictionary = lines[key]
		var positions: Array = line.keys()
		positions.sort()
		var first := -1
		var last := -1
		var gap := 0
		var infill := false
		var previous: int = positions[0] - 1 if not positions.is_empty() else 0
		for position: int in positions:
			if position != previous + 1:
				_close_wall(segment, theme.id, key, first, last, infill)
				first = -1
			previous = position
			var hit: int = line[position]
			if hit > 0:
				if first < 0:
					first = position
					infill = false
				last = position
				gap = 0
				infill = infill or hit == 2
			elif first >= 0:
				gap += 1
				if gap > 2:
					_close_wall(segment, theme.id, key, first, last, infill)
					first = -1
		_close_wall(segment, theme.id, key, first, last, infill)


## Door sides and framed squares of one generated chunk (pass on).
func _check_street_relationships(chunk: Node2D, role: StringName, buildings: Array, tag: String) -> void:
	for building: Dictionary in buildings:
		if building.infill:
			_steps[int(building.step)] = int(_steps.get(int(building.step), 0)) + 1
		# Courtyard rings open onto their court: a single door faces the
		# chunk centre (the court lies within two cells of it). Only a
		# walk-through passage's rear door faces out.
		if role == &"district_fill" and (building.doors as Array).size() == 1:
			var door: Array = building.doors[0]
			var toward := Vector2(CPC * 0.5, CPC * 0.5) - Vector2(door[0] + 0.5, door[1] + 0.5)
			_court_doors += 1
			_check(Vector2(door[2], door[3]).dot(toward) > 0.0, tag + " courtyard door faces away from its court " + str(building.rect) + " " + str(door))
	if chunk.has_meta(&"_proc_framed_square"):
		_framed += 1
		var open: int = int(chunk.get_meta(&"_proc_framed_open_sides", 0))
		if open != 0:
			_framed_open_sides += 1
		# Ring order north, south, west, east; a frame house's door faces
		# the square, so its direction names its ring.
		var ring_dirs := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
		for building: Dictionary in buildings:
			if not building.infill:
				continue
			for door: Array in building.doors:
				var dir := Vector2i(door[2], door[3])
				for index in 4:
					if open & (1 << index) and dir == ring_dirs[index]:
						failures.append(tag + " frame house stands on an open side " + str(building.rect))


func _close_wall(segment: int, theme_id: StringName, key: Variant, first: int, last: int, infill: bool) -> void:
	if first < 0:
		return
	var length := last - first + 1
	_walls.append(length)
	if infill:
		_infill_walls.append(length)
	_check(length < WALL_NEVER, "plan seg=%d theme=%s lane wall of %d cells at %s %d..%d" % [segment, theme_id, length, str(key), first, last])
	_check(not infill or length <= WALL_LIMIT, "plan seg=%d theme=%s infill lane wall of %d cells at %s %d..%d" % [segment, theme_id, length, str(key), first, last])


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--deco="): _deco = arg.trim_prefix("--deco=") != "0"
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
		_check_plan(theme, plan, segment)
	Global.attempt_segment = previous_segment
	_check(_infill_total > 0, "The pass built no infill at all")
	for step: int in [-1, 0, 1]:
		_check(int(_steps[step]) > 0, "No infill segment stands on setback step %d" % step)
	_check(_framed > 0 and _framed_open_sides > 0 and _framed_open_sides < _framed, "framed squares: %d, with open sides %d (want some of each)" % [_framed, _framed_open_sides])
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
	_walls.sort()
	_infill_walls.sort()
	print("CityStreetContinuityTest: plan chunks=%d doors=%d (aprons across a seam %d) lane walls=%d (longest %d) infill walls=%d (longest %d)" % [_plan_chunks, _plan_doors, _cross_seam_aprons, _walls.size(), _walls.back() if not _walls.is_empty() else 0, _infill_walls.size(), _infill_walls.back() if not _infill_walls.is_empty() else 0])
	print("CityStreetContinuityTest: deco=%s setback steps (lots) %s courtyard doors=%d framed squares=%d (open sides %d)" % [str(_deco), str(_steps), _court_doors, _framed, _framed_open_sides])
	print("CityStreetContinuityTest: chunks=%d originals=%d infill=%d checks=%d preexisting_unreachable=%d failures=%d" % [chunks, _original_total, _infill_total, _checks, _preexisting, failures.size()])
	get_tree().quit(1 if not failures.is_empty() else 0)
