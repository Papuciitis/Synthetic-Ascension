extends Node

# Regression: a slot whose files exist but cannot be parsed (an item .tres
# renamed, disk damage) was shown as "EMPTY SLOT / Click to create", and the
# click created a fresh profile over it. The card must say the slot is
# unreadable, offer only Delete, and SaveSelect must refuse to create.
#
# Uses slot 97 like SaveIntegrityTest; slots 1-3 (real profiles) are only read.

const TEST_SLOT := 97
const GARBAGE := "not a Godot resource"

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


func _primary_path() -> String:
	return "user://saves/slot_%d.tres" % TEST_SLOT


func _run() -> void:
	var sm := get_node_or_null("/root/SaveManager")
	_check(sm != null, "SaveManager autoload is present")
	if sm == null:
		_finish()
		return
	sm.delete_slot(TEST_SLOT)
	sm.ensure_dir()
	var file := FileAccess.open(_primary_path(), FileAccess.WRITE)
	file.store_string(GARBAGE)
	file.close()
	_check(sm.has_save(TEST_SLOT) and sm.load_slot(TEST_SLOT) == null, "fixture: the slot exists but cannot be read")

	# --- SaveCard presentation ---
	var card_scene := load("res://ui/components/SaveCard.tscn") as PackedScene
	_check(card_scene != null, "SaveCard.tscn loads")
	if card_scene != null:
		var card := card_scene.instantiate()
		add_child(card)
		await get_tree().process_frame
		card.call("set_slot_data", TEST_SLOT, null, true)
		var name_label: Label = card.get("name_label")
		var btn_delete: Button = card.get("btn_delete")
		var btn_rename: Button = card.get("btn_rename")
		_check(name_label != null and name_label.text == "UNREADABLE SAVE", "an unreadable slot is not presented as empty (got '%s')" % (name_label.text if name_label != null else "<none>"))
		_check(btn_delete != null and not btn_delete.disabled, "delete stays available on an unreadable slot")
		_check(btn_rename != null and btn_rename.disabled, "rename is not offered on an unreadable slot")
		card.queue_free()

	# --- SaveSelect refuses to create over it ---
	var select_scene := load("res://ui/screens/SaveSelect.tscn") as PackedScene
	_check(select_scene != null, "SaveSelect.tscn loads")
	if select_scene != null:
		var select := select_scene.instantiate()
		add_child(select)
		await get_tree().process_frame
		var slot_before := int(sm.get("current_slot"))
		select.call("_on_slot_pressed", TEST_SLOT)
		_check(FileAccess.get_file_as_string(_primary_path()) == GARBAGE, "pressing an unreadable slot leaves its file untouched")
		_check(sm.load_slot(TEST_SLOT) == null, "no fresh profile was created over the unreadable slot")
		_check(int(sm.get("current_slot")) == slot_before, "the unreadable slot did not become the current profile")
		select.queue_free()

	sm.delete_slot(TEST_SLOT)
	_check(not sm.has_save(TEST_SLOT), "cleanup: deleting the slot clears it")
	_finish()


func _finish() -> void:
	print("SaveSelectUnreadableSlotTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
