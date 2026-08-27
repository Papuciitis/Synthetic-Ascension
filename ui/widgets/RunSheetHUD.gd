extends PanelContainer
class_name RunSheetHUD

enum ArchivePage { PROFILE, SETS, MANIFESTATIONS, OBSERVATIONS }

const PAGE_LABELS := ["PROFILE", "SETS", "MANIFESTATIONS", "OBSERVATIONS"]

@onready var hpv: Label = $Archive/BodyMargin/Pages/ProfileScroll/Content/StatsGrid/HPV
@onready var armv: Label = $Archive/BodyMargin/Pages/ProfileScroll/Content/StatsGrid/ARMV
@onready var spdv: Label = $Archive/BodyMargin/Pages/ProfileScroll/Content/StatsGrid/SPDV
@onready var powv: Label = $Archive/BodyMargin/Pages/ProfileScroll/Content/StatsGrid/POWV
@onready var hstv: Label = $Archive/BodyMargin/Pages/ProfileScroll/Content/StatsGrid/HSTV
@onready var lckv: Label = $Archive/BodyMargin/Pages/ProfileScroll/Content/StatsGrid/LCKV

@onready var hpd: Label = $Archive/BodyMargin/Pages/ProfileScroll/Content/StatsGrid/HPD
@onready var armd: Label = $Archive/BodyMargin/Pages/ProfileScroll/Content/StatsGrid/ARMD
@onready var spdd: Label = $Archive/BodyMargin/Pages/ProfileScroll/Content/StatsGrid/SPDD
@onready var powd: Label = $Archive/BodyMargin/Pages/ProfileScroll/Content/StatsGrid/POWD
@onready var hstd: Label = $Archive/BodyMargin/Pages/ProfileScroll/Content/StatsGrid/HSTD
@onready var lckd: Label = $Archive/BodyMargin/Pages/ProfileScroll/Content/StatsGrid/LCKD

@onready var sets_vbox: VBoxContainer = $Archive/BodyMargin/Pages/SetsScroll/SetsVBox
@onready var manifestations_vbox: VBoxContainer = $Archive/BodyMargin/Pages/ManifestationsScroll/ManifestationsVBox
@onready var observations_vbox: VBoxContainer = $Archive/BodyMargin/Pages/ObservationsScroll/ObservationsVBox

@onready var _page_controls: Array[Control] = [
	$Archive/BodyMargin/Pages/ProfileScroll,
	$Archive/BodyMargin/Pages/SetsScroll,
	$Archive/BodyMargin/Pages/ManifestationsScroll,
	$Archive/BodyMargin/Pages/ObservationsScroll,
]
@onready var _page_buttons: Array[Button] = [
	$Archive/Index/Profile,
	$Archive/Index/Sets,
	$Archive/Index/Manifestations,
	$Archive/Index/Observations,
]

var _selected_page: int = ArchivePage.PROFILE
var _selected_set_id: StringName = &""
var _last_set_counts: Dictionary = {}
var _page_signatures := {
	ArchivePage.SETS: "__UNINITIALIZED__",
	ArchivePage.MANIFESTATIONS: "__UNINITIALIZED__",
	ArchivePage.OBSERVATIONS: "__UNINITIALIZED__",
}
var _rebuild_counts := {"sets": 0, "manifestations": 0, "observations": 0}
var _doctrine_events: Array[String] = []

const ACCENT := Color(1.0, 0.55, 0.20, 1.0)
## The layer's own colour. Anything naming a specific noun or rule uses that
## noun's colour from ManifestationNouns instead.
const MANIFEST := ManifestationNouns.LAYER


func _ready() -> void:
	for index in range(_page_buttons.size()):
		_page_buttons[index].pressed.connect(select_page.bind(index))
	select_page(_selected_page)
	if RunEvents != null and RunEvents.has_signal("doctrine_event_recorded"):
		var callback := Callable(self, "_on_doctrine_event_recorded")
		if not RunEvents.doctrine_event_recorded.is_connected(callback):
			RunEvents.doctrine_event_recorded.connect(callback)


func select_page(page: int) -> void:
	_selected_page = clampi(page, ArchivePage.PROFILE, ArchivePage.OBSERVATIONS)
	for index in range(_page_controls.size()):
		var selected := index == _selected_page
		_page_controls[index].visible = selected
		_page_buttons[index].set_pressed_no_signal(selected)
		_page_buttons[index].text = ("◆  " if selected else "◇  ") + PAGE_LABELS[index]


func selected_page() -> int:
	return _selected_page


func debug_rebuild_counts() -> Dictionary:
	return _rebuild_counts.duplicate()

func refresh(player: Node, inv: Inventory) -> void:
	if not visible:
		return
	_refresh_profile(player, inv)
	_refresh_sets(inv)
	_refresh_manifestations(player)
	_refresh_observations()


func _refresh_profile(player: Node, inv: Inventory) -> void:
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


func _refresh_sets(inv: Inventory) -> void:
	var counts := _set_counts(inv)
	_last_set_counts = counts.duplicate()
	var keys := counts.keys()
	keys.sort()
	var selected_exists := (
		_selected_set_id != &""
		and Global != null
		and Global.set_db.has(_selected_set_id)
	)
	if not keys.is_empty() and not selected_exists:
		_selected_set_id = StringName(keys[0])
	var signature := "%s|selected:%s" % [_set_signature(counts), String(_selected_set_id)]
	if signature == String(_page_signatures[ArchivePage.SETS]):
		return
	_page_signatures[ArchivePage.SETS] = signature
	_rebuild_counts["sets"] = int(_rebuild_counts["sets"]) + 1
	_rebuild_sets_page(counts, keys)


func inspect_set(set_id: StringName) -> void:
	if set_id == &"" or set_id == _selected_set_id:
		return
	_selected_set_id = set_id
	var keys := _last_set_counts.keys()
	keys.sort()
	_page_signatures[ArchivePage.SETS] = "%s|selected:%s" % [
		_set_signature(_last_set_counts), String(_selected_set_id),
	]
	_rebuild_counts["sets"] = int(_rebuild_counts["sets"]) + 1
	_rebuild_sets_page(_last_set_counts, keys)


func _rebuild_sets_page(counts: Dictionary, keys: Array) -> void:
	_clear_children(sets_vbox)
	_add_section_heading(sets_vbox, "SETS // EQUIPPED CONCORDANCES", ACCENT)
	var displayed_keys := keys.duplicate()
	if _selected_set_id != &"" and not displayed_keys.has(_selected_set_id):
		displayed_keys.append(_selected_set_id)
		displayed_keys.sort()
	if displayed_keys.is_empty():
		_add_target_line(sets_vbox, "NO ACTIVE CONCORDANCE", Color(1, 1, 1, 0.48), 11)
		return

	for sid in displayed_keys:
		var n: int = int(counts.get(sid, 0))
		var record := Button.new()
		record.focus_mode = Control.FOCUS_ALL
		record.flat = true
		record.alignment = HORIZONTAL_ALIGNMENT_LEFT
		record.add_theme_font_size_override("font_size", 12)
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
		var marker := "◆" if StringName(sid) == _selected_set_id else "◇"
		record.text = "%s  %s  %d/%d" % [marker, set_label.to_upper(), n, set_max]
		record.modulate = (ACCENT if StringName(sid) == _selected_set_id else Color(1, 1, 1, 0.72))
		record.pressed.connect(inspect_set.bind(StringName(sid)))
		sets_vbox.add_child(record)

	var selected_data: SetData = Global.set_db.get(_selected_set_id, null) as SetData
	if selected_data != null:
		_append_set_dossier(selected_data, int(counts.get(_selected_set_id, 0)))


func _append_set_dossier(data: SetData, equipped: int) -> void:
	var accent := data.accent_color if data.accent_color.a > 0.0 else ACCENT
	_add_section_heading(sets_vbox, "SET DOSSIER // %s" % data.display_name.to_upper(), accent)
	if data.identity_sentence != "":
		_add_set_body_line(data.identity_sentence, Color(1, 1, 1, 0.88), 12)
	if data.playstyle != "":
		_add_set_body_line("PLAYSTYLE // %s" % data.playstyle, Color(1, 1, 1, 0.70), 12)

	_add_set_body_line("PROGRESSION // %d/%d PIECES" % [
		equipped, maxi(1, data.max_pieces()),
	], accent, 12, &"InstitutionalHeading")
	var next_found := false
	var glossary_terms: Dictionary = {}
	for tier: SetTier in data.sorted_tiers():
		if tier == null:
			continue
		var state := "ACTIVE" if equipped >= tier.required_count else ("NEXT" if not next_found else "LATER")
		if equipped < tier.required_count and not next_found:
			next_found = true
		var marker := "✓" if state == "ACTIVE" else ("→" if state == "NEXT" else "○")
		_add_set_body_line("%s %s // %d PIECES // %s" % [
			marker, state, tier.required_count, tier.display_name,
		], accent if state == "ACTIVE" else Color(1, 1, 1, 0.62), 12, &"BodyStrong")
		if tier.mechanical_description != "":
			_add_set_body_line(tier.mechanical_description, Color(1, 1, 1, 0.78), 12)
		if tier.plain_description != "":
			_add_set_body_line("PLAIN // %s" % tier.plain_description, Color(1, 1, 1, 0.58), 12)
		for term: String in tier.glossary_terms:
			glossary_terms[term] = true

	if data.best_with != "":
		_add_set_body_line("BEST WITH // %s" % data.best_with, Color(1, 1, 1, 0.70), 12)
	if not glossary_terms.is_empty():
		_add_set_body_line("TERMS", accent, 12, &"InstitutionalHeading")
		for term_value: Variant in glossary_terms.keys():
			var term := String(term_value)
			var definition := String(data.glossary.get(term, ""))
			if definition != "":
				_add_set_body_line("• %s — %s" % [term, definition], Color(1, 1, 1, 0.62), 11)


func _add_set_body_line(
	text: String,
	colour: Color,
	font_size: int,
	variation: StringName = &""
) -> Label:
	var line := Label.new()
	line.text = text
	line.custom_minimum_size = Vector2(260, 0)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", font_size)
	line.modulate = colour
	if variation != &"":
		line.theme_type_variation = variation
	sets_vbox.add_child(line)
	return line


func _set_counts(inv: Inventory) -> Dictionary:
	var counts: Dictionary = {}
	if inv == null:
		return counts
	if inv.has_method("get_set_counts"):
		return inv.get_set_counts()
	for item_value in inv.items:
		var inst := item_value as ItemInstance
		if inst == null or inst.data == null:
			continue
		var set_id := String(inst.data.set_id)
		if set_id != "":
			counts[set_id] = int(counts.get(set_id, 0)) + 1
	return counts


func _set_signature(counts: Dictionary) -> String:
	var keys := counts.keys()
	keys.sort()
	var parts := PackedStringArray()
	for key in keys:
		parts.append("%s:%d" % [String(key), int(counts[key])])
	return "|".join(parts)


func _refresh_manifestations(player: Node) -> void:
	var signature := var_to_str(_manifestation_state(player))
	if signature == String(_page_signatures[ArchivePage.MANIFESTATIONS]):
		return
	_page_signatures[ArchivePage.MANIFESTATIONS] = signature
	_rebuild_counts["manifestations"] = int(_rebuild_counts["manifestations"]) + 1
	_clear_children(manifestations_vbox)
	_add_section_heading(manifestations_vbox, "MANIFESTATIONS // ACTIVE DOCTRINE", MANIFEST)
	_append_burden(player)
	_append_manifestations(player)
	_append_doctrine_record()
	if manifestations_vbox.get_child_count() == 1:
		_add_target_line(manifestations_vbox, "NO ACTIVE MANIFESTATION", Color(1, 1, 1, 0.48), 11)


func _on_doctrine_event_recorded(_event_id: StringName, label: String) -> void:
	if label.strip_edges() != "":
		var clean_label := label.strip_edges()
		if not _doctrine_events.has(clean_label):
			_doctrine_events.append(clean_label)
	_page_signatures[ArchivePage.MANIFESTATIONS] = "__DOCTRINE_EVENT__"


func _append_doctrine_record() -> void:
	if Global == null:
		return
	var stage_ids: Dictionary = Global.attempt_doctrine_stage_ids
	var recorded_events: Array[String] = Global.attempt_doctrine_events.duplicate()
	for local_event in _doctrine_events:
		if not recorded_events.has(local_event):
			recorded_events.append(local_event)
	if stage_ids.is_empty() and recorded_events.is_empty():
		return
	_add_line("", Color(1, 1, 1, 0.4), 8)
	_add_section_heading(manifestations_vbox, "DOCTRINE RECORD // INSCRIBED", ACCENT)
	for stage_id in [&"method", &"doctrine", &"apotheosis"]:
		var choice_id := StringName(str(stage_ids.get(String(stage_id), stage_ids.get(stage_id, ""))))
		if choice_id == StringName():
			continue
		var definition: MajorChoiceDef = Global.major_choice_db.get_def(choice_id)
		var title := definition.title if definition != null else String(choice_id)
		_add_target_line(manifestations_vbox, "%s // %s" % [String(stage_id).to_upper(), title.to_upper()], ACCENT, 11)
	if bool(Global.get_doctrine_rule(&"force_augment_identity", false)):
		_add_target_line(manifestations_vbox, "PERFECTED ENGINE // AUGMENT SEALS 3/3", ACCENT, 11)
	for event_label in recorded_events:
		_add_target_line(manifestations_vbox, event_label, Color(0.86, 0.35, 0.22, 1), 11)


func _manifestation_state(player: Node) -> Dictionary:
	if player == null:
		return {}
	var state := {}
	var burden := player.get("last_burden") as BurdenSnapshot
	if burden != null:
		state["burden"] = [
			burden.neg_count, burden.pos_count, burden.active_count,
			burden.total_active, burden.qualifying_count, burden.suppressed_slot,
			burden.suppressed_severity,
		]
	state["augment_ids"] = Global.permanent_augment_ids.duplicate() if Global != null else []
	state["doctrine_stage_ids"] = Global.attempt_doctrine_stage_ids.duplicate(true) if Global != null else {}
	state["doctrine_events"] = Global.attempt_doctrine_events.duplicate() if Global != null else _doctrine_events.duplicate()
	var runner := player.get_node_or_null("ManifestationRunner")
	if runner == null:
		return state
	if runner.has_method("get_active_summaries"):
		state["summaries"] = runner.call("get_active_summaries")
	if runner.has_method("get_active_pairs"):
		state["pairs"] = runner.call("get_active_pairs")
	if runner.has_method("get_noun_counts"):
		state["nouns"] = runner.call("get_noun_counts")
	if runner.has_method("get_meters"):
		state["meters"] = runner.call("get_meters")
	return state


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _add_section_heading(container: VBoxContainer, text: String, colour: Color) -> void:
	var heading := Label.new()
	heading.text = text
	heading.theme_type_variation = &"InstitutionalHeading"
	heading.add_theme_font_size_override("font_size", 13)
	heading.modulate = colour
	container.add_child(heading)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(colour.r, colour.g, colour.b, 0.42)
	container.add_child(rule)


func _add_target_line(container: VBoxContainer, text: String, colour: Color, font_size: int) -> Label:
	var line := Label.new()
	line.text = text
	line.add_theme_font_size_override("font_size", font_size)
	line.modulate = colour
	container.add_child(line)
	return line


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
		var doctrine_bonus: Dictionary = BurdenResolver.doctrine_bonus(level, snap.qualifying_count)
		var armour := float(doctrine_bonus["armor"])
		var hp := float(doctrine_bonus["hp"])
		var capped: bool = (
			armour >= BurdenResolver.doctrine_armor_cap - 0.001
			or hp >= BurdenResolver.doctrine_hp_cap - 0.0001
		)
		_add_line("DOCTRINE OF BURDEN", BURDEN, 11)
		_add_line(
			"   %d qualifying curses (≥%d%% of their range)  →  Armour +%d, Max HP +%d%%%s" % [
				snap.qualifying_count, int(BurdenSnapshot.QUALIFYING_BURDEN_RATIO * 100.0),
				int(round(armour)), int(round(hp * 100.0)),
				"  (CAPPED)" if capped else "",
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
		var entry_name: String = String(entry.get("name", ""))
		var entry_rule: String = String(entry.get("rule", ""))

		# One hoverable box per entry, so the pointer does not have to find the
		# two-line rule label specifically - the name is what a player aims at.
		var box := ManifestationInfoBox.new()
		box.add_theme_constant_override("separation", 0)
		box.setup(entry_name, _noun_names(entry_tags), entry_rule, entry_colour)
		manifestations_vbox.add_child(box)

		var heading := Label.new()
		heading.text = "%s  %s" % [slot_hint, entry_name]
		heading.add_theme_font_size_override("font_size", 12)
		heading.modulate = entry_colour
		heading.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(heading)

		var rule := Label.new()
		rule.text = "   " + entry_rule
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Trimmed here, complete on hover. Eight untrimmed paragraphs push the
		# panel past the bottom of a 1080p screen, but a rule the player cannot
		# read anywhere in the run is worse than a long panel.
		rule.max_lines_visible = 2
		rule.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		rule.custom_minimum_size = Vector2(260, 0)
		rule.add_theme_font_size_override("font_size", 12)
		rule.modulate = Color(1, 1, 1, 0.72)
		rule.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(rule)

	_append_manifestation_pairs(runner)


func _append_manifestation_pairs(runner: Node) -> void:
	if runner == null or not runner.has_method("get_active_pairs"):
		return
	var pairs: Array = runner.call("get_active_pairs")
	if pairs.is_empty():
		return

	_add_line("", Color(1, 1, 1, 0.4), 8)
	var section := _add_line("MANIFESTATION PAIRS", MANIFEST, 12)
	section.theme_type_variation = &"InstitutionalHeading"

	for pair_value in pairs:
		var pair := pair_value as Dictionary
		if pair == null or pair.is_empty():
			continue
		var nouns: Array = pair.get("nouns", []) as Array
		var accent := _pair_accent(nouns)
		var pair_name := String(pair.get("name", ""))
		var pair_rule := String(pair.get("rule", ""))
		var box := ManifestationInfoBox.new()
		box.add_theme_constant_override("separation", 1)
		box.setup(pair_name, _noun_names(nouns), pair_rule, accent)
		manifestations_vbox.add_child(box)

		var heading := Label.new()
		heading.text = pair_name
		heading.theme_type_variation = &"SacredHeading"
		heading.add_theme_font_size_override("font_size", 12)
		heading.modulate = accent
		heading.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(heading)

		var nouns_line := Label.new()
		nouns_line.text = _noun_names(nouns)
		nouns_line.add_theme_font_size_override("font_size", 12)
		nouns_line.modulate = Color(1, 1, 1, 0.55)
		nouns_line.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(nouns_line)

		var rule := Label.new()
		rule.text = "   " + pair_rule
		rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rule.custom_minimum_size = Vector2(260, 0)
		rule.add_theme_font_size_override("font_size", 12)
		rule.modulate = Color(1, 1, 1, 0.76)
		rule.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(rule)


func _refresh_observations() -> void:
	var ids := PackedStringArray()
	if Global != null:
		for enemy_id in Global.discovered_enemy_ids:
			ids.append(String(enemy_id))
	ids.sort()
	var signature := "|".join(ids)
	if signature == String(_page_signatures[ArchivePage.OBSERVATIONS]):
		return
	_page_signatures[ArchivePage.OBSERVATIONS] = signature
	_rebuild_counts["observations"] = int(_rebuild_counts["observations"]) + 1
	_clear_children(observations_vbox)
	_add_section_heading(observations_vbox, "OBSERVATIONS // INDEXED ARCHETYPES", ACCENT)
	if ids.is_empty():
		_add_target_line(observations_vbox, "NO ARCHETYPE INDEXED", Color(1, 1, 1, 0.48), 11)
		return

	for enemy_id_text in ids:
		var enemy_id := StringName(enemy_id_text)
		var entry := EnemyDossierCatalog.get_entry(enemy_id)
		if entry.is_empty():
			continue
		var archetype_name := String(entry.get("name", String(enemy_id).trim_prefix("enemy_").replace("_", " "))).to_upper()
		var record := VBoxContainer.new()
		record.add_theme_constant_override("separation", 0)
		record.focus_mode = Control.FOCUS_ALL
		record.mouse_filter = Control.MOUSE_FILTER_STOP
		record.tooltip_text = _observation_tooltip(entry)
		observations_vbox.add_child(record)

		var name_label := Label.new()
		name_label.text = "[ %s ]" % archetype_name
		name_label.theme_type_variation = &"BodyStrong"
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color(0.86, 0.62, 0.36, 1))
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		record.add_child(name_label)

		var counter := Label.new()
		counter.text = "COUNTER  //  %s" % String(entry.get("counter", "Observe and adapt."))
		counter.custom_minimum_size = Vector2(260, 0)
		counter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		counter.max_lines_visible = 2
		counter.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		counter.add_theme_font_size_override("font_size", 13)
		counter.modulate = Color(1, 1, 1, 0.78)
		counter.mouse_filter = Control.MOUSE_FILTER_PASS
		record.add_child(counter)


func _observation_tooltip(entry: Dictionary) -> String:
	return "“%s”\n\nROLE  //  %s\nBEHAVIOUR  //  %s\nEXPECT  //  %s\nCOUNTER  //  %s" % [
		String(entry.get("quote", "")),
		String(entry.get("role", "Unclassified")),
		String(entry.get("behaviour", "Unknown")),
		String(entry.get("expect", "Unknown")),
		String(entry.get("counter", "Observe and adapt.")),
	]


func _pair_accent(nouns: Array) -> Color:
	if nouns.is_empty():
		return MANIFEST
	var accent := ManifestationNouns.colour(StringName(nouns[0]))
	if nouns.size() > 1:
		accent = accent.lerp(ManifestationNouns.colour(StringName(nouns[1])), 0.5)
	return accent


## "momentum, cadence" - the nouns a rule declares, for the hover card.
func _noun_names(tags: Array) -> String:
	if tags.is_empty():
		return ""
	var names: PackedStringArray = PackedStringArray()
	for tag in tags:
		names.append(ManifestationNouns.label(tag))
	return " · ".join(names)


## One line made of several per-noun labels, so each noun can carry its own
## colour. A Label cannot colour a span, and the noun colours are the whole
## point of the line - "MOMENTUM 2" in the same orange the item badge and the
## HUD counter use is what makes the vocabulary learnable.
func _add_noun_row(parts: Array[Dictionary], font_size: int) -> void:
	if parts.is_empty():
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	manifestations_vbox.add_child(row)
	for part in parts:
		var label := Label.new()
		label.text = String(part.get("text", ""))
		label.add_theme_font_size_override("font_size", maxi(12, font_size))
		label.modulate = ManifestationNouns.colour(StringName(part.get("noun", &"")))
		row.add_child(label)


func _add_line(text: String, colour: Color, font_size: int) -> Label:
	return _add_target_line(
		manifestations_vbox,
		text,
		colour,
		font_size if text.is_empty() else maxi(12, font_size)
	)

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
