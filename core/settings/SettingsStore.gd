extends RefCounted
class_name SettingsStore

const Schema := preload("res://core/settings/SettingsSchema.gd")

var _primary_path: String
var _temporary_path: String
var _backup_path: String

# Schema version of the file the last load_settings() actually read
# (0 = none). A value above Schema.SCHEMA_VERSION means the file came from a
# newer build; it is still read best-effort - normalize() clamps and drops
# unknown keys - and a warning is logged.
var last_loaded_schema_version: int = 0


func _init(primary_path: String) -> void:
	_primary_path = primary_path
	_temporary_path = primary_path + ".tmp"
	_backup_path = primary_path + ".bak"


## Renders one filesystem failure: the engine's own name for the error - never
## the raw enum int - and the file the operation could not reach.
func format_io_error(action: String, path: String, err: int) -> String:
	return "[SettingsStore] %s failed: path=%s err=%s" % [action, path, error_string(err)]


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
		push_error(format_io_error("write temporary settings", _temporary_path, save_error))
		return false
	var validator := ConfigFile.new()
	if validator.load(_temporary_path) != OK:
		push_error(
			"[SettingsStore] temporary settings failed read-back validation: path=%s"
			% _temporary_path
		)
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
			push_error(format_io_error(
				"rotate settings backup",
				"%s -> %s" % [_primary_path, _backup_path],
				backup_error
			))
			_remove_if_exists(_temporary_path)
			return false
		moved_primary = true

	var promote_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(_temporary_path),
		ProjectSettings.globalize_path(_primary_path)
	)
	if promote_error != OK:
		push_error(format_io_error(
			"promote settings file",
			"%s -> %s" % [_temporary_path, _primary_path],
			promote_error
		))
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
	var file_version := int(config.get_value("schema", "version", 0))
	if file_version > Schema.SCHEMA_VERSION:
		push_warning(
			"[SettingsStore] reading a newer settings schema best-effort: path=%s file_version=%d build_version=%d"
			% [path, file_version, Schema.SCHEMA_VERSION]
		)
	last_loaded_schema_version = file_version
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
		push_error(format_io_error("create settings directory", absolute_dir, error))
		return false
	return true


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
