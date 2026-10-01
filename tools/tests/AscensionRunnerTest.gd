extends Node

# The advancement tree's shared combat contract on a real player: tagged hits
# arrive as parsed records with pre-hit health and overkill, the lethal hit
# travels with the death, untagged status ticks are still seen, managed
# projectiles carry their tags through the simulation, named rolls respect
# the cap and the modifier chain, pay_health floors at 1 HP without waking the
# on-damage rules, and the Q/V slots appear only when something is equipped.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionRunnerTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

var _passes := 0
var _failures := 0
var _hits: Array[Dictionary] = []
var _kills: Array = []
var _damage_taken := 0
var _paid: Array = []


## An engine whose tick takes a known time, to check the per-engine clock.
class SlowEngine:
	extends AscensionEngine
	var busy_usec := 0
	var cost := {"fragment_usec": 5}
	var clears_engines := false
	func discipline() -> String:
		return "ZZ"
	func frame_cost() -> Dictionary:
		return cost
	func tick(_delta: float) -> void:
		var until := Time.get_ticks_usec() + busy_usec
		while Time.get_ticks_usec() < until:
			pass
		if clears_engines:
			runner.engines.clear()


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _spawn_enemy(hp: float, at: Vector2, flags: int = 0) -> int:
	return EnemyWorld.create_enemy(SpawnState.new(&"asc_test", "res://asc_test.tscn", at, hp, 10.0, 8.0, 0, flags))


func _run() -> void:
	Global.selected_style_id = "melee"
	Global.attempt_ascension = AscensionLedger.fresh_state("melee")
	var ledger := Global.ascension_ledger()
	ledger.record_purchase("EX01", 0)

	var player: Node2D = PLAYER_SCENE.instantiate()
	add_child(player)
	# Two frames: the projectile manager clears its pool on the first frame it
	# sees a new current scene, and this whole test would otherwise run in
	# frame zero.
	await get_tree().process_frame
	await get_tree().process_frame
	var runner := player.get_node_or_null("AscensionRunner") as AscensionRunner
	_check(runner != null, "the player carries an AscensionRunner")
	if runner == null:
		_finish()
		return
	runner.refresh()
	runner.hit_resolved.connect(func(hit: Dictionary) -> void: _hits.append(hit))
	runner.kill_resolved.connect(func(hit: Dictionary, context: RefCounted) -> void: _kills.append([hit, context]))
	RunEvents.player_damage_taken.connect(func(_p: Node, _a: float, _pos: Vector2) -> void: _damage_taken += 1)
	RunEvents.player_paid_health.connect(func(_p: Node, amount: float, reason: StringName) -> void: _paid.append([amount, reason]))

	_check(runner.native_core == "melee" and runner.active("EX01"), "the runner reads the native Core and the owned starter")
	_check(RunEvents.enemy_damaged.has_connections(), "an owned node wires the runner to enemy_damaged")

	# --- tagged hits through the damage funnel
	var handle := _spawn_enemy(30.0, Vector2(100, 0))
	var tags := AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "EXQ", "slash", 1, 0.5, PackedStringArray(["execute"]))
	runner.damage_enemy(handle, 12.0, tags)
	_check(_hits.size() == 1, "one hit record per damage application (%d)" % _hits.size())
	if _hits.size() == 1:
		var hit := _hits[0]
		_check(hit["core"] == "melee" and hit["family"] == "tree" and hit["root"] == "EXQ" and hit["path"] == "slash" and hit["gen"] == 1, "tags parse into core / family / root / path / gen")
		_check(is_equal_approx(hit["pp"], 0.5) and AscensionTags.has_flag(hit["tags"], "execute"), "Proc Power and flags survive the round trip")
		_check(is_equal_approx(hit["before"], 30.0) and is_equal_approx(hit["after"], 18.0) and not hit["lethal"], "the record carries pre-hit and post-hit health")
		_check(is_equal_approx(hit["fraction_after"], 0.6) and hit["is_normal"], "HP fraction and normal/elite/boss classification are attached")
	runner.status_of(handle)["marked"] = 1.0
	runner.damage_enemy(handle, 40.0, AscensionTags.native("melee", "slash"))
	_check(_hits.size() == 2 and _hits[1]["lethal"] and is_equal_approx(_hits[1]["overkill"], 22.0), "a killing blow reports lethal and overkill (%s)" % str(_hits[1].get("overkill") if _hits.size() == 2 else null))
	_check(_kills.size() == 1 and _kills[0][0]["handle"] == handle and _kills[0][0]["family"] == "native", "the lethal hit record travels with enemy_defeated")
	_check(not runner.statuses.has(handle), "tree statuses clear on death")

	# --- untagged damage is still a record
	var second := _spawn_enemy(20.0, Vector2(200, 0), EnemyWorldTypes.Flags.ELITE)
	EnemyCombat.apply_status_damage(second, 5.0, player)
	_check(_hits.size() == 3 and _hits[2]["family"] == "status" and _hits[2]["is_elite"], "a status tick is an untagged record flagged elite")
	var stranger := Node.new()
	add_child(stranger)
	EnemyCombat.apply_damage(second, 1.0, 1, stranger)
	_check(_hits.size() == 3, "damage from other sources is ignored")
	EnemyWorld.remove_enemy(second, &"test")

	# --- managed projectiles carry tags through the simulation
	var target := _spawn_enemy(50.0, player.global_position + Vector2(120, 0))
	var before_bullet := _hits.size()
	var spawned := runner.spawn_bullet(player.global_position, Vector2.RIGHT, 7.0, AscensionTags.make("ranged", AscensionTags.FAMILY_TREE, "BR05", "fragment", 1, 0.4), {"speed": 900.0, "max_range": 400.0})
	_check(spawned, "the runner spawns a managed bullet with the player as source")
	for _i in range(20):
		await get_tree().physics_frame
		if _hits.size() > before_bullet:
			break
	_check(_hits.size() == before_bullet + 1 and _hits[before_bullet]["path"] == "fragment" and _hits[before_bullet]["root"] == "BR05", "a managed projectile's tags reach the hit record (%s)" % (str(_hits[before_bullet]["tags"]) if _hits.size() > before_bullet else "no hit"))
	EnemyWorld.remove_enemy(target, &"test")

	# --- named rolls
	runner.roll(&"always", 1.0)
	_check(is_equal_approx(runner.last_roll_chance, 0.95), "a certain roll is capped at 95% unless guaranteed")
	_check(runner.roll(&"forced", 0.0, 1.0, true) and is_equal_approx(runner.last_roll_chance, 1.0), "a guaranteed roll ignores the cap")
	_check(not runner.roll(&"never", 0.0), "a zero roll fails")
	runner.roll(&"scaled", 0.4, 0.5)
	_check(is_equal_approx(runner.last_roll_chance, 0.2), "Proc Power scales the chance")

	# --- pay_health
	player.hp = 10.0
	var paid: float = player.pay_health(50.0, &"tails")
	_check(is_equal_approx(paid, 9.0) and is_equal_approx(player.hp, 1.0), "pay_health floors at 1 HP (%s)" % str(paid))
	_check(_damage_taken == 0 and _paid.size() == 1 and _paid[0][1] == &"tails", "a health payment is not a hit: player_paid_health fires, player_damage_taken does not")
	_check(is_equal_approx(player.pay_health(5.0, &"tails"), 0.0), "nothing more can be paid at 1 HP")

	# --- Q / V slots
	_check(runner.get_node_or_null("QSlot") == null, "no Q slot while nothing is equipped")
	var verdict := runner.activate_q()
	_check(not verdict["ok"] and verdict["message"] == "NOTHING EQUIPPED", "activating an empty slot reports why")
	ledger.record_purchase("EX02", 200)
	ledger.record_purchase("EXQ", 800)
	runner.refresh()
	var slot := runner.get_node_or_null("QSlot") as AscensionSlotHud
	_check(slot != null and slot.hud_key_text == "Q" and slot.hud_title_text == "Gavel", "equipping Gavel creates the Q slot for the HUD")
	_check(bool(runner.slot_state("q")["ready"]), "the slot reads ready with no cooldown")
	verdict = runner.activate_q()
	_check(bool(verdict["ok"]) and verdict["message"] == "GAVEL" and runner.q_cooldown_left > 0.0, "the equipped Q reaches its engine and starts its cooldown")
	ledger.unequip("q", "EXQ")
	runner.refresh()
	await get_tree().process_frame
	_check(runner.get_node_or_null("QSlot") == null, "unequipping frees the slot")

	_check(is_equal_approx(Global.debug_enemy_hp_scale, 1.0), "the enemy HP fixture defaults to x1")

	# --- per-engine frame cost: a slow tick names its engine (2026-10-01: a
	# 299.5 ms tick with three engines active and nothing saying which).
	PerformanceFlightRecorder.set("write_reports", false)
	PerformanceFlightRecorder.set("automatic_capture", false)
	PerformanceFlightRecorder.set_enabled(true)
	var slow := SlowEngine.new()
	slow.setup(runner)
	runner.engines.append(slow)
	runner._process(0.016)
	var counters := runner.get_debug_counters()
	var engine_usec: Dictionary = counters.get("engine_usec", {})
	_check(engine_usec.has("EX") and engine_usec.has("ZZ") and engine_usec.size() == runner.engines.size(), "the frame cost carries one tick time per engine, by discipline (%s)" % str(engine_usec.keys()))
	var engine_sum := 0
	for code in engine_usec:
		engine_sum += int(engine_usec[code])
	_check(engine_sum + int(counters.get("encore_usec", 0)) == int(counters.get("tick_usec", -1)), "the engines and the Encore repeat add up to the tick exactly")
	var slow_events_before := (PerformanceFlightRecorder.get("_events") as Array).filter(func(event: Dictionary) -> bool: return String(event.get("name", "")) == "slow_tick").size()
	_check(slow_events_before == 0, "an ordinary tick records no slow_tick event")
	slow.busy_usec = AscensionRunner.SLOW_TICK_USEC + 1000
	var probe_handle := _spawn_enemy(50.0, Vector2(60, 0))
	runner.damage_enemy(probe_handle, 1.0, AscensionTags.native("melee", "slash"))
	runner.nearest_enemy(Vector2.ZERO, 200.0)
	runner._process(0.016)
	counters = runner.get_debug_counters()
	_check(int((counters.get("engine_usec", {}) as Dictionary).get("ZZ", 0)) >= AscensionRunner.SLOW_TICK_USEC and int((counters.get("engine_usec", {}) as Dictionary).get("EX", 0)) < AscensionRunner.SLOW_TICK_USEC, "the slow engine, and only it, carries the time")
	_check(int(counters.get("damage_calls", 0)) == 1 and int(counters.get("queries", 0)) >= 1, "the frame cost counts what the tree asked for (damage calls %d, queries %d)" % [int(counters.get("damage_calls", 0)), int(counters.get("queries", 0))])
	var slow_events: Array = (PerformanceFlightRecorder.get("_events") as Array).filter(func(event: Dictionary) -> bool: return String(event.get("name", "")) == "slow_tick")
	_check(slow_events.size() == 1 and int(((slow_events[0].get("details", {}) as Dictionary).get("engine_usec", {}) as Dictionary).get("ZZ", 0)) >= AscensionRunner.SLOW_TICK_USEC, "a tick over the threshold is recorded as ascension/slow_tick with the per-engine split")
	runner._process(0.016)
	_check(int(runner.get_debug_counters().get("damage_calls", -1)) == 0, "the per-frame counts reset every frame")
	# A slow stretch is one event per quarter second, not one per frame
	# (hundreds of events would be copied on the frame an incident closes);
	# a tick twice as slow as the last one recorded still gets its own.
	var count_slow := func() -> int: return (PerformanceFlightRecorder.get("_events") as Array).filter(func(event: Dictionary) -> bool: return String(event.get("name", "")) == "slow_tick").size()
	_check(int(count_slow.call()) == 1, "a second slow tick right after the first records no second event (%d)" % int(count_slow.call()))
	slow.busy_usec = (AscensionRunner.SLOW_TICK_USEC + 1000) * 3
	runner._process(0.016)
	_check(int(count_slow.call()) == 2, "a tick more than twice as slow is recorded at once (%d)" % int(count_slow.call()))
	slow.busy_usec = 0
	# An engine keeps ONE cost dictionary and rewrites it every frame. A
	# sample must hold that frame's values, not a reference to the live
	# dictionary (the 2026-10-01 captures: 62,805 rows whose fragment_usec
	# depended on when the incident was copied).
	var kept: Dictionary = runner.get_debug_counters()
	slow.cost["fragment_usec"] = 999
	_check(int((kept.get("ZZ", {}) as Dictionary).get("fragment_usec", -1)) == 5, "a sample keeps the engine's frame cost as it was, not the live dictionary")
	# An engine list emptied in place mid-tick (the runner leaving the tree,
	# a different ledger) must end the timed loop, as the plain loop did.
	slow.clears_engines = true
	runner.engines.erase(slow)
	runner.engines.insert(0, slow)
	var engines_before := runner.engines.duplicate()
	runner._process(0.016)
	_check(runner.engines.is_empty(), "a tick that empties the engine list in place ends the loop without an error")
	runner.engines.assign(engines_before)
	slow.clears_engines = false
	runner.engines.erase(slow)
	PerformanceFlightRecorder.set_enabled(false)

	Global.attempt_ascension = {}
	player.queue_free()
	_finish()


func _finish() -> void:
	print("AscensionRunnerTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
