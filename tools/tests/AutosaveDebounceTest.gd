extends Node

# Kill-path autosaves used to serialize, write, and re-validate the profile on
# a 0.6 s debounce during combat. They must instead mark the profile dirty and
# defer the disk write to a safe point (flush/scene change) or a long fallback.

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


func _run() -> void:
	_check("current_save" in SaveManager, "save manager exposes the active save")
	var previous_save: Variant = SaveManager.current_save
	var test_save := SaveData.new()
	test_save.slot_index = 97
	SaveManager.current_save = test_save

	_check("debug_save_writes" in SaveManager, "save manager counts disk writes for diagnostics")
	if not ("debug_save_writes" in SaveManager) or not Global.has_method("flush_pending_save"):
		_check(false, "pending-save flush contract is not implemented yet")
		SaveManager.current_save = previous_save
		print("AutosaveDebounceTest: %d passed, %d failed" % [_passes, _failures])
		get_tree().quit(1)
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

	SaveManager.current_save = previous_save
	print("AutosaveDebounceTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
