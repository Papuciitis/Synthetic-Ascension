extends SceneTree

class FakeDisplayAdapter:
	extends RefCounted
	var state := {&"window_mode": &"windowed", &"resolution": Vector2i(1280, 720), &"position": Vector2i(20, 30), &"vsync": &"on"}
	var last_applied: Dictionary = {}
	var last_keep_maximized := true
	var restored: Dictionary = {}

	func capture_state() -> Dictionary:
		return state.duplicate(true)

	func apply_state(values: Dictionary, keep_maximized_window: bool = true) -> Dictionary:
		last_applied = values.duplicate(true)
		last_keep_maximized = keep_maximized_window
		state.merge(values, true)
		return state.duplicate(true)

	func restore_state(snapshot: Dictionary) -> void:
		restored = snapshot.duplicate(true)
		state = snapshot.duplicate(true)

	func apply_vsync(value: StringName) -> StringName:
		state[&"vsync"] = value
		return value


class FakeRuntimeApplier:
	extends RefCounted
	var applied_all := 0
	var displayed: Array[Dictionary] = []
	var kept_maximized: Array[bool] = []

	func apply_all(_values: Dictionary) -> void:
		applied_all += 1

	func apply_persisted_display(video: Dictionary, keep_maximized: bool = true) -> Dictionary:
		displayed.append(video.duplicate(true))
		kept_maximized.append(keep_maximized)
		return video


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
	var runtime_script := load("res://core/settings/SettingsRuntimeApplier.gd") as Script
	_check(runtime_script != null, "settings runtime applier loads")
	if runtime_script == null:
		_finish()
		return

	var bus_names := [&"Master", &"Music", &"SFX", &"UI"]
	for bus_name in bus_names:
		_check(AudioServer.get_bus_index(bus_name) >= 0, "%s audio bus exists" % bus_name)
	var old_bus_values: Array[Dictionary] = []
	for bus_name in bus_names:
		var index := AudioServer.get_bus_index(bus_name)
		old_bus_values.append({&"index": index, &"volume": AudioServer.get_bus_volume_db(index), &"muted": AudioServer.is_bus_mute(index)})
	var old_max_fps := Engine.max_fps
	var old_scale := root.content_scale_factor

	var fake := FakeDisplayAdapter.new()
	var runtime = runtime_script.new(fake)
	var values := (load("res://core/settings/SettingsSchema.gd") as Script).call("defaults") as Dictionary
	values[&"audio"][&"master_volume"] = 0.5
	values[&"audio"][&"music_volume"] = 0.32
	values[&"audio"][&"sfx_volume"] = 0.75
	values[&"audio"][&"ui_volume"] = 0.8
	values[&"video"][&"frame_limit"] = 144
	values[&"video"][&"vsync"] = &"adaptive"
	values[&"accessibility"][&"ui_scale"] = 1.25
	runtime.apply_all(values)
	_check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master"))), 0.5), "master volume applies to Master bus")
	_check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music"))), 0.32), "music volume applies to Music bus")
	_check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX"))), 0.75), "SFX volume applies to SFX bus")
	_check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"UI"))), 0.8), "UI volume applies to UI bus")
	_check(Engine.max_fps == 144, "frame limit applies immediately")
	_check(is_equal_approx(root.content_scale_factor, 1.25), "UI scale applies immediately")
	_check(fake.state[&"vsync"] == &"adaptive", "VSync delegates through display boundary")

	_check(runtime.begin_display_preview({&"window_mode": &"borderless", &"resolution": Vector2i(1920, 1080)}), "display preview starts")
	_check(fake.last_applied[&"window_mode"] == &"borderless" and fake.last_applied[&"resolution"] == Vector2i(1920, 1080), "display preview applies requested mode and size")
	runtime.revert_display_preview()
	_check(fake.restored[&"window_mode"] == &"windowed" and fake.restored[&"resolution"] == Vector2i(1280, 720), "display rejection restores exact snapshot")
	runtime.apply_persisted_display({&"window_mode": &"windowed"}, false)
	_check(not fake.last_keep_maximized, "the saved window state can be told not to keep a maximized window")
	runtime.apply_persisted_display({&"window_mode": &"windowed"})
	_check(fake.last_keep_maximized, "and keeps one by default")

	for saved in old_bus_values:
		AudioServer.set_bus_volume_db(saved[&"index"], saved[&"volume"])
		AudioServer.set_bus_mute(saved[&"index"], saved[&"muted"])
	Engine.max_fps = old_max_fps
	root.content_scale_factor = old_scale

	# This suite is a script run, so its manager is a tool's: the saved window
	# state lands at once, before the tool sets the window it needs.
	var manager := (load("res://autoload/SettingsManager.gd") as Script).new() as Node
	manager.set("storage_path", "user://settings_runtime_test_%d/settings.cfg" % Time.get_ticks_usec())
	var applier := FakeRuntimeApplier.new()
	manager.set("runtime_applier", applier)
	root.add_child(manager)
	_check(applier.applied_all == 1 and applier.displayed.size() == 1, "a tool's run gets the saved window state at once")
	# On Windows the window opens maximized, and a maximized window ignores a
	# resize: a tool's saved windowed state must un-maximize it.
	_check(applier.kept_maximized == [false], "and a maximized window does not stay maximized for it")
	# A normal start waits for the first drawn frame: while the game loads,
	# the window's cached size is stale and a change flashes undrawn window
	# over the boot splash.
	manager.call("_apply_persisted_display_once_drawn")
	await process_frame
	_check(applier.displayed.size() == 1, "on a normal start the saved window state waits for the first frame to be shown")
	await process_frame
	await process_frame
	_check(applier.displayed.size() == 2 and applier.kept_maximized[1], "and then applies once, keeping a maximized window already at the saved size")
	# A window the player minimized during the splash: the state waits until
	# it is brought back. A desktop window reads as it was requested when the
	# start begins (its events are not processed yet), and minimized from the
	# first frame, for four frames.
	var minimized_script := GDScript.new()
	minimized_script.source_code = "extends \"res://autoload/SettingsManager.gd\"\nvar minimized_from := -1\nvar minimized_until := -1\nfunc _display_name() -> String:\n\treturn \"windows\"\nfunc _window_mode() -> DisplayServer.WindowMode:\n\tvar frame := Engine.get_process_frames()\n\treturn DisplayServer.WINDOW_MODE_MINIMIZED if frame >= minimized_from and frame < minimized_until else DisplayServer.WINDOW_MODE_WINDOWED\n"
	_check(minimized_script.reload() == OK, "fixture: a manager whose desktop window the player minimizes")
	var minimized_manager := minimized_script.new() as Node
	minimized_manager.set("storage_path", "user://settings_runtime_test_%d/settings.cfg" % Time.get_ticks_usec())
	var minimized_applier := FakeRuntimeApplier.new()
	minimized_manager.set("runtime_applier", minimized_applier)
	root.add_child(minimized_manager)
	var frame := Engine.get_process_frames()
	minimized_manager.set("minimized_from", frame + 1)
	minimized_manager.set("minimized_until", frame + 5)
	minimized_manager.call("_apply_persisted_display_once_drawn")
	for _frame in range(4):
		await process_frame
	_check(minimized_applier.displayed.size() == 1, "a window minimized during the splash is not restored over what the player switched to")
	for _frame in range(3):
		await process_frame
	_check(minimized_applier.displayed.size() == 2, "the saved state applies once it is brought back")
	minimized_manager.queue_free()
	var manager_class := manager.get_script() as Script
	_check(manager_class.call("window_minimized", "windows", DisplayServer.WINDOW_MODE_MINIMIZED) and manager_class.call("window_minimized", "x11", DisplayServer.WINDOW_MODE_MINIMIZED), "a minimized window counts as minimized")
	_check(not manager_class.call("window_minimized", "windows", DisplayServer.WINDOW_MODE_MAXIMIZED) and not manager_class.call("window_minimized", "x11", DisplayServer.WINDOW_MODE_WINDOWED) and not manager_class.call("window_minimized", "windows", DisplayServer.WINDOW_MODE_FULLSCREEN), "a shown window does not")
	_check(not manager_class.call("window_minimized", "headless", DisplayServer.WINDOW_MODE_MINIMIZED), "nor does a headless run's absent window, which reports minimized")
	# Which runs are normal starts: the main scene, named or not, and nothing
	# else; a script run is a tool's.
	var manager_script := manager.get_script() as Script
	var as_game: bool = manager_script.call("_opens_main_scene", PackedStringArray(["--path", "/project"]))
	var as_main: bool = manager_script.call("_opens_main_scene", PackedStringArray(["--path", "/project", "res://ui/screens/MainMenu.tscn"]))
	var as_tool: bool = manager_script.call("_opens_main_scene", PackedStringArray(["--path", "/project", "res://tools/tests/ElitePaletteVisualTest.tscn"]))
	var as_script: bool = manager_script.call("_opens_main_scene", PackedStringArray(["--path", "/project", "--script", "res://tools/dev/EnemyRosterShotProbe.gd"]))
	var as_short_script: bool = manager_script.call("_opens_main_scene", PackedStringArray(["-s", "res://tools/tests/SettingsRuntimeTest.gd"]))
	_check(as_game and as_main and not as_tool and not as_script and not as_short_script, "only the main scene's start waits; a tool's scene or script gets the saved window at once")
	manager.queue_free()
	_finish()


func _finish() -> void:
	print("SettingsRuntimeTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
