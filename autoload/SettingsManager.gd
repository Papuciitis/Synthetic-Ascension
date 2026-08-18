extends Node

signal settings_changed(section: StringName, key: StringName, value: Variant)

const Schema := preload("res://core/settings/SettingsSchema.gd")
const Store := preload("res://core/settings/SettingsStore.gd")

var storage_path := "user://settings.cfg"
var _values: Dictionary = {}
var _store: RefCounted


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_store = Store.new(storage_path)
	_values = _store.load_settings()


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
	settings_changed.emit(section, key, normalized_value)
	return not persist or _store.save_settings(_values)


func reset_section(section: StringName) -> void:
	var defaults: Dictionary = Schema.defaults()
	if not defaults.has(section):
		return
	_values[section] = (defaults[section] as Dictionary).duplicate(true)
	for key_variant in (_values[section] as Dictionary).keys():
		var key := StringName(key_variant)
		settings_changed.emit(section, key, _values[section][key])
	_store.save_settings(_values)


func snapshot() -> Dictionary:
	return _values.duplicate(true)
