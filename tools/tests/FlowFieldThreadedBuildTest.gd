extends Node

# The flow-field BFS must run on a worker thread against a walkability
# snapshot: time-slicing it on the main thread cost ~1.5 ms per frame and
# stretched every rebuild across seconds of wall clock, so the published field
# was stale almost always.

class StubChunkManager:
	extends ChunkManager
	# A vertical wall at cell x == 3 (all y), everything else walkable.
	func _ready() -> void:
		ground_enabled = false
		generation_enabled = false
		super._ready()

	func is_cell_walkable(cell: Vector2i) -> bool:
		return cell.x != 3

	func build_nav_walkability_snapshot() -> Dictionary:
		var blocked: Dictionary = {}
		for y in range(-64, 65):
			blocked[Vector2i(3, y)] = true
		var chunks: Dictionary = {}
		for cy in range(-3, 4):
			for cx in range(-3, 4):
				chunks[Vector2i(cx, cy)] = true
		return {
			"chunks": chunks,
			"blocked": blocked,
			"manual": {},
			"cells_per_chunk": 32,
		}

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _make_flow(threaded: bool) -> FlowFieldNav:
	var flow := FlowFieldNav.new()
	flow.radius_cells = 8
	flow.rebuild_interval = 0.01
	flow.set("threaded_build", threaded)
	add_child(flow)
	return flow


func _wait_for_completion(flow: FlowFieldNav) -> bool:
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline:
		var counters := flow.get_debug_counters() as Dictionary
		if int(counters.get("completed", 0)) > 0 and not bool(counters.get("building", false)):
			return true
		await get_tree().process_frame
	return false


func _run() -> void:
	var stub := StubChunkManager.new()
	add_child(stub)
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	player.global_position = Vector2.ZERO

	var flow := _make_flow(true)
	_check("threaded_build" in flow, "flow field exposes the threaded build mode")
	if not ("threaded_build" in flow):
		print("FlowFieldThreadedBuildTest: %d passed, %d failed" % [_passes, _failures])
		get_tree().quit(1)
		return

	var threaded_done: bool = await _wait_for_completion(flow)
	_check(threaded_done, "threaded build completes")
	var origin_cost := flow.sample_cost(Vector2.ZERO)
	_check(origin_cost == 0, "threaded field anchors at the player cell")
	_check(flow.sample_cost(Vector2(128.0, 0.0)) > 0, "threaded field carries distances outward")
	_check(flow.sample_cost(Vector2(3.5 * 64.0, 0.0)) >= 1_000_000_000, "walls stay unstamped in the threaded field")
	_check(flow.sample_dir(Vector2(128.0, 0.0)) != Vector2.ZERO, "threaded field yields flow directions")
	var threaded_counters := flow.get_debug_counters() as Dictionary
	_check(threaded_counters.has("last_snapshot_usec"), "threaded build reports main-thread snapshot duration")
	_check(threaded_counters.has("last_worker_usec"), "threaded build reports worker duration")
	_check(threaded_counters.has("last_publish_usec"), "threaded build reports main-thread publish duration")
	_check(int(threaded_counters.get("last_snapshot_usec", -1)) >= 0, "snapshot duration is non-negative")
	_check(int(threaded_counters.get("last_worker_usec", 0)) > 0, "worker duration records completed BFS work")
	_check(int(threaded_counters.get("last_publish_usec", -1)) >= 0, "publish duration is non-negative")

	# The sliced fallback must still work and agree with the threaded result.
	var sliced := _make_flow(false)
	var sliced_done: bool = await _wait_for_completion(sliced)
	_check(sliced_done, "sliced fallback build still completes")
	if threaded_done and sliced_done:
		var agree := true
		for probe in [Vector2(64, 0), Vector2(128, 64), Vector2(-128, -64), Vector2(320, 0), Vector2(0, 256)]:
			if flow.sample_cost(probe) != sliced.sample_cost(probe):
				agree = false
				break
		_check(agree, "threaded and sliced builds produce identical cost fields")

	# Leaving the tree must FORGET the build, not merely join its worker. A
	# nav node that re-enters used to keep _building set, so its next
	# _process fell into _step_build() and published a cancelled build from
	# the previous life's snapshot. Godot hygiene audit 2026-08-28 top-10 #7.
	# The flag is set directly: a real build of this size finishes inside a
	# frame, so waiting for one in flight would make the assertion vacuous
	# (it passed with and without the fix that way). What matters is the
	# invariant - whatever state a build left behind, leaving the tree
	# forgets it.
	var reentered := _make_flow(true)
	await get_tree().process_frame
	reentered.set("_building", true)
	reentered.set("_use_snapshot", true)
	reentered.set("_cancel_requested", true)
	_check(bool((reentered.get_debug_counters() as Dictionary).get("building", false)), "fixture: a build is marked in progress")
	remove_child(reentered)
	var after_exit := reentered.get_debug_counters() as Dictionary
	_check(
		not bool(after_exit.get("building", false)),
		"leaving the tree clears the in-progress build flag (%s)" % after_exit.get("building")
	)
	_check(
		not bool(reentered.get("_use_snapshot")) and not bool(reentered.get("_cancel_requested")),
		"and the snapshot and cancel flags with it"
	)
	add_child(reentered)
	await get_tree().process_frame
	_check(
		is_instance_valid(reentered),
		"and the node survives being re-entered"
	)
	reentered.queue_free()

	flow.queue_free()
	sliced.queue_free()
	stub.queue_free()
	player.queue_free()
	print("FlowFieldThreadedBuildTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
