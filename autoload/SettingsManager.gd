extends Node

signal settings_changed(section: StringName, key: StringName, value: Variant)
signal bindings_changed(action: StringName)
signal display_preview_started(seconds: float)
signal display_preview_finished(kept: bool)

const Schema := preload("res://core/settings/SettingsSchema.gd")
const Store := preload("res://core/settings/SettingsStore.gd")
const BindingService := preload("res://core/settings/InputBindingService.gd")
const ActionCatalog := preload("res://core/settings/InputActionCatalog.gd")
const RuntimeApplier := preload("res://core/settings/SettingsRuntimeApplier.gd")

var storage_path := "user://settings.cfg"
var runtime_applier: RefCounted
var _values: Dictionary = {}
var _store: RefCounted
var _binding_service: RefCounted


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_ui_controller_defaults()
	_store = Store.new(storage_path)
	_values = _store.load_settings()
	_binding_service = BindingService.new()
	_binding_service.ensure_actions()
	_binding_service.reset_defaults()
	var saved_bindings: Dictionary = get_value(&"controls", &"bindings", {}) as Dictionary
	if not saved_bindings.is_empty():
		_binding_service.apply_saved_bindings(saved_bindings)
	_binding_service.set_controller_deadzone(float(get_value(&"controls", &"controller_deadzone", 0.2)))
	if runtime_applier == null:
		runtime_applier = RuntimeApplier.new()
	runtime_applier.apply_all(_values)
	if _opens_main_scene(OS.get_cmdline_args()):
		_apply_persisted_display_once_drawn()
	else:
		# A tool, probe or test runs its own scene or script: the saved state
		# applies at once, before it loads, so the window it then sets (size,
		# mode) is the one it keeps. A saved windowed state un-maximizes the
		# window (on Windows it opens maximized, and then ignores a resize).
		runtime_applier.apply_persisted_display(_values[&"video"] as Dictionary, false)


## The saved window state is applied once the first frame is shown. While the
## game loads, the window's cached size and mode are still the requested ones
## (its events are not processed yet), and a change then leaves undrawn window
## over the boot splash until the slow first frame draws; afterwards the next
## frame redraws it at once, and a window already as saved is left alone.
## Process steps, not draws, so a headless start applies too. A window the
## player minimized during the splash stays minimized: the state waits until
## it is brought back, rather than restoring it over what they switched to.
func _apply_persisted_display_once_drawn() -> void:
	# The first frame is drawn and shown between these two steps.
	await get_tree().process_frame
	await get_tree().process_frame
	while _window_minimized():
		await get_tree().process_frame
	runtime_applier.apply_persisted_display(_values[&"video"] as Dictionary)


func _window_minimized() -> bool:
	return window_minimized(DisplayServer.get_name(), DisplayServer.window_get_mode())


## Whether a window in this mode is minimized by the player. A headless run
## reports its absent window as minimized; that one counts as shown.
static func window_minimized(display_name: String, mode: DisplayServer.WindowMode) -> bool:
	return display_name != "headless" and mode == DisplayServer.WINDOW_MODE_MINIMIZED


## Whether these command-line arguments start the project's main scene: the
## game itself, as an export or the editor's Run Project starts it. Any other
## scene named to run, or a script run (-s, --script), is a tool, probe or
## test.
static func _opens_main_scene(args: PackedStringArray) -> bool:
	if args.has("-s") or args.has("--script"):
		return false
	var main := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main.begins_with("uid://"):
		main = ResourceUID.get_id_path(ResourceUID.text_to_id(main))
	for arg in args:
		if arg.ends_with(".tscn") or arg.ends_with(".scn"):
			return ProjectSettings.localize_path(arg) == main
	return true


## Built-in UI actions can contain only keys on this engine build. Keep
## controller navigation shared by every native menu, outside game bindings.
func _ensure_ui_controller_defaults() -> void:
	var buttons := {
		&"ui_accept": JOY_BUTTON_A,
		&"ui_cancel": JOY_BUTTON_B,
		&"ui_up": JOY_BUTTON_DPAD_UP,
		&"ui_down": JOY_BUTTON_DPAD_DOWN,
		&"ui_left": JOY_BUTTON_DPAD_LEFT,
		&"ui_right": JOY_BUTTON_DPAD_RIGHT,
	}
	for action: StringName in buttons:
		if not InputMap.has_action(action):
			continue
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = buttons[action]
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


func get_value(section: StringName, key: StringName, fallback: Variant = null) -> Variant:
	var section_values: Dictionary = _values.get(section, {}) as Dictionary
	return section_values.get(key, fallback)


func set_value(section: StringName, key: StringName, value: Variant, persist: bool = true) -> bool:
	var defaults: Dictionary = Schema.defaults()
	if not defaults.has(section) or not (defaults[section] as Dictionary).has(key):
		return false
	var candidate := _values.duplicate(true)
	candidate[section][key] = value
	var normalized: Dictionary = Schema.normalize(candidate)
	var normalized_value: Variant = normalized[section][key]
	if _values[section][key] == normalized_value:
		return true
	_values = normalized
	if section == &"controls" and key == &"controller_deadzone" and _binding_service != null:
		_binding_service.set_controller_deadzone(float(normalized_value))
	if runtime_applier != null:
		runtime_applier.apply_all(_values)
	settings_changed.emit(section, key, normalized_value)
	return not persist or _store.save_settings(_values)


func reset_section(section: StringName) -> void:
	var defaults: Dictionary = Schema.defaults()
	if not defaults.has(section):
		return
	_values[section] = (defaults[section] as Dictionary).duplicate(true)
	if section == &"controls" and _binding_service != null:
		_binding_service.reset_defaults()
		_binding_service.set_controller_deadzone(float(_values[section][&"controller_deadzone"]))
		_values[section][&"bindings"] = _binding_service.serialize_bindings()
	for key_variant in (_values[section] as Dictionary).keys():
		var key := StringName(key_variant)
		settings_changed.emit(section, key, _values[section][key])
	_store.save_settings(_values)


func snapshot() -> Dictionary:
	return _values.duplicate(true)


func begin_display_preview(changes: Dictionary) -> bool:
	if runtime_applier == null or not bool(runtime_applier.begin_display_preview(changes)):
		return false
	display_preview_started.emit(12.0)
	return true


func confirm_display_preview() -> void:
	if runtime_applier == null:
		return
	var actual: Dictionary = runtime_applier.confirm_display_preview()
	if actual.is_empty():
		return
	for key in [&"window_mode", &"resolution", &"vsync"]:
		if actual.has(key):
			_values[&"video"][key] = actual[key]
	_values = Schema.normalize(_values)
	_store.save_settings(_values)
	display_preview_finished.emit(true)


func revert_display_preview() -> void:
	if runtime_applier == null or not bool(runtime_applier.is_display_preview_active()):
		return
	runtime_applier.revert_display_preview()
	display_preview_finished.emit(false)


func available_resolutions() -> Array[Vector2i]:
	return runtime_applier.available_resolutions() if runtime_applier != null else []


func input_entries() -> Array[Dictionary]:
	return ActionCatalog.entries()


func input_events(action: StringName, family: StringName) -> Array[InputEvent]:
	return _binding_service.events_for(action, family)


func bind_input(action: StringName, family: StringName, slot: int, event: InputEvent, resolution: StringName = &"cancel") -> Dictionary:
	var result: Dictionary = _binding_service.bind_event(action, family, slot, event, resolution)
	if bool(result.get(&"ok", false)):
		_save_bindings(action)
	return result


func clear_input_slot(action: StringName, family: StringName, slot: int) -> bool:
	if not _binding_service.clear_slot(action, family, slot):
		return false
	_save_bindings(action)
	return true


func reset_controls() -> void:
	reset_section(&"controls")
	bindings_changed.emit(&"")


func _save_bindings(action: StringName) -> void:
	_values[&"controls"][&"bindings"] = _binding_service.serialize_bindings()
	_store.save_settings(_values)
	bindings_changed.emit(action)
