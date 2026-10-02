extends PanelContainer
class_name AugmentTooltip
## An augment on hover (the HUD's augment row) in the same register as the
## item dossier: a square gold-ruled panel, the icon in a well, a Cinzel name,
## Garamond body. Looks are set once in _ready.

const OverlayKit := preload("res://ui/widgets/overlays/OverlayKit.gd")

var icon: TextureRect = null
var name_label: Label = null
var body_label: Label = null
var icon_frame: PanelContainer = null

var _style: StyleBox
var _icon_style: StyleBox

const BORDER: Color = OverlayKit.GOLD_DIM
const BG: Color = Color(0.028, 0.024, 0.021, 0.97)
const TOOLTIP_WIDTH: float = 360.0
## TOOLTIP_WIDTH less the Margin container's 15 + 15.
const BODY_WIDTH: float = 330.0

var _layout_ticket: int = 0

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0.0)
	size = Vector2(TOOLTIP_WIDTH, 1.0)
	_resolve_nodes()
	_build_styles()
	_constrain_body_width()

func _resolve_nodes() -> void:
	icon = get_node_or_null("Margin/VBox/Header/IconFrame/Icon") as TextureRect
	name_label = get_node_or_null("Margin/VBox/Header/HeaderText/Name") as Label
	body_label = get_node_or_null("Margin/VBox/Body") as Label
	icon_frame = get_node_or_null("Margin/VBox/Header/IconFrame") as PanelContainer

func _build_styles() -> void:
	_style = OverlayKit.shared(&"tip")
	add_theme_stylebox_override("panel", _style)
	_icon_style = OverlayKit.well(2)
	if icon_frame != null:
		icon_frame.add_theme_stylebox_override("panel", _icon_style)
	OverlayKit.style_label(name_label, &"heading", 17, OverlayKit.PARCHMENT)
	OverlayKit.style_label(body_label, &"body", 16, OverlayKit.BODY)


## Four small diamonds on the panel's corners (redrawn only on resize).
func _draw() -> void:
	OverlayKit.draw_corner_marks(self, Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color(OverlayKit.GOLD_DIM, 0.95), 3.0)

func hide_tooltip() -> void:
	_layout_ticket += 1
	visible = false

func show_augment(a: AugmentData, level: int = 1) -> void:
	if a == null:
		hide_tooltip()
		return

	if icon == null or name_label == null or body_label == null:
		_resolve_nodes()
		if icon == null or name_label == null or body_label == null:
			push_warning("[AugmentTooltip] Missing UI nodes (check scene paths).")
			hide_tooltip()
			return

	if _style == null or _icon_style == null:
		_build_styles()

	_layout_ticket += 1
	var ticket: int = _layout_ticket
	visible = false
	_constrain_body_width()

	icon.texture = a.icon
	var lvl: int = maxi(1, level)
	name_label.text = "%s  Lv.%d" % [a.display_name, lvl]

	var lines: Array[String] = []
	lines.append("Level: %d" % lvl)
	lines.append("")
	var desc := a.description.strip_edges()
	if desc == "":
		desc = a.card_blurb.strip_edges()
	if desc != "":
		lines.append(desc)

	var det := a.details
	if det.strip_edges() == "" and a.has_method("get"):
		var v: Variant = a.get("details")
		if v != null:
			det = str(v)
	det = det.strip_edges()
	if det != "":
		lines.append("")
		lines.append(det)

	# Generic stat mods (if present), at the level the header names. The base
	# `mods` are stale from Lv.2 on for every augment with mods_scale_per_level.
	if a.mods != null:
		var mods_lines := _format_stat_mods(_mods_at_level(a, lvl))
		if mods_lines.size() > 0:
			lines.append("")
			lines.append(("Stats at Lv.%d:\n" % lvl) + "\n".join(mods_lines))

	body_label.text = "\n".join(lines)
	# Wait until Containers have measured the wrapped body at BODY_WIDTH. Showing
	# before this pass is what caused the one-frame full-height tooltip.
	custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0.0)
	size = Vector2(TOOLTIP_WIDTH, 1.0)
	call_deferred("_finish_layout", ticket)

func _constrain_body_width() -> void:
	if body_label == null:
		return
	body_label.custom_minimum_size = Vector2(BODY_WIDTH, 0.0)
	body_label.size = Vector2(BODY_WIDTH, 1.0)

func _finish_layout(ticket: int) -> void:
	if ticket != _layout_ticket or body_label == null:
		return
	_constrain_body_width()
	reset_size()
	var measured: Vector2 = get_combined_minimum_size()
	size = Vector2(TOOLTIP_WIDTH, maxf(1.0, measured.y))
	visible = true

## The level-scaled delta, read back from AugmentData.apply_to_stats_at_level -
## the call the stat pass makes - applied to a default Stats and diffed
## against an untouched one, so the tooltip cannot drift from the formula.
func _mods_at_level(a: AugmentData, level: int) -> StatDelta:
	var base := Stats.new()
	var scaled := Stats.new()
	a.apply_to_stats_at_level(scaled, level)
	var out := StatDelta.new()
	out.max_hp = scaled.max_hp - base.max_hp
	out.armor = scaled.armor - base.armor
	out.move_speed = scaled.move_speed - base.move_speed
	out.power = scaled.power - base.power
	out.haste = scaled.haste - base.haste
	out.luck = scaled.luck - base.luck
	return out

func _format_stat_mods(m: StatDelta) -> Array[String]:
	var out: Array[String] = []
	if m == null:
		return out

	const EPS := 0.0001
	if absf(m.max_hp) > EPS:
		out.append("%+d Max HP" % int(round(m.max_hp)))
	if absf(m.armor) > EPS:
		out.append("%+d Armor" % int(round(m.armor)))
	if absf(m.move_speed) > EPS:
		out.append("%+d Move Speed" % int(round(m.move_speed)))
	if absf(m.power) > EPS:
		out.append("%+d%% Power" % int(round(m.power * 100.0)))
	if absf(m.haste) > EPS:
		out.append("%+d%% Haste" % int(round(m.haste * 100.0)))
	if absf(m.luck) > EPS:
		# Luck is a fraction (0.5 = +50%) and every other surface prints it as
		# one - the sheet's LCK %, the item tooltip, the identity line.
		out.append("%+d%% Luck" % int(round(m.luck * 100.0)))

	return out
