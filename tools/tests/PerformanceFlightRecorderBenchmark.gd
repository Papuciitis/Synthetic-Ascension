extends Node

const SAMPLE_COUNT := 100_000


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var script := load("res://autoload/PerformanceFlightRecorder.gd") as Script
	var recorder: Node = script.new()
	recorder.set_process(false)
	add_child(recorder)
	recorder.configure({
		"automatic_capture": false,
		"write_reports": false,
		"history_seconds": 10.0,
	})
	recorder.set_enabled(true)
	var started := Time.get_ticks_usec()
	for i in range(SAMPLE_COUNT):
		recorder.ingest_sample({
			"t_usec": i * 16_667,
			"frame_ms": 16.667,
			"fps": 60.0,
			"process_ms": 5.0,
			"physics_ms": 4.0,
			"enemies": 180,
			"projectiles": 550,
		})
	var elapsed := Time.get_ticks_usec() - started
	var average_usec := float(elapsed) / float(SAMPLE_COUNT)
	var bounded: bool = recorder.debug_history_size() <= recorder.debug_history_capacity()
	print(
		"PerformanceFlightRecorderBenchmark: samples=%d total_ms=%.2f average_usec=%.3f retained=%d capacity=%d"
		% [SAMPLE_COUNT, float(elapsed) / 1000.0, average_usec, recorder.debug_history_size(), recorder.debug_history_capacity()]
	)
	if not bounded:
		push_error("Flight recorder history grew beyond its capacity")
	recorder.queue_free()
	get_tree().quit(0 if bounded else 1)
