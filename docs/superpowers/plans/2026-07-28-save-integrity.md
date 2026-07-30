# Save Integrity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve the profile stash and active vendor snapshot across restarts while making each save-slot write recoverable and immune to stale Godot resource-cache reads.

**Architecture:** Keep `SaveData` as the existing persistence schema. Extend `Global.write_save()` to populate fields already restored by `Global.apply_save()`, then make `SaveManager` own a three-file transaction consisting of a primary, temporary, and retained backup resource. Validate temporary and loaded resources through uncached `ResourceLoader` calls.

**Tech Stack:** Godot 4.7.1, GDScript, Godot `ResourceSaver`, `ResourceLoader`, `DirAccess`, and a headless `SceneTree` regression runner.

## Global Constraints

- Developer Mode and `DevSetCollisionTools` must remain unchanged.
- No new save-schema fields or migrations.
- Older saves with absent stash or vendor fields must continue using current defaults.
- Tests must use an isolated `GODOT_USER_HOME` and never access normal player saves.
- Every production change must be preceded by a regression test that fails for the expected missing behavior.

---

## File Structure

- `autoload/global.gd`: Copy profile stash and active vendor state into `SaveData`.
- `autoload/SaveManager.gd`: Implement uncached loading, backup recovery, validated temporary saves, and complete slot deletion.
- `tools/tests/SaveIntegrityTest.gd`: Headless regression runner for serialization and disk transaction behavior.

### Task 1: Serialize Profile Stash and Active Vendor State

**Files:**

- Create: `tools/tests/SaveIntegrityTest.gd`
- Modify: `autoload/global.gd`

**Interfaces:**

- Consumes: Existing `Global.write_save(save: SaveData) -> void` and `Global.apply_save(save: SaveData) -> void`.
- Produces: `write_save` assignments to `SaveData.meta_stash`, `attempt_vendor_segment`, `attempt_vendor_refreshes`, `attempt_vendor_seed`, and `attempt_vendor_bag`.

- [ ] **Step 1: Create the headless test runner and failing serialization tests**

Create `tools/tests/SaveIntegrityTest.gd` with a `SceneTree` runner, an assertion counter, cleanup helpers, and these two tests:

```gdscript
extends SceneTree

const TEST_SLOT := 97
var _failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_write_save_copies_meta_stash()
	_test_write_save_copies_active_vendor_snapshot()
	await process_frame
	quit(1 if _failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _test_write_save_copies_meta_stash() -> void:
	var previous_stash := Global.meta_stash
	var stash := StashInventory.new()
	var marker := ItemInstance.new()
	stash.set_item(0, marker)
	Global.meta_stash = stash
	var save := SaveData.new()

	Global.write_save(save)

	_check(save.meta_stash == stash, "write_save copies the profile stash")
	_check(save.meta_stash.get_at(0) == marker, "copied stash retains its occupied slot")
	Global.meta_stash = previous_stash

func _test_write_save_copies_active_vendor_snapshot() -> void:
	var previous_active := Global.attempt_active
	var previous_segment := Global.attempt_vendor_segment
	var previous_refreshes := Global.attempt_vendor_refreshes
	var previous_seed := Global.attempt_vendor_seed
	var previous_bag := Global.attempt_vendor_bag
	var bag := BagInventory.new()
	bag.debug_bag = false
	Global.attempt_active = true
	Global.attempt_vendor_segment = 4
	Global.attempt_vendor_refreshes = 3
	Global.attempt_vendor_seed = 8675309
	Global.attempt_vendor_bag = bag
	var save := SaveData.new()

	Global.write_save(save)

	_check(save.attempt_vendor_segment == 4, "write_save copies vendor segment")
	_check(save.attempt_vendor_refreshes == 3, "write_save copies vendor refresh count")
	_check(save.attempt_vendor_seed == 8675309, "write_save copies vendor seed")
	_check(save.attempt_vendor_bag == bag, "write_save copies vendor bag")
	Global.attempt_active = previous_active
	Global.attempt_vendor_segment = previous_segment
	Global.attempt_vendor_refreshes = previous_refreshes
	Global.attempt_vendor_seed = previous_seed
	Global.attempt_vendor_bag = previous_bag
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```powershell
$env:GODOT_USER_HOME="$PWD\.test-user-save-integrity"
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tools/tests/SaveIntegrityTest.gd
```

Expected: exit code `1`; stash and all four active-vendor assertions report `FAIL` because `Global.write_save()` does not assign them.

- [ ] **Step 3: Add the minimal serialization assignments**

In `autoload/global.gd`, add the profile assignment next to other meta fields:

```gdscript
save.meta_stash = meta_stash
```

Inside the `if attempt_active:` branch, after saving `attempt_bag`, add:

```gdscript
save.attempt_vendor_segment = attempt_vendor_segment
save.attempt_vendor_refreshes = attempt_vendor_refreshes
save.attempt_vendor_seed = attempt_vendor_seed
save.attempt_vendor_bag = attempt_vendor_bag
```

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run the same isolated headless command.

Expected: exit code `0`; all stash and active-vendor assertions report `PASS`.

### Task 2: Add Uncached Loading and Recoverable Save Transactions

**Files:**

- Modify: `tools/tests/SaveIntegrityTest.gd`
- Modify: `autoload/SaveManager.gd`

**Interfaces:**

- Consumes: Existing `SaveManager.load_slot(slot: int) -> SaveData`, `save_slot(save: SaveData)`, `has_save(slot: int) -> bool`, and `delete_slot(slot: int) -> void`.
- Produces: `_temporary_path(slot: int) -> String`, `_backup_path(slot: int) -> String`, `_load_save_data(path: String) -> SaveData`, and `save_slot(save: SaveData) -> bool`.

- [ ] **Step 1: Add failing disk-transaction tests**

Extend `_run()` to call:

```gdscript
_test_second_save_keeps_previous_backup()
_test_load_recovers_from_corrupt_primary()
_test_load_bypasses_resource_cache()
_test_delete_removes_all_slot_files()
```

Add helpers that construct paths under `user://saves/`, remove only `TEST_SLOT` artifacts before and after each test, and load text through `FileAccess`. Add tests with these exact behaviors:

```gdscript
func _test_second_save_keeps_previous_backup() -> void:
	_cleanup_slot()
	var first := SaveData.new()
	first.slot_index = TEST_SLOT
	first.profile_name = "first"
	_check(SaveManager.save_slot(first), "first save succeeds")
	var second := SaveData.new()
	second.slot_index = TEST_SLOT
	second.profile_name = "second"
	_check(SaveManager.save_slot(second), "second save succeeds")
	var primary := ResourceLoader.load(_primary_path(), "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	var backup := ResourceLoader.load(_backup_path(), "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	_check(primary != null and primary.profile_name == "second", "primary contains newest generation")
	_check(backup != null and backup.profile_name == "first", "backup contains previous generation")
	_cleanup_slot()

func _test_load_recovers_from_corrupt_primary() -> void:
	_cleanup_slot()
	var first := SaveData.new()
	first.slot_index = TEST_SLOT
	first.profile_name = "recoverable"
	_check(SaveManager.save_slot(first), "recovery baseline save succeeds")
	var second := SaveData.new()
	second.slot_index = TEST_SLOT
	second.profile_name = "newest"
	_check(SaveManager.save_slot(second), "recovery backup generation is created")
	var file := FileAccess.open(_primary_path(), FileAccess.WRITE)
	file.store_string("not a Godot resource")
	file.close()
	var loaded := SaveManager.load_slot(TEST_SLOT)
	_check(loaded != null and loaded.profile_name == "recoverable", "invalid primary falls back to valid backup")
	_cleanup_slot()

func _test_load_bypasses_resource_cache() -> void:
	_cleanup_slot()
	var first := SaveData.new()
	first.slot_index = TEST_SLOT
	first.profile_name = "cached"
	_check(SaveManager.save_slot(first), "cache baseline save succeeds")
	var cached := ResourceLoader.load(_primary_path()) as SaveData
	_check(cached != null and cached.profile_name == "cached", "baseline enters resource cache")
	var replacement := SaveData.new()
	replacement.slot_index = TEST_SLOT
	replacement.profile_name = "fresh"
	_check(ResourceSaver.save(replacement, _primary_path()) == OK, "disk replacement succeeds")
	var loaded := SaveManager.load_slot(TEST_SLOT)
	_check(loaded != null and loaded.profile_name == "fresh", "load_slot ignores stale resource cache")
	_cleanup_slot()

func _test_delete_removes_all_slot_files() -> void:
	_cleanup_slot()
	for path in [_primary_path(), _temporary_path(), _backup_path()]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("fixture")
		file.close()
	SaveManager.delete_slot(TEST_SLOT)
	_check(not FileAccess.file_exists(_primary_path()), "delete removes primary")
	_check(not FileAccess.file_exists(_temporary_path()), "delete removes temporary")
	_check(not FileAccess.file_exists(_backup_path()), "delete removes backup")
```

- [ ] **Step 2: Run the suite and verify RED**

Run the isolated headless command from Task 1.

Expected: the suite exits `1`. The backup, corrupted-primary recovery, uncached-load, and complete-deletion assertions fail under the direct-write implementation.

- [ ] **Step 3: Add slot path and uncached typed-load helpers**

In `autoload/SaveManager.gd`, add:

```gdscript
func _temporary_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.tmp.tres" % slot

func _backup_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.bak.tres" % slot

func _load_save_data(path: String) -> SaveData:
	if not FileAccess.file_exists(path):
		return null
	var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	return resource as SaveData
```

Change `load_slot` to return a valid primary, otherwise a valid backup:

```gdscript
func load_slot(slot: int) -> SaveData:
	if not ensure_dir():
		return null
	var primary := _load_save_data(_slot_path(slot))
	if primary != null:
		return primary
	return _load_save_data(_backup_path(slot))
```

Change `has_save` to check both primary and backup.

- [ ] **Step 4: Implement the validated temporary/backup transaction**

Change `save_slot` to return `bool`. Its exact transaction must:

1. Save to `_temporary_path(slot)`.
2. Uncached-load and type-check the temporary resource.
3. Remove an existing backup and check the error.
4. Rename an existing primary to backup and check the error.
5. Rename temporary to primary and check the error.
6. Restore backup to primary if step 5 fails.
7. Return `true` only after the primary replacement succeeds.

Use `DirAccess.remove_absolute(ProjectSettings.globalize_path(path))` and `DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))` so every filesystem operation uses an absolute OS path.

- [ ] **Step 5: Expand slot deletion**

Replace the single-primary removal with a loop over:

```gdscript
[_slot_path(slot), _temporary_path(slot), _backup_path(slot)]
```

Globalize each path before `DirAccess.remove_absolute`.

- [ ] **Step 6: Run the suite and verify GREEN**

Run the isolated headless command.

Expected: exit code `0`; serialization, backup generation, recovery, cache bypass, and deletion assertions all report `PASS`.

### Task 3: Verify Round Trips and Project Health

**Files:**

- Modify: `tools/tests/SaveIntegrityTest.gd`

**Interfaces:**

- Consumes: Completed `Global` serialization and `SaveManager` transaction behavior.
- Produces: End-to-end disk round-trip regression coverage.

- [ ] **Step 1: Add end-to-end stash and vendor round-trip tests**

Add tests that:

1. Populate a stash with an `ItemInstance`, call `Global.write_save`, `SaveManager.save_slot`, and `SaveManager.load_slot`, then assert the loaded stash slot is occupied.
2. Populate an active vendor bag with an `ItemInstance`, set segment `4`, refreshes `3`, and seed `8675309`, then perform the same disk round trip and assert all fields and the occupied vendor slot survive.

Restore all mutated `Global` fields and clean the test slot in each test.

- [ ] **Step 2: Prove the new tests detect missing serialization**

Temporarily remove only the five new `Global.write_save` assignments, run the isolated headless suite, and confirm the two end-to-end tests fail for missing stash/vendor state. Restore the assignments immediately.

Expected: exit code `1` while assignments are absent, with failures naming the lost stash and vendor fields.

- [ ] **Step 3: Run the complete save-integrity suite**

Run:

```powershell
$env:GODOT_USER_HOME="$PWD\.test-user-save-integrity"
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tools/tests/SaveIntegrityTest.gd
```

Expected: exit code `0`, no failed assertions, and no parser errors.

- [ ] **Step 4: Run the project headless smoke check**

Run:

```powershell
$env:GODOT_USER_HOME="$PWD\.test-user-save-integrity"
& 'C:\Users\NaurisKrišjānis\Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --editor --quit
```

Expected: exit code `0` with no GDScript parse errors.

- [ ] **Step 5: Review the final change scope**

Confirm the modified production files are only:

- `autoload/global.gd`
- `autoload/SaveManager.gd`

Confirm `autoload/DevSetCollisionTools.gd` and Developer Mode configuration are unchanged.

- [ ] **Step 6: Record verification evidence**

Report the exact test and smoke-check exit codes, the number of passed assertions, any Godot warnings that remain, and the fact that the folder has no Git repository so no commit was created.

