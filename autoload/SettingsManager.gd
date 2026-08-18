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
	runtime_applier.apply_persisted_display(_values[&"video"] as Dictionary)


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
