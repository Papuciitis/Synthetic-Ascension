extends Node


const SAVE_DIR := "user://saves"
const SLOT_COUNT := 3

var current_slot: int = -1
var current_save: SaveData = null

func _slot_path(slot: int) -> String:
	return SAVE_DIR + "/slot_%d.tres" % slot

func _slot_pending_path(slot: int) -> String:
	return SAVE_DIR + "/slot_%d.pending.tres" % slot

func _slot_backup_path(slot: int) -> String:
	return SAVE_DIR + "/slot_%d.backup.tres" % slot

func ensure_dir() -> bool:
	# Use a user://-rooted DirAccess instead of passing a virtual path to an
	# "absolute" helper. This also lets us report directory creation failures.
	var user_dir: DirAccess = DirAccess.open("user://")
	if user_dir == null:
		push_error("Cannot open the user data directory: %s" % OS.get_user_data_dir())
		return false
	if user_dir.dir_exists("saves"):
		return true
	var err: Error = user_dir.make_dir_recursive("saves")
	if err != OK:
		push_error("Cannot create save directory '%s' (err=%s)" % [OS.get_user_data_dir(), str(err)])
		return false
	return true

func has_save(slot: int) -> bool:
	if not ensure_dir():
		return false
	return FileAccess.file_exists(_slot_path(slot)) or FileAccess.file_exists(_slot_pending_path(slot)) or FileAccess.file_exists(_slot_backup_path(slot))

func load_slot(slot: int) -> SaveData:
	if not ensure_dir():
		return null
	# A power loss or failed rename can leave the newest valid copy as pending or
	# backup. Load the newest valid candidate rather than losing the whole slot.
	var candidates: Array[String] = [_slot_path(slot), _slot_pending_path(slot), _slot_backup_path(slot)]
	var newest: SaveData = null
	var newest_mtime: int = -1
	for path in candidates:
		if not FileAccess.file_exists(path):
			continue
		var loaded: SaveData = ResourceLoader.load(path) as SaveData
		if loaded == null:
			continue
		var modified: int = int(FileAccess.get_modified_time(path))
		if newest == null or modified > newest_mtime:
			newest = loaded
			newest_mtime = modified
	return newest

func create_slot(slot: int, profile_name: String) -> SaveData:
	ensure_dir()
	var s := SaveData.new()
	s.slot_index = slot
	s.profile_name = profile_name
	s.updated_unix = int(Time.get_unix_time_from_system())
	save_slot(s)
	return s

func save_slot(save: SaveData) -> Error:
	if save == null:
		return ERR_INVALID_PARAMETER
	if not ensure_dir():
		return ERR_CANT_CREATE
	save.updated_unix = int(Time.get_unix_time_from_system())

	var slot: int = save.slot_index
	var target_path: String = _slot_path(slot)
	var pending_path: String = _slot_pending_path(slot)
	var target_name: String = target_path.get_file()
	var pending_name: String = pending_path.get_file()
	var backup_name: String = _slot_backup_path(slot).get_file()
	var save_dir: DirAccess = DirAccess.open(SAVE_DIR)
	if save_dir == null:
		push_error("Cannot open save directory: %s" % OS.get_user_data_dir())
		return ERR_CANT_OPEN

	if save_dir.file_exists(pending_name):
		var stale_err: Error = save_dir.remove(pending_name)
		if stale_err != OK:
			push_error("Cannot replace stale pending save for slot %d (err=%s)" % [slot, str(stale_err)])
			return stale_err

	# Serialize completely before touching the current save.
	var err: Error = ResourceSaver.save(save, pending_path)
	if err != OK:
		push_error("Failed writing pending save for slot %d in '%s' (err=%s)" % [slot, OS.get_user_data_dir(), str(err)])
		return err

	if save_dir.file_exists(backup_name):
		var old_backup_err: Error = save_dir.remove(backup_name)
		if old_backup_err != OK:
			push_warning("Could not remove the previous slot %d backup (err=%s)" % [slot, str(old_backup_err)])

	var had_target: bool = save_dir.file_exists(target_name)
	if had_target:
		# Recovered/copied Windows profiles can retain a read-only file attribute.
		if OS.get_name() == "Windows" and FileAccess.get_read_only_attribute(target_path):
			var writable_err: Error = FileAccess.set_read_only_attribute(target_path, false)
			if writable_err != OK:
				push_error("Slot %d is read-only and could not be made writable (err=%s)" % [slot, str(writable_err)])
				return writable_err
		var backup_err: Error = save_dir.rename(target_name, backup_name)
		if backup_err != OK:
			# Keep the fully written pending file as a recoverable candidate.
			push_error("Could not rotate slot %d save; pending copy preserved (err=%s)" % [slot, str(backup_err)])
			return backup_err

	var promote_err: Error = save_dir.rename(pending_name, target_name)
	if promote_err != OK:
		if had_target and save_dir.file_exists(backup_name):
			save_dir.rename(backup_name, target_name)
		push_error("Could not promote slot %d pending save (err=%s)" % [slot, str(promote_err)])
		return promote_err

	if save_dir.file_exists(backup_name):
		var cleanup_err: Error = save_dir.remove(backup_name)
		if cleanup_err != OK:
			push_warning("Slot %d saved, but its temporary backup could not be removed (err=%s)" % [slot, str(cleanup_err)])
	return OK

func delete_slot(slot: int) -> void:
	if not ensure_dir():
		return
	var save_dir: DirAccess = DirAccess.open(SAVE_DIR)
	if save_dir == null:
		return
	for path in [_slot_path(slot), _slot_pending_path(slot), _slot_backup_path(slot)]:
		var filename: String = String(path).get_file()
		if save_dir.file_exists(filename):
			save_dir.remove(filename)

func set_current(slot: int, save: SaveData) -> void:
	current_slot = slot
	current_save = save
	# Apply immediately so Continue can route correctly and Global has meta/attempt state.
	if Global != null and current_save != null and Global.has_method("apply_save"):
		Global.apply_save(current_save)

func save_current() -> Error:
	if current_save == null:
		return ERR_DOES_NOT_EXIST
	return save_slot(current_save)
