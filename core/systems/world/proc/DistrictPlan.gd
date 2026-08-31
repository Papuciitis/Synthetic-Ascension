extends RefCounted
class_name DistrictPlan

const N := 1
const E := 2
const S := 4
const W := 8
const INVALID_CHUNK := Vector2i(999999, 999999)

# Macro generation contract:
# - A readable main escape route.
# - Longer secondary routes that reconnect when possible.
# - An exploration web beyond those routes, with rewarded endpoints.
# - No hard map boundary: chunks outside the authored web remain streamable procedural wilderness.
# - Semantic roles drive chunk geometry, terrain and landmarks.

static func generate(segment: int, attempt_world_seed: int, chunk_size_px: int, theme: SegmentThemeData = null) -> Dictionary:
	var best_candidate: Dictionary = {}
	var best_score: int = -2147483648
	for retry_index in range(6):
		var retry_seed: int = attempt_world_seed if retry_index == 0 else _mix_seed(attempt_world_seed, 0x25120 + retry_index * 7919)
		var candidate: Dictionary = _generate_once(segment, retry_seed, chunk_size_px, theme)
		var validation: Dictionary = _validate_plan(candidate)
		candidate["validation"] = validation
		candidate["generation_attempt"] = retry_index + 1
		if bool(validation.get("valid", false)):
			return candidate
		var score := validation_score(validation)
		if score > best_score:
			best_score = score
			best_candidate = candidate
	var fallback_validation: Dictionary = best_candidate.get("validation", {}) as Dictionary
	fallback_validation["fallback_selected"] = true
	fallback_validation["fallback_score"] = best_score
	best_candidate["validation"] = fallback_validation
	push_warning("[DistrictPlan] Returning highest-scoring fallback after deterministic validation retries: %s" % str(fallback_validation))
	return best_candidate


static func validation_score(validation: Dictionary) -> int:
	if bool(validation.get("valid", false)):
		return 2147483647
	var errors: Array = validation.get("errors", []) as Array
	var score: int = 0
	var primary_distance := int(validation.get("start_to_primary", -1))
	var exit_distance := int(validation.get("start_to_exit", -1))
	var primary_to_exit := int(validation.get("primary_to_exit", -1))
	if primary_distance >= 0:
		score += 1_000_000
	if exit_distance >= 0 and primary_to_exit >= 0:
		score += 1_000_000
	var has_connector_error := errors.any(func(error: Variant) -> bool: return String(error).begins_with("non_reciprocal_connector"))
	var has_secondary_error := errors.any(func(error: Variant) -> bool: return String(error).begins_with("secondary_unreachable"))
	var has_urban_error := errors.any(func(error: Variant) -> bool:
		var text := String(error)
		return text.begins_with("urban_block_without_access") or text.begins_with("non_reciprocal_urban_access")
	)
	if not has_connector_error:
		score += 500_000
	if not has_secondary_error:
		score += 250_000
	if not has_urban_error:
		score += 100_000
	score += maxi(0, primary_distance) * 100
	score += maxi(0, primary_to_exit) * 100
	score += maxi(0, int(validation.get("secondary_count", 0))) * 10
	return score

static func _generate_once(segment: int, attempt_world_seed: int, chunk_size_px: int, theme: SegmentThemeData = null) -> Dictionary:
	segment = maxi(1, segment)
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_seed(attempt_world_seed, segment)

	var goal_dist_offset: int = 0
	var ortho_limit: int = 4
	var ortho_guard_bonus: int = 2
	var waypoint_chance: float = 0.90
	var meander_chance: float = 0.28
	var branch_count_min: int = 3
	var branch_count_max: int = 4
	var max_branch_len: int = 3
	var loop_budget_min: int = 1
	var loop_budget_max: int = 2
	var exploration_count_min: int = 3
	var exploration_count_max: int = 5
	var exploration_len_min: int = 2
	var exploration_len_max: int = 4
	var exploration_turn_chance: float = 0.40
	var exploration_reconnect_chance: float = 0.45
	var exploration_band_bonus: int = 4
	var landmark_count: int = 2
	var base_terrain: StringName = &"grass"
	var exploration_terrain: StringName = &"grass"
	var theme_id: StringName = &"service_courtyards"
	var envelope_cardinal_chance: float = 0.88
	var envelope_diagonal_chance: float = 0.42
	var want_miniboss_arena: bool = (segment == 5)
	var want_boss_arena: bool = (segment == 10)

	if theme != null:
		goal_dist_offset = theme.goal_dist_offset
		ortho_limit = maxi(2, theme.ortho_limit)
		ortho_guard_bonus = maxi(0, theme.ortho_guard_bonus)
		waypoint_chance = clampf(theme.waypoint_chance, 0.0, 1.0)
		meander_chance = clampf(theme.meander_chance, 0.0, 1.0)
		branch_count_min = maxi(1, theme.branch_count_min)
		branch_count_max = maxi(branch_count_min, theme.branch_count_max)
		max_branch_len = maxi(1, theme.max_branch_len)
		loop_budget_min = maxi(0, theme.loop_budget_min)
		loop_budget_max = maxi(loop_budget_min, theme.loop_budget_max)
		exploration_count_min = maxi(1, theme.exploration_branch_count_min)
		exploration_count_max = maxi(exploration_count_min, theme.exploration_branch_count_max)
		exploration_len_min = maxi(1, theme.exploration_branch_len_min)
		exploration_len_max = maxi(exploration_len_min, theme.exploration_branch_len_max)
		exploration_turn_chance = clampf(theme.exploration_turn_chance, 0.0, 1.0)
		exploration_reconnect_chance = clampf(theme.exploration_reconnect_chance, 0.0, 1.0)
		exploration_band_bonus = maxi(1, theme.exploration_band_bonus)
		landmark_count = clampi(theme.landmark_count, 1, 4)
		envelope_cardinal_chance = clampf(theme.urban_envelope_cardinal_chance, 0.0, 1.0)
		envelope_diagonal_chance = clampf(theme.urban_envelope_diagonal_chance, 0.0, 1.0)
		base_terrain = StringName(theme.base_terrain)
		exploration_terrain = StringName(theme.exploration_terrain)
		theme_id = theme.id
		want_miniboss_arena = theme.has_miniboss_arena
		want_boss_arena = theme.has_boss_arena

	# Segment 2 keeps its relay at the established five-to-six-step distance, but
	# extends the district beyond it so reaching the Exit Rite is a real journey.
	var base_dist: int = 12 if segment == 2 else 7 + maxi(0, segment - 2)
	var minimum_goal_dist: int = 12 if segment == 2 else 7
	var goal_dist: int = clampi(base_dist + goal_dist_offset + rng.randi_range(-1, 2), minimum_goal_dist, 18)
	var start_chunk := Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
	var exit_edge: int = rng.randi_range(0, 3)
	var exit_chunk := _make_exit_target(exit_edge, goal_dist, ortho_limit, rng)
	var primary_dir := _primary_direction(exit_edge)

	var main_route: Array[Vector2i] = _build_main_route(
		start_chunk,
		exit_chunk,
		exit_edge,
		ortho_limit,
		waypoint_chance,
		meander_chance,
		rng
	)
	if main_route.is_empty():
		main_route.append(start_chunk)
	if main_route[main_route.size() - 1] != exit_chunk:
		main_route.append(exit_chunk)
	var primary_index: int = _choose_primary_index(main_route, start_chunk, segment, rng)
	var primary_chunk: Vector2i = main_route[primary_index]

	var chunk_set: Dictionary = {}
	for c_main: Vector2i in main_route:
		chunk_set[c_main] = true

	# Secondary routes remain readable alternatives to the main route. They are longer than
	# the old one-cell pockets and may bend, loop or terminate in an interior/reward node.
	var secondary_paths: Array = []
	var secondary_end_chunks: Array[Vector2i] = []
	var branch_count: int = rng.randi_range(branch_count_min, branch_count_max)
	for i in range(branch_count):
		if main_route.size() < 4:
			break
		var low_idx: int = 1
		var high_idx: int = maxi(low_idx, main_route.size() - 2)
		var anchor: Vector2i = main_route[rng.randi_range(low_idx, high_idx)]
		var path: Array[Vector2i] = _try_build_branch(
			anchor,
			primary_dir,
			start_chunk,
			exit_chunk,
			ortho_limit + ortho_guard_bonus,
			1,
			max_branch_len,
			0.28,
			chunk_set,
			rng
		)
		if path.is_empty():
			continue
		secondary_paths.append(path)
		secondary_end_chunks.append(path[path.size() - 1])

	# Exploration web: starts from the main route and secondary routes, pushes farther sideways,
	# and deliberately leaves rewarded dead ends. This is not the world boundary; beyond it,
	# normal streamed chunks continue to exist as wilderness/ruins.
	var exploration_paths: Array = []
	var exploration_chunks: Array[Vector2i] = []
	var exploration_end_chunks: Array[Vector2i] = []
	var exploration_anchor_pool: Array[Vector2i] = []
	for idx in range(1, maxi(1, main_route.size() - 1)):
		if idx < main_route.size() - 1:
			exploration_anchor_pool.append(main_route[idx])
	for end_chunk: Vector2i in secondary_end_chunks:
		exploration_anchor_pool.append(end_chunk)
	for path_variant in secondary_paths:
		var secondary_path: Array = path_variant
		if secondary_path.size() >= 2:
			var secondary_mid: Vector2i = secondary_path[int(floor(float(secondary_path.size()) * 0.5))]
			exploration_anchor_pool.append(secondary_mid)

	var exploration_count: int = rng.randi_range(exploration_count_min, exploration_count_max)
	for j in range(exploration_count):
		if exploration_anchor_pool.is_empty():
			break
		var anchor2: Vector2i = exploration_anchor_pool[rng.randi_range(0, exploration_anchor_pool.size() - 1)]
		var path2: Array[Vector2i] = _try_build_branch(
			anchor2,
			primary_dir,
			start_chunk,
			exit_chunk,
			ortho_limit + ortho_guard_bonus + exploration_band_bonus,
			exploration_len_min,
			exploration_len_max,
			exploration_turn_chance,
			chunk_set,
			rng
		)
		if path2.is_empty():
			continue
		exploration_paths.append(path2)
		for c_exp: Vector2i in path2:
			if not exploration_chunks.has(c_exp):
				exploration_chunks.append(c_exp)
		var endpoint: Vector2i = path2[path2.size() - 1]
		exploration_end_chunks.append(endpoint)
		exploration_anchor_pool.append(endpoint)

	# Add short reconnects between nearby route pieces. Reconnects improve exploration flow,
	# while rewarded endpoints preserve the satisfaction of finding a true side pocket.
	var chunks_before_loops: Dictionary = chunk_set.duplicate()
	var loop_budget: int = rng.randi_range(loop_budget_min, loop_budget_max)
	if rng.randf() < exploration_reconnect_chance:
		loop_budget += 1
	_add_short_loops(chunk_set, loop_budget, start_chunk, exit_chunk, primary_dir, ortho_limit + ortho_guard_bonus + exploration_band_bonus, rng)
	for loop_key in chunk_set.keys():
		var loop_coord: Vector2i = loop_key
		if not chunks_before_loops.has(loop_coord) and not exploration_chunks.has(loop_coord):
			exploration_chunks.append(loop_coord)

	# Keep road connectivity separate from the surrounding urban envelope. Envelope
	# chunks make the route read as a district, but they must not silently become roads.
	# Cardinal blocks are generated first; diagonal blocks are only accepted when a
	# cardinal bridge already exists, so every urban block can be linked back to a street.
	var road_chunk_set: Dictionary = chunk_set.duplicate()
	var urban_envelope_set: Dictionary = {}
	var urban_envelope_chunks: Array[Vector2i] = []
	# Every theme gets an envelope now, at its own density. This used to read
	# `if theme_id == &"service_courtyards"`, which is why segments 3-10 were
	# routes drawn across an empty field.
	if envelope_cardinal_chance > 0.0:
		var cardinal_dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
		var diagonal_dirs: Array[Vector2i] = [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]
		var road_keys: Array = road_chunk_set.keys()
		road_keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
		for road_key in road_keys:
			var road_chunk: Vector2i = road_key as Vector2i
			for cardinal_dir in cardinal_dirs:
				var cardinal_candidate: Vector2i = road_chunk + cardinal_dir
				if road_chunk_set.has(cardinal_candidate) or urban_envelope_set.has(cardinal_candidate):
					continue
				if rng.randf() > envelope_cardinal_chance:
					continue
				chunk_set[cardinal_candidate] = true
				urban_envelope_set[cardinal_candidate] = true
				urban_envelope_chunks.append(cardinal_candidate)

		for road_key in road_keys:
			var road_chunk2: Vector2i = road_key as Vector2i
			for diagonal_dir in diagonal_dirs:
				var diagonal_candidate: Vector2i = road_chunk2 + diagonal_dir
				if road_chunk_set.has(diagonal_candidate) or urban_envelope_set.has(diagonal_candidate):
					continue
				if rng.randf() > envelope_diagonal_chance:
					continue
				var has_cardinal_bridge: bool = false
				for cardinal_dir in cardinal_dirs:
					var bridge_neighbor: Vector2i = diagonal_candidate + cardinal_dir
					if road_chunk_set.has(bridge_neighbor) or urban_envelope_set.has(bridge_neighbor):
						has_cardinal_bridge = true
						break
				if not has_cardinal_bridge:
					continue
				chunk_set[diagonal_candidate] = true
				urban_envelope_set[diagonal_candidate] = true
				urban_envelope_chunks.append(diagonal_candidate)

	# Segment 5 gets a dedicated pre-gate miniboss arena instead of stacking the boss and Exit Rite
	# in the same chunk. Later optional minibosses occupy a deep exploration reward node.
	var miniboss_chunk: Vector2i = INVALID_CHUNK
	if want_miniboss_arena:
		if segment == 5 and main_route.size() >= 3:
			miniboss_chunk = main_route[main_route.size() - 2]
		else:
			miniboss_chunk = _farthest_candidate(exploration_end_chunks, start_chunk, exit_chunk)
			if miniboss_chunk == INVALID_CHUNK:
				miniboss_chunk = _farthest_candidate(secondary_end_chunks, start_chunk, exit_chunk)

	var boss_chunk: Vector2i = INVALID_CHUNK
	if want_boss_arena:
		boss_chunk = exit_chunk

	var wardstone_chunks: Array[Vector2i] = _choose_wardstones(main_route, segment, miniboss_chunk, primary_chunk, rng)
	var landmark_chunks: Array[Vector2i] = _choose_landmarks(main_route, landmark_count, wardstone_chunks, miniboss_chunk, primary_chunk, rng)

	# Semantic role assignment. Priority increases toward the bottom of this block.
	var role_by_chunk: Dictionary = {}
	var terrain_by_chunk: Dictionary = {}
	for key in chunk_set.keys():
		var c_all: Vector2i = key
		role_by_chunk[c_all] = &"district_fill"
		terrain_by_chunk[c_all] = base_terrain

	for c_route: Vector2i in main_route:
		role_by_chunk[c_route] = &"main_street"

	for path_variant2 in secondary_paths:
		var p_secondary: Array = path_variant2
		for c_secondary_variant in p_secondary:
			var c_secondary: Vector2i = c_secondary_variant
			role_by_chunk[c_secondary] = &"secondary_route"

	for c_explore: Vector2i in exploration_chunks:
		role_by_chunk[c_explore] = &"service_lane"
		terrain_by_chunk[c_explore] = exploration_terrain

	var reward_chunks: Array[Vector2i] = []
	for i2 in range(secondary_end_chunks.size()):
		var secondary_end: Vector2i = secondary_end_chunks[i2]
		if i2 % 2 == 0:
			role_by_chunk[secondary_end] = &"optional_interior"
		else:
			role_by_chunk[secondary_end] = &"exploration_reward"
			reward_chunks.append(secondary_end)

	for exploration_end: Vector2i in exploration_end_chunks:
		role_by_chunk[exploration_end] = &"exploration_reward"
		terrain_by_chunk[exploration_end] = exploration_terrain
		if not reward_chunks.has(exploration_end):
			reward_chunks.append(exploration_end)

	# Vertical-slice secondary objective framework. Segment 2 always demonstrates both
	# templates; later districts deterministically roll between zero and three.
	var secondary_target_count: int = 2 if segment == 2 else rng.randi_range(0, 3)
	var secondary_objectives: Array[Dictionary] = []
	var secondary_used: Dictionary = {}
	# The miniboss arena claims its chunk later with higher priority; a
	# secondary planned on the same endpoint would be advertised but never
	# spawned (the arena role overwrites it).
	if miniboss_chunk != INVALID_CHUNK:
		secondary_used[miniboss_chunk] = true
	if secondary_target_count >= 1 and not exploration_paths.is_empty():
		var alley_path: Array = exploration_paths[rng.randi_range(0, exploration_paths.size() - 1)] as Array
		if not alley_path.is_empty() and not secondary_used.has(alley_path[alley_path.size() - 1] as Vector2i):
			var alley_endpoint: Vector2i = alley_path[alley_path.size() - 1]
			for alley_index in range(maxi(0, alley_path.size() - 2), alley_path.size() - 1):
				var alley_chunk: Vector2i = alley_path[alley_index]
				role_by_chunk[alley_chunk] = &"dangerous_alley"
			role_by_chunk[alley_endpoint] = &"secondary_alley_cache"
			secondary_used[alley_endpoint] = true
			secondary_objectives.append({
				"id": secondary_objective_id(int(rng.seed), alley_endpoint, &"dangerous_alley_cache"),
				"type": &"dangerous_alley_cache",
				"chunk": alley_endpoint,
				"world": _chunk_center_world(alley_endpoint, chunk_size_px),
			})

	if secondary_target_count >= 2:
		for building_endpoint: Vector2i in secondary_end_chunks:
			if secondary_used.has(building_endpoint):
				continue
			role_by_chunk[building_endpoint] = &"secondary_reward_building"
			secondary_used[building_endpoint] = true
			if not reward_chunks.has(building_endpoint):
				reward_chunks.append(building_endpoint)
			secondary_objectives.append({
				"id": secondary_objective_id(int(rng.seed), building_endpoint, &"searchable_reward_building"),
				"type": &"searchable_reward_building",
				"chunk": building_endpoint,
				"world": _chunk_center_world(building_endpoint, chunk_size_px),
			})
			break

	# The third slot used to be a second alley cache, so a district with three
	# secondaries offered two identical ones. A shrine is a different KIND of
	# detour - a decision rather than a trip - and it wants an open floor to
	# stand on, so it takes a plaza role rather than a dead end.
	if secondary_target_count >= 3:
		for extra_endpoint: Vector2i in exploration_end_chunks:
			if secondary_used.has(extra_endpoint):
				continue
			role_by_chunk[extra_endpoint] = &"secondary_wager_shrine"
			secondary_used[extra_endpoint] = true
			if not reward_chunks.has(extra_endpoint):
				reward_chunks.append(extra_endpoint)
			secondary_objectives.append({
				"id": secondary_objective_id(int(rng.seed), extra_endpoint, &"wager_shrine"),
				"type": &"wager_shrine",
				"chunk": extra_endpoint,
				"world": _chunk_center_world(extra_endpoint, chunk_size_px),
			})
			break

	for landmark_chunk: Vector2i in landmark_chunks:
		role_by_chunk[landmark_chunk] = &"landmark_plaza"

	if _theme_uses_checkpoint(theme_id) and main_route.size() >= 5:
		var checkpoint_idx: int = clampi(int(round(float(main_route.size() - 1) * 0.68)), 2, main_route.size() - 2)
		var checkpoint_chunk: Vector2i = main_route[checkpoint_idx]
		if not wardstone_chunks.has(checkpoint_chunk) and checkpoint_chunk != miniboss_chunk:
			role_by_chunk[checkpoint_chunk] = &"checkpoint"

	for ward_chunk: Vector2i in wardstone_chunks:
		role_by_chunk[ward_chunk] = &"wardstone_court"

	if main_route.size() >= 2:
		var approach_chunk: Vector2i = main_route[main_route.size() - 2]
		if approach_chunk != miniboss_chunk:
			role_by_chunk[approach_chunk] = &"exit_approach"

	role_by_chunk[primary_chunk] = &"primary_objective"
	role_by_chunk[start_chunk] = &"entry_court"
	role_by_chunk[exit_chunk] = &"gate"
	if miniboss_chunk != INVALID_CHUNK:
		role_by_chunk[miniboss_chunk] = &"miniboss_arena"
	if boss_chunk != INVALID_CHUNK:
		role_by_chunk[boss_chunk] = &"boss_arena"

	var connectors_by_chunk: Dictionary = _build_connectors(road_chunk_set)
	var urban_access_by_chunk: Dictionary = _build_urban_access_connectors(road_chunk_set, urban_envelope_set, attempt_world_seed)
	var archetype_by_chunk: Dictionary = {}
	for role_key in role_by_chunk.keys():
		var role_coord: Vector2i = role_key
		var role_value: StringName = role_by_chunk[role_coord]
		archetype_by_chunk[role_coord] = _archetype_for_role(role_value)

	var all_chunks: Array[Vector2i] = []
	for all_key in chunk_set.keys():
		var all_coord: Vector2i = all_key
		all_chunks.append(all_coord)

	var wardstone_world: Array[Vector2] = []
	for ward_world_chunk: Vector2i in wardstone_chunks:
		wardstone_world.append(_chunk_center_world(ward_world_chunk, chunk_size_px))

	var miniboss_world: Vector2 = Vector2.ZERO
	if miniboss_chunk != INVALID_CHUNK:
		miniboss_world = _chunk_center_world(miniboss_chunk, chunk_size_px)
	var boss_world: Vector2 = Vector2.ZERO
	if boss_chunk != INVALID_CHUNK:
		boss_world = _chunk_center_world(boss_chunk, chunk_size_px)

	return {
		"seed": int(rng.seed),
		"segment": segment,
		"theme_id": theme_id,
		"start_chunk": start_chunk,
		"primary_chunk": primary_chunk,
		"primary_index": primary_index,
		"exit_chunk": exit_chunk,
		"exit_edge": exit_edge,
		"wardstone_chunks": wardstone_chunks,
		"landmark_chunks": landmark_chunks,
		"reward_chunks": reward_chunks,
		"secondary_objectives": secondary_objectives,
		"secondary_end_chunks": secondary_end_chunks,
		"exploration_chunks": exploration_chunks,
		"exploration_end_chunks": exploration_end_chunks,
		"urban_envelope_chunks": urban_envelope_chunks,
		"main_route": main_route,
		"secondary_paths": secondary_paths,
		"exploration_paths": exploration_paths,
		"start_world": _chunk_center_world(start_chunk, chunk_size_px),
		"primary_world": _chunk_center_world(primary_chunk, chunk_size_px),
		"exit_world": _chunk_center_world(exit_chunk, chunk_size_px),
		"wardstone_world": wardstone_world,
		"miniboss_chunk": miniboss_chunk,
		"miniboss_world": miniboss_world,
		"boss_chunk": boss_chunk,
		"boss_world": boss_world,
		"role_by_chunk": role_by_chunk,
		"terrain_by_chunk": terrain_by_chunk,
		"archetype_by_chunk": archetype_by_chunk,
		"connectors_by_chunk": connectors_by_chunk,
		"urban_access_by_chunk": urban_access_by_chunk,
		"all_chunks": all_chunks,
	}

static func _choose_primary_index(main_route: Array[Vector2i], start_chunk: Vector2i, segment: int, rng: RandomNumberGenerator) -> int:
	if main_route.size() <= 1:
		return 0

	# Segment 2 is the first procedural quest and needs enough traversal before
	# the relay appears. Leave two route steps after it so the revealed gate still
	# has an approach, while later segments keep their existing pacing envelope.
	var last_index: int = main_route.size() - 1
	var exit_buffer_steps: int = 5 if segment == 2 else 3
	var max_index: int = maxi(1, last_index - exit_buffer_steps)
	var requested_min_steps: int = 5 if segment == 2 else 2
	var min_index: int = mini(max_index, requested_min_steps)
	var desired_index: int = min_index
	if segment == 2:
		desired_index = clampi(requested_min_steps + rng.randi_range(0, 1), min_index, max_index)
	else:
		desired_index = clampi(int(round(float(last_index) * 0.48)) + rng.randi_range(-1, 1), min_index, max_index)
	var min_chunk_distance: int = 4 if segment == 2 else 2

	# A route can meander back toward its start. Prefer a position that is also
	# physically distant, not merely several entries deep in the route array.
	var best_index: int = -1
	var best_delta: int = 2147483647
	for candidate_index in range(min_index, max_index + 1):
		var candidate_chunk: Vector2i = main_route[candidate_index]
		var chunk_distance: int = absi(candidate_chunk.x - start_chunk.x) + absi(candidate_chunk.y - start_chunk.y)
		if chunk_distance < min_chunk_distance:
			continue
		var desired_delta: int = absi(candidate_index - desired_index)
		if desired_delta < best_delta:
			best_delta = desired_delta
			best_index = candidate_index

	if best_index >= 0:
		return best_index

	# Short or unusually folded routes may not meet the geometric target. Choose
	# the farthest valid route point instead of falling back near the entrance.
	best_index = min_index
	var best_distance: int = -1
	for fallback_index in range(min_index, max_index + 1):
		var fallback_chunk: Vector2i = main_route[fallback_index]
		var fallback_distance: int = absi(fallback_chunk.x - start_chunk.x) + absi(fallback_chunk.y - start_chunk.y)
		if fallback_distance > best_distance:
			best_distance = fallback_distance
			best_index = fallback_index
	return best_index

static func _build_main_route(start_chunk: Vector2i, exit_chunk: Vector2i, exit_edge: int, ortho_limit: int, waypoint_chance: float, meander_chance: float, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var route: Array[Vector2i] = [start_chunk]
	var used: Dictionary = {}
	used[start_chunk] = true
	var targets: Array[Vector2i] = []
	var goal_dist: int = absi(exit_chunk.x - start_chunk.x) + absi(exit_chunk.y - start_chunk.y)
	if goal_dist >= 6 and rng.randf() < waypoint_chance:
		var waypoint := exit_chunk
		if exit_edge == 1 or exit_edge == 3:
			var sx: int = signi(exit_chunk.x - start_chunk.x)
			var distance_x: int = maxi(3, absi(exit_chunk.x - start_chunk.x))
			var mid_x: int = start_chunk.x + sx * clampi(int(round(float(distance_x) * 0.45)) + rng.randi_range(-1, 1), 2, distance_x - 2)
			var mid_y: int = rng.randi_range(-ortho_limit, ortho_limit)
			if mid_y == start_chunk.y:
				mid_y = clampi(mid_y + (1 if mid_y < ortho_limit else -1), -ortho_limit, ortho_limit)
			waypoint = Vector2i(mid_x, mid_y)
		else:
			var sy: int = signi(exit_chunk.y - start_chunk.y)
			var distance_y: int = maxi(3, absi(exit_chunk.y - start_chunk.y))
			var mid_y2: int = start_chunk.y + sy * clampi(int(round(float(distance_y) * 0.45)) + rng.randi_range(-1, 1), 2, distance_y - 2)
			var mid_x2: int = rng.randi_range(-ortho_limit, ortho_limit)
			if mid_x2 == start_chunk.x:
				mid_x2 = clampi(mid_x2 + (1 if mid_x2 < ortho_limit else -1), -ortho_limit, ortho_limit)
			waypoint = Vector2i(mid_x2, mid_y2)
		if waypoint != start_chunk and waypoint != exit_chunk:
			targets.append(waypoint)
	targets.append(exit_chunk)

	var current := start_chunk
	for target: Vector2i in targets:
		var guard: int = 2048
		while current != target and guard > 0:
			guard -= 1
			var dx: int = signi(target.x - current.x)
			var dy: int = signi(target.y - current.y)
			var primary_step := Vector2i.ZERO
			var secondary_step := Vector2i.ZERO
			if exit_edge == 1 or exit_edge == 3:
				primary_step = Vector2i(dx, 0) if dx != 0 else Vector2i.ZERO
				secondary_step = Vector2i(0, dy) if dy != 0 else Vector2i.ZERO
			else:
				primary_step = Vector2i(0, dy) if dy != 0 else Vector2i.ZERO
				secondary_step = Vector2i(dx, 0) if dx != 0 else Vector2i.ZERO

			var candidates: Array[Vector2i] = []
			if rng.randf() > meander_chance:
				if primary_step != Vector2i.ZERO: candidates.append(current + primary_step)
				if secondary_step != Vector2i.ZERO: candidates.append(current + secondary_step)
			else:
				if secondary_step != Vector2i.ZERO: candidates.append(current + secondary_step)
				if primary_step != Vector2i.ZERO: candidates.append(current + primary_step)

			if rng.randf() < 0.18:
				var perp := Vector2i(0, 1 if rng.randf() < 0.5 else -1) if (exit_edge == 1 or exit_edge == 3) else Vector2i(1 if rng.randf() < 0.5 else -1, 0)
				candidates.append(current + perp)

			var chosen := current
			for candidate: Vector2i in candidates:
				var clamped := candidate
				if exit_edge == 1 or exit_edge == 3:
					clamped.y = clampi(clamped.y, -ortho_limit, ortho_limit)
				else:
					clamped.x = clampi(clamped.x, -ortho_limit, ortho_limit)
				if not used.has(clamped):
					chosen = clamped
					break

			if chosen == current:
				if primary_step != Vector2i.ZERO:
					chosen = current + primary_step
				elif secondary_step != Vector2i.ZERO:
					chosen = current + secondary_step
				else:
					break
			current = chosen
			if not used.has(current):
				route.append(current)
				used[current] = true
	return route

static func _try_build_branch(anchor: Vector2i, primary_dir: Vector2i, start_chunk: Vector2i, exit_chunk: Vector2i, ortho_guard: int, min_len: int, max_len: int, turn_chance: float, chunk_set: Dictionary, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var perp_a: Vector2i = Vector2i(primary_dir.y, -primary_dir.x)
	var perp_b: Vector2i = -perp_a
	for attempt in range(12):
		var direction: Vector2i = perp_a if rng.randf() < 0.5 else perp_b
		if attempt >= 6 and rng.randf() < 0.35:
			direction = primary_dir if rng.randf() < 0.5 else -primary_dir
		var length: int = rng.randi_range(min_len, max_len)
		var current := anchor
		var temp: Array[Vector2i] = []
		for step_idx in range(length):
			if step_idx > 0 and rng.randf() < turn_chance:
				var turn_options: Array[Vector2i] = [primary_dir, -primary_dir, perp_a, perp_b]
				var new_dir: Vector2i = turn_options[rng.randi_range(0, turn_options.size() - 1)]
				if new_dir != -direction:
					direction = new_dir
			var next: Vector2i = current + direction
			if not _inside_campaign_band(next, start_chunk, exit_chunk, primary_dir, ortho_guard, 3):
				break
			if chunk_set.has(next):
				break
			temp.append(next)
			current = next
		if temp.size() < min_len:
			continue
		for c: Vector2i in temp:
			chunk_set[c] = true
		return temp
	return []

static func _add_short_loops(chunk_set: Dictionary, loop_budget: int, start_chunk: Vector2i, exit_chunk: Vector2i, primary_dir: Vector2i, ortho_guard: int, rng: RandomNumberGenerator) -> void:
	if loop_budget <= 0 or chunk_set.size() < 7:
		return
	var coords: Array[Vector2i] = []
	for key in chunk_set.keys():
		var c: Vector2i = key
		coords.append(c)
	for _loop_idx in range(loop_budget):
		var connected := false
		for _try in range(20):
			var a: Vector2i = coords[rng.randi_range(0, coords.size() - 1)]
			var b: Vector2i = coords[rng.randi_range(0, coords.size() - 1)]
			if a == b:
				continue
			var md: int = absi(a.x - b.x) + absi(a.y - b.y)
			if md < 2 or md > 5:
				continue
			var temp: Array[Vector2i] = []
			var current := a
			var guard: int = 12
			while current != b and guard > 0:
				guard -= 1
				var dx: int = signi(b.x - current.x)
				var dy: int = signi(b.y - current.y)
				var step := Vector2i(dx, 0) if dx != 0 and (dy == 0 or rng.randf() < 0.5) else Vector2i(0, dy)
				var next := current + step
				if not _inside_campaign_band(next, start_chunk, exit_chunk, primary_dir, ortho_guard, 3):
					temp.clear()
					break
				if not chunk_set.has(next):
					temp.append(next)
				current = next
			if current != b or temp.size() > 3:
				continue
			for c_new: Vector2i in temp:
				chunk_set[c_new] = true
				coords.append(c_new)
			connected = true
			break
		if not connected:
			continue

static func _choose_wardstones(main_route: Array[Vector2i], segment: int, miniboss_chunk: Vector2i, primary_chunk: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var wards: Array[Vector2i] = []
	if main_route.size() < 4:
		return wards
	var count: int = clampi(2 + int(floor(float(maxi(0, segment - 2)) / 3.0)), 2, 4)
	for i in range(count):
		var t: float = float(i + 1) / float(count + 1)
		var idx: int = clampi(int(round(t * float(main_route.size() - 1))) + rng.randi_range(-1, 1), 1, main_route.size() - 2)
		var candidate: Vector2i = main_route[idx]
		var tries: int = 10
		while (wards.has(candidate) or candidate == miniboss_chunk or candidate == primary_chunk) and tries > 0:
			tries -= 1
			idx = clampi(idx + rng.randi_range(-2, 2), 1, main_route.size() - 2)
			candidate = main_route[idx]
		if not wards.has(candidate) and candidate != miniboss_chunk and candidate != primary_chunk:
			wards.append(candidate)
	return wards

static func _choose_landmarks(main_route: Array[Vector2i], count: int, wardstones: Array[Vector2i], miniboss_chunk: Vector2i, primary_chunk: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var landmarks: Array[Vector2i] = []
	if main_route.size() < 5:
		return landmarks
	for i in range(count):
		var t: float = float(i + 1) / float(count + 1)
		var idx: int = clampi(int(round(t * float(main_route.size() - 1))) + rng.randi_range(-1, 1), 1, main_route.size() - 2)
		var candidate: Vector2i = main_route[idx]
		var tries: int = 12
		while (wardstones.has(candidate) or landmarks.has(candidate) or candidate == miniboss_chunk or candidate == primary_chunk) and tries > 0:
			tries -= 1
			idx = clampi(idx + rng.randi_range(-2, 2), 1, main_route.size() - 2)
			candidate = main_route[idx]
		if not wardstones.has(candidate) and not landmarks.has(candidate) and candidate != miniboss_chunk and candidate != primary_chunk:
			landmarks.append(candidate)
	return landmarks

static func _farthest_candidate(candidates: Array[Vector2i], start_chunk: Vector2i, excluded: Vector2i) -> Vector2i:
	var best := INVALID_CHUNK
	var best_distance: int = -1
	for candidate: Vector2i in candidates:
		if candidate == excluded or candidate == start_chunk:
			continue
		var distance: int = absi(candidate.x - start_chunk.x) + absi(candidate.y - start_chunk.y)
		if distance > best_distance:
			best_distance = distance
			best = candidate
	return best

static func _build_urban_access_connectors(road_chunk_set: Dictionary, urban_envelope_set: Dictionary, plan_seed: int) -> Dictionary:
	var result: Dictionary = {}
	if urban_envelope_set.is_empty():
		return result

	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var bits: Array[int] = [N, E, S, W]
	var opposite_bits: Array[int] = [S, W, N, E]
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = []
	var road_keys: Array = road_chunk_set.keys()
	road_keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for road_key in road_keys:
		var road_coord: Vector2i = road_key as Vector2i
		visited[road_coord] = true
		queue.append(road_coord)

	var cursor: int = 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		for dir_index in range(dirs.size()):
			var neighbor: Vector2i = current + dirs[dir_index]
			if not urban_envelope_set.has(neighbor) or visited.has(neighbor):
				continue
			result[current] = int(result.get(current, 0)) | bits[dir_index]
			result[neighbor] = int(result.get(neighbor, 0)) | opposite_bits[dir_index]
			visited[neighbor] = true
			queue.append(neighbor)

	# A diagonal candidate should always have a bridge, but deterministic generation
	# failures must never leave a sealed block. Drop unreachable envelope chunks from
	# the access map rather than inventing a visual doorway into nowhere.
	var sealed: Array[Vector2i] = []
	for envelope_key in urban_envelope_set.keys():
		var envelope_coord: Vector2i = envelope_key as Vector2i
		if not visited.has(envelope_coord):
			sealed.append(envelope_coord)
	if not sealed.is_empty():
		push_warning(_sealed_envelope_warning(plan_seed, sealed))
	return result


## One line for a whole plan's unreachable envelope chunks. The sweep above runs
## over every envelope chunk, so reporting inside it produced one warning per
## sealed chunk with nothing to tie them to the plan that made them.
static func _sealed_envelope_warning(plan_seed: int, sealed: Array[Vector2i]) -> String:
	var coords := PackedStringArray()
	for coord: Vector2i in sealed:
		coords.append("(%d,%d)" % [coord.x, coord.y])
	return (
		"[DistrictPlan] seed=%d dropped %d sealed envelope chunks from the street-access map: %s"
		% [plan_seed, sealed.size(), ",".join(coords)]
	)


static func _build_connectors(chunk_set: Dictionary) -> Dictionary:
	var connectors: Dictionary = {}
	for key in chunk_set.keys():
		var c: Vector2i = key
		var mask: int = 0
		if chunk_set.has(c + Vector2i(0, -1)): mask |= N
		if chunk_set.has(c + Vector2i(1, 0)): mask |= E
		if chunk_set.has(c + Vector2i(0, 1)): mask |= S
		if chunk_set.has(c + Vector2i(-1, 0)): mask |= W
		connectors[c] = mask
	return connectors

static func _archetype_for_role(role: StringName) -> StringName:
	match role:
		&"entry_court", &"landmark_plaza", &"exploration_reward", &"primary_objective", &"secondary_wager_shrine":
			return &"plaza"
		&"wardstone_court", &"checkpoint", &"miniboss_arena", &"boss_arena":
			return &"arena"
		&"gate":
			return &"gate"
		&"secondary_route", &"service_lane", &"dangerous_alley", &"secondary_alley_cache", &"secondary_reward_building":
			return &"street"
		_:
			return &"district"

static func _theme_uses_checkpoint(theme_id: StringName) -> bool:
	return theme_id == &"checkpoint_lanes" or theme_id == &"inner_district_gate" or theme_id == &"military_staging" or theme_id == &"outer_wall" or theme_id == &"siege_services" or theme_id == &"gate_district"

static func _inside_campaign_band(c: Vector2i, start_chunk: Vector2i, exit_chunk: Vector2i, primary_dir: Vector2i, ortho_guard: int, margin: int) -> bool:
	if primary_dir.x != 0:
		if absi(c.y) > ortho_guard:
			return false
		var min_x: int = mini(start_chunk.x, exit_chunk.x) - margin
		var max_x: int = maxi(start_chunk.x, exit_chunk.x) + margin
		return c.x >= min_x and c.x <= max_x
	if absi(c.x) > ortho_guard:
		return false
	var min_y: int = mini(start_chunk.y, exit_chunk.y) - margin
	var max_y: int = maxi(start_chunk.y, exit_chunk.y) + margin
	return c.y >= min_y and c.y <= max_y

static func _make_exit_target(exit_edge: int, goal_dist: int, ortho_limit: int, rng: RandomNumberGenerator) -> Vector2i:
	match exit_edge:
		0:
			return Vector2i(rng.randi_range(-ortho_limit, ortho_limit), -goal_dist)
		1:
			return Vector2i(goal_dist, rng.randi_range(-ortho_limit, ortho_limit))
		2:
			return Vector2i(rng.randi_range(-ortho_limit, ortho_limit), goal_dist)
		_:
			return Vector2i(-goal_dist, rng.randi_range(-ortho_limit, ortho_limit))

static func _primary_direction(exit_edge: int) -> Vector2i:
	match exit_edge:
		0: return Vector2i(0, -1)
		1: return Vector2i(1, 0)
		2: return Vector2i(0, 1)
		_: return Vector2i(-1, 0)

static func _chunk_center_world(c: Vector2i, chunk_size_px: int) -> Vector2:
	var half: float = float(chunk_size_px) * 0.5
	return Vector2(float(c.x * chunk_size_px) + half, float(c.y * chunk_size_px) + half)

static func secondary_objective_id(plan_seed: int, chunk: Vector2i, objective_type: StringName) -> int:
	var h: int = _mix_seed(plan_seed, chunk.x * 73856093)
	h = _mix_seed(h, chunk.y * 19349663)
	h = _mix_seed(h, str(objective_type).hash())
	return int(h & 0x7fffffff) + 1

static func _validate_plan(plan: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var connectors: Dictionary = plan.get("connectors_by_chunk", {}) as Dictionary
	var start: Vector2i = plan.get("start_chunk", INVALID_CHUNK) as Vector2i
	var primary: Vector2i = plan.get("primary_chunk", INVALID_CHUNK) as Vector2i
	var exit_chunk: Vector2i = plan.get("exit_chunk", INVALID_CHUNK) as Vector2i
	var from_start: Dictionary = _graph_distances(start, connectors)
	var from_primary: Dictionary = _graph_distances(primary, connectors)
	var primary_distance: int = int(from_start.get(primary, -1))
	var exit_distance: int = int(from_start.get(exit_chunk, -1))
	var primary_to_exit: int = int(from_primary.get(exit_chunk, -1))
	var segment: int = int(plan.get("segment", 1))
	var minimum_primary_distance: int = 5 if segment >= 2 else 2
	var minimum_primary_to_exit: int = 5 if segment >= 2 else 2

	if primary_distance < minimum_primary_distance:
		errors.append("primary_unreachable_or_too_close")
	if exit_distance < 5:
		errors.append("exit_unreachable_or_too_close")
	if primary_to_exit < minimum_primary_to_exit:
		errors.append("exit_not_beyond_primary")

	for objective_variant in plan.get("secondary_objectives", []):
		var objective: Dictionary = objective_variant as Dictionary
		var objective_chunk: Vector2i = objective.get("chunk", INVALID_CHUNK) as Vector2i
		if int(from_start.get(objective_chunk, -1)) < 0:
			errors.append("secondary_unreachable_%s" % str(objective_chunk))

	var urban_access: Dictionary = plan.get("urban_access_by_chunk", {}) as Dictionary
	for envelope_variant in plan.get("urban_envelope_chunks", []):
		var envelope_chunk: Vector2i = envelope_variant as Vector2i
		if int(urban_access.get(envelope_chunk, 0)) == 0:
			errors.append("urban_block_without_access_%s" % str(envelope_chunk))

	var access_dirs := {
		N: Vector2i(0, -1),
		E: Vector2i(1, 0),
		S: Vector2i(0, 1),
		W: Vector2i(-1, 0),
	}
	var access_opposite := {N: S, E: W, S: N, W: E}
	for access_chunk_variant in urban_access.keys():
		var access_chunk: Vector2i = access_chunk_variant as Vector2i
		var access_mask: int = int(urban_access[access_chunk])
		for access_bit_variant in access_dirs.keys():
			var access_bit: int = int(access_bit_variant)
			if (access_mask & access_bit) == 0:
				continue
			var access_neighbor: Vector2i = access_chunk + (access_dirs[access_bit] as Vector2i)
			if not urban_access.has(access_neighbor) or (int(urban_access[access_neighbor]) & int(access_opposite[access_bit])) == 0:
				errors.append("non_reciprocal_urban_access_%s_%d" % [str(access_chunk), access_bit])

	var dirs := {
		N: Vector2i(0, -1),
		E: Vector2i(1, 0),
		S: Vector2i(0, 1),
		W: Vector2i(-1, 0),
	}
	var opposite := {N: S, E: W, S: N, W: E}
	for chunk_variant in connectors.keys():
		var chunk: Vector2i = chunk_variant as Vector2i
		var mask: int = int(connectors[chunk])
		for bit_variant in dirs.keys():
			var bit: int = int(bit_variant)
			if (mask & bit) == 0:
				continue
			var neighbor: Vector2i = chunk + (dirs[bit] as Vector2i)
			if not connectors.has(neighbor) or (int(connectors[neighbor]) & int(opposite[bit])) == 0:
				errors.append("non_reciprocal_connector_%s_%d" % [str(chunk), bit])

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"start_to_primary": primary_distance,
		"start_to_exit": exit_distance,
		"primary_to_exit": primary_to_exit,
		"secondary_count": (plan.get("secondary_objectives", []) as Array).size(),
	}

static func _graph_distances(start: Vector2i, connectors: Dictionary) -> Dictionary:
	var distances: Dictionary = {}
	if not connectors.has(start):
		return distances
	var queue: Array[Vector2i] = [start]
	distances[start] = 0
	var head: int = 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		var mask: int = int(connectors.get(current, 0))
		var steps: Array[Dictionary] = [
			{"bit": N, "dir": Vector2i(0, -1)},
			{"bit": E, "dir": Vector2i(1, 0)},
			{"bit": S, "dir": Vector2i(0, 1)},
			{"bit": W, "dir": Vector2i(-1, 0)},
		]
		for step in steps:
			if (mask & int(step["bit"])) == 0:
				continue
			var next: Vector2i = current + (step["dir"] as Vector2i)
			if not connectors.has(next) or distances.has(next):
				continue
			distances[next] = int(distances[current]) + 1
			queue.append(next)
	return distances

static func _mix_seed(a: int, b: int) -> int:
	var h: int = int((a ^ (b * 0x9E3779B9)) & 0x7FFFFFFF)
	h = int((h * 1103515245 + 12345) & 0x7FFFFFFF)
	return h
