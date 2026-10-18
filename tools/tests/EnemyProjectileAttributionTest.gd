extends Node
## Telemetry must retain a hostile projectile's firing identity after its
## actor is gone, without changing the existing batched damage operation.
const PLAYER := preload("res://core/actors/player/player.tscn")
const MANAGER := preload("res://core/combat/projectile/ProjectileSimulationManager.gd")
const TRAUMA := preload("res://effects/items/logic/TraumaEffect.gd")

class LegacyTarget:
	extends Node2D
	var calls := 0
	var lost := 0.0
	func take_damage(amount: float, _source: Node = null) -> void:
		calls += 1
		lost += amount

var _passes := 0
var _failures := 0
var _player: CharacterBody2D
var _manager: ProjectileSimulationManager
var _resolved: Array[Dictionary] = []
var _health: Array[Dictionary] = []
var _reenter := false


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _context() -> Dictionary:
	return _player.call("get_balance_damage_context") as Dictionary if _player.has_method("get_balance_damage_context") else {}


func _on_resolved(who: Node, raw: float, adjusted: float, applied: float, source: Node, kind: StringName, outcome: StringName) -> void:
	if who != _player:
		return
	_resolved.append({"raw": raw, "adjusted": adjusted, "applied": applied,
		"source": source, "kind": kind, "outcome": outcome, "context": _context()})
	if _reenter:
		_reenter = false
		_player.call("_take_damage", 2.0, null, &"self_damage")
		_check(String(_context().get("source_id", "")) == "enemy_spitter", "an outer context survives a nested ordinary damage call")


func _on_health(who: Node, change: Dictionary) -> void:
	if who == _player:
		_health.append({"change": change.duplicate(), "context": _context()})


func _reset() -> void:
	_manager.clear_for_run_end()
	_player.heal(200.0, &"fixture_reset")
	_player.invulnerable_time = 0.0
	_resolved.clear()
	_health.clear()


func _spawn(id: StringName, damage: float, source: Node = null) -> void:
	_check(_manager.spawn_enemy(_player.position - Vector2(100, 0), Vector2.RIGHT,
		1000.0, damage, 3.0, source, id), "hostile projectile enters the real simulation")


func _impact() -> void:
	# Descending slots keep swap-removal from skipping another projectile.
	while _manager.active_count() > 0:
		_manager.call("_simulate_one", _manager.active_count() - 1, 0.2)
	_manager.call("_flush_hit_ledgers")


func _members(context: Dictionary) -> PackedStringArray:
	return PackedStringArray(context.get("member_ids", PackedStringArray()))


func _run() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.debug_player_god_mode = false
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.run_luck = 0.0
	ProjectileManager.set_process(false)
	ProjectileManager.set_physics_process(false)
	ProjectileManager.clear_for_run_end()
	_player = PLAYER.instantiate()
	add_child(_player)
	await get_tree().process_frame
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_player.stats = Stats.new()
	_player.stats.armor = 100.0
	_player.max_hp = 200.0
	_player.hp = 200.0
	_player.big_hit_protection = true
	_player.big_hit_ratio = 1.0 # Keep post-hit grace out of the nested fixture.
	_player.invulnerable_time = 0.0
	var ier := _player.get_node("ItemEffectRunner") as ItemEffectRunner
	ier.call("_clear_all")
	var trauma := TRAUMA.new()
	trauma.setup_with_item(_player, null, 6)
	ier.add_child(trauma)
	trauma.learned_category = &"unknown"
	ier._active_effects[&"attribution_fixture"] = trauma
	_manager = MANAGER.new()
	add_child(_manager)
	_manager.set_process(false)
	_manager.set_physics_process(false)
	_manager.debug_disable_impacts = true
	_manager.set("_player", _player)
	var recorder := BalanceRecorder
	recorder.report_directory = "user://enemy_projectile_attribution_%d" % Time.get_ticks_usec()
	recorder.record_headless = true
	recorder.begin_gameplay(_player)
	recorder.set_process(false)
	RunEvents.player_damage_resolved.connect(_on_resolved)
	RunEvents.balance_health_changed.connect(_on_health)

	# Reference operation: the current manager delivers one total with its
	# chosen source. Its single cap/armour/Trauma evaluation must stay exact.
	_player.take_damage(100.0, null)
	var reference_loss: float = 200.0 - _player.hp
	_check(is_equal_approx(reference_loss, 21.0), "reference batch applies one 60-raw cap, unknown-source Trauma and 100 armour")
	_reset()
	var shooter := Node2D.new()
	add_child(shooter)
	_spawn(&"enemy_spitter", 80.0, shooter)
	_spawn(&"enemy_spitter", 20.0, shooter)
	shooter.free()
	_impact()
	_check(is_equal_approx(200.0 - _player.hp, reference_loss), "freed-shooter attribution preserves the exact reference HP loss")
	_check(_resolved.size() == 1 and _health.size() == 1 and _resolved[0].raw == 100.0
		and _resolved[0].source == null and _resolved[0].kind == &"unknown",
		"two impacts remain one unchanged source/kind/raw batch and one health change")
	var context: Dictionary = _resolved[0].context if not _resolved.is_empty() else {}
	_check(String(context.get("source_id", "")) == "enemy_spitter" and _members(context) == PackedStringArray(["enemy_spitter"])
		and int(context.get("hit_count", 0)) == 2, "same-origin impacts retain one honest enemy identity and both hit contributions")
	_check(not _health.is_empty() and _health[0].context == context and _context().is_empty(),
		"canonical health and resolved damage see the same temporary context, then it clears")
	var summary: Dictionary = recorder.get_summary()
	_check(is_equal_approx(float(summary.totals.player_damage_by_source.get("enemy_spitter", 0.0)), reference_loss),
		"the actual recorder attributes the freed-shooter health loss to its retained identity")
	_check(is_equal_approx(float(summary.health.current_life.by_source.get("enemy_spitter", 0.0)), -reference_loss),
		"the health-reconciliation source uses the same retained identity")
	_check(trauma.learned_category == &"unknown", "telemetry identity cannot change Trauma's existing gameplay category")
	_check(is_equal_approx(float(summary.health.current_life.expected_hp), _player.hp),
		"the real health ledger reconciles the attributed impact with observed HP")

	_reset()
	var boss := Node2D.new()
	add_child(boss)
	boss.add_to_group(&"boss")
	_player.take_damage(100.0, boss)
	var boss_reference_loss: float = 200.0 - _player.hp
	_reset()
	_spawn(&"boss_arcanist", 100.0, boss)
	_impact()
	_check(is_equal_approx(boss_reference_loss, 31.5) and is_equal_approx(200.0 - _player.hp, boss_reference_loss)
		and _resolved.size() == 1 and _resolved[0].source == boss and _resolved[0].kind == &"unknown",
		"a living boss Node retains its original larger cap, source, kind and Trauma result")
	boss.free()

	_reset()
	_spawn(&"enemy_spitter", 12.0)
	_spawn(&"enemy_herald", 8.0)
	_impact()
	context = _resolved[0].context if not _resolved.is_empty() else {}
	var members := _members(context)
	_check(String(context.get("source_id", "")) == "mixed" and members.size() == 2
		and members.has("enemy_spitter") and members.has("enemy_herald"),
		"a mixed-source batch names both identities without assigning the entire batch to one")
	_check(_resolved.size() == 1 and _resolved[0].raw == 20.0 and is_equal_approx(200.0 - _player.hp, 7.0),
		"mixed telemetry preserves the existing single damage batch and defences (loss %.6f; %s)" % [200.0 - _player.hp, str(_resolved)])

	_reset()
	_spawn(&"enemy_spitter", 5.0)
	_spawn(&"", 5.0)
	_impact()
	context = _resolved[0].context if not _resolved.is_empty() else {}
	_check(String(context.get("source_id", "")) == "mixed" and _members(context).has("unknown"),
		"an unavailable member remains explicitly unknown inside a mixed batch")

	# Swapped and reused slots must never inherit a previous firing identity.
	_reset()
	_spawn(&"enemy_spitter", 5.0)
	_spawn(&"enemy_herald", 5.0)
	_manager.call("_remove", 0)
	_impact()
	_check(not _resolved.is_empty() and String((_resolved[0].context as Dictionary).get("source_id", "")) == "enemy_herald",
		"swap-removal moves the surviving projectile's telemetry identity")
	_reset()
	_spawn(&"", 5.0)
	_impact()
	_check(not _resolved.is_empty() and String((_resolved[0].context as Dictionary).get("source_id", "")) == "unknown",
		"a reused slot clears stale enemy ancestry")

	_reset()
	for index in range(20):
		_spawn(StringName("enemy_fixture_%d" % index), 1.0)
	_impact()
	context = _resolved[0].context if not _resolved.is_empty() else {}
	_check(String(context.get("source_id", "")) == "mixed" and _members(context).size() == 16
		and bool(context.get("members_overflow", false)) and int(context.get("hit_count", 0)) == 20,
		"member identities stay bounded while all twenty original damage contributions remain")
	_reset()
	_spawn(&"", 1.0) # Descending simulation meets this after the named members.
	for index in range(20):
		_spawn(StringName("enemy_fixture_%d" % index), 1.0)
	_impact()
	context = _resolved[0].context if not _resolved.is_empty() else {}
	_check(_members(context).size() == 16 and _members(context).has("unknown")
		and bool(context.get("members_overflow", false)) and int(context.get("hit_count", 0)) == 21,
		"an unknown contributor remains explicit even when it arrives after the member cap")

	_reset()
	_reenter = true
	_spawn(&"enemy_spitter", 10.0)
	_impact()
	_check(_resolved.size() == 2 and (_resolved[1].context as Dictionary).is_empty()
		and _resolved[1].kind == &"self_damage" and _context().is_empty(),
		"nested ordinary damage cannot inherit projectile attribution and the context stack empties")

	var legacy := LegacyTarget.new()
	add_child(legacy)
	_manager.clear_for_run_end()
	_manager.set("_player", legacy)
	_manager.spawn_enemy(Vector2(-100, 0), Vector2.RIGHT, 1000.0, 5.0, 3.0, null, &"enemy_spitter")
	_impact()
	_check(legacy.calls == 1 and is_equal_approx(legacy.lost, 5.0), "a two-argument legacy target keeps its existing delivery API")
	legacy.queue_free()
	_manager.set("_player", _player)

	RunEvents.player_damage_resolved.disconnect(_on_resolved)
	RunEvents.balance_health_changed.disconnect(_on_health)
	recorder.end_capture("suspended")
	recorder.flush_reports()
	_reset()
	_spawn(&"enemy_spitter", 5.0)
	_manager.call("_simulate_one", 0, 0.2)
	var pending: Dictionary = _manager.get("_pending_ledgers")
	var no_context := true
	for value: HitLedger in pending.values():
		for contribution: Dictionary in value.contributions:
			no_context = no_context and not contribution.has("balance_source_id")
	_check(no_context, "unrecorded damage does not write incoming telemetry into hit contributions")
	_manager.call("_flush_hit_ledgers")
	_manager.queue_free()
	_player.queue_free()
	await get_tree().process_frame
	print("EnemyProjectileAttributionTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
