extends Node

const TIER_FULL := 0
const TIER_MID := 1
const TIER_FAR := 2
const TIER_REVERSAL_WINDOW_USEC := 2_000_000
# Physics samples are smoothed with this time constant before the ordinary
# pressure levels read them, so one slow step (a burst spawn, a flow-field
# publish) cannot restart a release window; the severe fast path reads the
# raw sample so a genuine collapse still engages in 0.15 s.
const PRESSURE_SMOOTHING_SEC := 0.25

@export_range(0, 512, 1) var full_budget: int = 32
@export_range(0, 1024, 1) var mid_budget: int = 32
@export_range(0.05, 2.0, 0.01) var assignment_interval: float = 0.20
@export_range(1, 8, 1) var mid_group_count: int = 3
@export_range(1, 16, 1) var far_group_count: int = 7
@export_range(1.0, 33.0, 0.25) var physics_pressure_ms: float = 8.0

# Spatial bands cap fidelity by player distance so a horde that fits the budget
# numerically still cannot keep offscreen actors in full simulation. Each
# boundary has separate enter/exit thresholds: hysteresis against tier flapping
# when an actor hovers on a band edge between assignment refreshes.
@export var use_spatial_bands: bool = true
@export_range(0.0, 8000.0, 10.0) var full_distance_enter: float = 1200.0
@export_range(0.0, 8000.0, 10.0) var full_distance_exit: float = 1400.0
@export_range(0.0, 8000.0, 10.0) var mid_distance_enter: float = 1800.0
@export_range(0.0, 8000.0, 10.0) var mid_distance_exit: float = 2100.0

# Rank hysteresis: a tier incumbent is ranked as if rank_incumbent_bias times
# closer than it is, so a budget-boundary rank cannot flip tiers on tiny
# distance oscillations between refreshes. Applied squared for full-tier
# incumbents, linearly for mid. Measured 2026-08-22: 84% of tier churn was
# full<->mid rank flapping. 1.0 disables.
@export_range(0.70, 1.0, 0.01) var rank_incumbent_bias: float = 0.90

# Sustained physics pressure temporarily shrinks the budgets instead of tuning
# the whole game around the worst late-game frame. Engage/release timers keep
# the fallback from oscillating on a single spiky physics step.
@export var adaptive_budgets: bool = true
# Budget fallback threshold. Deliberately separate from physics_pressure_ms
# (8 ms), which flow-field load shedding consumes: this game's physics
# baseline sits near 12-14 ms, so 8 ms would keep the reduced budgets
# engaged almost permanently (measured 90.9% duty on 2026-08-22).
@export_range(1.0, 33.0, 0.25) var budget_pressure_ms: float = 14.0
@export_range(0, 512, 1) var pressure_full_budget: int = 12
@export_range(0, 1024, 1) var pressure_mid_budget: int = 24
@export_range(0.05, 5.0, 0.05) var pressure_engage_sec: float = 0.5
@export_range(0.05, 10.0, 0.05) var pressure_release_sec: float = 2.0
@export_range(0.05, 15.0, 0.05) var emergency_release_sec: float = 5.0
# Under sustained pressure the smart-archetype physics release distance
# shrinks by this factor: mid-clamped smart actors otherwise scale physics
# bodies linearly with the horde (measured 134 physics-enabled bodies at
# 250 enemies on 2026-08-22 because nothing inside 2600px ever releases).
@export_range(0.4, 1.0, 0.05) var pressure_release_distance_scale: float = 0.75
# Emergency tier: sustained physics beyond this bounds the cost by design
# at any population (measured 30ms physics p95 at 1129 alive).
@export_range(1.0, 33.0, 0.25) var emergency_pressure_ms: float = 20.0
@export_range(0, 512, 1) var emergency_full_budget: int = 8
@export_range(0, 1024, 1) var emergency_mid_budget: int = 16
@export_range(0.4, 1.0, 0.05) var emergency_release_distance_scale: float = 0.6

# Explicit body-physics boundaries for ordinary smart archetypes. Keeping the
# release/re-acquire pairs together here makes the pressure contract observable
# and avoids multiplying per-enemy values into accidental, drifting thresholds.
@export_group("Smart Physics Boundaries")
@export_range(0.0, 8000.0, 10.0) var normal_smart_release_distance: float = 2600.0
@export_range(0.0, 8000.0, 10.0) var normal_smart_reacquire_distance: float = 2300.0
@export_range(0.0, 8000.0, 10.0) var pressure_smart_release_distance: float = 1600.0
@export_range(0.0, 8000.0, 10.0) var pressure_smart_reacquire_distance: float = 1400.0
@export_range(0.0, 8000.0, 10.0) var emergency_smart_release_distance: float = 1450.0
@export_range(0.0, 8000.0, 10.0) var emergency_smart_reacquire_distance: float = 1250.0
# Emergency pressure may drop ordinary non-contact archetypes (ranged, orbit,
# summoner, tactical, herald) to far-tier physics closer than the smart
# boundary, but never inside this radius: a far-tier body has no collision
# shape and an unmonitorable hitbox, so a close one would be melee-immune and
# walk through walls on screen. Keep in step with
# EnemyRepresentationPolicy.deactivation_distance (640): an actor may only
# release its body where the representation policy would demote it anyway.
@export_range(0.0, 4000.0, 10.0) var noncontact_release_min_distance: float = 640.0

# A genuinely catastrophic physics step should not spend a full second walking
# through the ordinary two-stage fallback. It still requires a short sustained
# window so a single profiler/import hitch cannot collapse simulation fidelity.
@export_group("Severe Pressure Fast Path")
@export_range(1.0, 100.0, 0.5) var severe_pressure_ms: float = 40.0
@export_range(0.05, 1.0, 0.01) var severe_engage_sec: float = 0.15

var _previous_tiers: Dictionary = {}
var _enemy_index: Node = null
var _player: Node2D = null
var _assignment_left: float = 0.0
var _mid_groups: Array = []
var _far_groups: Array = []
var _mid_cursor: int = 0
var _far_cursor: int = 0
var _physics_pressure_override: Variant = null
var _pressure_active := false
var _pressure_level := 0
var _pressure_above_sec := 0.0
var _pressure_below_sec := 0.0
var _severe_above_sec := 0.0
# Per-step physics timing. Performance.TIME_PHYSICS_PROCESS is the MAX step
# time of the previous second, published once per second: useless for
# per-frame reasoning, and it turned one slow step into a full second of
# "pressure". Instead this node stamps the start of its own _physics_process
# and closes the sample at its next callback - the next physics step (during
# catch-up) or the frame's _process, whichever comes first. Nothing but the
# rest of that physics step (every scene callback, then the physics server
# step) runs in between, so the sample is the whole step. The scheduler's
# own assignment refresh is subtracted from the step it ran in, so the 5 Hz
# refresh cannot read as horde pressure.
var _step_start_usec := 0
var _step_start_frame := -1
var _step_refresh_usec := 0
var _last_step_sample_ms := 0.0
var _smoothed_physics_ms := -1.0
const MAX_STEP_SAMPLE_MS := 1000.0
var _debug_counters := {
	"full": 0,
	"mid": 0,
	"far": 0,
	"protected": 0,
	"physics_enabled": 0,
	"mid_steps": 0,
	"far_steps": 0,
	"assignment_usec": 0,
	"stale_entries": 0,
	"spatial_demotions": 0,
	"pressure_active": 0,
	"pressure_level": 0,
	"severe_engagements": 0,
	"physics_step_ms": 0.0,
}
var _tier_lifecycle_counters := {
	"tier_changes": 0,
	"tier_reversals": 0,

	"full_to_mid": 0,
	"mid_to_full": 0,

	"mid_to_far": 0,
	"far_to_mid": 0,

	"full_to_far": 0,
	"far_to_full": 0,
}

# enemy instance id -> last actual tier transition
var _last_tier_transition: Dictionary = {}

func _ready() -> void:
	# Pausable on purpose: this node drives mid/far enemy simulation, and
	# ALWAYS made the offscreen horde keep closing in during the augment
	# pick and tutorial modals while full-tier enemies stood frozen.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_physics_process(true)
	set_process(true)


func _process(_delta: float) -> void:
	_close_step_sample(Time.get_ticks_usec())


func _physics_process(delta: float) -> void:
	var step_started := Time.get_ticks_usec()
	_close_step_sample(step_started)
	_update_pressure_state(maxf(0.0, delta))
	_step_start_usec = step_started
	_step_start_frame = Engine.get_physics_frames()
	_step_refresh_usec = 0
	_assignment_left -= maxf(0.0, delta)
	if _assignment_left <= 0.0:
		var refresh_started := Time.get_ticks_usec()
		refresh_assignments()
		_step_refresh_usec = Time.get_ticks_usec() - refresh_started
	_mid_cursor = _run_next_group(
		_mid_groups,
		_mid_cursor,
		maxf(0.0, delta) * maxi(1, mid_group_count),
		TIER_MID,
		&"mid_steps"
	)
	_far_cursor = _run_next_group(
		_far_groups,
		_far_cursor,
		maxf(0.0, delta) * maxi(1, far_group_count),
		TIER_FAR,
		&"far_steps"
	)


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
		# Distance priorities are negative squared distances, so multiplying by
		# bias^2 ranks a full incumbent as if bias times closer. Positive
		# (boosted/protected) priorities are left untouched.
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

	ordinary_candidates.sort_custom(_candidate_before)

	var assignment: Dictionary = {}
	for candidate in protected_candidates:
		var enemy_id := int(candidate["id"])

		if bool(candidate.get("had_previous_tier", false)):
			_record_tier_transition(
				enemy_id,
				int(candidate["previous_tier"]),
				TIER_FULL
			)

		assignment[enemy_id] = TIER_FULL

	var full_count := mini(maxi(0, _effective_full_budget()), ordinary_candidates.size())
	var mid_count := mini(
		maxi(0, _effective_mid_budget()),
		maxi(0, ordinary_candidates.size() - full_count)
	)
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
		# Distance bands only lower fidelity: a budget slot never keeps an actor
		# beyond its band, and free budget never promotes a distant one.
		if use_spatial_bands:
			var spatial_tier := _spatial_tier_for(
				float(candidate.get("distance", 0.0)),
				int(candidate["previous_tier"]),
				bool(candidate.get("had_previous_tier", false))
			)
			if spatial_tier > tier:
				tier = spatial_tier
				spatial_demotions += 1
		# Enemies whose archetype must keep world collision clamp to mid rather
		# than becoming unshootable far proxies. This can exceed mid_budget by
		# design: collision correctness beats the soft budget.
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
			_record_tier_transition(
				enemy_id,
				int(candidate["previous_tier"]),
				tier
			)

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


func refresh_assignments() -> void:
	if _enemy_index == null or not is_instance_valid(_enemy_index):
		_enemy_index = get_node_or_null("/root/EnemyIndex")
	if _enemy_index == null or not _enemy_index.has_method("get_all"):
		_assignment_left = maxf(0.05, assignment_interval)
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	var player_position := _player.global_position if _player != null else Vector2.ZERO
	var enemies := _enemy_index.call("get_all") as Array
	var assignment := compute_assignment(enemies, player_position)
	_mid_groups = _empty_groups(mid_group_count)
	_far_groups = _empty_groups(far_group_count)
	for enemy_variant in enemies:
		var enemy := enemy_variant as Node
		if not _is_valid_candidate(enemy):
			continue
		var tier := int(assignment.get(enemy.get_instance_id(), TIER_FAR))
		if enemy.has_method("set_scheduler_tier"):
			enemy.call("set_scheduler_tier", tier)
		if tier == TIER_MID:
			_add_to_group_bucket(_mid_groups, enemy)
		elif tier == TIER_FAR:
			_add_to_group_bucket(_far_groups, enemy)
	_assignment_left = maxf(0.05, assignment_interval)


func _empty_groups(group_count: int) -> Array:
	var groups: Array = []
	groups.resize(maxi(1, group_count))
	for index in range(groups.size()):
		groups[index] = []
	return groups


func _add_to_group_bucket(groups: Array, enemy: Node) -> void:
	if groups.is_empty():
		return
	var bucket_index := int(enemy.get_instance_id() % groups.size())
	var bucket := groups[bucket_index] as Array
	# Store IDs rather than object Variants. A pooled or killed enemy may be freed
	# between assignment refreshes; retaining its Variant makes even `as Node`
	# throw before validity can be checked.
	bucket.append(enemy.get_instance_id())


func _run_next_group(
	groups: Array,
	cursor: int,
	step_delta: float,
	expected_tier: int,
	counter_key: StringName
) -> int:
	if groups.is_empty():
		return 0
	var group_index := posmod(cursor, groups.size())
	var bucket := groups[group_index] as Array
	for enemy_id_variant in bucket:
		var object := instance_from_id(int(enemy_id_variant))
		if object == null or not is_instance_valid(object) or not (object is Node):
			_debug_counters["stale_entries"] = int(_debug_counters.get("stale_entries", 0)) + 1
			continue
		var enemy := object as Node
		if not _is_valid_candidate(enemy):
			continue
		if enemy.has_method("simulation_tier") and int(enemy.call("simulation_tier")) != expected_tier:
			continue
		if enemy.has_method("run_scheduled_simulation"):
			enemy.call("run_scheduled_simulation", step_delta)
			_debug_counters[counter_key] = int(_debug_counters.get(counter_key, 0)) + 1
	return (group_index + 1) % groups.size()


func get_debug_counters() -> Dictionary:
	var output := _debug_counters.duplicate(true)

	output["lifecycle"] = _tier_lifecycle_counters.duplicate(true)

	return output

func is_under_physics_pressure() -> bool:
	if _physics_pressure_override != null:
		return bool(_physics_pressure_override)
	return Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0 > physics_pressure_ms


func _is_over_budget_pressure() -> bool:
	if _physics_pressure_override != null:
		return bool(_physics_pressure_override)
	return Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0 > budget_pressure_ms


func set_physics_pressure_override(value: Variant) -> void:
	_physics_pressure_override = value


func is_physics_pressure_active() -> bool:
	return _pressure_active


func physics_pressure_level() -> int:
	return _pressure_level


func physics_release_distance_scale() -> float:
	if _pressure_level >= 2:
		return emergency_release_distance_scale
	return pressure_release_distance_scale if _pressure_active else 1.0


func smart_physics_boundary(is_far: bool) -> float:
	if _pressure_level >= 2:
		return emergency_smart_reacquire_distance if is_far else emergency_smart_release_distance
	if _pressure_level >= 1:
		return pressure_smart_reacquire_distance if is_far else pressure_smart_release_distance
	return normal_smart_reacquire_distance if is_far else normal_smart_release_distance


func should_release_noncontact_smart(ai: int, player_distance: float) -> bool:
	if _pressure_level < 2:
		return false
	if player_distance < noncontact_release_min_distance:
		return false
	match ai:
		EnemySpec.AI.ORBIT, EnemySpec.AI.RANGED, EnemySpec.AI.SUMMONER, EnemySpec.AI.TACTICAL, EnemySpec.AI.HERALD:
			return true
	return false


func _update_pressure_state(delta: float) -> void:
	if not adaptive_budgets:
		_pressure_active = false
		_pressure_level = 0
		_pressure_above_sec = 0.0
		_pressure_below_sec = 0.0
		_severe_above_sec = 0.0
		_sync_pressure_counters()
		return
	var physics_ms := _measured_physics_ms()
	var smoothed := _smooth_physics_ms(physics_ms, delta)
	if physics_ms >= severe_pressure_ms:
		_severe_above_sec += delta
		_pressure_below_sec = 0.0
		if _pressure_level < 2 and _severe_above_sec >= severe_engage_sec:
			_pressure_level = 2
			_pressure_active = true
			_pressure_above_sec = 0.0
			_severe_above_sec = 0.0
			_debug_counters["severe_engagements"] = int(_debug_counters.get("severe_engagements", 0)) + 1
			if PerformanceFlightRecorder != null and bool(PerformanceFlightRecorder.get("enabled")):
				PerformanceFlightRecorder.record_counter_event(&"enemy", &"severe_pressure_engaged", 1, {
					"physics_ms": physics_ms,
				})
		_sync_pressure_counters()
		return
	_severe_above_sec = 0.0
	var measured := _pressure_level_for(smoothed)
	if measured > _pressure_level:
		_pressure_above_sec += delta
		_pressure_below_sec = 0.0
		if _pressure_above_sec >= pressure_engage_sec:
			_pressure_level += 1
			_pressure_above_sec = 0.0
	elif measured < _pressure_level:
		_pressure_below_sec += delta
		_pressure_above_sec = 0.0
		var release_window := emergency_release_sec if _pressure_level >= 2 else pressure_release_sec
		if _pressure_below_sec >= release_window:
			_pressure_level -= 1
			_pressure_below_sec = 0.0
	else:
		_pressure_above_sec = 0.0
		_pressure_below_sec = 0.0
	_pressure_level = clampi(_pressure_level, 0, 2)
	_pressure_active = _pressure_level >= 1
	_sync_pressure_counters()


func _sync_pressure_counters() -> void:
	_debug_counters["pressure_active"] = 1 if _pressure_active else 0
	_debug_counters["pressure_level"] = _pressure_level


func _measured_physics_ms() -> float:
	if _physics_pressure_override != null:
		if _physics_pressure_override is bool:
			return budget_pressure_ms + 0.001 if bool(_physics_pressure_override) else 0.0
		return maxf(0.0, float(_physics_pressure_override))
	return _last_step_sample_ms


func _smooth_physics_ms(physics_ms: float, delta: float) -> float:
	# A bool override means "pretend pressure is on/off", not a measurement:
	# it bypasses smoothing so the budget tests read the level directly.
	if _physics_pressure_override is bool:
		return physics_ms
	if _smoothed_physics_ms < 0.0:
		_smoothed_physics_ms = physics_ms
	else:
		var alpha := 1.0 - exp(-maxf(delta, 0.0) / PRESSURE_SMOOTHING_SEC)
		_smoothed_physics_ms += (physics_ms - _smoothed_physics_ms) * alpha
	return _smoothed_physics_ms


func _close_step_sample(now_usec: int) -> void:
	if _step_start_usec <= 0:
		return
	var step_ms := float(now_usec - _step_start_usec) / 1000.0
	_step_start_usec = 0
	# A pause (or a stall) between the stamps is not a physics step.
	if Engine.get_physics_frames() - _step_start_frame > 1 or step_ms > MAX_STEP_SAMPLE_MS:
		return
	_ingest_step_sample(step_ms, float(_step_refresh_usec) / 1000.0)


func _ingest_step_sample(step_ms: float, refresh_ms: float) -> void:
	_last_step_sample_ms = maxf(0.0, step_ms - refresh_ms)
	_debug_counters["physics_step_ms"] = snappedf(_last_step_sample_ms, 0.01)


func last_step_sample_ms() -> float:
	return _last_step_sample_ms


func _measured_pressure_level() -> int:
	return _pressure_level_for(_smoothed_physics_ms if _smoothed_physics_ms >= 0.0 else _measured_physics_ms())


func _pressure_level_for(physics_ms: float) -> int:
	if physics_ms > emergency_pressure_ms:
		return 2
	if physics_ms > budget_pressure_ms:
		return 1
	return 0


func _effective_full_budget() -> int:
	if _pressure_level >= 2:
		return mini(full_budget, emergency_full_budget)
	return mini(full_budget, pressure_full_budget) if _pressure_active else full_budget


func _effective_mid_budget() -> int:
	if _pressure_level >= 2:
		return mini(mid_budget, emergency_mid_budget)
	return mini(mid_budget, pressure_mid_budget) if _pressure_active else mid_budget


func _spatial_tier_for(distance: float, previous_tier: int, had_previous: bool) -> int:
	var full_limit := full_distance_enter
	if had_previous and previous_tier == TIER_FULL:
		full_limit = maxf(full_distance_enter, full_distance_exit)
	var mid_limit := mid_distance_enter
	if had_previous and previous_tier <= TIER_MID:
		mid_limit = maxf(mid_distance_enter, mid_distance_exit)
	if distance <= full_limit:
		return TIER_FULL
	if distance <= maxf(mid_limit, full_limit):
		return TIER_MID
	return TIER_FAR


func _is_valid_candidate(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.is_queued_for_deletion() or not enemy.is_inside_tree():
		return false
	if enemy.process_mode == Node.PROCESS_MODE_DISABLED or bool(enemy.get_meta("__in_pool", false)):
		return false
	return not ("dead" in enemy and bool(enemy.get("dead")))


func _priority_for(enemy: Node, player_position: Vector2, distance_squared: float) -> float:
	if enemy.has_method("simulation_priority"):
		return float(enemy.call("simulation_priority", player_position))
	return -distance_squared


func _max_tier_for(enemy: Node, player_distance: float) -> int:
	if enemy.has_method("max_scheduler_tier"):
		return clampi(
			int(enemy.call("max_scheduler_tier", player_distance)),
			TIER_FULL,
			TIER_FAR
		)
	return TIER_FAR


func _is_protected(enemy: Node, player_distance: float) -> bool:
	if enemy.has_method("is_simulation_protected"):
		return bool(enemy.call("is_simulation_protected", player_distance))
	if enemy.is_in_group(&"boss_like") or enemy.is_in_group(&"boss") or enemy.is_in_group(&"miniboss"):
		return true
	if bool(enemy.get_meta("objective_required", false)) or bool(enemy.get_meta("tutorial_actor", false)):
		return true
	if bool(enemy.get_meta("never_cull", false)):
		return true
	var kind := enemy.get_meta("special_spawn_kind", &"") as StringName
	if kind == &"summon":
		return true
	if kind == &"interior" and bool(enemy.get_meta("interior_active", true)):
		return true
	if kind == &"boss_add" and bool(enemy.get_meta("encounter_active", true)):
		return true
	if bool(enemy.get_meta("sniper_combat_committed", false)):
		return true
	if enemy.has_meta("sniper_engagement_range"):
		return player_distance <= maxf(0.0, float(enemy.get_meta("sniper_engagement_range")))
	return "is_elite" in enemy and bool(enemy.get("is_elite"))


func _candidate_before(a: Dictionary, b: Dictionary) -> bool:
	var priority_a := float(a["priority"])
	var priority_b := float(b["priority"])
	if not is_equal_approx(priority_a, priority_b):
		return priority_a > priority_b
	var previous_a := int(a["previous_tier"])
	var previous_b := int(b["previous_tier"])
	if previous_a != previous_b:
		return previous_a < previous_b
	return int(a["id"]) < int(b["id"])
func _record_tier_transition(
	enemy_id: int,
	from_tier: int,
	to_tier: int
) -> void:
	if from_tier == to_tier:
		return

	if (
		PerformanceFlightRecorder == null
		or not bool(PerformanceFlightRecorder.get("enabled"))
	):
		return

	_tier_lifecycle_counters["tier_changes"] = (
		int(_tier_lifecycle_counters.get("tier_changes", 0)) + 1
	)

	var transition_key := ""

	match [from_tier, to_tier]:
		[TIER_FULL, TIER_MID]:
			transition_key = "full_to_mid"

		[TIER_MID, TIER_FULL]:
			transition_key = "mid_to_full"

		[TIER_MID, TIER_FAR]:
			transition_key = "mid_to_far"

		[TIER_FAR, TIER_MID]:
			transition_key = "far_to_mid"

		[TIER_FULL, TIER_FAR]:
			transition_key = "full_to_far"

		[TIER_FAR, TIER_FULL]:
			transition_key = "far_to_full"

	if transition_key != "":
		_tier_lifecycle_counters[transition_key] = (
			int(_tier_lifecycle_counters.get(transition_key, 0)) + 1
		)

	var now_usec := Time.get_ticks_usec()
	var previous_variant: Variant = _last_tier_transition.get(enemy_id, {})

	if previous_variant is Dictionary:
		var previous := previous_variant as Dictionary

		if not previous.is_empty():
			var previous_from := int(previous.get("from", -1))
			var previous_to := int(previous.get("to", -1))
			var previous_usec := int(previous.get("t_usec", 0))

			var exact_reverse := (
				previous_from == to_tier
				and previous_to == from_tier
			)

			if (
				exact_reverse
				and previous_usec > 0
				and now_usec - previous_usec <= TIER_REVERSAL_WINDOW_USEC
			):
				_tier_lifecycle_counters["tier_reversals"] = (
					int(_tier_lifecycle_counters.get(
						"tier_reversals",
						0
					)) + 1
				)

	_last_tier_transition[enemy_id] = {
		"from": from_tier,
		"to": to_tier,
		"t_usec": now_usec,
	}
