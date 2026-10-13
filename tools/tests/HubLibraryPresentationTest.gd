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


func _run() -> void:
	SaveManager.save_dir = "user://saves_test_library_presentation/"
	SaveManager.current_save = null
	Global.start_new_attempt()
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
		library.call("select_book", "Buildcraft")
		_check(int(library.get("result_count")) >= 5, "Buildcraft provides useful starter pages")
		library.call("set_filter", "Items", "nothing matches this phrase")
		_check(int(library.get("result_count")) == 0, "empty search has no misleading page")
		library.call("show_shelves")
		_check(bool(library.find_child("LibraryShelves", true, false).visible), "return reveals the subject books")
		if not library.ChamberKit.reduced():
			_check(bool(library.find_child("BookReader", true, false).visible), "a book closes before the reader disappears")
		await get_tree().create_timer(0.4, true).timeout
		library.call("select_book", "Recipes")
		_check(int(library.get("result_count")) > 0, "the recipes book has discovery goals")
		var skin: Control = library.find_child("OpenBook", true, false)
		_check(skin.find_child("PageTurnLeaf", true, false) != null, "turning paper passes over the page text")
		library.call("_toggle_research_target")
		var target := Global.library_target_key
		_check(target != "" and not Global.library_has(target), "bookmarking a locked recipe does not discover it")
		library.call("_turn_page", 1)
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
	_check(Global.run_inventory.items == inventory_before and Global.followers == followers_before, "reading does not change possessions or Followers")
	_check(Global._rng.state == rng_before, "reading consumes no gameplay RNG")
	_check(Global.library_discoveries == discoveries_before and Global.grimoire_entries == grimoire_before, "reading and bookmarking do not award knowledge")
	library.call("_close")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", user_motion_setting, false)
	await get_tree().process_frame
	_check(not get_tree().paused, "closing restores the running world")
	print("HubLibraryPresentationTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
