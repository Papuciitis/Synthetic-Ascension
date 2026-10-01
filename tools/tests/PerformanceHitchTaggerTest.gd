extends Node

# Performance war room M3: hitch tagging from the fields a recorder sample
# already carries, through the summary and the incident CSV.
#
# Run: <godot> --headless --path . --quit-after 3000 res://tools/tests/PerformanceHitchTaggerTest.tscn

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


func _base(t_usec: int, wall_ms: float) -> Dictionary:
	return {
		"t_usec": t_usec,
		"elapsed_sec": float(t_usec) / 1_000_000.0,
		"frame_ms": 16.0,
		"wall_ms": wall_ms,
		"process_ms": wall_ms * 0.7,
		"physics_ms": 3.0,
		"enemies": 120,
		"projectiles": 200,
		"projectile_ms": 0.4,
		"ascension": {"tick_usec": 300, "flush_usec": 100, "hit_usec": 200, "BR": {"fragment_usec": 100}},
		"chunk_stream": {"queue_length": 0, "last_phases": {"coord": "(1, 1)", "total_ms": 3.0, "content_ms": 2.0, "blocker_physics_ms": 0.5, "blocker_render_ms": 0.3}},
		"flow_revision": 4,
		"flow_building": false,
		"flow_snapshot_usec": 0,
		"flow_publish_usec": 0,
		"enemy_lifecycle": {"attach_total_usec": 1000, "detach_total_usec": 500, "retire_total_usec": 200},
		"enemy_scheduler": {"physics_step_ms": 0.8},
		"sampling_overhead_usec": 120,
	}


func _run() -> void:
	_test_tags()
	_test_chunk_stages()
	_test_scene_change()
	_test_frame_phases()
	_test_summary_and_csv()
	print("PerformanceHitchTaggerTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_tags() -> void:
	var quiet := _base(1_000_000, 12.0)
	_check(String(PerformanceHitchTagger.tag(quiet, {})["tag"]).is_empty(), "a 12 ms sample is not a hitch")

	var tree := _base(2_000_000, 40.0)
	tree["ascension"] = {"tick_usec": 18_000, "flush_usec": 2_000, "hit_usec": 1_000, "BR": {"fragment_usec": 500}}
	var tree_tag := PerformanceHitchTagger.tag(tree, quiet)
	_check(String(tree_tag["tag"]) == "ascension" and absf(float(tree_tag["ms"]) - 20.5) < 0.001, "a 21 ms tree tick tags the hitch 'ascension' with the fragments taken out")

	var fragments := _base(3_000_000, 40.0)
	fragments["ascension"] = {"tick_usec": 20_000, "flush_usec": 200, "hit_usec": 100, "BR": {"fragment_usec": 17_000}}
	_check(String(PerformanceHitchTagger.tag(fragments, quiet)["tag"]) == "fragments", "fragment updates inside the tick tag 'fragments' when they are the larger part")

	var projectiles := _base(4_000_000, 35.0)
	projectiles["projectile_ms"] = 14.0
	_check(String(PerformanceHitchTagger.tag(projectiles, quiet)["tag"]) == "projectiles", "a 14 ms projectile step tags 'projectiles'")

	var chunk := _base(5_000_000, 45.0)
	chunk["chunk_stream"] = {"queue_length": 3, "last_phases": {"coord": "(2, 1)", "total_ms": 24.0, "setup_ms": 0.1, "ground_ms": 0.2, "content_ms": 21.0, "floor_ms": 0.2, "blocker_physics_ms": 1.5, "blocker_render_ms": 1.0}}
	var chunk_tag := PerformanceHitchTagger.tag(chunk, quiet)
	_check(String(chunk_tag["tag"]) == "chunk_content" and is_equal_approx(float(chunk_tag["ms"]), 24.0), "a new activation whose content phase dominates tags 'chunk_content' with the activation's total")
	var same_chunk := chunk.duplicate(true)
	same_chunk["t_usec"] = 5_016_000
	_check(String(PerformanceHitchTagger.tag(same_chunk, chunk)["tag"]) != "chunk_content", "the same activation is not charged to the next frame")

	var flow := _base(6_000_000, 36.0)
	flow["flow_revision"] = 5
	flow["flow_publish_usec"] = 9_000
	flow["flow_snapshot_usec"] = 3_000
	var flow_tag := PerformanceHitchTagger.tag(flow, quiet)
	_check(String(flow_tag["tag"]) == "flow" and is_equal_approx(float(flow_tag["ms"]), 12.0), "a flow revision change charges snapshot plus publish to 'flow'")
	var snapshot := _base(6_500_000, 36.0)
	snapshot["flow_building"] = true
	snapshot["flow_snapshot_usec"] = 11_000
	_check(String(PerformanceHitchTagger.tag(snapshot, quiet)["tag"]) == "flow", "a build starting this frame charges its snapshot to 'flow'")

	var lifecycle := _base(7_000_000, 33.0)
	lifecycle["enemy_lifecycle"] = {"attach_total_usec": 9_000, "detach_total_usec": 3_000, "retire_total_usec": 200}
	_check(String(PerformanceHitchTagger.tag(lifecycle, quiet)["tag"]) == "lifecycle", "attach and detach deltas of 10.5 ms tag 'lifecycle'")

	var step := _base(8_000_000, 33.0)
	step["enemy_scheduler"] = {"physics_step_ms": 9.5}
	_check(String(PerformanceHitchTagger.tag(step, quiet)["tag"]) == "enemy_step", "the enemy scheduler's step tags 'enemy_step'")

	# This frame's own physics (recorder rev 2026-09-30) wins over the slow
	# snapshot's copy, which can be up to 0.5 s old.
	var fresh := step.duplicate(true)
	fresh["physics_step_ms"] = 0.6
	fresh["physics_ticks"] = 1
	fresh["physics_frame_ms"] = 0.6
	_check(String(PerformanceHitchTagger.tag(fresh, quiet)["tag"]) != "enemy_step", "a stale slow-snapshot step no longer tags a frame whose own physics was light")
	fresh["physics_frame_ms"] = 12.0
	fresh["physics_step_ms"] = 12.0
	_check(String(PerformanceHitchTagger.tag(fresh, quiet)["tag"]) == "enemy_step", "one heavy physics tick in the frame tags 'enemy_step'")
	# Catch-up: after a long frame Godot runs several ticks; one tick alone
	# (8 ms) sits under the attribution floor of a 60 ms frame and read as
	# "unattributed", the ticks' sum is the frame's real physics cost.
	var catchup := step.duplicate(true)
	catchup["wall_ms"] = 60.0
	catchup["frame_ms"] = 60.0
	catchup["physics_step_ms"] = 8.0
	catchup["physics_ticks"] = 3
	catchup["physics_frame_ms"] = 24.0
	var caught := PerformanceHitchTagger.tag(catchup, quiet)
	_check(String(caught["tag"]) == "physics_catchup" and is_equal_approx(float(caught["ms"]), 24.0), "several physics ticks in one frame tag 'physics_catchup' with their sum (%s)" % str(caught))
	var legacy := catchup.duplicate(true)
	for key in ["physics_step_ms", "physics_ticks", "physics_frame_ms"]:
		legacy.erase(key)
	legacy["enemy_scheduler"] = {"physics_step_ms": 8.0}
	_check(String(PerformanceHitchTagger.tag(legacy, quiet)["tag"]) == "unattributed", "older captures without the per-frame fields keep their original tags")

	var nothing := _base(9_000_000, 40.0)
	_check(String(PerformanceHitchTagger.tag(nothing, quiet)["tag"]) == "unattributed", "a 40 ms frame with only sub-millisecond measured costs is 'unattributed'")
	var physics := _base(10_000_000, 40.0)
	physics["physics_ms"] = 24.0
	_check(String(PerformanceHitchTagger.tag(physics, quiet)["tag"]) == "physics_monitor", "with nothing measured, a physics monitor over half the frame tags 'physics_monitor'")

	var small := _base(11_000_000, 30.0)
	small["projectile_ms"] = 1.5
	_check(String(PerformanceHitchTagger.tag(small, quiet)["tag"]) == "unattributed", "a 1.5 ms cost cannot claim a 30 ms frame")


func _test_chunk_stages() -> void:
	var content := _base(1_000_000, 30.0)
	content["chunk_stream"] = {"last_phases": {"coord": "(4, 2)", "total_ms": 7.0, "content_ms": 6.5, "blocker_ms": 0.0, "blocker_physics_ms": 0.0, "blocker_render_ms": 0.0, "staged_pending": true}}
	var physics := content.duplicate(true)
	physics["t_usec"] = 1_016_000
	physics["chunk_stream"] = {"last_phases": {"coord": "(4, 2)", "total_ms": 7.0, "content_ms": 6.5, "blocker_ms": 0.0, "blocker_physics_ms": 6.0, "blocker_render_ms": 0.0, "staged_pending": true}}
	var render := physics.duplicate(true)
	render["t_usec"] = 1_032_000
	render["chunk_stream"] = {"last_phases": {"coord": "(4, 2)", "total_ms": 16.0, "content_ms": 6.5, "blocker_ms": 9.0, "blocker_physics_ms": 6.0, "blocker_render_ms": 3.0, "staged_pending": false}}
	_check(String(PerformanceHitchTagger.tag(content, {})["tag"]) == "chunk_content", "the content step of a staged activation tags 'chunk_content'")
	# The physics stage records its ms into the sample before the total grows,
	# so the total only moves when the render stage completes; that frame is
	# charged to the render stage with the whole blocker delta.
	var render_tag := PerformanceHitchTagger.tag(render, physics)
	_check(String(render_tag["tag"]) == "chunk_blocker_render" and is_equal_approx(float(render_tag["ms"]), 9.0), "the completing blocker stage is charged the blocker delta (9 ms) as 'chunk_blocker_render'")
	_check(String(PerformanceHitchTagger.tag(physics, content)["tag"]) == "unattributed", "a frame where the sample did not grow is not charged to the chunk")


## A scene change blocks one or two frames for 0.5-2 s (the 2026-10-01
## "1.10 s gap" was a run -> hub change with 2.7 ms attributed). The samples
## that span it carry the destination, and the whole frame is the change.
func _test_scene_change() -> void:
	var change := _base(9_000_000, 1100.0)
	change["scene_change"] = "HubWorld"
	change["physics_ticks"] = 4
	change["physics_frame_ms"] = 2.7
	var tagged := PerformanceHitchTagger.tag(change, _base(8_900_000, 16.7))
	_check(String(tagged["tag"]) == "scene_change" and is_equal_approx(float(tagged["ms"]), 1100.0), "a frame that spans a scene change is tagged 'scene_change' with the whole frame as its cost")
	var quiet := _base(9_100_000, 17.0)
	quiet["scene_change"] = "HubWorld"
	_check(String(PerformanceHitchTagger.tag(quiet, change)["tag"]) == "", "a scene-change sample under the hitch threshold is not a hitch")
	var ordinary := _base(9_200_000, 1100.0)
	ordinary["physics_ticks"] = 4
	ordinary["physics_frame_ms"] = 2.7
	_check(String(PerformanceHitchTagger.tag(ordinary, quiet)["tag"]) == "unattributed", "the same frame without the mark stays unattributed")
	# The recorder marks the samples around the change and logs the event.
	var script := load("res://autoload/PerformanceFlightRecorder.gd") as Script
	var recorder: Node = script.new()
	add_child(recorder)
	recorder.set("write_reports", false)
	recorder.set("automatic_capture", false)
	recorder.call("set_enabled", true)
	recorder.call("note_scene_change", "HubWorld")
	var marked := 0
	for i in range(5):
		recorder.call("_process", 0.016)
		var history: Array = recorder.get("_history")
		if String((history[-1] as Dictionary).get("scene_change", "")) == "HubWorld":
			marked += 1
	_check(marked == 3, "the recorder marks the three samples that follow a scene change (%d marked)" % marked)
	var events: Array = recorder.get("_events")
	_check(events.size() == 1 and String(events[0].get("category", "")) == "scene" and String(events[0].get("name", "")) == "change" and String((events[0].get("details", {}) as Dictionary).get("to", "")) == "HubWorld", "the change is logged as a scene/change event naming the destination")
	recorder.queue_free()


## The recorder splits the frame behind a sample from four clock stamps:
## script _process, the deferred end of the frame, and draw + present.
func _test_frame_phases() -> void:
	var script := load("res://autoload/PerformanceFlightRecorder.gd") as Script
	var recorder: Node = script.new()
	add_child(recorder)
	_check(recorder.get_node_or_null("FrameTail") != null and int(recorder.get_node("FrameTail").process_priority) > 1_000_000_000, "the recorder carries a tail node that runs after every other _process")
	_check((recorder.call("_frame_phases", 1_000) as Dictionary).is_empty(), "the first sample has no previous frame to split")
	recorder.set("_phase_process_end_usec", 4_000)
	recorder.set("_phase_pre_draw_usec", 5_000)
	recorder.set("_phase_post_draw_usec", 14_000)
	var phases: Dictionary = recorder.call("_frame_phases", 16_000)
	_check(is_equal_approx(float(phases.get("process", -1.0)), 3.0) and is_equal_approx(float(phases.get("deferred", -1.0)), 1.0) and is_equal_approx(float(phases.get("render_present", -1.0)), 9.0), "a frame splits into process 3 ms, deferred 1 ms, draw + present 9 ms (%s)" % str(phases))
	# Headless never draws: the draw stamps stay behind the frame.
	recorder.set("_phase_process_end_usec", 18_000)
	phases = recorder.call("_frame_phases", 30_000)
	_check(is_equal_approx(float(phases.get("process", -1.0)), 2.0) and not phases.has("deferred") and not phases.has("render_present"), "without a draw this frame only the process phase is reported")
	# A stamp from before the previous sample is not this frame's.
	_check((recorder.call("_frame_phases", 40_000) as Dictionary).is_empty(), "stale stamps report nothing rather than a wrong split")
	recorder.queue_free()


func _test_summary_and_csv() -> void:
	var samples: Array[Dictionary] = []
	var quiet := _base(1_000_000, 12.0)
	samples.append(quiet)
	var tree := _base(2_000_000, 40.0)
	tree["ascension"] = {"tick_usec": 18_000, "flush_usec": 2_000, "hit_usec": 1_000, "BR": {"fragment_usec": 500}}
	samples.append(tree)
	var chunk := _base(3_000_000, 45.0)
	chunk["chunk_stream"] = {"queue_length": 3, "last_phases": {"coord": "(2, 1)", "total_ms": 24.0, "content_ms": 21.0, "blocker_physics_ms": 1.5, "blocker_render_ms": 1.0}}
	samples.append(chunk)
	var tree2 := _base(4_000_000, 33.0)
	tree2["ascension"] = {"tick_usec": 12_000, "flush_usec": 1_000, "hit_usec": 500, "BR": {"fragment_usec": 100}}
	tree2["physics_ticks"] = 2
	tree2["physics_frame_ms"] = 9.5
	tree2["sampling_overhead_usec"] = 150
	tree2["frame_phases"] = {"process": 9.0, "deferred": 1.5, "render_present": 12.0}
	samples.append(tree2)
	var summary: Dictionary = PerformanceFlightRecorder.call("_build_summary", samples, [])
	_check(int(summary.get("hitch_count", -1)) == 3, "the summary counts the three samples over 28 ms")
	var tags: Array = summary.get("hitch_tags", [])
	_check(tags.size() == 2 and String(tags[0].get("tag", "")) == "ascension" and int(tags[0].get("count", 0)) == 2 and String(tags[1].get("tag", "")) == "chunk_content", "the tag distribution is ascension x2, chunk_content x1, most frequent first")
	var worst: Array = summary.get("worst_hitches", [])
	_check(worst.size() == 3 and String(worst[0].get("tag", "")) == "chunk_content" and is_equal_approx(float(worst[0].get("frame_ms", 0.0)), 45.0), "the worst hitch list leads with the 45 ms chunk frame")

	var directory := "user://hitch_tag_test"
	var result := PerformanceIncidentWriter.write_incident({
		"metadata": {"sequence": 1, "segment": 2},
		"summary": summary,
		"samples": samples,
		"events": [],
	}, directory)
	_check(bool(result.get("ok", false)), "the incident writer writes the report")
	var csv_path := String(result.get("csv_path", ""))
	var text := FileAccess.get_file_as_string(csv_path) if not csv_path.is_empty() else ""
	var lines := text.split("\n", false)
	_check(lines.size() == 5 and lines[0].contains(",wall_ms,ascension_usec,fragment_usec,projectile_ms,chunk_build_ms,flow_publish_usec,hitch_tag,hitch_ms"), "the CSV carries the wall, tree, fragment, projectile, chunk, flow and hitch tag columns")
	_check(lines.size() == 5 and lines[0].ends_with(",hitch_ms,physics_ticks,physics_frame_ms,sampling_usec,process_phase_ms,deferred_ms,render_present_ms"), "the CSV ends with the physics tick, sampling and frame phase columns")
	if lines.size() == 5:
		# Columns are read by header name: appended columns must not move them.
		var header := lines[0].split(",")
		var quiet_row := lines[1].split(",")
		var tree_row := lines[2].split(",")
		var chunk_row := lines[3].split(",")
		var tree2_row := lines[4].split(",")
		var tag_at := header.find("hitch_tag")
		_check(quiet_row[tag_at] == "" and tree_row[tag_at] == "ascension" and chunk_row[tag_at] == "chunk_content", "rows carry their tags (none, ascension, chunk_content)")
		_check(tree_row[header.find("wall_ms")] == "40.0" and tree_row[header.find("ascension_usec")] == "21000", "a row carries its wall time and the tree's microseconds")
		_check(tree2_row[header.find("physics_ticks")] == "2" and tree2_row[header.find("physics_frame_ms")] == "9.5" and tree2_row[header.find("sampling_usec")] == "150", "a row carries its physics tick count, summed physics time and sampling cost")
		_check(tree2_row[header.find("process_phase_ms")] == "9.0" and tree2_row[header.find("deferred_ms")] == "1.5" and tree2_row[header.find("render_present_ms")] == "12.0", "a row carries its frame phases")
		_check(tree_row[header.find("physics_ticks")] == "" and tree_row[header.find("render_present_ms")] == "", "a sample without the fields writes empty cells, not zeros")
	# Clean up the report files.
	var json_path := String(result.get("json_path", ""))
	for path in [csv_path, json_path]:
		if not path.is_empty():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not csv_path.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(csv_path.get_base_dir()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
