extends Node

const TEST_SLOT: int = 97
const BuildInfoScript := preload("res://core/systems/telemetry/BuildInfo.gd")

var _failures: int = 0
var _passes: int = 0
var _global: Node
var _save_manager: Node


func _ready() -> void:
	_global = get_node("/root/Global")
	_save_manager = get_node("/root/SaveManager")
	call_deferred("_run")


func _run() -> void:
	_test_write_save_copies_meta_stash()
	_test_write_save_copies_active_vendor_snapshot()
	_test_second_save_keeps_previous_backup()
	_test_load_recovers_from_corrupt_primary()
	_test_save_after_unreadable_primary_keeps_backup()
	_test_load_bypasses_resource_cache()
	_test_delete_removes_all_slot_files()
	_test_meta_stash_round_trip()
	_test_active_vendor_round_trip()
	_test_doctrine_state_round_trip()
	_test_legacy_major_choice_migration()
	_test_manifestation_cards_round_trip()
	_test_save_version_round_trip()
	_test_io_failures_render_engine_error_names()
	await get_tree().process_frame
	print("SaveIntegrityTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _primary_path() -> String:
	return "user://saves/slot_%d.tres" % TEST_SLOT


func _temporary_path() -> String:
	return "user://saves/slot_%d.tmp.tres" % TEST_SLOT


func _backup_path() -> String:
	return "user://saves/slot_%d.bak.tres" % TEST_SLOT


func _broken_path() -> String:
	return "user://saves/slot_%d.broken.tres" % TEST_SLOT


func _cleanup_slot() -> void:
	for path in [_primary_path(), _temporary_path(), _backup_path(), _broken_path()]:
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			_check(error == OK, "test fixture removes %s" % path.get_file())


func _test_write_save_copies_meta_stash() -> void:
	var previous_stash: StashInventory = _global.meta_stash
	var stash := StashInventory.new()
	var marker := ItemInstance.new()
	stash.set_item(0, marker)
	_global.meta_stash = stash
	var save := SaveData.new()

	_global.write_save(save)

	_check(save.meta_stash == stash, "write_save copies the profile stash")
	_check(
		save.meta_stash != null and save.meta_stash.get_at(0) == marker,
		"copied stash retains its occupied slot"
	)
	_global.meta_stash = previous_stash


func _test_write_save_copies_active_vendor_snapshot() -> void:
	var previous_active: bool = _global.attempt_active
	var previous_segment: int = _global.attempt_vendor_segment
	var previous_refreshes: int = _global.attempt_vendor_refreshes
	var previous_seed: int = _global.attempt_vendor_seed
	var previous_bag: BagInventory = _global.attempt_vendor_bag
	var bag := BagInventory.new()
	bag.debug_bag = false
	_global.attempt_active = true
	_global.attempt_vendor_segment = 4
	_global.attempt_vendor_refreshes = 3
	_global.attempt_vendor_seed = 8675309
	_global.attempt_vendor_bag = bag
	var save := SaveData.new()

	_global.write_save(save)

	_check(save.attempt_vendor_segment == 4, "write_save copies vendor segment")
	_check(save.attempt_vendor_refreshes == 3, "write_save copies vendor refresh count")
	_check(save.attempt_vendor_seed == 8675309, "write_save copies vendor seed")
	_check(save.attempt_vendor_bag == bag, "write_save copies vendor bag")
	_global.attempt_active = previous_active
	_global.attempt_vendor_segment = previous_segment
	_global.attempt_vendor_refreshes = previous_refreshes
	_global.attempt_vendor_seed = previous_seed
	_global.attempt_vendor_bag = previous_bag


func _test_second_save_keeps_previous_backup() -> void:
	_cleanup_slot()
	var first := SaveData.new()
	first.slot_index = TEST_SLOT
	first.profile_name = "first"
	_save_manager.save_slot(first)
	var second := SaveData.new()
	second.slot_index = TEST_SLOT
	second.profile_name = "second"
	_save_manager.save_slot(second)

	var primary := ResourceLoader.load(
		_primary_path(), "", ResourceLoader.CACHE_MODE_IGNORE
	) as SaveData
	var backup := ResourceLoader.load(
		_backup_path(), "", ResourceLoader.CACHE_MODE_IGNORE
	) as SaveData
	_check(
		primary != null and primary.profile_name == "second",
		"primary contains newest generation"
	)
	_check(
		backup != null and backup.profile_name == "first",
		"backup contains previous generation"
	)
	_cleanup_slot()


func _test_load_recovers_from_corrupt_primary() -> void:
	_cleanup_slot()
	var first := SaveData.new()
	first.slot_index = TEST_SLOT
	first.profile_name = "recoverable"
	_save_manager.save_slot(first)
	var second := SaveData.new()
	second.slot_index = TEST_SLOT
	second.profile_name = "newest"
	_save_manager.save_slot(second)
	var file := FileAccess.open(_primary_path(), FileAccess.WRITE)
	file.store_string("not a Godot resource")
	file.close()

	var loaded: SaveData = _save_manager.load_slot(TEST_SLOT)

	_check(
		loaded != null and loaded.profile_name == "recoverable",
		"invalid primary falls back to valid backup"
	)
	_cleanup_slot()


func _test_save_after_unreadable_primary_keeps_backup() -> void:
	# A primary that cannot be parsed (content rename, disk damage) used to be
	# rotated over the backup by the next save - destroying the last good
	# generation the backup was holding. SaveSelect's "Click to create" on such a
	# slot was exactly that next save.
	_cleanup_slot()
	var first := SaveData.new()
	first.slot_index = TEST_SLOT
	first.profile_name = "recoverable"
	_save_manager.save_slot(first)
	var second := SaveData.new()
	second.slot_index = TEST_SLOT
	second.profile_name = "newest"
	_save_manager.save_slot(second)
	var file := FileAccess.open(_primary_path(), FileAccess.WRITE)
	file.store_string("not a Godot resource")
	file.close()

	var loaded: SaveData = _save_manager.load_slot(TEST_SLOT)
	_check(loaded != null and loaded.profile_name == "recoverable", "fixture: the backup serves the unreadable primary")

	var third := SaveData.new()
	third.slot_index = TEST_SLOT
	third.profile_name = "after_repair"
	_check(_save_manager.save_slot(third), "saving over an unreadable primary succeeds")
	var backup := ResourceLoader.load(_backup_path(), "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	_check(backup != null and backup.profile_name == "recoverable", "the last good generation survives as the backup")
	var primary := ResourceLoader.load(_primary_path(), "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	_check(primary != null and primary.profile_name == "after_repair", "the new save is the primary")
	_check(FileAccess.file_exists(_broken_path()), "the unreadable file is set aside as slot_N.broken.tres")

	_save_manager.delete_slot(TEST_SLOT)
	_check(not FileAccess.file_exists(_broken_path()), "delete_slot also removes the set-aside file")
	_cleanup_slot()


func _test_load_bypasses_resource_cache() -> void:
	_cleanup_slot()
	var first := SaveData.new()
	first.slot_index = TEST_SLOT
	first.profile_name = "cached"
	_save_manager.save_slot(first)
	var cached := ResourceLoader.load(_primary_path()) as SaveData
	_check(
		cached != null and cached.profile_name == "cached",
		"baseline enters resource cache"
	)
	var replacement := SaveData.new()
	replacement.slot_index = TEST_SLOT
	replacement.profile_name = "fresh"
	_check(
		ResourceSaver.save(replacement, _primary_path()) == OK,
		"disk replacement succeeds"
	)

	var loaded: SaveData = _save_manager.load_slot(TEST_SLOT)

	_check(
		loaded != null and loaded.profile_name == "fresh",
		"load_slot ignores stale resource cache"
	)
	_cleanup_slot()


func _test_delete_removes_all_slot_files() -> void:
	_cleanup_slot()
	_save_manager.ensure_dir()
	for path in [_primary_path(), _temporary_path(), _backup_path()]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("fixture")
		file.close()

	_save_manager.delete_slot(TEST_SLOT)

	_check(not FileAccess.file_exists(_primary_path()), "delete removes primary")
	_check(not FileAccess.file_exists(_temporary_path()), "delete removes temporary")
	_check(not FileAccess.file_exists(_backup_path()), "delete removes backup")
	_cleanup_slot()


func _test_meta_stash_round_trip() -> void:
	_cleanup_slot()
	var previous_stash: StashInventory = _global.meta_stash
	var stash := StashInventory.new()
	stash.set_item(0, ItemInstance.new())
	_global.meta_stash = stash
	var save := SaveData.new()
	save.slot_index = TEST_SLOT
	_global.write_save(save)

	var saved: bool = _save_manager.save_slot(save)
	var loaded: SaveData = _save_manager.load_slot(TEST_SLOT)

	_check(saved, "stash round-trip save succeeds")
	_check(
		loaded != null
		and loaded.meta_stash != null
		and loaded.meta_stash.get_at(0) != null,
		"occupied profile stash survives a disk round trip"
	)
	_global.meta_stash = previous_stash
	_cleanup_slot()


## Explainer cards are profile knowledge, like the enemy dossiers. A card that
## did not survive the round trip would be shown again on the next launch,
## forever, which is the failure mode a "seen" flag exists to prevent.
func _test_manifestation_cards_round_trip() -> void:
	_cleanup_slot()
	var previous: Array[StringName] = _global.seen_manifestation_cards.duplicate()
	_global.seen_manifestation_cards = [&"intro", &"noun:momentum"] as Array[StringName]
	var save := SaveData.new()
	save.slot_index = TEST_SLOT
	_global.write_save(save)

	var saved: bool = _save_manager.save_slot(save)
	var loaded: SaveData = _save_manager.load_slot(TEST_SLOT)

	_check(saved, "manifestation card round-trip save succeeds")
	_check(
		loaded != null and loaded.meta_seen_manifestation_cards.has("intro"),
		"a seen Manifestation card survives a disk round trip"
	)
	_check(
		loaded != null and loaded.meta_seen_manifestation_cards.has("noun:momentum"),
		"and prefixed per-noun ids survive alongside it"
	)
	_global.seen_manifestation_cards = previous
	_cleanup_slot()


func _test_active_vendor_round_trip() -> void:
	_cleanup_slot()
	var previous_active: bool = _global.attempt_active
	var previous_segment: int = _global.attempt_vendor_segment
	var previous_refreshes: int = _global.attempt_vendor_refreshes
	var previous_seed: int = _global.attempt_vendor_seed
	var previous_bag: BagInventory = _global.attempt_vendor_bag
	var bag := BagInventory.new()
	bag.debug_bag = false
	bag.set_item(0, ItemInstance.new())
	_global.attempt_active = true
	_global.attempt_vendor_segment = 4
	_global.attempt_vendor_refreshes = 3
	_global.attempt_vendor_seed = 8675309
	_global.attempt_vendor_bag = bag
	var save := SaveData.new()
	save.slot_index = TEST_SLOT
	_global.write_save(save)

	var saved: bool = _save_manager.save_slot(save)
	var loaded: SaveData = _save_manager.load_slot(TEST_SLOT)

	_check(saved, "vendor round-trip save succeeds")
	_check(
		loaded != null and loaded.attempt_vendor_segment == 4,
		"vendor segment survives a disk round trip"
	)
	_check(
		loaded != null and loaded.attempt_vendor_refreshes == 3,
		"vendor refresh count survives a disk round trip"
	)
	_check(
		loaded != null and loaded.attempt_vendor_seed == 8675309,
		"vendor seed survives a disk round trip"
	)
	_check(
		loaded != null
		and loaded.attempt_vendor_bag != null
		and loaded.attempt_vendor_bag.get_at(0) != null,
		"occupied vendor bag survives a disk round trip"
	)
	_global.attempt_active = previous_active
	_global.attempt_vendor_segment = previous_segment
	_global.attempt_vendor_refreshes = previous_refreshes
	_global.attempt_vendor_seed = previous_seed
	_global.attempt_vendor_bag = previous_bag
	_cleanup_slot()


func _test_doctrine_state_round_trip() -> void:
	var previous_active: bool = _global.attempt_active
	var previous_stage: StringName = _global.attempt_pending_doctrine_stage
	var previous_ids: Dictionary = _global.attempt_doctrine_stage_ids.duplicate(true)
	var previous_rules: Dictionary = _global.attempt_doctrine_rules.duplicate(true)
	var previous_events: Array[String] = _global.attempt_doctrine_events.duplicate()
	_global.attempt_active = true
	_global.attempt_pending_doctrine_stage = &"doctrine"
	_global.attempt_doctrine_stage_ids = {&"method": &"doctrine_method_open_circuit"}
	_global.attempt_doctrine_rules = {"max_hp_mul": 0.75}
	var recorded_events: Array[String] = ["WITNESS EXPENDED"]
	_global.attempt_doctrine_events = recorded_events
	var save := SaveData.new()
	_global.write_save(save)
	_check(save.attempt_doctrine_version == 1, "Doctrine schema version is written")
	_check(save.attempt_pending_doctrine_stage == "doctrine", "pending Doctrine stage is written")
	_check(StringName(save.attempt_doctrine_stage_ids.get(&"method", &"")) == &"doctrine_method_open_circuit", "selected stage id is written")
	_check(is_equal_approx(float(save.attempt_doctrine_rules.get("max_hp_mul", 1.0)), 0.75), "Doctrine rules are written")
	_check(save.attempt_doctrine_events == ["WITNESS EXPENDED"], "Doctrine record is written")
	_global.attempt_active = previous_active
	_global.attempt_pending_doctrine_stage = previous_stage
	_global.attempt_doctrine_stage_ids = previous_ids
	_global.attempt_doctrine_rules = previous_rules
	_global.attempt_doctrine_events = previous_events


func _test_legacy_major_choice_migration() -> void:
	var restore := SaveData.new()
	_global.write_save(restore)
	var legacy := SaveData.new()
	legacy.attempt_active = true
	legacy.attempt_major_choice_id = "major_ritual"
	legacy.attempt_major_choice_taken_ids = []
	legacy.attempt_mod_exit_hold_mul = 0.80
	legacy.attempt_doctrine_version = 0
	legacy.attempt_pending_big_choice = true
	legacy.attempt_major_choice_offer_ids = ["major_ritual", "major_satchel", "major_sanctum"]
	_global.apply_save(legacy)
	_check(_global.attempt_major_choice_taken_ids.has(&"major_ritual"), "legacy selected id enters history")
	_check(is_equal_approx(_global.attempt_exit_hold_mul, 0.80), "legacy effect remains applied")
	_check(_global.attempt_pending_doctrine_stage == &"", "migration does not queue missed stages")
	_check(not _global.pending_big_choice, "migration clears an obsolete pending legacy choice")
	_check(_global.attempt_major_choice_offer_ids.is_empty(), "migration clears disabled legacy offer ids")
	_global.apply_save(restore)


func _test_save_version_round_trip() -> void:
	# Saves carried no version of any kind: nothing could tell a pre-versioned
	# profile from a current one, or one written by a newer build.
	_cleanup_slot()
	var save := SaveData.new()
	save.slot_index = TEST_SLOT
	_check(save.save_version == 0, "a profile write_save never touched reads as pre-versioned (0)")
	_global.write_save(save)
	_check(
		save.save_version == SaveData.CURRENT_SAVE_VERSION,
		"write_save stamps the current save version (got %d)" % save.save_version
	)
	_check(
		save.game_version != "" and save.game_version == String(BuildInfoScript.version()),
		"write_save stamps the game version (got '%s')" % save.game_version
	)
	_save_manager.save_slot(save)
	var loaded: SaveData = _save_manager.load_slot(TEST_SLOT)
	_check(
		loaded != null
		and loaded.save_version == SaveData.CURRENT_SAVE_VERSION
		and loaded.game_version == save.game_version,
		"both versions survive the disk round trip"
	)

	# A profile from a newer build still applies best-effort instead of failing.
	var future := SaveData.new()
	future.slot_index = TEST_SLOT
	future.save_version = SaveData.CURRENT_SAVE_VERSION + 1
	future.game_version = "99.0.0"
	future.last_style_id = "melee"
	_global.apply_save(future)
	_check(_global.selected_style_id == "melee", "a save with a newer save_version still applies")
	_cleanup_slot()


func _test_io_failures_render_engine_error_names() -> void:
	# Logging audit 2026-08-28 §3 #13: every "err=%s" in SaveManager formatted
	# the raw enum int through str(), and the read-back validation message named
	# no path at all.
	_check(_save_manager.has_method("format_io_error"), "SaveManager renders IO failures through one formatter")
	if _save_manager.has_method("format_io_error"):
		var rendered: String = str(_save_manager.call(
			"format_io_error",
			"slot %d: write temporary save" % TEST_SLOT,
			_temporary_path(),
			ERR_FILE_CANT_OPEN
		))
		_check(rendered.contains(_temporary_path()), "a save failure names the file it could not reach")
		_check(rendered.contains(error_string(ERR_FILE_CANT_OPEN)), "and the engine's own name for the error")
		var error_field := rendered.get_slice("err=", 1)
		_check(
			error_field != "" and not error_field.is_valid_int(),
			"never the raw enum int (rendered '%s')" % error_field
		)
	# Every "err=" the file renders must be fed by error_string(), and no failure
	# path may stringify an error code with str().
	var source := FileAccess.get_file_as_string("res://autoload/SaveManager.gd")
	_check(
		source.count("error_string(") > 0 and source.count("err=%s") == source.count("error_string("),
		"every error code SaveManager renders goes through error_string()"
	)
	_check(not source.contains("str("), "no SaveManager failure path stringifies an error code with str()")
	_check(
		source.contains("read-back validation: path="),
		"the read-back validation failure names the temporary file"
	)
