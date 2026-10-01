extends Node

## The flight recorder's own cost when an incident closes, with samples shaped
## like a real segment-2 capture (tools/tests/fixtures/flight_recorder_sample.json:
## 129 values each, as the 2026-09-27 captures carry). 10 s of history and 5 s
## of aftermath at 60 Hz with ~200 events, three incidents in a row; report
## writing goes to a writer that touches no disk.
##
## Prints the slowest frame of recorder work (ingest + report servicing on the
## same frame), its two parts' worst cases, and the direct cost of one
## sanitizing copy of an incident. Exits 1 when a frame's recorder work
## exceeds FRAME_BUDGET_MS or a report goes missing.
##
## Run: <godot> --headless --path . res://tools/tests/PerformanceIncidentFinalizeBenchmark.tscn

const FIXTURE := "res://tools/tests/fixtures/flight_recorder_sample.json"
const HZ := 60
const HISTORY_SECONDS := 10.0
const AFTERMATH_SECONDS := 5.0
const EVENTS_PER_INCIDENT := 200
const INCIDENTS := 3
## Recorder work allowed on any one frame (the hitch threshold is 28 ms).
## Before the budgeted copy the finalizing frame took 300-500 ms here.
const FRAME_BUDGET_MS := 20.0

var _written := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var template: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var script := load("res://autoload/PerformanceFlightRecorder.gd") as Script
	var recorder: Node = script.new()
	recorder.set_process(false)
	add_child(recorder)
	recorder.configure({
		"automatic_capture": true,
		"write_reports": true,
		"history_seconds": HISTORY_SECONDS,
		"aftermath_seconds": AFTERMATH_SECONDS,
		"cooldown_seconds": 0.0,
	})
	recorder.set("_report_write_queue", PerformanceIncidentWriteQueue.new(_no_disk_writer))
	recorder.set_enabled(true)

	var step_usec := int(1_000_000.0 / HZ)
	var t := 1_000_000
	var worst_ingest := 0
	var worst_step := 0
	var worst_frame := 0
	var frames := 0
	var frame_total := 0
	var history_frames := int(HISTORY_SECONDS * HZ)
	# Aftermath, then enough calm frames to re-arm the automatic trigger.
	var aftermath_frames := int(AFTERMATH_SECONDS * HZ) + 40
	for incident in range(INCIDENTS):
		for i in range(history_frames + aftermath_frames):
			if i % maxi(1, (history_frames + aftermath_frames) / EVENTS_PER_INCIDENT) == 0:
				recorder.record_event(&"benchmark", &"tick", {"i": i, "at": Vector2(i, i)})
			var sample := template.duplicate(true)
			sample["t_usec"] = t
			# One slow frame trips the automatic trigger on the sample's own
			# clock, so the aftermath runs its full length like in play.
			var slow := i == history_frames
			sample["frame_ms"] = 40.0 if slow else 16.667
			sample["wall_ms"] = 40.0 if slow else 16.667
			var started := Time.get_ticks_usec()
			recorder.ingest_sample(sample)
			var ingest := Time.get_ticks_usec() - started
			started = Time.get_ticks_usec()
			# What _process does each frame besides sampling.
			recorder.call("_poll_completed_reports")
			if recorder.has_method("_drain_retiring"):
				recorder.call("_drain_retiring")
			var step := Time.get_ticks_usec() - started
			worst_ingest = maxi(worst_ingest, ingest)
			worst_step = maxi(worst_step, step)
			worst_frame = maxi(worst_frame, ingest + step)
			frame_total += ingest + step
			frames += 1
			t += step_usec
	recorder.call("flush_reports")

	var incident: Dictionary = recorder.get_latest_incident()
	var copy_started := Time.get_ticks_usec()
	var _copy: Variant = PerformanceIncidentWriter._json_safe(incident)
	var copy_ms := float(Time.get_ticks_usec() - copy_started) / 1000.0
	var typed_samples: Array[Dictionary] = []
	for row in incident.get("samples", []):
		typed_samples.append(row)
	var summary_started := Time.get_ticks_usec()
	recorder.call("_build_summary", typed_samples, incident.get("events", []))
	var summary_ms := float(Time.get_ticks_usec() - summary_started) / 1000.0
	var dup_started := Time.get_ticks_usec()
	var _shallow := typed_samples.duplicate()
	var dup_ms := float(Time.get_ticks_usec() - dup_started) / 1000.0
	print("  breakdown: build_summary_ms=%.1f shallow_samples_copy_ms=%.2f events=%d" % [summary_ms, dup_ms, (incident.get("events", []) as Array).size()])
	var worst_frame_ms := float(worst_frame) / 1000.0
	print("PerformanceIncidentFinalizeBenchmark: incidents=%d written=%d samples/incident=%d worst_frame_ms=%.2f worst_ingest_ms=%.2f worst_queue_step_ms=%.2f mean_frame_ms=%.3f one_sanitizing_copy_ms=%.1f" % [
		INCIDENTS, _written, (incident.get("samples", []) as Array).size(), worst_frame_ms,
		float(worst_ingest) / 1000.0, float(worst_step) / 1000.0,
		float(frame_total) / 1000.0 / maxf(1.0, float(frames)), copy_ms,
	])
	var ok := _written == INCIDENTS and worst_frame_ms <= FRAME_BUDGET_MS
	if not ok:
		push_error("FAIL: recorder frame work %.2f ms (budget %.1f ms), %d/%d reports written" % [worst_frame_ms, FRAME_BUDGET_MS, _written, INCIDENTS])
	recorder.queue_free()
	get_tree().quit(0 if ok else 1)


func _no_disk_writer(_incident: Dictionary, _directory: String) -> Dictionary:
	_written += 1
	return {"ok": true, "json_path": "memory://benchmark.json", "csv_path": "", "error": ""}
