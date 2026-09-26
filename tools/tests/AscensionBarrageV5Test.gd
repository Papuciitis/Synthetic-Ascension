extends Node

# Ranged V5 Barrage (handoff 2026-09-25): Spin Up climbs and decays with no
# Heat bar and no Jam, Burst's x2 rides after the shot-rate cap, ranked Fifth
# Shot / Fragmentation follow their tables, Hot Rounds burns unheated through
# the named strongest-refresh burn, Hot Core is a deliberate purchase whose
# Meltdown never stops the gun, and Overload has a no-Heat trigger.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionBarrageV5Test.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

var _passes := 0
var _failures := 0
var _player: Node2D
var _runner: AscensionRunner
var _engine: BarrageEngineV5


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _spawn_enemy(hp: float, at: Vector2) -> int:
	return EnemyWorld.create_enemy(SpawnState.new(&"asc_br_v5", "res://asc_br_v5.tscn", at, hp, 10.0, 8.0, 0, 0))


func _fire() -> void:
	RunEvents.weapon_fired.emit(_player, &"ranged", _player.global_position, _player.global_position + Vector2(200, 0), 1.0, 1.0)


func _native_bullet_tags(volley: int) -> PackedStringArray:
	var tags := AscensionTags.native("ranged", "bullet")
	tags.append("volley:%d" % volley)
	return AscensionTags.with_flag(tags, "core_strike")


func _run() -> void:
	Global.selected_style_id = "ranged"
	Global.attempt_ascension = AscensionLedger.fresh_state("ranged", "v5_ranged")
	var ledger := Global.ascension_ledger()
	_check(ledger.is_v5(), "the attempt runs the V5 tree")
	ledger.record_purchase("BR01", 0)
	for id in ["BR02", "BR04", "BR05", "BR06", "BR07", "BR08", "BR11", "BRQ", "BRC"]:
		ledger.record_purchase(id, 100)
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	_check(_engine != null, "a V5 run loads BarrageEngineV5")
	if _engine == null:
		_finish()
		return
	var D := _runner.native_damage()

	# --- BR-01: no Heat without Hot Core, Spin Up stages climb and decay.
	for _i in range(8):
		_fire()
		_engine.tick(0.2)
	_check(not _engine.claims_heat() and is_zero_approx(_engine.heat), "no BR03: no Heat pool, ever (%s)" % str(_engine.heat))
	_check(int(_engine.counters["jams"]) == 0 and not _engine.jammed(), "no BR03: nothing Jams")
	_check(_engine.spin_stage() >= 2, "1.4 s of sustained fire reaches Spin Up stage 2 (%d)" % _engine.spin_stage())
	_check(is_equal_approx(_engine.haste_multiplier("ranged"), 1.0 + _engine.spin_bonus()), "the engine haste is 1 + the stage bonus")
	_engine._spin_streak = 2.4
	_engine._spin_last_input = _engine._clock
	_check(_engine.spin_stage() == 3 and is_equal_approx(_engine.spin_bonus(), 0.60), "rank-1 stage 3 gives +60%")
	# Decay: after 0.75 s of idle grace, one stage per 0.5 s.
	_engine.tick(0.8)
	_check(_engine.spin_stage() == 3, "0.8 s idle is inside the grace + first step: stage holds")
	_engine.tick(0.5)
	_check(_engine.spin_stage() == 2, "0.5 s past the grace drops one stage (%d)" % _engine.spin_stage())
	_engine.tick(0.5)
	_check(_engine.spin_stage() == 1, "another 0.5 s drops another stage")
	# A pause under 0.35 s between shots still counts as firing time.
	_engine._spin_last_input = _engine._clock
	var streak_before: float = _engine._spin_streak
	_engine.tick(0.3)
	_fire()
	_check(is_equal_approx(_engine._spin_streak, streak_before + 0.3), "a 0.3 s gap between shots accrues as firing time")

	# --- BR-02: Burst is a post-cap window, not a capped haste source.
	_check(is_equal_approx(_runner.get_post_cap_haste_multiplier(), 1.0), "no Burst: post-cap multiplier is 1")
	var verdict := _engine.activate_q("BRQ")
	_check(bool(verdict["ok"]), "Burst starts")
	_check(is_equal_approx(_runner.get_post_cap_haste_multiplier(), 2.0), "Burst supplies exactly one x2 after the cap")
	_check(_engine.haste_multiplier("ranged") < 2.0, "Burst does not also inflate the capped haste")
	_engine.tick(2.1)
	_check(_engine.burst_left <= 0.0 and int(_engine.counters["burst_rounds"]) >= 12, "Burst completes with its 12-round fan (%d)" % int(_engine.counters["burst_rounds"]))
	_check(is_equal_approx(_runner.get_post_cap_haste_multiplier(), 1.0), "the x2 ends with the window")

	# --- BR-03: Fifth Shot rank table.
	var fifths_before := int(_engine.counters["fifth_shots"])
	_engine._strike_credit = 0.0
	_engine._fifth_package = 0
	for _i in range(6):
		_fire()
	_check(int(_engine.counters["fifth_shots"]) == fifths_before + 1, "rank 1: the fifth strike arms, the sixth fires")
	(ledger.state["owned"] as Dictionary)["BR02"] = 4
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	_engine._strike_credit = 0.0
	_engine._fifth_package = 0
	fifths_before = int(_engine.counters["fifth_shots"])
	for _i in range(4):
		_fire()
	_check(int(_engine.counters["fifth_shots"]) == fifths_before + 1, "rank 4: every third strike arms four rounds")

	# --- BR-04: Fragmentation rank 4 emits five fragments per real kill.
	(ledger.state["owned"] as Dictionary)["BR05"] = 4
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	var frags_before := int(_engine.counters["fragments"])
	var victim := _spawn_enemy(4.0, _player.global_position + Vector2(100, 0))
	_runner.damage_enemy(victim, 50.0, _native_bullet_tags(900))
	_check(int(_engine.counters["fragments"]) == frags_before + 5, "a rank-4 kill releases five seeking fragments (%d)" % (int(_engine.counters["fragments"]) - frags_before))

	# --- BR-06: Hot Rounds burns without Heat, named, strongest-refresh.
	var target := _spawn_enemy(500.0, _player.global_position + Vector2(120, 0))
	for volley in range(1, 4):
		_runner.damage_enemy(target, 1.0, _native_bullet_tags(volley))
	_check(EnemyStatus.has_named_burn(target, &"hot_rounds"), "the third strike's first impact applies the named Hot Rounds burn")
	_check(not EnemyStatus.has_status(target, &"burn"), "the named burn is not the generic burn kind")
	# Strongest rate wins: a weaker reapplication cannot soften it.
	EnemyStatus.apply_named_burn(target, &"hot_rounds", 3.0, 0.5, 0.30 * D, _player)
	EnemyStatus.apply_named_burn(target, &"hot_rounds", 3.0, 0.5, 0.15 * D, _player)
	var hp_before := EnemyWorld.get_health(target)
	EnemyStatus.advance(0.51)
	var tick_damage := hp_before - EnemyWorld.get_health(target)
	_check(is_equal_approx(tick_damage, 0.30 * D * 0.5), "a weaker refresh keeps the stronger rate (tick %.2f)" % tick_damage)
	EnemyWorld.remove_enemy(target, &"test")

	# --- Kill Throttle: three stage-2 kills grant Overdrive.
	_engine._spin_streak = 2.4
	_engine._spin_last_input = _engine._clock
	var overdrives_before := int(_engine.counters.get("overdrives", 0))
	for i in range(3):
		var prey := _spawn_enemy(2.0, _player.global_position + Vector2(80 + i * 10, 0))
		_runner.damage_enemy(prey, 30.0, _native_bullet_tags(950 + i))
	_check(int(_engine.counters.get("overdrives", 0)) == overdrives_before + 1 and _engine._overdrive_left > 0.0, "three kills at stage 2+ grant Overdrive")

	# --- BR-10: Reserve Feed works with no Heat.
	_engine.stored_rounds = 0
	_engine._reserve_credit = 0.0
	_engine._reserve_release_inputs = 0
	for _i in range(6):
		_fire()
	_check(_engine.stored_rounds >= 2, "six inputs store two reserve rounds (%d)" % _engine.stored_rounds)
	var stored_fired_before := int(_engine.counters["stored_fired"])
	for _i in range(6):
		_fire()
	_check(int(_engine.counters["stored_fired"]) > stored_fired_before, "the twelfth input releases stored rounds toward aim")

	# --- BR-13: Overload's no-Heat trigger: 20 stage-3 inputs in 8 s.
	var overloads_before := int(_engine.counters["overloads"])
	_engine.overload_recovery_left = 0.0
	_engine._stage3_inputs.clear()
	_engine._spin_streak = 2.4
	for _i in range(20):
		_engine._spin_last_input = _engine._clock
		_fire()
		_engine.tick(0.05)
		_engine._spin_streak = maxf(_engine._spin_streak, 2.4)
	_check(int(_engine.counters["overloads"]) == overloads_before + 1, "twenty stage-3 inputs inside 8 s fire Overload with no Heat (%d)" % int(_engine.counters["overloads"]))

	# --- Hot Core: a deliberate purchase creates the optional Heat layer.
	ledger.record_purchase("BR03", 400)
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	_check(_engine.claims_heat(), "owning BR03 creates the Heat pool")
	for _i in range(7):
		_fire()
	_check(_engine.heat >= 50.0 and _engine.tier_index() == 1, "seven inputs cross 50 Heat into tier 1 (%s)" % str(_engine.heat))
	var aura: Array = _engine.aura_state()
	_check(is_equal_approx(float(aura[0]), 0.5 * AscensionRunner.R) and is_equal_approx(float(aura[1]), 0.12 * D), "tier 1 aura: 0.5R radius at 0.12 D/s")
	var near := _spawn_enemy(300.0, _player.global_position + Vector2(30, 0))
	var far := _spawn_enemy(300.0, _player.global_position + Vector2(70, 0))
	_engine._aura_tick_left = 0.0
	_engine._tick_aura(0.26)
	_check(EnemyWorld.get_health(near) < 300.0, "an enemy inside the aura takes the radiant tick")
	_check(is_equal_approx(EnemyWorld.get_health(far), 300.0), "an enemy just outside the radius takes nothing")
	EnemyWorld.remove_enemy(near, &"test")
	EnemyWorld.remove_enemy(far, &"test")

	# --- Meltdown: 2 s locked window, rest at 40, lockout to 99, no Jam.
	_engine.heat = 96.0
	_engine.add_heat(8.0)
	_check(_engine._meltdown_left > 0.0 and is_equal_approx(_engine.heat, 100.0), "crossing 100 begins the 2 s Meltdown at locked 100")
	_engine.add_heat(50.0)
	_check(is_equal_approx(_engine.heat, 100.0), "Meltdown discards extra Heat instead of banking it")
	_check(int(_engine.counters["jams"]) == 0 and float(_player.get("_weapon_cd")) < 0.5, "Meltdown never stops the gun")
	_engine.tick(2.1)
	_check(is_equal_approx(_engine.heat, 40.0) and _engine._meltdown_lockout_left > 0.0, "Meltdown ends at 40 with the 3 s lockout")
	_engine._idle = 0.0
	_engine.add_heat(200.0)
	_check(is_equal_approx(_engine.heat, 99.0), "during lockout ordinary Heat stops at 99")

	# --- Overclock + Thermal Fury: sustained Meltdown IS a Meltdown
	# (playtest review findings 7 and 8). BRF2 needs BR08+BR11-adjacent
	# locals; both routes — Overclock owned before heating, and heat carried
	# through the lockout — must deliver the fork.
	ledger.record_purchase("BR03", 0)   # idempotent for a fresh read below
	for id in ["BRF2", "BRK1"]:
		ledger.record_purchase(id, 100)
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	_engine._meltdown_lockout_left = 0.0
	_engine.heat = 0.0
	var loose_before := int(_engine.counters["loose_rounds"])
	_engine.add_heat(120.0)
	_check(_engine._sustained_meltdown and _engine.in_meltdown(), "Overclock crossing 100 enters SUSTAINED Meltdown")
	_check(int(_engine.counters.get("sustained_meltdowns", 0)) == 1, "the episode is counted")
	var aura_hot: Array = _engine.aura_state()
	var expected_dps := 0.35 * D * 2.0
	_check(is_equal_approx(float(aura_hot[1]), expected_dps), "Thermal Fury doubles the Overclock aura while sustained (%.2f)" % float(aura_hot[1]))
	var hp_at_sustained := float(_player.get("hp"))
	_engine._idle = 999.0
	_engine.tick(1.0)   # cools 25/s -> 95, exits the sustained region
	_check(not _engine._sustained_meltdown and _engine.heat < 100.0, "cooling below 100 leaves sustained Meltdown")
	_check(float(_player.get("hp")) < hp_at_sustained, "Thermal Fury's 5%% tax lands at the end of the sustained episode")
	_check(is_zero_approx(float(_engine.aura_state()[1])), "below 100 the Overclock aura (and its doubling) is gone")

	# The 180 emergency vent is a Heavy Barrel release (finding 8): one
	# Force spend, the bonus spread over 16 rounds, BRC half-snapshot free.
	ledger.record_purchase("BA01", 100)
	ledger.record_purchase("MR8", 100)
	_runner.refresh()
	_engine = _runner.engine_for("BR01") as BarrageEngineV5
	var bastion := _runner.engine_of_discipline("BA") as BastionEngine
	_check(bastion != null, "the rig owns a Bastion engine for Force")
	if bastion != null:
		bastion.force = 60.0
		_engine._meltdown_lockout_left = 0.0
		_engine._emergency_vent_left = 0.0
		_engine.heat = 0.0
		_engine.add_heat(185.0)
		_check(int(_engine.counters.get("emergency_vents", 0)) == 1, "185 Heat fires the emergency vent")
		_check(is_zero_approx(bastion.force) and is_equal_approx(float(_engine.counters.get("heavy_barrel_force", 0.0)), 60.0), "the vent spends the 60 Force exactly once")
		_check(is_equal_approx(_engine._heavy_barrel_bonus, 0.06 * D * 60.0 * 0.5), "BRC's half-snapshot is banked without a second spend")
		# Zero-Force: the vent still fires, nothing is spent.
		_engine.tick(0.7)   # vent recovery, heat rest
		_engine._meltdown_lockout_left = 0.0
		_engine._heavy_barrel_bonus = 0.0
		_engine.heat = 0.0
		_engine.add_heat(185.0)
		_check(int(_engine.counters.get("emergency_vents", 0)) == 2 and is_equal_approx(float(_engine.counters.get("heavy_barrel_force", 0.0)), 60.0), "a zero-Force vent fires without a spend")

	# Overclock acquired DURING an ordinary Meltdown converts the frozen
	# window into the sustained region (the second acceptance route).
	_engine._sustained_meltdown = false
	_engine._meltdown_left = 1.2
	_engine._meltdown_lockout_left = 0.0
	_engine.heat = 100.0
	_engine.tick(0.1)
	_check(_engine._meltdown_left <= 0.0 and _engine._sustained_meltdown, "a mid-Meltdown Overclock purchase converts to sustained instead of freezing")
	_engine._idle = 999.0
	_engine.tick(1.0)

	# --- Foreign Spin Up expires on the clock (finding 9).
	_engine._foreign_stage = 3
	_engine._foreign_last_witness = _engine._clock
	_engine.tick(3.0)
	_check(_engine._foreign_stage == 3, "a fresh foreign stage survives inside the 4 s window")
	_engine.tick(1.5)
	_check(_engine._foreign_stage == 0, "an idle foreign stage expires after 4 s without a Witness")

	# --- A Q-less Hot Core build keeps a persistent readout (finding 10).
	var q_state: Dictionary = _runner.slot_state("q")
	_check(float(q_state.get("resource_max", 0.0)) > 0.0, "the Heat pool reaches the Q readout without a Q equipped")
	_check(_runner._passive_q_readout_exists(), "a passive Hot Core build keeps its slot HUD")

	_finish()


func _finish() -> void:
	print("AscensionBarrageV5Test: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
