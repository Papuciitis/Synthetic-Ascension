extends PanelContainer
class_name ItemTooltip
## The item dossier on hover (HUD bar and bag, the Exchange, Gear & Stash) in
## the front end's register: a square gold-ruled panel, the icon in a well
## ruled in its rarity's colour, a Cinzel name and line, Garamond body with
## Cinzel section heads. Every look is set once in _ready; a show rewrites
## text, never styles (bar the well, and only when the rarity changes).

const OverlayKit := preload("res://ui/widgets/overlays/OverlayKit.gd")

var icon: TextureRect = null
var name_label: Label = null
var meta_label: Label = null
var body_label: RichTextLabel = null
var icon_frame: PanelContainer = null
var kicker_label: Label = null

var _dossier_mode: bool = false
## Set by show_lines(), which may hide the well and retitle the kicker;
## show_item() puts both back.
var _custom_header: bool = false
var _default_kicker: String = ""
var _well_rarity: int = -99
## The width the last show laid itself out at, to tell it from a host's.
var _laid_out_width: float = 0.0

var _style: StyleBox
var _icon_style: StyleBox

const BORDER: Color = OverlayKit.GOLD_DIM
const BG: Color = Color(0.028, 0.024, 0.021, 0.97)

const POS: Color = OverlayKit.SAGE
const NEG: Color = OverlayKit.CURSE
const CMP_POS_HEX: String = "#A6CB8E"
const CMP_NEG_HEX: String = "#E2826C"
const CMP_NEUTRAL_HEX: String = "#9C9282"
const LOCK_HEX: String = "#E8C27A"
## Section heads (Cinzel, through the body's bold face) and their quieter
## follow-on lines.
const HEAD_HEX: String = "#D3A562"
const QUIET_HEX: String = "#8C8373"
## The layer's own colour, for chrome that is about Manifestations in general.
## Anything that names a specific rule uses that rule's NOUN hex instead - see
## ManifestationNouns.
const MANIFEST_HEX: String = ManifestationNouns.LAYER_HEX

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

## The tallest a dossier stands: the screen less this margin above and below.
const SCREEN_MARGIN := 8.0
## A dossier taller than that widens in these steps, up to this many times its
## normal width; past it the host's clamp has the last word.
const FIT_STEP := 60.0
const FIT_MAX_SCALE := 2.0

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
	# A host that shrinks an overlong dossier (the imprinter) places what is drawn.
	tip_size *= scale

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
	kicker_label = get_node_or_null("Margin/VBox/Kicker") as Label

func _build_styles() -> void:
	_style = OverlayKit.shared(&"tip")
	add_theme_stylebox_override("panel", _style)
	_icon_style = OverlayKit.shared(&"tip_well")
	if icon_frame != null:
		icon_frame.add_theme_stylebox_override("panel", _icon_style)
	OverlayKit.style_label(name_label, &"heading", 17, OverlayKit.PARCHMENT)
	# The meta line takes its polarity through modulate, so its own colour is
	# white and a show never rewrites a theme override.
	OverlayKit.style_label(meta_label, &"caption", 12, Color.WHITE)
	OverlayKit.style_label(kicker_label, &"caption", 11, OverlayKit.GOLD_DIM)
	if body_label != null:
		body_label.add_theme_font_override(&"normal_font", OverlayKit.font(&"body"))
		body_label.add_theme_font_override(&"bold_font", OverlayKit.font(&"heading"))
		body_label.add_theme_font_override(&"italics_font", OverlayKit.font(&"italic"))
		body_label.add_theme_font_size_override(&"normal_font_size", 16)
		body_label.add_theme_font_size_override(&"bold_font_size", 12)
		body_label.add_theme_font_size_override(&"italics_font_size", 16)
		body_label.add_theme_color_override(&"default_color", OverlayKit.BODY)
		body_label.add_theme_constant_override(&"line_separation", 1)


## Four small diamonds on the panel's corners (redrawn only on resize).
func _draw() -> void:
	OverlayKit.draw_corner_marks(self, Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color(OverlayKit.GOLD_DIM, 0.95), 3.0)


## The icon well's rule follows the item's rarity.
func _apply_well(rarity: int) -> void:
	if icon_frame == null or rarity == _well_rarity:
		return
	_well_rarity = rarity
	icon_frame.add_theme_stylebox_override("panel", OverlayKit.well(rarity))


## The body's wrap width, set before its text is measured. A RichTextLabel the
## container has not sized yet wraps at width 1 and reports a body thousands
## of pixels tall, which is what the first HUD tooltip of a run used to show.
## Returns the panel width the body was measured for.
func _constrain_body_width() -> float:
	if body_label == null:
		return size.x
	var margin := get_node_or_null("Margin") as MarginContainer
	var pad := 0.0
	if margin != null:
		pad = float(margin.get_theme_constant(&"margin_left") + margin.get_theme_constant(&"margin_right"))
	# The width the panel will take: its minimum, or more for a long name.
	var outer := custom_minimum_size.x
	var vbox := body_label.get_parent()
	for child in vbox.get_children():
		if child != body_label and child is Control and (child as Control).visible:
			outer = maxf(outer, (child as Control).get_combined_minimum_size().x + pad)
	# A host may lay the dossier out wider than that (Gear & Stash), but a
	# width the last show left behind (a long name, a fit) is not the host's.
	if not is_equal_approx(size.x, _laid_out_width):
		outer = maxf(outer, size.x)
	body_label.size = Vector2(maxf(1.0, outer - pad), body_label.size.y)
	return outer


static func _head(text: String) -> String:
	return "[color=%s][b]%s[/b][/color]" % [HEAD_HEX, text]


func hide_tooltip() -> void:
	visible = false


func set_dossier_mode(enabled: bool) -> void:
	_dossier_mode = enabled
	custom_minimum_size = Vector2(380.0 if enabled else 360.0, 0.0)
	if kicker_label == null:
		_resolve_nodes()
	if kicker_label != null:
		kicker_label.visible = enabled
	reset_size()

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
	custom_minimum_size = Vector2(380.0 if _dossier_mode else 360.0, 0.0)
	if _custom_header:
		_custom_header = false
		if icon_frame != null:
			icon_frame.visible = true
		if kicker_label != null:
			kicker_label.text = _default_kicker
			kicker_label.visible = _dossier_mode

	# Header
	name_label.text = String(inst.data.display_name)
	var pol_col: Color = POS if inst.polarity == ItemInstance.Polarity.POS else NEG
	meta_label.modulate = pol_col
	var slot_txt: String = _slot_text(int(inst.data.equip_slot))
	meta_label.text = "%s  ·  R%d  ·  %s%s" % [slot_txt, int(inst.rarity), ("POS" if inst.polarity == ItemInstance.Polarity.POS else "NEG"), ("  ·  LOCKED" if inst.locked else "")]

	if icon != null:
		icon.texture = inst.data.icon
	_apply_well(int(inst.rarity))

	# Body lines
	var lines: Array[String] = []
	var desc: String = String(inst.data.description).strip_edges()
	if desc != "":
		lines.append(desc)

	# Short effects (auto-generated from effect scenes; effect scripts can implement get_effects_short)
	var eff: PackedStringArray = inst.data.get_effects_short(inst)
	if eff.size() > 0:
		lines.append("")
		lines.append(_head("EFFECTS"))
		for e in eff:
			lines.append("• %s" % String(e))

	# Manifestation is identity, not a stat, so it sits above the numbers.
	if inst.has_manifestation():
		var manifest_def: ManifestationDef = inst.manifestation_def()
		if manifest_def != null:
			lines.append("")
			# Coloured by the rule's own noun, not by the layer. The palette is
			# the vocabulary: the same orange on the tooltip, on the item badge
			# and on the HUD counter is what teaches "these two combine"
			# without the player reading a word.
			var primary_hex: String = MANIFEST_HEX
			if manifest_def.primary_tag() != &"":
				primary_hex = ManifestationNouns.hex(manifest_def.primary_tag())
			var noun_names: PackedStringArray = PackedStringArray()
			for tag in manifest_def.tags:
				noun_names.append("[color=%s]%s[/color]" % [
					ManifestationNouns.hex(tag), ManifestationNouns.label(tag),
				])
			lines.append("[color=%s]MANIFESTATION — %s[/color]" % [primary_hex, manifest_def.display_name.to_upper()])
			if not noun_names.is_empty():
				# Naming the nouns is how the player learns which items combine:
				# two of a noun is what turns an accident into a build.
				var noun_separator: String = "[color=%s] · [/color]" % CMP_NEUTRAL_HEX
				lines.append(noun_separator.join(noun_names))
			lines.append("[color=%s]%s[/color]" % [primary_hex, ManifestationCatalog.describe(inst.manifestation_id, inst)])
			# A noun counts DISTINCT rules (ManifestationRunner.get_noun_counts),
			# so a second item carrying this rule never lights the pair - the
			# one thing a player holding two of them expects it to do.
			lines.append("[color=%s]Survives every merge. Duplicates rank this item up; they never reroll its rule. Two items with one rule light no second ◆ — a noun counts distinct rules.[/color]" % CMP_NEUTRAL_HEX)

	var rolled_lines: Array[String] = _format_delta(inst.rolled_mods)
	if rolled_lines.size() > 0:
		lines.append("")
		lines.append(_head("ITEM STATS"))
		lines.append("  " + "  ·  ".join(rolled_lines))
		# The next whole rank's change, from the same evaluator that made the
		# stats above (balance revision 2 curves; legacy items too).
		var next_lines: Array[String] = _format_delta(ItemScaling.next_rank_delta(inst))
		if not next_lines.is_empty():
			lines.append("[color=%s]  next rank: %s[/color]" % [CMP_NEUTRAL_HEX, "  ·  ".join(next_lines)])

	if inst.locked:
		lines.append("")
		lines.append("[color=%s]LOCKED — protected from trade, movement, replacement and duplicate cleanup.[/color]" % LOCK_HEX)

	_append_stat_comparison(lines, inst)

	# Hover is a decision surface, not the set manual. The complete identity,
	# progression, playstyle and glossary live in Run Sheet // Sets.
	if String(inst.data.set_id) != "":
		_append_set_summary(lines, StringName(str(inst.data.set_id)))

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
	# A cursed item is worth different amounts to different builds, so the
	# tooltip has to say what THIS wardrobe is currently doing with it - not
	# just that it is NEG.
	var lens_suppressed: bool = false
	if inst.polarity == ItemInstance.Polarity.NEG and Global != null:
		var burden_snapshot: BurdenSnapshot = BurdenResolver.resolve(
			Global.run_inventory, Global.permanent_augment_ids
		)
		var slot_index: int = int(inst.data.equip_slot)
		var severity: float = absf(inst.active_pct())
		var ratio: float = BurdenResolver.burden_ratio_for(inst)
		lines.append("")
		if slot_index >= Inventory.STAT_SLOT_COUNT:
			# Accessory curses drive scripted behaviour, not a stat: they count
			# as NEG in the polarity census, never in Burden arithmetic.
			lines.append(
				"[color=%s]ACCESSORY CURSE %d%% — counts as NEG in the polarity census; not a stat Burden.[/color]"
				% [NEG.to_html(false), int(round(severity * 100.0))]
			)
		elif burden_snapshot.is_suppressed(slot_index) and Global.run_inventory != null \
		and Global.run_inventory.get_at(slot_index) == inst:
			lens_suppressed = true
			lines.append(
				"[color=%s]SUPPRESSED — %d%% curse inverted to +%d%%. Still NEG in the polarity census; counts for neither the Doctrine nor the Engine.[/color]"
				% [
					CMP_POS_HEX,
					int(round(severity * 100.0)),
					int(round(BurdenResolver.inverted_return(severity) * 100.0)),
				]
			)
		else:
			var qualifies: bool = ratio >= BurdenSnapshot.QUALIFYING_BURDEN_RATIO
			var weight: String = "catastrophic" if severity >= 0.70 else (
				"severe" if severity >= 0.40 else (
					"real" if qualifies else "trivial"
				)
			)
			lines.append(
				"[color=%s]ACTIVE BURDEN %d%% (%d%% of its range) — %s.%s[/color]"
				% [
					NEG.to_html(false),
					int(round(severity * 100.0)),
					int(round(ratio * 100.0)),
					weight,
					"" if qualifies else " Too mild for its range to count as a burden.",
				]
			)
	elif inst.polarity == ItemInstance.Polarity.POS:
		_append_pos_roll(lines, inst)

	if inst.polarity == ItemInstance.Polarity.NEG:
		var deepening: bool = (
			Global != null
			and Global.permanent_augment_ids.has(&"augment_corruption_engine")
		)
		if deepening:
			lines.append("Feeding DEEPENS the curse (Corruption Engine)")
		elif lens_suppressed:
			# The Lens returns a share of SEVERITY, and a feed keeps the mildest
			# roll: stabilising the one curse it is inverting is the one feed in
			# the wardrobe that makes the player weaker.
			lines.append("Feeding stabilizes the curse (mildest roll survives) — a milder roll shrinks your inverted return")
		else:
			lines.append("Feeding stabilizes the curse (mildest roll survives)")

	var measured_width := _constrain_body_width()
	body_label.text = "\n".join(lines)
	reset_size()
	_fit_screen_height(measured_width)
	_laid_out_width = size.x
	visible = true


## A dossier that is not one item's own record (the imprinter's held rule and
## its before/after, ui/widgets/ImprintDossier.gd): the same panel, header,
## wrap and fit as show_item(), with the caller's BBCode lines. A null
## `icon_texture` hides the well, `rarity` rules it otherwise; an empty
## `kicker` hides the kicker; `width` is the panel's width before any fit.
func show_lines(
	title: String,
	meta: String,
	meta_colour: Color,
	kicker: String,
	lines: Array[String],
	icon_texture: Texture2D = null,
	rarity: int = 0,
	width: float = 380.0
) -> void:
	if name_label == null or meta_label == null or body_label == null:
		_resolve_nodes()
		if name_label == null or meta_label == null or body_label == null:
			hide_tooltip()
			return
	# The width first, so the body wraps at it when it is measured.
	custom_minimum_size = Vector2(width, 0.0)
	_custom_header = true
	if kicker_label != null:
		if _default_kicker.is_empty():
			_default_kicker = kicker_label.text
		kicker_label.text = kicker
		kicker_label.visible = not kicker.is_empty()
	name_label.text = title
	meta_label.text = meta
	meta_label.modulate = meta_colour
	if icon_frame != null:
		icon_frame.visible = icon_texture != null
	if icon != null:
		icon.texture = icon_texture
	if icon_texture != null:
		_apply_well(rarity)
	var measured_width := _constrain_body_width()
	body_label.text = "\n".join(lines)
	reset_size()
	_fit_screen_height(measured_width)
	_laid_out_width = size.x
	visible = true


## A long dossier (a Manifestation, the comparison, the equip preview) can
## stand taller than the screen, and the host's clamp then cuts its last
## sections off the bottom edge. It is laid out wider instead, a step at a
## time, so its long lines wrap into fewer.
func _fit_screen_height(width: float) -> void:
	if not is_inside_tree() or body_label == null:
		return
	var limit := get_viewport_rect().size.y - 2.0 * SCREEN_MARGIN
	var widest := custom_minimum_size.x * FIT_MAX_SCALE
	while size.y > limit and width < widest:
		width = minf(width + FIT_STEP, widest)
		custom_minimum_size.x = width
		_constrain_body_width()
		# The body's new width alone leaves the containers' cached minimum.
		body_label.update_minimum_size()
		reset_size()


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
	lines.append(_head("INSTANT COMPARISON"))
	lines.append("Compared with: %s" % String(current.data.display_name))

	var rows: Array[String] = build_comparison_rows(
		current, candidate, Global.run_inventory, Global.permanent_augment_ids
	)
	if rows.is_empty():
		lines.append("[color=%s]No numeric stat change.[/color]" % CMP_NEUTRAL_HEX)
	else:
		for row: String in rows:
			lines.append(row)


func build_comparison_rows(current: ItemInstance, candidate: ItemInstance, inventory: Inventory, augment_ids: Array = []) -> Array[String]:
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

	# Under an Inversion Lens the raw roll diff can invert the truth - a deeper
	# curse is a bigger return, and the penalty of a curse the Lens would take
	# is never paid - so that slot gets the Lens's own reading instead.
	var lens_rows: Array[String] = _lens_roll_rows(current, candidate, inventory, augment_ids)
	if not lens_rows.is_empty():
		rows.append_array(lens_rows)
	else:
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

	# The whole point of the layer: an R2 with the right rule can beat an R9
	# with a dull one, and a merge will never hand you the rule for free.
	if current.manifestation_id != candidate.manifestation_id:
		rows.append("[color=%s]MANIFESTATION CHANGES[/color]" % CMP_NEUTRAL_HEX)
		rows.append("[color=%s]Before: %s[/color]" % [
			CMP_NEG_HEX,
			ManifestationCatalog.display_name(current.manifestation_id) if current.has_manifestation() else "none",
		])
		var after_hex: String = MANIFEST_HEX
		if candidate.has_manifestation():
			var after_noun := ManifestationNouns.primary_of(candidate.manifestation_id)
			if after_noun != &"":
				after_hex = ManifestationNouns.hex(after_noun)
		rows.append("[color=%s]After: %s[/color]" % [
			after_hex,
			ManifestationCatalog.display_name(candidate.manifestation_id) if candidate.has_manifestation() else "none",
		])

	var set_id := StringName(candidate.data.set_id)
	if inventory != null and set_id != StringName() and int(candidate.data.equip_slot) < Inventory.STAT_SLOT_COUNT:
		var before_average: float = inventory.get_set_rarity_average(set_id)
		var sum_rarity: float = 0.0
		var piece_count: int = 0
		for slot_index in range(Inventory.STAT_SLOT_COUNT):
			var item: ItemInstance = candidate if slot_index == int(candidate.data.equip_slot) else inventory.get_at(slot_index)
			if item != null and item.data != null and StringName(item.data.set_id) == set_id:
				sum_rarity += float(maxi(0, item.rarity)) + clampf(float(item.upgrade_meter), 0.0, 0.999999)
				piece_count += 1
		var after_average: float = sum_rarity / float(piece_count) if piece_count > 0 else 0.0
		if not is_equal_approx(before_average, after_average):
			# The set's damage channel (balance revision 2), not the old potency.
			var before_strength: float = float(SetScaling.profile(before_average).damage)
			var after_strength: float = float(SetScaling.profile(after_average).damage)
			var set_colour: String = CMP_POS_HEX if after_strength > before_strength else CMP_NEG_HEX
			rows.append(
				"[color=%s]Set strength  %.2fx → %.2fx[/color]"
				% [set_colour, before_strength, after_strength]
			)
	return rows


## Stat key each statistical slot's roll is applied to, in the order the stat
## pass walks the slots (player.recompute_run_stats). The first three slots
## multiply their stat by (1 + roll); the last three add the roll to it.
const SLOT_STAT_KEYS: Array[String] = ["max_hp", "armor", "move_speed", "power", "haste", "luck"]
const MULTIPLIED_SLOT_COUNT: int = 3


## The POS mirror of the burden line: the roll is already on the instance and
## on the slot label, but nothing said whether it multiplies or adds. The
## comparison block and the slot label print it bare, so the one place the
## player reads an item in full names the arithmetic.
func _append_pos_roll(lines: Array[String], inst: ItemInstance) -> void:
	var slot_index: int = int(inst.data.equip_slot)
	if slot_index < 0:
		return
	var roll: float = inst.active_pct()
	lines.append("")
	if slot_index >= Inventory.STAT_SLOT_COUNT:
		# The stat pass never reads an accessory's roll; its own effect scene
		# does (Regeneration Ring, Oakheart, Firestone read active_pct()).
		lines.append(
			"[color=%s]ACCESSORY ROLL %+d%% — read by this item's scripted effect; not a stat.[/color]"
			% [POS.to_html(false), int(round(roll * 100.0))]
		)
		return
	var stat: String = String(KEY_MAP.get(SLOT_STAT_KEYS[slot_index], SLOT_STAT_KEYS[slot_index].to_upper()))
	if slot_index < MULTIPLIED_SLOT_COUNT:
		lines.append(
			"[color=%s]EFFECT ROLL %+d%% — %s ×%.2f on this slot[/color]"
			% [POS.to_html(false), int(round(roll * 100.0)), stat, 1.0 + roll]
		)
	else:
		lines.append(
			"[color=%s]EFFECT ROLL %+d%% — %s %+d%% on this slot[/color]"
			% [POS.to_html(false), int(round(roll * 100.0)), stat, int(round(roll * 100.0))]
		)


## What the candidate's slot would pay under an Inversion Lens, phrased the
## way the sheet's Lens line is. Empty when the Lens has no say in this swap,
## so the caller prints the raw roll diff. The "after" wardrobe goes through
## the same BurdenResolver the stat pass uses, so the selection rule (most
## severe statistical curse, lowest slot on ties) is never re-derived here.
func _lens_roll_rows(current: ItemInstance, candidate: ItemInstance, inventory: Inventory, augment_ids: Array) -> Array[String]:
	var rows: Array[String] = []
	if inventory == null or not augment_ids.has(&"augment_inversion_lens"):
		return rows
	var slot: int = int(candidate.data.equip_slot)
	if slot < 0 or slot >= Inventory.STAT_SLOT_COUNT:
		return rows
	var before: BurdenSnapshot = BurdenResolver.resolve(inventory, augment_ids)
	var preview := Inventory.new()
	for slot_index in range(Inventory.SLOT_COUNT):
		preview.items[slot_index] = candidate if slot_index == slot else inventory.get_at(slot_index)
	var after: BurdenSnapshot = BurdenResolver.resolve(preview, augment_ids)
	var current_suppressed: bool = before.is_suppressed(slot) and inventory.get_at(slot) == current
	var candidate_suppressed: bool = after.is_suppressed(slot)
	if not current_suppressed and not candidate_suppressed:
		return rows

	# What the slot pays now and what it would pay: the return when the Lens
	# holds it, the stored roll when it does not.
	var before_value: float = (
		BurdenResolver.inverted_return(before.suppressed_severity) if current_suppressed
		else current.active_pct()
	)
	var after_value: float = (
		BurdenResolver.inverted_return(after.suppressed_severity) if candidate_suppressed
		else candidate.active_pct()
	)
	var colour: String = CMP_POS_HEX if after_value >= before_value else CMP_NEG_HEX
	if candidate_suppressed:
		rows.append("[color=%s]%-12s would be suppressed → %+.1f%% returned[/color]" % [
			colour, "Effect roll", after_value * 100.0,
		])
	else:
		rows.append("[color=%s]%-12s %+.1f%% (ends the %+.1f%% return)[/color]" % [
			colour, "Effect roll", (after_value - before_value) * 100.0, before_value * 100.0,
		])

	# The Lens holds exactly one slot. When this swap moves it, the curse it
	# leaves weighs on the player again and the one it lands on stops.
	if after.suppressed_slot != before.suppressed_slot:
		if before.suppressed_slot >= 0 and before.suppressed_slot != slot:
			rows.append("[color=%s]Lens leaves %s — its %d%% curse weighs again[/color]" % [
				CMP_NEG_HEX, Inventory.slot_label(before.suppressed_slot).to_upper(),
				int(round(before.suppressed_severity * 100.0)),
			])
		if after.suppressed_slot >= 0 and after.suppressed_slot != slot:
			rows.append("[color=%s]Lens moves to %s — its %d%% curse → +%d%% returned[/color]" % [
				CMP_POS_HEX, Inventory.slot_label(after.suppressed_slot).to_upper(),
				int(round(after.suppressed_severity * 100.0)),
				int(round(BurdenResolver.inverted_return(after.suppressed_severity) * 100.0)),
			])
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


func _append_set_summary(lines: Array[String], set_id: StringName) -> void:
	var counts: Dictionary = _current_set_counts()
	var have: int = int(counts.get(set_id, 0))
	var data: SetData = _set_data(set_id)
	lines.append("")
	if data == null:
		lines.append(_head("SET // %s · %d EQUIPPED" % [String(set_id).to_upper(), have]))
		lines.append("[color=%s]ARCHIVE // RUN SHEET // SETS[/color]" % QUIET_HEX)
		return
	var maximum := maxi(1, data.max_pieces())
	lines.append("%s  [color=%s]%s  %d/%d[/color]" % [
		_head("SET // %s" % data.display_name.to_upper()), HEAD_HEX, _progress_pips(have, maximum), have, maximum,
	])
	var active_tier: SetTier = null
	var next_tier: SetTier = null
	for tier: SetTier in data.sorted_tiers():
		if tier == null:
			continue
		if have >= tier.required_count:
			active_tier = tier
		elif next_tier == null:
			next_tier = tier
	if active_tier != null:
		lines.append("ACTIVE // %s" % active_tier.display_name.to_upper())
	if next_tier != null:
		lines.append("NEXT // %d PIECES · %s" % [
			next_tier.required_count, next_tier.display_name.to_upper(),
		])
	lines.append("[color=%s]ARCHIVE // RUN SHEET // SETS[/color]" % QUIET_HEX)

func _append_replacement_preview(lines: Array[String], candidate: ItemInstance) -> void:
	if Global == null or Global.run_inventory == null or candidate == null or candidate.data == null:
		return
	var target_slot: int = int(candidate.data.equip_slot)
	if target_slot < 0 or target_slot >= Inventory.SLOT_COUNT:
		return
	var current: ItemInstance = Global.run_inventory.get_at(target_slot)
	lines.append("")
	lines.append(_head("EQUIP PREVIEW · %s" % Inventory.slot_label(target_slot).to_upper()))
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
