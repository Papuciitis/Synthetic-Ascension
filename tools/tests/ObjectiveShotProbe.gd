extends Node

## Renders every primary objective type in a real procedural district.
##
## Objective visuals are pure _draw() with no scene file and no art, so the only
## way to know a new template reads at all - let alone reads differently from
## the others - is to put it in a district and look at it. Shots land in
## OBJ_SHOT_DIR (env) or user://objective_shots.

var _dir: String = ""
var _is_worker: bool = false


func _ready() -> void:
	if _is_worker:
		get_tree().create_timer(150.0).timeout.connect(func() -> void:
			push_error("ObjectiveShotProbe timed out")
			get_tree().quit(1)
		)
		_run.call_deferred()
		return
	_dir = OS.get_environment("OBJ_SHOT_DIR")
	if _dir.is_empty():
		_dir = ProjectSettings.globalize_path("user://objective_shots")
	DirAccess.make_dir_recursive_absolute(_dir)
	# Must outlive goto_game()'s scene change.
	var worker := Node.new()
	worker.name = "ObjectiveShotWorker"
	worker.process_mode = Node.PROCESS_MODE_ALWAYS
	worker.set_script(get_script())
	worker.set("_dir", _dir)
	worker.set("_is_worker", true)
	get_tree().root.add_child.call_deferred(worker)


## An augment card or a tutorial modal pauses the tree, which stops objectives
## processing and parks the camera - so every shot would be of the modal.
func _dismiss_blocking_ui() -> void:
	var scene := get_tree().current_scene
	var ui := scene.get_node_or_null("UI") if scene != null else null
	if ui != null:
		for child in ui.get_children():
			if child.has_method("open_choose_3"):
				child.queue_free()
	# Enemy dossiers and info cards are separate nodes with their own dismiss
	# button; walking the tree for it is cheaper than knowing all their names.
	_press_continue(get_tree().root)
	get_tree().paused = false


func _disable_tutorial_modals(node: Node) -> void:
	var script: Variant = node.get_script()
	if script != null and String(script.resource_path).ends_with("TutorialModalController.gd"):
		node.queue_free()
		return
	for child in node.get_children():
		_disable_tutorial_modals(child)


func _press_continue(node: Node) -> void:
	var button := node as Button
	if button != null and button.visible and button.text.strip_edges().to_lower() == "continue":
		button.emit_signal("pressed")
		return
	for child in node.get_children():
		_press_continue(child)


func _run() -> void:
	Global.start_new_attempt()
	Global.attempt_segment = 6
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.debug_dev_mode = true
	Global.debug_player_god_mode = true
	Global.goto_game()
	var player: Node2D = null
	for _wait in range(400):
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group(&"player") as Node2D
		if player != null:
			break
	if player == null:
		push_error("FAIL: no player")
		get_tree().quit(1)
		return

	# First-encounter dossiers pause the tree, and the breach objective spawns
	# constantly - so without this every shot is of a card.
	_disable_tutorial_modals(get_tree().root)
	_dismiss_blocking_ui()
	# The district only builds one objective, so swap the node between shots
	# rather than rerolling the whole segment three times.
	var host := get_tree().get_first_node_in_group(&"primary_objective") as Node2D
	var anchor: Vector2 = host.global_position if host != null else player.global_position
	var parent: Node = host.get_parent() if host != null else get_tree().current_scene
	if host != null:
		host.queue_free()
		await get_tree().process_frame

	for id in PrimaryObjectiveCatalog.all_ids():
		var objective := PrimaryObjectiveCatalog.script_for(id).new() as PrimaryObjective
		objective.configure(4242)
		objective.global_position = anchor
		parent.add_child(objective)
		# Stand just off centre so activation fires and the site reads in frame.
		player.global_position = anchor + Vector2(0, 140)
		for _f in range(120):
			await get_tree().process_frame
			if get_tree().paused:
				_dismiss_blocking_ui()
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := "%s/obj_%s.png" % [_dir, String(id)]
		print("OBJ shot %s activated=%s -> %s (err=%d)" % [
			String(id), str(objective.is_activated()), path, image.save_png(path)
		])
		objective.queue_free()
		await get_tree().process_frame

	# The wager shrine only appears in districts that roll three secondaries, so
	# it is placed by hand here rather than hoping for the seed.
	var shrine := WagerShrineObjective.new()
	shrine.configure(4242)
	shrine.global_position = anchor
	parent.add_child(shrine)
	player.global_position = anchor + Vector2(0, 40)
	for _f in range(200):
		await get_tree().process_frame
		if get_tree().paused:
			_dismiss_blocking_ui()
	await RenderingServer.frame_post_draw
	var shrine_image := get_viewport().get_texture().get_image()
	var shrine_path := "%s/obj_wager_shrine.png" % _dir
	print("OBJ shot wager_shrine -> %s (err=%d)" % [shrine_path, shrine_image.save_png(shrine_path)])

	print("ObjectiveShotProbe: done")
	get_tree().quit(0)
