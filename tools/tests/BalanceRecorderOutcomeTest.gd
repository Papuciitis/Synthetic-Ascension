extends Node

# Runtime recorder against the real player and the real advancement-tree
# rules that produce the damage outcomes the core ledger must not drop:
# a lethal hit intercepted by Last Hit, a swing REWRITE makes miss, a rule's
# self-damage, and developer funding through the dev route loader's reason.
#
# Run: <godot> --headless --path . res://tools/tests/BalanceRecorderOutcomeTest.tscn

const PLAYER = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

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


func _own(runner: AscensionRunner, native: String, ids: Array) -> void:
	Global.selected_style_id = native
	Global.attempt_ascension = AscensionLedger.fresh_state(native)
	var ledger := Global.ascension_ledger()
	ledger.note_segment_completed(9)
	for id in ids:
		ledger.record_purchase(String(id), 100)
	runner.q_cooldown_left = 0.0
	runner._v_gap_left = 0.0
	runner.refresh()


func _run() -> void:
	var recorder := get_node_or_null("/root/BalanceRecorder")
	_check(recorder != null, "runtime balance recorder is installed")
	if recorder == null:
		_finish()
		return
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.debug_player_god_mode = false
	Global.debug_ascension_revelations_enabled = true
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.run_luck = 0.0
	Global.set_followers(100)
	var player = PLAYER.instantiate()
	add_child(player)
	await get_tree().process_frame
	player.set_process(false)
	player.set_physics_process(false)
	player.stats = Stats.new()
	player.stats.armor = 0.0
	player.max_hp = 100.0
	player.hp = 100.0
	player.invulnerable_time = 0.0
	var runner := player.get_node("AscensionRunner") as AscensionRunner
	runner.set_process(false)
	var dir := "user://balance_outcome_test_%s" % Time.get_ticks_usec()
	recorder.report_directory = dir
	recorder.record_headless = true
	recorder.begin_gameplay(player)
	recorder.set_process(false)
	_check(recorder.is_recording(), "explicit headless capture starts")
	var attacker := Node2D.new()
	attacker.global_position = player.global_position + Vector2(40, 0)
	add_child(attacker)
	var handle := EnemyWorld.create_enemy(SpawnState.new(&"recorder_normal", "res://recorder_normal.tscn", attacker.global_position, 50.0, 10.0, 8.0, 0, 0))
	EnemyWorld.bind_actor(handle, attacker)

	# Last Hit (Bastion): a lethal hit leaves the player at 1 HP. The health
	# it removed is real and the hit must count once as intercepted.
	_own(runner, "melee", ["BA01", "BA12"])
	var bastion := runner.engine_of_discipline("BA") as BastionEngine
	_check(bastion != null, "the Bastion engine loads for the outcome fixture")
	bastion.force = 60.0
	player.hp = 10.0
	player.take_damage(50.0, attacker)
	var summary: Dictionary = recorder.get_summary()
	_check(player.hp == 1.0 and summary.totals.deaths == 0, "the real rule intercepted the lethal hit (hp %.1f)" % player.hp)
	_check(summary.totals.player_hp_lost == 9.0 and summary.totals.player_overkill == 41.0 and summary.totals.intercepted_hits == 1, "the intercepted hit charges 9 HP, 41 overkill and counts once (lost %.1f, overkill %.1f, intercepted %d)" % [summary.totals.player_hp_lost, summary.totals.player_overkill, int(summary.totals.intercepted_hits)])
	_check(summary.totals.player_damage_by_source.get("recorder_normal", 0.0) == 9.0, "the intercepted hit is attributed to its enemy source")

	# REWRITE (Distortion): a normal's adjacent swing misses; no HP moves.
	# (Last Hit granted 0.5 s of invulnerability; the player does not tick here.)
	player.invulnerable_time = 0.0
	player.hp = 50.0
	_own(runner, "magic", ["DT01", "DT06", "DTV"])
	runner.v_charge = AscensionRunner.V_CHARGE_MAX
	var verdict: Dictionary = runner.activate_v()
	_check(bool(verdict.get("ok", false)), "REWRITE starts (%s)" % String(verdict.get("message", "")))
	player.take_damage(10.0, attacker)
	summary = recorder.get_summary()
	_check(player.hp == 50.0 and summary.totals.missed_hits == 1 and summary.totals.player_hp_lost == 9.0, "a rule-made miss counts as an avoided hit without HP loss (missed %d)" % int(summary.totals.missed_hits))

	# Danger Close (Ordnance): a blast covering the player is self-damage
	# with its own source label, through the real player damage path.
	_own(runner, "ranged", ["OR01", "OR02", "OR03", "OR04", "ORK2"])
	var ordnance := runner.engine_of_discipline("OR") as OrdnanceEngine
	_check(ordnance != null, "the Ordnance engine loads for the self-damage fixture")
	player.invulnerable_time = 0.0
	player.hp = 50.0
	ordnance.call_shell(player.global_position)
	ordnance.tick(0.7)
	runner.flush_attacks()
	summary = recorder.get_summary()
	_check(player.hp < 50.0 and summary.totals.player_damage_by_source.get("self_damage", 0.0) > 0.0 and int(ordnance.counters.get("self_hits", 0)) == 1, "a rule's self-damage is attributed to self_damage (hp %.1f)" % player.hp)

	# Developer funding through the wallet uses the loader's reason and must
	# not become earned income; the wallet still reconciles.
	Global.transaction_followers(13200, &"dev_grant", {"source": "ascension route"})
	Global.transaction_followers(-12000, &"ascension_purchase", {"node": "fixture"})
	Global.transaction_followers(30, &"combat_influence", {"enemy_id": "fixture"})
	summary = recorder.get_summary()
	var t: Dictionary = summary.totals
	_check(t.followers_debug == 13200 and t.followers_earned == 30 and t.followers_spent == 12000, "runtime developer grants land in their own bucket (debug %d, earned %d)" % [int(t.followers_debug), int(t.followers_earned)])
	_check(t.followers_open + t.followers_earned - t.followers_spent + t.followers_adjustments + t.followers_debug == t.followers_close and summary.wallet_discontinuities == 0, "the runtime wallet reconciles through the debug bucket")

	var capture_path: String = recorder.capture_directory
	recorder.end_capture("suspended")
	recorder.flush_reports()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(capture_path.path_join("summary.json")))
	_check(saved is Dictionary and int(saved.totals.intercepted_hits) == 1 and int(saved.totals.missed_hits) == 1 and int(saved.totals.followers_debug) == 13200, "the saved summary carries the new outcome and debug fields")
	var report := FileAccess.get_file_as_string(capture_path.path_join("report.md"))
	_check(report.contains("Lethal hits intercepted") and report.contains("Debug grants"), "the report names intercepted hits and debug grants")
	var csv := FileAccess.get_file_as_string(capture_path.path_join("segments.csv"))
	_check(csv.begins_with("segment,status,seconds_gameplay,seconds_paused,seconds_hub,seconds_loading,") and csv.contains("followers_debug"), "the segment export carries loading time and debug grants")
	EnemyWorld.remove_enemy(handle, &"test")
	attacker.free()
	Global.attempt_ascension = {}
	player.free()
	for name in ["events.jsonl", "summary.json", "report.md", "segments.csv"]:
		DirAccess.remove_absolute(capture_path.path_join(name))
	DirAccess.remove_absolute(capture_path)
	_finish()


func _finish() -> void:
	print("BalanceRecorderOutcomeTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
