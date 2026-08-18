extends Node

# Camera-aware streaming used to rebuild the full desired-chunk plan every
# process frame. A stationary player must not trigger endless replans.

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


func _run() -> void:
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	player.global_position = Vector2.ZERO

	var manager := ChunkManager.new()
	manager.ground_enabled = false
	manager.generation_enabled = false
	manager.use_camera_stream_bounds = true
	add_child(manager)
	manager.start_streaming(Vector2.ZERO)

	_check("_stream_plans_total" in manager, "chunk manager counts streaming replans")
	if not ("_stream_plans_total" in manager):
		_finish(manager, player)
		return

	var plans_before := int(manager.get("_stream_plans_total"))
	manager.call("_process", 0.016)
	manager.call("_process", 0.016)
	manager.call("_process", 0.016)
	_check(
		int(manager.get("_stream_plans_total")) == plans_before,
		"a stationary player does not replan streaming every frame"
	)

	player.global_position = Vector2(4096.0, 0.0)
	manager.call("_process", 0.016)
	_check(
		int(manager.get("_stream_plans_total")) > plans_before,
		"crossing into a new area replans streaming"
	)

	_finish(manager, player)


func _finish(manager: Node, player: Node) -> void:
	manager.queue_free()
	player.queue_free()
	print("ChunkStreamReplanThrottleTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
