extends Button
class_name AugmentLibraryEntry

signal requested_equip(augment_id: StringName)
signal request_reorder(from_index: int, to_index: int)

const ChamberKit := preload("res://ui/widgets/chambers/ChamberKit.gd")

@onready var icon_rect: TextureRect = $Margin/HBox/IconFrame/Icon
@onready var name_label: Label = $Margin/HBox/VBox/Name
@onready var tag_label: Label = $Margin/HBox/VBox/Tags
@onready var _blurb_label: Label = $Margin/HBox/VBox/Blurb
@onready var _state_label: Label = $Margin/HBox/State
@onready var _margin: Control = $Margin
@onready var _icon_frame: PanelContainer = $Margin/HBox/IconFrame

var augment_id: StringName = &""
var owned_index: int = -1
var allow_reorder: bool = true
var _data: AugmentData = null
var _bound_slot := -1
var _hover_tw: Tween = null

func set_data(a: AugmentData, tags: PackedStringArray = PackedStringArray()) -> void:
	_data = a
	augment_id = (a.id if a != null else &"")
	if icon_rect != null:
		icon_rect.texture = (a.icon if a != null else null)
	if name_label != null:
		name_label.text = (Global.augment_display_name(a.id) if a != null else "Unknown")
	if _blurb_label != null:
		_blurb_label.text = _blurb(a)
		_blurb_label.visible = _blurb_label.text != ""
	if tag_label != null:
		if tags.size() > 0:
			tag_label.text = "  ·  ".join(tags)
			tag_label.visible = true
		else:
			tag_label.text = ""
			tag_label.visible = false
	# The library used to show only the name — hovering now answers
	# "yes I have this, but what does it DO?"
	tooltip_text = _compose_tooltip(a)
	refresh_state()


## Re-reads whether this augment sits on a key and its level (display only).
func refresh_state() -> void:
	_bound_slot = -1
	var level := 1
	if Global != null and augment_id != StringName():
		var ids: Variant = Global.get("permanent_augment_ids")
		if ids is Array:
			_bound_slot = (ids as Array).find(augment_id)
		if Global.has_method("get_augment_level"):
			level = int(Global.get_augment_level(augment_id))
	if _state_label != null:
		var parts: PackedStringArray = []
		if _bound_slot >= 0:
			parts.append("◆ KEY %d" % (_bound_slot + 1))
		if level > 1:
			parts.append("LV %d" % level)
		_state_label.text = "\n".join(parts)
		_state_label.add_theme_color_override("font_color", ChamberKit.GOLD_BRIGHT if _bound_slot >= 0 else ChamberKit.GOLD_DIM)
	_apply_styles()


func _blurb(a: AugmentData) -> String:
	if a == null:
		return ""
	var t := a.card_blurb.strip_edges()
	if t == "":
		t = a.description.strip_edges()
	return t.replace("\n", " ")


func _compose_tooltip(a: AugmentData) -> String:
	if a == null:
		return ""
	var parts: PackedStringArray = []
	if a.card_blurb.strip_edges() != "":
		parts.append(a.card_blurb.strip_edges())
	elif a.description.strip_edges() != "":
		parts.append(a.description.strip_edges())
	if a.details.strip_edges() != "":
		parts.append(a.details.strip_edges())
	var level: int = Global.get_augment_level(a.id) if Global != null and Global.has_method("get_augment_level") else 1
	if level > 1:
		parts.append("Level %d" % level)
	return "\n\n".join(parts)

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	if _icon_frame != null:
		_icon_frame.add_theme_stylebox_override("panel", ChamberKit.shared(&"art"))
	if name_label != null:
		name_label.add_theme_color_override("font_color", ChamberKit.PARCHMENT)
	if _blurb_label != null:
		_blurb_label.add_theme_color_override("font_color", ChamberKit.MUTED)
	if tag_label != null:
		tag_label.add_theme_color_override("font_color", ChamberKit.GOLD_DIM)
	_apply_styles()
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	pressed.connect(func() -> void:
		# Single click: quick-equip (kept for convenience)
		if augment_id != StringName():
			requested_equip.emit(augment_id)
	)


func _apply_styles() -> void:
	var rest := ChamberKit.shared(&"row_bound" if _bound_slot >= 0 else &"row")
	var lit := ChamberKit.shared(&"row_hover")
	add_theme_stylebox_override("normal", rest)
	add_theme_stylebox_override("disabled", rest)
	add_theme_stylebox_override("hover", lit)
	add_theme_stylebox_override("pressed", lit)
	add_theme_stylebox_override("hover_pressed", lit)


func _on_hover(on: bool) -> void:
	if name_label != null:
		name_label.add_theme_color_override("font_color", ChamberKit.GOLD_BRIGHT if on else ChamberKit.PARCHMENT)
	if _margin == null:
		return
	if _hover_tw != null and _hover_tw.is_running():
		_hover_tw.kill()
	var target := 5.0 if on and not ChamberKit.reduced() else 0.0
	_hover_tw = ChamberKit.tween(self)
	_hover_tw.tween_property(_margin, "position:x", target, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _gui_input(event: InputEvent) -> void:
	# Double-click also equips (nice UX + avoids “Button pressed swallowed” edge cases)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click and mb.pressed:
			if augment_id != StringName():
				requested_equip.emit(augment_id)

# ------------------------------------------------------------
# Drag & drop
# Godot 4 uses _get/_can/_drop overrides (not get_drag_data)
# ------------------------------------------------------------

# Drag from library -> slot, OR reorder within library.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if augment_id == StringName():
		return null

	var d := {
		"type": &"augment",
		"augment_id": augment_id,
		"source": &"library",
		"owned_index": owned_index
	}

	set_drag_preview(_drag_preview())
	return d


## What follows the cursor: the art in its gold window and the name.
func _drag_preview() -> Control:
	var holder := Control.new()
	var plate := PanelContainer.new()
	plate.theme = ChamberKit.THEME
	plate.add_theme_stylebox_override("panel", ChamberKit.box(Color(0.05, 0.038, 0.028, 0.96), ChamberKit.GOLD, 1, 8.0, 12))
	plate.position = Vector2(-30, -30)
	plate.modulate = Color(1, 1, 1, 0.94)
	holder.add_child(plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	plate.add_child(row)
	var art := TextureRect.new()
	art.texture = icon_rect.texture if icon_rect != null else null
	art.custom_minimum_size = Vector2(48, 48)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	row.add_child(art)
	var caption := Label.new()
	caption.text = name_label.text if name_label != null else ""
	caption.theme_type_variation = &"ArcaneHeading"
	caption.add_theme_font_size_override("font_size", 16)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption)
	return holder

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not allow_reorder:
		return false
	if not (data is Dictionary):
		return false
	var d: Dictionary = data
	if d.get("type", &"") != &"augment":
		return false
	# Only reorder library items onto other library items.
	if d.get("source", &"") != &"library":
		return false
	if not d.has("owned_index"):
		return false
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var d: Dictionary = data
	var from_i: int = int(d.get("owned_index", -1))
	var to_i: int = owned_index
	if from_i < 0 or to_i < 0 or from_i == to_i:
		return
	request_reorder.emit(from_i, to_i)
