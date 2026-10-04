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
const CRITICAL_FLAGS := (
	Types.Flags.CRITICAL
	| Types.Flags.OBJECTIVE
	| Types.Flags.TUTORIAL
	| Types.Flags.NEVER_RETIRE
)

var materialized_budget := 64
var activation_distance := 480.0
var deactivation_distance := 640.0
var max_promotions_per_step := 4
var max_demotions_per_step := 4
# When the materialized count is over budget (a spawner creating actors faster
# than four demotions per step can retire), demotion bursts toward the budget:
# up to max_demotions_per_step * backlog_burst_multiplier in one step. Within
# budget the calm rate applies.
var backlog_burst_multiplier := 4

# One evaluate() reads the world once (EnemyWorldService.gather_representation_view)
# and keeps each candidate list as parallel arrays: handles in active-slot
# order, their squared distance to the player, and a taken mark. The old
# version sorted all three lists every 0.2 s with a GDScript comparator that
# re-read positions through validated getters - 12-16 ms per call at 250
# alive (FPS audit 2026-10-04, item 2), though at most max_promotions_per_step
# ambient and demotion_limit (<= 16) demotion entries are ever consumed. Now
# each consumer takes its next entry with a linear min/max search, and the
# ambient list is not searched at all while the budget is full. The choices
# are identical, ties included: the old insertion sort was stable for the
# lists it sorted in practice, and every search keeps the first entry among
# equals (EnemyRepresentationPolicyEquivalenceTest).
var _view_handles: Array[int] = []
var _view_representations := PackedInt32Array()
var _view_ai_kinds := PackedInt32Array()
var _view_flags := PackedInt64Array()
var _view_distance_squared := PackedFloat64Array()
var _required_promotions: Array[int] = []
var _required_distance_squared := PackedFloat64Array()
var _required_critical := PackedByteArray()
var _required_taken := PackedByteArray()
var _ambient_promotions: Array[int] = []
var _ambient_distance_squared := PackedFloat64Array()
var _ambient_taken := PackedByteArray()
var _demotion_candidates: Array[int] = []
var _demotion_distance_squared := PackedFloat64Array()
var _demotion_taken := PackedByteArray()
# Why each materialized actor is materialized (roadmap 5.7), refreshed per
# evaluate(): the live-vs-benchmark comparison needs the reasons, not the count.
var _reason_required_kind := 0
var _reason_required_flag := 0
var _reason_in_band := 0
var _reason_beyond_band := 0


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
	if world == null:
		return _counters(0, 0)

	world.gather_representation_view(
		player_position,
		_view_handles,
		_view_representations,
		_view_ai_kinds,
		_view_flags,
		_view_distance_squared,
	)
	var materialized_count := 0
	var activation_squared := maxf(activation_distance, 0.0) ** 2
	var deactivation_squared := maxf(deactivation_distance, activation_distance) ** 2
	for index in range(_view_handles.size()):
		var representation := _view_representations[index]
		var ai_kind := _view_ai_kinds[index]
		var flags := _view_flags[index]
		var proxy_eligible := ai_kind == CHASE_AI_KIND and (flags & REQUIRED_FLAGS) == 0
		var distance_squared := _view_distance_squared[index]
		if representation == Types.Representation.MATERIALIZED:
			materialized_count += 1
			if proxy_eligible:
				_demotion_candidates.append(_view_handles[index])
				_demotion_distance_squared.append(distance_squared)
				if distance_squared > deactivation_squared:
					_reason_beyond_band += 1
				else:
					_reason_in_band += 1
			elif ai_kind != CHASE_AI_KIND:
				_reason_required_kind += 1
			else:
				_reason_required_flag += 1
		elif representation == Types.Representation.DATA_ONLY:
			if not proxy_eligible:
				_required_promotions.append(_view_handles[index])
				_required_distance_squared.append(distance_squared)
				_required_critical.append(1 if (flags & CRITICAL_FLAGS) != 0 else 0)
			elif distance_squared <= activation_squared:
				_ambient_promotions.append(_view_handles[index])
				_ambient_distance_squared.append(distance_squared)
	_demotion_taken.resize(_demotion_candidates.size())
	_demotion_taken.fill(0)
	_required_taken.resize(_required_promotions.size())
	_required_taken.fill(0)
	_ambient_taken.resize(_ambient_promotions.size())
	_ambient_taken.fill(0)

	var projected := materialized_count
	var demotion_limit := maxi(0, max_demotions_per_step)
	var over_budget := materialized_count - effective_budget()
	if over_budget > 0:
		demotion_limit = clampi(over_budget, demotion_limit, demotion_limit * maxi(1, backlog_burst_multiplier))
	# Farthest first, while the farthest left is beyond the deactivation band.
	while demotions.size() < demotion_limit:
		var farthest := _farthest_open_demotion()
		if farthest < 0 or _demotion_distance_squared[farthest] <= deactivation_squared:
			break
		_demotion_taken[farthest] = 1
		demotions.append(_demotion_candidates[farthest])
		projected -= 1

	var budget := effective_budget()
	for _required_index in range(_required_promotions.size()):
		if projected >= budget:
			projected = _make_required_room(projected, budget, demotions, demotion_limit)
		if projected >= budget:
			break
		var best := _best_open_required()
		_required_taken[best] = 1
		promotions.append(_required_promotions[best])
		projected += 1

	while projected > budget and demotions.size() < demotion_limit:
		var demoted := _append_next_demotion(demotions)
		if not demoted:
			break
		projected -= 1

	var ambient_promotions_added := 0
	var promotion_limit := maxi(0, max_promotions_per_step)
	while projected < budget and ambient_promotions_added < promotion_limit:
		var nearest := _nearest_open_ambient()
		if nearest < 0:
			break
		_ambient_taken[nearest] = 1
		promotions.append(_ambient_promotions[nearest])
		ambient_promotions_added += 1
		projected += 1

	return _counters(materialized_count, projected, demotions.size())


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


## The farthest demotion candidate not yet taken, whatever its band.
func _append_next_demotion(demotions: Array[int]) -> bool:
	var farthest := _farthest_open_demotion()
	if farthest < 0:
		return false
	_demotion_taken[farthest] = 1
	demotions.append(_demotion_candidates[farthest])
	return true


## Index of the farthest untaken demotion candidate (first among equals), or -1.
func _farthest_open_demotion() -> int:
	var best := -1
	var best_distance := -INF
	for index in range(_demotion_candidates.size()):
		if _demotion_taken[index] != 0:
			continue
		var distance_squared := _demotion_distance_squared[index]
		if best < 0 or distance_squared > best_distance:
			best = index
			best_distance = distance_squared
	return best


## Index of the next required promotion: critical records first, then the
## nearest (first among equals). The caller guarantees one is left.
func _best_open_required() -> int:
	var best := -1
	var best_critical := false
	var best_distance := INF
	for index in range(_required_promotions.size()):
		if _required_taken[index] != 0:
			continue
		var critical := _required_critical[index] != 0
		var distance_squared := _required_distance_squared[index]
		if best < 0 or (critical and not best_critical) or (critical == best_critical and distance_squared < best_distance):
			best = index
			best_critical = critical
			best_distance = distance_squared
	return best


## Index of the nearest untaken ambient promotion (first among equals), or -1.
func _nearest_open_ambient() -> int:
	var best := -1
	var best_distance := INF
	for index in range(_ambient_promotions.size()):
		if _ambient_taken[index] != 0:
			continue
		var distance_squared := _ambient_distance_squared[index]
		if best < 0 or distance_squared < best_distance:
			best = index
			best_distance = distance_squared
	return best


func _clear_buffers() -> void:
	_view_handles.clear()
	_required_promotions.clear()
	_required_distance_squared.clear()
	_required_critical.clear()
	_ambient_promotions.clear()
	_ambient_distance_squared.clear()
	_demotion_candidates.clear()
	_demotion_distance_squared.clear()
	_reason_required_kind = 0
	_reason_required_flag = 0
	_reason_in_band = 0
	_reason_beyond_band = 0


func _counters(materialized: int, projected: int, demoted: int = 0) -> Dictionary:
	return {
		"budget": effective_budget(),
		"materialized": materialized,
		"projected_materialized": projected,
		"required_waiting": _required_promotions.size(),
		"ambient_waiting": _ambient_promotions.size(),
		"materialized_required_kind": _reason_required_kind,
		"materialized_required_flag": _reason_required_flag,
		"materialized_in_band": _reason_in_band,
		"materialized_beyond_band": _reason_beyond_band,
		"demotion_backlog": maxi(0, _reason_beyond_band - demoted),
	}
