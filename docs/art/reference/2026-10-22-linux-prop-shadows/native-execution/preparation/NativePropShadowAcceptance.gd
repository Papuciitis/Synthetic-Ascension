extends "/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/CityPropShadowAcceptance.gd"
## Execution envelope only. Inherits every original48 predicate unchanged.
## SettingsManager applies saved display/cap before this scene's _ready.


func _ready() -> void:
	Engine.max_fps = 20
	get_window().mode = Window.MODE_WINDOWED
	get_window().borderless = false
	get_window().size = Vector2i(640, 360)
	_begin_native.call_deferred()


func _begin_native() -> void:
	await get_tree().process_frame
	var state: Dictionary = {"display":DisplayServer.get_name(), "driver":RenderingServer.get_current_rendering_driver_name(), "renderer":RenderingServer.get_current_rendering_method(), "adapter":RenderingServer.get_video_adapter_name(), "api":RenderingServer.get_video_adapter_api_version(), "engine_max_fps":Engine.max_fps, "physics_ticks_per_second":Engine.physics_ticks_per_second, "window_mode":get_window().mode, "window_borderless":get_window().borderless, "window_size":[get_window().size.x, get_window().size.y], "parent_source_sha256":FileAccess.get_sha256("/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/CityPropShadowAcceptance.gd"), "scope":"Native boot observation before calling unchanged parent._ready; no predicate, renderer, resource or physical acceptance override."}
	var path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--native-state="): path = arg.trim_prefix("--native-state=")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE) if path.is_absolute_path() else null
	if file == null:
		push_error("Native prop fixture could not write actual boot state")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(state, "  ") + "\n")
	file.close()
	if DisplayServer.get_name() == "headless" or state.driver != "opengl3" or state.renderer != "gl_compatibility" or Engine.max_fps != 20 or Engine.physics_ticks_per_second != 60 or get_window().mode != Window.MODE_WINDOWED or get_window().borderless or get_window().size != Vector2i(640, 360):
		push_error("Native prop fixture actual backend/cap/window differs from reviewed setup")
		get_tree().quit(2)
		return
	super._ready()
