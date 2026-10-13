extends Node

const LIBRARY := preload("res://ui/screens/HubLibrary.gd")
var _passes := 0
var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error("HubLibraryPresentationTest: " + message)


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
	SfxManager.debug_record = true
	SfxManager.debug_requests.clear()
	var user_motion_setting := bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	var inventory_before: Array = Global.run_inventory.items.duplicate()
	var followers_before: int = Global.followers
	var rng_before: int = Global._rng.state
	var discoveries_before := Global.library_discoveries.duplicate()
	var grimoire_before := Global.grimoire_entries.duplicate()
	var library: Node = LIBRARY.new()
	add_child(library)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(library.find_child("LibraryShelves", true, false) != null, "the Alcove presents physical shelves")
	_check(library.find_child("OpenBook", true, false) != null, "the reader is an open book")
	_check(library.find_child("ResearchTarget", true, false) != null, "a research bookmark is available")
	_check(library.has_method("select_book"), "subject spines have a book navigation action")
	_check(library.has_method("show_shelves"), "readers can return to the shelves")
	_check(get_tree().paused, "reading pauses the world")
	if library.has_method("select_book"):
		var books: Array = library.get("_book_buttons")
		_check(books.size() == 9, "nine labelled volumes cover builds, discoveries and lore")
		await _click(books[0])
		_check(bool(library.find_child("BookReader", true, false).visible), "clicking the actual spine opens its book")
		_check(_sound_count(&"library_open") == 1, "opening a physical book requests its handling sound")
		_check(SfxManager.get("_ui").process_mode == Node.PROCESS_MODE_ALWAYS, "book sounds keep playing while reading pauses the world")
		library.call("select_book", "Buildcraft")
		_check(int(library.get("result_count")) >= 5, "Buildcraft provides useful starter pages")
		library.call("_turn_page", 1)
		var remembered := String(library.get("_selected_key"))
		library.call("select_book", "Pairs")
		library.call("select_book", "Buildcraft")
		_check(String(library.get("_selected_key")) == remembered, "each volume remembers its own reading place")
		library.call("set_filter", "Items", "nothing matches this phrase")
		_check(int(library.get("result_count")) == 0, "empty search has no misleading page")
		library.call("show_shelves")
		_check(bool(library.find_child("LibraryShelves", true, false).visible), "return reveals the subject books")
		if not library.ChamberKit.reduced():
			_check(bool(library.find_child("BookReader", true, false).visible), "a book closes before the reader disappears")
		await get_tree().create_timer(0.4, true).timeout
		library.call("select_book", "Recipes")
		_check(int(library.get("result_count")) > 0, "the recipes book has discovery goals")
		var cancel := InputEventJoypadButton.new()
		cancel.button_index = JOY_BUTTON_B
		cancel.pressed = true
		library.call("_input", cancel)
		await get_tree().create_timer(0.3, true).timeout
		if not is_instance_valid(library):
			_check(false, "controller Back puts the book on the shelf without leaving the Alcove")
			SettingsManager.set_value(&"accessibility", &"reduced_motion", user_motion_setting, false)
			print("HubLibraryPresentationTest: %d passed, %d failed" % [_passes, _failures])
			get_tree().quit(1)
			return
		_check(not bool(library.get("_closing")) and bool(library.find_child("LibraryShelves", true, false).visible), "controller Back puts the book on the shelf without leaving the Alcove")
		_check(books[7].has_focus(), "returning to the shelf focuses the book just read")
		library.call("select_book", "Recipes")
		var skin: Control = library.find_child("OpenBook", true, false)
		_check(skin.find_child("PageTurnLeaf", true, false) != null, "turning paper passes over the page text")
		library.call("_toggle_research_target")
		_check(_sound_count(&"library_bookmark") == 1, "bookmarking a clue requests a soft handling sound")
		var target := Global.library_target_key
		_check(target != "" and not Global.library_has(target), "bookmarking a locked recipe does not discover it")
		library.call("_turn_page", 1)
		_check(_sound_count(&"library_page_1") + _sound_count(&"library_page_2") + _sound_count(&"library_page_3") >= 2, "turns use the recorded paper variants")
		_check(String(library.get("_selected_key")) != target, "the page turn advances the selected entry")
		if not library.ChamberKit.reduced():
			_check(float(skin.get("turn_progress")) < 1.0, "changing pages animates a turning leaf")
		library.call("_open_research_target")
		_check(library.get("_selected_key") == target, "the research bookmark returns to the exact clue")
		SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
		library.call("select_book", "Buildcraft")
		library.call("_turn_page", 1)
		_check(skin.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(float(skin.get("turn_progress")), 1.0), "Reduced Motion presents open and turned pages immediately")
		library.call("_follow_book_link", "book:Pairs")
		_check(int(library.get("result_count")) == ManifestationPairCatalog.all_ids().size(), "guide book links navigate to the selected live subject")
		library.call("select_book", "Buildcraft")
		await get_tree().process_frame
		await get_tree().process_frame
		var body: RichTextLabel = library.get("_body")
		var scroll := body.get_v_scroll_bar()
		var controller_scroll := InputEventJoypadMotion.new()
		controller_scroll.axis = JOY_AXIS_RIGHT_Y
		controller_scroll.axis_value = 1.0
		library.call("_input", controller_scroll)
		await get_tree().create_timer(0.15, true).timeout
		_check(scroll.value > 0.0, "the controller right stick scrolls long book text")
		controller_scroll.axis_value = 0.0
		library.call("_input", controller_scroll)
		var stopped_value := scroll.value
		await get_tree().create_timer(0.1, true).timeout
		_check(is_equal_approx(scroll.value, stopped_value), "releasing the right stick stops reading scroll")
		scroll.value = 0.0
		var page_down := InputEventKey.new()
		page_down.keycode = KEY_PAGEDOWN
		page_down.pressed = true
		library.call("_input", page_down)
		_check(scroll.value > 0.0, "keyboard Page Down scrolls the selected book page")
		library.call("select_book", "Chronicles")
		library.call("_turn_page", -1)
		var sounds_before := SfxManager.debug_requests.size()
		library.call("_turn_page", -1)
		_check(SfxManager.debug_requests.size() == sounds_before, "a page boundary does not play a false paper turn")
	for id: StringName in [&"library_open", &"library_close", &"library_page_1", &"library_page_2", &"library_page_3", &"library_bookmark"]:
		var definition: Variant = SfxManager.get("_defs").get(id)
		_check(definition != null and definition.stream != null and definition.stream.get_length() > 0.05 and definition.bus == &"UI", "library cue %s loads a short stream on the existing UI bus" % id)
	_check(Global.run_inventory.items == inventory_before and Global.followers == followers_before, "reading does not change possessions or Followers")
	_check(Global._rng.state == rng_before, "reading consumes no gameplay RNG")
	_check(Global.library_discoveries == discoveries_before and Global.grimoire_entries == grimoire_before, "reading and bookmarking do not award knowledge")
	library.call("_close")
	SfxManager.debug_record = false
	SfxManager.debug_requests.clear()
	SettingsManager.set_value(&"accessibility", &"reduced_motion", user_motion_setting, false)
	await get_tree().process_frame
	_check(not get_tree().paused, "closing restores the running world")
	print("HubLibraryPresentationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
