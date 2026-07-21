extends PanelContainer
class_name ItemTooltip

var icon: TextureRect = null
var name_label: Label = null
var meta_label: Label = null
var body_label: Label = null
var icon_frame: PanelContainer = null

var _style: StyleBoxFlat
var _icon_style: StyleBoxFlat

const BORDER: Color = Color(1.0, 0.55, 0.20)
const BG: Color = Color(0.08, 0.08, 0.08, 0.96)

const POS: Color = Color(0.25, 1.0, 1.0, 1.0)
const NEG: Color = Color(1.0, 0.35, 0.55, 1.0)

const KEY_MAP: Dictionary = {
	"max_hp": "HP",
	"armor": "ARM",
	"move_speed": "SPD",
	"power": "POW",
	"haste": "HST",
	"luck": "LCK",
}

const PCT_KEYS := {
	"power": true,
	"haste": true,
	"luck": true,
}

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resolve_nodes()
	_build_styles()

func _resolve_nodes() -> void:
	icon = get_node_or_null("Margin/VBox/Header/IconFrame/Icon") as TextureRect
	name_label = get_node_or_null("Margin/VBox/Header/HeaderText/Name") as Label
	meta_label = get_node_or_null("Margin/VBox/Header/HeaderText/Meta") as Label
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
	visible = false

func show_item(inst: ItemInstance) -> void:
	if inst == null or inst.data == null:
		hide_tooltip()
		return

	# If show_item is called before _ready finished (or node paths changed), re-resolve safely.
	if icon == null or name_label == null or meta_label == null or body_label == null:
		_resolve_nodes()
		if icon == null or name_label == null or meta_label == null or body_label == null:
			push_warning("[ItemTooltip] Missing UI nodes (check scene paths). Tooltip will not render.")
			hide_tooltip()
			return

	# Enforce a sane width BEFORE setting long text (prevents first-show wrap explosion).
	custom_minimum_size = Vector2(420, 0)

	# Header
	name_label.text = String(inst.data.display_name)
	var pol_col: Color = POS if inst.polarity == ItemInstance.Polarity.POS else NEG
	meta_label.modulate = pol_col
	meta_label.text = "R%d  %s" % [int(inst.rarity), ("POS" if inst.polarity == ItemInstance.Polarity.POS else "NEG")]

	if icon != null:
		icon.texture = inst.data.icon

	# Body lines
	var lines: Array[String] = []
	var slot_txt: String = ""
	match int(inst.data.equip_slot):
		int(ItemData.EquipSlot.HP): slot_txt = "HP"
		int(ItemData.EquipSlot.ARMOR): slot_txt = "ARMOR"
		int(ItemData.EquipSlot.MOVE): slot_txt = "MOVE"
		int(ItemData.EquipSlot.POWER): slot_txt = "POWER"
		int(ItemData.EquipSlot.HASTE): slot_txt = "HASTE"
		int(ItemData.EquipSlot.LUCK): slot_txt = "LUCK"
		int(ItemData.EquipSlot.OFFHAND): slot_txt = "OFF-HAND"
		int(ItemData.EquipSlot.RING): slot_txt = "RING"
		_: slot_txt = ""

	if slot_txt != "":
		lines.append("SLOT: %s" % slot_txt)

	# Sell value (Hub + tooltips)
	var sell_v: int = 0
	if Global != null and Global.has_method("compute_sell_value"):
		sell_v = int(Global.compute_sell_value(inst))
	lines.append("SELL: %d" % sell_v)

	var desc: String = String(inst.data.description).strip_edges()
	if desc != "":
		lines.append("")
		lines.append(desc)

	# Short effects (auto-generated from effect scenes; effect scripts can implement get_effects_short)
	var eff: PackedStringArray = inst.data.get_effects_short(inst)
	if eff.size() > 0:
		lines.append("")
		lines.append("EFFECTS:")
		for e in eff:
			lines.append("• %s" % String(e))

	lines.append("")

	# Set preview (2/4/6) + current count
	if String(inst.data.set_id) != "":
		var sid: StringName = StringName(str(inst.data.set_id))
		var have: int = 0

		if Global != null and Global.run_inventory != null and Global.run_inventory.has_method("get_set_counts"):
			var counts: Dictionary = Global.run_inventory.get_set_counts()
			have = int(counts.get(sid, 0))

		lines.append("SET: %s  (%d/6)" % [String(sid).to_upper(), have])

		if Global != null and Global.set_db != null and Global.set_db.has(sid):
			var sd: SetData = Global.set_db.get(sid, null) as SetData
			if sd != null:
				# Sort tiers so they print in order
				var tiers: Array = sd.tiers.duplicate()
				tiers.sort_custom(func(a: SetTier, b: SetTier) -> bool:
					return a.required_count < b.required_count
				)

				for t: SetTier in tiers:
					if t == null:
						continue
					var req: int = int(t.required_count)
					if req != 2 and req != 4 and req != 6:
						continue

					var active: bool = have >= req
					var prefix: String = "✓" if active else "•"
					var parts: Array[String] = []

					if t.mods != null:
						var tier_mod_lines: Array[String] = _format_delta(t.mods)
						if tier_mod_lines.size() > 0:
							parts.append(", ".join(tier_mod_lines))

					if t.effect_scenes.size() > 0:
						var tier_eff_names: Array[String] = []
						for scn: PackedScene in t.effect_scenes:
							if scn == null:
								continue
							var short_txt: String = ""
							# Safe instantiate (NOT added to tree) to read tooltip metadata.
							var eff_node: Node = scn.instantiate() as Node
							if eff_node != null and eff_node.has_method("get_tooltip_short"):
								short_txt = String(eff_node.call("get_tooltip_short")).strip_edges()
							if eff_node != null:
								eff_node.free()
							if short_txt == "":
								var rp: String = String(scn.resource_path)
								var nm: String = rp.get_file().get_basename() if rp != "" else "Effect"
								short_txt = nm.replace("_", " ").to_upper()
							tier_eff_names.append(short_txt)
						if tier_eff_names.size() > 0:
							parts.append("Effects: " + ", ".join(tier_eff_names))

					var detail: String = (" | ".join(parts) if parts.size() > 0 else "—")
					lines.append("%s %d: %s" % [prefix, req, detail])

		lines.append("")

	# Upgrade meter
	var um: float = clampf(float(inst.upgrade_meter), 0.0, 1.0) * 100.0
	lines.append("UPGRADE: %d%%" % int(round(um)))

	# Rolled modifiers
	var rolled_lines: Array[String] = _format_delta(inst.rolled_mods)
	if rolled_lines.size() > 0:
		lines.append("")
		lines.append_array(rolled_lines)

	body_label.text = "\n".join(lines)
	reset_size()
	visible = true

# (rest of your functions unchanged)
func _format_delta(delta: Variant) -> Array[String]:
	var out: Array[String] = []
	var res: Resource = delta as Resource
	if res == null:
		return out

	var props: Array[Dictionary] = res.get_property_list()
	for p: Dictionary in props:
		if not p.has("name"):
			continue
		var k: String = String(p["name"])
		if k.begins_with("resource_") or k == "script":
			continue

		var v: Variant = res.get(k)
		if v is float or v is int:
			var f: float = float(v)
			if absf(f) < 0.0001:
				continue
			var abbr: String = String(KEY_MAP.get(k, k.to_upper()))
			if PCT_KEYS.has(k):
				out.append("%s %s" % [abbr, _fmt_pct(f)])
			else:
				out.append("%s %s" % [abbr, _fmt_num(f)])
	return out

func _fmt_num(v: float) -> String:
	var prefix: String = ("+" if v > 0.0 else "")
	if is_equal_approx(v, float(int(v))):
		return "%s%d" % [prefix, int(v)]
	return "%s%.1f" % [prefix, v]


func _fmt_pct(frac: float) -> String:
	# frac is a fraction (0.12 => 12%)
	var pct: float = frac * 100.0
	if absf(pct) < 0.01:
		return "+0%"
	# Snap near integers to avoid ugly decimals
	if is_equal_approx(pct, float(int(pct))):
		return "%+.0f%%" % pct
	return "%+.1f%%" % pct

func _rarity_to_color(r: int) -> Color:
	var a: float = 1.0
	if r <= -2: return Color(0.45, 0.0, 0.0, a)
	if r == -1: return Color(0.75, 0.1, 0.1, a)
	if r == 0:  return Color(0.25, 0.25, 0.25, a)
	if r == 1:  return Color(0.2, 0.9, 0.2, a)
	if r == 2:  return Color(0.25, 0.45, 1.0, a)
	if r == 3:  return Color(0.7, 0.25, 0.95, a)
	return Color(1.0, 0.65, 0.15, a)
