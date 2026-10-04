extends Node

## The scheduler's array-based compute_assignment (FPS audit 2026-10-04,
## item 6) must assign exactly the tiers the Dictionary-based one did. The
## old body is kept verbatim in a subclass; both run on the same live
## EnemyActors (every archetype, elites, protected metas, stunned and
## knocked-back actors, exact distance ties) and plain nodes, over rounds of
## movement and pressure changes so incumbency (previous tiers) evolves.

const SchedulerScript = preload("res://autoload/EnemySimulationScheduler.gd")


class ReferenceScheduler:
	extends "res://autoload/EnemySimulationScheduler.gd"

	func compute_assignment(enemies: Array, player_position: Vector2) -> Dictionary:
		var started_usec := Time.get_ticks_usec()
		var protected_candidates: Array[Dictionary] = []
		var ordinary_candidates: Array[Dictionary] = []
		var live_ids: Dictionary = {}

		for enemy_variant in enemies:
			var enemy := enemy_variant as Node
			if not _is_valid_candidate(enemy):
				continue
			var enemy_id := int(enemy.get_instance_id())
			live_ids[enemy_id] = true
			var position := (enemy as Node2D).global_position if enemy is Node2D else Vector2.ZERO
			var distance_squared := position.distance_squared_to(player_position)
			var distance := sqrt(distance_squared)
			var had_previous_tier := _previous_tiers.has(enemy_id)
			var previous_tier := int(_previous_tiers.get(enemy_id, TIER_FAR))
			var priority := _priority_for(enemy, player_position, distance_squared)
			if had_previous_tier and priority < 0.0 and rank_incumbent_bias < 1.0:
				if previous_tier == TIER_FULL:
					priority *= rank_incumbent_bias * rank_incumbent_bias
				elif previous_tier == TIER_MID:
					priority *= rank_incumbent_bias
			var candidate := {
				"node": enemy,
				"id": enemy_id,
				"distance_squared": distance_squared,
				"distance": distance,
				"priority": priority,
				"had_previous_tier": had_previous_tier,
				"previous_tier": previous_tier,
				"max_tier": _max_tier_for(enemy, distance),
			}
			if _is_protected(enemy, distance):
				protected_candidates.append(candidate)
			else:
				ordinary_candidates.append(candidate)

		ordinary_candidates.sort_custom(_reference_candidate_before)

		var assignment: Dictionary = {}
		for candidate in protected_candidates:
			var enemy_id := int(candidate["id"])
			if bool(candidate.get("had_previous_tier", false)):
				_record_tier_transition(enemy_id, int(candidate["previous_tier"]), TIER_FULL)
			assignment[enemy_id] = TIER_FULL

		var full_count := mini(maxi(0, _effective_full_budget()), ordinary_candidates.size())
		var mid_count := mini(maxi(0, _effective_mid_budget()), maxi(0, ordinary_candidates.size() - full_count))
		var full_assigned := 0
		var mid_assigned := 0
		var far_assigned := 0
		var spatial_demotions := 0
		for index in range(ordinary_candidates.size()):
			var candidate := ordinary_candidates[index] as Dictionary
			var tier := TIER_FAR
			if index < full_count:
				tier = TIER_FULL
			elif index < full_count + mid_count:
				tier = TIER_MID
			if use_spatial_bands:
				var spatial_tier := _spatial_tier_for(
					float(candidate.get("distance", 0.0)),
					int(candidate["previous_tier"]),
					bool(candidate.get("had_previous_tier", false))
				)
				if spatial_tier > tier:
					tier = spatial_tier
					spatial_demotions += 1
			var max_tier := int(candidate.get("max_tier", TIER_FAR))
			if tier > max_tier:
				tier = max_tier
			if tier == TIER_FULL:
				full_assigned += 1
			elif tier == TIER_MID:
				mid_assigned += 1
			elif tier == TIER_FAR:
				far_assigned += 1
			var enemy_id := int(candidate["id"])
			if bool(candidate.get("had_previous_tier", false)):
				_record_tier_transition(enemy_id, int(candidate["previous_tier"]), tier)
			assignment[enemy_id] = tier

		for tracked_id_variant in _last_tier_transition.keys():
			var tracked_id := int(tracked_id_variant)
			if not live_ids.has(tracked_id):
				_last_tier_transition.erase(tracked_id)

		_previous_tiers.clear()
		for enemy_id in assignment:
			_previous_tiers[enemy_id] = int(assignment[enemy_id])

		_debug_counters["full"] = full_assigned + protected_candidates.size()
		_debug_counters["mid"] = mid_assigned
		_debug_counters["far"] = far_assigned
		_debug_counters["protected"] = protected_candidates.size()
		_debug_counters["physics_enabled"] = int(_debug_counters["full"]) + mid_assigned
		_debug_counters["spatial_demotions"] = spatial_demotions
		_debug_counters["pressure_active"] = 1 if _pressure_active else 0
		_debug_counters["pressure_level"] = _pressure_level
		_debug_counters["assignment_usec"] = Time.get_ticks_usec() - started_usec
		return assignment

	func _reference_candidate_before(a: Dictionary, b: Dictionary) -> bool:
		var priority_a := float(a["priority"])
		var priority_b := float(b["priority"])
		if not is_equal_approx(priority_a, priority_b):
			return priority_a > priority_b
		var previous_a := int(a["previous_tier"])
		var previous_b := int(b["previous_tier"])
		if previous_a != previous_b:
			return previous_a < previous_b
		return int(a["id"]) < int(b["id"])


const AI_CHOICES := [
	EnemySpec.AI.CHASE, EnemySpec.AI.CHASE, EnemySpec.AI.CHASE, EnemySpec.AI.RANGED, EnemySpec.AI.ORBIT,
	EnemySpec.AI.CHARGE, EnemySpec.AI.BOMBER, EnemySpec.AI.SNIPER, EnemySpec.AI.SPLITTER,
	EnemySpec.AI.LEECH, EnemySpec.AI.SUMMONER, EnemySpec.AI.TACTICAL, EnemySpec.AI.HERALD,
]

var _passes := 0
var _failures := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _counters(scheduler: Node) -> Dictionary:
	var counters := scheduler.call("get_debug_counters") as Dictionary
	return {
		"full": counters.get("full"), "mid": counters.get("mid"), "far": counters.get("far"),
		"protected": counters.get("protected"), "physics_enabled": counters.get("physics_enabled"),
		"spatial_demotions": counters.get("spatial_demotions"),
	}


func _run() -> void:
	var live := get_node_or_null("/root/EnemySimulationScheduler")
	if live != null:
		live.set_physics_process(false)
	_rng.seed = 20261004
	var scene := load("res://core/actors/enemy/enemy.tscn") as PackedScene
	var enemies: Array = []
	for index in range(140):
		var enemy := scene.instantiate() as EnemyActor
		var spec := EnemySpec.new()
		spec.ai = int(AI_CHOICES[_rng.randi_range(0, AI_CHOICES.size() - 1)])
		enemy.spec = spec
		add_child(enemy)
		enemy.is_elite = _rng.randf() < 0.1
		var roll := _rng.randf()
		if roll < 0.05:
			enemy.set_meta(&"objective_required", true)
		elif roll < 0.10:
			enemy.set_meta(&"special_spawn_kind", &"summon")
		elif roll < 0.13:
			enemy.add_to_group(&"miniboss")
		if _rng.randf() < 0.1:
			enemy.stun_time = 0.5
		elif _rng.randf() < 0.1:
			enemy.knockback_vel = Vector2(40.0, 0.0)
		enemies.append(enemy)
	for index in range(20):
		var probe := Node2D.new()
		add_child(probe)
		enemies.append(probe)
	var player := Vector2(300.0, -200.0)
	var reference := ReferenceScheduler.new()
	var candidate := SchedulerScript.new()
	add_child(reference)
	add_child(candidate)
	var rounds := 10
	var mismatches := 0
	var tiers_seen := {0: 0, 1: 0, 2: 0}
	for round_index in range(rounds):
		for i in range(enemies.size()):
			var node := enemies[i] as Node2D
			var distance := _rng.randf_range(0.0, 3200.0)
			# Every tenth node shares a distance with its neighbour: exact ties
			# go to the incumbency and id tie-breakers.
			if i % 10 == 1:
				distance = (enemies[i - 1] as Node2D).global_position.distance_to(player)
			node.global_position = player + Vector2.RIGHT.rotated(_rng.randf() * TAU) * distance
		var level := round_index % 3
		for scheduler in [reference, candidate]:
			if level == 0:
				scheduler.call("set_physics_pressure_override", false)
				scheduler.call("_update_pressure_state", 6.0)
			elif level == 1:
				scheduler.call("set_physics_pressure_override", 16.0)
				scheduler.call("_update_pressure_state", 0.6)
			else:
				scheduler.call("set_physics_pressure_override", 45.0)
				scheduler.call("_update_pressure_state", 0.2)
		var expected := reference.compute_assignment(enemies, player)
		var actual := candidate.call("compute_assignment", enemies, player) as Dictionary
		var same := expected == actual and _counters(reference) == _counters(candidate)
		if not same:
			mismatches += 1
			push_error("round %d mismatch: %d vs %d entries, counters %s vs %s" % [round_index, expected.size(), actual.size(), str(_counters(reference)), str(_counters(candidate))])
		for tier in expected.values():
			tiers_seen[int(tier)] = int(tiers_seen[int(tier)]) + 1
	_check(mismatches == 0, "array-based assignment matches the Dictionary-based one over %d rounds, three pressure levels" % rounds)
	_check(int(tiers_seen[0]) > 0 and int(tiers_seen[1]) > 0 and int(tiers_seen[2]) > 0, "every tier was assigned (%s)" % str(tiers_seen))

	var started := Time.get_ticks_usec()
	for _i in range(20):
		reference.compute_assignment(enemies, player)
	var old_usec := float(Time.get_ticks_usec() - started) / 20.0
	started = Time.get_ticks_usec()
	for _i in range(20):
		candidate.call("compute_assignment", enemies, player)
	var new_usec := float(Time.get_ticks_usec() - started) / 20.0
	print("EnemySchedulerAssignmentEquivalenceTest: compute_assignment at %d candidates: %.0f us (dictionaries) vs %.0f us (arrays)" % [enemies.size(), old_usec, new_usec])
	_check(new_usec < old_usec, "the array-based assignment is cheaper")
	for node in enemies:
		(node as Node).queue_free()
	reference.queue_free()
	candidate.queue_free()
	if live != null:
		live.set_physics_process(true)
	await get_tree().process_frame
	print("EnemySchedulerAssignmentEquivalenceTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
