extends Node

## Renders every primary objective type in a real procedural district.
##
## Objective visuals are pure _draw() with no scene file and no art, so the only
## way to know a new template reads at all - let alone reads differently from
## the others - is to put it in a district and look at it. Shots land in
## OBJ_SHOT_DIR (env) or user://objective_shots.
##
## The screenshots need a display; placing each objective in a live district and
## standing on it does not. The probe had no assertions at all and quit(0) on
## the success path, and headless it never even got there: it awaits
## RenderingServer.frame_post_draw before every shot, which never fires without
## a display, so the run hung on the first objective and the harness ended it
## at 0.

var _dir: String = ""
var _is_worker: bool = false
var _passes: int = 0
var _failures: int = 0
var _captured: int = 0


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _can_capture() -> bool:
	return DisplayServer.get_name() != "headless"


func _finish() -> void:
	print("ObjectiveShotProbe: %d passed, %d failed, %d shots" % [
		_passes, _failures, _captured,
	])
	get_tree().quit(1 if _failures > 0 else 0)


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
	_check(player != null, "the district built a player to stand on the sites")
	if player == null:
		_finish()
		return

	# First-encounter dossiers pause the tree, and the breach objective spawns
	# constantly - so without this every shot is of a card.
	_disable_tutorial_modals(get_tree().root)
	_dismiss_blocking_ui()
	# The district only builds one objective, so swap the node between shots
	# rather than rerolling the whole segment three times.
	var host := get_tree().get_first_node_in_group(&"primary_objective") as Node2D
	_check(host != null, "the district rolled a primary objective to stand in for")
	var anchor: Vector2 = host.global_position if host != null else player.global_position
	var parent: Node = host.get_parent() if host != null else get_tree().current_scene
	if host != null:
		host.queue_free()
		await get_tree().process_frame

	var ids: Array = PrimaryObjectiveCatalog.all_ids()
	_check(not ids.is_empty(), "the primary objective catalog is populated (%d)" % ids.size())
	for id in ids:
		var objective := PrimaryObjectiveCatalog.script_for(id).new() as PrimaryObjective
		_check(objective != null, "'%s' instantiates as a PrimaryObjective" % String(id))
		if objective == null:
			continue
		objective.configure(4242)
		objective.global_position = anchor
		parent.add_child(objective)
		# Stand just off centre so activation fires and the site reads in frame.
		player.global_position = anchor + Vector2(0, 140)
		for _f in range(120):
			await get_tree().process_frame
			if get_tree().paused:
				_dismiss_blocking_ui()
		_check(
			objective.is_inside_tree(),
			"'%s' is live in the district after 120 frames" % String(id)
		)
		# The site has to react to the player standing on it, or the shot is of
		# an idle template and says nothing about how the active state reads.
		_check(
			objective.is_activated(),
			"'%s' activates with the player standing on it" % String(id)
		)
		if _can_capture():
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var path := "%s/obj_%s.png" % [_dir, String(id)]
			var err := image.save_png(path)
			print("OBJ shot %s activated=%s -> %s (err=%d)" % [
				String(id), str(objective.is_activated()), path, err
			])
			_check(err == OK, "'%s' was captured (err=%d)" % [String(id), err])
			_captured += 1
		else:
			print("OBJ %s activated=%s (headless, no shot)" % [
				String(id), str(objective.is_activated()),
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
	_check(shrine.is_inside_tree(), "the wager shrine is live in the district")
	if _can_capture():
		await RenderingServer.frame_post_draw
		var shrine_image := get_viewport().get_texture().get_image()
		var shrine_path := "%s/obj_wager_shrine.png" % _dir
		var shrine_err := shrine_image.save_png(shrine_path)
		print("OBJ shot wager_shrine -> %s (err=%d)" % [shrine_path, shrine_err])
		_check(shrine_err == OK, "the wager shrine was captured (err=%d)" % shrine_err)
		_captured += 1
		_check(
			_captured == ids.size() + 1,
			"every objective and the shrine were captured (%d of %d)" % [_captured, ids.size() + 1]
		)
	else:
		print("OBJ headless: no display, %d screenshots skipped" % (ids.size() + 1))
	_finish()
