extends RefCounted
class_name PerformanceIncidentWriteQueue

var _writer: Callable
var _jobs: Array[Dictionary] = []
var _completed: Array[Dictionary] = []
var _thread: Thread = null
var _active_job: Dictionary = {}


func _init(writer: Callable = Callable()) -> void:
	_writer = writer


func enqueue(incident: Dictionary, directory: String) -> void:
	# The caller guarantees a finalized incident is immutable, so it is handed
	# to the worker as-is; a deep copy here used to be the third full copy of
	# the incident made on the main thread before the write even started.
	_jobs.append({
		"incident": incident,
		"directory": directory,
	})
	_start_next()


func pending_count() -> int:
	return _jobs.size() + (1 if not _active_job.is_empty() else 0)


func poll_completed() -> Array[Dictionary]:
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
