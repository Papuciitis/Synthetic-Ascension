extends SceneTree

var _passes := 0
var _failures := 0


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu_scene := load("res://ui/screens/MainMenu.tscn") as PackedScene
	_check(menu_scene != null, "main menu scene loads")
	if menu_scene != null:
		var menu := menu_scene.instantiate()
		root.add_child(menu)
		await process_frame
		_check(
			menu.get_node_or_null("Center/Panel/Padding/VBox/DevPanel/Pad/Margin/VBox/StartDevSegment") != null,
			"developer panel exposes an isolated Dev Segment launch button"
		)
		menu.queue_free()
		await process_frame

	var prototype_scene := load("res://scenes/world/dev_segment/DevSegment.tscn") as PackedScene
	_check(prototype_scene != null, "pre-authored Dev Segment scene loads")
	if prototype_scene != null:
		var prototype := prototype_scene.instantiate()
		root.add_child(prototype)
		await process_frame
		var outdoor_pieces := prototype.find_children("*", "Node2D", true, false).filter(
			func(node: Node) -> bool: return String(node.get_meta(&"piece_role", "")) == "empty_outdoor"
		)
		var corner_pieces := prototype.find_children("*", "Node2D", true, false).filter(
			func(node: Node) -> bool: return String(node.get_meta(&"piece_role", "")) == "room_corner"
		)
		_check(outdoor_pieces.size() > 0, "prototype contains reusable empty-outdoor pieces")
		_check(corner_pieces.size() == 4, "prototype contains four reusable authored room corners")
		_check(
			prototype.find_children("*", "StaticBody2D", true, false).size() == 8,
			"room-corner collisions are authored in the prefab scenes"
		)
		prototype.queue_free()
		await process_frame

	var global := root.get_node_or_null("Global")
	_check(global != null, "Global autoload is available")
	global.set("debug_dev_segment", true)
	global.set("attempt_active", true)
	global.set("attempt_segment", 2)
	var recorder := root.get_node_or_null("PerformanceFlightRecorder")
	recorder.call("clear_session")
	recorder.call("set_enabled", true)
	var game_scene := load("res://scenes/game.tscn") as PackedScene
	_check(game_scene != null, "game scene loads for Dev Segment routing")
	if game_scene != null:
		var game := game_scene.instantiate()
		root.add_child(game)
		await process_frame
		await process_frame
		_check(game.get_node_or_null("DevSegment") != null, "game routes the developer flag to the prefab segment")
		_check(game.get_node_or_null("ChunkManager") == null, "Dev Segment removes chunk streaming entirely")
		_check(game.get_node_or_null("FlowFieldNav") == null, "Dev Segment removes flow-field navigation entirely")
		_check(game.get_node_or_null("Spawner") == null, "Dev Segment removes enemy spawning")
		_check(game.get_node_or_null("Level1") == null, "Dev Segment removes the normal handcrafted builder")
		_check(recorder != null and bool(recorder.get("enabled")), "Dev Segment automatically enables performance incident recording")
		_check(
			int(recorder.call("debug_event_total", &"world", &"chunk_created")) == 0,
			"Dev Segment never starts even one streamed chunk"
		)
		game.queue_free()
		await process_frame
	global.set("debug_dev_segment", false)

	print("DevSegmentTest: %d passed, %d failed" % [_passes, _failures])
	quit(0 if _failures == 0 else 1)
