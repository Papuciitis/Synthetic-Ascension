extends Node

const TEST_SLOT: int = 97

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
	_test_load_bypasses_resource_cache()
	_test_delete_removes_all_slot_files()
	_test_meta_stash_round_trip()
	_test_active_vendor_round_trip()
	_test_manifestation_cards_round_trip()
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


func _cleanup_slot() -> void:
	for path in [_primary_path(), _temporary_path(), _backup_path()]:
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
