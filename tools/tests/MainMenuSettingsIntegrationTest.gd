extends SceneTree

var _passes := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var menu_scene := load("res://ui/screens/MainMenu.tscn") as PackedScene
	_check(menu_scene != null, "main menu scene loads")
	if menu_scene == null:
		_finish()
		return
	var menu := menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	var path := "Center/Panel/Padding/VBox/"
	for button_name in ["Continue", "Saves", "Settings", "Quit"]:
		var button := menu.get_node(path + button_name) as Button
		_check(button.focus_mode == Control.FOCUS_ALL, "%s accepts keyboard/controller focus" % button_name)
	var settings_button := menu.get_node(path + "Settings") as Button
	settings_button.pressed.emit()
	await process_frame
	var settings_screens := menu.find_children("SettingsScreen", "Control", true, false)
	_check(settings_screens.size() == 1, "Settings button creates exactly one reusable screen")
	if settings_screens.size() == 1:
		var screen := settings_screens[0]
		_check(screen.visible, "Settings button opens the screen")
		screen.call("close")
		await process_frame
		_check(not screen.visible, "closing Settings hides the reusable screen")
		_check(settings_button.has_focus(), "closing Settings restores menu focus")
		settings_button.pressed.emit()
		await process_frame
		_check(menu.find_children("SettingsScreen", "Control", true, false).size() == 1, "reopening Settings does not stack screens")
	menu.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("MainMenuSettingsIntegrationTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
