extends Node

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
	_test_literal_obstacle_directions()
	var flow := FlowFieldNav.new()
	flow.radius_cells = 4
	add_child(flow)

	_check(flow.has_method("get_debug_counters"), "flow field exposes rebuild diagnostics")
	if not flow.has_method("get_debug_counters"):
		_finish()
		return

	flow.call("_request_rebuild_if_needed", Vector2i.ZERO, 0)
	var first := flow.call("get_debug_counters") as Dictionary
	var requested_after_initial := int(first.get("requested", 0))
	flow.call("_request_rebuild_if_needed", Vector2i.ZERO, 0)
	var stationary := flow.call("get_debug_counters") as Dictionary
	_check(int(stationary.get("requested", 0)) == requested_after_initial, "stationary unchanged world does not request rebuild")

	flow.call("_request_rebuild_if_needed", Vector2i.ONE, 0)
	var below_threshold := flow.call("get_debug_counters") as Dictionary
	_check(int(below_threshold.get("requested", 0)) == requested_after_initial, "movement below threshold does not request rebuild")

	flow.call("_request_rebuild_if_needed", Vector2i(2, 0), 0)
	var moved := flow.call("get_debug_counters") as Dictionary
	_check(int(moved.get("requested", 0)) == requested_after_initial + 1, "two-cell movement requests rebuild")
	_check(StringName(moved.get("last_request_reason", &"")) == &"player_moved", "movement rebuild records its reason")

	flow.call("_request_rebuild_if_needed", Vector2i(2, 0), 1)
	var revised := flow.call("get_debug_counters") as Dictionary
	_check(StringName(revised.get("last_request_reason", &"")) == &"nav_revision", "walkability revision records its reason")

	flow.queue_free()

	var chunk_manager := ChunkManager.new()
	add_child(chunk_manager)
	_check(chunk_manager.has_method("request_nav_revision"), "chunk manager exposes batched revision requests")
	_check(chunk_manager.has_method("commit_pending_nav_revision"), "chunk manager exposes deterministic revision commit")
	if chunk_manager.has_method("request_nav_revision") and chunk_manager.has_method("commit_pending_nav_revision"):
		var before := int(chunk_manager.call("get_nav_revision"))
		chunk_manager.call("request_nav_revision", &"chunk_generated")
		chunk_manager.call("request_nav_revision", &"chunk_generated")
		chunk_manager.call("request_nav_revision", &"manual_block")
		_check(int(chunk_manager.call("get_nav_revision")) == before, "same-frame requests remain pending")
		chunk_manager.call("commit_pending_nav_revision")
		_check(int(chunk_manager.call("get_nav_revision")) == before + 1, "same-frame requests commit one revision")
		var nav_debug := chunk_manager.call("get_nav_debug_counters") as Dictionary
		_check(StringName(nav_debug.get("last_reason", &"")) == &"manual_block", "batched revision exposes its latest cause")
	chunk_manager.queue_free()
	_finish()


func _test_literal_obstacle_directions() -> void:
	var manager := ChunkManager.new()
	manager.generation_enabled = false
	manager.ground_enabled = false
	manager.debug_draw_chunk_outlines = false
	add_child(manager)
	var loaded_chunk := Node2D.new()
	manager.add_child(loaded_chunk)
	manager.set("_chunks", {Vector2i.ZERO: loaded_chunk})
	manager.set("_manual_blocked_cells", {Vector2i(5, 4): true})
	var flow := FlowFieldNav.new()
	flow.radius_cells = 4
	flow.max_expansions_per_frame = 1000
	flow.max_ms_per_frame = 0.0
	# This test drives the deterministic sliced core directly; the threaded
	# path is covered by FlowFieldThreadedBuildTest.
	flow.set("threaded_build", false)
	add_child(flow)
	flow.set("_cm", manager)
	flow.call("_ensure_buffers")
	flow.call("_start_rebuild", Vector2i(4, 4), 0)
	flow.call("_step_build")
	_check(flow.call("_dir_at_cell", Vector2i(3, 4)) == Vector2.RIGHT, "open cell points directly toward the origin")
	_check(flow.call("_dir_at_cell", Vector2i(5, 5)) == Vector2.LEFT, "blocked cardinal prevents diagonal corner cutting")

	var doorway_blocks: Dictionary = {}
	for y in range(0, 9):
		if y != 4:
			doorway_blocks[Vector2i(6, y)] = true
	manager.set("_manual_blocked_cells", doorway_blocks)
	flow.call("_start_rebuild", Vector2i(4, 4), 1)
	flow.call("_step_build")
	var doorway_direction := flow.call("_dir_at_cell", Vector2i(8, 3)) as Vector2
	_check(doorway_direction.is_equal_approx(Vector2(-1, 1).normalized()), "doorway approach retains its hand-derived diagonal")
	flow.call("_start_rebuild", Vector2i(4, 4), 2)
	flow.call("_step_build")
	_check((flow.call("_dir_at_cell", Vector2i(8, 3)) as Vector2).is_equal_approx(doorway_direction), "repeated rebuild preserves literal directions")
	_check(flow.has_method("get_hot_loop_buffer_stats"), "flow field exposes reusable hot-loop buffer diagnostics")
	if flow.has_method("get_hot_loop_buffer_stats"):
		var stats := flow.call("get_hot_loop_buffer_stats") as Dictionary
		_check(stats.get("step_storage") == &"packed" and int(stats.get("candidate_capacity", 0)) == 8, "neighbor storage remains fixed after rebuilds")
	flow.queue_free()
	manager.queue_free()


func _finish() -> void:
	print("FlowFieldUnitTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
