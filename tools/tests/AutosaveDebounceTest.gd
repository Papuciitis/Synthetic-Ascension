extends Node

# Kill-path autosaves used to serialize, write, and re-validate the profile on
# a 0.6 s debounce during combat. They must instead mark the profile dirty and
# defer the disk write to a safe point (flush/scene change) or a long fallback.
#
# The writes below are real disk writes, so this suite owns a scratch slot of
# its own and deletes it on every exit path. Slot 97 belongs to
# SaveIntegrityTest and SaveSelectUnreadableSlotTest, which both clear it on
# entry; sharing it made this suite's leftover file visible only when it
# happened to run last in a sweep.
const TEST_SLOT := 96

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _slot_paths() -> Array[String]:
	return [
		"user://saves/slot_%d.tres" % TEST_SLOT,
		"user://saves/slot_%d.tmp.tres" % TEST_SLOT,
		"user://saves/slot_%d.bak.tres" % TEST_SLOT,
		"user://saves/slot_%d.broken.tres" % TEST_SLOT,
	]


func _leftover_artifacts() -> Array[String]:
	var found: Array[String] = []
	for path in _slot_paths():
		if FileAccess.file_exists(path):
			found.append(path)
	return found


func _finish(previous_save: Variant) -> void:
	SaveManager.current_save = previous_save
	# The point of the cleanup: a headless run of this suite must not leave a
	# profile behind on the developer's machine.
	SaveManager.delete_slot(TEST_SLOT)
	var leftovers := _leftover_artifacts()
	_check(
		leftovers.is_empty(),
		"the suite deletes the save artifacts it wrote (%s)" % ", ".join(leftovers)
	)
	print("AutosaveDebounceTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _run() -> void:
	_check("current_save" in SaveManager, "save manager exposes the active save")
	var previous_save: Variant = SaveManager.current_save
	# Start from a clean scratch slot so a leftover from an aborted earlier run
	# cannot make the closing cleanup check pass or fail for the wrong reason.
	SaveManager.delete_slot(TEST_SLOT)
	var test_save := SaveData.new()
	test_save.slot_index = TEST_SLOT
	SaveManager.current_save = test_save

	_check("debug_save_writes" in SaveManager, "save manager counts disk writes for diagnostics")
	if not ("debug_save_writes" in SaveManager) or not Global.has_method("flush_pending_save"):
		_check(false, "pending-save flush contract is not implemented yet")
		_finish(previous_save)
		return
	var writes_before := int(SaveManager.get("debug_save_writes"))

	Global.request_autosave()
	await get_tree().create_timer(1.2).timeout
	_check(
		int(SaveManager.get("debug_save_writes")) == writes_before,
		"combat autosave request does not write to disk on a sub-second debounce"
	)

	_check(Global.has_method("flush_pending_save"), "global exposes a pending-save flush for safe points")
	if Global.has_method("flush_pending_save"):
		Global.call("flush_pending_save")
		_check(
			int(SaveManager.get("debug_save_writes")) == writes_before + 1,
			"flushing a dirty profile writes exactly once"
		)
		_check(
			SaveManager.get("debug_last_save_validated") == false,
			"autosave flush skips the synchronous read-back validation"
		)
		_check(
			Global.get("_autosave_timer") == null,
			"autosave flush releases the pending SceneTreeTimer callback"
		)
		Global.call("flush_pending_save")
		_check(
			int(SaveManager.get("debug_save_writes")) == writes_before + 1,
			"flushing a clean profile is a no-op"
		)

	# Direct saves stay validated and clear any pending autosave.
	Global.request_autosave()
	Global.save_current_profile()
	_check(
		SaveManager.get("debug_last_save_validated") == true,
		"manual saves keep the synchronous read-back validation"
	)
	_check(
		Global.get("_autosave_timer") == null,
		"manual saves also release the pending SceneTreeTimer callback"
	)
	if Global.has_method("flush_pending_save"):
		var writes_after_manual := int(SaveManager.get("debug_save_writes"))
		Global.call("flush_pending_save")
		_check(
			int(SaveManager.get("debug_save_writes")) == writes_after_manual,
			"a direct save clears the pending autosave"
		)

	# Proof the cleanup below has something to clean: these were real writes.
	_check(
		not _leftover_artifacts().is_empty(),
		"the suite really wrote slot %d to disk" % TEST_SLOT
	)
	_finish(previous_save)
