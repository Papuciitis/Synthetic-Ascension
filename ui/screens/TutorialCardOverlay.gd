extends CanvasLayer
class_name TutorialCardOverlay

signal dismissed

const Accessibility := preload("res://core/settings/AccessibilityPresentation.gd")
const INTERFACE_THEME := preload("res://ui/theme/SyntheticHudTheme.tres")

var _root: Control
var _eyebrow: Label
var _title: Label
var _image: TextureRect
var _body: Label
var _button: Button
var _revealing := false
var _reveal_progress := 0.0
var _typewriter_character_limit := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 230
	_build_ui()


func _process(delta: float) -> void:
	if not _revealing:
		return
	var characters_per_second := Accessibility.current_typewriter_characters_per_second()
	if is_inf(characters_per_second):
		_complete_reveal()
		return
	_reveal_progress += delta * characters_per_second
	_body.visible_characters = mini(_typewriter_character_limit, int(_reveal_progress))
	if _body.visible_characters >= _typewriter_character_limit:
		_complete_reveal()


func present(title_text: String, body_text: String, eyebrow_text: String = "FIELD DOSSIER", texture: Texture2D = null, typewriter_character_limit: int = -1) -> void:
	_eyebrow.text = eyebrow_text
	_title.text = title_text
	_body.text = body_text
	_body.visible_characters = 0
	_reveal_progress = 0.0
	var total := _body.get_total_character_count()
	_typewriter_character_limit = total if typewriter_character_limit < 0 else mini(typewriter_character_limit, total)
	_revealing = _typewriter_character_limit > 0
	if not _revealing or is_inf(Accessibility.current_typewriter_characters_per_second()):
		_complete_reveal()
	_image.texture = texture
	_image.visible = texture != null
	_root.visible = true
	await get_tree().process_frame
	_button.grab_focus()


func _on_continue_pressed() -> void:
	if _revealing:
		_complete_reveal()
		return
	_dismiss()


func _complete_reveal() -> void:
	_revealing = false
	_body.visible_characters = -1
	_reveal_progress = float(_body.get_total_character_count())


func _dismiss() -> void:
	if not _root.visible:
		return
	_root.visible = false
	dismissed.emit()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = INTERFACE_THEME
	add_child(_root)
	var black := ColorRect.new()
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Color(0.012, 0.011, 0.010, 0.88)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(black)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 480)
	panel.theme_type_variation = &"InstitutionalPanel"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.042, 0.038, 0.034, 0.98)
	panel_style.border_color = Color(0.66, 0.37, 0.17, 0.9)
	panel_style.set_border_width_all(1)
	panel_style.border_width_left = 2
	panel_style.border_width_bottom = 2
	panel_style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	_eyebrow = Label.new()
	_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eyebrow.modulate = Color(1.0, 0.64, 0.28, 0.95)
	_eyebrow.theme_type_variation = &"InstitutionalHeading"
	_eyebrow.add_theme_font_size_override("font_size", 15)
	box.add_child(_eyebrow)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.theme_type_variation = &"InstitutionalHeading"
	_title.add_theme_font_size_override("font_size", 29)
	box.add_child(_title)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = Color(1.0, 0.55, 0.2, 0.7)
	box.add_child(rule)
	_image = TextureRect.new()
	_image.custom_minimum_size = Vector2(0, 96)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_image)
	_body = Label.new()
	_body.custom_minimum_size = Vector2(620, 205)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 18)
	box.add_child(_body)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(0, 44)
	_button.theme_type_variation = &"InstitutionalButton"
	_button.text = "CONTINUE"
	_button.pressed.connect(_on_continue_pressed)
	box.add_child(_button)
	_root.visible = false
