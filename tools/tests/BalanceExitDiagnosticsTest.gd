extends Node

# Exit and pressure diagnostics against the real owners of the state: the
# Exit Rite scene through entry, lapse, re-entry, death with retained
# progress and completion; the ThreatDirector's overtime clock with tagged
# injections from two contributors; the spawner's resolved requests and
# reservations. Every recorded number is compared with the owner's own state.
#
# Run: <godot> --headless --path . res://tools/tests/BalanceExitDiagnosticsTest.tscn

const PLAYER := preload("res://core/actors/player/player.tscn")
const SpawnState := preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const EXIT_RITE_SCENE: PackedScene = preload("res://scenes/world/gates/ExitRite.tscn")
const GOSPEL := preload("res://effects/manifestations/logic/OvertimeGospel.gd")
const BeatsScript := preload("res://core/systems/encounters/EncounterBeats.gd")

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
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.attempt_exit_hold_mul = 1.0
	Global.debug_player_god_mode = false
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.run_luck = 0.0
	Global.set_followers(5000)
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
	var dir := "user://balance_exit_test_%s" % Time.get_ticks_usec()
	recorder.report_directory = dir
	recorder.record_headless = true
	recorder.begin_gameplay(player)
	recorder.set_process(false)
	_check(recorder.is_recording() and bool(recorder.get_summary().metadata.features.exit_detail), "explicit headless capture starts with exit detail measured")
	var attacker := Node2D.new()
	attacker.global_position = player.global_position + Vector2(40, 0)
	add_child(attacker)
	var handle := EnemyWorld.create_enemy(SpawnState.new(&"recorder_normal", "res://recorder_normal.tscn", attacker.global_position, 50.0, 10.0, 8.0, 0, 0))
	EnemyWorld.bind_actor(handle, attacker)

	await _rite_checks(recorder, player, attacker)
	_overtime_checks(recorder, player)
	await _spawner_checks(recorder, player)

	var capture_path: String = recorder.capture_directory
	recorder.end_capture("suspended")
	recorder.flush_reports()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(capture_path.path_join("summary.json")))
	_check(saved is Dictionary and String(saved.segments[0].exit.status) == "completed" and int(saved.segments[0].exit.attempts) == 3 and bool(saved.metadata.features.exit_detail), "the saved summary carries the per-segment exit block")
	var report := FileAccess.get_file_as_string(capture_path.path_join("report.md"))
	_check(report.contains("## Exit and pressure") and report.contains("| completed |") and report.contains("Overtime clock injections") and report.contains("beat:spawned"), "the report explains exit, injections and spawn outcomes")
	EnemyWorld.remove_enemy(handle, &"test")
	attacker.free()
	player.free()
	for name in ["events.jsonl", "summary.json", "report.md", "segments.csv"]:
		DirAccess.remove_absolute(capture_path.path_join(name))
	DirAccess.remove_absolute(capture_path)
	_finish()


func _rite_checks(recorder: Node, player: Node, attacker: Node2D) -> void:
	var rite := EXIT_RITE_SCENE.instantiate() as ExitRite
	# Placed away from the player before it enters the tree: the zone is a real
	# Area2D, and a locked rite overlapping the body would backlash (a rejection
	# plus 0.4 s of invulnerability) on the first physics step.
	rite.position = player.global_position + Vector2(600, 0)
	add_child(rite)
	await get_tree().process_frame
	rite.set_process(false)
	recorder._process(0.5)
	rite.set_locked(false)
	recorder._process(1.0)
	var exit_seen: Dictionary = recorder._ledger._current.exit
	_check(String(exit_seen.status) == "unlocked" and exit_seen.unlocked_at != null, "the unlock is recorded with its gameplay time")

	# Attempt 1: enter, hold four seconds, step out past the grace, return.
	rite._on_body_entered(player)
	_check(bool(rite.balance_snapshot().inside) and int(exit_seen.attempts) == 1 and absf(float(exit_seen.unlock_to_first_channel) - 1.0) < 0.000001, "an actual channel entry is the first attempt, timed from the unlock (%.2f s)" % float(exit_seen.unlock_to_first_channel))
	for i in range(40):
		rite._process(0.1)
	var hold_before_lapse: float = rite.get("_hold")
	_check(hold_before_lapse > 3.9, "the rite really channelled (%.2f s)" % hold_before_lapse)
	rite._on_body_exited(player)
	for i in range(30):
		rite._process(0.1)
	var hold_after_lapse: float = rite.get("_hold")
	_check(bool(rite.balance_snapshot().lapse_draining) and hold_after_lapse < hold_before_lapse and int(exit_seen.lapses) == 1, "the lapse past the grace drained progress and is counted once (%.2f -> %.2f)" % [hold_before_lapse, hold_after_lapse])
	rite._on_body_entered(player)
	rite._process(0.1)
	_check(int(exit_seen.attempts) == 2 and absf(float(exit_seen.progress_lost.lapse) - (hold_before_lapse - hold_after_lapse)) < 0.000001, "re-entry is the second attempt and the lapse loss equals the rite's own drain (%.3f)" % float(exit_seen.progress_lost.lapse))

	# A real death inside the channel, reconstruction, and a second death
	# within ten seconds of it.
	player.invulnerable_time = 0.0
	player.take_damage(1000.0, attacker)
	_check(not bool(player.is_dead) and int(exit_seen.deaths_while_channeling) == 1, "a death inside the circle counts as a channeling death")
	recorder._process(0.5)
	player.invulnerable_time = 0.0
	player.take_damage(1000.0, attacker)
	_check(int(exit_seen.deaths_while_channeling) == 2 and int(exit_seen.deaths_after_reconstruction) == 1 and int(exit_seen.reconstruction_spent) > 0, "a death half a second after reconstruction is a reconstruction death with its spending (%d Followers)" % int(exit_seen.reconstruction_spent))
	# The rite's own death rule: the dead body keeps a share of the progress.
	var hold_before_death: float = rite.get("_hold")
	player.is_dead = true
	rite._process(0.1)
	player.is_dead = false
	var hold_after_death: float = rite.get("_hold")
	_check(hold_after_death < hold_before_death and absf(float(exit_seen.progress_lost.death) - (hold_before_death - hold_after_death)) < 0.000001, "death retention loss is recorded exactly as the rite applied it (%.3f)" % float(exit_seen.progress_lost.death))
	# Back to the circle after the reconstruction: the time back is measured.
	rite._on_body_exited(player)
	recorder._process(0.7)
	rite._on_body_entered(player)
	_check(int(exit_seen.attempts) == 3 and exit_seen.reentry_seconds.size() == 1 and absf(float(exit_seen.reentry_seconds[0]) - 0.7) < 0.000001, "time from reconstruction back to the channel is recorded (%.2f s)" % float(exit_seen.reentry_seconds[0]))
	player.invulnerable_time = 0.0

	# Completion: seals fire on the way, the climax completes the rite.
	for i in range(260):
		rite._process(0.1)
		if bool(rite.get("_completed")):
			break
	var snapshot: Dictionary = rite.balance_snapshot()
	_check(bool(snapshot.completed) and String(exit_seen.status) == "completed" and exit_seen.completed_at != null, "completion is recorded when the rite completes")
	_check(int(exit_seen.seals) == int(snapshot.seals) and int(snapshot.seals) == 3, "every automatic seal is counted against the rite's ledger (%d)" % int(exit_seen.seals))
	_check(float(exit_seen.channel_seconds) > 0.0 and int(exit_seen.rejections) == 0, "channel time accumulates across attempts (%.1f s)" % float(exit_seen.channel_seconds))
	rite.set_locked(true)
	rite._on_body_entered(player)
	_check(int(exit_seen.rejections) == 1, "a locked rite's backlash is a rejection, not an attempt")
	rite.queue_free()


func _overtime_checks(recorder: Node, player: Node) -> void:
	var director := ThreatDirector
	director.reset_run_state()
	director._on_resonance_changed(1.0)
	_check(bool(director.gate_unsealed), "resonance unseals the gate")
	director._process(10.0)
	var elapsed_before: float = director._unseal_time
	director.add_overtime_pressure(20.0, "gospel:A")
	director.add_overtime_pressure(25.0, "gospel:B")
	var snapshot: Dictionary = director.balance_snapshot()
	var k_excess := maxi(0, int(director._kills_since_unseal) - int(director.overtime_kill_buffer))
	var expected := float(director._unseal_time) * float(director.overtime_time_rate) + float(k_excess) * float(director.overtime_kill_rate) * float(director.dominance_mul)
	_check(is_equal_approx(float(director.overtime), expected) and is_equal_approx(float(director._unseal_time), elapsed_before + 45.0), "final overtime equals the pre-instrumentation formula over the injected clock (%.4f)" % float(director.overtime))
	_check(is_equal_approx(float(snapshot.injected_seconds), 45.0) and is_equal_approx(float(snapshot.elapsed_unseal_seconds) + float(snapshot.injected_seconds), float(snapshot.unseal_seconds)), "the director reports elapsed and injected clock separately, summing to the clock it uses")
	_check(is_equal_approx(float(snapshot.overtime_time_part) + float(snapshot.overtime_kill_part), float(director.overtime)), "the time and kill components sum to the overtime")
	var recorded: Dictionary = recorder._ledger._current.exit.overtime
	_check(is_equal_approx(float(recorded.injections.get("gospel:A", 0.0)), 20.0) and is_equal_approx(float(recorded.injections.get("gospel:B", 0.0)), 25.0) and is_equal_approx(float(recorded.injected_seconds), 45.0) and is_equal_approx(float(recorded.final_overtime), float(director.overtime)), "two contributors are recorded separately and sum to 45 injected seconds")
	# A real Gospel instance tags its slot and item instance.
	var gospel = GOSPEL.new()
	gospel.setup_manifestation(player, null, 5, null, null)
	add_child(gospel)
	gospel.set_process(false)
	gospel._open_gospel()
	gospel._preach()
	var tag: String = gospel.contributor_tag()
	_check(tag.begins_with("manifestation:overtime_gospel@slot5#") and is_equal_approx(float(recorded.injections.get(tag, 0.0)), 20.0) and is_equal_approx(float(recorded.injected_seconds), 65.0), "a real Gospel sermon injects its 20 s under a slot-tagged contributor (%s)" % tag)
	gospel.queue_free()
	director.reset_run_state()


func _spawner_checks(recorder: Node, player: Node) -> void:
	var spawner := EnemySpawner.new()
	spawner.spawning_enabled = false
	add_child(spawner)
	await get_tree().process_frame
	spawner.set_process(false)
	var pos: Vector2 = player.global_position + Vector2(300, 0)
	_check(spawner.spawn_beat_member(BeatsScript.GRUNT, pos) == null, "a disabled spawner refuses a beat member")
	spawner.spawning_enabled = true
	var index := EnemyIndex
	var saved_cap: int = index.special_population_cap
	index.special_population_cap = 0
	_check(spawner.spawn_beat_member(BeatsScript.GRUNT, pos) == null, "an exhausted special cap refuses a beat member")
	index.special_population_cap = saved_cap
	var reserved_before: int = index._special_reserved_total
	var member: Node = spawner.spawn_beat_member(BeatsScript.GRUNT, pos)
	_check(member != null, "a beat member spawns for real")
	var pending_snapshot: Dictionary = spawner.balance_snapshot()
	var reserved_mid: int = index._special_reserved_total
	_check(int(pending_snapshot.pending_spawns) == int(spawner._pending_spawn_total) and int(spawner._pending_spawn_total) == 1, "the deferred member is a pending reservation until it enters the tree (%d)" % int(spawner._pending_spawn_total))
	_check(reserved_mid == reserved_before + 1, "the beat member holds one special reservation until it registers")
	await get_tree().process_frame
	_check(int(spawner._pending_spawn_total) == 0 and int(spawner.balance_snapshot().pending_spawns) == 0, "the reservation releases when the member enters the tree")
	var reserved_now: int = index._special_reserved_total
	spawner.balance_snapshot()
	recorder.get_summary()
	recorder._capture_sample()
	_check(index._special_reserved_total == reserved_now and int(spawner._pending_spawn_total) == 0, "reading the snapshot, the summary and a sample reserves nothing")
	spawner.set_rite_pressure_active(true)
	spawner.spawn_burst(3)
	spawner._on_tick()
	spawner.set_rite_pressure_active(false)
	var spawns: Dictionary = recorder._ledger._current.exit.spawns
	_check(int(spawns.get("beat:spawning_disabled", {}).get("requests", 0)) == 1 and int(spawns.get("beat:special_cap", {}).get("requests", 0)) == 1, "beat refusals are recorded by reason")
	_check(int(spawns.get("beat:spawned", {}).get("requests", 0)) == 1 and int(spawns.get("beat:spawned", {}).get("enemies", 0)) == 1, "the accepted beat member is recorded once")
	_check(int(spawns.get("burst:rite_pressure", {}).get("requests", 0)) == 1 and int(spawns.get("ambient:rite_pressure", {}).get("requests", 0)) == 1, "ambient and burst requests refused by the rite are recorded with that reason")
	var snapshot_after: Dictionary = spawner.balance_snapshot()
	_check(not bool(snapshot_after.rite_pressure_active) and int(snapshot_after.cap) > 0 and snapshot_after.has("pending_spawns"), "the spawner snapshot reads population and gates (cap %d)" % int(snapshot_after.cap))
	if member != null and is_instance_valid(member):
		member.queue_free()
	spawner.queue_free()
	await get_tree().process_frame


func _finish() -> void:
	print("BalanceExitDiagnosticsTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
