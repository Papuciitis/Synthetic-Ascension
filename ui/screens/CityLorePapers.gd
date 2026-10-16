extends CanvasLayer
## Optional recovery copies beside the Quiet Alcove. The world beneath this
## panel is the safe hub; no field combat input or horde is interrupted.

signal closed()

const DISCOVERY := preload("res://core/systems/narrative/CityLoreDiscovery.gd")
const ChamberKit := preload("res://ui/widgets/chambers/ChamberKit.gd")

var _root: Control
var _panel: PanelContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _detail: VBoxContainer
var _detail_title: Label
var _source: Label
var _excerpt: Label
var _status: Label
var _keep_button: Button
var _leave_button: Button
var _return_button: Button
var _paper_buttons: Dictionary = {}
var _selected_id := ""
var _was_paused := false
var _closing := false
var _tree: SceneTree
var _refit_pending := false
var _focus_reading_pending := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 160
	_tree = get_tree()
	_was_paused = _tree.paused
	_tree.paused = true
	_build_screen()
	get_viewport().size_changed.connect(_resize_panel)
	_resize_panel()
	leave_document()


func _build_screen() -> void:
	_root = Control.new()
	_root.name = "CityPapers"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = ChamberKit.THEME
	add_child(_root)
	var veil := ColorRect.new()
	veil.color = ChamberKit.VEIL
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(veil)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", ChamberKit.shared(&"panel"))
	_root.add_child(_panel)
	var margin := MarginContainer.new()
	for edge: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	_panel.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	page.add_child(_label("Papers", 28, ChamberKit.PARCHMENT, &"ArcaneHeading"))
	page.add_child(_label("Copies brought through the records route. Inspect a paper, then choose whether to keep a copy.", 21, ChamberKit.BODY))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.focus_mode = Control.FOCUS_ALL
	_scroll.gui_input.connect(_reading_input)
	page.add_child(_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(content)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	content.add_child(_list)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 18)
	content.add_child(_detail)
	_detail_title = _label("", 25, ChamberKit.PARCHMENT, &"ArcaneHeading")
	_detail.add_child(_detail_title)
	_source = _label("", 21, ChamberKit.MUTED)
	_detail.add_child(_source)
	_excerpt = _label("", 25, ChamberKit.PARCHMENT)
	_detail.add_child(_excerpt)
	_status = _label("", 21, ChamberKit.GOLD_BRIGHT)
	page.add_child(_status)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	page.add_child(actions)
	_keep_button = _button("Keep a copy", keep_copy)
	actions.add_child(_keep_button)
	_leave_button = _button("Leave", leave_document)
	actions.add_child(_leave_button)
	_return_button = _button("Return to Courtyard", _close)
	actions.add_child(_return_button)


func _label(text: String, font_size: int, colour: Color, variation: StringName = &"ArcaneBody") -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The first minimum-height measurement must already know its wrap width.
	# Otherwise the short introduction can expand the whole panel vertically.
	label.custom_minimum_size.x = maxf(1.0, _frame_size().x - 60.0)
	label.size.x = label.custom_minimum_size.x
	ChamberKit.label(label, variation, font_size, colour)
	label.text = text
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"ArcaneSmallButton"
	button.add_theme_font_size_override("font_size", 20)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size.x = maxf(1.0, _frame_size().x - 60.0)
	button.text = text
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	return button


func _frame_size() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var margin := 16.0 if viewport_size.x < 800.0 else 32.0
	return Vector2(minf(900.0, maxf(1.0, viewport_size.x - margin * 2.0)), minf(680.0, maxf(1.0, viewport_size.y - margin * 2.0)))


func _resize_panel(focus_reading: bool = false) -> void:
	var frame_size := _frame_size()
	for child: Node in _root.find_children("*", "Label", true, false):
		var label := child as Label
		label.custom_minimum_size.x = maxf(1.0, frame_size.x - 60.0)
		label.size.x = label.custom_minimum_size.x
	_place_panel()
	_focus_reading_pending = _focus_reading_pending or focus_reading
	if not _refit_pending:
		_refit_pending = true
		_refit_after_layout()


func _place_panel() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var frame_size := _frame_size()
	_panel.position = (viewport_size - frame_size) * 0.5
	_panel.size = frame_size


func _refit_after_layout() -> void:
	await get_tree().process_frame
	if _closing or not is_inside_tree():
		return
	# Containers have now measured the constrained labels instead of a
	# transient one-word-wide column. Reapply the requested viewport bounds.
	_place_panel()
	await get_tree().process_frame
	_refit_pending = false
	if _closing or not is_inside_tree():
		return
	if _focus_reading_pending and not _selected_id.is_empty():
		_focus_reading_pending = false
		_scroll.scroll_vertical = 0
		if _scroll.get_v_scroll_bar().max_value > _scroll.get_v_scroll_bar().page:
			_scroll.grab_focus()
		else:
			_focus_action()


func _focus_action() -> void:
	if _keep_button.disabled:
		_leave_button.grab_focus()
	else:
		_keep_button.grab_focus()


func _reading_input(event: InputEvent) -> void:
	if not _scroll.has_focus() or _selected_id.is_empty():
		return
	var limit := maxi(0, int(_scroll.get_v_scroll_bar().max_value - _scroll.get_v_scroll_bar().page))
	if event.is_action_pressed(&"ui_focus_next") or event.is_action_pressed(&"ui_accept"):
		_focus_action()
	elif event.is_action_pressed(&"ui_down"):
		_scroll.scroll_vertical = mini(limit, _scroll.scroll_vertical + 40)
	elif event.is_action_pressed(&"ui_up"):
		_scroll.scroll_vertical = maxi(0, _scroll.scroll_vertical - 40)
	elif event.is_action_pressed(&"ui_page_down"):
		_scroll.scroll_vertical = mini(limit, _scroll.scroll_vertical + maxi(40, int(_scroll.size.y * 0.8)))
	elif event.is_action_pressed(&"ui_page_up"):
		_scroll.scroll_vertical = maxi(0, _scroll.scroll_vertical - maxi(40, int(_scroll.size.y * 0.8)))
	else:
		return
	_scroll.accept_event()


func _refresh_list() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_paper_buttons.clear()
	for row: Dictionary in DISCOVERY.available_documents():
		var id := String(row["id"])
		var caption := String(row["name"])
		if bool(row["copied"]):
			caption += " · Copied"
		var button := _button(caption, inspect_document.bind(id))
		_list.add_child(button)
		_paper_buttons[id] = button
	if _paper_buttons.is_empty():
		_list.add_child(_label("No copies have reached this tray yet. Earlier papers remain available as you travel through the city.", 23, ChamberKit.BODY))


func inspect_document(id: String) -> bool:
	if _closing:
		return false
	var paper: Dictionary = {}
	for row: Dictionary in DISCOVERY.available_documents():
		if String(row["id"]) == id:
			paper = row
			break
	if paper.is_empty():
		return false
	_selected_id = id
	_detail_title.text = String(paper["name"])
	_source.text = "Source: " + String(paper["source"])
	_excerpt.text = String(paper["excerpt"])
	_list.hide()
	_detail.show()
	_keep_button.show()
	_keep_button.disabled = bool(paper["copied"])
	_leave_button.show()
	_return_button.hide()
	_status.text = "Chronicle copied — read in Library" if bool(paper["copied"]) else ""
	_status.visible = not _status.text.is_empty()
	_scroll.scroll_vertical = 0
	_resize_panel(true)
	return true


func keep_copy() -> bool:
	if _closing or _selected_id.is_empty():
		return false
	var copied := DISCOVERY.collect(_selected_id)
	if copied:
		_keep_button.disabled = true
		_status.text = "Chronicle copied — read in Library"
		_status.show()
		_leave_button.grab_focus()
		_resize_panel()
	return copied


func leave_document() -> void:
	var previous := _selected_id
	_selected_id = ""
	_refresh_list()
	_detail.hide()
	_list.show()
	_keep_button.hide()
	_leave_button.hide()
	_return_button.show()
	_status.hide()
	_scroll.scroll_vertical = 0
	_resize_panel()
	if _paper_buttons.has(previous):
		(_paper_buttons[previous] as Button).grab_focus()
	elif not _paper_buttons.is_empty():
		(_paper_buttons.values()[0] as Button).grab_focus()
	else:
		_return_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event == null or event.is_echo() or not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _selected_id.is_empty():
		_close()
	else:
		leave_document()


func _close() -> void:
	if _closing:
		return
	_closing = true
	_tree.paused = _was_paused
	closed.emit()
	queue_free()


func _exit_tree() -> void:
	if not _closing and _tree != null:
		_tree.paused = _was_paused
