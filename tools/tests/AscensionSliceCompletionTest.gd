extends Node

# The rules that completed the first three disciplines: Clean Cut, the
# Overkill axiom, exact keystone maths through the damage hook (Execution);
# Heat Beam and Projectile Life (Barrage); Denial's projectile slow, Undo,
# Fixed Coin, Replay and REWRITE's missed swings (Distortion).
#
# Run: <godot> --headless --path . res://tools/tests/AscensionSliceCompletionTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

var _passes := 0
var _failures := 0
var _player: Node2D
var _runner: AscensionRunner
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


func _spawn(hp: float, at: Vector2, flags: int = 0) -> int:
	return EnemyWorld.create_enemy(SpawnState.new(&"asc_slice", "res://asc_slice.tscn", at, hp, 10.0, 8.0, 0, flags))


func _load(native: String, ids: Array) -> void:
	Global.selected_style_id = native
	Global.attempt_ascension = AscensionLedger.fresh_state(native)
	_ledger = Global.ascension_ledger()
	_ledger.note_segment_completed(9)
	for entry in ids:
		if entry is Array:
			_ledger.record_purchase(String(entry[0]), 1600, String(entry[1]))
		else:
			_ledger.record_purchase(String(entry), 100)
	_runner.q_cooldown_left = 0.0
	_runner._saved_recovery.clear()
	_runner._v_gap_left = 0.0
	_runner.v_charge = 0.0
	_runner.v2_charge = 0.0
	_runner.v_reserve = 0.0
	_runner.v2_reserve = 0.0
	_runner.refresh()
	_runner.q_cooldown_left = 0.0


func _native(core: String, path: String, execute: bool = false) -> PackedStringArray:
	var tags := AscensionTags.native(core, path)
	tags = AscensionTags.with_flag(tags, "core_strike")
	if execute:
		tags = AscensionTags.with_flag(tags, "execute_enabled")
	tags.append("cast:native:1")
	return tags


func _run() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	var origin := _player.global_position

	# ---------------- Execution: exact keystones through the damage hook
	_load("melee", ["EX01", "EX02", "EX04", "EXK1"])
	var healthy := _spawn(100.0, origin + Vector2(60, 0))
	_runner.damage_enemy(healthy, 20.0, _native("melee", "slash", true))
	_check(is_equal_approx(_runner.enemy_hp(healthy), 85.0), "Only the Weak: a Core hit on a target above half HP lands 75%% (%s)" % str(_runner.enemy_hp(healthy)))
	_runner.damage_enemy(healthy, 40.0, _native("melee", "slash", true))
	_check(is_equal_approx(_runner.enemy_hp(healthy), 85.0 - (40.0 + 7.5) * 0.75), "the marked hit gains the consumed Mark's +0.5D and then loses 25%% above half (%s)" % str(_runner.enemy_hp(healthy)))
	# Below half the hit is whole; the re-applied Mark is consumed again for
	# +0.5D, and 31.9% stays above Only the Weak's 22% line.
	_runner.damage_enemy(healthy, 10.0, _native("melee", "slash", true))
	_check(is_equal_approx(_runner.enemy_hp(healthy), 49.375 - 17.5), "below half HP the hit is whole (%s)" % str(_runner.enemy_hp(healthy)))
	EnemyWorld.remove_enemy(healthy, &"test")
	_load("melee", ["EX01", "EX02", "EX04", "EXK2"])
	var pair_a := _spawn(100.0, origin + Vector2(60, 0))
	var pair_b := _spawn(100.0, origin + Vector2(-60, 0))
	_runner.damage_enemy(pair_a, 10.0, _native("melee", "slash", true))
	_check(is_equal_approx(_runner.enemy_hp(pair_a), 100.0 - 15.0), "One at a Time: the marking hit already lands +50%% (%s)" % str(_runner.enemy_hp(pair_a)))
	_runner.damage_enemy(pair_b, 10.0, AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "EX06", "slash", 1, 0.5))
	_check(is_equal_approx(_runner.enemy_hp(pair_b), 100.0 - 7.0) or _runner.has_status(pair_b, "mark"), "an unmarked target takes 30%% less from a payload (%s)" % str(_runner.enemy_hp(pair_b)))
	EnemyWorld.remove_enemy(pair_a, &"test")
	EnemyWorld.remove_enemy(pair_b, &"test")

	# ---------------- Execution: Clean Cut and the Overkill axiom
	_load("melee", ["EX01", "EX02", "EX03", "EX12"])
	var execution := _runner.engine_for("EX01") as ExecutionEngine
	_player.set("_weapon_cd", 0.3)
	var victim := _spawn(100.0, origin + Vector2(60, 0))
	_runner.damage_enemy(victim, 92.0, _native("melee", "slash", true))
	_check(not _runner.enemy_alive(victim) and is_equal_approx(_player.native_recovery_left(), 0.0), "Clean Cut: the first execution after a native input clears the attack recovery")
	_player.get("_dash").cooldown_left = 1.0
	var neighbour := _spawn(100.0, origin + Vector2(120, 0))
	_runner.damage_enemy(neighbour, 92.0, AscensionTags.make("melee", AscensionTags.FAMILY_TREE, "EX06", "slash", 1, 0.5, PackedStringArray(["execute_enabled"])))
	_check(not _runner.enemy_alive(neighbour) and is_equal_approx(_player.get("_dash").cooldown_left, 0.85), "a generated execution refunds 0.15 s of dash recovery (%s)" % str(_player.get("_dash").cooldown_left))
	_load("ranged", ["BR01", "BR02", "BRQ", ["G1", "melee"], "EX01", "EX02", "EX03", "EX05", "EXA"])
	execution = _runner.engine_for("EX01") as ExecutionEngine
	var shot := _spawn(10.0, origin + Vector2(60, 0))
	var beside := _spawn(100.0, origin + Vector2(120, 0))
	_runner.damage_enemy(shot, 40.0, _native("ranged", "bullet"))
	_check(int(execution.counters["spillovers"]) == 1, "Overkill axiom: a Ranged Core kill sends Spillover")
	for _i in range(30):
		execution.tick(1.0 / 60.0)
	_check(is_equal_approx(_runner.enemy_hp(beside), 100.0 - 0.6 * 30.0), "the axiom bolt carries 60%% of the overkill (%s)" % str(_runner.enemy_hp(beside)))
	EnemyWorld.remove_enemy(beside, &"test")

	# ---------------- Barrage: Heat Beam and Projectile Life
	_load("ranged", ["BR01", "BR02", "BRQ", "BRQ1", "BRQ2", "BRF1", "BRE1", "BRS2", "BRS2", "BRS2", "BRS2"])
	var barrage := _runner.engine_for("BR01") as BarrageEngine
	_check(is_equal_approx(barrage.projectile_life_multiplier(), 1.0 + 0.5 * 4.0 / 104.0), "Projectile Life rank 4 lengthens projectiles by 50%% x 4/104")
	_runner.aim_override = origin + Vector2(400, 0)
	var line_a := _spawn(100.0, origin + Vector2(200, 0))
	var line_b := _spawn(100.0, origin + Vector2(400, 4))
	var verdict := _runner.activate_q()
	_check(bool(verdict["ok"]) and verdict["message"] == "HEAT BEAM" and barrage.beam_left > 2.9, "Heat Beam: Burst becomes a 3 s beam with Sustained")
	var heat_before := barrage.heat
	barrage.tick(0.31)
	_check(int(barrage.counters.get("beam_ticks", 0)) == 2 and _runner.enemy_hp(line_a) < 100.0 and _runner.enemy_hp(line_b) < 100.0, "the beam pierces every enemy along its line every 0.15 s")
	_check(is_equal_approx(barrage.heat, heat_before + 10.0), "each beam tick adds 5 Heat (%s)" % str(barrage.heat))
	barrage.heat = 70.0
	_runner.activate_q()
	_check(barrage.beam_left <= 0.0 and barrage.stationary_beam_left > 0.0, "releasing in the Cool Head band leaves a stationary beam")
	EnemyWorld.remove_enemy(line_a, &"test")
	EnemyWorld.remove_enemy(line_b, &"test")
	barrage.stationary_beam_left = 0.0

	# ---------------- Distortion: Denial slows hostile bullets inside R
	_load("magic", ["DT01", "DT04", "DT05"])
	var distortion := _runner.engine_for("DT04") as DistortionEngine
	distortion.tick(0.0)
	ProjectileManager.spawn_enemy(origin + Vector2(50, 0), Vector2.RIGHT, 100.0, 1.0, 5.0, null)
	ProjectileManager.spawn_enemy(origin + Vector2(300, 0), Vector2.RIGHT, 100.0, 1.0, 5.0, null)
	var near_id: int = ProjectileManager._ids[ProjectileManager.active_count() - 2]
	var far_id: int = ProjectileManager._ids[ProjectileManager.active_count() - 1]
	var found_before: Array = []
	ProjectileManager.enemy_projectiles_in_radius(origin, 2000.0, found_before)
	# Wait by travelled distance, not frames: headless frame pacing varies.
	for _i in range(60):
		await get_tree().process_frame
		var probe: Array = []
		ProjectileManager.enemy_projectiles_in_radius(origin, 2000.0, probe)
		var moved_enough := false
		for bullet in probe:
			if int(bullet["id"]) == far_id and (bullet["position"] as Vector2).x - origin.x > 300.0 + 12.0:
				moved_enough = true
		if moved_enough:
			break
	var found_after: Array = []
	ProjectileManager.enemy_projectiles_in_radius(origin, 2000.0, found_after)
	var by_id_before: Dictionary = {}
	for bullet in found_before:
		by_id_before[int(bullet["id"])] = (bullet["position"] as Vector2).x
	var by_id_after: Dictionary = {}
	for bullet in found_after:
		by_id_after[int(bullet["id"])] = (bullet["position"] as Vector2).x
	var near_moved: float = float(by_id_after.get(near_id, 0.0)) - float(by_id_before.get(near_id, 0.0))
	var far_moved: float = float(by_id_after.get(far_id, 0.0)) - float(by_id_before.get(far_id, 0.0))
	_check(near_moved > 0.0 and far_moved > 0.0 and absf(near_moved / far_moved - 0.7) < 0.1, "a hostile bullet inside R moves 30%% slower than one outside (%.2f vs %.2f)" % [near_moved, far_moved])
	ProjectileManager.clear_for_run_end()

	# ---------------- Distortion: Undo, Fixed Coin, Replay, REWRITE misses
	_load("magic", ["DT01", "DT06", "DTF1"])
	distortion = _runner.engine_for("DT06") as DistortionEngine
	_player.hp = 100.0
	var attacker := _spawn(200.0, origin + Vector2(50, 0))
	var attacker_node := Node2D.new()
	add_child(attacker_node)
	EnemyWorld.bind_actor(attacker, attacker_node)
	_player.take_damage(30.0, attacker_node)
	_check(_player.hp > 95.0 and int(distortion.counters.get("undos", 0)) == 1, "Undo restores a 25%% burst and schedules self-Debt (hp %.1f)" % _player.hp)
	_runner.damage_enemy(attacker, 200.0, _native("magic", "impact"))
	distortion.tick(3.1)
	_check(_player.hp > 80.0, "killing the greatest contributor cancels half the bill (hp %.1f)" % _player.hp)
	attacker_node.queue_free()
	_load("magic", ["DT01", "DT06", "DTQ", "DTQ5", "DTE1"])
	distortion = _runner.engine_for("DT06") as DistortionEngine
	_player.hp = 100.0
	_runner.activate_q()
	_check(distortion.heads_left > 0.0, "Counterfeit tap chooses Heads")
	_player.take_damage(20.0, null)
	var hp_after_hit: float = _player.hp
	distortion.tick(2.0)
	_check(_player.hp > hp_after_hit and int(distortion.counters.get("heads_refunds", 0)) == 1, "Fixed Coin: Heads refunds 30%% of damage suffered when it ends (%.1f -> %.1f)" % [hp_after_hit, _player.hp])
	_load("magic", ["DT01", "DT06", "DTV", "DTV2"])
	distortion = _runner.engine_for("DT06") as DistortionEngine
	var replayed := _spawn(30.0, origin + Vector2(60, 0))
	var witness := _spawn(100.0, origin + Vector2(70, 0))
	_runner.damage_enemy(replayed, 10.0, _native("magic", "impact"))
	_runner.damage_enemy(replayed, 10.0, _native("magic", "impact"))
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	_runner.activate_v()
	_runner.damage_enemy(replayed, 100.0, _native("magic", "impact"))
	_check(int(distortion.counters.get("replays", 0)) == 3, "Replay repeats the corpse's last three hits (%d)" % int(distortion.counters.get("replays", 0)))
	_runner.flush_attacks()
	_check(_runner.enemy_hp(witness) < 100.0, "the replayed impacts hit the neighbour at the corpse (%s)" % str(_runner.enemy_hp(witness)))
	var swinger := _spawn(50.0, origin + Vector2(40, 0))
	var swinger_node := Node2D.new()
	swinger_node.global_position = origin + Vector2(40, 0)
	add_child(swinger_node)
	EnemyWorld.bind_actor(swinger, swinger_node)
	var hp_before_swing: float = _player.hp
	_player.take_damage(10.0, swinger_node)
	_check(is_equal_approx(_player.hp, hp_before_swing), "REWRITE: a normal's adjacent swing misses")
	var shooter := _spawn(50.0, origin + Vector2(400, 0), EnemyWorldTypes.Flags.ELITE)
	var shooter_node := Node2D.new()
	shooter_node.global_position = origin + Vector2(400, 0)
	add_child(shooter_node)
	EnemyWorld.bind_actor(shooter, shooter_node)
	_player.take_damage(10.0, shooter_node)
	_check(_player.hp < hp_before_swing, "an elite's attack still lands")
	for handle in [replayed, witness, swinger, shooter]:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"test")

	Global.attempt_ascension = {}
	_player.queue_free()
	print("AscensionSliceCompletionTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
