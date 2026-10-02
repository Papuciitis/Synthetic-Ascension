extends Button
class_name AugmentEquipSlot

signal drop_received(slot_index: int, data: Dictionary)
signal unequip_requested(slot_index: int)
signal lock_toggled(slot_index: int, locked: bool)

const ChamberKit := preload("res://ui/widgets/chambers/ChamberKit.gd")

@export var slot_index: int = 0
@export var key_text: String = "1"

@onready var key_label: Label = $Margin/VBox/Header/Key
@onready var name_label: Label = $Margin/VBox/Header/Name
@onready var btn_lock: Button = $Margin/VBox/Header/BtnLock
@onready var icon_rect: TextureRect = $Margin/VBox/IconFrame/Icon
@onready var hint_label: Label = $Margin/VBox/Hint
@onready var _blurb_label: Label = $Margin/VBox/IconFrame/Blurb
@onready var _frame: Control = $Frame
@onready var _art_frame: Control = $Margin/VBox/IconFrame/Icon/ArtFrame

var augment_id: StringName = &""
var locked: bool = false
var _data: AugmentData = null
var _hovered := false
var _drop_hot := false
var _glow_tw: Tween = null
var _bind_tw: Tween = null
var _empty_mark: Control = null
var _shown_id: StringName = &""
var _shown_once := false

func set_locked(v: bool) -> void:
	locked = v
	if btn_lock != null:
		btn_lock.button_pressed = locked
		btn_lock.text = ("UNLOCK" if locked else "LOCK")
		btn_lock.modulate = Color.WHITE
	_update_glow()

func set_data(a: AugmentData) -> void:
	_data = a
	augment_id = (a.id if a != null else &"")
	if key_label != null:
		key_label.text = "KEY " + key_text
	if name_label != null:
		name_label.text = (a.display_name if a != null else "Empty Key")
		name_label.add_theme_color_override("font_color", ChamberKit.PARCHMENT if a != null else ChamberKit.MUTED)
	if icon_rect != null:
		icon_rect.texture = (a.icon if a != null else null)
	if _empty_mark != null:
		_empty_mark.visible = a == null
	if _blurb_label != null:
		var blurb := ""
		if a != null:
			blurb = a.card_blurb.strip_edges()
			if blurb == "":
				blurb = a.description.strip_edges()
		_blurb_label.text = blurb.replace("\n", " ") if a != null else "An unbound key. Its power waits for an augment."
		_blurb_label.add_theme_color_override("font_color", ChamberKit.BODY if a != null else Color(ChamberKit.MUTED, 0.75))
	if hint_label != null:
		if locked:
			hint_label.text = "Locked (unlock to modify)"
			hint_label.modulate = Color(1, 1, 1, 0.7)
		else:
			hint_label.text = ("Right-click to unequip" if a != null else "Drop an augment here")
			hint_label.modulate = Color(1, 1, 1, 0.75 if a != null else 0.6)
	_update_glow()
	# A newly bound augment is marked by a brief flare of the key.
	if _shown_once and augment_id != StringName() and augment_id != _shown_id:
		_bind_flash()
	_shown_id = augment_id
	_shown_once = true


func _bind_flash() -> void:
	if not is_inside_tree() or icon_rect == null or _frame == null:
		return
	if _bind_tw != null and _bind_tw.is_running():
		_bind_tw.kill()
	if _glow_tw != null and _glow_tw.is_running():
		_glow_tw.kill()
	var rest := 0.65 if _hovered else (0.32 if locked else 0.0)
	_frame.set("glow", 1.0)
	icon_rect.modulate = Color(1.7, 1.45, 1.1)
	_bind_tw = ChamberKit.tween(self).set_parallel(true)
	_bind_tw.tween_property(_frame, "glow", rest, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_bind_tw.tween_property(icon_rect, "modulate", Color.WHITE, 0.55).set_trans(Tween.TRANS_SINE)
	if not ChamberKit.reduced():
		icon_rect.pivot_offset = icon_rect.size * 0.5
		icon_rect.scale = Vector2.ONE * 1.14
		_bind_tw.tween_property(icon_rect, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_dress()
	if btn_lock != null:
		btn_lock.focus_mode = Control.FOCUS_NONE
		btn_lock.toggled.connect(func(v: bool) -> void:
			set_locked(v)
			lock_toggled.emit(slot_index, v)
		)
	mouse_entered.connect(func() -> void:
		_hovered = true
		_update_glow()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		_drop_hot = false
		_update_glow()
	)


# ------------------------------------------------------------
# Presentation
# ------------------------------------------------------------

func _dress() -> void:
	var rest := ChamberKit.box(Color(0.03, 0.026, 0.022, 0.94), Color(0, 0, 0, 0), 0)
	var lit := ChamberKit.box(Color(0.06, 0.044, 0.03, 0.97), Color(0, 0, 0, 0), 0)
	for state in [&"normal", &"disabled"]:
		add_theme_stylebox_override(state, rest)
	for state in [&"hover", &"pressed", &"hover_pressed"]:
		add_theme_stylebox_override(state, lit)
	if key_label != null:
		key_label.add_theme_stylebox_override("normal", ChamberKit.shared(&"keycap"))
		key_label.add_theme_color_override("font_color", ChamberKit.GOLD_BRIGHT)
	if hint_label != null:
		hint_label.add_theme_color_override("font_color", ChamberKit.MUTED)
	if btn_lock != null:
		btn_lock.add_theme_stylebox_override("normal", ChamberKit.shared(&"toggle"))
		btn_lock.add_theme_stylebox_override("hover", ChamberKit.shared(&"toggle_hover"))
		btn_lock.add_theme_stylebox_override("pressed", ChamberKit.shared(&"toggle_on"))
		btn_lock.add_theme_stylebox_override("hover_pressed", ChamberKit.shared(&"toggle_on"))
		btn_lock.add_theme_stylebox_override("focus", ChamberKit.shared(&"empty"))
		btn_lock.add_theme_color_override("font_color", ChamberKit.MUTED)
	if icon_rect != null:
		_empty_mark = Control.new()
		_empty_mark.name = "EmptyMark"
		_empty_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_empty_mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_empty_mark.draw.connect(_draw_empty_mark)
		icon_rect.add_child(_empty_mark)
		icon_rect.move_child(_empty_mark, 0)
		_empty_mark.visible = icon_rect.texture == null


## An unbound key: a dark well with a faint keyhole diamond.
func _draw_empty_mark() -> void:
	var s := _empty_mark.size
	_empty_mark.draw_rect(Rect2(Vector2.ZERO, s), Color(0.012, 0.011, 0.01, 0.95))
	var c := s * 0.5
	var col := Color(ChamberKit.GOLD_DIM, 0.55)
	for r in [16.0, 9.0]:
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)])
		_empty_mark.draw_polyline(pts, Color(col, col.a * (1.0 if r > 10.0 else 0.6)), 1.0, true)
	_empty_mark.draw_line(c + Vector2(0, -28), c + Vector2(0, -19), Color(col, 0.35), 1.0, true)
	_empty_mark.draw_line(c + Vector2(0, 19), c + Vector2(0, 28), Color(col, 0.35), 1.0, true)


## The frame warms on hover, stays warm while locked, and burns brightest
## while an augment is held over it.
func _update_glow() -> void:
	if _frame == null:
		return
	var target := 0.0
	if _drop_hot:
		target = 1.0
	elif _hovered:
		target = 0.65
	elif locked:
		target = 0.32
	if _art_frame != null:
		_art_frame.set("glow", 0.8 if (_hovered or _drop_hot) else 0.0)
	if _bind_tw != null and _bind_tw.is_running() and (_hovered or _drop_hot):
		# The cursor takes over from a bind flare still settling.
		_bind_tw.kill()
		if icon_rect != null:
			icon_rect.modulate = Color.WHITE
			icon_rect.scale = Vector2.ONE
	elif _bind_tw != null and _bind_tw.is_running():
		return
	if _glow_tw != null and _glow_tw.is_running():
		_glow_tw.kill()
	var now := float(_frame.get("glow"))
	if is_equal_approx(now, target):
		return
	if ChamberKit.reduced() or not is_inside_tree():
		_frame.set("glow", target)
		return
	_glow_tw = ChamberKit.tween(self)
	_glow_tw.tween_property(_frame, "glow", target, 0.16)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drop_hot:
		_drop_hot = false
		_update_glow()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if augment_id != StringName() and not locked:
				unequip_requested.emit(slot_index)

# ------------------------------------------------------------
# Drag & drop (Godot 4 virtuals: _get/_can/_drop)
# ------------------------------------------------------------

# Drag from slot -> another slot
func _get_drag_data(_at_position: Vector2) -> Variant:
	if augment_id == StringName() or locked:
		return null
	var d := {
		"type": &"augment",
		"augment_id": augment_id,
		"source": &"slot",
		"slot": slot_index
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
	if locked:
		return false
	if not (data is Dictionary):
		return false
	var d: Dictionary = data
	if d.get("type", &"") != &"augment":
		return false
	if not _drop_hot:
		_drop_hot = true
		_update_glow()
	return true

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if locked:
		return
	_drop_hot = false
	_update_glow()
	if data is Dictionary:
		drop_received.emit(slot_index, data)
