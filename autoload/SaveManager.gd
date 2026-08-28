extends Node


const SAVE_DIR := "user://saves/"
const SLOT_COUNT := 3

var current_slot: int = -1
var current_save: SaveData = null

# Diagnostics: how often the profile hits the disk, and whether the last write
# ran the synchronous read-back validation (autosaves skip it).
var debug_save_writes: int = 0
var debug_last_save_validated: bool = true

# Slots whose primary file existed but could not be parsed at the last
# load_slot(). The backup is then the last good generation, and save_slot must
# not rotate the unreadable primary over it.
var _unreadable_primary: Dictionary = {}

func _slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.tres" % slot

func _temporary_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.tmp.tres" % slot

func _backup_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.bak.tres" % slot

func _broken_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.broken.tres" % slot

func _load_save_data(path: String) -> SaveData:
	if not FileAccess.file_exists(path):
		return null
	var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return resource as SaveData

func ensure_dir() -> bool:
	# make_dir_recursive_absolute() needs an OS path. Passing user:// directly can
	# fail with ERR_CANT_OPEN on Windows/Godot 4.7 even though ResourceSaver later
	# accepts the virtual path.
	var absolute_dir: String = ProjectSettings.globalize_path(SAVE_DIR)
	var err: int = DirAccess.make_dir_recursive_absolute(absolute_dir)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_error("Failed creating save directory '%s', err=%s" % [absolute_dir, str(err)])
		return false
	return DirAccess.dir_exists_absolute(absolute_dir)

func has_save(slot: int) -> bool:
	if not ensure_dir():
		return false
	return (
		FileAccess.file_exists(_slot_path(slot))
		or FileAccess.file_exists(_backup_path(slot))
	)

func load_slot(slot: int) -> SaveData:
	if not ensure_dir():
		return null
	var primary := _load_save_data(_slot_path(slot))
	if primary != null:
		_unreadable_primary.erase(slot)
		return primary
	if FileAccess.file_exists(_slot_path(slot)):
		_unreadable_primary[slot] = true
	return _load_save_data(_backup_path(slot))

func create_slot(slot: int, profile_name: String) -> SaveData:
	ensure_dir()
	var s := SaveData.new()
	s.slot_index = slot
	s.profile_name = profile_name
	s.updated_unix = int(Time.get_unix_time_from_system())
	save_slot(s)
	return s

func save_slot(save: SaveData, validated: bool = true) -> bool:
	if save == null or not ensure_dir():
		return false
	debug_save_writes += 1
	debug_last_save_validated = validated
	save.updated_unix = int(Time.get_unix_time_from_system())
	var slot := save.slot_index
	var primary_path := _slot_path(slot)
	var temporary_path := _temporary_path(slot)
	var backup_path := _backup_path(slot)
	var absolute_primary := ProjectSettings.globalize_path(primary_path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)

	if FileAccess.file_exists(temporary_path):
		var stale_temp_error := DirAccess.remove_absolute(absolute_temporary)
		if stale_temp_error != OK:
			push_error(
				"Failed removing stale temporary save for slot %d, err=%s"
				% [slot, str(stale_temp_error)]
			)
			return false

	var save_error := ResourceSaver.save(save, temporary_path)
	if save_error != OK:
		push_error("Failed writing temporary save for slot %d, err=%s" % [slot, str(save_error)])
		return false

	# Autosaves skip the synchronous read-back: parsing the file we just wrote
	# doubles the disk cost on the main thread. Manual and transition saves keep
	# the full round-trip check.
	if validated and _load_save_data(temporary_path) == null:
		push_error("Temporary save validation failed for slot %d" % slot)
		DirAccess.remove_absolute(absolute_temporary)
		return false

	var moved_primary := false
	var set_aside := false
	var absolute_broken := ProjectSettings.globalize_path(_broken_path(slot))
	if FileAccess.file_exists(primary_path) and bool(_unreadable_primary.get(slot, false)):
		# The primary could not be parsed at the last load, so the backup is the
		# last good generation. Set the primary aside instead of rotating it over
		# the backup.
		if FileAccess.file_exists(_broken_path(slot)):
			DirAccess.remove_absolute(absolute_broken)
		var aside_error := DirAccess.rename_absolute(absolute_primary, absolute_broken)
		if aside_error != OK:
			push_error(
				"Failed setting aside unreadable save for slot %d, err=%s"
				% [slot, str(aside_error)]
			)
			DirAccess.remove_absolute(absolute_temporary)
			return false
		set_aside = true
	elif FileAccess.file_exists(primary_path):
		if FileAccess.file_exists(backup_path):
			var remove_backup_error := DirAccess.remove_absolute(absolute_backup)
			if remove_backup_error != OK:
				push_error(
					"Failed replacing backup for slot %d, err=%s"
					% [slot, str(remove_backup_error)]
				)
				DirAccess.remove_absolute(absolute_temporary)
				return false
		var backup_error := DirAccess.rename_absolute(absolute_primary, absolute_backup)
		if backup_error != OK:
			push_error(
				"Failed backing up slot %d, err=%s" % [slot, str(backup_error)]
			)
			DirAccess.remove_absolute(absolute_temporary)
			return false
		moved_primary = true

	var replace_error := DirAccess.rename_absolute(absolute_temporary, absolute_primary)
	if replace_error != OK:
		push_error("Failed replacing slot %d, err=%s" % [slot, str(replace_error)])
		if moved_primary:
			var restore_error := DirAccess.rename_absolute(absolute_backup, absolute_primary)
			if restore_error != OK:
				push_error(
					"Failed restoring backup for slot %d, err=%s"
					% [slot, str(restore_error)]
				)
		elif set_aside:
			DirAccess.rename_absolute(absolute_broken, absolute_primary)
		return false
	_unreadable_primary.erase(slot)
	return true

func delete_slot(slot: int) -> void:
	if not ensure_dir():
		return
	_unreadable_primary.erase(slot)
	for path in [_slot_path(slot), _temporary_path(slot), _backup_path(slot), _broken_path(slot)]:
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if error != OK:
				push_error(
					"Failed deleting save artifact '%s', err=%s" % [path, str(error)]
				)

func set_current(slot: int, save: SaveData) -> void:
	current_slot = slot
	current_save = save
	# Apply immediately so Continue can route correctly and Global has meta/attempt state.
	if Global != null and current_save != null and Global.has_method("apply_save"):
		Global.apply_save(current_save)

func save_current(validated: bool = true) -> void:
	if current_save != null:
		save_slot(current_save, validated)
