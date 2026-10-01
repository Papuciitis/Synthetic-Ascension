extends RefCounted
class_name PerformanceIncidentWriteQueue

## Main-thread work allowed per step() while an incident is being copied.
## The worker may only ever see pure data (see enqueue), but copying a whole
## incident at once was the recorder's own hitch: ~900 samples x ~130 values
## is 260-340 ms of GDScript on one frame (the 2026-09-27 "sampling" stalls,
## PerformanceIncidentFinalizeBenchmark). The copy now advances one sample at
## a time under this budget; a report reaches the worker a few seconds later.
const STEP_BUDGET_USEC := 1500

var _writer: Callable
## Incidents still being copied on the main thread, oldest first:
## {source, directory, keys, key_index, item_index, partial, output}.
var _sanitizing: Array[Dictionary] = []
var _jobs: Array[Dictionary] = []
var _completed: Array[Dictionary] = []
var _thread: Thread = null
var _active_job: Dictionary = {}


func _init(writer: Callable = Callable()) -> void:
	_writer = writer


func enqueue(incident: Dictionary, directory: String) -> void:
	# The worker must only ever see pure data. The old contract handed the
	# incident over as-is on an immutability promise, but samples can carry
	# live Object references — stringifying those from the worker thread
	# tripped the scene-tree thread guard and segfaulted (2026-09-26 crash).
	# The sanitizing copy is made on the MAIN thread, a type-level guarantee,
	# and is still the only copy; step() makes it a slice per frame.
	_sanitizing.append({
		"source": incident,
		"directory": directory,
		"keys": incident.keys(),
		"key_index": 0,
		"item_index": 0,
		"partial": [],
		"output": {},
	})


## Advances the main-thread copy by up to `budget_usec`; a finished copy goes
## to the worker. Called from poll_completed(), so the owner's per-frame poll
## drives it.
func step(budget_usec: int = STEP_BUDGET_USEC) -> void:
	var deadline := Time.get_ticks_usec() + budget_usec
	while not _sanitizing.is_empty():
		var job := _sanitizing[0]
		if not _sanitize_until(job, deadline):
			return
		_sanitizing.pop_front()
		_jobs.append({"incident": job["output"], "directory": job["directory"]})
		_start_next()
		if Time.get_ticks_usec() >= deadline:
			return


## Copies top-level entries, and array entries (samples, events) one element
## at a time, until done (true) or the deadline passes (false).
func _sanitize_until(job: Dictionary, deadline: int) -> bool:
	var source := job["source"] as Dictionary
	var keys := job["keys"] as Array
	var output := job["output"] as Dictionary
	while int(job["key_index"]) < keys.size():
		var key: Variant = keys[int(job["key_index"])]
		var value: Variant = source.get(key)
		if value is Array:
			var items := value as Array
			var partial := job["partial"] as Array
			var index := int(job["item_index"])
			while index < items.size():
				partial.append(PerformanceIncidentWriter._json_safe(items[index]))
				index += 1
				if Time.get_ticks_usec() >= deadline:
					job["item_index"] = index
					return false
			output[str(key)] = partial
			job["partial"] = []
			job["item_index"] = 0
		else:
			output[str(key)] = PerformanceIncidentWriter._json_safe(value)
		job["key_index"] = int(job["key_index"]) + 1
		if Time.get_ticks_usec() >= deadline:
			return false
	return true


func pending_count() -> int:
	return _sanitizing.size() + _jobs.size() + (1 if not _active_job.is_empty() else 0)


func poll_completed() -> Array[Dictionary]:
	step()
	var output := _take_completed()
	if _thread == null or not _thread.is_started() or _thread.is_alive():
		return output

	var writer_result: Variant = _thread.wait_to_finish()
	output.append(_completion(_active_job, writer_result))
	_thread = null
	_active_job = {}
	_start_next()
	output.append_array(_take_completed())
	return output


func shutdown() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	# Nothing may be lost on exit: finish every copy now, however long.
	while not _sanitizing.is_empty():
		step(1 << 40)
	while pending_count() > 0:
		if _thread != null and _thread.is_started():
			var writer_result: Variant = _thread.wait_to_finish()
			output.append(_completion(_active_job, writer_result))
			_thread = null
			_active_job = {}
		output.append_array(_take_completed())
		_start_next()
	output.append_array(_take_completed())
	return output


func _start_next() -> void:
	while _thread == null and not _jobs.is_empty():
		_active_job = _jobs.pop_front()
		_thread = Thread.new()
		var error := _thread.start(_run_job.bind(_active_job), Thread.PRIORITY_LOW)
		if error == OK:
			return
		_completed.append({
			"incident": _active_job.get("incident", {}),
			"result": {
				"ok": false,
				"json_path": "",
				"csv_path": "",
				"error": "Cannot start performance report writer: %s" % error_string(error),
			},
		})
		_thread = null
		_active_job = {}


func _run_job(job: Dictionary) -> Dictionary:
	var incident := job.get("incident", {}) as Dictionary
	var directory := String(job.get("directory", ""))
	if _writer.is_valid():
		var custom_result: Variant = _writer.call(incident, directory)
		return custom_result as Dictionary if custom_result is Dictionary else {}
	return PerformanceIncidentWriter.write_incident(incident, directory)


func _completion(job: Dictionary, writer_result: Variant) -> Dictionary:
	var result := writer_result as Dictionary if writer_result is Dictionary else {
		"ok": false,
		"json_path": "",
		"csv_path": "",
		"error": "Performance report writer returned an invalid result.",
	}
	return {
		"incident": job.get("incident", {}),
		"result": result,
	}


func _take_completed() -> Array[Dictionary]:
	var output := _completed.duplicate()
	_completed.clear()
	return output
