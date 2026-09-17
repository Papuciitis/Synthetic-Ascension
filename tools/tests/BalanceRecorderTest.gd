extends Node

const PLAYER := preload("res://core/actors/player/player.tscn")
const SPAWN := preload("res://core/systems/enemy_world/EnemySpawnState.gd")
var _passes := 0
var _failures := 0

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	var recorder := get_node_or_null("/root/BalanceRecorder")
	_check(recorder != null, "runtime balance recorder is installed")
	if recorder == null:
		_finish()
		return
	_check(not recorder.is_recording(), "headless suite does not automatically start capture")
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.debug_player_god_mode = false
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.set_followers(100)
	var player = PLAYER.instantiate()
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.stats = Stats.new()
	player.stats.armor = 100.0
	player.hp = 20.0
	player.max_hp = 100.0
	player.invulnerable_time = 0.0
	Global.run_luck = 0.0
	var dir := "user://balance_runtime_test_%s" % Time.get_ticks_usec()
	recorder.report_directory = dir
	recorder.record_headless = true
	recorder.begin_gameplay(player)
	recorder.set_process(false)
	_check(recorder.is_recording(), "explicit headless capture starts")
	Global.transaction_followers(50, &"combat_influence", {"enemy_id": "test"})
	Global.transaction_followers(-20, &"shop_buy")
	Global.transaction_followers(20, &"ascension_refund")
	# Use real damage; suppress reconstruction side effects by disconnecting the
	# final lethal action from this test with a larger remaining health pool.
	player.hp = 80.0
	player.take_damage(40.0, self)
	var summary: Dictionary = recorder.get_summary()
	_check(summary.totals.player_hp_lost == 20.0 and summary.totals.player_damage_before_defenses == 40.0, "real player damage captures mitigation and HP loss")
	player.hp = 95.0
	player.heal(30.0, &"pickup")
	player.lock_healing(2.0, &"test")
	player.heal(10.0, &"pickup")
	summary = recorder.get_summary()
	_check(summary.totals.healing == 5.0 and summary.totals.heal_overflow == 25.0 and summary.totals.heal_blocked == 10.0, "real healing records applied overflow and sealed amounts")
	var handle := EnemyWorld.create_enemy(SPAWN.new(&"recorder_fixture", "", Vector2.ZERO, 25.0, 0.0, 1.0, 0, 0, {"follower_reward_min": 0, "follower_reward_max": 0}))
	var ledger := HitLedger.new()
	ledger.add_resolved_hit(100.0, player, Vector2.ZERO, true, 0, 0.0, 0.5, 0.0)
	EnemyCombat.apply_hit_ledger(handle, ledger)
	summary = recorder.get_summary()
	_check(summary.totals.enemy_hp_removed == 25.0 and summary.totals.enemy_overkill == 75.0 and summary.totals.kills == 1, "production proxy death records one kill and exact HP loss")
	_check(summary.totals.critical_hits == 1, "critical hit survives ledger aggregation")
	var reused := EnemyWorld.create_enemy(SPAWN.new(&"recorder_fixture", "", Vector2.ZERO, 40.0, 0.0, 1.0, 0, 0, {"follower_reward_min": 0, "follower_reward_max": 0}))
	EnemyCombat.apply_damage(handle, 100.0, 1, player)
	EnemyWorld.remove_enemy(reused, &"test_cleanup")
	_check(recorder.get_summary().totals.kills == 1, "stale handles and despawns cannot manufacture kills")
	Global.on_segment_completed(2)
	Global.transaction_followers(-10, &"shop_buy")
	summary = recorder.get_summary()
	_check(summary.segments.size() == 2 and summary.segments[0].status == "completed" and summary.segments[1].followers_open == 150, "segment completion rotates accounting before hub spending")
	_check(summary.totals.followers_earned == 50 and summary.totals.followers_spent == 30 and summary.totals.followers_adjustments == 20, "runtime wallet events remain classified and reconciled")
	var capture_path: String = recorder.capture_directory
	Global.on_attempt_failed_die_die()
	_check(not recorder.is_recording(), "run failure closes recording before wallet reset")
	recorder.flush_reports()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(capture_path.path_join("summary.json")))
	_check(saved is Dictionary and saved.outcome == "failed" and saved.totals.followers_close == 140, "saved final summary keeps pre-reset wallet")
	var history := FileAccess.get_file_as_string(capture_path.path_join("events.jsonl"))
	_check(history.contains('"kind":"build"') and history.contains('"kind":"sample"'), "capture contains loadout and runtime snapshots")
	Global.attempt_active = true
	Global.attempt_segment = 3
	Global.set_followers(500)
	recorder.begin_gameplay(player)
	_check(recorder.capture_directory != capture_path and recorder.get_summary().totals.kills == 0, "new capture has unique files and fresh counters")
	var second_path: String = recorder.capture_directory
	Global.transaction_followers(0, &"trade", {"buy_value": 40, "sell_value": 40})
	summary = recorder.get_summary()
	_check(summary.totals.followers_earned == 40 and summary.totals.followers_spent == 40, "zero-net shop exchange still records both sides")
	var elite := preload("res://core/actors/enemy/enemy.tscn").instantiate() as EnemyActor
	var spec := EnemySpec.new()
	spec.id = &"recorder_elite"
	spec.max_hp = 100.0
	spec.elite_hp_mult = 1.6
	spec.item_pickup_scene = elite.item_pickup_scene
	elite.spec = spec
	elite.position = Vector2(10000.0, 10000.0)
	add_child(elite)
	elite.make_elite()
	# Boss arenas also change health after registration; use the real adapter.
	elite.configure_health(400.0, true)
	var enemy_rows: Dictionary = recorder.get_summary().totals.enemies
	var elite_key := String(EnemyWorld.get_spec_id(EnemyCombat.handle_for_actor(elite))) + " [elite]"
	_check(enemy_rows.has(elite_key) and enemy_rows[elite_key].hp_max == 400.0 and enemy_rows[elite_key].seen == 1, "real elite promotion and post-registration HP changes refresh scaling records")
	elite.free()
	player.stats.armor = 100.0
	player.hp = 10.0
	player.invulnerable_time = 0.0
	Global.run_luck = 0.0
	player.take_damage(100.0, self)
	summary = recorder.get_summary()
	_check(summary.totals.player_hp_lost == 10.0 and summary.totals.player_overkill == 40.0, "real lethal hit captures only ten remaining HP")
	_check(summary.totals.deaths == 1 and summary.totals.respawns == 1, "real reconstruction records death and restoration once")
	recorder._process(2.0)
	get_tree().paused = true
	recorder._process(3.0)
	get_tree().paused = false
	summary = recorder.get_summary()
	_check(summary.totals.seconds_gameplay == 2.0 and summary.totals.seconds_paused == 3.0, "runtime pause routing excludes paused time from gameplay")
	var save := SaveData.new()
	Global.apply_save(save)
	_check(not recorder.is_recording(), "loading a save closes the observed session")
	recorder.end_capture("suspended")
	recorder.flush_reports()
	player.free()
	for folder in [capture_path, second_path]:
		for name in ["events.jsonl", "summary.json", "report.md", "segments.csv"]:
			DirAccess.remove_absolute(folder.path_join(name))
		DirAccess.remove_absolute(folder)
	# Dated parent directories are kept local in user:// and contain no saves.
	_finish()

func _finish() -> void:
	print("BalanceRecorderTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
