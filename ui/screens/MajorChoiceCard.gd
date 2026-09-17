extends Button
class_name MajorChoiceCard

signal focused(card: MajorChoiceCard)

@export var base_bg := Color(0.035, 0.04, 0.035, 0.97)
@export var base_border := Color(0.32, 0.27, 0.16, 1.0)
@export var hover_border := Color(0.76, 0.50, 0.18, 1.0)
@export var focused_border := Color(0.94, 0.68, 0.28, 1.0)
@export var corner_radius := 2
@export var border_width := 1

var choice_id: StringName = &""
var def_ref: MajorChoiceDef = null
var _focused_plate := false
var _hovered := false
var _style: StyleBoxFlat

@onready var seal_label: Label = $Margin/VBox/SealLine/Seal
@onready var stage_role_label: Label = $Margin/VBox/SealLine/StageRole
@onready var title_label: Label = $Margin/VBox/Title
@onready var family_label: Label = $Margin/VBox/Family
@onready var gift_text: Label = $Margin/VBox/GiftText
@onready var price_text: Label = $Margin/VBox/PriceText
@onready var consequence_text: Label = $Margin/VBox/ConsequencePlate/Margin/VBox/ConsequenceText


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	focus_mode = Control.FOCUS_ALL
	_build_style()
	mouse_entered.connect(func() -> void:
		_hovered = true
		_update_style()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		_update_style()
	)
	pressed.connect(func() -> void:
		focused.emit(self)
	)


func set_def(definition: MajorChoiceDef, _preview: PackedStringArray, seal_index: int = 1) -> void:
	def_ref = definition
	choice_id = definition.id if definition != null else &""
	if definition == null:
		return
	seal_label.text = "%02d" % seal_index
	stage_role_label.text = "%s // %s" % [String(definition.stage).to_upper(), String(definition.offer_role).to_upper()]
	title_label.text = definition.title.to_upper()
	family_label.text = "THESIS FAMILY · %s" % String(definition.family_id).to_upper()
	gift_text.text = definition.gift_text
	price_text.text = definition.price_text
	consequence_text.text = definition.consequence_text
	tooltip_text = get_detail_text()


func set_plate_focused(value: bool) -> void:
	_focused_plate = value
	consequence_text.modulate = Color(1.0, 0.92, 0.74, 1.0) if value else Color(0.82, 0.80, 0.72, 0.88)
	_update_style()


func get_detail_text(_max_bullets: int = 999) -> String:
	if def_ref == null:
		return ""
	return "%s\n\nGIFT\n%s\n\nPRICE\n%s\n\nCONSEQUENCE\n%s" % [
		def_ref.title,
		def_ref.gift_text,
		def_ref.price_text,
		def_ref.consequence_text,
	]


func _build_style() -> void:
	_style = StyleBoxFlat.new()
	_style.bg_color = base_bg
	_style.set_border_width_all(border_width)
	_style.border_color = base_border
	_style.corner_radius_top_left = corner_radius
	_style.corner_radius_top_right = corner_radius
	_style.corner_radius_bottom_left = corner_radius
	_style.corner_radius_bottom_right = corner_radius
	_style.shadow_size = 6
	_style.shadow_offset = Vector2(3, 5)
	_style.shadow_color = Color(0, 0, 0, 0.65)
	for state in [&"normal", &"hover", &"pressed", &"focus"]:
		add_theme_stylebox_override(state, _style)
	_update_style()


func _update_style() -> void:
	if _style == null:
		return
	_style.border_color = focused_border if _focused_plate else (hover_border if _hovered else base_border)
	_style.set_border_width_all(2 if _focused_plate else border_width)
