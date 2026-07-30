extends CanvasLayer
class_name OpeningPresentation

signal advanced
signal choice_selected(index: int)

enum Style { HISTORICAL, DIALOGUE, INSTITUTIONAL, SYNTHETIC, FOLLOWER }

var _shade: ColorRect
var _panel: PanelContainer
var _eyebrow: Label
var _title: Label
var _body: Label
var _choices: VBoxContainer
var _continue_button: Button
var _prompt: Label
var _waiting: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 220
	_build_ui()
	hide_card()

func _unhandled_input(event: InputEvent) -> void:
	if not _waiting or not _panel.visible or not _choices.get_children().is_empty():
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		advance()

func present_historical(mortal_name: String) -> void:
	await present_card(
		Style.HISTORICAL,
		"",
		"",
		"This is the earliest surviving account.",
		[],
		"Continue"
	)
	await present_card(
		Style.HISTORICAL,
		OpeningSequenceData.HISTORICAL_EYEBROW,
		"A PROHIBITED EXPERIMENT",
		OpeningSequenceData.historical_body(mortal_name),
		[],
		"Begin"
	)

func present_dialogue(speaker: String, role: String, text_value: String, choices: Array = []) -> int:
	return await present_card(Style.DIALOGUE, role, speaker, text_value, choices, "Continue")

func present_announcement(title_value: String, body_value: String, button_text: String = "Acknowledge") -> void:
	if SfxManager != null:
		SfxManager.play_ui(&"ui_error", -2.0)
	await present_card(Style.INSTITUTIONAL, "FACILITY ANNOUNCEMENT", title_value, body_value, [], button_text)

func present_synthetic(title_value: String, body_value: String) -> void:
	await present_card(Style.SYNTHETIC, "SYNTHETIC RESPONSE", title_value, body_value, [], "Stabilise")

func present_follower(body_value: String) -> void:
	await present_card(Style.FOLLOWER, "HUMAN COMMITMENT", OpeningSequenceData.FOLLOWER_TITLE, body_value, [], "Continue")

func present_card(style: int, eyebrow_value: String, title_value: String, body_value: String, choices: Array = [], button_text: String = "Continue") -> int:
	_clear_choices()
	_apply_style(style)
	_eyebrow.text = eyebrow_value
	_title.text = title_value
	_body.text = body_value
	_panel.visible = true
	_shade.visible = true
	_waiting = true
	_continue_button.text = button_text
	_continue_button.visible = choices.is_empty()
	if choices.is_empty():
		_continue_button.grab_focus()
	else:
		for index in range(choices.size()):
			var entry: Dictionary = choices[index] as Dictionary
			var button := Button.new()
			button.text = String(entry.get("label", "Continue"))
			button.focus_mode = Control.FOCUS_ALL
			button.custom_minimum_size = Vector2(0.0, 42.0)
			button.pressed.connect(_select_choice.bind(index))
			_choices.add_child(button)
		if not _choices.get_children().is_empty():
			(_choices.get_child(0) as Button).grab_focus()
	var result := -1
	if choices.is_empty():
		await advanced
	else:
		result = await choice_selected
	_waiting = false
	hide_card()
	return result

func advance() -> void:
	if not _waiting or not _choices.get_children().is_empty():
		return
	advanced.emit()

func show_prompt(text_value: String) -> void:
	_prompt.text = text_value
	_prompt.visible = text_value != ""

func hide_prompt() -> void:
	_prompt.visible = false

func hide_card() -> void:
	if _panel != null:
		_panel.visible = false
	if _shade != null:
		_shade.visible = false

func _select_choice(index: int) -> void:
	if _waiting:
		choice_selected.emit(index)

func _clear_choices() -> void:
	if _choices == null:
		return
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()

func _apply_style(style: int) -> void:
	var border := Color("6e7788")
	var accent := Color("d6dde8")
	var background := Color(0.035, 0.04, 0.05, 0.97)
	match style:
		Style.HISTORICAL:
			border = Color(0, 0, 0, 0)
			accent = Color("d6dde8")
			background = Color(0, 0, 0, 0)
		Style.DIALOGUE:
			border = Color("b78548")
			accent = Color("f2c27d")
		Style.INSTITUTIONAL:
			border = Color("c44f46")
			accent = Color("ff8175")
			background = Color(0.08, 0.025, 0.025, 0.98)
		Style.SYNTHETIC:
			border = Color("39d7e8")
			accent = Color("77f2ff")
			background = Color(0.015, 0.055, 0.065, 0.98)
		Style.FOLLOWER:
			border = Color("dcaa50")
			accent = Color("ffd989")
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.shadow_color = Color(0, 0, 0, 0.55)
	box.shadow_size = 0 if style == Style.HISTORICAL else 16
	_panel.add_theme_stylebox_override("panel", box)
	_eyebrow.add_theme_color_override("font_color", accent)
	_title.add_theme_color_override("font_color", accent)

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_shade = ColorRect.new()
	_shade.color = Color(0.005, 0.007, 0.01, 0.72)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_shade)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-390, 155)
	_panel.size = Vector2(780, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_eyebrow = Label.new()
	_eyebrow.add_theme_font_size_override("font_size", 13)
	column.add_child(_eyebrow)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 27)
	column.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 18)
	_body.custom_minimum_size = Vector2(700, 0)
	column.add_child(_body)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	column.add_child(_choices)
	_continue_button = Button.new()
	_continue_button.custom_minimum_size = Vector2(160, 42)
	_continue_button.focus_mode = Control.FOCUS_ALL
	_continue_button.pressed.connect(advance)
	column.add_child(_continue_button)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-340, -96)
	_prompt.size = Vector2(680, 48)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.add_theme_color_override("font_color", Color("fff2cc"))
	var prompt_box := StyleBoxFlat.new()
	prompt_box.bg_color = Color(0.02, 0.025, 0.03, 0.92)
	prompt_box.border_color = Color("bd7b31")
	prompt_box.set_border_width_all(1)
	prompt_box.set_corner_radius_all(6)
	_prompt.add_theme_stylebox_override("normal", prompt_box)
	_prompt.visible = false
	root.add_child(_prompt)
