extends Node
const LIBRARY := preload("res://ui/screens/HubLibrary.gd")
var _passes := 0
var _failures := 0
var _library: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error("HubLibraryPresentationTest: " + message)

func _settle() -> void:
	await get_tree().create_timer(1.65, true).timeout
	await get_tree().process_frame

func _click(button: Button) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame

func _sound_count(id: StringName) -> int:
	return SfxManager.debug_requests.filter(func(request: Dictionary) -> bool: return request["id"] == id).size()

func _run() -> void:
	SaveManager.save_dir = "user://saves_test_library_presentation/"
	SaveManager.current_save = null
	Global.start_new_attempt()
	Global.library_read_entries.clear()
	Global.library_note("item:beka")
	var user_motion: bool = SettingsManager.get_value(&"accessibility", &"reduced_motion", false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	SfxManager.debug_record = true
	SfxManager.debug_requests.clear()
	var inventory_before := Global.run_inventory.items.duplicate()
	var followers_before := Global.followers
	var rng_before := Global._rng.state
	var discoveries_before := Global.library_discoveries.duplicate()
	var grimoire_before := Global.grimoire_entries.duplicate()
	_library = LIBRARY.new()
	add_child(_library)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(get_tree().paused, "reading pauses the world")
	_check(_library.find_children("*", "ItemList", true, false).is_empty(), "the reader has no catalogue list")
	_check(_library.has_method("_pull_ribbon"), "ribbons navigate the current binding's landmarks")
	var books: Array = _library.get("_book_buttons")
	var skin: Control = _library.get("_open_book")
	_check(books.size() == 9, "nine physical volumes preserve all subjects")
	_check(skin.has_method("capture_leaf") and skin.has_method("paper_rect"), "printed paper and its turn share the real leaf")
	await _click(books[0])
	await _settle()
	_check(_library.get("_active_category") == "Buildcraft", "clicking the actual spine opens its own volume")
	_check(_sound_count(&"library_open") == 1, "book pickup requests one opening cue")
	_check(SfxManager.get("_ui").process_mode == Node.PROCESS_MODE_ALWAYS, "book audio remains active in the paused world")
	_check(String(_library.get("_selected_key")) == "guide:equipment_identity", "the primer begins with equipment")
	var folios: Array = _library.get("_folios")
	_check(folios.size() > 1, "a long account continues across real leaves")
	_check(not Global.library_read_entries.has("guide:equipment_identity"), "opening the beginning does not mark an unfinished long account read")
	var first_key := String(_library.get("_selected_key"))
	var first_text := String(_library.get("_body").text)
	_library.call("_turn_page", 1)
	_check(_library.get("_selected_key") == first_key and int(_library.get("_folio_index")) == 1, "a continuation turn stays in the same account")
	_check(String(_library.get("_body").text) != first_text, "the next leaf carries the next part of the account")
	_check(_library.get("_continuation").visible and not String(_library.get("_continuation").text).is_empty(), "later spreads continue the account on their facing left page")
	_check(int(skin.get("turn_direction")) == 1 and float(skin.get("turn_progress")) < 1, "forward paper curls in the forward direction")
	_library.call("_turn_page", -1)
	_check(int(skin.get("turn_direction")) == 1 and int(_library.get("_folio_index")) == 1, "a rapid reverse request cannot replace the leaf already in motion")
	_check(not Global.library_read_entries.has(first_key), "a final spread hidden beneath a turning leaf is not marked read early")
	_library.call("_follow_book_link", "book:Chronicles")
	_check(_library.get("_active_category") == "Buildcraft", "book links cannot interrupt the captured leaf")
	await get_tree().create_timer(0.65, true).timeout
	_check(int(skin.get("turn_direction")) == -1 and int(_library.get("_folio_index")) == 0, "turning back restores the previous leaf with opposite geometry")
	await get_tree().create_timer(0.65, true).timeout
	_library.call("_turn_page", 1)
	await get_tree().create_timer(0.65, true).timeout
	_check(Global.library_read_entries.has(first_key), "a recovered long account is marked read once its final spread lands")
	var remembered_folio := int(_library.get("_folio_index"))
	_library.call("select_book", "Recipes")
	await get_tree().create_timer(0.06, true).timeout
	_check(_library.get("_active_category") == "Buildcraft" and skin.get("cover_title") == "Buildcraft", "a subject change closes the old binding before assigning another identity")
	_library.call("select_book", "Pairs")
	_library.call("select_book", "Recipes")
	_check(_library.get("_active_category") == "Buildcraft" and skin.get("cover_title") == "Buildcraft", "repeated subject requests wait for the same old cover to close")
	await _settle()
	_check(_library.get("_active_category") == "Recipes" and int(_library.get("result_count")) > 0, "the requested volume opens after the physical swap")
	var ribbons: Array = _library.get("_ribbons")
	_check(ribbons.size() == 3, "three cloth landmarks replace subject-changing tabs")
	_library.call("_toggle_research_target")
	var target := Global.library_target_key
	_check(target != "" and not Global.library_has(target), "marking a sealed clue does not discover it")
	_check(_sound_count(&"library_bookmark") == 1, "marking a clue uses the quiet handling cue")
	_library.call("_show_entry", 1, false)
	_library.call("_pull_ribbon", "research")
	_check(_library.get("_selected_key") == target and _library.get("_active_category") == "Recipes", "the research ribbon returns to a marked account in this same volume")
	await get_tree().create_timer(0.65, true).timeout
	_library.call("select_book", "Buildcraft")
	await _settle()
	_check(_library.get("_selected_key") == first_key and int(_library.get("_folio_index")) == remembered_folio, "each binding remembers account and continuation leaf")
	var key_before := String(_library.get("_selected_key"))
	_library.call("_pull_ribbon", "research")
	_check(ribbons[2].disabled and _library.get("_active_category") == "Buildcraft" and _library.get("_selected_key") == key_before, "a thread in another volume cannot morph the current book")
	_library.call("_pull_ribbon", "beginning")
	_check(int(_library.get("_selected_index")) == 0 and int(_library.get("_folio_index")) == 0, "the first ribbon leads to the beginning of this volume")
	await get_tree().create_timer(0.65, true).timeout
	_library.call("_pull_ribbon", "unread")
	_check(_library.get("_active_category") == "Buildcraft" and String(_library.get("_selected_key")).begins_with("guide:"), "the unread ribbon only finds accounts in this volume")
	await get_tree().create_timer(0.65, true).timeout
	_library.call("_open_research_target")
	await _settle()
	_check(_library.get("_selected_key") == target and _library.get("_active_category") == "Recipes", "the shelf research shortcut explicitly opens the marked volume")
	_library.call("set_filter", "Items", "beka")
	_check(int(_library.get("result_count")) == 1 and _library.get("_icon").visible, "a known item is illustrated with its actual game asset")
	_library.call("set_filter", "Pairs", "Red Line")
	_check(int(_library.get("result_count")) == 0, "find cannot identify an undiscovered name")
	_library.call("set_filter", "Pairs", "")
	_check(_library.get("_seal").visible and not _library.get("_icon").visible, "a sealed account shows wax without a revealing illustration")
	_check(not String(_library.get("_account_text")).contains("Red Line"), "printed sealed accounts conceal actual identities and payoffs")
	_library.call("set_filter", "Buildcraft", "Shared nouns and pairs")
	_check(_library.get("_selected_key") == "guide:nouns_and_pairs" and int(_library.get("_selected_index")) == 0, "find can isolate a later known account")
	_library.call("_pull_ribbon", "beginning")
	_check(_library.get("_selected_key") == "guide:equipment_identity" and int(_library.get("_selected_index")) == 0, "Beginning remaps a filtered account by identity before returning to the full volume")
	await get_tree().create_timer(0.65, true).timeout
	_library.call("set_filter", "Items", "nothing matches this phrase")
	_check(int(_library.get("result_count")) == 0 and _library.get("_next_page").disabled, "empty find has no false turn target")
	_library.call("set_filter", "Buildcraft", "")
	_library.call("_show_entry", 0, false)
	await get_tree().process_frame
	var down := InputEventKey.new()
	down.keycode = KEY_PAGEDOWN
	down.pressed = true
	_library.call("_input", down)
	_check(int(_library.get("_folio_index")) == 1, "Page Down turns an actual continuation leaf")
	await get_tree().create_timer(0.65, true).timeout
	_library.call("_pull_ribbon", "beginning")
	await get_tree().create_timer(0.65, true).timeout
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_Y
	stick.axis_value = 1
	_library.call("_input", stick)
	await get_tree().create_timer(0.1, true).timeout
	_check(int(_library.get("_folio_index")) == 1, "controller reading input turns the next leaf")
	stick.axis_value = 0
	_library.call("_input", stick)
	var stopped_folio := int(_library.get("_folio_index"))
	await get_tree().create_timer(0.8, true).timeout
	_check(int(_library.get("_folio_index")) == stopped_folio, "releasing the stick stops leaf navigation")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	_library.call("select_book", "Chronicles")
	_library.call("_turn_page", 1)
	_check(is_equal_approx(float(skin.get("open_progress")), 1) and is_equal_approx(float(skin.get("turn_progress")), 1), "Reduced Motion immediately presents the cover and leaf")
	_library.call("_show_entry", 0, false)
	var sounds_before := SfxManager.debug_requests.size()
	_library.call("_turn_page", -1)
	_check(SfxManager.debug_requests.size() == sounds_before, "a book boundary makes no false handling sound")
	var cancel := InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	cancel.pressed = true
	_library.call("_input", cancel)
	_check(_library.get("_shelves").visible and not bool(_library.get("_closing")), "Back puts a volume on the shelves before leaving")
	_check(books[8].has_focus(), "the shelf restores focus to the volume just read")
	for id: StringName in [&"library_open", &"library_close", &"library_page_1", &"library_page_2", &"library_page_3", &"library_bookmark"]:
		var definition: Variant = SfxManager.get("_defs").get(id)
		_check(definition != null and definition.stream != null and definition.bus == &"UI", "cue %s loads on the existing UI bus" % id)
	_check(Global.run_inventory.items == inventory_before and Global.followers == followers_before, "reading never changes possessions or Followers")
	_check(Global._rng.state == rng_before, "physical reading never consumes gameplay RNG")
	_check(Global.library_discoveries == discoveries_before and Global.grimoire_entries == grimoire_before, "ribbons and reading never award discoveries")
	_library.call("_close")
	await get_tree().process_frame
	_check(not get_tree().paused, "leaving restores the running world")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", user_motion, false)
	SfxManager.debug_record = false
	SfxManager.debug_requests.clear()
	print("HubLibraryPresentationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
