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
	var screen_scene := load("res://ui/screens/settings/SettingsScreen.tscn") as PackedScene
	var capture_scene := load("res://ui/screens/settings/InputCaptureOverlay.tscn") as PackedScene
	var conflict_scene := load("res://ui/screens/settings/BindingConflictOverlay.tscn") as PackedScene
	var display_scene := load("res://ui/screens/settings/DisplayConfirmationOverlay.tscn") as PackedScene
	_check(screen_scene != null, "Settings screen scene loads")
	_check(capture_scene != null, "input capture overlay loads")
	_check(conflict_scene != null, "binding conflict overlay loads")
	_check(display_scene != null, "display confirmation overlay loads")
	if screen_scene == null or capture_scene == null or conflict_scene == null or display_scene == null:
		_finish()
		return

	var settings_source := root.get_node("SettingsManager")
	var screen := screen_scene.instantiate()
	_check(screen.has_method("configure"), "Settings screen script compiles and exposes configure")
	if not screen.has_method("configure"):
		screen.free()
		_finish()
		return
	screen.call("configure", settings_source)
	root.add_child(screen)
	await process_frame
	screen.call("open")
	await process_frame
	_check(screen.visible, "Settings screen opens visibly")
	for tab_name in ["AudioTab", "VideoTab", "ControlsTab", "AccessibilityTab"]:
		_check(screen.find_child(tab_name, true, false) is Button, "%s exists" % tab_name)
	var audio_tab := screen.find_child("AudioTab", true, false) as Button
	_check(audio_tab != null and audio_tab.has_focus(), "opening Settings focuses the active tab")
	var controls_tab := screen.find_child("ControlsTab", true, false) as Button
	controls_tab.pressed.emit()
	await process_frame
	_check(StringName(screen.get("_active_section")) == &"controls", "tab press switches the active section")
	var expected_rows := (settings_source.call("input_entries") as Array).size()
	_check(screen.get_tree().get_nodes_in_group(&"settings_binding_row").size() == expected_rows, "Controls builds one row per exposed action")

	var capture := capture_scene.instantiate()
	root.add_child(capture)
	await process_frame
	var captured := [false]
	capture.captured.connect(func(_event: InputEvent) -> void: captured[0] = true)
	capture.call("begin", &"keyboard_mouse")
	await process_frame
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.pressed = true
	capture.call("_input", key)
	_check(bool(captured[0]), "capture overlay accepts a physical keyboard key")
	capture.queue_free()

	var conflict := conflict_scene.instantiate()
	root.add_child(conflict)
	await process_frame
	var resolution := [&""]
	conflict.resolved.connect(func(value: StringName) -> void: resolution[0] = value)
	conflict.call("present", "Move Left", "Move Right")
	(conflict.find_child("Swap", true, false) as Button).pressed.emit()
	_check(resolution[0] == &"swap", "conflict overlay emits explicit Swap resolution")
	conflict.queue_free()

	var display := display_scene.instantiate()
	root.add_child(display)
	await process_frame
	var kept := [true]
	display.finished.connect(func(value: bool) -> void: kept[0] = value)
	display.call("start", 0.1)
	display.call("_process", 0.2)
	_check(not bool(kept[0]), "display confirmation timeout rejects the preview")
	display.queue_free()

	screen.call("close")
	_check(not screen.visible, "Settings screen closes without changing scenes")
	screen.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("SettingsScreenTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
