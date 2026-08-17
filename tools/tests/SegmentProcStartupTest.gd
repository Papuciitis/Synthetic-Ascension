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
	PerformanceFlightRecorder.clear_session()
	PerformanceFlightRecorder.set_enabled(true)
	var player := Node2D.new()
	player.add_to_group(&"startup_test_player")
	add_child(player)
	var manager := ChunkManager.new()
	manager.player_group = &"startup_test_player"
	manager.generation_enabled = false
	manager.ground_enabled = false
	manager.debug_draw_chunk_outlines = false
	add_child(manager)
	await get_tree().process_frame
	_check(manager.has_method("configure_procedural_world"), "chunk manager exposes an atomic procedural configuration boundary")
	_check(manager.has_method("start_streaming"), "chunk manager exposes explicit streaming startup")
	_check(manager.get("streaming_started") != true, "chunk manager stays dormant after ready")
	_check(PerformanceFlightRecorder.debug_event_total(&"world", &"chunk_created") == 0, "no chunk is created before plan data is installed")

	var center := Vector2i(2, -1)
	var center_position := Vector2(2.5 * manager.chunk_size_px, -0.5 * manager.chunk_size_px)
	var connectors := {center: WorldBlockerGeometry.N | WorldBlockerGeometry.E}
	var access := {center: WorldBlockerGeometry.S}
	var roles := {center: &"checkpoint"}
	var terrain := {center: &"urban"}
	var archetypes := {center: &"gate"}
	if manager.has_method("configure_procedural_world"):
		manager.call("configure_procedural_world", 99173, connectors, access, roles, terrain, archetypes)
	if manager.has_method("start_streaming"):
		manager.call("start_streaming", center_position)
	_check(manager.get("streaming_started") == true, "explicit start transitions the manager once")
	_check(manager.world_seed == 99173 and manager.get_chunk_role(center) == &"checkpoint", "seed and semantic plan are installed before activation")
	_check(manager.get_chunk_connectors(center) == connectors[center], "connector plan is installed before activation")
	_check(PerformanceFlightRecorder.debug_event_total(&"world", &"chunk_created") == 1, "startup creates the center chunk exactly once before queued neighbors")
	manager.call("start_streaming", center_position)
	_check(PerformanceFlightRecorder.debug_event_total(&"world", &"chunk_created") == 1, "repeated startup requests are idempotent")
	manager.queue_free()
	player.queue_free()
	await get_tree().process_frame

	PerformanceFlightRecorder.clear_session()
	var segment_one := ChunkManager.new()
	segment_one.generation_enabled = false
	segment_one.ground_enabled = false
	add_child(segment_one)
	await get_tree().process_frame
	_check(segment_one.get("streaming_started") != true, "handcrafted Segment 1 never starts procedural streaming")
	_check(PerformanceFlightRecorder.debug_event_total(&"world", &"chunk_created") == 0, "handcrafted startup creates no procedural chunks")
	segment_one.queue_free()

	print("SegmentProcStartupTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
