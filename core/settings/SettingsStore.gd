extends RefCounted
class_name SettingsStore

const Schema := preload("res://core/settings/SettingsSchema.gd")

var _primary_path: String
var _temporary_path: String
var _backup_path: String


func _init(primary_path: String) -> void:
	_primary_path = primary_path
	_temporary_path = primary_path + ".tmp"
	_backup_path = primary_path + ".bak"


func load_settings() -> Dictionary:
	var loaded := _load_path(_primary_path)
	if loaded.is_empty():
		loaded = _load_path(_backup_path)
	return Schema.normalize(loaded)


func save_settings(values: Dictionary) -> bool:
	if not _ensure_parent_directory():
		return false
	var normalized: Dictionary = Schema.normalize(values)
	var config := ConfigFile.new()
	config.set_value("schema", "version", Schema.SCHEMA_VERSION)
	for section: StringName in Schema.SECTIONS:
		for key_variant in normalized[section].keys():
			var key := StringName(key_variant)
			config.set_value(String(section), String(key), normalized[section][key])
	var save_error := config.save(_temporary_path)
	if save_error != OK:
		push_error("Failed writing temporary settings, err=%s" % save_error)
		return false
	var validator := ConfigFile.new()
	if validator.load(_temporary_path) != OK:
		push_error("Temporary settings validation failed")
		_remove_if_exists(_temporary_path)
		return false

	_remove_if_exists(_backup_path)
	var moved_primary := false
	if FileAccess.file_exists(_primary_path):
		var backup_error := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(_primary_path),
			ProjectSettings.globalize_path(_backup_path)
		)
		if backup_error != OK:
			push_error("Failed rotating settings backup, err=%s" % backup_error)
			_remove_if_exists(_temporary_path)
			return false
		moved_primary = true

	var promote_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(_temporary_path),
		ProjectSettings.globalize_path(_primary_path)
	)
	if promote_error != OK:
		push_error("Failed promoting settings file, err=%s" % promote_error)
		if moved_primary:
			DirAccess.rename_absolute(
				ProjectSettings.globalize_path(_backup_path),
				ProjectSettings.globalize_path(_primary_path)
			)
		return false
	return true


func _load_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return {}
	if not config.has_section_key("schema", "version"):
		return {}
	var raw: Dictionary = {}
	for section: StringName in Schema.SECTIONS:
		var values: Dictionary = {}
		if config.has_section(String(section)):
			for key in config.get_section_keys(String(section)):
				values[StringName(key)] = config.get_value(String(section), key)
		raw[section] = values
	return raw


func _ensure_parent_directory() -> bool:
	var absolute_dir := ProjectSettings.globalize_path(_primary_path.get_base_dir())
	var error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if error != OK and error != ERR_ALREADY_EXISTS:
		push_error("Failed creating settings directory, err=%s" % error)
		return false
	return true


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
