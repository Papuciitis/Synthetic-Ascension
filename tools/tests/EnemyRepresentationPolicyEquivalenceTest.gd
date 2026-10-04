extends Node

## The representation policy's single-pass evaluate (FPS audit 2026-10-04,
## item 2) must make exactly the choices the sort-based one made. This test
## keeps a verbatim copy of the old algorithm and compares promotions,
## demotions (order included) and every counter over randomized worlds:
## mixed representations, dying records, smart archetypes, protected flags,
## tight and loose budgets, backlog bursts and calm steps. Distances are
## random floats, so exact ties only occur in the small explicit tie cases,
## where the old insertion sort (<= 16 elements) is stable and the new
## selection must keep the same first-come order.

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const WorldScript = preload("res://core/systems/enemy_world/EnemyWorld.gd")
const PolicyScript = preload("res://core/systems/enemy_world/EnemyRepresentationPolicy.gd")


## The pre-2026-10-04 evaluate(), copied verbatim (only renamed).
class ReferencePolicy:
	extends RefCounted

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
	var backlog_burst_multiplier := 4

	var _world: EnemyWorldService = null
	var _player_position := Vector2.ZERO
	var _all_handles: Array[int] = []
	var _required_promotions: Array[int] = []
	var _ambient_promotions: Array[int] = []
	var _demotion_candidates: Array[int] = []
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
		_world = world
		_player_position = player_position
		if world == null:
			return _counters(0, 0)

		world.active_handles(_all_handles)
		var materialized_count := 0
		var activation_squared := maxf(activation_distance, 0.0) ** 2
		var deactivation_squared := maxf(deactivation_distance, activation_distance) ** 2
		for handle in _all_handles:
			if world.is_dying(handle):
				continue
			var representation := world.get_representation(handle)
			var proxy_eligible := is_proxy_eligible(world, handle)
			if representation == Types.Representation.MATERIALIZED:
				materialized_count += 1
				if proxy_eligible:
					_demotion_candidates.append(handle)
					if player_position.distance_squared_to(world.get_position(handle)) > deactivation_squared:
						_reason_beyond_band += 1
					else:
						_reason_in_band += 1
				elif world.get_ai_kind(handle) != CHASE_AI_KIND:
					_reason_required_kind += 1
				else:
					_reason_required_flag += 1
			elif representation == Types.Representation.DATA_ONLY:
				if not proxy_eligible:
					_required_promotions.append(handle)
				elif player_position.distance_squared_to(world.get_position(handle)) <= activation_squared:
					_ambient_promotions.append(handle)

		_required_promotions.sort_custom(_required_before)
		_ambient_promotions.sort_custom(_nearer_first)
		_demotion_candidates.sort_custom(_farther_first)

		var projected := materialized_count
		var demotion_limit := maxi(0, max_demotions_per_step)
		var over_budget := materialized_count - effective_budget()
		if over_budget > 0:
			demotion_limit = clampi(over_budget, demotion_limit, demotion_limit * maxi(1, backlog_burst_multiplier))
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

		return _counters(materialized_count, projected, demotions.size())

	func _make_required_room(projected: int, budget: int, demotions: Array[int], demotion_limit: int) -> int:
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


var _passes := 0
var _failures := 0
var _rng := RandomNumberGenerator.new()
var _compared_promotions := 0
var _compared_demotions := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


const FLAG_CHOICES := [
	Types.Flags.ELITE,
	Types.Flags.CRITICAL | Types.Flags.NEVER_RETIRE,
	Types.Flags.OBJECTIVE,
	Types.Flags.TUTORIAL,
	Types.Flags.SPECIAL,
	Types.Flags.NEVER_RETIRE,
]


func _populate(world: Node, count: int, player: Vector2, scenario: Dictionary) -> void:
	var smart_share := float(scenario.get("smart_share", 0.3))
	var flag_share := float(scenario.get("flag_share", 0.1))
	var materialized_share := float(scenario.get("materialized_share", 0.4))
	var dying_share := float(scenario.get("dying_share", 0.05))
	var radius := float(scenario.get("radius", 1200.0))
	for index in range(count):
		var angle := _rng.randf() * TAU
		var distance := _rng.randf_range(0.0, radius)
		var position := player + Vector2.RIGHT.rotated(angle) * distance
		var ai_kind := 0 if _rng.randf() >= smart_share else _rng.randi_range(1, 10)
		var flags := 0
		if _rng.randf() < flag_share:
			flags = int(FLAG_CHOICES[_rng.randi_range(0, FLAG_CHOICES.size() - 1)])
		var handle := int(world.call("create_enemy", SpawnState.new(
			&"eq_%d" % index, "res://eq.tscn", position, 20.0, 75.0, 8.0, ai_kind, flags,
		)))
		var roll := _rng.randf()
		if roll < dying_share:
			world.call("set_health", handle, 0.0)
			world.call("try_begin_death", handle)
		elif roll < dying_share + materialized_share:
			world.call("set_representation", handle, Types.Representation.MATERIALIZED)
	# Churn the slot order the way play does: remove a few, add a few.
	var handles: Array[int] = []
	world.call("active_handles", handles)
	for index in range(handles.size()):
		if _rng.randf() < 0.08:
			world.call("remove_enemy", handles[index], &"churn")


func _configure(policy: RefCounted, scenario: Dictionary) -> void:
	policy.set("materialized_budget", int(scenario.get("budget", 64)))
	policy.set("max_promotions_per_step", int(scenario.get("promotions", 4)))
	policy.set("max_demotions_per_step", int(scenario.get("demotions", 4)))
	policy.set("backlog_burst_multiplier", int(scenario.get("burst", 4)))
	policy.set("activation_distance", float(scenario.get("activation", 480.0)))
	policy.set("deactivation_distance", float(scenario.get("deactivation", 640.0)))


func _compare(world: Node, player: Vector2, scenario: Dictionary, label: String) -> bool:
	var reference := ReferencePolicy.new()
	var policy := PolicyScript.new()
	_configure(reference, scenario)
	_configure(policy, scenario)
	var ref_promotions: Array[int] = []
	var ref_demotions: Array[int] = []
	var new_promotions: Array[int] = []
	var new_demotions: Array[int] = []
	var ref_counters := reference.evaluate(world as EnemyWorldService, player, ref_promotions, ref_demotions)
	var new_counters := policy.call("evaluate", world, player, new_promotions, new_demotions) as Dictionary
	var same := ref_promotions == new_promotions and ref_demotions == new_demotions and ref_counters == new_counters
	_compared_promotions += ref_promotions.size()
	_compared_demotions += ref_demotions.size()
	if not same:
		push_error("%s mismatch\n  ref promotions %s\n  new promotions %s\n  ref demotions %s\n  new demotions %s\n  ref %s\n  new %s" % [
			label, str(ref_promotions), str(new_promotions), str(ref_demotions), str(new_demotions), str(ref_counters), str(new_counters),
		])
	return same


func _run() -> void:
	_rng.seed = 20261004
	var scenarios: Array[Dictionary] = [
		{"name": "calm horde under budget", "count": 40, "budget": 64},
		{"name": "250 chase, budget full (the audit's 186 waiting)", "count": 250, "budget": 64, "smart_share": 0.0, "flag_share": 0.0, "materialized_share": 0.27, "radius": 700.0},
		{"name": "minute-14 mix, mostly smart", "count": 160, "budget": 64, "smart_share": 0.6, "materialized_share": 0.8},
		{"name": "over budget backlog burst", "count": 200, "budget": 24, "materialized_share": 0.7},
		{"name": "tight budget, protected records waiting", "count": 120, "budget": 8, "flag_share": 0.4, "materialized_share": 0.2},
		{"name": "many promotions per step", "count": 180, "budget": 96, "promotions": 32, "demotions": 2},
		{"name": "no demotions allowed", "count": 150, "budget": 30, "demotions": 0},
		{"name": "no promotions allowed", "count": 150, "budget": 90, "promotions": 0},
		{"name": "inverted bands (deactivation inside activation)", "count": 150, "budget": 40, "activation": 700.0, "deactivation": 300.0},
		{"name": "everything far away", "count": 120, "budget": 32, "radius": 5000.0},
		{"name": "budget of one", "count": 90, "budget": 1, "materialized_share": 0.5},
		{"name": "heavy dying share", "count": 140, "budget": 48, "dying_share": 0.4},
	]
	var mismatches := 0
	var evaluations := 0
	for scenario in scenarios:
		for repeat in range(12):
			var world := WorldScript.new()
			add_child(world)
			var player := Vector2(_rng.randf_range(-3000.0, 3000.0), _rng.randf_range(-3000.0, 3000.0))
			_populate(world, int(scenario["count"]), player, scenario)
			evaluations += 1
			if not _compare(world, player, scenario, "%s #%d" % [scenario["name"], repeat]):
				mismatches += 1
			world.queue_free()
		_check(mismatches == 0, "%s: identical promotions, demotions and counters (12 random worlds)" % scenario["name"])
	_check(evaluations == scenarios.size() * 12, "%d randomized evaluations compared" % evaluations)
	_check(_compared_promotions > 500 and _compared_demotions > 500, "the comparisons exercised real choices (%d promotions, %d demotions)" % [_compared_promotions, _compared_demotions])

	# Ties in the small lists the old insertion sort kept stable: equal
	# distances must keep first-come order in every list.
	var tie_world := WorldScript.new()
	add_child(tie_world)
	for index in range(6):
		var tie_handle := int(tie_world.call("create_enemy", SpawnState.new(&"tie_m_%d" % index, "res://eq.tscn", Vector2(900.0, 0.0).rotated(float(index)), 20.0, 75.0, 8.0, 0, 0)))
		tie_world.call("set_representation", tie_handle, Types.Representation.MATERIALIZED)
	for index in range(6):
		tie_world.call("create_enemy", SpawnState.new(&"tie_a_%d" % index, "res://eq.tscn", Vector2(300.0, 0.0).rotated(float(index)), 20.0, 75.0, 8.0, 0, 0))
	for index in range(5):
		tie_world.call("create_enemy", SpawnState.new(&"tie_r_%d" % index, "res://eq.tscn", Vector2(200.0, 0.0).rotated(float(index)), 20.0, 75.0, 8.0, 3, 0))
	_check(_compare(tie_world, Vector2.ZERO, {"budget": 6, "promotions": 3, "demotions": 2}, "ties: tight budget"), "equal distances keep first-come order (tight budget)")
	_check(_compare(tie_world, Vector2.ZERO, {"budget": 40, "promotions": 4, "demotions": 4}, "ties: open budget"), "equal distances keep first-come order (open budget)")
	_check(_compare(tie_world, Vector2.ZERO, {"budget": 3, "promotions": 4, "demotions": 16}, "ties: over budget"), "equal distances keep first-come order (over budget)")
	tie_world.queue_free()

	# The fast path the audit asked for: with the budget full the ambient
	# list is counted but never ordered, and the choices still match.
	var full_world := WorldScript.new()
	add_child(full_world)
	_rng.seed = 7
	_populate(full_world, 250, Vector2.ZERO, {"smart_share": 0.0, "flag_share": 0.0, "materialized_share": 0.3, "dying_share": 0.0, "radius": 600.0})
	var policy := PolicyScript.new()
	var promotions: Array[int] = []
	var demotions: Array[int] = []
	var counters := policy.call("evaluate", full_world, Vector2.ZERO, promotions, demotions) as Dictionary
	_check(int(counters.get("ambient_waiting", 0)) > 64, "the full-budget world has a long ambient queue (%d waiting)" % int(counters.get("ambient_waiting", 0)))
	_check(_compare(full_world, Vector2.ZERO, {}, "full budget defaults"), "full-budget choices match the sort-based policy")
	var started := Time.get_ticks_usec()
	for _i in range(20):
		policy.call("evaluate", full_world, Vector2.ZERO, promotions, demotions)
	var new_usec := float(Time.get_ticks_usec() - started) / 20.0
	var reference := ReferencePolicy.new()
	started = Time.get_ticks_usec()
	for _i in range(20):
		reference.evaluate(full_world as EnemyWorldService, Vector2.ZERO, promotions, demotions)
	var old_usec := float(Time.get_ticks_usec() - started) / 20.0
	print("EnemyRepresentationPolicyEquivalenceTest: evaluate at 250 alive: sort-based %.0f us, single-pass %.0f us (%.1fx)" % [old_usec, new_usec, old_usec / maxf(new_usec, 1.0)])
	_check(new_usec < old_usec, "the single-pass evaluate is faster than the sort-based one")
	full_world.queue_free()

	print("EnemyRepresentationPolicyEquivalenceTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
