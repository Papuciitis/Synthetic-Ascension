extends Node

const QUEUE_SCRIPT_PATH := "res://autoload/performance/PerformanceIncidentWriteQueue.gd"

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
	_check(ResourceLoader.exists(QUEUE_SCRIPT_PATH), "background incident write queue exists")
	if not ResourceLoader.exists(QUEUE_SCRIPT_PATH):
		_finish()
		return

	var queue_script := load(QUEUE_SCRIPT_PATH) as Script
	var write_queue: RefCounted = queue_script.new(Callable(self, "_slow_writer"))
	var enqueue_started := Time.get_ticks_msec()
	write_queue.call("enqueue", _incident(1), "user://ignored-by-test")
	write_queue.call("enqueue", _incident(2), "user://ignored-by-test")
	var enqueue_elapsed := Time.get_ticks_msec() - enqueue_started
	_check(enqueue_elapsed < 50, "enqueue does not wait for slow report serialization")
	_check(int(write_queue.call("pending_count")) == 2, "active and queued reports remain observable")

	var completed: Array = []
	var deadline := Time.get_ticks_msec() + 3000
	while completed.size() < 2 and Time.get_ticks_msec() < deadline:
		completed.append_array(write_queue.call("poll_completed") as Array)
		await get_tree().process_frame

	_check(completed.size() == 2, "both queued reports finish in the background")
	if completed.size() == 2:
		var first_result := (completed[0] as Dictionary).get("result", {}) as Dictionary
		var second_result := (completed[1] as Dictionary).get("result", {}) as Dictionary
		_check(int(first_result.get("sequence", 0)) == 1, "reports complete in enqueue order")
		_check(int(second_result.get("sequence", 0)) == 2, "the next report starts after the first")
	write_queue.call("shutdown")
	_finish()


func _slow_writer(incident: Dictionary, _directory: String) -> Dictionary:
	OS.delay_msec(200)
	var metadata := incident.get("metadata", {}) as Dictionary
	return {
		"ok": true,
		"json_path": "memory://incident-%03d.json" % int(metadata.get("sequence", 0)),
		"csv_path": "memory://incident-%03d.csv" % int(metadata.get("sequence", 0)),
		"error": "",
		"sequence": int(metadata.get("sequence", 0)),
	}


func _incident(sequence: int) -> Dictionary:
	return {
		"schema_version": 1,
		"metadata": {"sequence": sequence, "segment": 2},
		"summary": {"worst_frame_ms": 40.0 + sequence},
		"samples": [],
		"events": [],
	}


func _finish() -> void:
	print("PerformanceIncidentWriteQueueTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
