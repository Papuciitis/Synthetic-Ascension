extends Node

const TIER_FULL := 0
const TIER_MID := 1
const TIER_FAR := 2

@export_range(0, 512, 1) var full_budget: int = 32
@export_range(0, 1024, 1) var mid_budget: int = 48
@export_range(0.05, 2.0, 0.01) var assignment_interval: float = 0.20
@export_range(1, 8, 1) var mid_group_count: int = 2
@export_range(1, 16, 1) var far_group_count: int = 6
@export_range(1.0, 33.0, 0.25) var physics_pressure_ms: float = 8.0

var _previous_tiers: Dictionary = {}
var _debug_counters := {
	"full": 0,
	"mid": 0,
	"far": 0,
	"protected": 0,
	"physics_enabled": 0,
	"mid_steps": 0,
	"far_steps": 0,
	"assignment_usec": 0,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(false)


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
		var candidate := {
			"node": enemy,
			"id": enemy_id,
			"distance_squared": distance_squared,
			"priority": _priority_for(enemy, player_position, distance_squared),
			"previous_tier": int(_previous_tiers.get(enemy_id, TIER_FAR)),
		}
		if _is_protected(enemy, sqrt(distance_squared)):
			protected_candidates.append(candidate)
		else:
			ordinary_candidates.append(candidate)

	ordinary_candidates.sort_custom(_candidate_before)

	var assignment: Dictionary = {}
	for candidate in protected_candidates:
		assignment[int(candidate["id"])] = TIER_FULL

	var full_count := mini(maxi(0, full_budget), ordinary_candidates.size())
	var mid_count := mini(
		maxi(0, mid_budget),
		maxi(0, ordinary_candidates.size() - full_count)
	)
	for index in range(ordinary_candidates.size()):
		var tier := TIER_FAR
		if index < full_count:
			tier = TIER_FULL
		elif index < full_count + mid_count:
			tier = TIER_MID
		assignment[int(ordinary_candidates[index]["id"])] = tier

	_previous_tiers.clear()
	for enemy_id in assignment:
		_previous_tiers[enemy_id] = int(assignment[enemy_id])

	_debug_counters["full"] = full_count + protected_candidates.size()
	_debug_counters["mid"] = mid_count
	_debug_counters["far"] = maxi(0, ordinary_candidates.size() - full_count - mid_count)
	_debug_counters["protected"] = protected_candidates.size()
	_debug_counters["physics_enabled"] = int(_debug_counters["full"]) + mid_count
	_debug_counters["assignment_usec"] = Time.get_ticks_usec() - started_usec
	return assignment


func refresh_assignments() -> void:
	# Runtime tier application and reduced tick groups are introduced in the next
	# tested step. Keeping this entry point now makes the assignment contract
	# usable without coupling the pure planner to the SceneTree.
	pass


func get_debug_counters() -> Dictionary:
	return _debug_counters.duplicate(true)


func is_under_physics_pressure() -> bool:
	return Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0 > physics_pressure_ms


func _is_valid_candidate(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.is_queued_for_deletion() or not enemy.is_inside_tree():
		return false
	return not ("dead" in enemy and bool(enemy.get("dead")))


func _priority_for(enemy: Node, player_position: Vector2, distance_squared: float) -> float:
	if enemy.has_method("simulation_priority"):
		return float(enemy.call("simulation_priority", player_position))
	return -distance_squared


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
