extends Node

const HitFeelScript := preload("res://autoload/HitFeel.gd")
const TEST_PATH := "user://tests/screen_shake_settings.cfg"

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
	var saved := SettingsManager.snapshot()
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	SettingsManager.set_value(&"accessibility", &"hit_feel", true, false)
	_check(SettingsManager.set_value(&"accessibility", &"screen_shake", true, false), "screen shake is an independent setting")
	var player := Node2D.new()
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	player.add_child(camera)
	add_child(player)
	var feel := HitFeelScript.new()
	add_child(feel)
	_check(feel.punch_direction(player, Vector2.RIGHT, 6.0) and camera.offset.x > 0.0, "enabled screen shake moves the camera")
	SettingsManager.set_value(&"accessibility", &"screen_shake", false, false)
	_check(camera.offset == Vector2.ZERO and feel.punch_offset() == Vector2.ZERO, "switching shake off immediately clears an active kick")
	_check(not feel.punch_direction(player, Vector2.RIGHT, 6.0) and camera.offset == Vector2.ZERO, "disabled shake blocks subsequent camera kicks")
	Engine.time_scale = 1.0
	feel.request_stop(40)
	_check(feel.is_stopped(), "hit-stop still works with screen shake off")
	feel.queue_free()
	await get_tree().process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0), "hit-stop cleanup restores time")
	SettingsManager.set_value(&"accessibility", &"screen_shake", true, false)
	feel = HitFeelScript.new()
	add_child(feel)
	_check(feel.punch_direction(player, Vector2.LEFT, 6.0), "shake can be enabled again immediately")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	_check(camera.offset == Vector2.ZERO and not feel.punch_direction(player, Vector2.RIGHT, 6.0), "reduced motion clears and blocks camera shake")
	feel.queue_free()
	await get_tree().process_frame

	var store := SettingsStore.new(TEST_PATH)
	var values := SettingsSchema.defaults()
	values[&"accessibility"][&"screen_shake"] = false
	_check(store.save_settings(values), "isolated screen shake preference saves")
	_check(store.load_settings()[&"accessibility"].get(&"screen_shake", true) == false, "disabled screen shake survives reload")
	for path in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var screen := (load("res://ui/screens/settings/SettingsScreen.tscn") as PackedScene).instantiate()
	screen.call("configure", SettingsManager)
	add_child(screen)
	screen.call("open")
	(screen.find_child("AccessibilityTab", true, false) as Button).pressed.emit()
	var toggle := screen.find_child("ScreenShakeToggle", true, false) as CheckBox
	_check(toggle != null and toggle.button_pressed, "Accessibility exposes the live Screen shake toggle")
	screen.call("close")
	screen.queue_free()
	player.queue_free()
	for key in [&"screen_shake", &"reduced_motion", &"hit_feel"]:
		SettingsManager.set_value(&"accessibility", key, saved[&"accessibility"].get(key, true), false)
	await get_tree().process_frame
	print("ScreenShakeSettingTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
