extends RefCounted
class_name DisplaySettingsAdapter


func capture_state() -> Dictionary:
	return {
		&"window_mode": _mode_name(),
		&"resolution": DisplayServer.window_get_size(),
		&"position": DisplayServer.window_get_position(),
		&"vsync": _vsync_name(DisplayServer.window_get_vsync_mode()),
	}


## `keep_maximized_window`: a maximized window already at the requested
## windowed size may stay maximized. A tool that sizes its own window passes
## false: a maximized window ignores a resize on Windows.
func apply_state(values: Dictionary, keep_maximized_window: bool = true) -> Dictionary:
	var wanted_mode := StringName(values.get(&"window_mode", _mode_name()))
	var keep_maximized := false
	match wanted_mode:
		&"fullscreen":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		&"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			_apply_resolution(values.get(&"resolution", DisplayServer.window_get_size()) as Vector2i)
		_:
			var requested := _clamped_resolution(values.get(&"resolution", DisplayServer.window_get_size()) as Vector2i)
			# A maximized window is already windowed (capture_state records it
			# so). Un-maximizing it only to size it back would flash undrawn
			# window over the boot splash at every start.
			keep_maximized = keep_maximized_window and _is_maximized_at(requested)
			if not keep_maximized:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
				DisplayServer.window_set_size(requested)
	if values.has(&"position") and wanted_mode == &"windowed" and not keep_maximized:
		DisplayServer.window_set_position(values[&"position"] as Vector2i)
	if values.has(&"vsync"):
		apply_vsync(StringName(values[&"vsync"]))
	return capture_state()


func restore_state(snapshot: Dictionary) -> void:
	apply_state(snapshot)


func apply_vsync(value: StringName) -> StringName:
	var mode := DisplayServer.VSYNC_ENABLED
	match value:
		&"off": mode = DisplayServer.VSYNC_DISABLED
		&"adaptive": mode = DisplayServer.VSYNC_ADAPTIVE
	DisplayServer.window_set_vsync_mode(mode)
	return _vsync_name(DisplayServer.window_get_vsync_mode())


func available_resolutions() -> Array[Vector2i]:
	var usable := DisplayServer.screen_get_usable_rect()
	var candidates: Array[Vector2i] = [
		Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
		Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
	]
	var result: Array[Vector2i] = []
	for candidate in candidates:
		if candidate.x <= usable.size.x and candidate.y <= usable.size.y:
			result.append(candidate)
	var current := DisplayServer.window_get_size()
	if current not in result:
		result.append(current)
	return result


func _apply_resolution(requested: Vector2i) -> void:
	DisplayServer.window_set_size(_clamped_resolution(requested))


func _clamped_resolution(requested: Vector2i) -> Vector2i:
	var usable := DisplayServer.screen_get_usable_rect()
	return Vector2i(
		clampi(requested.x, 640, maxi(640, usable.size.x)),
		clampi(requested.y, 360, maxi(360, usable.size.y))
	)


func _is_maximized_at(size: Vector2i) -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED \
		and not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS) \
		and DisplayServer.window_get_size() == size


func _mode_name() -> StringName:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		return &"fullscreen"
	if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS):
		return &"borderless"
	return &"windowed"


func _vsync_name(mode: DisplayServer.VSyncMode) -> StringName:
	match mode:
		DisplayServer.VSYNC_DISABLED: return &"off"
		DisplayServer.VSYNC_ADAPTIVE: return &"adaptive"
	return &"on"
