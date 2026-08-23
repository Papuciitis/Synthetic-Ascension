extends PanelContainer
class_name ItemTooltip

var icon: TextureRect = null
var name_label: Label = null
var meta_label: Label = null
var body_label: RichTextLabel = null
var icon_frame: PanelContainer = null

var _style: StyleBoxFlat
var _icon_style: StyleBoxFlat

const BORDER: Color = Color(1.0, 0.55, 0.20)
const BG: Color = Color(0.08, 0.08, 0.08, 0.96)

const POS: Color = Color(0.25, 1.0, 1.0, 1.0)
const NEG: Color = Color(1.0, 0.35, 0.55, 1.0)
const CMP_POS_HEX: String = "#78E08F"
const CMP_NEG_HEX: String = "#D77A86"
const CMP_NEUTRAL_HEX: String = "#A8A8A8"
const LOCK_HEX: String = "#F2C35B"

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
	make_subtree_mouse_transparent()
	_resolve_nodes()
	_build_styles()


func make_subtree_mouse_transparent() -> void:
	_set_mouse_transparent_recursive(self)


func _set_mouse_transparent_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_transparent_recursive(child)


func place_beside(
	source_rect: Rect2,
	viewport_rect: Rect2,
	gap: float = 12.0
) -> Vector2:
	var margin := 8.0
	var tip_size := size
	if tip_size.x <= 0.0 or tip_size.y <= 0.0:
		reset_size()
		tip_size = get_combined_minimum_size()
		size = tip_size

	var right_x := source_rect.end.x + gap
	var left_x := source_rect.position.x - tip_size.x - gap
	var min_x := viewport_rect.position.x + margin
	var max_x := viewport_rect.end.x - tip_size.x - margin
	var out_x := right_x
	if right_x + tip_size.x > viewport_rect.end.x - margin and left_x >= min_x:
		out_x = left_x
	else:
		out_x = clampf(out_x, min_x, maxf(min_x, max_x))

	var min_y := viewport_rect.position.y + margin
	var max_y := viewport_rect.end.y - tip_size.y - margin
	var out_y := clampf(source_rect.position.y, min_y, maxf(min_y, max_y))
	global_position = Vector2(out_x, out_y)
	return global_position

func _resolve_nodes() -> void:
	icon = get_node_or_null("Margin/VBox/Header/IconFrame/Icon") as TextureRect
	name_label = get_node_or_null("Margin/VBox/Header/HeaderText/Name") as Label
	meta_label = get_node_or_null("Margin/VBox/Header/HeaderText/Meta") as Label
	body_label = get_node_or_null("Margin/VBox/Body") as RichTextLabel
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

	# Establish width before assigning wrapped text. This also prevents the old
	# first-hover, full-height layout spike.
	custom_minimum_size = Vector2(460, 0)

	# Header
	name_label.text = String(inst.data.display_name)
	var pol_col: Color = POS if inst.polarity == ItemInstance.Polarity.POS else NEG
	meta_label.modulate = pol_col
	var slot_txt: String = _slot_text(int(inst.data.equip_slot))
	meta_label.text = "%s  ·  R%d  ·  %s%s" % [slot_txt, int(inst.rarity), ("POS" if inst.polarity == ItemInstance.Polarity.POS else "NEG"), ("  ·  LOCKED" if inst.locked else "")]

	if icon != null:
		icon.texture = inst.data.icon

	# Body lines
	var lines: Array[String] = []
	var desc: String = String(inst.data.description).strip_edges()
	if desc != "":
		lines.append(desc)

	# Short effects (auto-generated from effect scenes; effect scripts can implement get_effects_short)
	var eff: PackedStringArray = inst.data.get_effects_short(inst)
	if eff.size() > 0:
		lines.append("")
		lines.append("EFFECTS:")
		for e in eff:
			lines.append("• %s" % String(e))

	var rolled_lines: Array[String] = _format_delta(inst.rolled_mods)
	if rolled_lines.size() > 0:
		lines.append("")
		lines.append("ITEM STATS")
		lines.append("  " + "  ·  ".join(rolled_lines))

	if inst.locked:
		lines.append("")
		lines.append("[color=%s]LOCKED — protected from trade, movement, replacement and duplicate cleanup.[/color]" % LOCK_HEX)

	_append_stat_comparison(lines, inst)

	# Set identity, progression, active/next/later tiers and terminology.
	if String(inst.data.set_id) != "":
		var sid: StringName = StringName(str(inst.data.set_id))
		var counts: Dictionary = _current_set_counts()
		var have: int = int(counts.get(sid, 0))
		var sd: SetData = _set_data(sid)
		lines.append("")
		lines.append("SET IDENTITY")
		if sd == null:
			lines.append("%s  ·  %d equipped" % [String(sid).to_upper(), have])
		else:
			lines.append("%s  %s  %d / %d" % [sd.display_name.to_upper(), _progress_pips(have, sd.max_pieces()), have, sd.max_pieces()])
			if sd.identity_sentence != "":
				lines.append(sd.identity_sentence)
			if sd.playstyle != "":
				lines.append("PLAYSTYLE  " + sd.playstyle)
			lines.append("")
			lines.append("SET PROGRESSION")
			var next_found: bool = false
			for tier: SetTier in sd.sorted_tiers():
				if tier == null:
					continue
				var state: String = "ACTIVE" if have >= tier.required_count else ("NEXT" if not next_found else "LATER")
				if have < tier.required_count and not next_found:
					next_found = true
				var marker: String = "✓" if state == "ACTIVE" else ("→" if state == "NEXT" else "○")
				lines.append("%s %s · %d PIECES · %s" % [marker, state, tier.required_count, tier.display_name.to_upper()])
				if tier.mechanical_description != "":
					lines.append("  " + tier.mechanical_description)
				if tier.plain_description != "":
					lines.append("  IN PLAIN TERMS: " + tier.plain_description)
			if sd.best_with != "":
				lines.append("")
				lines.append("BEST WITH  " + sd.best_with)
			_append_glossary(lines, sd)

	_append_replacement_preview(lines, inst)

	# Secondary economy/progression information.
	lines.append("")
	# K6 legibility: the meter is real power now (continuous rarity), so
	# frame it as progress toward the next rank, not an abstract percent.
	var meter_frac: float = clampf(float(inst.upgrade_meter), 0.0, 1.0)
	var filled: int = int(round(meter_frac * 8.0))
	var meter_bar := ""
	for bar_i in range(8):
		meter_bar += ("▰" if bar_i < filled else "▱")
	var sell_v: int = 0
	if Global != null and Global.has_method("compute_sell_value"):
		sell_v = int(Global.compute_sell_value(inst))
	lines.append("R%d → R%d  %s %d%%  ·  SELL %d" % [
		int(inst.rarity), int(inst.rarity) + 1, meter_bar, int(round(meter_frac * 100.0)), sell_v,
	])
	if inst.polarity == ItemInstance.Polarity.NEG:
		var deepening: bool = (
			Global != null
			and Global.permanent_augment_ids.has(&"augment_corruption_engine")
		)
		lines.append(
			"Feeding DEEPENS the curse (Corruption Engine)" if deepening
			else "Feeding stabilizes the curse (mildest roll survives)"
		)

	body_label.text = "\n".join(lines)
	reset_size()
	visible = true


func _append_stat_comparison(lines: Array[String], candidate: ItemInstance) -> void:
	if Global == null or Global.run_inventory == null or candidate == null or candidate.data == null:
		return
	var slot: int = int(candidate.data.equip_slot)
	if slot < 0 or slot >= Inventory.SLOT_COUNT:
		return
	var current: ItemInstance = Global.run_inventory.get_at(slot)
	if current == null or current == candidate or current.rolled_mods == null or candidate.rolled_mods == null:
		return

	lines.append("")
	lines.append("INSTANT COMPARISON")
	lines.append("Compared with: %s" % String(current.data.display_name))

	var rows: Array[String] = build_comparison_rows(current, candidate, Global.run_inventory)
	if rows.is_empty():
		lines.append("[color=%s]No numeric stat change.[/color]" % CMP_NEUTRAL_HEX)
	else:
		for row: String in rows:
			lines.append(row)


func build_comparison_rows(current: ItemInstance, candidate: ItemInstance, inventory: Inventory) -> Array[String]:
	var rows: Array[String] = []
	if current == null or candidate == null or current.data == null or candidate.data == null:
		return rows
	var specs: Array[Array] = [
		["HP", "max_hp", false],
		["Armour", "armor", false],
		["Movement", "move_speed", false],
		["Power", "power", true],
		["Haste", "haste", true],
		["Luck", "luck", true],
	]
	for spec: Array in specs:
		var key: String = String(spec[1])
		var before: float = float(current.rolled_mods.get(key))
		var after: float = float(candidate.rolled_mods.get(key))
		var delta: float = after - before
		if absf(delta) < 0.0001:
			continue
		var shown: float = delta * 100.0 if bool(spec[2]) else delta
		var value_text: String = ("%+.1f%%" % shown) if bool(spec[2]) else _fmt_num(shown)
		var colour: String = CMP_POS_HEX if delta > 0.0 else CMP_NEG_HEX
		rows.append("[color=%s]%-12s %s[/color]" % [colour, String(spec[0]), value_text])

	var pct_delta: float = candidate.active_pct() - current.active_pct()
	if absf(pct_delta) >= 0.0001:
		var pct_colour: String = CMP_POS_HEX if pct_delta > 0.0 else CMP_NEG_HEX
		rows.append("[color=%s]%-12s %+.1f%%[/color]" % [pct_colour, "Effect roll", pct_delta * 100.0])

	var current_effects: PackedStringArray = current.data.get_effects_short(current)
	var candidate_effects: PackedStringArray = candidate.data.get_effects_short(candidate)
	if current_effects != candidate_effects:
		rows.append("[color=%s]SCRIPTED EFFECT CHANGES[/color]" % CMP_NEUTRAL_HEX)
		if not current_effects.is_empty():
			rows.append("[color=%s]Before: %s[/color]" % [CMP_NEG_HEX, "; ".join(current_effects)])
		if not candidate_effects.is_empty():
			rows.append("[color=%s]After: %s[/color]" % [CMP_POS_HEX, "; ".join(candidate_effects)])

	var set_id := StringName(candidate.data.set_id)
	if inventory != null and set_id != StringName() and int(candidate.data.equip_slot) < Inventory.STAT_SLOT_COUNT:
		var before_average: float = inventory.get_set_rarity_average(set_id)
		var sum_rarity: float = 0.0
		var piece_count: int = 0
		for slot_index in range(Inventory.STAT_SLOT_COUNT):
			var item: ItemInstance = candidate if slot_index == int(candidate.data.equip_slot) else inventory.get_at(slot_index)
			if item != null and item.data != null and StringName(item.data.set_id) == set_id:
				sum_rarity += float(item.rarity)
				piece_count += 1
		var after_average: float = sum_rarity / float(piece_count) if piece_count > 0 else 0.0
		if not is_equal_approx(before_average, after_average):
			var before_strength: float = RarityMath.potency(before_average)
			var after_strength: float = RarityMath.potency(after_average)
			var set_colour: String = CMP_POS_HEX if after_strength > before_strength else CMP_NEG_HEX
			rows.append(
				"[color=%s]Set strength  %.2fx → %.2fx[/color]"
				% [set_colour, before_strength, after_strength]
			)
	return rows

func _slot_text(slot: int) -> String:
	if slot >= 0 and slot < Inventory.SLOT_COUNT:
		return Inventory.slot_label(slot).to_upper()
	return "UNEQUIPPED"

func _set_data(set_id: StringName) -> SetData:
	if Global == null or Global.set_db == null:
		return null
	return Global.set_db.get(set_id, null) as SetData

func _current_set_counts() -> Dictionary:
	if Global != null and Global.run_inventory != null:
		return Global.run_inventory.get_set_counts()
	return {}

func _progress_pips(have: int, maximum: int) -> String:
	var out: String = ""
	for index in range(maximum):
		var pip_number: int = index + 1
		var is_breakpoint: bool = pip_number == 2 or pip_number == 4 or pip_number == 6
		if is_breakpoint:
			out += "◆" if pip_number <= have else "◇"
		else:
			out += "●" if pip_number <= have else "○"
	return out

func _append_glossary(lines: Array[String], data: SetData) -> void:
	var used: Dictionary = {}
	for tier: SetTier in data.tiers:
		if tier == null:
			continue
		for term: String in tier.glossary_terms:
			used[term] = true
	if used.is_empty():
		return
	lines.append("")
	lines.append("TERMS")
	for term_value: Variant in used.keys():
		var term: String = String(term_value)
		var definition: String = String(data.glossary.get(term, ""))
		if definition != "":
			lines.append("• %s — %s" % [term, definition])

func _append_replacement_preview(lines: Array[String], candidate: ItemInstance) -> void:
	if Global == null or Global.run_inventory == null or candidate == null or candidate.data == null:
		return
	var target_slot: int = int(candidate.data.equip_slot)
	if target_slot < 0 or target_slot >= Inventory.SLOT_COUNT:
		return
	var current: ItemInstance = Global.run_inventory.get_at(target_slot)
	lines.append("")
	lines.append("EQUIP PREVIEW · %s" % Inventory.slot_label(target_slot).to_upper())
	if current == candidate:
		lines.append("Already equipped; set breakpoints do not change.")
		return
	lines.append("REPLACES  %s" % (String(current.data.display_name) if current != null and current.data != null else "EMPTY SLOT"))
	var before: Dictionary = _current_set_counts()
	var after: Dictionary = before.duplicate()
	if target_slot < Inventory.STAT_SLOT_COUNT:
		if current != null and current.data != null:
			_adjust_count(after, StringName(current.data.set_id), -1)
		_adjust_count(after, StringName(candidate.data.set_id), 1)
	var relevant: Dictionary = {}
	if current != null and current.data != null and String(current.data.set_id) != "":
		relevant[StringName(current.data.set_id)] = true
	if String(candidate.data.set_id) != "":
		relevant[StringName(candidate.data.set_id)] = true
	var any_breakpoint: bool = false
	for sid_value: Variant in relevant.keys():
		var sid: StringName = StringName(sid_value)
		var old_count: int = int(before.get(sid, 0))
		var new_count: int = int(after.get(sid, 0))
		var data: SetData = _set_data(sid)
		var label: String = data.display_name if data != null else String(sid)
		lines.append("%s  %d → %d" % [label, old_count, new_count])
		if data == null:
			continue
		for tier: SetTier in data.sorted_tiers():
			if tier == null:
				continue
			if old_count < tier.required_count and new_count >= tier.required_count:
				lines.append("  GAIN  %dP %s" % [tier.required_count, tier.display_name])
				any_breakpoint = true
			elif old_count >= tier.required_count and new_count < tier.required_count:
				lines.append("  LOSE  %dP %s" % [tier.required_count, tier.display_name])
				any_breakpoint = true
	if not any_breakpoint:
		lines.append("No set breakpoint crossed.")

func _adjust_count(counts: Dictionary, sid: StringName, amount: int) -> void:
	if sid == StringName():
		return
	var value: int = maxi(0, int(counts.get(sid, 0)) + amount)
	if value == 0:
		counts.erase(sid)
	else:
		counts[sid] = value

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
