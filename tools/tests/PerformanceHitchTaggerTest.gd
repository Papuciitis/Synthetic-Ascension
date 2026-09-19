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
	_check(lines.size() == 5 and lines[0].ends_with(",wall_ms,ascension_usec,fragment_usec,projectile_ms,chunk_build_ms,flow_publish_usec,hitch_tag,hitch_ms"), "the CSV carries the wall, tree, fragment, projectile, chunk, flow and hitch tag columns")
	if lines.size() == 5:
		var quiet_row := lines[1].split(",")
		var tree_row := lines[2].split(",")
		var chunk_row := lines[3].split(",")
		_check(quiet_row[quiet_row.size() - 2] == "" and tree_row[tree_row.size() - 2] == "ascension" and chunk_row[chunk_row.size() - 2] == "chunk_content", "rows carry their tags (none, ascension, chunk_content)")
		_check(tree_row[tree_row.size() - 8] == "40.0" and tree_row[tree_row.size() - 7] == "21000", "a row carries its wall time and the tree's microseconds")
	# Clean up the report files.
	var json_path := String(result.get("json_path", ""))
	for path in [csv_path, json_path]:
		if not path.is_empty():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not csv_path.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(csv_path.get_base_dir()))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
