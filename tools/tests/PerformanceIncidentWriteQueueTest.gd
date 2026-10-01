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

	# The copy is budgeted (2026-09-30: a 900-sample incident copied in one
	# go was a 260-340 ms frame, the captures' "sampling" stalls). A big
	# incident advances a slice per step, never much past the budget, and
	# the result is exactly what the one-shot copy made: same report bytes.
	var template := {"t_usec": 1, "enemy_scheduler": {"physics_step_ms": 3.5, "buckets": [1, 2, 3]}, "at": Vector2(1, 2), "tag": &"x"}
	var rows: Array = []
	for i in range(900):
		var row := template.duplicate(true)
		row["t_usec"] = i
		rows.append(row)
	var big := {"schema_version": 1, "metadata": {"sequence": 9}, "summary": {"worst_frame_ms": 50.0}, "samples": rows, "events": [{"t_usec": 3, "at": Vector2(5, 6)}]}
	var sliced_queue: RefCounted = queue_script.new(Callable(self, "_instant_writer"))
	sliced_queue.call("enqueue", big, "user://ignored-by-test")
	var steps := 0
	var worst_step_usec := 0
	var budget_usec := int(sliced_queue.get("STEP_BUDGET_USEC"))
	while int(sliced_queue.call("pending_count")) > 0 and steps < 10_000 and (sliced_queue.get("_sanitizing") as Array).size() > 0:
		var started := Time.get_ticks_usec()
		sliced_queue.call("step")
		worst_step_usec = maxi(worst_step_usec, Time.get_ticks_usec() - started)
		steps += 1
	_check(steps > 1, "a big incident is copied over several steps, not one (%d steps)" % steps)
	_check(worst_step_usec < budget_usec + 5000, "no step runs far past its budget (%d usec, budget %d)" % [worst_step_usec, budget_usec])
	var sliced_done: Array = sliced_queue.call("shutdown") as Array
	var sliced_copy: Dictionary = (sliced_done[0] as Dictionary).get("incident", {}) if sliced_done.size() == 1 else {}
	_check(JSON.stringify(sliced_copy) == JSON.stringify(PerformanceIncidentWriter._json_safe(big)), "the budgeted copy is byte-identical to the one-shot copy")

	# Exit never loses a report: shutdown finishes a copy left half-way.
	var half_queue: RefCounted = queue_script.new(Callable(self, "_instant_writer"))
	half_queue.call("enqueue", big, "user://ignored-by-test")
	half_queue.call("step", 1)
	var half_done: Array = half_queue.call("shutdown") as Array
	var half_copy: Dictionary = (half_done[0] as Dictionary).get("incident", {}) if half_done.size() == 1 else {}
	_check(half_done.size() == 1 and (half_copy.get("samples", []) as Array).size() == 900, "shutdown completes and writes a copy interrupted mid-way")

	# The recorder merges one 0.5 s slow snapshot into ~30 samples BY
	# REFERENCE, so consecutive samples carry the very same nested values.
	# Copying them again for every sample was most of the incident copy (the
	# 2026-10-01 captures: 23% of all frames spent 1.5-2 ms in it). A nested
	# value that IS the previous sample's is copied once and shared by the
	# output rows; the report bytes do not change.
	var shared_node := Node.new()
	add_child(shared_node)
	var snapshot_a := {"physics_step_ms": 3.5, "lifecycle": {"tier_changes": 7}, "owner": shared_node}
	var snapshot_b := {"physics_step_ms": 4.5, "lifecycle": {"tier_changes": 8}}
	var tiers := [3, 2, 1]
	var shared_rows: Array = []
	for i in range(6):
		var shared_row := {"t_usec": i, "enemy_scheduler": (snapshot_a if i < 3 else snapshot_b), "enemy_tiers": tiers, "ascension": {"tick_usec": i}, "at": Vector2(i, 1)}
		if i == 4:
			shared_row.erase("enemy_scheduler")
		shared_rows.append(shared_row)
	var shared_incident := {"schema_version": 1, "metadata": {"sequence": 11}, "samples": shared_rows, "events": [{"t_usec": 2, "details": snapshot_b}]}
	var shared_queue: RefCounted = queue_script.new(Callable(self, "_instant_writer"))
	shared_queue.call("enqueue", shared_incident, "user://ignored-by-test")
	var shared_steps := 0
	while (shared_queue.get("_sanitizing") as Array).size() > 0 and shared_steps < 10_000:
		# A one-microsecond budget: the copy stops after every sample, so the
		# sharing has to survive from one step to the next.
		shared_queue.call("step", 1)
		shared_steps += 1
	var shared_done: Array = shared_queue.call("shutdown") as Array
	var shared_copy: Dictionary = (shared_done[0] as Dictionary).get("incident", {}) if shared_done.size() == 1 else {}
	var out_rows: Array = shared_copy.get("samples", [])
	_check(out_rows.size() == 6 and JSON.stringify(shared_copy) == JSON.stringify(PerformanceIncidentWriter._json_safe(shared_incident)), "samples sharing nested values copy to the same report bytes")
	if out_rows.size() == 6:
		_check(is_same(out_rows[0]["enemy_scheduler"], out_rows[1]["enemy_scheduler"]) and is_same(out_rows[1]["enemy_scheduler"], out_rows[2]["enemy_scheduler"]), "a nested value shared by consecutive samples is copied once")
		_check(is_same(out_rows[0]["enemy_tiers"], out_rows[5]["enemy_tiers"]), "a shared array is copied once across the whole run of samples")
		_check(not is_same(out_rows[0]["enemy_scheduler"], snapshot_a) and String(out_rows[0]["enemy_scheduler"]["owner"]).begins_with("<Node#"), "the shared copy is still a sanitized copy, never the live dictionary")
		_check(not is_same(out_rows[2]["enemy_scheduler"], out_rows[3]["enemy_scheduler"]) and is_equal_approx(float(out_rows[3]["enemy_scheduler"]["physics_step_ms"]), 4.5), "a new snapshot gets its own copy")
		_check(not (out_rows[4] as Dictionary).has("enemy_scheduler") and int(out_rows[5]["enemy_scheduler"]["lifecycle"]["tier_changes"]) == 8, "a sample without the key breaks the chain; the next one is copied afresh")
		_check(not is_same(out_rows[0]["ascension"], out_rows[1]["ascension"]) and int(out_rows[1]["ascension"]["tick_usec"]) == 1, "per-frame values keep their own copies")
	shared_node.queue_free()

	# The recorder closes an incident with an EMPTY summary: building it (a
	# pass over ~900 samples plus the hitch tags) was 5-27 ms on the closing
	# frame in the 2026-10-01 captures. The worker builds it from its own
	# copy, in place, so the report reads exactly as before.
	var summary_rows: Array = []
	for i in range(40):
		summary_rows.append({"t_usec": 1_000_000 + i * 16_667, "frame_ms": 16.0, "wall_ms": (45.0 if i == 20 else 16.0)})
	var unsummarized := {"schema_version": 1, "metadata": {"sequence": 12}, "summary": {}, "samples": summary_rows, "events": [{"t_usec": 1_100_000, "category": "enemy", "name": "died", "details": {}}]}
	var summary_queue: RefCounted = queue_script.new(Callable(self, "_instant_writer"))
	summary_queue.call("enqueue", unsummarized, "user://ignored-by-test")
	var summarized_done: Array = summary_queue.call("shutdown") as Array
	var summarized: Dictionary = (summarized_done[0] as Dictionary).get("incident", {}) if summarized_done.size() == 1 else {}
	var built: Dictionary = summarized.get("summary", {})
	_check(int(built.get("hitch_count", -1)) == 1 and is_equal_approx(float(built.get("worst_wall_ms", 0.0)), 45.0), "an incident handed over with an empty summary gets it built by the writer (%d hitch, worst %.1f ms)" % [int(built.get("hitch_count", -1)), float(built.get("worst_wall_ms", 0.0))])
	_check(summarized.keys() == ["schema_version", "metadata", "summary", "samples", "events"], "the summary keeps its place in the report")
	_check(JSON.stringify(built) == JSON.stringify(PerformanceFlightRecorder.call("_build_summary", summary_rows, unsummarized["events"])), "and is what the recorder itself would have built")
	_check((unsummarized["summary"] as Dictionary).is_empty(), "the recorder's own incident is not written to from the worker")
	_check(is_equal_approx(float((sliced_copy.get("summary", {}) as Dictionary).get("worst_frame_ms", 0.0)), 50.0) and (sliced_copy.get("summary", {}) as Dictionary).size() == 1, "a summary that is already there is left alone")
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
