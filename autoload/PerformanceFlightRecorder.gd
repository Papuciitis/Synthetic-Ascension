extends Node

signal incident_finalized(summary: Dictionary, report_path: String)

const STATE_DISABLED := "disabled"
const STATE_WATCHING := "watching"
const STATE_AFTERMATH := "aftermath"
const STATE_COOLDOWN := "cooldown"
const SCHEMA_VERSION := 1
const MAX_SAMPLE_RATE := 120
const MAX_EVENTS := 2048
const EVENT_BUCKET_USEC := 250_000
const PerformanceIncidentWriteQueueScript := preload("res://autoload/performance/PerformanceIncidentWriteQueue.gd")

var enabled := false
var automatic_capture := true
var write_reports := true
var history_seconds := 10.0
var aftermath_seconds := 5.0
var cooldown_seconds := 2.0
var absolute_threshold_ms := 28.0
var relative_multiplier := 1.8
var baseline_alpha := 0.025
var report_directory := "user://performance_captures"

var _state := STATE_DISABLED
var _history: Array[Dictionary] = []
var _capture_samples: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _counter_buckets: Dictionary = {}
var _baseline_ms := 0.0
var _trigger_usec := 0
var _aftermath_end_usec := 0
var _cooldown_end_usec := 0
var _sequence := 0
var _latest_incident: Dictionary = {}
var _latest_report_path := ""
var _latest_error := ""
var _trigger_reason: StringName = &""
var _session_started_usec := 0
var _slow_snapshot_left := 0.0
var _cached_slow_snapshot: Dictionary = {}
var _sampling_overhead_usec := 0
var _max_sampling_overhead_usec := 0
var _dropped_samples := 0
var _automatic_armed := true
var _recovery_frames := 0
var _report_write_queue: RefCounted = PerformanceIncidentWriteQueueScript.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	if RunEvents != null and RunEvents.has_signal("resonance_changed"):
		RunEvents.resonance_changed.connect(_on_resonance_changed)
	var threat_director := get_node_or_null("/root/ThreatDirector")
	if threat_director != null and threat_director.has_signal("threat_changed"):
		threat_director.connect("threat_changed", _on_threat_changed)


func _process(delta: float) -> void:
	_poll_completed_reports()
	if not enabled:
		return
	var started := Time.get_ticks_usec()
	_slow_snapshot_left -= delta
	if _slow_snapshot_left <= 0.0:
		_slow_snapshot_left = 0.5
		_cached_slow_snapshot = _collect_slow_snapshot()
	var sample := collect_runtime_sample()
	# frame_ms is the real spacing of this frame (delta); process_ms stays the
	# engine monitor, which reports the PREVIOUS frame's process step. The two
	# describe different frames by design — see collect_runtime_sample().
	sample["frame_ms"] = delta * 1000.0
	ingest_sample(sample)
	_sampling_overhead_usec = Time.get_ticks_usec() - started
	_max_sampling_overhead_usec = maxi(_max_sampling_overhead_usec, _sampling_overhead_usec)


func _exit_tree() -> void:
	for completion in _report_write_queue.shutdown():
		_accept_report_completion(completion)


func set_enabled(value: bool) -> void:
	if value == enabled:
		return
	enabled = value
	if enabled:
		_state = STATE_WATCHING
		_session_started_usec = Time.get_ticks_usec()
		_baseline_ms = 0.0
		_automatic_armed = true
		_recovery_frames = 0
	else:
		_state = STATE_DISABLED
		_capture_samples.clear()


func configure(settings: Dictionary) -> void:
	automatic_capture = bool(settings.get("automatic_capture", automatic_capture))
	write_reports = bool(settings.get("write_reports", write_reports))
	history_seconds = clampf(float(settings.get("history_seconds", history_seconds)), 1.0, 60.0)
	aftermath_seconds = clampf(float(settings.get("aftermath_seconds", aftermath_seconds)), 0.05, 30.0)
	cooldown_seconds = clampf(float(settings.get("cooldown_seconds", cooldown_seconds)), 0.0, 30.0)
	absolute_threshold_ms = clampf(float(settings.get("absolute_threshold_ms", absolute_threshold_ms)), 16.7, 250.0)
	relative_multiplier = clampf(float(settings.get("relative_multiplier", relative_multiplier)), 1.1, 5.0)


func ingest_sample(sample: Dictionary) -> void:
	if not enabled:
		return
	var normalized := sample.duplicate()
	var now_usec := int(normalized.get("t_usec", Time.get_ticks_usec()))
	normalized["t_usec"] = now_usec
	var frame_ms := float(normalized.get("frame_ms", 0.0))
	var baseline_before := _baseline_ms
	if _baseline_ms <= 0.0:
		_baseline_ms = frame_ms
	else:
		_baseline_ms = lerpf(_baseline_ms, frame_ms, baseline_alpha)
	normalized["baseline_ms"] = baseline_before
	if frame_ms < absolute_threshold_ms * 0.90:
		_recovery_frames += 1
		if _recovery_frames >= 30:
			_automatic_armed = true
	else:
		_recovery_frames = 0
	_history.append(normalized)
	_trim_history(now_usec)

	if _state == STATE_WATCHING and automatic_capture and _automatic_armed:
		var absolute_spike := frame_ms >= absolute_threshold_ms
		var relative_spike := baseline_before > 0.0 and frame_ms >= baseline_before * relative_multiplier
		if absolute_spike or relative_spike:
			_begin_incident(&"automatic", now_usec)
	elif _state == STATE_AFTERMATH:
		if _capture_samples.is_empty() or int((_capture_samples[-1] as Dictionary).get("t_usec", -1)) != now_usec:
			_capture_samples.append(normalized)
		if now_usec >= _aftermath_end_usec:
			_finalize_incident(now_usec)
	elif _state == STATE_COOLDOWN and now_usec >= _cooldown_end_usec:
		_state = STATE_WATCHING


func mark_incident(reason: StringName = &"manual") -> void:
	if not enabled or _state != STATE_WATCHING:
		return
	_begin_incident(reason, Time.get_ticks_usec())


func record_event(category: StringName, event_name: StringName, details: Dictionary = {}) -> void:
	if not enabled:
		return
	_events.append({
		"t_usec": Time.get_ticks_usec(),
		"category": String(category),
		"name": String(event_name),
		"details": details.duplicate(),
	})
	if _events.size() > MAX_EVENTS:
		_events.pop_front()


func record_counter_event(category: StringName, event_name: StringName, amount: int = 1, details: Dictionary = {}) -> void:
	if not enabled or amount == 0:
		return
	var now_usec := Time.get_ticks_usec()
	var bucket := floori(float(now_usec) / float(EVENT_BUCKET_USEC))
	var key := "%s|%s|%d|%s" % [category, event_name, bucket, JSON.stringify(details)]
	if _counter_buckets.has(key):
		_counter_buckets[key]["amount"] = int(_counter_buckets[key]["amount"]) + amount
	else:
		var event := {
			"t_usec": now_usec,
			"category": String(category),
			"name": String(event_name),
			"amount": amount,
			"details": details.duplicate(),
			# Lets _trim_history release the bucket in O(1) instead of
			# deep-comparing every bucket per expired event. Stripped from
			# finalized incident copies.
			"__bucket_key": key,
		}
		_counter_buckets[key] = event
		_events.append(event)
		if _events.size() > MAX_EVENTS:
			_events.pop_front()


func collect_runtime_sample() -> Dictionary:
	var now_usec := Time.get_ticks_usec()
	var sample := {
		"t_usec": now_usec,
		"elapsed_sec": float(now_usec - _session_started_usec) / 1_000_000.0,
		# Fallback for external callers; _process overwrites frame_ms with the
		# true delta of the current frame.
		"frame_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		# TIME_PROCESS is the previous frame's process step, not this frame's.
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"rendered_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"physics_objects": int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)),
		"sampling_overhead_usec": _sampling_overhead_usec,
	}
	sample.merge(_cached_slow_snapshot, true)
	return sample


func _collect_slow_snapshot() -> Dictionary:
	var output := {
		"enemies": 0,
		"ambient_enemies": 0,
		"special_enemies": 0,
		"enemy_tiers": {},
		"enemy_scheduler": {},
		"enemy_pool": {},
		"enemy_world_logical": 0,
		"enemy_world_materialized": 0,
		"enemy_world_data_only": 0,
		"enemy_world_dying": 0,
		"enemy_world_spatial_cells": 0,
		"enemy_world_max_cell_occupancy": 0,
		"projectiles": 0,
		"chunks": 0,
		"flow_building": false,
		"flow_revision": 0,
		"segment": Global.attempt_segment if Global != null else 0,
		"threat": 0.0,
		"resonance": 0.0,
	}
	var threat_director := get_node_or_null("/root/ThreatDirector")
	if threat_director != null:
		output["threat"] = float(threat_director.get("threat"))
		output["resonance"] = float(threat_director.get("resonance"))
	var index := get_node_or_null("/root/EnemyIndex")
	if index != null and index.has_method("get_debug_counters"):
		var counters := index.call("get_debug_counters") as Dictionary
		output["enemies"] = int(counters.get("indexed", 0))
		output["ambient_enemies"] = int(counters.get("ambient", 0))
		output["special_enemies"] = int(counters.get("special", 0))
		output["enemy_tiers"] = counters.get("tiers", {})
	var enemy_world := get_node_or_null("/root/EnemyWorld")
	if enemy_world != null and enemy_world.has_method("get_debug_counters"):
		var world_data := enemy_world.call("get_debug_counters") as Dictionary
		output["enemy_world_logical"] = int(world_data.get("logical", 0))
		output["enemy_world_materialized"] = int(world_data.get("materialized", 0))
		output["enemy_world_data_only"] = int(world_data.get("data_only", 0))
		output["enemy_world_dying"] = int(world_data.get("dying", 0))
		output["enemy_world_spatial_cells"] = int(world_data.get("spatial_cells", 0))
		output["enemy_world_max_cell_occupancy"] = int(world_data.get("max_cell_occupancy", 0))
	var scheduler := get_node_or_null("/root/EnemySimulationScheduler")
	if scheduler != null and scheduler.has_method("get_debug_counters"):
		output["enemy_scheduler"] = (scheduler.call("get_debug_counters") as Dictionary).duplicate(true)
	var pool := get_node_or_null("/root/PoolManager")
	if pool != null and pool.has_method("get_debug_counters"):
		output["enemy_pool"] = (pool.call("get_debug_counters") as Dictionary).duplicate(true)
	var manager := get_tree().get_first_node_in_group(&"projectile_simulation_manager")
	if manager != null:
		if manager.has_method("active_count"):
			output["projectiles"] = int(manager.call("active_count"))
		elif "active_count" in manager:
			output["projectiles"] = int(manager.get("active_count"))
	var chunks := get_tree().get_first_node_in_group(&"chunk_manager")
	if chunks != null and chunks.has_method("loaded_chunk_count"):
		output["chunks"] = int(chunks.call("loaded_chunk_count"))
	var flow := get_tree().get_first_node_in_group(&"flow_field_nav")
	if flow != null and flow.has_method("get_debug_counters"):
		var flow_data := flow.call("get_debug_counters") as Dictionary
		output["flow_building"] = bool(flow_data.get("building", false))
		output["flow_revision"] = int(flow_data.get("last_revision", 0))
	return output


func _begin_incident(reason: StringName, now_usec: int) -> void:
	_state = STATE_AFTERMATH
	_trigger_reason = reason
	if reason == &"automatic":
		_automatic_armed = false
		_recovery_frames = 0
	_trigger_usec = now_usec
	_aftermath_end_usec = now_usec + int(aftermath_seconds * 1_000_000.0)
	# Shallow copy on purpose: samples are never mutated after ingest, and a
	# deep copy of ~1200 ring entries used to land 10-33 ms of work on the very
	# frame that tripped the threshold.
	_capture_samples = _history.duplicate()


func _finalize_incident(now_usec: int) -> void:
	_sequence += 1
	var event_start := _trigger_usec - int(history_seconds * 1_000_000.0)
	var incident_events: Array = []
	for event_variant in _events:
		var event := event_variant as Dictionary
		var event_time := int(event.get("t_usec", 0))
		if event_time >= event_start and event_time <= now_usec:
			# Counter events keep aggregating in place, so incident copies must
			# own their data. The bucket key is internal bookkeeping.
			var event_copy := event.duplicate(true)
			event_copy.erase("__bucket_key")
			incident_events.append(event_copy)
	var summary := _build_summary(_capture_samples, incident_events)
	var segment := int((_capture_samples[-1] as Dictionary).get("segment", 0)) if not _capture_samples.is_empty() else 0
	_latest_incident = {
		"schema_version": SCHEMA_VERSION,
		"metadata": {
			"sequence": _sequence,
			"segment": segment,
			"trigger_reason": String(_trigger_reason),
			"trigger_usec": _trigger_usec,
			"history_seconds": history_seconds,
			"aftermath_seconds": aftermath_seconds,
			"absolute_threshold_ms": absolute_threshold_ms,
			"relative_multiplier": relative_multiplier,
			"max_sampling_overhead_usec": _max_sampling_overhead_usec,
			"dropped_samples": _dropped_samples,
		},
		"summary": summary,
		# Shallow: entries are immutable after ingest (see _begin_incident).
		"samples": _capture_samples.duplicate(),
		"events": incident_events,
	}
	_state = STATE_COOLDOWN if cooldown_seconds > 0.0 else STATE_WATCHING
	_cooldown_end_usec = now_usec + int(cooldown_seconds * 1_000_000.0)
	if write_reports:
		_report_write_queue.enqueue(_latest_incident, report_directory)
	else:
		incident_finalized.emit(summary, "")


func _build_summary(samples: Array[Dictionary], events: Array) -> Dictionary:
	var frame_times: Array[float] = []
	var worst := 0.0
	var below_60 := 0
	var below_45 := 0
	var below_30 := 0
	var process_peak := 0.0
	var physics_peak := 0.0
	for sample in samples:
		var frame_ms := float(sample.get("frame_ms", 0.0))
		frame_times.append(frame_ms)
		worst = maxf(worst, frame_ms)
		process_peak = maxf(process_peak, float(sample.get("process_ms", 0.0)))
		physics_peak = maxf(physics_peak, float(sample.get("physics_ms", 0.0)))
		if frame_ms > 1000.0 / 60.0: below_60 += 1
		if frame_ms > 1000.0 / 45.0: below_45 += 1
		if frame_ms > 1000.0 / 30.0: below_30 += 1
	frame_times.sort()
	return {
		"worst_frame_ms": worst,
		"median_frame_ms": _percentile(frame_times, 0.50),
		"p95_frame_ms": _percentile(frame_times, 0.95),
		"p99_frame_ms": _percentile(frame_times, 0.99),
		"frames_below_60": below_60,
		"frames_below_45": below_45,
		"frames_below_30": below_30,
		"peak_process_ms": process_peak,
		"peak_physics_ms": physics_peak,
		"dominant_thread": "physics" if physics_peak > process_peak else "process",
		"nearby_event_groups": _event_group_summary(events),
		"note": "Events overlap the incident timeline; correlation does not prove causation.",
	}


func _percentile(sorted_values: Array[float], fraction: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := clampi(int(ceil(fraction * sorted_values.size())) - 1, 0, sorted_values.size() - 1)
	return sorted_values[index]


func _event_group_summary(events: Array) -> Array:
	var groups := {}
	for event_variant in events:
		var event := event_variant as Dictionary
		var key := "%s/%s" % [event.get("category", ""), event.get("name", "")]
		groups[key] = int(groups.get(key, 0)) + int(event.get("amount", 1))
	var output: Array = []
	for key in groups:
		output.append({"event": key, "count": groups[key]})
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["count"]) > int(b["count"]))
	return output.slice(0, mini(12, output.size()))


func _poll_completed_reports() -> void:
	for completion in _report_write_queue.poll_completed():
		_accept_report_completion(completion)


func _accept_report_completion(completion: Dictionary) -> void:
	var incident := completion.get("incident", {}) as Dictionary
	var result := completion.get("result", {}) as Dictionary
	if bool(result.get("ok", false)):
		_latest_report_path = String(result.get("json_path", ""))
		_latest_error = ""
	else:
		_latest_error = String(result.get("error", "Unknown report write failure"))
	incident_finalized.emit(incident.get("summary", {}), _latest_report_path)


func _trim_history(now_usec: int) -> void:
	var cutoff := now_usec - int(history_seconds * 1_000_000.0)
	while not _history.is_empty() and (int((_history[0] as Dictionary).get("t_usec", 0)) < cutoff or _history.size() > debug_history_capacity()):
		_history.pop_front()
	while not _events.is_empty() and int((_events[0] as Dictionary).get("t_usec", 0)) < cutoff - 1_000_000:
		var removed := _events.pop_front() as Dictionary
		var bucket_key := String(removed.get("__bucket_key", ""))
		if bucket_key != "" and is_same(_counter_buckets.get(bucket_key), removed):
			_counter_buckets.erase(bucket_key)


func get_status_snapshot() -> Dictionary:
	return {
		"enabled": enabled,
		"automatic_capture": automatic_capture,
		"automatic_armed": _automatic_armed,
		"state": _state,
		"baseline_ms": _baseline_ms,
		"incident_count": _sequence,
		"latest_summary": _latest_incident.get("summary", {}),
		"latest_report_path": _latest_report_path,
		"latest_error": _latest_error,
		"history_samples": _history.size(),
		"event_count": _events.size(),
		"sampling_overhead_usec": _sampling_overhead_usec,
		"max_sampling_overhead_usec": _max_sampling_overhead_usec,
		"dropped_samples": _dropped_samples,
		"pending_reports": _report_write_queue.pending_count(),
	}


func get_latest_incident() -> Dictionary:
	return _latest_incident.duplicate(true)


func clear_session() -> void:
	_history.clear()
	_capture_samples.clear()
	_events.clear()
	_counter_buckets.clear()
	_latest_incident.clear()
	_latest_report_path = ""
	_latest_error = ""
	_sequence = 0
	_baseline_ms = 0.0
	_automatic_armed = true
	_recovery_frames = 0
	_state = STATE_WATCHING if enabled else STATE_DISABLED


func debug_history_size() -> int:
	return _history.size()


func debug_history_capacity() -> int:
	return ceili(history_seconds * MAX_SAMPLE_RATE) + 2


func debug_event_total(category: StringName, event_name: StringName) -> int:
	var total := 0
	for event_variant in _events:
		var event := event_variant as Dictionary
		if String(event.get("category", "")) == String(category) and String(event.get("name", "")) == String(event_name):
			total += int(event.get("amount", 1))
	return total


func _on_resonance_changed(value: float) -> void:
	record_event(&"progression", &"resonance_changed", {"value": value})


func _on_threat_changed(value: float) -> void:
	record_event(&"progression", &"threat_changed", {"value": value})
