extends Node

## Opening the inventory must stop the world, and closing it must give the world
## back - but only if the inventory is what stopped it.
##
## Needs a real run: the HUD, the bag controller and the tree pause only exist
## together in the game scene.

var _passes: int = 0
var _failures: int = 0
var _dir: String = ""
var _is_worker: bool = false


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: %s" % message)


func _ready() -> void:
	if _is_worker:
		get_tree().create_timer(120.0).timeout.connect(func() -> void:
			push_error("ManagementPauseProbe timed out")
			get_tree().quit(1)
		)
		_run.call_deferred()
		return
	_dir = OS.get_environment("PAUSE_SHOT_DIR")
	if _dir.is_empty():
		_dir = ProjectSettings.globalize_path("user://pause_shots")
	DirAccess.make_dir_recursive_absolute(_dir)
	var worker := Node.new()
	worker.name = "ManagementPauseWorker"
	worker.process_mode = Node.PROCESS_MODE_ALWAYS
	worker.set_script(get_script())
	worker.set("_dir", _dir)
	worker.set("_is_worker", true)
	get_tree().root.add_child.call_deferred(worker)


func _run() -> void:
	Global.start_new_attempt()
	Global.attempt_segment = 1
	Global.attempt_opening_completed = true
	Global.attempt_opening_phase = 10
	Global.debug_dev_mode = true
	Global.debug_player_god_mode = true
	Global.goto_game()
	for _wait in range(400):
		await get_tree().process_frame
		if get_tree().get_first_node_in_group(&"player") != null:
			break
	_dismiss_blocking_ui()
	for _f in range(30):
		await get_tree().process_frame
		if get_tree().paused:
			_dismiss_blocking_ui()

	var hud := _find_hud(get_tree().root)
	_check(hud != null, "the run has a HUD")
	if hud == null:
		_finish()
		return
	var bag: Node = hud.get("bag_ctl")
	_check(bag != null, "the HUD has a bag controller")
	if bag == null:
		_finish()
		return

	_check(InputMap.has_action(&"bag_toggle"), "the inventory has a binding")
	_check(not get_tree().paused, "the world is running before the bag opens")

	bag.call("toggle_bag_open")
	for _f in range(6):
		await get_tree().process_frame
	_check(bool(bag.call("is_management_mode")), "the bag opened")
	_check(get_tree().paused, "opening the inventory stops the world")
	_check(
		int(hud.process_mode) == int(Node.PROCESS_MODE_ALWAYS),
		"the HUD keeps running so the panel is still usable"
	)
	# A paused headless viewport has no meaningful capture and may never finish a
	# readback. Interactive runs still preserve the visual probe artifact.
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw(false)
		var image := get_viewport().get_texture().get_image()
		print("PAUSE shot -> %s (err=%d)" % [
			"%s/paused_inventory.png" % _dir,
			image.save_png("%s/paused_inventory.png" % _dir)
		])

	var run_sheet := hud.get("run_sheet") as Control
	var focused_tab := (
		run_sheet.get_node_or_null("Archive/Index/Sets") as Button
		if run_sheet != null else null
	)
	_check(focused_tab != null, "the paused archive exposes its Sets tab")
	if focused_tab != null:
		focused_tab.grab_focus()
		await get_tree().process_frame
		_check(get_viewport().gui_get_focus_owner() == focused_tab, "the Sets tab owns keyboard focus")

	var tab_press := InputEventKey.new()
	tab_press.pressed = true
	tab_press.keycode = KEY_TAB
	tab_press.physical_keycode = KEY_TAB
	Input.parse_input_event(tab_press)
	for _f in range(6):
		await get_tree().process_frame
	_check(not bool(bag.call("is_management_mode")), "Tab closes management even when an archive tab has focus")
	_check(not get_tree().paused, "Tab-closing the inventory gives the world back")
	var tab_release := InputEventKey.new()
	tab_release.pressed = false
	tab_release.keycode = KEY_TAB
	tab_release.physical_keycode = KEY_TAB
	Input.parse_input_event(tab_release)

	bag.call("toggle_bag_open")
	for _f in range(4):
		await get_tree().process_frame
	_check(bool(bag.call("is_management_mode")), "management reopens for Escape routing")
	if focused_tab != null:
		focused_tab.grab_focus()
		await get_tree().process_frame
	var escape_press := InputEventKey.new()
	escape_press.pressed = true
	escape_press.keycode = KEY_ESCAPE
	escape_press.physical_keycode = KEY_ESCAPE
	Input.parse_input_event(escape_press)
	for _f in range(6):
		await get_tree().process_frame
	_check(not bool(bag.call("is_management_mode")), "Escape closes management while an archive tab has focus")
	_check(not get_tree().paused, "Escape-closing the inventory gives the world back")
	var escape_release := InputEventKey.new()
	escape_release.pressed = false
	escape_release.keycode = KEY_ESCAPE
	escape_release.physical_keycode = KEY_ESCAPE
	Input.parse_input_event(escape_release)

	# A modal already holding the pause must keep it: the bag opening on top of
	# a tutorial card must not resume the fight when it closes.
	get_tree().paused = true
	bag.call("toggle_bag_open")
	for _f in range(4):
		await get_tree().process_frame
	bag.call("toggle_bag_open")
	for _f in range(4):
		await get_tree().process_frame
	_check(get_tree().paused, "the bag never resumes a pause it did not take")
	get_tree().paused = false

	_finish()


func _find_hud(node: Node) -> Node:
	var script: Variant = node.get_script()
	if script != null and String(script.resource_path).ends_with("ui/screens/hud.gd"):
		return node
	for child in node.get_children():
		var found := _find_hud(child)
		if found != null:
			return found
	return null


func _dismiss_blocking_ui() -> void:
	var scene := get_tree().current_scene
	var ui := scene.get_node_or_null("UI") if scene != null else null
	if ui != null:
		for child in ui.get_children():
			if child.has_method("open_choose_3"):
				child.queue_free()
	get_tree().paused = false


func _finish() -> void:
	print("ManagementPauseProbe: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
