extends SceneTree

class FakeDisplayAdapter:
	extends RefCounted
	var state := {&"window_mode": &"windowed", &"resolution": Vector2i(1280, 720), &"position": Vector2i(20, 30), &"vsync": &"on"}
	var last_applied: Dictionary = {}
	var restored: Dictionary = {}

	func capture_state() -> Dictionary:
		return state.duplicate(true)

	func apply_state(values: Dictionary) -> Dictionary:
		last_applied = values.duplicate(true)
		state.merge(values, true)
		return state.duplicate(true)

	func restore_state(snapshot: Dictionary) -> void:
		restored = snapshot.duplicate(true)
		state = snapshot.duplicate(true)

	func apply_vsync(value: StringName) -> StringName:
		state[&"vsync"] = value
		return value


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

	for saved in old_bus_values:
		AudioServer.set_bus_volume_db(saved[&"index"], saved[&"volume"])
		AudioServer.set_bus_mute(saved[&"index"], saved[&"muted"])
	Engine.max_fps = old_max_fps
	root.content_scale_factor = old_scale
	_finish()


func _finish() -> void:
	print("SettingsRuntimeTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
