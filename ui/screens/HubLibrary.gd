extends CanvasLayer
## The Chronicler's read-only reference. Nothing here awards discoveries,
## equips items, spends Followers or advances the attempt.

signal closed()

const LibraryData := preload("res://ui/screens/HubLibraryData.gd")
const ChamberKit := preload("res://ui/widgets/chambers/ChamberKit.gd")

var result_count: int = 0
var _entries: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _search: LineEdit
var _categories: OptionButton
var _list: ItemList
var _count: Label
var _title: Label
var _subtitle: Label
var _body: RichTextLabel
var _icon: TextureRect
var _was_paused := false
var _closing := false
var _layout: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 160
	_was_paused = get_tree().paused
	get_tree().paused = true
	_entries = LibraryData.build_entries()
	_build_screen()
	_refresh_results()
	_search.grab_focus()


func _build_screen() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = ChamberKit.VEIL
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_close())
	add_child(overlay)
	_layout = MarginContainer.new()
	_layout.name = "LibraryLayout"
	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout.theme = ChamberKit.THEME
	_layout.add_theme_constant_override("margin_left", 32)
	_layout.add_theme_constant_override("margin_right", 32)
	_layout.add_theme_constant_override("margin_top", 24)
	_layout.add_theme_constant_override("margin_bottom", 24)
	# Empty margins pass clicks through to the backdrop; the panel captures them.
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layout)
	var panel := PanelContainer.new()
	panel.name = "LibraryPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", ChamberKit.shared(&"panel"))
	_layout.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)
	var heading := Label.new()
	heading.text = "Quiet Alcove · Library"
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", ChamberKit.PARCHMENT)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(heading)
	var close := Button.new()
	close.name = "ReturnToCourtyard"
	close.text = "Return · Esc / B"
	close.pressed.connect(_close)
	header.add_child(close)
	var intro := Label.new()
	intro.text = "The Chronicler's reference to rules, threats and equipment."
	intro.add_theme_color_override("font_color", ChamberKit.MUTED)
	intro.add_theme_font_size_override("font_size", 16)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(intro)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 12)
	column.add_child(filters)
	_categories = OptionButton.new()
	_categories.name = "Category"
	_categories.add_item("All categories")
	for category: String in LibraryData.CATEGORIES:
		_categories.add_item(category)
	_categories.item_selected.connect(func(_index: int) -> void: _refresh_results())
	filters.add_child(_categories)
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = "Search names, nouns, effects or advice…"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_text: String) -> void: _refresh_results())
	filters.add_child(_search)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 14)
	_count.add_theme_color_override("font_color", ChamberKit.MUTED)
	column.add_child(_count)
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 20)
	column.add_child(content)
	_list = ItemList.new()
	_list.name = "Entries"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.size_flags_stretch_ratio = 0.38
	_list.add_theme_font_size_override("font_size", 18)
	_list.add_theme_constant_override("line_separation", 8)
	_list.add_theme_stylebox_override("panel", ChamberKit.shared(&"well"))
	_list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_list.item_selected.connect(_show_entry)
	content.add_child(_list)
	var details := VBoxContainer.new()
	details.name = "Details"
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_stretch_ratio = 0.62
	details.add_theme_constant_override("separation", 10)
	content.add_child(details)
	var detail_header := HBoxContainer.new()
	detail_header.add_theme_constant_override("separation", 12)
	details.add_child(detail_header)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(56, 56)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_header.add_child(_icon)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", ChamberKit.PARCHMENT)
	detail_header.add_child(_title)
	_subtitle = Label.new()
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_font_size_override("font_size", 16)
	_subtitle.add_theme_color_override("font_color", ChamberKit.GOLD)
	details.add_child(_subtitle)
	_body = RichTextLabel.new()
	_body.name = "ReferenceText"
	_body.bbcode_enabled = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 18)
	_body.add_theme_font_size_override("bold_font_size", 18)
	_body.add_theme_color_override("default_color", ChamberKit.BODY)
	_body.scroll_active = true
	_body.selection_enabled = true
	details.add_child(_body)
	var footer := Label.new()
	footer.text = "Browse freely. Reference numbers use base rank; your rolled equipment may differ."
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_theme_font_size_override("font_size", 14)
	footer.add_theme_color_override("font_color", ChamberKit.MUTED)
	column.add_child(footer)


func set_filter(category: String, query: String) -> void:
	var index := LibraryData.CATEGORIES.find(category)
	_categories.select(index + 1 if index >= 0 else 0)
	_search.set_text(query)
	_refresh_results()


func _refresh_results() -> void:
	var selected_id := ""
	var selected_category := ""
	var previous := _list.get_selected_items()
	if not previous.is_empty() and previous[0] < _results.size():
		selected_id = String(_results[previous[0]]["id"])
		selected_category = String(_results[previous[0]]["category"])
	var category := "All" if _categories.selected == 0 else LibraryData.CATEGORIES[_categories.selected - 1]
	_results = LibraryData.filter_entries(_entries, category, _search.text)
	result_count = _results.size()
	_list.clear()
	var selected := 0
	for index: int in range(_results.size()):
		var entry: Dictionary = _results[index]
		_list.add_item(String(entry["title"]))
		_list.set_item_tooltip(index, "%s · %s\n%s" % [entry["category"], entry["title"], entry["subtitle"]])
		if entry["id"] == selected_id and entry["category"] == selected_category:
			selected = index
	_count.text = "%d %s%s" % [result_count, "entry" if result_count == 1 else "entries", " · " + category if category != "All" else ""]
	if _results.is_empty():
		_title.text = "No matching entries"
		_subtitle.text = "Try another category or a shorter search."
		_body.text = "Search looks through names, nouns, rules and counterplay advice."
		_icon.hide()
	else:
		_list.select(selected)
		_show_entry(selected)


func _show_entry(index: int) -> void:
	if index < 0 or index >= _results.size():
		return
	var entry: Dictionary = _results[index]
	_title.text = String(entry["title"])
	_subtitle.text = String(entry["category"]) + (" · " + String(entry["subtitle"]) if not String(entry["subtitle"]).is_empty() else "")
	_body.text = String(entry["body"])
	_body.scroll_to_line(0)
	_icon.texture = entry["icon"] as Texture2D
	_icon.visible = _icon.texture != null


func _input(event: InputEvent) -> void:
	# ui_cancel may contain only Escape in a fresh engine input map.
	var cancel := event.is_action_pressed(&"ui_cancel")
	if event is InputEventJoypadButton:
		cancel = cancel or (event.pressed and event.button_index == JOY_BUTTON_B)
	if not _closing and cancel:
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if _closing:
		return
	_closing = true
	get_tree().paused = _was_paused
	closed.emit()
	queue_free()


func _exit_tree() -> void:
	if not _closing and get_tree() != null:
		get_tree().paused = _was_paused
