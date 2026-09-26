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

	# The worker must only ever see pure data (the 2026-09-26 playtest crash:
	# a live Object inside a sample was stringified from the worker thread —
	# scene-tree thread guard, then signal 11). Enqueue sanitizes ONCE on the
	# main thread; identity passthrough was the old, crashing contract.
	var passthrough_queue: RefCounted = queue_script.new(Callable(self, "_instant_writer"))
	var live_node := Node.new()
	add_child(live_node)
	var freed_node := Node.new()
	freed_node.free()
	var owned_incident := {"metadata": {"sequence": 7}, "samples": [{"who": live_node, "gone": freed_node, "at": Vector2(3, 4)}]}
	passthrough_queue.call("enqueue", owned_incident, "user://ignored-by-test")
	var handed_over: Array = passthrough_queue.call("shutdown") as Array
	var handed: Dictionary = (handed_over[0] as Dictionary).get("incident", {}) if handed_over.size() == 1 else {}
	var sample_row: Dictionary = ((handed.get("samples", []) as Array)[0] as Dictionary) if not handed.is_empty() else {}
	_check(handed_over.size() == 1 and not is_same(handed, owned_incident), "enqueue hands the worker a sanitized copy, never the live dict")
	_check(String(sample_row.get("who", "")).begins_with("<Node#"), "a live Object becomes a tag, never a cross-thread call (%s)" % str(sample_row.get("who")))
	_check(String(sample_row.get("gone", "")) == "<freed object>", "a freed Object becomes a tag instead of a segfault")
	_check(String(sample_row.get("at", "")).begins_with("("), "vectors serialize as text")
	_check(JSON.stringify(handed) != "", "the sanitized incident stringifies without touching the tree")
	live_node.queue_free()
	_finish()


func _instant_writer(incident: Dictionary, _directory: String) -> Dictionary:
	var metadata := incident.get("metadata", {}) as Dictionary
	return {
		"ok": true,
		"json_path": "memory://instant-%03d.json" % int(metadata.get("sequence", 0)),
		"csv_path": "memory://instant-%03d.csv" % int(metadata.get("sequence", 0)),
		"error": "",
		"sequence": int(metadata.get("sequence", 0)),
	}


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
