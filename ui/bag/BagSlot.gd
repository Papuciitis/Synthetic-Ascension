extends PanelContainer
class_name BagSlot

signal discard_requested(slot_index: int)
signal clicked()
signal equip_requested(slot_index: int)

const POS_TINT := Color(0.25, 1.0, 1.0, 0.18)
const NEG_TINT := Color(1.0, 0.25, 0.35, 0.28)

var slot_index: int = -1
var allow_discard: bool = false

var _stack: Variant = null
var current_inst_id: int = 0

# resolved nodes (may be null if this script is attached to a different scene)
var content: Control = null
var icon: TextureRect = null
var overlay: ColorRect = null
var meter_label: Label = null
var rarity_label: Label = null
var rolls_label: Label = null

var _pol_tint: ColorRect = null
var _pol_badge: Label = null
var _frame_sb: StyleBoxFlat = null
var _flash: ColorRect = null
var _flash_tween: Tween = null
const FLASH_COL := Color(1.0, 0.55, 0.20, 0.0) # your orange "accent"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resolve_nodes()
	_apply_mouse_passthrough()
	_ensure_polarity_ui()
	_apply_frame_style()

	mouse_entered.connect(func(): _set_hover(true))
	mouse_exited.connect(func(): _set_hover(false))

func _resolve_nodes() -> void:
	content = get_node_or_null("Content") as Control
	if content == null:
		content = self

	icon = content.get_node_or_null("Icon") as TextureRect
	overlay = content.get_node_or_null("RarityOverlay") as ColorRect
	meter_label = content.get_node_or_null("Meter") as Label
	rarity_label = content.get_node_or_null("Rarity") as Label
	rolls_label = content.get_node_or_null("Rolls") as Label

func _apply_mouse_passthrough() -> void:
	# Only the PanelContainer itself should take clicks
	if content != null: content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != null: icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if overlay != null: overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if meter_label != null: meter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rarity_label != null: rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rolls_label != null: rolls_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _pol_tint != null: _pol_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _pol_badge != null: _pol_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply_frame_style() -> void:
	_frame_sb = StyleBoxFlat.new()
	_frame_sb.bg_color = Color(0.08, 0.08, 0.08, 0.88)
	_frame_sb.border_color = Color(0.12, 0.12, 0.12, 1.0)
	_frame_sb.set_border_width_all(2)
	_frame_sb.corner_radius_top_left = 12
	_frame_sb.corner_radius_top_right = 12
	_frame_sb.corner_radius_bottom_left = 12
	_frame_sb.corner_radius_bottom_right = 12
	add_theme_stylebox_override("panel", _frame_sb)

func _set_hover(on: bool) -> void:
	if _frame_sb == null:
		return
	var strong: bool = on and _stack != null
	_frame_sb.border_color = (Color(1.0, 0.55, 0.20, 1.0) if strong else Color(0.12, 0.12, 0.12, 1.0))

func set_stack(stack: Variant, idx: int, can_discard: bool, is_ghost: bool = false) -> void:
	# IMPORTANT: if this script is used on some other node tree, don't crash
	_resolve_nodes()
	_ensure_polarity_ui()
	_apply_mouse_passthrough()

	# ghost look (fade whole slot)
	modulate = (Color(1, 1, 1, 0.45) if is_ghost else Color(1, 1, 1, 1))

	if has_meta("item_instance"):
		remove_meta("item_instance")

	_stack = stack
	slot_index = idx
	allow_discard = can_discard
	current_inst_id = (int((_stack as Object).get_instance_id()) if (_stack is Object) else 0)

	# resolve data safely
	var data: Variant = null
	if _stack is Object:
		data = (_stack as Object).get("data")
	elif _stack is Dictionary:
		data = (_stack as Dictionary).get("data", null)

	# empty slot
	if _stack == null or data == null:
		if icon != null:
			icon.texture = null
			icon.visible = false
			icon.modulate = Color(1, 1, 1, 1)

		if meter_label != null: meter_label.text = ""
		if rarity_label != null: rarity_label.text = ""
		if rolls_label != null: rolls_label.text = ""
		if overlay != null: overlay.color = Color(0, 0, 0, 0)
		tooltip_text = ""

		if _pol_tint != null: _pol_tint.color = Color(0, 0, 0, 0)
		if _pol_badge != null: _pol_badge.text = ""
		modulate = Color(1, 1, 1, 1)
		return

	# keep meta for tooltip
	set_meta("item_instance", _stack)

	# icon safely
	var tex: Texture2D = null
	var vtex: Variant = null
	if data is Object:
		vtex = (data as Object).get("icon")
	elif data is Dictionary:
		vtex = (data as Dictionary).get("icon", null)

	if vtex is Texture2D:
		tex = vtex as Texture2D

	if icon != null:
		icon.texture = tex
		icon.visible = (tex != null)
		icon.modulate = Color(1, 1, 1, 1)

	# polarity (optional)
	var pol: int = 0
	if _stack is Object:
		pol = int((_stack as Object).get("polarity"))
	elif _stack is Dictionary:
		pol = int((_stack as Dictionary).get("polarity", 0))

	var is_pos: bool = (pol == int(ItemInstance.Polarity.POS))
	if _pol_tint != null:
		_pol_tint.color = (POS_TINT if is_pos else NEG_TINT)
	if _pol_badge != null:
		_pol_badge.text = ("+" if is_pos else "−")

	tooltip_text = "" # HUD handles tooltip

	# meter/rarity/rolls (optional)
	var meter: float = 0.0
	if _stack is Object:
		var mv: Variant = (_stack as Object).get("upgrade_meter")
		if mv is float or mv is int:
			meter = float(mv)

	var pct: int = int(round(clampf(meter, 0.0, 1.0) * 100.0))
	if meter_label != null:
		meter_label.text = "%d%%" % pct

	var rar: int = 0
	var prog: int = 0
	if _stack is Object:
		rar = int((_stack as Object).get("rarity"))
		prog = int((_stack as Object).get("progress"))
	elif _stack is Dictionary:
		rar = int((_stack as Dictionary).get("rarity", 0))
		prog = int((_stack as Dictionary).get("progress", 0))

	if rarity_label != null:
		rarity_label.text = "r%d" % rar
	if rolls_label != null:
		rolls_label.text = "x%d" % prog
	if overlay != null:
		overlay.color = _rarity_to_color(rar)

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return

	if mb.button_index == MOUSE_BUTTON_LEFT:
		if slot_index >= 0:
			equip_requested.emit(slot_index)
		else:
			clicked.emit()

	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if slot_index >= 0:
			if allow_discard and mb.shift_pressed:
				discard_requested.emit(slot_index)
			else:
				equip_requested.emit(slot_index)
		else:
			clicked.emit()

func _rarity_to_color(r: int) -> Color:
	var a: float = 0.18
	if r <= -2: return Color(0.45, 0.0, 0.0, a)
	if r == -1: return Color(0.75, 0.1, 0.1, a)
	if r == 0:  return Color(0, 0, 0, 0)
	if r == 1:  return Color(0.2, 0.9, 0.2, a)
	if r == 2:  return Color(0.25, 0.45, 1.0, a)
	if r == 3:  return Color(0.7, 0.25, 0.95, a)
	return Color(1.0, 0.65, 0.15, a)

func _ensure_polarity_ui() -> void:
	if content == null:
		_resolve_nodes()
	if content == null:
		return

	# only set z_index if the nodes exist
	if icon != null: icon.z_index = 0
	if overlay != null: overlay.z_index = 2
	if meter_label != null: meter_label.z_index = 3
	if rarity_label != null: rarity_label.z_index = 3
	if rolls_label != null: rolls_label.z_index = 3

	_pol_tint = content.get_node_or_null("PolTint") as ColorRect
	if _pol_tint == null:
		_pol_tint = ColorRect.new()
		_pol_tint.name = "PolTint"
		_pol_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pol_tint.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		_pol_tint.color = Color(0, 0, 0, 0)
		_pol_tint.z_index = 1
		content.add_child(_pol_tint)

	_pol_badge = content.get_node_or_null("PolBadge") as Label
	if _pol_badge == null:
		_pol_badge = Label.new()
		_pol_badge.name = "PolBadge"
		_pol_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pol_badge.text = ""
		_pol_badge.z_index = 3
		content.add_child(_pol_badge)

		_pol_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
		_pol_badge.custom_minimum_size = Vector2(16, 16)
		_pol_badge.offset_right = -4
		_pol_badge.offset_left = _pol_badge.offset_right - 16
		_pol_badge.offset_top = 2
		_pol_badge.offset_bottom = _pol_badge.offset_top + 16
		_pol_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_pol_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _ensure_flash_ui() -> void:
	if content == null:
		_resolve_nodes()
	if content == null:
		return

	_flash = content.get_node_or_null("Flash") as ColorRect
	if _flash == null:
		_flash = ColorRect.new()
		_flash.name = "Flash"
		_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		_flash.color = FLASH_COL
		_flash.z_index = 20
		content.add_child(_flash)

func play_merge_flash(strong: bool = false) -> void:
	_ensure_flash_ui()
	if _flash == null:
		return

	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()

	var a0: float = (0.60 if strong else 0.38)
	_flash.color = Color(FLASH_COL.r, FLASH_COL.g, FLASH_COL.b, a0)

	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.20)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
