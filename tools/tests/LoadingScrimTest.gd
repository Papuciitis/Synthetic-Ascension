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
		# A destination card without a wait cue looked like a frozen menu.
		# Exercise the actual widget, including an unnamed menu transition.
		var reduced_before := bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))
		SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
		Global.attempt_segment = 10
		var viewport := SubViewport.new()
		viewport.size = Vector2i(360, 240)
		get_tree().root.add_child(viewport)
		var card := LoadingScrim.new()
		viewport.add_child(card)
		card.show_for("SEGMENT 10", get_tree().current_scene)
		await get_tree().process_frame
		await get_tree().process_frame
		var spinner := card.find_child("Spinner", true, false) as Control
		var loading_label := card.find_child("LoadingLabel", true, false) as Label
		_check(spinner != null and spinner.is_visible_in_tree(), "a segment transition displays its wait indicator")
		_check(loading_label != null and loading_label.is_visible_in_tree() and "loading" in loading_label.text.to_lower(), "the card explicitly explains that the game is loading")
		if spinner != null:
			var initial_rotation := spinner.rotation
			await get_tree().create_timer(0.08).timeout
			_check(not is_equal_approx(spinner.rotation, initial_rotation), "the wait indicator advances while the loading card is waiting")
			SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
			await get_tree().process_frame
			await get_tree().process_frame
			var reduced_rotation := spinner.rotation
			await get_tree().create_timer(0.08).timeout
			_check(is_equal_approx(spinner.rotation, reduced_rotation) and spinner.is_visible_in_tree(), "Reduced Motion retains a visible static wait indicator")
		if loading_label != null:
			var bounds := loading_label.get_global_rect()
			_check(Rect2(Vector2.ZERO, Vector2(360, 240)).encloses(bounds), "the loading message fits inside a small viewport")
		_check(Rect2(Vector2.ZERO, Vector2(360, 240)).encloses(card._title.get_global_rect()) and card._subtitle.is_visible_in_tree() and Rect2(Vector2.ZERO, Vector2(360, 240)).encloses(card._subtitle.get_global_rect()), "the compact segment card retains its destination and district")
		viewport.size = Vector2i(320, 240)
		for _frame in range(4):
			await get_tree().process_frame
		_check(Rect2(Vector2.ZERO, Vector2(320, 240)).encloses(card._content.get_global_rect()), "a visible loading card reflows when its viewport shrinks")
		card.show_for("", get_tree().current_scene)
		await get_tree().process_frame
		_check(loading_label != null and loading_label.is_visible_in_tree(), "unnamed menu transitions retain the loading message")
		SettingsManager.set_value(&"accessibility", &"reduced_motion", reduced_before, false)
		viewport.queue_free()
		await get_tree().process_frame
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
