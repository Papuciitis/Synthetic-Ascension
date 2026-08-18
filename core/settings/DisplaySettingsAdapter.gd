extends RefCounted
class_name DisplaySettingsAdapter


func capture_state() -> Dictionary:
	return {
		&"window_mode": _mode_name(),
		&"resolution": DisplayServer.window_get_size(),
		&"position": DisplayServer.window_get_position(),
		&"vsync": _vsync_name(DisplayServer.window_get_vsync_mode()),
	}


func apply_state(values: Dictionary) -> Dictionary:
	var wanted_mode := StringName(values.get(&"window_mode", _mode_name()))
	match wanted_mode:
		&"fullscreen":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		&"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			_apply_resolution(values.get(&"resolution", DisplayServer.window_get_size()) as Vector2i)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			_apply_resolution(values.get(&"resolution", DisplayServer.window_get_size()) as Vector2i)
	if values.has(&"position") and wanted_mode == &"windowed":
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
	var usable := DisplayServer.screen_get_usable_rect()
	var clamped := Vector2i(
		clampi(requested.x, 640, maxi(640, usable.size.x)),
		clampi(requested.y, 360, maxi(360, usable.size.y))
	)
	DisplayServer.window_set_size(clamped)


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
