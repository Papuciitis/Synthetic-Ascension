extends SceneTree

# Guidance must survive its transient HUD timer, honour the configured
# interaction action, and point through the authored facility's doorways.
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
	var global := root.get_node("Global")
	global.set("debug_disable_autosave", true)
	root.get_node("SaveManager").set("save_dir", "user://tests/tutorial_guidance/")
	global.set("attempt_segment", 1)
	await _check_persistent_objective()
	await _check_alignment_input()
	await _check_segment_route(global)
	print("TutorialGuidanceTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func _check_persistent_objective() -> void:
	var host := Node.new()
	root.add_child(host)
	var panel := PanelContainer.new()
	var title := Label.new()
	var detail := Label.new()
	host.add_child(panel)
	host.add_child(title)
	host.add_child(detail)
	var controller := load("res://ui/controllers/HudObjectiveController.gd").new() as Node
	controller.set("_panel", panel)
	controller.set("_title", title)
	controller.set("_detail", detail)
	controller.set("expanded_duration", 0.1)
	host.add_child(controller)
	controller.call("_on_objective_changed", "REWRITE THE FIRST WARDSTONE", "Follow the marker into the archive. Stay inside the Wardstone.")
	await create_timer(0.15).timeout
	_check(panel.visible and detail.visible, "tutorial action and destination remain visible after the HUD timer")
	root.get_node("Global").set("attempt_segment", 2)
	controller.call("_on_objective_changed", "LATER DISTRICT", "A transient objective detail.")
	await create_timer(0.15).timeout
	_check(not detail.visible, "later district objective details still collapse")
	root.get_node("Global").set("attempt_segment", 1)
	host.queue_free()
	await process_frame


func _check_alignment_input() -> void:
	var world := load("res://core/systems/world/opening/OpeningSequenceWorld.gd").new() as Node2D
	var player := Node2D.new()
	root.add_child(world)
	root.add_child(player)
	world.call("configure", Vector2.ZERO, player, 3)
	player.position = Vector2(-82, 32)
	Input.action_press(&"interact")
	world.call("_process", 0.0)
	_check(int(world.get("_stage")) == 1, "the configured Interact action completes the current alignment")
	Input.action_release(&"interact")
	await process_frame
	player.position = Vector2(82, 32)
	Input.action_press(&"interact")
	world.call("_process", 0.0)
	_check(int(world.get("_stage")) == 1, "standing at a later node cannot bypass the active alignment")
	Input.action_release(&"interact")
	world.queue_free()
	player.queue_free()
	await process_frame


func _check_segment_route(global: Node) -> void:
	global.set("attempt_active", true)
	global.set("attempt_opening_completed", true)
	global.get("attempt_segment1_milestones").clear()
	global.set("objective_target_pos", Vector2.INF)
	global.set("tip_shown_intro_move", true)
	if global.get("run_inventory") == null:
		global.call("reset_run_inventory")
	if global.get("run_bag") == null:
		global.call("reset_run_bag_inventory")
	_check(change_scene_to_file("res://scenes/game.tscn") == OK, "segment 1 scene starts for guidance checks")
	for _frame in range(12):
		await process_frame
	var level := current_scene.get_node_or_null("Level1")
	_check(level != null, "authored tutorial exists")
	if level == null:
		return
	_check(global.get("objective_target_pos") != Vector2.INF, "the first tutorial task has a destination marker")
	global.call("record_segment1_milestone", &"synthesis")
	global.call("record_segment1_milestone", &"first_confrontation")
	global.call("record_segment1_milestone", &"assistant_commitment")
	level.call("_update_objective")
	_check(global.get("objective_target_pos") != Vector2.INF, "leaving the opening immediately guides toward the first Wardstone")
	_check(not bool(global.call("has_segment1_milestone", &"wardstone_1")), "publishing guidance never grants a destination milestone")
	var guidance := level.get_node_or_null("TutorialGuidance")
	_check(guidance != null, "tutorial has visible route guidance")
	if guidance == null:
		return
	var path: Array = guidance.get("_path")
	_check(not path.is_empty() and path[-1] == Vector2i(-11, 0), "archive route reaches the first Wardstone")
	_check(_path_avoids_blockers(path, level), "archive route uses open doors and never crosses authored cover")
	level.call("_on_wardstone_activated", null, 1)
	path = guidance.get("_path")
	_check(not path.is_empty() and Rect2i(Vector2i(32, -33), Vector2i(5, 27)).has_point(path[-1]), "attuning the first Wardstone reaches the checkpoint trigger even when cover occupies its centre")
	_check(path.any(func(cell: Vector2i) -> bool: return cell.x == 18 and cell.y >= -16 and cell.y <= -12), "the route uses the newly opened courtyard gate")
	_check(_path_avoids_blockers(path, level), "updated route respects remaining security seals")
	for milestone in [&"security_started", &"security_cleared", &"wardstone_2"]:
		global.call("record_segment1_milestone", milestone)
	level.call("_refresh_progression_seals")
	level.call("_update_objective")
	path = guidance.get("_path")
	_check(not path.is_empty() and path[-1] == Vector2i(49, -45), "the outer approach route includes the city reveal before the Rite")
	global.call("record_segment1_milestone", &"city_reveal")
	level.call("_update_objective")
	path = guidance.get("_path")
	_check(not path.is_empty() and path[-1] == Vector2i(20, -50), "after the reveal the route reaches the actual Rite")
	_check(_path_avoids_blockers(path, level), "the Rite route goes around the sealed warehouse")
	_check(not bool(global.call("has_segment1_milestone", &"final_plaza")), "route guidance preserves the plaza arrival gate")
	await _check_rebound_prompt(level)


func _path_avoids_blockers(path: Array, level: Node) -> bool:
	if path.is_empty():
		return false
	var walls: Dictionary = level.get("_wall_kind")
	var fences: Dictionary = level.get("_fence_cells")
	var cover: Dictionary = level.get("_half_cells")
	for cell: Vector2i in path:
		if walls.has(cell) or fences.has(cell) or cover.has(cell):
			return false
	return true


func _check_rebound_prompt(level: Node) -> void:
	var previous_events := InputMap.action_get_events(&"interact")
	InputMap.action_erase_events(&"interact")
	var rebound := InputEventKey.new()
	rebound.physical_keycode = KEY_J
	InputMap.action_add_event(&"interact", rebound)
	var controller := load("res://core/systems/world/opening/OpeningSequenceController.gd").new() as Node
	var presentation := load("res://ui/screens/opening/OpeningPresentation.tscn").instantiate() as CanvasLayer
	var world := load("res://core/systems/world/opening/OpeningSequenceWorld.gd").new() as Node2D
	root.add_child(controller)
	root.add_child(presentation)
	root.add_child(world)
	var player := get_first_node_in_group(&"player") as Node2D
	world.call("configure", Vector2(800, 1376), player, 3)
	controller.set("_level", level)
	controller.set("_world", world)
	controller.set("_presentation", presentation)
	level.set("_opening_sequence_active", true)
	controller.call("_show_alignment_guidance", 0, 3)
	var prompt := presentation.get("_prompt") as Label
	_check(prompt.visible and prompt.text.contains("J"), "alignment prompt displays the rebound Interact key")
	_check(prompt.text.contains("1/3"), "alignment prompt identifies the current node and total")
	level.set("_opening_sequence_active", false)
	level.call("_update_objective")
	InputMap.action_erase_events(&"interact")
	for event in previous_events:
		InputMap.action_add_event(&"interact", event)
	controller.queue_free()
	presentation.queue_free()
	world.queue_free()
	await process_frame
