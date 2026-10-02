extends CanvasLayer
class_name TutorialCardOverlay
## A blocking record (tutorial cards, scripted records, the enemy dossier's
## long form): a warm veil over the stopped world and a card in the front
## end's register, a double gold rule with corner diamonds and a crown star,
## a Cinzel caption and heading, a starred rule, Garamond body typed out at
## the accessibility speed, and one Continue. The card eases up into place;
## Reduced Motion leaves only the fade. Its clock is real time.

signal dismissed

const Accessibility := preload("res://core/settings/AccessibilityPresentation.gd")
const CARD_THEME := preload("res://ui/theme/ArcaneMenuTheme.tres")
const OverlayKit := preload("res://ui/widgets/overlays/OverlayKit.gd")
const ArcaneFrameScript := preload("res://ui/components/ArcaneFrame.gd")
const ArcaneRuleScript := preload("res://ui/components/ArcaneRule.gd")

var _root: Control
var _veil: ColorRect
var _center: CenterContainer
var _eyebrow: Label
var _title: Label
var _image: TextureRect
var _image_frame: Control
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
	_reveal_progress += OverlayKit.real_delta(delta) * characters_per_second
	_body.visible_characters = mini(_typewriter_character_limit, int(_reveal_progress))
	if _body.visible_characters >= _typewriter_character_limit:
		_complete_reveal()


func present(title_text: String, body_text: String, eyebrow_text: String = "FIELD DOSSIER", texture: Texture2D = null, typewriter_character_limit: int = -1) -> void:
	_eyebrow.text = eyebrow_text
	_eyebrow.visible = eyebrow_text != ""
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
	_image_frame.visible = texture != null
	_root.visible = true
	_play_arrival()
	await get_tree().process_frame
	_button.grab_focus()


func _play_arrival() -> void:
	OverlayKit.fade_in(_veil, 0.22)
	OverlayKit.arrive(_center, 16.0, 0.4, 0.04)


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
	_root.theme = CARD_THEME
	add_child(_root)
	_veil = ColorRect.new()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(0.01, 0.008, 0.006, 0.86)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_veil)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(740, 0)
	panel.add_theme_stylebox_override("panel", OverlayKit.shared(&"card"))
	_center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 46)
	margin.add_theme_constant_override("margin_right", 46)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 34)
	panel.add_child(margin)
	var frame := ArcaneFrameScript.new() as Control
	frame.set("inset", 8.0)
	panel.add_child(frame)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	_eyebrow = Label.new()
	_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eyebrow.theme_type_variation = &"ArcaneCaption"
	_eyebrow.add_theme_font_size_override("font_size", 14)
	_eyebrow.add_theme_color_override("font_color", Color(0.86, 0.62, 0.36))
	box.add_child(_eyebrow)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.theme_type_variation = &"ArcaneHeading"
	_title.add_theme_font_size_override("font_size", 31)
	_title.add_theme_color_override("font_color", OverlayKit.PARCHMENT)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	var rule := ArcaneRuleScript.new() as Control
	rule.set("ornament", 2)
	rule.custom_minimum_size = Vector2(360, 16)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(rule)
	# The picture sits in a well ruled in gold, like an item's icon.
	_image_frame = CenterContainer.new()
	_image_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_image_frame)
	var well := PanelContainer.new()
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_theme_stylebox_override("panel", OverlayKit.well(0))
	_image_frame.add_child(well)
	_image = TextureRect.new()
	_image.custom_minimum_size = Vector2(112, 112)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(_image)
	_body = Label.new()
	_body.custom_minimum_size = Vector2(640, 150)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.theme_type_variation = &"ArcaneBody"
	_body.add_theme_font_size_override("font_size", 21)
	_body.add_theme_constant_override("line_spacing", 3)
	box.add_child(_body)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	box.add_child(spacer)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(230, 46)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.text = "CONTINUE"
	_button.pressed.connect(_on_continue_pressed)
	box.add_child(_button)
	_root.visible = false
