extends RefCounted
class_name SettingsRuntimeApplier

const DisplayAdapter := preload("res://core/settings/DisplaySettingsAdapter.gd")

var _display_adapter: RefCounted
var _display_snapshot: Dictionary = {}
var _preview_active := false


func _init(display_adapter: RefCounted = null) -> void:
	_display_adapter = display_adapter if display_adapter != null else DisplayAdapter.new()


func apply_all(values: Dictionary) -> void:
	var audio: Dictionary = values.get(&"audio", {}) as Dictionary
	_apply_audio_bus(&"Master", float(audio.get(&"master_volume", 1.0)), bool(audio.get(&"master_muted", false)))
	_apply_audio_bus(&"Music", float(audio.get(&"music_volume", 0.32)), bool(audio.get(&"music_muted", false)))
	_apply_audio_bus(&"SFX", float(audio.get(&"sfx_volume", 1.0)), bool(audio.get(&"sfx_muted", false)))
	_apply_audio_bus(&"UI", float(audio.get(&"ui_volume", 1.0)), bool(audio.get(&"ui_muted", false)))
	var video: Dictionary = values.get(&"video", {}) as Dictionary
	Engine.max_fps = int(video.get(&"frame_limit", 0))
	_display_adapter.call("apply_vsync", StringName(video.get(&"vsync", &"on")))
	var accessibility: Dictionary = values.get(&"accessibility", {}) as Dictionary
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.root.content_scale_factor = float(accessibility.get(&"ui_scale", 1.0))


func apply_persisted_display(video: Dictionary) -> Dictionary:
	return _display_adapter.call("apply_state", video) as Dictionary


func begin_display_preview(changes: Dictionary) -> bool:
	if _preview_active:
		return false
	_display_snapshot = _display_adapter.call("capture_state") as Dictionary
	_display_adapter.call("apply_state", changes)
	_preview_active = true
	return true


func confirm_display_preview() -> Dictionary:
	if not _preview_active:
		return {}
	var actual := _display_adapter.call("capture_state") as Dictionary
	_display_snapshot.clear()
	_preview_active = false
	return actual


func revert_display_preview() -> void:
	if not _preview_active:
		return
	_display_adapter.call("restore_state", _display_snapshot)
	_display_snapshot.clear()
	_preview_active = false


func is_display_preview_active() -> bool:
	return _preview_active


func available_resolutions() -> Array[Vector2i]:
	return _display_adapter.call("available_resolutions") as Array[Vector2i]


func _apply_audio_bus(bus_name: StringName, linear_volume: float, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var volume := clampf(linear_volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(index, muted or volume <= 0.0)
