extends CanvasLayer
class_name TutorialCardOverlay

signal dismissed

var _root: Control
var _eyebrow: Label
var _title: Label
var _image: TextureRect
var _body: Label
var _button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 230
	_build_ui()

func present(title_text: String, body_text: String, eyebrow_text: String = "FIELD DOSSIER", texture: Texture2D = null) -> void:
	_eyebrow.text = eyebrow_text
	_title.text = title_text
	_body.text = body_text
	_image.texture = texture
	_image.visible = texture != null
	_root.visible = true
	await get_tree().process_frame
	_button.grab_focus()

func _dismiss() -> void:
	if not _root.visible:
		return
	_root.visible = false
	dismissed.emit()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var black := ColorRect.new()
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Color(0.005, 0.005, 0.008, 0.92)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(black)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 610)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.035, 0.047, 0.99)
	panel_style.border_color = Color(1.0, 0.55, 0.2, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 38)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	_eyebrow = Label.new()
	_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eyebrow.modulate = Color(1.0, 0.64, 0.28, 0.95)
	_eyebrow.add_theme_font_size_override("font_size", 17)
	box.add_child(_eyebrow)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	box.add_child(_title)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = Color(1.0, 0.55, 0.2, 0.7)
	box.add_child(rule)
	_image = TextureRect.new()
	_image.custom_minimum_size = Vector2(0, 120)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_image)
	_body = Label.new()
	_body.custom_minimum_size = Vector2(700, 270)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 20)
	box.add_child(_body)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(0, 48)
	_button.text = "Continue"
	_button.pressed.connect(_dismiss)
	box.add_child(_button)
	_root.visible = false

