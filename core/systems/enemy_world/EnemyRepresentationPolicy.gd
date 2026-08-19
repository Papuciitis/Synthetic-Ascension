class_name EnemyRepresentationPolicy
extends RefCounted

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")

const HARD_BUDGET_CEILING := 96
const CHASE_AI_KIND := 0
const REQUIRED_FLAGS := (
	Types.Flags.ELITE
	| Types.Flags.CRITICAL
	| Types.Flags.OBJECTIVE
	| Types.Flags.TUTORIAL
	| Types.Flags.NEVER_RETIRE
	| Types.Flags.SPECIAL
)

var materialized_budget := 64
var activation_distance := 480.0
var deactivation_distance := 640.0
var max_promotions_per_step := 4
var max_demotions_per_step := 4

var _world: EnemyWorldService = null
var _player_position := Vector2.ZERO
var _all_handles: Array[int] = []
var _required_promotions: Array[int] = []
var _ambient_promotions: Array[int] = []
var _demotion_candidates: Array[int] = []


func effective_budget() -> int:
	return clampi(materialized_budget, 1, HARD_BUDGET_CEILING)


func is_proxy_eligible(world: EnemyWorldService, handle: int) -> bool:
	if world == null or not world.is_valid_handle(handle) or world.is_dying(handle):
		return false
	return (
		world.get_ai_kind(handle) == CHASE_AI_KIND
		and (world.get_flags(handle) & REQUIRED_FLAGS) == 0
	)


func evaluate(
	world: EnemyWorldService,
	player_position: Vector2,
	promotions: Array[int],
	demotions: Array[int],
) -> Dictionary:
	promotions.clear()
	demotions.clear()
	_clear_buffers()
	_world = world
	_player_position = player_position
	if world == null:
		return _counters(0, 0)

	world.active_handles(_all_handles)
	var materialized_count := 0
	var activation_squared := maxf(activation_distance, 0.0) ** 2
	for handle in _all_handles:
		if world.is_dying(handle):
			continue
		var representation := world.get_representation(handle)
		var proxy_eligible := is_proxy_eligible(world, handle)
		if representation == Types.Representation.MATERIALIZED:
			materialized_count += 1
			if proxy_eligible:
				_demotion_candidates.append(handle)
		elif representation == Types.Representation.DATA_ONLY:
			if not proxy_eligible:
				_required_promotions.append(handle)
			elif player_position.distance_squared_to(world.get_position(handle)) <= activation_squared:
				_ambient_promotions.append(handle)

	_required_promotions.sort_custom(_required_before)
	_ambient_promotions.sort_custom(_nearer_first)
	_demotion_candidates.sort_custom(_farther_first)

	var projected := materialized_count
	var deactivation_squared := maxf(deactivation_distance, activation_distance) ** 2
	var demotion_limit := maxi(0, max_demotions_per_step)
	for handle in _demotion_candidates:
		if demotions.size() >= demotion_limit:
			break
		if player_position.distance_squared_to(world.get_position(handle)) > deactivation_squared:
			demotions.append(handle)
			projected -= 1

	var budget := effective_budget()
	for handle in _required_promotions:
		if projected >= budget:
			projected = _make_required_room(projected, budget, demotions, demotion_limit)
		if projected >= budget:
			break
		promotions.append(handle)
		projected += 1

	while projected > budget and demotions.size() < demotion_limit:
		var demoted := _append_next_demotion(demotions)
		if not demoted:
			break
		projected -= 1

	var ambient_promotions_added := 0
	var promotion_limit := maxi(0, max_promotions_per_step)
	for handle in _ambient_promotions:
		if projected >= budget or ambient_promotions_added >= promotion_limit:
			break
		promotions.append(handle)
		ambient_promotions_added += 1
		projected += 1

	return _counters(materialized_count, projected)


func _make_required_room(
	projected: int,
	budget: int,
	demotions: Array[int],
	demotion_limit: int,
) -> int:
	if projected < budget or demotions.size() >= demotion_limit:
		return projected
	if _append_next_demotion(demotions):
		return projected - 1
	return projected


func _append_next_demotion(demotions: Array[int]) -> bool:
	for handle in _demotion_candidates:
		if not demotions.has(handle):
			demotions.append(handle)
			return true
	return false


func _required_before(a: int, b: int) -> bool:
	var a_flags := _world.get_flags(a)
	var b_flags := _world.get_flags(b)
	var a_critical := (a_flags & (Types.Flags.CRITICAL | Types.Flags.OBJECTIVE | Types.Flags.TUTORIAL | Types.Flags.NEVER_RETIRE)) != 0
	var b_critical := (b_flags & (Types.Flags.CRITICAL | Types.Flags.OBJECTIVE | Types.Flags.TUTORIAL | Types.Flags.NEVER_RETIRE)) != 0
	if a_critical != b_critical:
		return a_critical
	return _nearer_first(a, b)


func _nearer_first(a: int, b: int) -> bool:
	return _player_position.distance_squared_to(_world.get_position(a)) < _player_position.distance_squared_to(_world.get_position(b))


func _farther_first(a: int, b: int) -> bool:
	return _player_position.distance_squared_to(_world.get_position(a)) > _player_position.distance_squared_to(_world.get_position(b))


func _clear_buffers() -> void:
	_all_handles.clear()
	_required_promotions.clear()
	_ambient_promotions.clear()
	_demotion_candidates.clear()


func _counters(materialized: int, projected: int) -> Dictionary:
	return {
		"budget": effective_budget(),
		"materialized": materialized,
		"projected_materialized": projected,
		"required_waiting": _required_promotions.size(),
		"ambient_waiting": _ambient_promotions.size(),
	}
