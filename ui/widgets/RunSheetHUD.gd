extends PanelContainer
class_name RunSheetHUD

@onready var hpv: Label = $Margin/VBox/StatsGrid/HPV
@onready var armv: Label = $Margin/VBox/StatsGrid/ARMV
@onready var spdv: Label = $Margin/VBox/StatsGrid/SPDV
@onready var powv: Label = $Margin/VBox/StatsGrid/POWV
@onready var hstv: Label = $Margin/VBox/StatsGrid/HSTV
@onready var lckv: Label = $Margin/VBox/StatsGrid/LCKV

@onready var hpd: Label = $Margin/VBox/StatsGrid/HPD
@onready var armd: Label = $Margin/VBox/StatsGrid/ARMD
@onready var spdd: Label = $Margin/VBox/StatsGrid/SPDD
@onready var powd: Label = $Margin/VBox/StatsGrid/POWD
@onready var hstd: Label = $Margin/VBox/StatsGrid/HSTD
@onready var lckd: Label = $Margin/VBox/StatsGrid/LCKD

@onready var sets_vbox: VBoxContainer = $Margin/VBox/SetsVBox

const ACCENT := Color(1.0, 0.55, 0.20, 1.0)
## The layer's own colour. Anything naming a specific noun or rule uses that
## noun's colour from ManifestationNouns instead.
const MANIFEST := ManifestationNouns.LAYER

func refresh(player: Node, inv: Inventory) -> void:
	# The HUD ticks this at 10 Hz whether or not the panel is on screen, and a
	# refresh rebuilds every child label and asks each equipped Manifestation to
	# format its rule text. None of that is worth paying for while hidden.
	if not visible:
		return
	# Player.stats is already the complete final snapshot: race, style, permanent
	# augments, attempt modifiers, equipped item deltas, set tiers, item effects
	# and active percentage rolls. Inventory deltas must not be added a second time.
	var max_hp_total: float = _get_num(player, "max_hp", _get_stats_num(player, "max_hp", 0.0))
	var armor_total: float = _get_stats_num(player, "armor", _get_num(player, "armor", 0.0))
	var stored_spd: float = _get_stats_num(player, "move_speed", _get_num(player, "speed", 0.0))
	var spd_total: float = _get_effective_move_speed(player, stored_spd)
	var pow_total: float = _get_stats_num(player, "power", _get_num(player, "power", 0.0))
	var hst_total: float = _get_stats_num(player, "haste", _get_num(player, "haste", 0.0))
	var lck_total: float = _get_stats_num(player, "luck", _get_num(player, "luck", 0.0))

	# Parenthesised values remain the equipped flat deltas for quick attribution;
	# they are informational only and are not added to the final totals again.
	var d := StatDelta.new()
	if inv != null and inv.has_method("sum_mods"):
		d = inv.sum_mods()

	# --- totals ---
	var cur_hp: float = _get_num(player, "hp", -1.0)
	if cur_hp >= 0.0:
		hpv.text = "%d / %d" % [int(round(cur_hp)), int(round(maxf(1.0, max_hp_total)))]
	else:
		hpv.text = str(int(round(maxf(1.0, max_hp_total))))

	armv.text = str(int(round(armor_total)))
	spdv.text = str(int(round(spd_total)))
	powv.text = _fmt_pct_fraction(pow_total)
	hstv.text = _fmt_pct_fraction(hst_total)
	lckv.text = _fmt_pct_fraction(lck_total)

	# --- deltas (from items) ---
	hpd.text = _fmt_int_delta(d.max_hp)      # show max hp delta
	armd.text = _fmt_int_delta(d.armor)
	spdd.text = _fmt_int_delta(d.move_speed)
	powd.text = _fmt_pct_delta(d.power)
	hstd.text = _fmt_pct_delta(d.haste)
	lckd.text = _fmt_pct_delta(d.luck)

	# --- sets ---
	for c in sets_vbox.get_children():
		c.queue_free()

	if inv == null:
		return

	var counts: Dictionary = {}
	if inv.has_method("get_set_counts"):
		counts = inv.get_set_counts()
	else:
		for it in inv.items:
			var inst := it as ItemInstance
			if inst == null or inst.data == null:
				continue
			var sid := String(inst.data.set_id)
			if sid == "":
				continue
			counts[sid] = int(counts.get(sid, 0)) + 1

	for sid in counts.keys():
		var n: int = int(counts[sid])
		var line := Label.new()
		line.add_theme_font_size_override("font_size", 12)
		# Display name and real piece count from the set DB, not internal
		# ids with a hardcoded /6.
		var set_label := String(sid).to_upper()
		var set_max := 6
		var sd: SetData = Global.set_db.get(StringName(sid), null) as SetData
		if sd != null:
			if sd.display_name != "":
				set_label = sd.display_name
			if sd.has_method("max_pieces"):
				set_max = maxi(1, int(sd.call("max_pieces")))
		line.text = "%s %d/%d" % [set_label, n, set_max]
		line.modulate = (ACCENT if n >= set_max else Color(1, 1, 1, 0.85))
		sets_vbox.add_child(line)

	_append_burden(player)
	_append_manifestations(player)


const BURDEN := Color(0.85, 0.42, 0.95, 1.0)


## The curse ledger, showing the ARITHMETIC rather than the augment's name.
##
## Three archetypes read the same wardrobe and disagree about it, so "Corruption
## Engine: active" tells the player nothing they can act on. What they need is
## which curses are live, which one is switched off, and what the augment turned
## that into.
func _append_burden(player: Node) -> void:
	if player == null:
		return
	var snap: BurdenSnapshot = player.get("last_burden") as BurdenSnapshot
	if snap == null or (snap.neg_count <= 0 and snap.pos_count <= 0):
		return
	if snap.neg_count <= 0:
		return

	_add_line("", Color(1, 1, 1, 0.4), 8)
	_add_line("BURDEN", BURDEN, 12)
	_add_line(
		"%d NEG / %d POS   ·   %d active   ·   %d%% total severity" % [
			snap.neg_count, snap.pos_count, snap.active_count,
			int(round(snap.total_active * 100.0)),
		],
		Color(1, 1, 1, 0.80), 11
	)

	var ids: Array = Global.permanent_augment_ids if Global != null else []

	if ids.has(&"augment_corruption_engine"):
		var top_two := snap.heaviest(2)
		var rate := BurdenResolver.asymptotic_rate(
			0.24, Global.get_augment_level(&"augment_corruption_engine")
		)
		_add_line("CORRUPTION ENGINE", BURDEN, 11)
		_add_line(
			"   top two active: %d%%  ×  %d%%/100%%  →  Power +%.1f%%%s" % [
				int(round(top_two * 100.0)), int(round(rate * 100.0)),
				minf(0.30, top_two * rate) * 100.0,
				"  (CAPPED)" if top_two * rate > 0.30 else "",
			],
			Color(1, 1, 1, 0.72), 10
		)

	if ids.has(&"augment_doctrine_of_burden"):
		var level: int = Global.get_augment_level(&"augment_doctrine_of_burden")
		var armour := BurdenResolver.asymptotic_rate(16.0, level) * float(snap.qualifying_count)
		var hp := BurdenResolver.asymptotic_rate(0.09, level) * float(snap.qualifying_count)
		_add_line("DOCTRINE OF BURDEN", BURDEN, 11)
		_add_line(
			"   %d qualifying curses (≥%d%%)  →  Armour +%d, Max HP +%d%%" % [
				snap.qualifying_count, int(BurdenSnapshot.QUALIFYING_BURDEN * 100.0),
				int(round(armour)), int(round(hp * 100.0)),
			],
			Color(1, 1, 1, 0.72), 10
		)

	if ids.has(&"augment_inversion_lens"):
		_add_line("INVERSION LENS", BURDEN, 11)
		if snap.suppressed_slot >= 0:
			_add_line(
				"   %s suppressed: %d%% curse  →  +%d%% returned, 0%% burden" % [
					Inventory.slot_label(snap.suppressed_slot).to_upper(),
					int(round(snap.suppressed_severity * 100.0)),
					int(round(BurdenResolver.inverted_return(snap.suppressed_severity) * 100.0)),
				],
				Color(1, 1, 1, 0.72), 10
			)
		else:
			_add_line("   nothing cursed to suppress", Color(1, 1, 1, 0.55), 10)


func _append_manifestations(player: Node) -> void:
	# The chain readout. Sets say what the build IS; this says what this
	# particular run mutated into, in the order the slots are worn.
	if player == null:
		return
	var runner: Node = player.get_node_or_null("ManifestationRunner")
	if runner == null or not runner.has_method("get_active_summaries"):
		return
	var summaries: Array = runner.call("get_active_summaries")
	if summaries.is_empty():
		return

	_add_line("", Color(1, 1, 1, 0.4), 8)
	_add_line("MANIFESTATIONS", MANIFEST, 12)

	# Noun counts first. Two of a noun is what makes two unrelated items combine,
	# so "MOMENTUM 2" is the single most useful line on the panel - it is the
	# readout that tells you one more movement item would turn something on.
	if runner.has_method("get_noun_counts"):
		var counts: Dictionary = runner.call("get_noun_counts")
		var parts: Array[Dictionary] = []
		# Authored order, so the line does not reshuffle itself every time an
		# unrelated item is equipped.
		for noun in ManifestationNouns.ORDER:
			var n: int = int(counts.get(noun, 0))
			if n <= 0:
				continue
			parts.append({
				"noun": noun,
				"text": "%s %d%s" % [ManifestationNouns.label(noun), n, "*" if n >= 2 else ""],
			})
		_add_noun_row(parts, 11)

	# Live resources first: with eight rules equipped the list below is long,
	# and the numbers the player acts on mid-fight must not be the part that
	# falls off the bottom of the panel.
	if runner.has_method("get_meters"):
		var meters: Array = runner.call("get_meters")
		var readout: Array[Dictionary] = []
		for meter_value in meters:
			var meter: Dictionary = meter_value
			readout.append({
				"noun": StringName(meter.get("noun", &"")),
				"text": "%s %s" % [String(meter.get("label", "")), String(meter.get("text", ""))],
			})
		_add_noun_row(readout, 11)

	for entry_value in summaries:
		var entry: Dictionary = entry_value
		var slot_hint: String = Inventory.slot_hint(int(entry.get("slot", -1)))
		var entry_tags: Array = entry.get("tags", []) as Array
		var entry_colour: Color = ManifestationNouns.colour(entry_tags[0]) if not entry_tags.is_empty() else MANIFEST
		_add_line("%s  %s" % [slot_hint, String(entry.get("name", ""))], entry_colour, 12)
		var rule := Label.new()
		rule.text = "   " + String(entry.get("rule", ""))
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# The full rule lives in the item tooltip; eight untrimmed paragraphs
		# push the panel past the bottom of a 1080p screen.
		rule.max_lines_visible = 2
		rule.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		rule.custom_minimum_size = Vector2(260, 0)
		rule.add_theme_font_size_override("font_size", 10)
		rule.modulate = Color(1, 1, 1, 0.72)
		sets_vbox.add_child(rule)


## One line made of several per-noun labels, so each noun can carry its own
## colour. A Label cannot colour a span, and the noun colours are the whole
## point of the line - "MOMENTUM 2" in the same orange the item badge and the
## HUD counter use is what makes the vocabulary learnable.
func _add_noun_row(parts: Array[Dictionary], font_size: int) -> void:
	if parts.is_empty():
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	sets_vbox.add_child(row)
	for part in parts:
		var label := Label.new()
		label.text = String(part.get("text", ""))
		label.add_theme_font_size_override("font_size", font_size)
		label.modulate = ManifestationNouns.colour(StringName(part.get("noun", &"")))
		row.add_child(label)


func _add_line(text: String, colour: Color, font_size: int) -> void:
	var line := Label.new()
	line.text = text
	line.add_theme_font_size_override("font_size", font_size)
	line.modulate = colour
	sets_vbox.add_child(line)

# ---------------------------d
# ---------------------------

func _fmt_int_delta(x: float) -> String:
	var v: int = int(round(x))
	if v == 0:
		return ""
	return "(%+d)" % v

func _fmt_pct_delta(x: float) -> String:
	# x is fraction: 0.20 => +20%
	var p: float = x * 100.0
	if is_equal_approx(p, 0.0):
		return ""
	if absf(p) < 0.01:
		return "(+<0.01%)" if p > 0.0 else "(−<0.01%)"
	if is_equal_approx(p, float(int(p))):
		return "(%+.0f%%)" % p
	return "(%+.2f%%)" % p

func _fmt_pct_fraction(x: float) -> String:
	# x is fraction: 0.20 => +20%
	var p: float = x * 100.0
	if is_equal_approx(p, 0.0):
		return "0%"
	if absf(p) < 0.01:
		return "+<0.01%" if p > 0.0 else "−<0.01%"
	if is_equal_approx(p, float(int(p))):
		return "%+.0f%%" % p
	return "%+.2f%%" % p

# ---------------------------
# Safe getters
# ---------------------------

func _get_num(obj: Object, prop: String, fallback: float) -> float:
	if obj == null:
		return fallback
	var v: Variant = obj.get(prop)
	if v is float or v is int:
		return float(v)
	return fallback

func _get_effective_move_speed(player: Object, fallback: float) -> float:
	if player == null:
		return fallback
	if player.has_method("get_effective_move_speed"):
		var value: Variant = player.call("get_effective_move_speed")
		if value is float or value is int:
			return float(value)
	return fallback


func _get_stats_num(player: Object, prop: String, fallback: float) -> float:
	if player == null:
		return fallback
	var stats: Variant = player.get("stats")
	if stats == null:
		return fallback
	if stats is Object:
		var v: Variant = (stats as Object).get(prop)
		if v is float or v is int:
			return float(v)
	return fallback
