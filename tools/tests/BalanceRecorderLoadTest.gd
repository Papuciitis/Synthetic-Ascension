extends Node

const Ledger := preload("res://core/systems/telemetry/BalanceLedger.gd")
const Writer := preload("res://core/systems/telemetry/BalanceCaptureWriter.gd")
const Queue := preload("res://autoload/performance/PerformanceIncidentWriteQueue.gd")
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

static func slow_write(batch: Dictionary, directory: String) -> Dictionary:
	OS.delay_msec(100)
	return Writer.write_batch(batch, directory)

func _run() -> void:
	var ledger := Ledger.new()
	ledger.start({}, 0, 2)
	ledger.enemy_seen(1, "load_fixture", false, 1000000.0)
	var started := Time.get_ticks_usec()
	for i in range(100000):
		ledger.enemy_damage(1, 1.0, 1.0, 1, 0, true)
	var usec := Time.get_ticks_usec() - started
	ledger.flush_window()
	_check(ledger.summary().totals.enemy_hp_removed == 100000.0, "100,000 hits keep exact totals")
	_check(ledger.take_records().size() == 2, "100,000 hits retain one metrics window instead of per-hit records")
	print("Balance ledger: 100000 hits in %d usec (%.3f usec/hit)" % [usec, float(usec) / 100000.0])
	# Exercise the two-batch cap with real, deliberately slow writes. Only the
	# worker latency changes; its outputs are real files.
	var recorder := get_node("/root/BalanceRecorder")
	var player := preload("res://core/actors/player/player.tscn").instantiate()
	Global.start_new_attempt()
	Global.attempt_segment = 2
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	recorder.record_headless = true
	recorder.report_directory = "user://balance_load_test_%d" % Time.get_ticks_usec()
	recorder._queue = Queue.new(slow_write)
	recorder.begin_gameplay(player)
	recorder.set_process(false)
	var path: String = recorder.capture_directory
	for i in range(40):
		Global.transaction_followers(1, &"combat_influence")
		recorder._submit(false)
	_check(recorder._queue.pending_count() <= 2, "runtime caps outstanding writes under backpressure")
	recorder.end_capture("load_test")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("summary.json")))
	_check(saved is Dictionary and saved.totals.followers_earned == 40 and saved.dropped_records == 0 and saved.writer_failures == 0, "finalization drains pending history and saves exact totals")
	var transactions := 0
	for line in FileAccess.get_file_as_string(path.path_join("events.jsonl")).split("\n", false):
		var event: Dictionary = JSON.parse_string(line)
		if event.kind == "transaction":
			transactions += 1
	_check(transactions == 40, "slow writer preserves each transaction exactly once")
	player.free()
	for name in ["events.jsonl", "summary.json", "report.md", "segments.csv"]:
		DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)
	print("BalanceRecorderLoadTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
