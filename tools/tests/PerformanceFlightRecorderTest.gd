extends Node

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var script := load("res://autoload/PerformanceFlightRecorder.gd") as Script
	_check(script != null, "flight recorder script exists")
	if script == null:
		_finish()
		return
	var recorder: Node = script.new()
	recorder.set_process(false)
	add_child(recorder)
	recorder.configure({
		"history_seconds": 1.0,
		"aftermath_seconds": 0.1,
		"cooldown_seconds": 0.1,
		"absolute_threshold_ms": 30.0,
		"relative_multiplier": 2.0,
		"automatic_capture": true,
		"write_reports": false,
	})
	recorder.set_enabled(true)
	for i in range(120):
		recorder.ingest_sample(_sample(i * 16_667, 16.0))
	_check(recorder.debug_history_size() <= recorder.debug_history_capacity(), "history remains bounded")
	recorder.ingest_sample(_sample(2_100_000, 45.0))
	_check(recorder.get_status_snapshot().get("state") == "aftermath", "absolute spike triggers aftermath")
	for i in range(10):
		recorder.ingest_sample(_sample(2_116_667 + i * 16_667, 16.0))
	_check(not recorder.get_latest_incident().is_empty(), "aftermath finalizes an incident")
	var incident: Dictionary = recorder.get_latest_incident()
	_check(float(incident.get("summary", {}).get("worst_frame_ms", 0.0)) >= 45.0, "summary retains worst frame")
	_check((incident.get("samples", []) as Array).size() <= 80, "incident keeps bounded pre-history")

	recorder.clear_session()
	recorder.configure({"automatic_capture": false, "write_reports": false})
	recorder.mark_incident(&"manual_test")
	_check(recorder.get_status_snapshot().get("state") == "aftermath", "manual marker triggers capture")

	recorder.clear_session()
	recorder.set_enabled(false)
	recorder.ingest_sample(_sample(5_000_000, 90.0))
	_check(recorder.get_status_snapshot().get("state") == "disabled", "disabled recorder ignores spikes")

	recorder.set_enabled(true)
	recorder.configure({"automatic_capture": false, "write_reports": false})
	recorder.record_counter_event(&"spawn", &"grunt", 40)
	recorder.record_counter_event(&"spawn", &"grunt", 20)
	_check(recorder.debug_event_total(&"spawn", &"grunt") == 60, "counter events aggregate")
	recorder.record_event(&"flow", &"rebuild_started", {"revision": 3})
	recorder.mark_incident(&"event_test")
	var event_test_start := Time.get_ticks_usec()
	for i in range(10):
		recorder.ingest_sample(_sample(event_test_start + i * 16_667, 18.0))
	incident = recorder.get_latest_incident()
	_check(not (incident.get("events", []) as Array).is_empty(), "incident contains correlated events")
	var report_result := PerformanceIncidentWriter.write_incident(incident, "user://performance_capture_tests")
	_check(bool(report_result.get("ok", false)), "incident writer creates reports")
	_check(FileAccess.file_exists(String(report_result.get("json_path", ""))), "JSON report exists")
	_check(FileAccess.file_exists(String(report_result.get("csv_path", ""))), "CSV timeline exists")
	var report_file := FileAccess.open(String(report_result.get("json_path", "")), FileAccess.READ)
	var parsed: Variant = JSON.parse_string(report_file.get_as_text()) if report_file != null else null
	_check(parsed is Dictionary and int((parsed as Dictionary).get("schema_version", 0)) == 1, "JSON report has versioned schema")
	recorder.queue_free()
	_finish()


func _sample(t_usec: int, frame_ms: float) -> Dictionary:
	return {
		"t_usec": t_usec,
		"elapsed_sec": float(t_usec) / 1_000_000.0,
		"frame_ms": frame_ms,
		"fps": 1000.0 / maxf(frame_ms, 0.001),
		"process_ms": frame_ms * 0.6,
		"physics_ms": frame_ms * 0.4,
		"enemies": 180,
		"projectiles": 550,
	}


func _finish() -> void:
	print("PerformanceFlightRecorderTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
