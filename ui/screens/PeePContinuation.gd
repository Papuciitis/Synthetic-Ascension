extends Control
## A still, paused-tree-safe pause between city attempts. There are no motion
## effects, so Reduced Motion receives the same immediately usable screen.
const ARCANE_THEME := preload("res://ui/theme/ArcaneMenuTheme.tres")
const RULE := preload("res://ui/components/ArcaneRule.gd")
const ENCOUNTER := preload("res://data/narrative/PeePEncounterData.gd")
const MARGIN := preload("res://ui/screens/peep/PeePMargin.gd")
const DEVELOPMENT_SCREEN := preload("res://ui/screens/CityDevelopmentScreen.tscn")

var _leaving := false
var _content: VBoxContainer
var _scroll: ScrollContainer
var _begin: Button
var _menu: Button
var _quit: Button
var _prepare: Button
var _read_first: Button
var _first_conversation: Label
var _development: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Global.has_pending_peep():
		set_process_unhandled_input(false)
		hide()
		Global.goto_main_menu()
		return
	theme = ARCANE_THEME
	var first := not StoryDirector.has_flag(ENCOUNTER.FIRST_SEEN_FLAG)
	_build(Global.pending_peep_summary(), first)
	if first and StoryDirector.add_flag(ENCOUNTER.FIRST_SEEN_FLAG):
		# The conversation is fully present now. Its memory survives deferring
		# this decision, including quitting before a deferred autosave can run.
		Global.save_current_profile()
	SfxManager.play_ui(&"ui_click")
	resized.connect(_fit_width)
	_fit_width()
	_scroll.grab_focus()
	_focus_arrival.call_deferred()

func _build(summary: Dictionary, first: bool) -> void:
	var dark := ColorRect.new()
	dark.color = Color(0.035, 0.032, 0.028)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in [&"left", &"right", &"top", &"bottom"]:
		margin.add_theme_constant_override("margin_" + String(side), 24)
	add_child(margin)
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.name = "Scroll"
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.gui_input.connect(_on_reading_input)
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	center.add_child(_content)
	var mark := MARGIN.new() as Control
	mark.name = "PeePMargin"
	_content.add_child(mark)
	_label("PeeP", "Speaker", &"ArcaneCaption", 15)
	_label(ENCOUNTER.GREETING, "Greeting", &"ArcaneHeading", 38)
	_label(ENCOUNTER.FIRST_BODY if first else ENCOUNTER.REPEAT_BODY, "Invitation", &"ArcaneBody", 25)
	if not first:
		_read_first = _button("Read first conversation", "ReadFirstConversation", _content)
		_read_first.pressed.connect(_toggle_first_conversation)
		_first_conversation = _label(ENCOUNTER.FIRST_CONVERSATION, "FirstConversation", &"ArcaneBody", 23)
		_first_conversation.hide()
	var rule := RULE.new() as Control
	rule.custom_minimum_size.y = 20
	_content.add_child(rule)
	var mortal := String(summary.get("name", ""))
	if mortal.is_empty():
		mortal = "Your city attempt"
	_label("%s — ended in segment %d." % [mortal, int(summary.get("segment", 1))], "Outcome", &"ArcaneItalic", 20)
	_label(ENCOUNTER.FINALITY, "Finality", &"ArcaneBody", 21)
	_label(ENCOUNTER.RETAINED, "Retained", &"ArcaneBody", 21)
	_label(ENCOUNTER.RESET, "Reset", &"ArcaneBody", 21)
	_label(ENCOUNTER.MILESTONES, "Milestones", &"ArcaneItalic", 18)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_content.add_child(actions)
	_prepare = _button("PREPARE NEXT ATTEMPT", "Prepare", actions)
	_begin = _button("BEGIN ANOTHER CITY ATTEMPT", "Begin", actions)
	_menu = _button("RETURN TO MENU", "Menu", actions)
	_quit = _button("QUIT GAME", "Quit", actions)
	_begin.pressed.connect(_continue)
	_menu.pressed.connect(_return_to_menu)
	_quit.pressed.connect(_quit_game)
	_prepare.pressed.connect(_open_preparation)
	scroll.focus_next = scroll.get_path_to(_begin)
	scroll.focus_neighbor_bottom = scroll.get_path_to(_begin)
	var buttons: Array[Button] = [_prepare, _begin, _menu, _quit]
	if _read_first != null:
		buttons.push_front(_read_first)
	for i in range(buttons.size()):
		var previous := buttons[posmod(i - 1, buttons.size())]
		var next := buttons[(i + 1) % buttons.size()]
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(previous)
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(next)
		buttons[i].focus_previous = buttons[i].get_path_to(previous)
		buttons[i].focus_next = buttons[i].get_path_to(next)
	_label(ENCOUNTER.BREAK_HINT, "BreakHint", &"ArcaneItalic", 18)
	_label("Arrow keys or Page Up / Page Down to read. Tab to the decision.", "ReadingHint", &"ArcaneItalic", 17)

func _toggle_first_conversation() -> void:
	if _leaving or is_instance_valid(_development):
		return
	_first_conversation.visible = not _first_conversation.visible
	_read_first.text = "Close first conversation" if _first_conversation.visible else "Read first conversation"
	SfxManager.play_ui(&"ui_toggle")
	if _first_conversation.visible:
		_focus_replay_reading.call_deferred()

func _focus_replay_reading() -> void:
	# Let the expanded label measure before placing its opening words at the
	# reading edge. Tab still returns directly to the continuation action.
	await get_tree().process_frame
	if _leaving or not _first_conversation.visible or is_instance_valid(_development):
		return
	_scroll.grab_focus()
	var opening_y := _first_conversation.get_global_rect().position.y
	_scroll.scroll_vertical += int(opening_y - _scroll.get_global_rect().position.y)

func _open_preparation() -> void:
	if _leaving or is_instance_valid(_development):
		return
	_development = DEVELOPMENT_SCREEN.instantiate() as CanvasLayer
	_development.connect(&"closed", _on_preparation_closed)
	add_child(_development)
	SfxManager.play_ui(&"ui_click")

func _on_preparation_closed() -> void:
	_development = null
	if not _leaving:
		_prepare.grab_focus()

func _label(caption: String, node_name: String, variation: StringName, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = caption
	label.theme_type_variation = variation
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(label)
	return label

func _button(caption: String, node_name: String, parent: Control) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.theme_type_variation = &"ArcaneSmallButton"
	button.custom_minimum_size.y = 42
	button.focus_mode = Control.FOCUS_ALL
	parent.add_child(button)
	return button

func _fit_width() -> void:
	if _content != null:
		# Leave room for the scrollbar when the content is taller than the window.
		_content.custom_minimum_size.x = clampf(size.x - 72.0, 0.0, 660.0)

func _focus_arrival() -> void:
	# Container measurement settles in the first layout frame. Start small
	# screens at the greeting, with no offscreen action ready to activate.
	await get_tree().process_frame
	if _leaving:
		return
	if _content.size.y <= _scroll.size.y:
		_begin.grab_focus()
	else:
		_scroll.scroll_vertical = 0

func _on_reading_input(event: InputEvent) -> void:
	if not _scroll.has_focus() or is_instance_valid(_development):
		return
	var limit := maxi(0, int(_scroll.get_v_scroll_bar().max_value - _scroll.get_v_scroll_bar().page))
	var step := 48
	var page := maxi(step, int(_scroll.size.y * 0.8))
	if event.is_action_pressed(&"ui_focus_next"):
		_begin.grab_focus()
	elif event.is_action_pressed(&"ui_down"):
		if _scroll.scroll_vertical >= limit:
			_begin.grab_focus()
		else:
			_scroll.scroll_vertical = mini(limit, _scroll.scroll_vertical + step)
	elif event.is_action_pressed(&"ui_up"):
		_scroll.scroll_vertical = maxi(0, _scroll.scroll_vertical - step)
	elif event.is_action_pressed(&"ui_page_down"):
		_scroll.scroll_vertical = mini(limit, _scroll.scroll_vertical + page)
	elif event.is_action_pressed(&"ui_page_up"):
		_scroll.scroll_vertical = maxi(0, _scroll.scroll_vertical - page)
	else:
		return
	_scroll.accept_event()

func _lock_actions() -> bool:
	if _leaving or is_instance_valid(_development):
		return false
	_leaving = true
	for button in [_prepare, _begin, _menu, _quit]:
		button.disabled = true
	if _read_first != null:
		_read_first.disabled = true
	return true

func _continue() -> void:
	if not _lock_actions():
		return
	SfxManager.play_ui(&"ui_click")
	if Global.accept_peep_continuation():
		get_tree().paused = false
		Global.goto_game()
	else:
		Global.goto_main_menu()

func _return_to_menu() -> void:
	if _lock_actions():
		SfxManager.play_ui(&"ui_back")
		get_tree().paused = false
		Global.goto_main_menu()

func _quit_game() -> void:
	if _lock_actions():
		Global.request_quit()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_development):
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_return_to_menu()
