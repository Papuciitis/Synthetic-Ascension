extends Node

const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const WorldTypes = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")

class FlowCounterFixture:
	extends Node

	func get_debug_counters() -> Dictionary:
		return {
			"requested": 2,
			"started": 2,
			"completed": 1,
			"superseded": 0,
			"cells_total": 100,
			"cpu_us_total": 1000,
			"last_cells": 100,
			"last_cpu_us": 1000,
			"last_request_reason": &"test",
			"last_completed_reason": &"test",
			"player_moved": 0,
			"last_revision": 37,
			"pending_revision": 38,
			"pending": false,
			"building": false,
		}

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
	var world := get_node_or_null("/root/EnemyWorld")
	_check(world != null, "enemy world exists for recorder sampling")
	var logical_handles: Array[int] = []
	if world != null:
		world.call("clear_world")
		for i in range(500):
			var row := floori(float(i) / 25.0)
			var handle := int(world.call(
				"create_enemy",
				SpawnState.new(
					&"recorder_fixture",
					"res://recorder_fixture.tscn",
					Vector2(float(i % 25) * 64.0, float(row) * 64.0),
					10.0,
					10.0,
					5.0,
					0,
				),
			))
			logical_handles.append(handle)
			if i < 64:
				world.call("set_representation", handle, WorldTypes.Representation.MATERIALIZED)
	var flow_fixture := FlowCounterFixture.new()
	add_child(flow_fixture)
	flow_fixture.add_to_group(&"flow_field_nav")
	var slow_snapshot := recorder.call("_collect_slow_snapshot") as Dictionary
	var scheduler_data := slow_snapshot.get("enemy_scheduler", {}) as Dictionary
	var pool_data := slow_snapshot.get("enemy_pool", {}) as Dictionary
	_check(int(slow_snapshot.get("enemy_world_logical", -1)) == 500, "recorder samples logical enemies")
	_check(int(slow_snapshot.get("enemy_world_materialized", -1)) == 64, "recorder samples materialized enemies")
	_check(int(slow_snapshot.get("enemy_world_data_only", -1)) == 436, "recorder samples data-only enemies")
	_check(int(slow_snapshot.get("enemy_world_dying", -1)) == 0, "recorder samples dying enemies")
	_check(int(slow_snapshot.get("enemy_world_spatial_cells", -1)) > 0, "recorder samples spatial cells")
	_check(int(slow_snapshot.get("enemy_world_max_cell_occupancy", -1)) >= 1, "recorder samples cell occupancy")
	_check(int(slow_snapshot.get("flow_revision", -1)) == 37, "recorder reads the actual flow revision key")
	if world != null:
		for handle in logical_handles:
			world.call("remove_enemy", handle, &"recorder_test_cleanup")
	flow_fixture.remove_from_group(&"flow_field_nav")
	flow_fixture.free()
	for key in [&"full", &"mid", &"far", &"protected", &"physics_enabled", &"mid_steps", &"far_steps", &"assignment_usec"]:
		_check(scheduler_data.has(key), "slow snapshot includes scheduler %s" % key)
	for key in [&"reuse_hits", &"releases", &"inactive"]:
		_check(pool_data.has(key), "slow snapshot includes pool %s" % key)
	_check("debug_combat_transactions" in Global, "combat transaction logging has an explicit debug gate")
	if "debug_combat_transactions" in Global:
		Global.debug_combat_transactions = false
		var follower_result := Global.transaction_followers(2, &"recorder_test", {}, false, false)
		_check(int(follower_result.get("change", 0)) == 2, "disabled transaction logging preserves follower results")
		Global.transaction_followers(-2, &"recorder_test_cleanup", {}, false, false)
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

	recorder.clear_session()
	recorder.configure({
		"automatic_capture": false,
		"write_reports": true,
		"aftermath_seconds": 0.05,
		"cooldown_seconds": 0.0,
	})
	recorder.set("report_directory", "user://performance_capture_async_tests")
	var completed_report_paths: Array[String] = []
	recorder.incident_finalized.connect(func(_summary: Dictionary, path: String) -> void:
		completed_report_paths.append(path)
	)
	recorder.mark_incident(&"async_write_test")
	var async_start := Time.get_ticks_usec()
	for i in range(6):
		recorder.ingest_sample(_sample(async_start + i * 16_667, 18.0))
	_check(int(recorder.get_status_snapshot().get("pending_reports", 0)) == 1, "finalized report is queued off the game thread")
	recorder.set_process(true)
	var async_deadline := Time.get_ticks_msec() + 3000
	while completed_report_paths.is_empty() and Time.get_ticks_msec() < async_deadline:
		await get_tree().process_frame
	recorder.set_process(false)
	_check(completed_report_paths.size() == 1, "background report completion returns to the recorder")
	if completed_report_paths.size() == 1:
		_check(FileAccess.file_exists(completed_report_paths[0]), "background recorder writes the JSON report")
	_check(int(recorder.get_status_snapshot().get("pending_reports", -1)) == 0, "completed background report leaves no pending work")
	# Incident capture must not deep-copy the whole history ring on the spike
	# frame itself: samples are immutable after ingest, so capture shares them.
	recorder.clear_session()
	recorder.configure({"automatic_capture": false, "write_reports": false})
	recorder.ingest_sample(_sample(Time.get_ticks_usec(), 12.0))
	recorder.mark_incident(&"shared_capture_test")
	var history_head: Dictionary = (recorder.get("_history") as Array)[0]
	var capture_head: Dictionary = (recorder.get("_capture_samples") as Array)[0]
	_check(is_same(history_head, capture_head), "incident capture shares immutable samples instead of deep-copying the ring")

	# Counter cleanup must not deep-compare every bucket per expired event.
	recorder.clear_session()
	recorder.record_counter_event(&"trim", &"bucket_test", 3, {"detail": 1})
	var counter_event: Dictionary = (recorder.get("_events") as Array)[0]
	_check(counter_event.has("__bucket_key"), "counter events carry their bucket key for O(1) trim cleanup")
	recorder.ingest_sample(_sample(Time.get_ticks_usec() + 30_000_000, 10.0))
	_check((recorder.get("_counter_buckets") as Dictionary).is_empty(), "expired counter event releases its bucket")

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
