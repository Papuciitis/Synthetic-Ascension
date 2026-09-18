extends Node

# Balance plan Task 1: a capture must say which balance revision and tuning
# profile produced it (instrumentation-only captures stay at revision 1 with
# no profile hash), a Regeneration Ring heal must carry a stable item source,
# and Slow Heart's takeback and release must reconcile to observed HP
# without ever being counted as enemy damage. Real effects, real player.
#
# Run: <godot> --headless --path . res://tools/tests/BalanceRevisionTest.tscn

const PLAYER := preload("res://core/actors/player/player.tscn")
const SLOW_HEART := preload("res://effects/items/logic/curses/SlowHeartCurse.gd")
const RING := preload("res://effects/items/logic/RegenerationRingEffect.gd")

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
	Global.debug_player_god_mode = false
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
	var dir := "user://balance_revision_test_%s" % Time.get_ticks_usec()
	recorder.report_directory = dir
	recorder.record_headless = true
	recorder.begin_gameplay(player)
	recorder.set_process(false)

	# Revision and profile identity.
	var meta: Dictionary = recorder.get_summary().metadata
	var profile_exists := FileAccess.file_exists(recorder.TUNING_PROFILE_PATH)
	var expected_revision := 2 if profile_exists and ItemScaling.active() else 1
	_check(int(meta.balance_revision) == expected_revision and int(meta.recorder_revision) == 2 and ((meta.tuning_stages as Array) == (["items", "sets", "economy"] if expected_revision == 2 else ["sets", "economy"])), "the capture declares the live item-balance revision (%d) and its tuning stages" % expected_revision)
	var hash_now: String = recorder.tuning_hash()
	_check(String(meta.tuning_hash) == hash_now and hash_now == recorder.tuning_hash() and (profile_exists == (not hash_now.is_empty())), "the tuning hash is stable and empty exactly when no tuning profile exists (profile %s)" % ("present" if profile_exists else "absent"))
	var features: Dictionary = meta.features
	_check(int(recorder.get_summary().schema_version) == 2 and features.size() == 6 and bool(features.pure_snapshots) and bool(features.health_reconciliation) and bool(features.source_attribution), "schema 2 declares the six feature flags with the core ones measured")

	# Regeneration Ring: a stable item source that reconciles.
	player.hp = 50.0
	recorder._capture_sample()
	var ring: Node = RING.new()
	ring.setup_with_item(player, null, -1)
	add_child(ring)
	ring.set_process(false)
	ring._process(1.0)
	var summary: Dictionary = recorder.get_summary()
	var healed: float = float((summary.totals.healing_by_source as Dictionary).get("item:ring_regeneration", 0.0))
	_check(healed > 0.0 and player.hp == 50.0 + healed and float(summary.health.current_life.expected_hp) == player.hp, "a Regeneration Ring tick heals under item:ring_regeneration and reconciles (%.2f)" % healed)
	_check(not (summary.totals.healing_by_source as Dictionary).has("generic"), "the ring never hides behind the generic heal source")
	remove_child(ring)
	ring.free()

	# Slow Heart: the takeback is an adjustment, the release is healing; the
	# recorder counts no enemy damage for either.
	var lost_before: float = float(summary.totals.player_hp_lost)
	player.hp = 1.0
	# A direct HP set is an unexplained gap by design; the sample resyncs it.
	recorder._capture_sample()
	var unexplained_before: int = int(recorder.get_summary().health.totals.unexplained_checks)
	var slow: Node = SLOW_HEART.new()
	slow.setup_with_item(player, null, -1)
	add_child(slow)
	slow.set_process(false)
	player.heal(20.0, &"pickup")
	summary = recorder.get_summary()
	var life: Dictionary = summary.health.current_life
	_check(player.hp == 4.0 and float((life.by_source as Dictionary).get("item:curse_slow_heart", 0.0)) == -17.0 and float(life.expected_hp) == 4.0, "Slow Heart's takeback is an adjustment under the curse's source that reconciles (hp %.1f)" % player.hp)
	slow._process(1.0)
	summary = recorder.get_summary()
	_check(float((summary.totals.healing_by_source as Dictionary).get("item:curse_slow_heart", 0.0)) == 3.5 and player.hp == 7.5 and float(summary.health.current_life.expected_hp) == 7.5, "the release is healing under the curse's source and reconciles (hp %.1f)" % player.hp)
	recorder._capture_sample()
	summary = recorder.get_summary()
	_check(float(summary.totals.player_hp_lost) == lost_before and int(summary.health.totals.unexplained_checks) == unexplained_before, "neither the takeback nor the release is counted as enemy damage, and the curse's HP changes reconcile against a sample")
	remove_child(slow)
	slow.free()

	var capture_path: String = recorder.capture_directory
	recorder.end_capture("suspended")
	recorder.flush_reports()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(capture_path.path_join("summary.json")))
	_check(saved is Dictionary and int(saved.metadata.balance_revision) == expected_revision and String(saved.metadata.tuning_hash) == hash_now, "the saved capture carries the revision and hash")
	player.free()
	for name in ["events.jsonl", "summary.json", "report.md", "segments.csv"]:
		DirAccess.remove_absolute(capture_path.path_join(name))
	DirAccess.remove_absolute(capture_path)
	_finish()


func _finish() -> void:
	print("BalanceRevisionTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
