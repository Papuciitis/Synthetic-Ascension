extends SceneTree

var _passes := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var flow := FlowFieldNav.new()
	flow.radius_cells = 4
	root.add_child(flow)

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
	root.add_child(chunk_manager)
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


func _finish() -> void:
	print("FlowFieldUnitTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
