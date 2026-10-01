extends RefCounted
class_name PerformanceIncidentWriteQueue

## Main-thread work allowed per step() while an incident is being copied.
## The worker may only ever see pure data (see enqueue), but copying a whole
## incident at once was the recorder's own hitch: ~900 samples x ~130 values
## is 260-340 ms of GDScript on one frame (the 2026-09-27 "sampling" stalls,
## PerformanceIncidentFinalizeBenchmark). The copy now advances one sample at
## a time under this budget; a report reaches the worker a few seconds later.
## The default for a queue built without one; the flight recorder passes its
## own, smaller budget (its samples copy cheaply, see _copy_item).
const STEP_BUDGET_USEC := 1500

const PerformanceIncidentSummaryScript := preload("res://autoload/performance/PerformanceIncidentSummary.gd")

var _writer: Callable
## This queue's per-step copy budget (step()'s default).
var _step_budget_usec := STEP_BUDGET_USEC
## Incidents still being copied on the main thread, oldest first:
## {source, directory, keys, key_index, item_index, partial, output,
##  previous_source, previous_copy}.
var _sanitizing: Array[Dictionary] = []
var _jobs: Array[Dictionary] = []
var _completed: Array[Dictionary] = []
var _thread: Thread = null
var _active_job: Dictionary = {}


func _init(writer: Callable = Callable(), step_budget_usec: int = STEP_BUDGET_USEC) -> void:
	_writer = writer
	_step_budget_usec = step_budget_usec


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
		"previous_source": {},
		"previous_copy": {},
	})


## Advances the main-thread copy by up to `budget_usec`; a finished copy goes
## to the worker. Called from poll_completed(), so the owner's per-frame poll
## drives it.
func step(budget_usec: int = -1) -> void:
	var deadline := Time.get_ticks_usec() + (budget_usec if budget_usec >= 0 else _step_budget_usec)
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
				partial.append(_copy_item(job, items[index]))
				index += 1
				if Time.get_ticks_usec() >= deadline:
					job["item_index"] = index
					return false
			output[str(key)] = partial
			job["partial"] = []
			job["item_index"] = 0
			job["previous_source"] = {}
			job["previous_copy"] = {}
		else:
			output[str(key)] = PerformanceIncidentWriter._json_safe(value)
		job["key_index"] = int(job["key_index"]) + 1
		if Time.get_ticks_usec() >= deadline:
			return false
	return true


## The sanitized copy of one array entry. Two things make a recorder sample
## cheap to copy. Most of its values are plain (numbers, text), which a
## native shallow copy carries as they are; and the recorder merges one 0.5 s
## slow snapshot into every sample of that half second by reference, so
## consecutive samples hold the very same nested dictionaries and arrays: a
## nested value that IS the previous entry's reuses that entry's copy instead
## of being walked again. (Walking every value of every sample was the
## 2026-10-01 captures' 1.5-2 ms of recorder work on 23% of all frames.) The
## copies are shared only inside this incident's output, which the worker
## alone reads; every value is still checked here, on the main thread.
func _copy_item(job: Dictionary, item: Variant) -> Variant:
	if not (item is Dictionary):
		return PerformanceIncidentWriter._json_safe(item)
	var source := item as Dictionary
	var previous_source := job["previous_source"] as Dictionary
	var previous_copy := job["previous_copy"] as Dictionary
	var output := source.duplicate()
	var keys := source.keys()
	var values := source.values()
	for index in range(values.size()):
		var value: Variant = values[index]
		var type := typeof(value)
		var key: Variant = keys[index]
		if typeof(key) != TYPE_STRING:
			# Not shaped like a sample: the general copy turns keys into text.
			job["previous_source"] = {}
			job["previous_copy"] = {}
			return PerformanceIncidentWriter._json_safe(item)
		if type <= TYPE_STRING:
			# nil, bool, int, float, String: already JSON-safe.
			continue
		if (type == TYPE_DICTIONARY or type == TYPE_ARRAY) and previous_source.has(key) and is_same(previous_source[key], value):
			output[key] = previous_copy[key]
		else:
			output[key] = PerformanceIncidentWriter._json_safe(value)
	job["previous_source"] = source
	job["previous_copy"] = output
	return output


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
	# The recorder closes an incident with an empty summary and leaves the
	# building to this thread; the copy is this job's own, so it is filled
	# in place and keeps its position in the report.
	var summary: Variant = incident.get("summary")
	if summary is Dictionary and (summary as Dictionary).is_empty() and incident.get("samples") is Array:
		incident["summary"] = PerformanceIncidentSummaryScript.build(incident["samples"], incident.get("events", []) as Array)
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
