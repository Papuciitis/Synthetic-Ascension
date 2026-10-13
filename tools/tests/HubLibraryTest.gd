extends Node

const HUB_WORLD := preload("res://scenes/hub/HubWorld.tscn")
const LIBRARY_DATA := preload("res://ui/screens/HubLibraryData.gd")

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
		push_error("HubLibraryTest: " + message)


func _click(button: Button) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame


func _confirm(use_controller: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event: InputEvent
		if use_controller:
			var controller := InputEventJoypadButton.new()
			controller.button_index = JOY_BUTTON_A
			controller.pressed = pressed
			event = controller
		else:
			var key := InputEventKey.new()
			key.keycode = KEY_ENTER
			key.physical_keycode = KEY_ENTER
			key.pressed = pressed
			event = key
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	await get_tree().process_frame


func _run() -> void:
	if DisplayServer.get_name() != "headless":
		get_tree().root.mode = Window.MODE_WINDOWED
		get_tree().root.size = Vector2i(1280, 720)
		get_tree().root.grab_focus()
	# Hub entry saves: keep every write away from the player's profile slots.
	SaveManager.save_dir = "user://saves_test_hub_library/"
	SaveManager.current_save = SaveData.new()
	SaveManager.current_save.slot_index = 98
	Global.selected_style_id = "ranged"
	Global.start_new_attempt()
	Global.pending_big_choice = false
	StoryDirector.cards_override = 0
	# The catalogue now has sealed pages; seed earned knowledge for the search regression.
	Global.library_note("item:beka")
	for entry: Dictionary in LIBRARY_DATA.build_entries():
		if entry["category"] == "Enemies":
			Global.library_note(String(entry["key"]))
	var inventory_before: Array = Global.run_inventory.items.duplicate()
	var rng_before := Global._rng.state
	var followers_before := Global.followers
	var segment_before := Global.attempt_segment
	var entries: Array[Dictionary] = LIBRARY_DATA.build_entries()
	for category: String in LIBRARY_DATA.CATEGORIES:
		_check(not LIBRARY_DATA.filter_entries(entries, category, "").is_empty(), category + " contains live catalog entries")
	_check(LIBRARY_DATA.filter_entries(entries, "Manifestations", "").size() == ManifestationCatalog.all_ids().size(), "each manifestation has a known or sealed page")
	_check(LIBRARY_DATA.filter_entries(entries, "Pairs", "").size() == ManifestationPairCatalog.all_ids().size(), "each pair has a known or sealed page")
	var beka_results: Array[Dictionary] = LIBRARY_DATA.filter_entries(entries, "Items", "  BEKA  ")
	_check(beka_results.size() == 1 and beka_results[0]["id"] == "beka", "search trims whitespace and ignores case")
	_check(not LIBRARY_DATA.filter_entries(entries, "Enemies", "wind-up").is_empty(), "search includes enemy advice, not just names")
	_check(LIBRARY_DATA.filter_entries(entries, "Items", "nothing matches this phrase").is_empty(), "an unmatched search returns no results")
	_check(Global.run_inventory.items == inventory_before and Global.followers == followers_before, "building the reference never changes equipment or Followers")
	_check(Global._rng.state == rng_before, "building item previews never consumes the attempt RNG")
	var stats := StatDelta.new()
	stats.power = 0.05
	stats.haste = -0.1
	stats.luck = 0.07
	stats.max_hp = 12.0
	var formatted: String = LIBRARY_DATA._stats(stats)
	_check(formatted.contains("Power: +5%") and formatted.contains("Haste: -10%") and formatted.contains("Luck: +7%") and formatted.contains("Health: +12"), "stat reference uses game units and percentages")
	for entry: Dictionary in entries:
		_check(not String(entry["body"]).strip_edges().is_empty(), "entry has readable details: " + String(entry["id"]))

	var hub: HubWorld = HUB_WORLD.instantiate()
	hub.departure_scene_change_enabled = false
	hub.crowd_seed = 7
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame
	var camera := hub._player.get_node("Camera2D") as Camera2D
	var initial_position := hub._player.global_position
	var initial_zoom := camera.zoom
	hub.set_hub_zoom(100.0)
	_check(is_equal_approx(hub.hub_zoom, HubWorld.HUB_ZOOM_MAX), "zoom is bounded at the upper limit")
	hub.set_hub_zoom(-100.0)
	_check(is_equal_approx(hub.hub_zoom, HubWorld.HUB_ZOOM_MIN), "zoom is bounded at the lower limit")
	hub.set_hub_zoom(2.0)
	_check(camera.zoom.is_equal_approx(initial_zoom * 2.0), "zoom changes the world camera")
	_check(hub._zoom_controls.get_parent() is CanvasLayer, "zoom controls stay in screen space")
	var wheel_over_controls := InputEventMouseButton.new()
	wheel_over_controls.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_over_controls.pressed = true
	wheel_over_controls.position = hub._zoom_controls.get_global_rect().get_center()
	hub._unhandled_input(wheel_over_controls)
	_check(is_equal_approx(hub.hub_zoom, 2.0), "wheel events over camera buttons cannot zoom the world")
	hub._toggle_beka_view()
	hub._process(0.0)
	_check(hub._beka_view and camera.global_position.is_equal_approx(hub.crowd.beka.global_position), "Beka view follows the actual Beka")
	_check(hub._player.global_position.is_equal_approx(initial_position), "viewing Beka never moves the player")
	hub._reset_hub_view()
	_check(not hub._beka_view and camera.position == Vector2.ZERO and camera.zoom.is_equal_approx(initial_zoom), "reset returns to the player at default zoom")
	var alcove: HubStation = null
	for station: HubStation in hub._stations:
		if station.station_name == "Quiet Alcove":
			alcove = station
	_check(alcove != null and alcove.verb == "Browse", "the alcove advertises its library action")
	alcove.activated.emit()
	await get_tree().process_frame
	var library := hub._open_panel
	_check(library != null and library.has_method("set_filter"), "the alcove opens the library")
	_check(get_tree().paused and not hub._interact_enabled, "library pauses movement and station interaction")
	_check(not hub._zoom_controls.visible, "courtyard camera buttons hide beneath the library")
	library.call("set_filter", "Items", "beka")
	_check(int(library.get("result_count")) == 1, "the screen filters its visible results")
	library.call("set_filter", "Items", "nothing matches this phrase")
	_check(int(library.get("result_count")) == 0, "the screen supports an empty result state")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	hub._unhandled_input(wheel)
	_check(is_equal_approx(hub.hub_zoom, 1.0), "scrolling a modal cannot zoom the courtyard")
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	Input.parse_input_event(escape)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(hub._open_panel == null and not get_tree().paused and hub._interact_enabled, "Escape returns to the active courtyard")
	_check(hub._zoom_controls.visible, "camera controls return after closing the library")
	hub._open_library()
	await get_tree().process_frame
	var controller_cancel := InputEventJoypadButton.new()
	controller_cancel.button_index = JOY_BUTTON_B
	controller_cancel.pressed = true
	Input.parse_input_event(controller_cancel)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(hub._open_panel == null and not get_tree().paused, "controller cancel closes the library while the world is paused")
	_check(Global.attempt_segment == segment_before and Global.followers == followers_before and Global.run_inventory.items == inventory_before, "reading and closing never advances the attempt or changes owned resources")

	# Toolbar mouse focus must not steal Enter/A from the next station action.
	hub._player.global_position = alcove.global_position - Vector2(0.0, HubWorld.FEET)
	for attempt: int in range(8):
		await get_tree().physics_frame
		await get_tree().process_frame
		if alcove.player_inside():
			break
	hub._update_focus()
	_check(hub._focus == alcove, "focus regression stands on the alcove ring")
	var plus: Button = null
	for child: Node in hub._zoom_controls.get_child(0).get_child(0).get_children():
		if child is Button and child.text == "+":
			plus = child
	hub._reset_hub_view()
	await _click(plus)
	_check(is_equal_approx(hub.hub_zoom, 1.25), "a real mouse click activates Zoom In")
	_check(not plus.has_focus(), "mouse activation returns Zoom In focus to the courtyard")
	await _confirm()
	_check(hub._open_panel != null, "Enter opens the alcove after clicking Zoom In")
	if hub._open_panel != null:
		hub._open_panel.call("_close")
	await get_tree().process_frame
	plus.release_focus()
	hub._reset_hub_view()
	await _click(hub._beka_view_button)
	_check(hub._beka_view, "a real mouse click activates View Beka")
	_check(not hub._beka_view_button.has_focus(), "mouse activation returns View Beka focus to the courtyard")
	await _confirm()
	_check(hub._open_panel != null and hub._beka_view, "Enter opens the alcove instead of toggling the focused Beka button")
	if hub._open_panel != null:
		hub._open_panel.call("_close")
	await get_tree().process_frame
	hub._beka_view_button.release_focus()
	hub._reset_hub_view()
	# Exercise deliberate controller navigation with A mapped to UI confirm;
	# some engine defaults expose only the keyboard version of ui_accept.
	var ui_accept_a := InputEventJoypadButton.new()
	ui_accept_a.button_index = JOY_BUTTON_A
	var add_ui_a := not InputMap.event_is_action(ui_accept_a, &"ui_accept")
	if add_ui_a:
		InputMap.action_add_event(&"ui_accept", ui_accept_a)
	_check(plus.focus_mode == Control.FOCUS_ALL, "zoom buttons remain available to deliberate keyboard/controller focus")
	plus.grab_focus()
	await get_tree().process_frame
	# Exercise focused activation directly without depending on window focus
	# or connected pad hardware. Real pointer activation and raw Enter/A
	# routing back to the station are checked separately.
	plus.pressed.emit()
	_check(is_equal_approx(hub.hub_zoom, 1.25) and hub._open_panel == null, "deliberate focused toolbar activation still works")
	_check(not plus.has_focus(), "controller activation hands focus back to the courtyard")
	await _confirm(true)
	_check(hub._open_panel != null, "the next controller A opens the alcove instead of reactivating Zoom In")
	if hub._open_panel != null:
		hub._open_panel.call("_close")
	await get_tree().process_frame
	if add_ui_a:
		InputMap.action_erase_event(&"ui_accept", ui_accept_a)
	hub.queue_free()
	await get_tree().process_frame
	var test_dir := ProjectSettings.globalize_path(SaveManager.save_dir)
	if DirAccess.dir_exists_absolute(test_dir):
		for file: String in DirAccess.get_files_at(test_dir):
			DirAccess.remove_absolute(test_dir.path_join(file))
		DirAccess.remove_absolute(test_dir)
	SaveManager.save_dir = SaveManager.SAVE_DIR
	SaveManager.current_save = null
	print("HubLibraryTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
