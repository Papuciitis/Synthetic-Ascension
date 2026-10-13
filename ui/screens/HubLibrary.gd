extends CanvasLayer
## The Chronicler's books. Knowledge is earned in play; reading spends nothing.

signal closed()
const LibraryData := preload("res://ui/screens/HubLibraryData.gd")
const ChamberKit := preload("res://ui/widgets/chambers/ChamberKit.gd")
const BookSpine := preload("res://ui/widgets/library/LibraryBook.gd")
const OpenBook := preload("res://ui/widgets/library/LibraryOpenBook.gd")
const BACKDROP_PATH := "res://assets/ui/library/alcove_library_courtyard.png"
const PAGE_INK := Color(0.20, 0.115, 0.065)
const BINDINGS := [Color(0.90, 0.83, 0.65), Color(0.68, 0.85, 0.75), Color(0.78, 0.69, 0.89), Color(0.80, 0.67, 0.56), Color(0.91, 0.73, 0.61), Color(0.64, 0.77, 0.90), Color(0.66, 0.84, 0.67), Color(0.90, 0.77, 0.53), Color(0.84, 0.65, 0.64)]

var result_count := 0
var _entries: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _search: LineEdit
var _categories: OptionButton
var _discovery_filter: OptionButton
var _list: ItemList
var _count: Label
var _title: Label
var _subtitle: Label
var _body: RichTextLabel
var _icon: TextureRect
var _layout: Control
var _shelves: Control
var _reader: VBoxContainer
var _open_book: Control
var _book_pages: HBoxContainer
var _book_buttons: Array[Button] = []
var _research_button: Button
var _track_button: Button
var _previous_page: Button
var _next_page: Button
var _page_number: Label
var _selected_key := ""
var _page_tween: Tween
var _open_tween: Tween
var _was_paused := false
var _closing := false
var _reading_scroll_axis := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 160
	_was_paused = get_tree().paused
	get_tree().paused = true
	_entries = LibraryData.build_entries()
	_build_screen()
	_refresh_book_marks()
	show_shelves(false)
	get_viewport().size_changed.connect(_place_books)
	_place_books.call_deferred()
	set_process(false)


func _build_screen() -> void:
	_layout = Control.new()
	_layout.name = "LibraryLayout"
	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout.theme = ChamberKit.THEME
	add_child(_layout)
	var backdrop := TextureRect.new()
	backdrop.name = "AlcoveCourtyard"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(BACKDROP_PATH):
		backdrop.texture = load(BACKDROP_PATH) as Texture2D
	_layout.add_child(backdrop)
	var header_shade := ColorRect.new()
	header_shade.color = Color(0.02, 0.018, 0.016, 0.86)
	header_shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header_shade.offset_bottom = 70
	header_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout.add_child(header_shade)
	var header := HBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 24
	header.offset_right = -24
	header.offset_top = 12
	header.offset_bottom = 58
	header.add_theme_constant_override("separation", 14)
	_layout.add_child(header)
	var heading := _label("Quiet Alcove", 28, ChamberKit.PARCHMENT, &"ArcaneHeading")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_research_button = _button("Research bookmark", _open_research_target)
	_research_button.name = "ResearchTarget"
	header.add_child(_research_button)
	var close := _button("Return · Esc / B", _close)
	close.name = "ReturnToCourtyard"
	header.add_child(close)
	_build_shelves()
	_build_reader()


func _build_shelves() -> void:
	_shelves = Control.new()
	_shelves.name = "LibraryShelves"
	_shelves.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shelves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout.add_child(_shelves)
	for index: int in range(LibraryData.CATEGORIES.size()):
		var book: Button = BookSpine.new()
		book.name = "Book" + LibraryData.CATEGORIES[index]
		book.set("book_title", LibraryData.CATEGORIES[index])
		book.set("volume", index + 1)
		book.set("tint", BINDINGS[index])
		book.pressed.connect(select_book.bind(LibraryData.CATEGORIES[index]))
		_shelves.add_child(book)
		_book_buttons.append(book)
	var note := PanelContainer.new()
	note.name = "ChroniclerNote"
	note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	note.anchor_left = 0.12
	note.anchor_right = 0.68
	note.offset_top = -87
	note.offset_bottom = -16
	note.add_theme_stylebox_override("panel", ChamberKit.box(Color(0.03, 0.025, 0.02, 0.89), Color(0, 0, 0, 0), 0, 10))
	_shelves.add_child(note)
	var prose := _label("The Chronicler's library\nChoose a spine. Sealed pages hint at discoveries still to come; gold ribbons mark unread pages.", 17, ChamberKit.BODY, &"ArcaneBody")
	prose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_child(prose)


func _place_books() -> void:
	if not is_instance_valid(_shelves):
		return
	var extent := _layout.size
	# Measured empty ledges in the close-up of the existing courtyard stall.
	for index: int in range(_book_buttons.size()):
		var upper := index < 5
		var column := index if upper else index - 5
		var columns := 5 if upper else 4
		var shelf_width := extent.x * 0.474
		var gap := extent.x * 0.008
		var width := (shelf_width - gap * (columns - 1)) / columns
		var height := extent.y * (0.10 if upper else 0.12)
		var book := _book_buttons[index]
		book.position = Vector2(extent.x * 0.134 + column * (width + gap), extent.y * (0.507 if upper else 0.674))
		book.size = Vector2(width, height)


func _build_reader() -> void:
	var reader_margin := MarginContainer.new()
	reader_margin.name = "ReaderMargin"
	reader_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reader_margin.add_theme_constant_override("margin_left", 18)
	reader_margin.add_theme_constant_override("margin_right", 18)
	reader_margin.add_theme_constant_override("margin_top", 80)
	reader_margin.add_theme_constant_override("margin_bottom", 12)
	reader_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout.add_child(reader_margin)
	_reader = VBoxContainer.new()
	_reader.name = "BookReader"
	_reader.add_theme_constant_override("separation", 8)
	reader_margin.add_child(_reader)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	_reader.add_child(tools)
	tools.add_child(_button("← Shelves", show_shelves))
	_categories = OptionButton.new()
	_categories.name = "Category"
	_categories.add_item("All books")
	for category: String in LibraryData.CATEGORIES:
		_categories.add_item(category)
	_categories.item_selected.connect(func(_index: int) -> void: _refresh_results())
	tools.add_child(_categories)
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = "Search discoveries and clues…"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_text: String) -> void: _refresh_results())
	tools.add_child(_search)
	_discovery_filter = OptionButton.new()
	_discovery_filter.name = "PageVisibility"
	for caption: String in ["All pages", "Discovered", "Unread", "Sealed"]:
		_discovery_filter.add_item(caption)
	_discovery_filter.item_selected.connect(func(_index: int) -> void: _refresh_results())
	tools.add_child(_discovery_filter)
	_open_book = OpenBook.new()
	_open_book.name = "OpenBook"
	_open_book.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_open_book.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reader.add_child(_open_book)
	_book_pages = HBoxContainer.new()
	_book_pages.name = "BookPages"
	_book_pages.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_book_pages.anchor_left = 0.105
	_book_pages.anchor_right = 0.895
	_book_pages.anchor_top = 0.135
	_book_pages.anchor_bottom = 0.83
	_open_book.add_child(_book_pages)
	_open_book.resized.connect(func() -> void:
		_book_pages.add_theme_constant_override("separation", roundi(_open_book.size.x * 0.07))
		_open_book.pivot_offset = _open_book.size * 0.5)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.size_flags_stretch_ratio = 0.5
	contents.add_theme_constant_override("separation", 6)
	_book_pages.add_child(contents)
	contents.add_child(_label("Contents", 22, PAGE_INK, &"ArcaneHeading"))
	_count = _label("", 15, PAGE_INK)
	_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(_count)
	_list = ItemList.new()
	_list.name = "Entries"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_size_override("font_size", 18)
	_list.add_theme_color_override("font_color", PAGE_INK)
	_list.add_theme_color_override("font_selected_color", ChamberKit.PARCHMENT)
	_list.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_list.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_list.add_theme_stylebox_override("selected", ChamberKit.box(Color(0.30, 0.19, 0.10, 0.86), Color(0, 0, 0, 0), 0))
	_list.add_theme_stylebox_override("selected_focus", ChamberKit.box(Color(0.30, 0.19, 0.10, 0.86), Color(0, 0, 0, 0), 0))
	_list.add_theme_constant_override("line_separation", 8)
	_list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_list.item_selected.connect(_show_entry)
	contents.add_child(_list)
	var details := VBoxContainer.new()
	details.name = "Details"
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_stretch_ratio = 0.5
	details.add_theme_constant_override("separation", 7)
	_book_pages.add_child(details)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	details.add_child(title_row)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(40, 40)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	title_row.add_child(_icon)
	_title = _label("", 24, PAGE_INK, &"ArcaneHeading")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_row.add_child(_title)
	_subtitle = _label("", 16, Color(0.35, 0.23, 0.12), &"ArcaneItalic")
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_subtitle)
	_body = RichTextLabel.new()
	_body.name = "ReferenceText"
	_body.bbcode_enabled = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 20)
	_body.add_theme_font_size_override("bold_font_size", 20)
	_body.add_theme_color_override("default_color", PAGE_INK)
	_body.scroll_active = true
	_body.selection_enabled = true
	_body.focus_mode = Control.FOCUS_ALL
	_body.meta_clicked.connect(_follow_book_link)
	details.add_child(_body)
	_track_button = _button("Bookmark clue", _toggle_research_target)
	_track_button.name = "BookmarkPage"
	_track_button.theme_type_variation = &"ArcaneLinkButton"
	_track_button.add_theme_color_override("font_color", PAGE_INK)
	_track_button.add_theme_color_override("font_hover_color", Color(0.40, 0.22, 0.08))
	_track_button.add_theme_color_override("font_focus_color", Color(0.40, 0.22, 0.08))
	_track_button.add_theme_font_size_override("font_size", 16)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		_track_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	details.add_child(_track_button)
	var turns := HBoxContainer.new()
	turns.add_theme_constant_override("separation", 8)
	_reader.add_child(turns)
	_previous_page = _button("← Previous page", _turn_page.bind(-1))
	turns.add_child(_previous_page)
	_page_number = _label("", 15, ChamberKit.PARCHMENT)
	_page_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turns.add_child(_page_number)
	_next_page = _button("Next page →", _turn_page.bind(1))
	turns.add_child(_next_page)


func _label(caption: String, font_size: int, colour: Color, variation: StringName = &"ArcaneBody") -> Label:
	var label := Label.new()
	label.text = caption
	ChamberKit.label(label, variation, font_size, colour)
	return label


func _button(caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.theme_type_variation = &"ArcaneSmallButton"
	button.pressed.connect(action)
	return button


func select_book(category: String) -> void:
	set_filter(category, "")
	_list.grab_focus()
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_open_book.pivot_offset = _open_book.size * Vector2(0.5, 0.5)
	_open_book.scale = Vector2.ONE
	if not ChamberKit.reduced():
		_open_book.scale = Vector2(0.08, 0.94)
		_open_tween = ChamberKit.tween(self)
		_open_tween.tween_property(_open_book, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func set_filter(category: String, query: String) -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	_open_book.scale = Vector2.ONE
	_shelves.hide()
	_reader.show()
	var index := LibraryData.CATEGORIES.find(category)
	_categories.select(index + 1 if index >= 0 else 0)
	_search.set_text(query)
	_discovery_filter.select(0)
	_refresh_results()


func show_shelves(animate: bool = true) -> void:
	_reading_scroll_axis = 0.0
	set_process(false)
	_shelves.show()
	_refresh_book_marks()
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	if animate and _reader.visible and not ChamberKit.reduced():
		_open_book.pivot_offset = _open_book.size * 0.5
		_open_tween = ChamberKit.tween(self)
		_open_tween.tween_property(_open_book, "scale", Vector2(0.04, 0.94), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_open_tween.tween_callback(_reader.hide)
		_shelves.modulate.a = 0.6
		ChamberKit.tween(self).tween_property(_shelves, "modulate:a", 1.0, 0.18)
	else:
		_reader.hide()
	if not _book_buttons.is_empty():
		_book_buttons[0].grab_focus()


func _refresh_book_marks() -> void:
	for index: int in range(_book_buttons.size()):
		var known := 0
		var total := 0
		var unread := 0
		for entry: Dictionary in _entries:
			if entry["category"] != LibraryData.CATEGORIES[index]:
				continue
			total += 1
			if entry["discovered"]:
				known += 1
				if not Global.library_read_entries.has(String(entry["key"])):
					unread += 1
		var book := _book_buttons[index]
		book.set("discovered_pages", known)
		book.set("total_pages", total)
		book.set("unread_pages", unread)
		book.call("refresh_marks")
	var target := _entry_for_key(Global.library_target_key)
	_research_button.disabled = target.is_empty()
	_research_button.text = "Research bookmark" if target.is_empty() else "Research: " + (String(target["title"]) if target["discovered"] else String(target["category"]) + " clue")
	_research_button.tooltip_text = "Pin a page or clue inside a book to plan your next discovery." if target.is_empty() else "Return to your bookmarked page."


func _refresh_results() -> void:
	var category := "All" if _categories.selected == 0 else LibraryData.CATEGORIES[_categories.selected - 1]
	var found := LibraryData.filter_entries(_entries, category, _search.text)
	_results.clear()
	for entry: Dictionary in found:
		var discovered := bool(entry["discovered"])
		var unread := discovered and not Global.library_read_entries.has(String(entry["key"]))
		if (_discovery_filter.selected == 1 and not discovered) or (_discovery_filter.selected == 2 and not unread) or (_discovery_filter.selected == 3 and discovered):
			continue
		_results.append(entry)
	result_count = _results.size()
	_list.clear()
	var selected := 0
	var known := 0
	for index: int in range(_results.size()):
		var entry: Dictionary = _results[index]
		var unread := bool(entry["discovered"]) and not Global.library_read_entries.has(String(entry["key"]))
		_list.add_item(("◆ " if unread else "") + String(entry["title"]))
		_list.set_item_tooltip(index, String(entry["title"]) + "\n" + String(entry["subtitle"]))
		if entry["discovered"]:
			known += 1
		if entry["key"] == _selected_key:
			selected = index
	_count.text = "%d discovered · %d sealed" % [known, result_count - known]
	if _results.is_empty():
		_selected_key = ""
		_title.text = "No matching pages"
		_subtitle.text = "Try another book, filter or shorter search."
		_body.text = "Only discoveries and the clues written on sealed pages can be searched."
		_icon.hide()
		_track_button.hide()
		_page_number.text = "No matching pages"
		_previous_page.disabled = true
		_next_page.disabled = true
	else:
		_list.select(selected)
		_show_entry(selected, false)


func _show_entry(index: int, animate: bool = true) -> void:
	if index < 0 or index >= _results.size():
		return
	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
	_open_book.set("turn_progress", 1.0)
	_open_book.set("turn_caption", "[b]" + _title.text + "[/b]\n\n" + _body.text)
	var entry: Dictionary = _results[index]
	var changed := _selected_key != String(entry["key"])
	_selected_key = String(entry["key"])
	_title.text = String(entry["title"])
	_subtitle.text = String(entry["subtitle"]) if entry["discovered"] else "The Chronicler awaits your account."
	_body.text = String(entry["body"]) if entry["discovered"] else "[b]A page still sealed[/b]\n\n" + String(entry["hint"]) + "\n\nBookmark this clue if you want to seek it out. The name and account will appear once you discover it in play."
	if entry["category"] == "Recipes":
		_body.text += "\n\nRecipe clues describe the base ingredients. [url=book:Buildcraft]Buildcraft[/url] explains when their cards can appear and any lower level thresholds this attempt."
	_body.scroll_to_line(0)
	_icon.texture = entry["icon"] as Texture2D
	_icon.visible = _icon.texture != null
	_track_button.visible = bool(entry["trackable"])
	_update_bookmark_button()
	_page_number.text = "Page %d/%d · LB/RB turn · right stick scrolls" % [index + 1, result_count]
	_page_number.tooltip_text = "Use the right stick, mouse wheel, or Page Up / Page Down to read longer pages."
	_previous_page.disabled = index == 0
	_next_page.disabled = index == result_count - 1
	if entry["discovered"]:
		Global.library_mark_read(_selected_key)
		_list.set_item_text(index, String(entry["title"]))
	if animate and changed and not ChamberKit.reduced():
		_open_book.set("turn_progress", 0.0)
		_page_tween = ChamberKit.tween(self)
		_page_tween.tween_property(_open_book, "turn_progress", 1.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _turn_page(direction: int) -> void:
	if _results.is_empty():
		return
	var selected := _list.get_selected_items()
	var index := selected[0] if not selected.is_empty() else 0
	index = clampi(index + direction, 0, _results.size() - 1)
	_list.select(index)
	_list.ensure_current_is_visible()
	_show_entry(index)


func _entry_for_key(key: String) -> Dictionary:
	for entry: Dictionary in _entries:
		if entry["key"] == key:
			return entry
	return {}


func _update_bookmark_button() -> void:
	_track_button.text = "Remove research bookmark" if Global.library_target_key == _selected_key else "Bookmark this page" if _entry_for_key(_selected_key).get("discovered", false) else "Bookmark this clue"


func _toggle_research_target() -> void:
	if _selected_key == "":
		return
	Global.library_set_target("" if Global.library_target_key == _selected_key else _selected_key)
	_update_bookmark_button()
	_refresh_book_marks()


func _open_research_target() -> void:
	var entry := _entry_for_key(Global.library_target_key)
	if entry.is_empty():
		return
	_selected_key = Global.library_target_key
	select_book(String(entry["category"]))


func _follow_book_link(meta: Variant) -> void:
	var link := String(meta)
	if link.begins_with("book:"):
		var category := link.trim_prefix("book:")
		if LibraryData.CATEGORIES.has(category):
			select_book(category)


func _input(event: InputEvent) -> void:
	if _reader.visible and event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y:
		_reading_scroll_axis = event.axis_value if absf(event.axis_value) > 0.22 else 0.0
		set_process(not is_zero_approx(_reading_scroll_axis))
		get_viewport().set_input_as_handled()
	if _reader.visible and event is InputEventKey and event.pressed and not _search.has_focus():
		if event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
			_scroll_reading_page(maxf(80.0, _body.size.y * 0.85) * (-1.0 if event.keycode == KEY_PAGEUP else 1.0))
			get_viewport().set_input_as_handled()
	var cancel := event.is_action_pressed(&"ui_cancel")
	if event is InputEventJoypadButton and event.pressed:
		cancel = cancel or event.button_index == JOY_BUTTON_B
		if _reader.visible and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			_turn_page(-1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1)
			get_viewport().set_input_as_handled()
	if not _closing and cancel:
		get_viewport().set_input_as_handled()
		_close()


func _process(delta: float) -> void:
	if not _reader.visible:
		_reading_scroll_axis = 0.0
		set_process(false)
		return
	_scroll_reading_page(_reading_scroll_axis * 360.0 * delta)


func _scroll_reading_page(distance: float) -> void:
	var scroll := _body.get_v_scroll_bar()
	scroll.value = clampf(scroll.value + distance, scroll.min_value, maxf(scroll.min_value, scroll.max_value - scroll.page))


func _close() -> void:
	if _closing:
		return
	_closing = true
	get_tree().paused = _was_paused
	closed.emit()
	queue_free()
