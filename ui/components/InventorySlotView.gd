extends PanelContainer
class_name InventorySlotView

signal clicked(slot: int, button: int, double_click: bool, shift: bool)

@export var slot_index: int = -1
@export var slot_hint: String = ""
var drag_host: Node = null

@onready var content: Control = get_node_or_null("Content") as Control
@onready var icon: TextureRect = get_node_or_null("Content/Icon") as TextureRect
@onready var overlay: ColorRect = get_node_or_null("Content/RarityOverlay") as ColorRect
@onready var value_label: Label = get_node_or_null("Content/Bottom/Value") as Label
@onready var count_label: Label = get_node_or_null("Content/Bottom/Count") as Label
@onready var bottom_bg: ColorRect = get_node_or_null("Content/BottomBG") as ColorRect
@onready var bottom_row: Control = get_node_or_null("Content/Bottom") as Control

var _pol_tint: ColorRect = null
var _meter_bg: ColorRect = null
var _meter_fill: ColorRect = null

var _rarity_tri_bg: Polygon2D = null
var _rarity_tri: Polygon2D = null
var _rarity_lbl: Label = null
var _set_emblem: SetEmblem = null
var _lock_badge: Label = null
var _lock_border: Panel = null
var _manifest_badge: ManifestBadge = null

var _shown_rarity: int = 0

const ICON_PAD := 4
const BORDER_W := 2
const BOTTOM_H := 18

# Keep these subtle so the slot doesn't get “muddy”
const POS_TINT := Color(0.25, 1.0, 1.0, 0.12)
const NEG_TINT := Color(1.0, 0.35, 0.55, 0.14)

const METER_BG := Color(0, 0, 0, 0.22)
const ORANGE := Color(1.0, 0.55, 0.20, 0.90)
const METER_POS := Color(0.25, 1.0, 1.0, 0.92)
const METER_NEG := Color(1.0, 0.35, 0.55, 0.92)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	_ensure_optional_ui()
	_ensure_lock_badge()
	_ensure_manifest_badge()
	_ensure_lock_border()
	_apply_text_style()
	_apply_insets()

	resized.connect(func():
		_apply_insets()
		if _shown_rarity != 0:
			_show_rarity_corner(_shown_rarity)
	)

# ✅ THIS is the important part:
	if content != null:
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_force_mouse_passthrough_recursive(content if content != null else self)

func _force_mouse_passthrough_recursive(n: Node) -> void:
	if n == null:
		return

	for c in n.get_children():
		var ctrl := c as Control
		if ctrl != null:
			ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_force_mouse_passthrough_recursive(c)

func _apply_text_style() -> void:
	# Smaller + calmer. (These get drawn over icons; big fonts feel “cluttered”.)
	if value_label != null:
		value_label.add_theme_font_size_override("font_size", 11)
		value_label.modulate = Color(1, 1, 1, 0.86)
	if count_label != null:
		count_label.add_theme_font_size_override("font_size", 11)
		count_label.modulate = Color(1, 1, 1, 0.86)

func _apply_insets() -> void:
	var left := BORDER_W + ICON_PAD
	var top := BORDER_W + ICON_PAD
	var right := -(BORDER_W + ICON_PAD)

	# Icon stays BIG (goes under bottom strip)
	if icon != null:
		icon.offset_left = left
		icon.offset_top = top
		icon.offset_right = right
		icon.offset_bottom = -(BORDER_W + ICON_PAD)

	# Overlays/tints should NOT affect the bottom strip
	var overlay_bottom := -(BOTTOM_H + BORDER_W + ICON_PAD)

	if overlay != null:
		overlay.offset_left = left
		overlay.offset_top = top
		overlay.offset_right = right
		overlay.offset_bottom = overlay_bottom

	if _pol_tint != null:
		_pol_tint.offset_left = left
		_pol_tint.offset_top = top
		_pol_tint.offset_right = right
		_pol_tint.offset_bottom = overlay_bottom

	# Bottom strip insets (keeps it inside the frame)
	if bottom_bg != null:
		bottom_bg.offset_left = 2
		bottom_bg.offset_right = -2
	if bottom_row != null:
		bottom_row.offset_left = 2
		bottom_row.offset_right = -2

func _ensure_optional_ui() -> void:
	if content == null:
		content = self

	if icon != null: icon.z_index = 0
	if overlay != null: overlay.z_index = 1

	_pol_tint = content.get_node_or_null("PolTint") as ColorRect
	if _pol_tint == null:
		_pol_tint = ColorRect.new()
		_pol_tint.name = "PolTint"
		_pol_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pol_tint.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		content.add_child(_pol_tint)
	_pol_tint.z_index = 2
	_pol_tint.color = Color(0, 0, 0, 0)

	# Upgrade bar lives in BottomBG (looks intentional)
	var bar_parent: Control = bottom_bg if bottom_bg != null else content

	_meter_bg = bar_parent.get_node_or_null("UpgradeBG") as ColorRect
	if _meter_bg == null:
		_meter_bg = ColorRect.new()
		_meter_bg.name = "UpgradeBG"
		_meter_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_meter_bg.color = METER_BG
		bar_parent.add_child(_meter_bg)

	_meter_bg.z_index = 10
	_meter_bg.set_anchors_preset(Control.PRESET_TOP_WIDE, true)
	_meter_bg.offset_left = 3
	_meter_bg.offset_right = -3
	_meter_bg.offset_top = 2
	_meter_bg.offset_bottom = 6
	_meter_bg.visible = false

	_meter_fill = _meter_bg.get_node_or_null("UpgradeFill") as ColorRect
	if _meter_fill == null:
		_meter_fill = ColorRect.new()
		_meter_fill.name = "UpgradeFill"
		_meter_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_meter_fill.anchor_left = 0.0
		_meter_fill.anchor_top = 0.0
		_meter_fill.anchor_bottom = 1.0
		_meter_fill.anchor_right = 0.0
		_meter_bg.add_child(_meter_fill)

	_meter_fill.z_index = 11
	_meter_fill.anchor_right = 0.0

	# Corner rarity marker (soft “wedge”, inset so it respects rounded corners)
	_rarity_tri_bg = content.get_node_or_null("RarityTriBG") as Polygon2D
	if _rarity_tri_bg == null:
		_rarity_tri_bg = Polygon2D.new()
		_rarity_tri_bg.name = "RarityTriBG"
		_rarity_tri_bg.z_index = 20
		content.add_child(_rarity_tri_bg)
	_rarity_tri_bg.position = Vector2.ZERO

	_rarity_tri = content.get_node_or_null("RarityTri") as Polygon2D
	if _rarity_tri == null:
		_rarity_tri = Polygon2D.new()
		_rarity_tri.name = "RarityTri"
		_rarity_tri.z_index = 21
		content.add_child(_rarity_tri)
	_rarity_tri.position = Vector2.ZERO

	_try_set_node_bool_property(_rarity_tri_bg, &"antialiased", true)
	_try_set_node_bool_property(_rarity_tri, &"antialiased", true)


	_rarity_lbl = content.get_node_or_null("RarityCornerLbl") as Label
	if _rarity_lbl == null:
		_rarity_lbl = Label.new()
		_rarity_lbl.name = "RarityCornerLbl"
		_rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rarity_lbl.add_theme_font_size_override("font_size", 9)
		_rarity_lbl.modulate = Color(1, 1, 1, 0.92)
		content.add_child(_rarity_lbl)

	_rarity_lbl.z_index = 22
	_rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_rarity_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_rarity_lbl.visible = false

	_hide_rarity_corner()

	_set_emblem = content.get_node_or_null("SetEmblem") as SetEmblem
	if _set_emblem == null:
		_set_emblem = SetEmblem.new()
		_set_emblem.name = "SetEmblem"
		content.add_child(_set_emblem)
	_set_emblem.z_index = 24
	_set_emblem.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	_set_emblem.offset_left = -21.0
	_set_emblem.offset_top = 5.0
	_set_emblem.offset_right = -5.0
	_set_emblem.offset_bottom = 21.0
	_set_emblem.configure(&"")

func _hide_rarity_corner() -> void:
	_shown_rarity = 0
	if _rarity_tri_bg != null:
		_rarity_tri_bg.visible = false
	if _rarity_tri != null:
		_rarity_tri.visible = false
	if _rarity_lbl != null:
		_rarity_lbl.visible = false
		_rarity_lbl.text = ""

func _show_rarity_corner(r: int) -> void:
	_shown_rarity = r

	# Inset so it doesn't fight the rounded corner
	var inset: float = 7.0
	var radius: float = 18.0
	var segments: int = 14  # more = smoother curve

	var cx: float = float(BORDER_W) + inset
	var cy: float = float(BORDER_W) + inset
	var center: Vector2 = Vector2(cx, cy)

	# Background wedge (slightly larger) for depth/contrast
	var bg_pts: PackedVector2Array = _make_corner_wedge_points(center, radius + 2.0, segments)
	var fg_pts: PackedVector2Array = _make_corner_wedge_points(center, radius, segments)

	var fg: Color = _rarity_corner_color(r)

	# BG wedge: tinted darker version (NOT pure black)
	var bg: Color = fg.lerp(Color(0, 0, 0, 1), 0.65)
	bg.a = 0.22

	if _rarity_tri_bg != null:
		_rarity_tri_bg.polygon = bg_pts
		_rarity_tri_bg.color = bg
		_rarity_tri_bg.visible = true

	if _rarity_tri != null:
		_rarity_tri.polygon = fg_pts
		_rarity_tri.color = fg
		_rarity_tri.visible = true

	if _rarity_lbl != null:
		_rarity_lbl.visible = true
		_rarity_lbl.text = "r%d" % r
		_rarity_lbl.position = center + Vector2(4.0, 2.0)
		_rarity_lbl.modulate = Color(1, 1, 1, 0.75) # softer label


func _empty_hint() -> String:
	return slot_hint if slot_hint != "" else Inventory.slot_hint(slot_index)
	

func set_item(inst: ItemInstance) -> void:
	if has_meta("item_instance"):
		remove_meta("item_instance")

	if inst == null or inst.data == null:
		if icon != null: icon.texture = null
		if overlay != null: overlay.color = Color(0, 0, 0, 0)
		if value_label != null: value_label.text = _empty_hint()
		if count_label != null: count_label.text = ""
		if _pol_tint != null: _pol_tint.color = Color(0, 0, 0, 0)
		if _meter_bg != null: _meter_bg.visible = false
		if _meter_fill != null: _meter_fill.anchor_right = 0.0
		_hide_rarity_corner()
		if _set_emblem != null:
			_set_emblem.configure(&"")
		if _lock_badge != null: _lock_badge.visible = false
		if _lock_border != null: _lock_border.visible = false
		if _manifest_badge != null: _manifest_badge.visible = false
		return

	set_meta("item_instance", inst)
	# Manifestation is identity, so it needs to read at a glance from the bar -
	# the tooltip explains the rule, this only says "this one is not ordinary",
	# and its colour says which noun it speaks about.
	if _manifest_badge != null:
		_manifest_badge.show_for_item(inst)
	if _set_emblem != null:
		_set_emblem.configure(StringName(inst.data.set_id))
	if _lock_badge != null:
		_lock_badge.visible = inst.locked
	if _lock_border != null:
		_lock_border.visible = inst.locked

	if icon != null:
		icon.texture = inst.data.icon

	if value_label != null:
		value_label.text = "%+.0f" % (inst.active_pct() * 100.0)
	if count_label != null:
		count_label.text = "x%d" % int(inst.progress)

	var r := int(inst.rarity)
	if overlay != null:
		overlay.color = _rarity_overlay_color(r)

	if r != 0:
		_show_rarity_corner(r)
	else:
		_hide_rarity_corner()

	var is_pos: bool = (int(inst.polarity) == int(ItemInstance.Polarity.POS))
	if _pol_tint != null:
		_pol_tint.color = (POS_TINT if is_pos else NEG_TINT)

	var meter := clampf(float(inst.upgrade_meter), 0.0, 1.0)
	if _meter_bg != null:
		_meter_bg.visible = (meter > 0.001)
	if _meter_fill != null:
		var end_col := (METER_POS if is_pos else METER_NEG)
		_meter_fill.color = ORANGE.lerp(end_col, meter)
		_meter_fill.anchor_right = meter

func _rarity_color(r: int) -> Color:
	if r <= -2: return Color(0.45, 0.0, 0.0, 1)
	if r == -1: return Color(0.75, 0.1, 0.1, 1)
	if r == 0:  return Color(0.12, 0.12, 0.12, 1)
	if r == 1:  return Color(0.2, 0.9, 0.2, 1)
	if r == 2:  return Color(0.25, 0.45, 1.0, 1)
	if r == 3:  return Color(0.7, 0.25, 0.95, 1)
	return Color(1.0, 0.65, 0.15, 1)

func _rarity_overlay_color(r: int) -> Color:
	if r == 0:
		return Color(0, 0, 0, 0)
	var c := _rarity_color(r)
	return Color(c.r, c.g, c.b, 0.06)


func _ensure_lock_badge() -> void:
	if content == null:
		content = get_node_or_null("Content") as Control
	if content == null:
		return
	_lock_badge = content.get_node_or_null("LockBadge") as Label
	if _lock_badge == null:
		_lock_badge = Label.new()
		_lock_badge.name = "LockBadge"
		_lock_badge.text = "LOCK"
		_lock_badge.add_theme_font_size_override("font_size", 9)
		_lock_badge.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30, 1.0))
		_lock_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_lock_badge.position = Vector2(-34, 3)
		_lock_badge.size = Vector2(31, 14)
		_lock_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lock_badge.z_index = 20
		content.add_child(_lock_badge)
	_lock_badge.visible = false

func _ensure_manifest_badge() -> void:
	if content == null:
		content = get_node_or_null("Content") as Control
	if content == null:
		return
	# Directly under the set emblem, so the two never overlap.
	_manifest_badge = ManifestBadge.attach(content, Control.PRESET_TOP_RIGHT, Rect2(-20, 22, 16, 14))


func _ensure_lock_border() -> void:
	if _lock_border != null:
		return
	_lock_border = get_node_or_null("LockBorder") as Panel
	if _lock_border == null:
		_lock_border = Panel.new()
		_lock_border.name = "LockBorder"
		_lock_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lock_border.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		_lock_border.z_index = 30
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.border_color = Color(1.0, 0.72, 0.22, 0.95)
		style.set_border_width_all(2)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		_lock_border.add_theme_stylebox_override("panel", style)
		add_child(_lock_border)
	_lock_border.visible = false

func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	clicked.emit(slot_index, mb.button_index, mb.double_click, mb.shift_pressed)

func _get_drag_data(_at_position: Vector2) -> Variant:
	var inst: ItemInstance = get_meta("item_instance", null) as ItemInstance
	if inst == null or inst.data == null or inst.locked:
		return null
	var payload := {"kind": 0, "idx": slot_index} # HubItemSlot.Kind.EQUIPPED
	if icon != null and icon.texture != null:
		var preview := TextureRect.new()
		preview.texture = icon.texture
		preview.custom_minimum_size = Vector2(48, 48)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		set_drag_preview(preview)
	return payload

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return drag_host != null and data is Dictionary and drag_host.has_method("can_drop_item") and bool(drag_host.call("can_drop_item", data, 0, slot_index))

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if drag_host != null and data is Dictionary and drag_host.has_method("handle_drop_item"):
		drag_host.call("handle_drop_item", data, 0, slot_index)

func _try_set_node_bool_property(obj: Object, prop: StringName, value: bool) -> void:
	if obj == null:
		return
	for d in obj.get_property_list():
		var dd: Dictionary = d
		if StringName(dd.get("name", "")) == prop:
			obj.set(prop, value)
			return

func _make_corner_wedge_points(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(center) # fan center

	var segs: int = maxi(4, segments)
	for i in range(segs + 1):
		var t: float = float(i) / float(segs)
		var ang: float = t * (PI * 0.5) # 0..90 degrees
		var p: Vector2 = center + Vector2(cos(ang), sin(ang)) * radius
		pts.append(p)

	return pts

const CORNER_BASE := Color(0.12, 0.12, 0.12, 1.0) # matches your slot border vibe

func _rarity_corner_color(r: int) -> Color:
	var c: Color = _rarity_color(r)

	# mute saturation + slightly reduce brightness
	var h: float = c.h
	var s: float = c.s * 0.55
	var v: float = c.v * 0.85
	var soft: Color = Color.from_hsv(h, s, v, 1.0)

	# blend toward your dark UI base so it fits the theme
	soft = soft.lerp(CORNER_BASE, 0.35)

	# final alpha (subtle)
	soft.a = 0.55
	return soft
