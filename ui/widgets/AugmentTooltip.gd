extends PanelContainer
class_name AugmentTooltip

var icon: TextureRect = null
var name_label: Label = null
var body_label: Label = null
var icon_frame: PanelContainer = null

var _style: StyleBoxFlat
var _icon_style: StyleBoxFlat

const BORDER: Color = Color(1.0, 0.55, 0.20)
const BG: Color = Color(0.08, 0.08, 0.08, 0.96)
const TOOLTIP_WIDTH: float = 360.0
const BODY_WIDTH: float = 340.0

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
	_style = StyleBoxFlat.new()
	_style.bg_color = BG
	_style.set_border_width_all(2)
	_style.border_color = BORDER
	_style.corner_radius_top_left = 14
	_style.corner_radius_top_right = 14
	_style.corner_radius_bottom_left = 14
	_style.corner_radius_bottom_right = 14
	_style.shadow_size = 10
	_style.shadow_offset = Vector2(0, 6)
	_style.shadow_color = Color(0, 0, 0, 0.35)
	add_theme_stylebox_override("panel", _style)

	_icon_style = StyleBoxFlat.new()
	_icon_style.bg_color = Color(0.12, 0.12, 0.12, 1.0)
	_icon_style.set_border_width_all(1)
	_icon_style.border_color = Color(0.10, 0.10, 0.10, 1.0)
	_icon_style.corner_radius_top_left = 10
	_icon_style.corner_radius_top_right = 10
	_icon_style.corner_radius_bottom_left = 10
	_icon_style.corner_radius_bottom_right = 10

	if icon_frame != null:
		icon_frame.add_theme_stylebox_override("panel", _icon_style)

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

	# Generic stat mods (if present)
	if a.mods != null:
		var mods_lines := _format_stat_mods(a.mods)
		if mods_lines.size() > 0:
			lines.append("")
			lines.append("Stats:\n" + "\n".join(mods_lines))

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
		out.append("%+d Luck" % int(round(m.luck)))

	return out
