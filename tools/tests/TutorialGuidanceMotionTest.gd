extends SceneTree

# The visible marker is also the HUD arrow's target. Exercise that public
# position with deterministic movement through a straight corridor and a turn.
var _passes := 0
var _failures := 0
var _global: Node


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
	_global = root.get_node("Global")
	_global.set("debug_disable_autosave", true)
	root.get_node("SaveManager").set("save_dir", "user://tests/tutorial_guidance_motion/")
	_check_cell_refresh()
	_check_continuous_lookahead()
	_check_refresh_during_motion()
	_check_corner_handoff()
	_check_checkpoint_change()
	_check_frame_rates()
	await _check_stationary_caption_refresh()
	print("TutorialGuidanceMotionTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func _fixture(regions: Array[Rect2i], destination: Vector2) -> Dictionary:
	var player := Node2D.new()
	player.position = Vector2(32, 32)
	root.add_child(player)
	var guidance := load("res://core/systems/world/TutorialGuidance.gd").new() as Node2D
	root.add_child(guidance)
	guidance.set("_player", player)
	var blockers: Array[Dictionary] = []
	guidance.call("configure", 64, regions, blockers)
	guidance.call("set_destination", destination, "DESTINATION")
	guidance.set_process(false)
	return {"player": player, "guidance": guidance}


func _marker() -> Vector2:
	return _global.get("objective_target_pos") as Vector2


func _dispose(fixture: Dictionary) -> void:
	fixture.guidance.free()
	fixture.player.free()


func _check_cell_refresh() -> void:
	var fixture := _fixture([Rect2i(0, 0, 12, 1)], Vector2(736, 32))
	var before := _marker()
	fixture.player.position = Vector2(96, 32)
	fixture.guidance.call("_refresh_path")
	_check(_marker().is_equal_approx(before), "crossing a cell keeps the visible marker continuous at route refresh")
	fixture.guidance.call("_process", 1.0 / 60.0)
	var step := _marker() - before
	_check(step.x > 0.0 and step.length() <= 16.0 and is_zero_approx(step.y), "the first frame advances smoothly along the corridor")
	_dispose(fixture)


func _check_continuous_lookahead() -> void:
	var fixture := _fixture([Rect2i(0, 0, 12, 1)], Vector2(736, 32))
	var previous := _marker()
	var advancing_frames := 0
	var bounded := true
	for frame in range(24):
		fixture.player.position.x = 32.0 + (frame + 1) * 4.0
		fixture.guidance.call("_process", 1.0 / 60.0)
		var current := _marker()
		if current.x > previous.x:
			advancing_frames += 1
		bounded = bounded and current.distance_to(previous) <= 16.0 and is_equal_approx(current.y, 32.0)
		previous = current
	_check(advancing_frames >= 22, "straight-corridor guidance moves between grid refreshes instead of pausing then jumping")
	_check(bounded, "steady player movement never produces a large marker step")
	_dispose(fixture)


func _check_corner_handoff() -> void:
	var regions: Array[Rect2i] = [Rect2i(0, 0, 5, 1), Rect2i(4, 0, 1, 6)]
	var fixture := _fixture(regions, Vector2(224, 32))
	var before := _marker()
	fixture.guidance.call("set_destination", Vector2(288, 352), "NEXT CHECKPOINT")
	fixture.player.position = Vector2(288, 96)
	fixture.guidance.call("_refresh_path")
	_check(_marker().is_equal_approx(before), "a waypoint handoff preserves the current marker position")
	var stays_on_floor := true
	var visits_corner := false
	var bounded := true
	var previous := _marker()
	for _frame in range(100):
		fixture.guidance.call("_process", 1.0 / 60.0)
		var current := _marker()
		var cell := Vector2i((current / 64.0).floor())
		stays_on_floor = stays_on_floor and regions.any(func(region: Rect2i) -> bool: return region.has_point(cell))
		# The horizontal leg must finish before the marker turns south.
		stays_on_floor = stays_on_floor and (current.x >= 287.99 or is_equal_approx(current.y, 32.0))
		visits_corner = visits_corner or (current.x >= 287.99 and current.y > 32.0)
		bounded = bounded and current.distance_to(previous) <= 16.0
		previous = current
	_check(stays_on_floor and visits_corner, "corner transitions follow both walkable legs without cutting across the wall")
	_check(bounded, "corner transitions retain the per-frame motion bound")
	_check(_marker().distance_to(Vector2(288, 352)) < 1.0, "the marker reaches the new checkpoint promptly without overshooting")
	_dispose(fixture)


func _check_refresh_during_motion() -> void:
	var fixture := _fixture([Rect2i(0, 0, 12, 1)], Vector2(736, 32))
	fixture.player.position = Vector2(96, 32)
	fixture.guidance.call("_refresh_path")
	fixture.guidance.call("_process", 0.05)
	var before := _marker()
	fixture.player.position = Vector2(160, 32)
	fixture.guidance.call("_refresh_path")
	_check(_marker().is_equal_approx(before), "a refresh during motion preserves the fractional marker position")
	fixture.guidance.call("_process", 1.0 / 60.0)
	_check(_marker().x > before.x, "an in-flight route refresh keeps moving forward instead of returning to the cell centre")
	_dispose(fixture)


func _check_checkpoint_change() -> void:
	var fixture := _fixture([Rect2i(0, 0, 12, 1)], Vector2(736, 32))
	var before := _marker()
	fixture.guidance.call("set_destination", Vector2(160, 32), "NEW CHECKPOINT")
	_check(_marker().is_equal_approx(before), "changing checkpoint starts from the visible position")
	fixture.guidance.call("_process", 1.0 / 60.0)
	_check(_marker().x < before.x and _marker().x > 160.0, "a changed checkpoint affects motion on the next frame")
	for _frame in range(70):
		fixture.guidance.call("_process", 1.0 / 60.0)
	_check(_marker().distance_to(Vector2(160, 32)) < 1.0, "checkpoint motion settles at the destination")
	fixture.guidance.call("set_destination", Vector2.INF, "")
	_check(_marker() == Vector2.INF, "clearing guidance immediately removes its marker and arrow")
	_dispose(fixture)


func _position_after_refresh(frame_count: int) -> Vector2:
	var fixture := _fixture([Rect2i(0, 0, 12, 1)], Vector2(736, 32))
	fixture.player.position = Vector2(96, 32)
	fixture.guidance.call("_refresh_path")
	for _frame in range(frame_count):
		fixture.guidance.call("_process", 0.2 / frame_count)
	var result := _marker()
	_dispose(fixture)
	return result


func _check_frame_rates() -> void:
	var at_30_fps := _position_after_refresh(6)
	var at_120_fps := _position_after_refresh(24)
	_check(at_30_fps.distance_to(at_120_fps) < 1.0, "marker motion over the same time remains consistent at 30 and 120 fps")


func _check_stationary_caption_refresh() -> void:
	var fixture := _fixture([Rect2i(0, 0, 4, 1)], Vector2(224, 32))
	var draws := {"count": 0}
	fixture.guidance.draw.connect(func() -> void: draws.count += 1)
	await process_frame
	await process_frame
	var before: int = draws.count
	fixture.guidance.call("set_destination", Vector2(224, 32), "HOLD THE CHECKPOINT")
	await process_frame
	await process_frame
	_check(draws.count > before, "a stationary marker redraws when the checkpoint action changes")
	_dispose(fixture)
