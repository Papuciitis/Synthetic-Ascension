extends CanvasLayer
class_name OpeningPresentation
## The opening's story cards in the front end's register. Five voices keep
## their own look: the HISTORICAL account floats unboxed in Cinzel Decorative
## and Garamond italic; DIALOGUE is a warm card in a gold double rule;
## the INSTITUTIONAL announcement is ruled in danger red; the SYNTHETIC
## response keeps a cold teal on its rule and caption only; the FOLLOWER's
## commitment glows gold. Text types out at the accessibility speed on real
## time (the opening slows Engine.time_scale under some cards), choices are
## ledger rows, and each card eases up into place (only fades under Reduced
## Motion).

signal advanced
signal choice_selected(index: int)

enum Style { HISTORICAL, DIALOGUE, INSTITUTIONAL, SYNTHETIC, FOLLOWER }

const Accessibility := preload("res://core/settings/AccessibilityPresentation.gd")
const CARD_THEME := preload("res://ui/theme/ArcaneMenuTheme.tres")
const OverlayKit := preload("res://ui/widgets/overlays/OverlayKit.gd")
const ArcaneFrameScript := preload("res://ui/components/ArcaneFrame.gd")
const ArcaneRuleScript := preload("res://ui/components/ArcaneRule.gd")

const PANEL_WIDTH := 800.0
## The card's top edge, below the centre so the scene above stays readable;
## a taller card rises so its foot stays on screen. The unboxed historical
## account sits higher, nearer the middle of its darker shade.
const PANEL_TOP := 650.0
const HISTORICAL_TOP := 300.0
const BOTTOM_MARGIN := 30.0

static var _looks: Dictionary = {}

var _shade: ColorRect
var _stage: Control
var _panel: PanelContainer
var _frame: Control
var _eyebrow: Label
var _title: Label
var _rule: Control
var _body: Label
var _choices: VBoxContainer
var _continue_button: Button
var _prompt: Label
var _waiting: bool = false
var _revealing := false
var _reveal_progress := 0.0
var _has_choices := false
var _style := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 220
	_build_ui()
	hide_card()
	_shade.visible = false


func _process(delta: float) -> void:
	if not _revealing:
		return
	var characters_per_second := Accessibility.current_typewriter_characters_per_second()
	if is_inf(characters_per_second):
		_complete_reveal()
		return
	_reveal_progress += OverlayKit.real_delta(delta) * characters_per_second
	var total := _body.get_total_character_count()
	_body.visible_characters = mini(total, int(_reveal_progress))
	if _body.visible_characters >= total:
		_complete_reveal()


func _unhandled_input(event: InputEvent) -> void:
	if not _waiting or not _panel.visible:
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		if _revealing or not _has_choices:
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
	_eyebrow.visible = eyebrow_value != ""
	_title.text = title_value
	_title.visible = title_value != ""
	_rule.visible = title_value != "" or eyebrow_value != ""
	_body.text = body_value
	_body.visible_characters = 0
	_reveal_progress = 0.0
	_revealing = _body.get_total_character_count() > 0
	_has_choices = not choices.is_empty()
	# The shade outlives a card by a frame, so a run of cards never flickers.
	var was_showing := _shade.visible
	_panel.visible = true
	_shade.visible = true
	_waiting = true
	_continue_button.text = button_text
	_choices.visible = false
	_continue_button.visible = _revealing or not _has_choices
	if _has_choices:
		for index in range(choices.size()):
			var entry: Dictionary = choices[index] as Dictionary
			var button := Button.new()
			button.text = String(entry.get("label", "Continue"))
			button.focus_mode = Control.FOCUS_ALL
			button.custom_minimum_size = Vector2(0.0, 38.0)
			OverlayKit.style_choice(button)
			button.pressed.connect(_select_choice.bind(index))
			_choices.add_child(button)
	_panel.reset_size()
	_place_panel()
	# Once the new words are laid out, fit the card to them (a shorter card
	# after a long one would otherwise keep the long one's height).
	_refit_panel.call_deferred()
	_play_arrival(was_showing)
	if _revealing and is_inf(Accessibility.current_typewriter_characters_per_second()):
		_complete_reveal()
	elif _revealing or not _has_choices:
		_continue_button.grab_focus()
	else:
		_complete_reveal()
	var result := -1
	if choices.is_empty():
		await advanced
	else:
		result = await choice_selected
	_waiting = false
	hide_card()
	return result


## Each card eases up into place; the shade fades in only when the first card
## of a run of cards arrives over the world.
func _play_arrival(was_showing: bool) -> void:
	if not was_showing:
		OverlayKit.fade_in(_shade, 0.28)
	OverlayKit.arrive(_stage, 14.0, 0.38, 0.02)


func _refit_panel() -> void:
	if _panel == null or not _panel.visible:
		return
	_panel.reset_size()
	_place_panel()


## Keeps the card at its voice's height unless that would run its foot off
## the screen (a long account, or choices unfolding under the text).
func _place_panel() -> void:
	if _panel == null:
		return
	var view_height := _stage.size.y if _stage.size.y > 0.0 else 1080.0
	var top := HISTORICAL_TOP if _style == Style.HISTORICAL else PANEL_TOP
	var fitted := minf(top, view_height - BOTTOM_MARGIN - _panel.size.y)
	if not is_equal_approx(_panel.position.y, fitted):
		_panel.position.y = fitted

func advance() -> void:
	if not _waiting:
		return
	if _revealing:
		_complete_reveal()
		return
	if _has_choices:
		return
	advanced.emit()


func _complete_reveal() -> void:
	_revealing = false
	_body.visible_characters = -1
	_reveal_progress = float(_body.get_total_character_count())
	_choices.visible = _has_choices
	_continue_button.visible = not _has_choices
	if _has_choices and not _choices.get_children().is_empty():
		(_choices.get_child(0) as Button).call_deferred("grab_focus")
	elif not _has_choices:
		_continue_button.call_deferred("grab_focus")

func show_prompt(text_value: String) -> void:
	var was_visible := _prompt.visible
	_prompt.text = text_value
	_prompt.visible = text_value != ""
	if _prompt.visible and not was_visible:
		_prompt.modulate.a = 0.0
		OverlayKit.tween(_prompt).tween_property(_prompt, "modulate:a", 1.0, 0.24)

func hide_prompt() -> void:
	_prompt.visible = false

func hide_card() -> void:
	_revealing = false
	if _panel != null:
		_panel.visible = false
	_hide_shade_after_frame()


## The next card usually follows in the same frame; only a shade still unused
## a frame later goes.
func _hide_shade_after_frame() -> void:
	if _shade == null or not is_inside_tree():
		if _shade != null:
			_shade.visible = false
		return
	await get_tree().process_frame
	if _shade != null and _panel != null and not _panel.visible:
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


## One voice's look, built once and shared by every card in that voice.
static func _look(style: int) -> Dictionary:
	if _looks.has(style):
		return _looks[style]
	var look := {
		"panel": OverlayKit.shared(&"card"),
		"frame": true,
		"frame_colour": Color(0.58, 0.44, 0.27, 0.85),
		"glow": 0.0,
		"eyebrow": Color(0.78, 0.6, 0.38),
		"title": OverlayKit.GOLD_BRIGHT,
		"title_font": &"heading",
		"title_size": 29,
		"rule": Color(0.66, 0.5, 0.31, 0.75),
		"body_font": &"body",
		"body_size": 22,
		"body": OverlayKit.PARCHMENT,
		"align": HORIZONTAL_ALIGNMENT_LEFT,
		"shade": Color(0.008, 0.006, 0.005, 0.66),
	}
	match style:
		Style.HISTORICAL:
			look["panel"] = OverlayKit.shared(&"empty")
			look["frame"] = false
			look["eyebrow"] = Color(0.72, 0.58, 0.4)
			look["title"] = OverlayKit.PARCHMENT
			look["title_font"] = &"title"
			look["title_size"] = 40
			look["body_font"] = &"italic"
			look["body_size"] = 25
			look["body"] = Color(0.88, 0.83, 0.74)
			look["align"] = HORIZONTAL_ALIGNMENT_CENTER
			look["shade"] = Color(0.006, 0.005, 0.004, 0.84)
		Style.INSTITUTIONAL:
			var notice := OverlayKit.box(Color(0.05, 0.024, 0.02, 0.97), Color(0, 0, 0, 0), 0, 0.0, 28)
			notice.shadow_color = Color(0, 0, 0, 0.62)
			look["panel"] = notice
			look["frame_colour"] = Color(0.74, 0.32, 0.24, 0.9)
			look["eyebrow"] = Color(0.92, 0.45, 0.34)
			look["title"] = OverlayKit.PARCHMENT
			look["title_size"] = 26
			look["rule"] = Color(0.78, 0.36, 0.26, 0.8)
		Style.SYNTHETIC:
			var cold := OverlayKit.box(Color(0.02, 0.028, 0.03, 0.97), Color(0, 0, 0, 0), 0, 0.0, 28)
			cold.shadow_color = Color(0, 0, 0, 0.62)
			look["panel"] = cold
			look["frame_colour"] = Color(0.34, 0.6, 0.62, 0.8)
			look["eyebrow"] = OverlayKit.TEAL
			look["title"] = Color(0.88, 0.9, 0.86)
			look["rule"] = Color(0.42, 0.76, 0.78, 0.7)
		Style.FOLLOWER:
			var warm := OverlayKit.box(Color(0.05, 0.036, 0.024, 0.97), Color(0, 0, 0, 0), 0, 0.0, 30)
			warm.shadow_color = Color(0.5, 0.28, 0.08, 0.3)
			look["panel"] = warm
			look["frame_colour"] = Color(0.86, 0.66, 0.4, 0.95)
			look["glow"] = 0.35
			look["eyebrow"] = OverlayKit.GOLD
			look["title"] = OverlayKit.GOLD_BRIGHT
			look["rule"] = Color(0.9, 0.7, 0.42, 0.85)
	_looks[style] = look
	return look


func _apply_style(style: int) -> void:
	if style == _style:
		return
	_style = style
	var look := _look(style)
	_panel.add_theme_stylebox_override("panel", look["panel"] as StyleBox)
	_frame.visible = bool(look["frame"])
	_frame.set("colour", look["frame_colour"])
	_frame.set("glow", float(look["glow"]))
	_shade.color = look["shade"] as Color
	var align: HorizontalAlignment = int(look["align"]) as HorizontalAlignment
	OverlayKit.style_label(_eyebrow, &"caption", 14, look["eyebrow"] as Color)
	OverlayKit.style_label(_title, StringName(look["title_font"]), int(look["title_size"]), look["title"] as Color)
	OverlayKit.style_label(_body, StringName(look["body_font"]), int(look["body_size"]), look["body"] as Color)
	for label: Label in [_eyebrow, _title, _body]:
		label.horizontal_alignment = align
	_rule.set("colour", look["rule"])
	_rule.set("ornament_at", 0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else 0.035)
	_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if align == HORIZONTAL_ALIGNMENT_CENTER else Control.SIZE_FILL
	_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if align == HORIZONTAL_ALIGNMENT_CENTER else Control.SIZE_SHRINK_END

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = CARD_THEME
	add_child(root)
	_shade = ColorRect.new()
	_shade.color = Color(0.008, 0.006, 0.005, 0.66)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_shade)
	# The stage moves for the arrival; the card inside it keeps its place.
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stage)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left = -PANEL_WIDTH * 0.5
	_panel.offset_right = PANEL_WIDTH * 0.5
	_panel.offset_top = PANEL_TOP
	_panel.offset_bottom = PANEL_TOP
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.add_child(_panel)
	_panel.resized.connect(_place_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 26)
	_panel.add_child(margin)
	_frame = ArcaneFrameScript.new() as Control
	_frame.set("inset", 6.0)
	_panel.add_child(_frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	_eyebrow = Label.new()
	column.add_child(_eyebrow)
	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A wrapping label measures its height at its width; give it the column's
	# from the start, or the first measurement stacks every word.
	_title.custom_minimum_size = Vector2(PANEL_WIDTH - 80.0, 0)
	column.add_child(_title)
	_rule = ArcaneRuleScript.new() as Control
	_rule.custom_minimum_size = Vector2(380, 12)
	column.add_child(_rule)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(PANEL_WIDTH - 80.0, 0)
	_body.add_theme_constant_override("line_spacing", 2)
	column.add_child(_body)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 3)
	column.add_child(_choices)
	_continue_button = Button.new()
	_continue_button.custom_minimum_size = Vector2(200, 44)
	_continue_button.focus_mode = Control.FOCUS_ALL
	_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_continue_button.pressed.connect(advance)
	column.add_child(_continue_button)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.offset_left = -340.0
	_prompt.offset_right = 340.0
	_prompt.offset_top = -100.0
	_prompt.offset_bottom = -52.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	OverlayKit.style_label(_prompt, &"semi", 19, OverlayKit.GOLD_BRIGHT, 3)
	_prompt.add_theme_stylebox_override("normal", OverlayKit.shared(&"plate"))
	_prompt.visible = false
	root.add_child(_prompt)
