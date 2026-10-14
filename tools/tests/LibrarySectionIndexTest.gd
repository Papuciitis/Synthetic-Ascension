extends Node
## Physical current-volume bookmarks: safe ink, bounded fan and direct selection.
const INDEX_PATH := "res://ui/widgets/library/LibrarySectionIndex.gd"
var _passes := 0
var _failures := 0
var _requests: Array[String] = []

func _ready() -> void:
	SaveManager.save_dir = "user://saves_test_library_section_index/"
	SaveManager.current_save = null
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred(&"_run")

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error("LibrarySectionIndexTest: " + message)

func _run() -> void:
	_check(ResourceLoader.exists(INDEX_PATH), "current-volume section ribbons are available")
	if not ResourceLoader.exists(INDEX_PATH):
		_finish()
		return
	var index: Control = load(INDEX_PATH).new()
	var original_reduced := bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	index.size = Vector2(210, 430)
	add_child(index)
	index.account_requested.connect(func(key: String) -> void: _requests.append(key))
	var entries: Array[Dictionary] = []
	entries.append({"key": "guide:equipment_identity", "title": "Equipment, sets and rules", "discovered": true, "folio": 1})
	for number: int in range(1, 18):
		entries.append({"key": "rule:%02d" % number, "title": "Secret title %d" % number if number == 5 else "The remembered rule number %d" % number, "body": "A concealed mechanical payoff", "discovered": number != 5, "hint": "Seek two distinct rules of flame.", "folio": number + 1})
	index.set_entries(entries, "guide:equipment_identity")
	index.set_reading_enabled(true)
	index.set_book_open_progress(1.0, 1000.0)
	await get_tree().process_frame
	var initial: Array[Dictionary] = index.visible_entries()
	_check(initial.size() >= 3 and initial.size() <= 7, "fan shows a bounded useful number of account tabs")
	_check(String(initial[0].label).contains("Equipment") and String(initial[0].tooltip) == "Equipment, sets and rules", "primer tabs use short captions while preserving the full known title")
	(index.get_node("Tail1") as Button).pressed.emit()
	_check(_requests == ["rule:01"], "pressing a side ribbon directly requests its account, without moving the window")
	_check(index.visible_entries()[0].key == "guide:equipment_identity", "selecting an account does not advance the browsing window")
	index.select_key("rule:05")
	var found_seal := false
	for row: Dictionary in index.visible_entries():
		if row.key == "rule:05":
			found_seal = String(row.label) == "Sealed · 06" and String(row.tooltip).contains("flame") and not str(row).contains("Secret title") and not str(row).contains("mechanical payoff")
	_check(found_seal, "sealed ribbon ink exposes only its ordinal and public clue")
	var before := String(index.visible_entries()[0].key)
	index.set_entries(entries, "rule:05")
	_check(String(index.visible_entries()[0].key) == before, "same-account read-state updates retain the browsing window")
	_requests.clear()
	(index.get_node("LaterSections") as Button).pressed.emit()
	_check(String(index.visible_entries()[0].key) != before and _requests.is_empty(), "browse-more ink advances the fan without selecting an account")
	_check(String(index.visible_entries()[0].key) == "rule:04" or String(index.visible_entries()[0].key) == "rule:05" or String(index.visible_entries()[0].key) == "rule:06", "clicking more sections advances a bank instead of repeating one tab at a time")
	(index.get_node("LaterSections") as Button).pressed.emit()
	var wheeled_from := String(index.visible_entries()[0].key)
	index.select_key("rule:05")
	_check(String(index.visible_entries()[0].key) == wheeled_from, "same-account reflow updates never snap a manually browsed fan back")
	index.set_entries(entries, "rule:05")
	_check(String(index.visible_entries()[0].key) == wheeled_from, "same-account read updates retain a fan browsed beyond the selected account")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	index._gui_input(wheel)
	_check(String(index.visible_entries()[0].key) != wheeled_from and _requests.is_empty(), "wheel browses later tabs without changing the open account")
	index.select_key("rule:17")
	_check(String(index.visible_entries().back().key) == "rule:17", "programmatic account changes reveal the selected section at the end")
	_check((index.get_node("LaterSections") as Button).disabled, "no later control remains active past the last account")
	index.select_key("guide:equipment_identity")
	(index.get_node("Tail0") as Button).grab_focus()
	var down := InputEventAction.new()
	down.action = &"ui_down"
	down.pressed = true
	for step: int in range(8):
		var focused := get_viewport().gui_get_focus_owner()
		focused._gui_input(down)
	_check(get_viewport().gui_get_focus_owner().get_meta("account_key", "") == "rule:08", "controller focus crosses the fan boundary and reveals the next account")
	for tail: Node in index.get_children():
		if tail is Button and tail.name.begins_with("Tail") and tail.visible:
			_check(tail.size.y >= 54.0, "cloth target remains at least 54 logical pixels high")
			var caption := tail.get_node("Caption") as Label
			var lines := caption.text.split("\n")
			var fits := lines.size() <= 2
			for line: String in lines:
				fits = fits and caption.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, caption.get_theme_font_size("font_size")).x <= caption.size.x + 0.1
			_check(fits, "printed section name stays inside its two-line cloth area")
			_check(caption.position.y >= 6.0 and caption.position.y + caption.size.y <= tail.size.y - 6.0 and caption.get_minimum_size().y <= tail.size.y - 12.0, "measured printed ink clears the cloth braid with six logical pixels on each edge (minimum %.1f, tail %.1f)" % [caption.get_minimum_size().y, tail.size.y])
	var dpad := InputEventJoypadButton.new()
	dpad.button_index = JOY_BUTTON_DPAD_DOWN
	_check(InputMap.event_is_action(dpad, &"ui_down"), "physical D-pad down is mapped to native focus navigation")
	index.select_key("rule:01")
	(index.get_node("Tail0") as Button).grab_focus()
	for step: int in 8:
		await _accept_event(dpad, true)
		await _accept_event(dpad, false)
	_check(get_viewport().gui_get_focus_owner().get_meta("account_key", "") == "rule:09", "real D-pad events carry focus across a fan bank")
	dpad.button_index = JOY_BUTTON_DPAD_UP
	_check(InputMap.event_is_action(dpad, &"ui_up"), "physical D-pad up is mapped to native focus navigation")
	await _accept_event(dpad, true)
	await _accept_event(dpad, false)
	_check(get_viewport().gui_get_focus_owner().get_meta("account_key", "") == "rule:08", "real D-pad up returns focus to the preceding account")
	var original_accept_events := InputMap.action_get_events(&"ui_accept")
	for original: InputEvent in original_accept_events:
		if original is InputEventJoypadButton and original.button_index == JOY_BUTTON_A:
			InputMap.action_erase_event(&"ui_accept", original)
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	(index.get_node("Tail0") as Button).grab_focus()
	var requested_key := String((index.get_node("Tail0") as Button).get_meta("account_key"))
	_requests.clear()
	await _accept_event(accept, true)
	await _accept_event(accept, true)
	await _accept_event(accept, false)
	_check(_requests == [requested_key], "unmapped controller A activates the focused account exactly once per hold")
	InputMap.action_add_event(&"ui_accept", accept)
	_requests.clear()
	await _accept_event(accept, true)
	await _accept_event(accept, false)
	_check(_requests == [requested_key], "mapped controller A retains native button activation exactly once")
	InputMap.action_erase_event(&"ui_accept", accept)
	var bank_before := String(index.visible_entries()[0].key)
	(index.get_node("EarlierSections") as Button).grab_focus()
	_requests.clear()
	await _accept_event(accept, true)
	await _accept_event(accept, false)
	_check(_requests.is_empty() and String(index.visible_entries()[0].key) != bank_before, "unmapped controller A also browses a focused bank control")
	for original: InputEvent in original_accept_events:
		if original is InputEventJoypadButton and original.button_index == JOY_BUTTON_A:
			InputMap.action_add_event(&"ui_accept", original)
	var root_before: Rect2 = (index.get_node("Tail0") as Button).cloth_geometry().root
	(index.get_node("Tail0") as Button).button_down.emit()
	await get_tree().create_timer(0.12).timeout
	_check((index.get_node("Tail0") as Button).cloth_geometry().root == root_before, "pulling a tab keeps its sewn root fixed")
	_check((index.get_node("Tail0/Caption") as Label).position.x > 33.0, "printed ink moves outward with the pulled cloth")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	await get_tree().process_frame
	(index.get_node("Tail0") as Button).button_down.emit()
	_check(is_equal_approx((index.get_node("Tail0/Caption") as Label).position.x, 31.0), "Reduced Motion retains the printed attachment without a cloth pull")
	index.set_book_open_progress(0.5, 1000.0)
	_check(is_equal_approx(index.modulate.a, 1.0) and (index.get_node("Tail0") as Button).disabled, "attached cloth remains opaque while input waits for the cover")
	index.set_book_open_progress(1.0, 1000.0)
	index.set_reading_enabled(false)
	var closed_window := String(index.visible_entries()[0].key)
	index._gui_input(wheel)
	_check((index.get_node("Tail0") as Button).disabled and String(index.visible_entries()[0].key) == closed_window, "closed-state navigation cannot scroll or activate ribbons")
	index.size = Vector2(210, 540)
	index.set_entries(entries, "rule:17")
	await get_tree().process_frame
	_check(index.visible_entries().size() <= 7 and String(index.visible_entries().back().key) == "rule:17", "resizing keeps the selected end account visible without an unbounded fan")
	var guides: Array[Dictionary] = []
	for key: String in ["equipment_identity", "nouns_and_pairs", "merges_and_imprints", "augment_growth", "doctrine_families"]:
		guides.append({"key": "guide:" + key, "title": key.replace("_", " ").capitalize(), "discovered": true})
	index.size = Vector2(210, 300)
	index.set_entries(guides, "guide:equipment_identity")
	await get_tree().process_frame
	_check(index.visible_entries().size() == 5 and not (index.get_node("EarlierSections") as Button).visible and not (index.get_node("LaterSections") as Button).visible, "all five primer sections fit without a browsing control at compact reader height")
	var compact_guide_fit := true
	for slot: int in 5:
		var tail := index.get_node("Tail%d" % slot) as Button
		compact_guide_fit = compact_guide_fit and (tail.get_node("Caption") as Label).get_minimum_size().y <= tail.size.y - 12.0
	_check(compact_guide_fit, "compact guide captions also clear both gold braids")
	var no_entries: Array[Dictionary] = []
	index.set_entries(no_entries, "")
	_check(index.visible_entries().is_empty() and not (index.get_node("Tail0") as Button).visible, "a search with no accounts clears the cloth without stale requests")
	if DisplayServer.get_name() != "headless":
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--section-out="):
				await _render_samples(argument.trim_prefix("--section-out="), guides, entries)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", original_reduced, false)
	index.queue_free()
	await get_tree().process_frame
	_finish()

func _finish() -> void:
	print("LibrarySectionIndexTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _accept_event(event: InputEventJoypadButton, pressed: bool) -> void:
	event.pressed = pressed
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame

func _render_samples(output: String, guides: Array[Dictionary], rules: Array[Dictionary]) -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900, 600)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(900, 600)
	background.color = Color(0.075, 0.055, 0.045)
	viewport.add_child(background)
	for column: int in 2:
		var sample: Control = load(INDEX_PATH).new()
		sample.position = Vector2(120 + column * 410, 65)
		sample.size = Vector2(210, 430)
		viewport.add_child(sample)
		sample.set_entries(guides if column == 0 else rules, "guide:equipment_identity" if column == 0 else "rule:02")
		sample.set_reading_enabled(true)
		sample.set_book_open_progress(1.0, 1000.0)
		var binding := ColorRect.new()
		binding.position = Vector2(75 + column * 410, 50)
		binding.size = Vector2(58, 470)
		binding.color = Color(0.23, 0.12, 0.065)
		viewport.add_child(binding)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(viewport.get_texture().get_image().save_png(output.path_join("section_caption_safe_area.png")) == OK, "isolated cloth and ink render is written")
	viewport.queue_free()
	await get_tree().process_frame
