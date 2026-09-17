extends Node

# A scene change shows the loading card before the block and lifts it a few
# frames after the new scene exists. The checks run from a node under the
# root, because the test scene itself is what gets replaced.
#
# Run: <godot> --headless --path . res://tools/tests/LoadingScrimTest.tscn

class Driver:
	extends Node

	var _passes := 0
	var _failures := 0

	func _check(condition: bool, message: String) -> void:
		if condition:
			_passes += 1
			print("PASS: ", message)
		else:
			_failures += 1
			push_error("FAIL: " + message)

	func run() -> void:
		var before := get_tree().current_scene
		Global.attempt_segment = 3
		_check(Global._scene_title(Global.PATH_GAME) == "SEGMENT 3" and Global._scene_title(Global.PATH_HUB_SHOP) == "THE HUB", "the card names the destination")
		Global.goto_scene(Global.PATH_MAIN_MENU)
		var scrim := Global.loading_scrim()
		_check(scrim.is_showing() and scrim._title.text == "", "the card shows at once for a scene change")
		await get_tree().process_frame
		_check(scrim.is_showing() and get_tree().current_scene == before, "the card gets a frame on screen before the scene changes")
		var changed := false
		for _i in range(8):
			await get_tree().process_frame
			if get_tree().current_scene != before and get_tree().current_scene != null:
				changed = true
		_check(changed, "the scene changed after the card rendered")
		_check(scrim._fading or not scrim.is_showing(), "the card starts lifting once the new scene has rendered")
		# Headless frames are not paced, so wait by wall time, not frames.
		await get_tree().create_timer(LoadingScrim.FADE_SECONDS + 0.4).timeout
		_check(not scrim.is_showing(), "the card is gone after the fade")
		print("LoadingScrimTest: %d passed, %d failed" % [_passes, _failures])
		get_tree().quit(1 if _failures > 0 else 0)


func _ready() -> void:
	# The root is busy with this scene's setup during _ready; add the driver
	# once that finishes, and let its own _ready start the run.
	var driver := Driver.new()
	driver.name = "LoadingScrimDriver"
	driver.ready.connect(driver.run, CONNECT_ONE_SHOT)
	get_tree().root.call_deferred("add_child", driver)
