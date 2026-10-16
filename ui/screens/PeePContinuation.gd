extends Control
## A still, paused-tree-safe pause between city attempts. There are no motion
## effects, so Reduced Motion receives the same immediately usable screen.
const ARCANE_THEME := preload("res://ui/theme/ArcaneMenuTheme.tres")
const RULE := preload("res://ui/components/ArcaneRule.gd")

var _leaving := false
var _content: VBoxContainer
var _scroll: ScrollContainer
var _begin: Button
var _menu: Button
var _quit: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Global.has_pending_peep():
		set_process_unhandled_input(false)
		hide()
		Global.goto_main_menu()
		return
	theme = ARCANE_THEME
	_build(Global.pending_peep_summary())
	resized.connect(_fit_width)
	_fit_width()
	_scroll.grab_focus()
	_focus_arrival.call_deferred()

func _build(summary: Dictionary) -> void:
	var dark := ColorRect.new()
	dark.color = Color(0.025, 0.026, 0.035)
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
	_label("PeeP", "Speaker", &"ArcaneCaption", 15)
	_label("Ah. There you are.", "Greeting", &"ArcaneHeading", 38)
	_label("That doesn't have to be the end.\nWant to try again?", "Invitation", &"ArcaneBody", 25)
	var rule := RULE.new() as Control
	rule.custom_minimum_size.y = 20
	_content.add_child(rule)
	var mortal := String(summary.get("name", ""))
	if mortal.is_empty():
		mortal = "Your city attempt"
	_label("%s — ended in segment %d." % [mortal, int(summary.get("segment", 1))], "Outcome", &"ArcaneItalic", 20)
	_label("Discoveries, owned augments, Stash equipment and committed choices stay with you.", "Retained", &"ArcaneBody", 21)
	_label("Carried gear, Followers and purchased tree powers reset. Augment upgrades restart.", "Reset", &"ArcaneBody", 21)
	_label("Committed choice effects return at their city milestones.", "Milestones", &"ArcaneItalic", 18)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_content.add_child(actions)
	_begin = _button("BEGIN ANOTHER CITY ATTEMPT", "Begin", actions)
	_menu = _button("RETURN TO MENU", "Menu", actions)
	_quit = _button("QUIT GAME", "Quit", actions)
	_begin.pressed.connect(_continue)
	_menu.pressed.connect(_return_to_menu)
	_quit.pressed.connect(_quit_game)
	scroll.focus_next = scroll.get_path_to(_begin)
	scroll.focus_neighbor_bottom = scroll.get_path_to(_begin)
	var buttons: Array[Button] = [_begin, _menu, _quit]
	for i in range(buttons.size()):
		var previous := buttons[posmod(i - 1, buttons.size())]
		var next := buttons[(i + 1) % buttons.size()]
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(previous)
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(next)
		buttons[i].focus_previous = buttons[i].get_path_to(previous)
		buttons[i].focus_next = buttons[i].get_path_to(next)
	_label("Take a break if you like. This decision will be here when you return.", "BreakHint", &"ArcaneItalic", 18)

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
	if _scroll.has_focus() and (event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_focus_next")):
		_begin.grab_focus()
		_scroll.accept_event()

func _lock_actions() -> bool:
	if _leaving:
		return false
	_leaving = true
	for button in [_begin, _menu, _quit]:
		button.disabled = true
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
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_return_to_menu()
