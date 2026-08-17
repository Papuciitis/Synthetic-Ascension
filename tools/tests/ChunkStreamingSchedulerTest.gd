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
	_test_visible_rect_planning()
	_test_center_first_ordering()
	_test_elapsed_time_budget()
	print("ChunkStreamingSchedulerTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_visible_rect_planning() -> void:
	var inside := ChunkStreamPlanner.desired_coords(
		Vector2i.ZERO, Rect2(Vector2(64, 484), Vector2(1920, 1080)), 2048, 1
	)
	var expected_inside: Array[Vector2i] = []
	for y in range(-1, 2):
		for x in range(-1, 2):
			expected_inside.append(Vector2i(x, y))
	_check(inside == expected_inside, "viewport inside one chunk plus prefetch produces a 3x3 desired set")

	var crossing := ChunkStreamPlanner.desired_coords(
		Vector2i.ZERO, Rect2(Vector2(1800, 1800), Vector2(500, 500)), 2048, 1
	)
	var expected_crossing: Array[Vector2i] = []
	for y in range(-1, 3):
		for x in range(-1, 3):
			expected_crossing.append(Vector2i(x, y))
	_check(crossing == expected_crossing, "viewport crossing both axes expands to the exact prefetched rectangle")


func _test_center_first_ordering() -> void:
	var desired: Array[Vector2i] = []
	for y in range(-1, 2):
		for x in range(-1, 2):
			desired.append(Vector2i(x, y))
	var ordered := ChunkStreamPlanner.ordered_missing(desired, {Vector2i(-1, -1): true}, Vector2i.ZERO)
	_check(ordered[0] == Vector2i.ZERO, "missing chunks are center-first")
	_check(ordered.slice(1, 4) == [Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0)], "equal-distance jobs use deterministic y/x ties")


func _test_elapsed_time_budget() -> void:
	var tiny := _new_scheduler_manager()
	tiny.max_chunk_generations_per_frame = 9
	tiny.stream_activation_budget_ms = 0.001
	tiny.call("queue_missing_chunks", Vector2i.ZERO)
	var tiny_count := int(tiny.call("process_chunk_generation_queue"))
	_check(tiny_count >= 1 and tiny_count < 9, "tiny elapsed-time budget still activates one job but not the full queue")
	tiny.queue_free()

	var capped := _new_scheduler_manager()
	capped.max_chunk_generations_per_frame = 2
	capped.stream_activation_budget_ms = 1000.0
	capped.call("queue_missing_chunks", Vector2i.ZERO)
	_check(int(capped.call("process_chunk_generation_queue")) == 2, "count ceiling remains a hard safety bound")
	capped.queue_free()


func _new_scheduler_manager() -> ChunkManager:
	var manager := ChunkManager.new()
	manager.use_camera_stream_bounds = false
	manager.load_radius = 1
	manager.ground_enabled = false
	manager.generation_enabled = false
	manager.debug_draw_chunk_outlines = false
	add_child(manager)
	manager.set("_current_center", Vector2i.ZERO)
	return manager
