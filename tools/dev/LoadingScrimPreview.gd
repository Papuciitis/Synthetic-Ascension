extends Node
## Capture the production loading card held over this scene, without a save
## selection or scene build. The spinner does not imply measurable progress.

var _out := "res://.superpowers/sdd/2026-10-18-finish-boss-delivery/loading/captures/"


func _enter_tree() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	PerformanceFlightRecorder.set_enabled(false)
	BalanceRecorder.set_enabled(false)
	get_window().position = Vector2i(-10000, -10000)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("LoadingScrimPreview requires rendering")
		get_tree().quit(1)
		return
	var before := SaveManager.debug_save_writes
	var absolute_out := ProjectSettings.globalize_path(_out)
	DirAccess.make_dir_recursive_absolute(absolute_out)
	AudioServer.set_bus_mute(0, true)
	get_window().mode = Window.MODE_WINDOWED
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_factor = 1.0
	Engine.max_fps = 60
	Global.attempt_segment = 10
	var scrim := Global.loading_scrim()
	var captures: Array[Dictionary] = []
	var failures := 0
	for row: Dictionary in [
		{"name": "segment-normal", "title": "SEGMENT 10", "window": Vector2i(1280, 720), "viewport": Vector2i(1920, 1080), "reduced": false},
		{"name": "hub-small", "title": "THE HUB", "window": Vector2i(960, 540), "viewport": Vector2i(1920, 1080), "reduced": false},
		{"name": "segment-compact-reduced", "title": "SEGMENT 10", "window": Vector2i(360, 240), "viewport": Vector2i(360, 240), "reduced": true},
		{"name": "menu-reduced", "title": "", "window": Vector2i(960, 540), "viewport": Vector2i(1920, 1080), "reduced": true},
	]:
		get_window().size = row.window
		get_window().content_scale_size = row.viewport
		SettingsManager.set_value(&"accessibility", &"reduced_motion", row.reduced, false)
		scrim.show_for(row.title, self)
		for _frame in range(5):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var filename := String(row.name) + ".png"
		var image := get_viewport().get_texture().get_image()
		if image.save_png(absolute_out.path_join(filename)) != OK:
			failures += 1
		captures.append({"file": filename, "window": str(row.window), "viewport": str(row.viewport), "reduced_motion": row.reduced})
	if SaveManager.debug_save_writes != before:
		failures += 1
	var metadata := FileAccess.open(absolute_out.path_join("capture-info.json"), FileAccess.WRITE)
	if metadata != null:
		metadata.store_string(JSON.stringify({"scene": "res://tools/dev/LoadingScrimPreview.tscn", "captures": captures, "failures": failures, "save_writes": SaveManager.debug_save_writes - before, "scope": "Production scene-transition card held for capture. No asynchronous scene loading or measured progress is implied."}, "\t"))
	else:
		failures += 1
	print("LoadingScrimPreview: %d captures; failures=%d; save_writes=%d" % [captures.size(), failures, SaveManager.debug_save_writes - before])
	get_tree().quit(1 if failures else 0)
