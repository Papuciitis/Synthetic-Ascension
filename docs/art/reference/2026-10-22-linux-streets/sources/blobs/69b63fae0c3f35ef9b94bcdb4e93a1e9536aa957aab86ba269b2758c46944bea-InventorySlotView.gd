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

var _rarity_edge: ColorRect = null
var _rarity_lbl: Label = null
var _empty_mark: Control = null
var _set_emblem: SetEmblem = null
var _lock_badge: Label = null
var _lock_border: Panel = null
var _manifest_badge: ManifestBadge = null

var _shown_rarity: int = 0

const HudStyle := preload("res://ui/widgets/hud/HudStyle.gd")

const ICON_PAD := 4
const BORDER_W := 1
const BOTTOM_H := 15

# A curse is shaded faintly toward the danger red; a blessing is left clean,
# so the HD art reads without a coloured film over it.
const POS_TINT := Color(0.0, 0.0, 0.0, 0.0)
const NEG_TINT := Color(0.86, 0.32, 0.24, 0.13)

const METER_BG := Color(0, 0, 0, 0.35)
const ORANGE := Color(0.86, 0.64, 0.36, 0.95)
const METER_POS := Color(0.99, 0.84, 0.58, 0.98)
const METER_NEG := Color(0.95, 0.4, 0.3, 0.95)

# The value label while the Inversion Lens is returning this slot's severity
# as a bonus: the arcane accent, because the number is the Lens's magic.
const VALUE_RETURNED := Color(0.6, 0.78, 1.0, 1.0)
const HINT_TINT := Color(0.72, 0.58, 0.40, 0.85)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The art is cut larger than the well (128-256 px) and drawn down to it:
	# mipmapped filtering keeps the downscale clean.
	if icon != null:
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

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
	# Small lining figures with a dark rim: they sit over the art.
	for lbl: Label in [value_label, count_label]:
		if lbl == null:
			continue
		lbl.theme_type_variation = &"HudFigure"
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_constant_override("outline_size", 3)
	if bottom_bg != null:
		bottom_bg.color = Color(0.02, 0.016, 0.012, 0.66)
		bottom_bg.offset_top = -float(BOTTOM_H + BORDER_W)
		bottom_bg.offset_bottom = -float(BORDER_W)
	if bottom_row != null:
		bottom_row.offset_top = -float(BOTTOM_H + BORDER_W)
		bottom_row.offset_bottom = -float(BORDER_W)

func _apply_insets() -> void:
	var left := BORDER_W + ICON_PAD
	var top := BORDER_W + ICON_PAD
	var right := -(BORDER_W + ICON_PAD)

	# The art keeps the whole well; the figure strip sits translucent over its foot.
	if icon != null:
		icon.offset_left = left
		icon.offset_top = top
		icon.offset_right = right
		icon.offset_bottom = -(BORDER_W + ICON_PAD)

	# Overlays/tints should NOT affect the bottom strip
	var overlay_bottom := -(BOTTOM_H + BORDER_W)

	if overlay != null:
		overlay.offset_left = BORDER_W
		overlay.offset_top = BORDER_W
		overlay.offset_right = -BORDER_W
		overlay.offset_bottom = overlay_bottom

	if _pol_tint != null:
		_pol_tint.offset_left = BORDER_W
		_pol_tint.offset_top = BORDER_W
		_pol_tint.offset_right = -BORDER_W
		_pol_tint.offset_bottom = overlay_bottom

	# Bottom strip insets (keeps it inside the frame)
	if bottom_bg != null:
		bottom_bg.offset_left = BORDER_W
		bottom_bg.offset_right = -BORDER_W
	if bottom_row != null:
		bottom_row.offset_left = 4
		bottom_row.offset_right = -4

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
	_meter_bg.offset_top = 0
	_meter_bg.offset_bottom = 2
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

	# Rarity: a thin edge in the rarity's colour along the foot of the well
	# (the Gear & Stash mark) and the small "r2" figure in the top corner.
	_rarity_edge = content.get_node_or_null("RarityEdge") as ColorRect
	if _rarity_edge == null:
		_rarity_edge = ColorRect.new()
		_rarity_edge.name = "RarityEdge"
		_rarity_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(_rarity_edge)
	_rarity_edge.z_index = 12
	_rarity_edge.anchor_left = 0.0
	_rarity_edge.anchor_top = 1.0
	_rarity_edge.anchor_right = 1.0
	_rarity_edge.anchor_bottom = 1.0
	_rarity_edge.offset_left = BORDER_W
	_rarity_edge.offset_right = -BORDER_W
	_rarity_edge.offset_top = -(BORDER_W + 2)
	_rarity_edge.offset_bottom = -BORDER_W
	_rarity_edge.visible = false

	_empty_mark = content.get_node_or_null("EmptyMark") as Control
	if _empty_mark == null:
		_empty_mark = Control.new()
		_empty_mark.name = "EmptyMark"
		_empty_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_empty_mark.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		_empty_mark.draw.connect(_draw_empty_mark)
		content.add_child(_empty_mark)

	_rarity_lbl = content.get_node_or_null("RarityCornerLbl") as Label
	if _rarity_lbl == null:
		_rarity_lbl = Label.new()
		_rarity_lbl.name = "RarityCornerLbl"
		_rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rarity_lbl.theme_type_variation = &"HudFigure"
		_rarity_lbl.add_theme_font_size_override("font_size", 9)
		_rarity_lbl.add_theme_constant_override("outline_size", 3)
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
	if _rarity_edge != null:
		_rarity_edge.visible = false
	if _rarity_lbl != null:
		_rarity_lbl.visible = false
		_rarity_lbl.text = ""

func _show_rarity_corner(r: int) -> void:
	_shown_rarity = r
	var colour := HudStyle.rarity_colour(r)
	if _rarity_edge != null:
		_rarity_edge.color = Color(colour, 0.9)
		_rarity_edge.visible = true
	if _rarity_lbl != null:
		_rarity_lbl.visible = true
		_rarity_lbl.text = "r%d" % r
		_rarity_lbl.position = Vector2(BORDER_W + 3, BORDER_W + 1)
		_rarity_lbl.add_theme_color_override("font_color", colour.lerp(HudStyle.PARCHMENT, 0.35))


## Whether an EMPTY slot shows its engraved diamond. A screen that shows a
## slot as empty while its item sits elsewhere (the Exchange's cart ghost)
## turns it off so the mark does not cut through the ghost.
func set_empty_mark(on: bool) -> void:
	if _empty_mark != null:
		_empty_mark.visible = on and not has_meta("item_instance")


## An empty well carries a small engraved diamond, as the Exchange's do.
func _draw_empty_mark() -> void:
	if _empty_mark == null:
		return
	var c := Vector2(_empty_mark.size.x * 0.5, (_empty_mark.size.y - BOTTOM_H) * 0.5 + 1.0)
	var pts := HudStyle.diamond(c, 4.0)
	pts.append(pts[0])
	_empty_mark.draw_polyline(pts, Color(HudStyle.GOLD_DIM, 0.4), 1.0, true)


func _empty_hint() -> String:
	return slot_hint if slot_hint != "" else Inventory.slot_hint(slot_index)
	

func set_item(inst: ItemInstance) -> void:
	if has_meta("item_instance"):
		remove_meta("item_instance")

	if inst == null or inst.data == null:
		if icon != null: icon.texture = null
		if overlay != null: overlay.color = Color(0, 0, 0, 0)
		if value_label != null:
			value_label.text = _empty_hint()
			value_label.remove_theme_color_override("font_color")
			value_label.modulate = HINT_TINT
		if _empty_mark != null: _empty_mark.visible = true
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
	if _empty_mark != null:
		_empty_mark.visible = false
	if value_label != null:
		value_label.modulate = Color.WHITE
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
		# Suppression never rewrites the stored roll, so a slot the Inversion
		# Lens has switched off kept reading "-80" while contributing +44%.
		# Print what the slot pays, the way the sheet's Lens line does.
		var suppressing: BurdenSnapshot = _suppressing_snapshot(inst)
		if suppressing != null:
			value_label.text = "%+.0f" % (BurdenResolver.inverted_return(suppressing.suppressed_severity) * 100.0)
			value_label.add_theme_color_override("font_color", VALUE_RETURNED)
		else:
			value_label.text = "%+.0f" % (inst.active_pct() * 100.0)
			value_label.remove_theme_color_override("font_color")
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

## The burden snapshot when this slot's EQUIPPED instance is the one the
## Inversion Lens is suppressing; null otherwise. Resolved here rather than
## read from player.last_burden: the bar repaints on the same `changed` signal
## the stat pass recomputes on and subscribes first (game.gd binds the HUD
## before it connects the recompute), so the player's snapshot is one change
## stale at paint time. Same resolver and same equipped-instance guard as the
## tooltip's SUPPRESSED line, so a bag duplicate never claims the return.
func _suppressing_snapshot(inst: ItemInstance) -> BurdenSnapshot:
	if inst == null or int(inst.polarity) != int(ItemInstance.Polarity.NEG):
		return null
	if slot_index < 0 or slot_index >= Inventory.STAT_SLOT_COUNT:
		return null
	if Global == null or Global.run_inventory == null or Global.run_inventory.get_at(slot_index) != inst:
		return null
	var burden: BurdenSnapshot = BurdenResolver.resolve(Global.run_inventory, Global.permanent_augment_ids)
	return burden if burden.is_suppressed(slot_index) else null

func _rarity_overlay_color(r: int) -> Color:
	if r == 0:
		return Color(0, 0, 0, 0)
	return Color(HudStyle.rarity_colour(r), 0.07)


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
		_lock_badge.theme_type_variation = &"HudFigure"
		_lock_badge.add_theme_font_size_override("font_size", 9)
		_lock_badge.add_theme_color_override("font_color", HudStyle.GOLD_BRIGHT)
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
	# Between the set emblem (y 5..21) and the figure strip (from y 34), a size
	# smaller than the bag's, so its foot never sits on the count.
	_manifest_badge = ManifestBadge.attach(content, Control.PRESET_TOP_RIGHT, Rect2(-19, 19, 14, 14), 25, 11)


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
		style.border_color = Color(HudStyle.GOLD_BRIGHT, 0.9)
		style.set_border_width_all(2)
		style.set_corner_radius_all(1)
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
