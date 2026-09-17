extends Node

# Distortion on a Magic native: Causal Debt deposits a quarter of each Core
# hit and pays it two seconds later as Magic damage with Interest, Back Pay
# moves a corpse's Debt, Pass It On splits it, Twice echoes a strike on a
# named roll that Heads and REWRITE guarantee, Bad Luck banks Misfortune on
# failures and spends five for a guarantee, Snake Eyes flattens chances,
# Residue leaves scars that Scar Tissue releases, Misfire deletes hostile
# bullets, Coin pays and refunds health, Payday accelerates a fed crowd, and
# REWRITE keeps matured Debt collectable for consumers (review F3).
#
# Run: <godot> --headless --path . res://tools/tests/AscensionDistortionTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

var _passes := 0
var _failures := 0
var _player: Node2D
var _runner: AscensionRunner
var _engine: DistortionEngine
var _ledger: AscensionLedger


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
	return EnemyWorld.create_enemy(SpawnState.new(&"asc_distortion", "res://asc_distortion.tscn", at, hp, 10.0, 8.0, 0, 0))


func _impact_tags() -> PackedStringArray:
	var tags := AscensionTags.native("magic", "impact")
	return AscensionTags.with_flag(tags, "core_strike")


func _fire_magic(target: Vector2) -> void:
	RunEvents.weapon_fired.emit(_player, &"magic", _player.global_position, target, 1.0, 1.0)


func _tick(seconds: float) -> void:
	var steps := int(ceil(seconds / (1.0 / 60.0)))
	for _i in range(steps):
		_engine.tick(1.0 / 60.0)


func _own(ids: Array) -> void:
	for id in ids:
		if not _ledger.owns(String(id)):
			_ledger.record_purchase(String(id), 100)
	_runner.refresh()
	_engine = _runner.engine_for("DT06") as DistortionEngine


func _disown(ids: Array) -> void:
	for id in ids:
		_ledger.owned().erase(String(id))
	_runner.refresh()
	_engine = _runner.engine_for("DT06") as DistortionEngine


func _run() -> void:
	Global.selected_style_id = "magic"
	Global.attempt_ascension = AscensionLedger.fresh_state("magic")
	_ledger = Global.ascension_ledger()
	_ledger.record_purchase("DT06", 0)
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_own(["DT07", "DT09", "DT01", "DT03"])
	_check(_engine != null, "the Distortion engine loads")
	if _engine == null:
		_finish()
		return
	var D := _runner.native_damage()
	_check(is_equal_approx(D, 18.6), "a Magic native's D is 18.6 (%s)" % str(D))
	var origin := _player.global_position

	# --- Causal Debt with Interest
	var debtor := _spawn_enemy(200.0, origin + Vector2(100, 0))
	_runner.damage_enemy(debtor, 40.0, _impact_tags())
	_check(is_equal_approx(_engine.unpaid_debt(debtor), 10.0) and int(_engine.counters["deposits"]) == 1, "a Magic Core hit deposits 25%% of its damage as Debt (%s)" % str(_engine.unpaid_debt(debtor)))
	_runner.damage_enemy(debtor, 40.0, _impact_tags())
	_check(_engine.pending_bucket_count() == 1 and is_equal_approx(_engine.unpaid_debt(debtor), 20.0), "same-source packets merge into one bucket")
	_check(_runner.has_status(debtor, "fading"), "Residue applies Fading")
	var hp_before_maturity := _runner.enemy_hp(debtor)
	_tick(2.1)
	var paid: float = hp_before_maturity - _runner.enemy_hp(debtor)
	var fading_paid: float = float(_engine.counters["fading_ticks"]) * 0.5 * 0.15 * D
	var debt_paid: float = paid - fading_paid
	_check(int(_engine.counters["matured"]) == 1 and debt_paid > 20.0 * 1.29 and debt_paid < 20.0 * 1.46, "the bucket matures after 2 s with simple Interest (%s)" % str(debt_paid))
	_check(_engine.unpaid_debt(debtor) == 0.0, "a paid bucket leaves the ledger")
	_tick(0.5)
	_check(int(_engine.counters["scars"]) >= 1, "an expiring Fading leaves a scar")

	# --- Back Pay from a corpse
	var dying := _spawn_enemy(30.0, origin + Vector2(-100, 0))
	var heir := _spawn_enemy(200.0, origin + Vector2(-160, 0))
	_runner.damage_enemy(dying, 20.0, _impact_tags())
	_check(is_equal_approx(_engine.unpaid_debt(dying), 5.0), "the dying target owes 5")
	_runner.damage_enemy(dying, 50.0, AscensionTags.native("magic", "impact"))
	_check(int(_engine.counters["back_pays"]) == 1 and _engine.unpaid_debt(heir) > 3.7, "Back Pay moves 75%% of a corpse's Debt to the nearest enemy (%s)" % str(_engine.unpaid_debt(heir)))
	_tick(0.1)
	_check(_engine.unpaid_debt(heir) == 0.0 and int(_engine.counters["matured"]) == 2, "the transferred packet matures immediately")

	# --- Pass It On replaces Back Pay
	for handle in [debtor, heir]:
		EnemyWorld.remove_enemy(handle, &"test")
	_own(["DTF2"])
	var payer := _spawn_enemy(30.0, origin + Vector2(0, 150))
	var a := _spawn_enemy(200.0, origin + Vector2(40, 150))
	var b := _spawn_enemy(200.0, origin + Vector2(-40, 150))
	_runner.damage_enemy(payer, 20.0, _impact_tags())
	_runner.damage_enemy(payer, 50.0, AscensionTags.native("magic", "impact"))
	_check(int(_engine.counters["pass_ons"]) == 1 and is_equal_approx(_engine.unpaid_debt(a), 2.0) and is_equal_approx(_engine.unpaid_debt(b), 2.0), "Pass It On gives 40%% to up to three neighbours (%s, %s)" % [str(_engine.unpaid_debt(a)), str(_engine.unpaid_debt(b))])
	_tick(0.6)
	for handle in [a, b]:
		EnemyWorld.remove_enemy(handle, &"test")

	# --- Twice and the roll registry
	_runner.rng().seed = 7
	var twice_before := int(_engine.counters["twice"])
	for _i in range(40):
		_fire_magic(origin + Vector2(60, 0))
	var twice_rolled := int(_engine.counters["twice"]) - twice_before
	_check(twice_rolled >= 2 and twice_rolled <= 18, "Twice fires on roughly a fifth of strikes (%d of 40)" % twice_rolled)
	_check(_engine._echoes.size() == twice_rolled, "each Twice queues an echo of the strike")
	_engine._echoes.clear()
	_own(["DT10"])
	var misfortune_before := _runner.misfortune()
	for _i in range(10):
		_fire_magic(origin + Vector2(60, 0))
	_check(_runner.misfortune() > misfortune_before, "Bad Luck banks Misfortune on failed rolls (%d)" % _runner.misfortune())
	_engine._echoes.clear()
	var state := _runner.manifestation_state()
	state.set("misfortune", 5)
	var twice_now := int(_engine.counters["twice"])
	_fire_magic(origin + Vector2(60, 0))
	_check(int(_engine.counters["twice"]) == twice_now + 1 and _runner.misfortune() == 0, "five Misfortune guarantee the next roll and are spent")
	_engine._echoes.clear()
	_own(["DTK2"])
	_runner.roll(&"twice", 0.2)
	_check(is_equal_approx(_runner.last_roll_chance, 0.5), "Snake Eyes makes every chance exactly 50%")
	_disown(["DTK2"])
	_engine._echoes.clear()

	# --- Scar Tissue
	_own(["DT11"])
	var scars_live := _engine.scars.size()
	_check(scars_live >= 1, "scars are still on the ground (%d)" % scars_live)
	var scar_pos: Vector2 = _engine.scars[0]["pos"]
	var bystander := _spawn_enemy(200.0, scar_pos + Vector2(10, 0))
	_fire_magic(scar_pos)
	_check(int(_engine.counters["scar_releases"]) >= 1 and _engine.scars.size() < scars_live, "a Core impact on a scar releases it")
	_check(_engine.unpaid_debt(bystander) > 0.0, "the release deposits Debt on enemies in reach")
	_engine._echoes.clear()
	EnemyWorld.remove_enemy(bystander, &"test")

	# --- Misfire
	_own(["DT04"])
	_runner.rng().seed = 3
	for i in range(30):
		ProjectileManager.spawn_enemy(origin + Vector2(40, float(i) * 2.0 - 30.0), Vector2.LEFT, 10.0, 1.0, 5.0, null)
	_tick(0.05)
	_check(int(_engine.counters["misfire_rolls"]) == 30, "each distinct hostile bullet inside R is judged once (%d)" % int(_engine.counters["misfire_rolls"]))
	_check(int(_engine.counters["misfires"]) >= 1 and int(_engine.counters["misfires"]) < 15, "about 15%% vanish (%d)" % int(_engine.counters["misfires"]))
	var judged := int(_engine.counters["misfire_rolls"])
	_tick(0.05)
	_check(int(_engine.counters["misfire_rolls"]) == judged, "a bullet that stayed is not judged again")
	ProjectileManager.clear_for_run_end()

	# --- Coin
	_own(["DTQ", "DTQ6"])
	_check(_runner.q_id == "DTQ", "Coin sits on Q")
	_player.hp = 100.0
	_runner.rng().seed = 11
	var verdict := _runner.activate_q()
	_check(bool(verdict["ok"]) and is_equal_approx(float(verdict["cooldown"]), 9.0), "the Coin flips on a 9 s recovery (%s)" % str(verdict["message"]))
	var flipped_tails := _engine.tails_left > 0.0
	if flipped_tails:
		_check(is_equal_approx(_player.hp, 88.0), "Tails pays 12% of current HP")
		_check(is_equal_approx(_runner.get_power_multiplier(), 1.6), "Tails adds 60% Magic damage")
	else:
		_check(is_equal_approx(_player.hp, 100.0), "Heads costs nothing")
		var forced := int(_engine.counters["twice"])
		_fire_magic(origin + Vector2(60, 0))
		_check(int(_engine.counters["twice"]) == forced + 1, "Heads guarantees Twice")
	var fodder := _spawn_enemy(1.0, origin + Vector2(120, 0))
	var penny_target := _spawn_enemy(200.0, origin + Vector2(160, 0))
	_runner.damage_enemy(fodder, 10.0, _impact_tags())
	_check(int(_engine.counters["pennies"]) == 1, "a kill during Coin sends a Bad Penny to a neighbour")
	if flipped_tails:
		_check(_player.hp > 88.0, "a kill refunds 1% max HP of the health paid")
	_engine._echoes.clear()
	_tick(4.0)
	EnemyWorld.remove_enemy(penny_target, &"test")

	# --- Payday: twenty deposits inside 4 s
	_own(["DTC"])
	var crowd: Array[int] = []
	for i in range(10):
		crowd.append(_spawn_enemy(500.0, origin + Vector2(200 + float(i) * 12.0, 200)))
	for handle in crowd:
		_runner.damage_enemy(handle, 20.0, _impact_tags())
	_tick(0.3)
	for handle in crowd:
		_runner.damage_enemy(handle, 20.0, _impact_tags())
	_check(int(_engine.counters["deposits"]) >= 20, "twenty deposits landed (%d)" % int(_engine.counters["deposits"]))
	_tick(1.8)
	_check(int(_engine.counters["paydays"]) == 1, "the next natural maturity after twenty deposits in 4 s starts Payday")
	_tick(0.6)
	_check(_engine.pending_bucket_count() == 0, "Payday matures everything within half a second")
	_engine._echoes.clear()

	# --- REWRITE keeps matured Debt collectable
	_own(["DTV"])
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	verdict = _runner.activate_v()
	_check(bool(verdict["ok"]) and _engine.rewrite_left > 0.0, "REWRITE starts")
	_check(_engine.unpaid_debt(crowd[0]) >= 0.0 and int(_engine.counters["deposits"]) >= 30, "every visible enemy receives 1D of V Debt")
	var rewrite_target := crowd[1]
	var hp_before_rewrite := _runner.enemy_hp(rewrite_target)
	_runner.damage_enemy(rewrite_target, 40.0, _impact_tags())
	_tick(0.05)
	_check(_runner.enemy_hp(rewrite_target) < hp_before_rewrite - 40.0, "new Debt matures immediately during REWRITE")
	_check(_engine.unpaid_debt(rewrite_target) > 0.0, "the paid bucket stays collectable for consumers")
	var collected := _engine.collect_debt(rewrite_target)
	_check(collected > 0.0 and _engine.unpaid_debt(rewrite_target) == 0.0, "a consumer collects it once (%s)" % str(collected))
	_tick(4.1)
	_check(_engine.rewrite_left <= 0.0, "REWRITE ends after 4 s")
	_engine._echoes.clear()
	for handle in crowd:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"test")

	Global.attempt_ascension = {}
	_player.queue_free()
	_finish()


func _finish() -> void:
	print("AscensionDistortionTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
