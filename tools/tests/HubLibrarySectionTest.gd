extends Node
## Direct account landmarks retain physical reading, secrecy, and queued input.
const LIBRARY := preload("res://ui/screens/HubLibrary.gd")
var _passes := 0
var _failures := 0
var _library: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.save_dir = "user://saves_test_library_sections/"
	SaveManager.current_save = null
	call_deferred(&"_run")

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error("HubLibrarySectionTest: " + message)

func _frames(count: int = 3) -> void:
	for step: int in count:
		await get_tree().process_frame

func _has_property(object: Object, key: String) -> bool:
	for property: Dictionary in object.get_property_list():
		if String(property.name) == key:
			return true
	return false

func _page_sounds() -> int:
	return SfxManager.debug_requests.filter(func(request: Dictionary) -> bool: return String(request.id).begins_with("library_page_")).size()

func _click(button: Button) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await _frames(1)

func _controller_accept(button: Button) -> void:
	button.grab_focus()
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await _frames(1)

func _keyboard_accept(button: Button) -> void:
	button.grab_focus()
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await _frames(1)

func _run() -> void:
	Global.start_new_attempt()
	Global.library_note("item:beka")
	var original_motion := bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	SfxManager.debug_record = true
	SfxManager.debug_requests.clear()
	var inventory_before := Global.run_inventory.items.duplicate()
	var followers_before := Global.followers
	var rng_before := Global._rng.state
	var discoveries_before := Global.library_discoveries.duplicate()
	_library = LIBRARY.new()
	add_child(_library)
	await _frames()
	_check(_has_property(_library, "_section_index"), "each reading volume has an attached side ribbon index")
	_check(_library.has_method("_jump_to_account"), "account ribbons jump to a section's first printed leaf")
	if _library.has_method("_jump_to_account") and _has_property(_library, "_section_index"):
		await _exercise_index()
	_check(Global.run_inventory.items == inventory_before and Global.followers == followers_before, "section browsing does not change possessions or Followers")
	_check(Global._rng.state == rng_before and Global.library_discoveries == discoveries_before, "section browsing never rolls gameplay or unlocks discoveries")
	_library.call("show_shelves", false)
	_library.call("_close")
	await _frames()
	_check(not get_tree().paused, "leaving indexed reading restores gameplay")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", original_motion, false)
	SfxManager.debug_record = false
	SfxManager.debug_requests.clear()
	print("HubLibrarySectionTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _exercise_index() -> void:
	_library.call("set_filter", "Buildcraft", "")
	await _frames(5)
	var index: Control = _library.get("_section_index")
	_check(index.get_parent() == _library.get("_open_book"), "side cloth belongs to this book's physical canvas")
	_check(index.find_children("*", "ItemList", true, false).is_empty(), "sections use cloth bookmarks rather than a catalogue list")
	var shown: Array = index.call("visible_entries")
	_check(shown.size() == 5, "all five primer subjects are directly reachable")
	_check(shown.any(func(entry: Dictionary) -> bool: return entry.key == "guide:doctrine_families"), "the last guide has its own named bookmark")
	var sounds := _page_sounds()
	await _click(index.get_node("Tail4") as Button)
	_check(_library.get("_selected_key") == "guide:doctrine_families" and int(_library.get("_folio_index")) == 0, "a cloth selection skips straight to the requested guide's beginning")
	_check(_library.get("_active_category") == "Buildcraft" and _page_sounds() == sounds + 1, "one direct jump keeps the volume and plays one paper cue")
	sounds = _page_sounds()
	_library.call("_jump_to_account", "guide:doctrine_families")
	_check(_page_sounds() == sounds, "choosing the current section beginning does not fake another page turn")
	_library.call("_jump_to_account", "item:beka")
	_check(_library.get("_selected_key") == "guide:doctrine_families", "side landmarks cannot replace the current volume")
	_library.call("set_filter", "Buildcraft", "pairs")
	await _frames()
	_library.call("_jump_to_account", "guide:merges_and_imprints")
	_check(_library.get("_selected_key") == "guide:merges_and_imprints" and _library.get("_search").text.is_empty(), "a side landmark clears a restrictive find and resolves the account by identity")
	_check(int(_library.get("result_count")) == 5, "the full current volume is restored after an indexed jump")
	await _keyboard_accept(index.get_node("Tail0") as Button)
	_check(_library.get("_selected_key") == "guide:equipment_identity", "native keyboard confirmation opens the focused section")
	_library.call("_turn_page", 1)
	_library.call("_jump_to_account", "guide:equipment_identity")
	_check(int(_library.get("_folio_index")) == 0, "choosing a section from its continuation returns to that section's beginning")
	_library.call("set_filter", "Sets", "")
	await _frames()
	shown = index.call("visible_entries")
	_check(shown.size() == 3 and shown.all(func(entry: Dictionary) -> bool: return String(entry.label).contains("Sealed")), "every hidden set has a distinct sealed landmark without its name")
	var hidden_key := String(shown[2].key)
	await _controller_accept(index.get_node("Tail2") as Button)
	_check(_library.get("_selected_key") == hidden_key and _library.get("_seal").visible, "sealed landmarks open their public clue without unlocking it")
	_check(not Global.library_has(hidden_key), "opening a sealed set from its ribbon grants no discovery")
	_library.call("set_filter", "Items", "nothing matches this wording")
	await _frames()
	_check(int(_library.get("result_count")) == 0 and not index.call("visible_entries").is_empty(), "empty search keeps the book's side landmarks available")
	_library.call("_jump_to_account", "item:beka")
	_check(_library.get("_selected_key") == "item:beka" and _library.get("_icon").visible, "a known account remains reachable from an empty search")
	_library.call("set_filter", "Items", "")
	var equipment: Array = _library.get("_results")
	_library.call("_jump_to_account", String(equipment.back().key))
	_check(int(index.get("_window_start")) > 0, "the equipment fan can browse a late chapter")
	_library.call("select_book", "Recipes")
	await _frames(5)
	shown = index.call("visible_entries")
	_check(shown.any(func(entry: Dictionary) -> bool: return entry.key == _library.get("_selected_key")), "switching volumes reveals the current account rather than the previous book's ribbon bank")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	_library.call("set_filter", "Buildcraft", "")
	await _frames()
	_library.call("_jump_to_account", "guide:merges_and_imprints")
	var skin: Control = _library.get("_open_book")
	_check(float(skin.get("turn_progress")) < 1.0, "a jump turns the existing printed leaf")
	_library.call("_jump_to_account", "guide:nouns_and_pairs")
	_check(_library.get("_selected_key") == "guide:merges_and_imprints", "a rapid second landmark waits for the current leaf to land")
	await get_tree().create_timer(1.0, true).timeout
	_check(_library.get("_selected_key") == "guide:nouns_and_pairs" and int(_library.get("_folio_index")) == 0, "the queued landmark lands on the requested account's first spread")
	_check(int(skin.get("turn_direction")) == -1 and float(skin.get("turn_progress")) == 1.0, "queued navigation uses the correct backward turn and finishes")
	_library.call("_jump_to_account", "guide:augment_growth")
	_library.call("_jump_to_account", "guide:doctrine_families")
	_library.call("show_shelves", false)
	await get_tree().create_timer(0.55, true).timeout
	_check(_library.get("_shelves").visible and String(_library.get("_pending_account")).is_empty(), "putting the book away cancels a waiting section jump")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	_library.call("select_book", "Buildcraft")
	await _frames()
	_check(_library.get("_selected_key") == "guide:augment_growth", "reopening remembers the last displayed account rather than a cancelled jump")
