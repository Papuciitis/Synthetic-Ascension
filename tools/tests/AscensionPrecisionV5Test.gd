extends Node

# Ranged V5 Precision (handoff 2026-09-25): the selective ranks change Read
# thresholds, pierce counts, Aim time, returns, splits and spares; Far Shot's
# ranked bonus stays on its own Weak Points; Smart Rounds costs -15%; and the
# Firing Squad boss fallback needs three physical hits worth 12D on one
# durable target from one root.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionPrecisionV5Test.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

var _passes := 0
var _failures := 0
var _player: Node2D
var _runner: AscensionRunner
var _engine: PrecisionEngineV5


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _spawn_enemy(hp: float, at: Vector2, elite: bool = false) -> int:
	var flags := EnemyWorldTypes.Flags.ELITE if elite else 0
	return EnemyWorld.create_enemy(SpawnState.new(&"asc_pr_v5", "res://asc_pr_v5.tscn", at, hp, 10.0, 8.0, 0, flags))


func _bullet_tags(cast: String, pid: int) -> PackedStringArray:
	var tags := AscensionTags.native("ranged", "bullet")
	tags = AscensionTags.with_flag(tags, "core_strike")
	tags.append("cast:" + cast)
	return tags


func _run() -> void:
	Global.selected_style_id = "ranged"
	Global.attempt_ascension = AscensionLedger.fresh_state("ranged", "v5_ranged")
	var ledger := Global.ascension_ledger()
	ledger.record_purchase("PR01", 0)
	for id in ["PR02", "PR03", "PR05", "PR06", "PR07", "PR09", "PR11", "PR12", "PRC"]:
		ledger.record_purchase(id, 100)
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_runner.refresh()
	_engine = _runner.engine_for("PR01") as PrecisionEngineV5
	_check(_engine != null, "a V5 run loads PrecisionEngineV5")
	if _engine == null:
		_finish()
		return
	var D := _runner.native_damage()

	# --- Rank getters follow the authored tables.
	_check(is_equal_approx(_engine._read_threshold(), 3.0), "PR01 rank 1 exposes at 3.0")
	(ledger.state["owned"] as Dictionary)["PR01"] = 3
	_check(is_equal_approx(_engine._read_threshold(), 2.0), "PR01 rank 3 exposes at 2.0")
	_check(_engine._pierce_bonus() == 2, "PR03 rank 1 pierces 2 extra")
	(ledger.state["owned"] as Dictionary)["PR03"] = 4
	_check(_engine._pierce_bonus() == 5, "PR03 rank 4 pierces 5 extra")
	_check(is_equal_approx(_engine._aim_seconds(), 0.8), "PR05 rank 1 aims in 0.80 s")
	(ledger.state["owned"] as Dictionary)["PR05"] = 3
	_check(is_equal_approx(_engine._aim_seconds(), 0.5), "PR05 rank 3 aims in 0.50 s")
	_check(_engine._terrain_bounces() == 1, "PR06 rank 1 bounces once")
	(ledger.state["owned"] as Dictionary)["PR06"] = 2
	_check(_engine._terrain_bounces() == 2, "PR06 rank 2 bounces twice")
	_check(is_equal_approx(_engine._return_fraction(), 0.6), "PR07 rank 1 returns at 60%")
	(ledger.state["owned"] as Dictionary)["PR07"] = 3
	_check(is_equal_approx(_engine._return_fraction(), 0.9), "PR07 rank 3 returns at 90%")
	_check(_engine._split_angles().size() == 2, "PR09 rank 1 splits into 2")
	(ledger.state["owned"] as Dictionary)["PR09"] = 3
	_check(_engine._split_angles() == [-30.0, -10.0, 10.0, 30.0], "PR09 rank 3 splits into 4 at the authored angles")
	_check(is_equal_approx(_engine._crossing_window(), 0.5), "PR11 rank 1 window 0.50 s")
	(ledger.state["owned"] as Dictionary)["PR11"] = 2
	_check(is_equal_approx(_engine._crossing_window(), 0.65), "PR11 rank 2 window 0.65 s")
	_check(_engine._spare_cap() == 3, "PR12 rank 1 stores 3 spares")
	(ledger.state["owned"] as Dictionary)["PR12"] = 3
	_check(_engine._spare_cap() == 6, "PR12 rank 3 stores 6")
	_check(is_equal_approx(_engine._smart_rounds_scale(), 0.85), "Smart Rounds costs -15% in the V5 test change")

	# --- PR-02: the ranked bonus only on Far Shot's own Weak Points.
	(ledger.state["owned"] as Dictionary)["PR02"] = 3
	_runner.refresh()
	_engine = _runner.engine_for("PR01") as PrecisionEngineV5
	var far_victim := _spawn_enemy(500.0, _player.global_position + Vector2(200, 0))
	_engine.expose(far_victim, "far_shot")
	var preview := {"handle": far_victim, "raw": 10.0, "tags": _bullet_tags("t1", 1), "core": "ranged", "family": "native", "core_strike": true}
	var boosted := _engine.modify_outgoing_damage(preview, 10.0)
	_check(is_equal_approx(boosted, 10.0 + D + 0.4 * D), "a Far Shot Weak Point consumes for +1.4D at rank 3 (%.1f)" % boosted)
	var read_victim := _spawn_enemy(500.0, _player.global_position + Vector2(60, 0))
	_engine.expose(read_victim, "")
	var preview2 := {"handle": read_victim, "raw": 10.0, "tags": _bullet_tags("t2", 2), "core": "ranged", "family": "native", "core_strike": true}
	var plain := _engine.modify_outgoing_damage(preview2, 10.0)
	_check(is_equal_approx(plain, 10.0 + D), "an ordinary Weak Point stays +1D")
	EnemyWorld.remove_enemy(far_victim, &"test")
	EnemyWorld.remove_enemy(read_victim, &"test")

	# --- PRC boss fallback: >= 3 physical hits totalling >= 12D on one
	# elite from one projectile root triggers the six-gun payoff once.
	var boss := _spawn_enemy(4000.0, _player.global_position + Vector2(150, 0), true)
	var squads_before := int(_engine.counters["squads"])
	var tags := _bullet_tags("root:boss", 7)
	var ledger_payload := HitLedger.new()
	for i in range(3):
		var payload := HitLedger.new()
		payload.target_handle = boss
		payload.source = _player
		payload.hit_count = 1
		payload.total_raw_damage = 4.5 * D
		payload.tags = tags
		payload.projectile_id = 7
		EnemyCombat.apply_hit_ledger(boss, payload)
	_check(int(_engine.counters["squads"]) == squads_before + 1, "three physical hits worth 12D+ on one elite fire the Firing Squad fallback")
	_check(int(_engine.counters.get("squad_boss_triggers", 0)) == 1, "the fallback is attributed to the boss route")
	# During the 8 s recovery the same route cannot refire.
	for i in range(3):
		var payload2 := HitLedger.new()
		payload2.target_handle = boss
		payload2.source = _player
		payload2.hit_count = 1
		payload2.total_raw_damage = 4.5 * D
		payload2.tags = tags
		payload2.projectile_id = 7
		EnemyCombat.apply_hit_ledger(boss, payload2)
	_check(int(_engine.counters["squads"]) == squads_before + 1, "the fallback respects the recovery period")
	EnemyWorld.remove_enemy(boss, &"test")

	# --- The same route through REAL projectiles (playtest review finding
	# 11): three legal trajectories from the player's position, colliding
	# through the actual simulation, each with its own projectile id but one
	# cast root. No synthetic HitLedger anywhere in this section.
	_engine._squad_recovery = 0.0
	_engine._boss_roots.clear()
	var durable := _spawn_enemy(4000.0, _player.global_position + Vector2(300, 0), true)
	var squads_real := int(_engine.counters["squads"])
	var profile := HitProfileAdapter.new()
	profile.damage = 5.0 * D
	profile.speed = 900.0
	profile.max_range = 500.0
	profile.collision_radius = 6.0
	profile.set_meta("asc_tags", _bullet_tags("real:boss", 0))
	for _shot in range(3):
		ProjectileManager.spawn_player(_player.global_position + Vector2(40, 0), Vector2.RIGHT, profile, _player)
		for _frame in range(30):
			await get_tree().process_frame
			if int(_engine.counters["squads"]) > squads_real:
				break
			var record_count := (_engine._boss_roots as Dictionary).size()
			if record_count > 0 and _shot < 2:
				break
	_check(int(_engine.counters["squads"]) == squads_real + 1, "three REAL projectile hits on one elite fire the Firing Squad (%d)" % int(_engine.counters["squads"]))
	EnemyWorld.remove_enemy(durable, &"test")
	ProjectileManager.clear_for_run_end()

	_finish()


func _finish() -> void:
	print("AscensionPrecisionV5Test: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
