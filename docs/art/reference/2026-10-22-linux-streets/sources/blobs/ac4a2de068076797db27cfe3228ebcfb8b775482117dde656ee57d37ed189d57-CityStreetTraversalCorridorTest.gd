extends "res://tools/dev/CityStreetTraversalProbe.gd"
## A blocked passage must fail instead of finding a path or sidestep around
## its flanking buildings. Arrival at both ends alone is insufficient proof.

var _sidestep_target := Vector2.INF


func _run() -> void:
	_player = CharacterBody2D.new()
	_player.add_to_group(&"player")
	add_child(_player)
	_chunks = ChunkManager.new()
	_chunks.generation_enabled = false
	_chunks.ground_enabled = false
	_chunks.ground_splat_enabled = false
	_chunks.decals_enabled = false
	_chunks.deco_enabled = false
	_chunks.world_atmosphere_enabled = false
	_chunks.use_camera_stream_bounds = false
	_chunks.load_radius = 0
	_chunks.unload_radius = 1
	add_child(_chunks)
	_chunks.start_streaming(Vector2.ZERO)
	var failures: Array[String] = []
	var corridor := Rect2i(10, 9, 3, 9)
	var blocked := {Vector2i(10, 13): true, Vector2i(11, 13): true, Vector2i(12, 13): true}
	var start := Vector2i(11, 9)
	var goal := Vector2i(11, 17)
	if _live_path(start, goal, blocked).is_empty():
		failures.append("control layout has no outside detour")
	_passage_corridor = corridor
	if not _live_path(start, goal, blocked).is_empty():
		failures.append("blocked passage escaped its corridor through the outside detour")
	# No allowed neighbour is available; the tempting diagonal/left cells
	# outside the mouth must not become a production sidestep destination.
	_player.global_position = _chunks.cell_to_world_center(Vector2i(10, 10))
	var neighbours := {Vector2i(10, 9): true, Vector2i(11, 9): true, Vector2i(11, 10): true, Vector2i(10, 11): true, Vector2i(11, 11): true}
	await _live_sidestep(_chunks.cell_to_world_center(goal), neighbours)
	if _sidestep_target != Vector2.INF:
		failures.append("blocked passage sidestepped outside its allowed cells")
	if not has_method("_passage_trace_result"):
		failures.append("passage proof has no actual-cell trace validation")
	else:
		var passage := Rect2i(10, 10, 3, 7)
		var trace: Array[Vector2i] = []
		for y in range(9, 18):
			trace.append(Vector2i(11, y))
		if not bool(call("_passage_trace_result", passage, trace).get("valid", false)):
			failures.append("ordered in-corridor trace was rejected")
		var missing_near: Array[Vector2i] = [Vector2i(11, 13), Vector2i(11, 14), Vector2i(11, 15), Vector2i(11, 16), Vector2i(11, 17)]
		if bool(call("_passage_trace_result", passage, missing_near).get("valid", false)):
			failures.append("trace proof accepted a route without its near mouth")
		var outside: Array[Vector2i] = [Vector2i(11, 9), Vector2i(11, 10), Vector2i(11, 11), Vector2i(10, 11), Vector2i(9, 11), Vector2i(9, 12), Vector2i(10, 12), Vector2i(11, 12), Vector2i(11, 13), Vector2i(11, 14), Vector2i(11, 15), Vector2i(11, 16), Vector2i(11, 17)]
		if bool(call("_passage_trace_result", passage, outside).get("valid", false)):
			failures.append("trace proof accepted an actual outside detour")
		var skipped: Array[Vector2i] = [Vector2i(11, 9), Vector2i(11, 13), Vector2i(11, 17)]
		if bool(call("_passage_trace_result", passage, skipped).get("valid", false)):
			failures.append("trace proof accepted unsampled passage jumps")
	for failure: String in failures:
		push_error(failure)
	print("CityStreetTraversalCorridorTest: failures=%d" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)


## Observe the real sidestep selector's chosen destination without claiming
## that this headless fixture performs the later player-input movement.
func _live_step(target: Vector2) -> bool:
	_sidestep_target = target
	return true
