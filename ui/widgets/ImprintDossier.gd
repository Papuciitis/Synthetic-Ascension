extends RefCounted
## The imprinter's hover dossiers (ui/screens/ImprintScreen.gd), written in
## the item tooltip's register and shown through its panel
## (ItemTooltip.show_lines()).
##
## * held(): what a held imprint adds. The whole rule with real numbers on an
##   item it could go onto, those numbers one per line, how they scale with
##   the item's rank, its nouns in their colours, the slots it takes, and what
##   it would light or break among the rules the player wears.
## * preview(): the full before -> after of putting it onto one item. The rule
##   lost and the rule gained with this item's numbers, every number that
##   changes, the nouns and pairs that change, what equipping a bagged item
##   would change against what is worn now, the item's own stats (which an
##   imprint never touches), and the price.
##
## Nothing here restates a rule. ManifestationCatalog.describe() and
## stat_effects() render each rule on a detached node with the item's rank,
## nouns are counted the way ManifestationRunner counts them (distinct rules),
## pairs come from ManifestationPairCatalog with the runner's mean-rank
## scaling, and the equip comparison is ItemTooltip.build_comparison_rows() on
## a copy of the item carrying the imprint.
##
## Preload by path; no class_name.

const POS_HEX: String = ItemTooltip.CMP_POS_HEX
const NEG_HEX: String = ItemTooltip.CMP_NEG_HEX
const NEUTRAL_HEX: String = ItemTooltip.CMP_NEUTRAL_HEX
const HEAD_HEX: String = ItemTooltip.HEAD_HEX
const QUIET_HEX: String = ItemTooltip.QUIET_HEX
const PRICE_HEX: String = "#E8C27A"
## How the Momentum rules turn pixels into the metres they quote.
const PIXELS_PER_METRE: float = 32.0
## Fitting items the held dossier lists before it says how many more there are.
const LIST_LIMIT: int = 5


## Header and lines for a held imprint, for ItemTooltip.show_lines():
## {title, meta, meta_colour, kicker, lines}. Empty for an unknown rule.
static func held(imprint_id: StringName) -> Dictionary:
	var def := ManifestationCatalog.get_def(imprint_id)
	if def == null:
		return {}
	var fitting: Array[Dictionary] = []
	for candidate in ImprintService.candidates(imprint_id):
		var inst: ItemInstance = candidate["inst"]
		if def.allows_slot(int(inst.data.equip_slot)):
			fitting.append(candidate)
	# The numbers as they would apply: on the highest-ranked worn item it fits,
	# else the highest-ranked bagged one, else at rank 0. Each item's own
	# numbers are its before -> after on the right.
	var reference: Dictionary = {}
	var best := -1.0
	for candidate in fitting:
		var worn_bonus := 1000.0 if String(candidate["where"]) == "worn" else 0.0
		var score: float = worn_bonus + float(ManifestationCatalog.scaling_on(candidate["inst"])["rank"])
		if score > best:
			best = score
			reference = candidate
	var on_item: ItemInstance = null
	if not reference.is_empty():
		on_item = _carrying(reference["inst"], imprint_id)

	var lines: Array[String] = []
	lines.append(_noun_line(def.tags))
	lines.append("")
	lines.append(_head("THE RULE"))
	lines.append("[color=%s]%s[/color]" % [_rule_hex(imprint_id), ManifestationCatalog.describe(imprint_id, on_item)])
	if on_item != null:
		lines.append("[color=%s]Numbers as they read on %s.[/color]" % [QUIET_HEX, _item_ref(reference)])
	else:
		lines.append("[color=%s]Numbers at rank 0: nothing you carry takes this rule.[/color]" % QUIET_HEX)
	lines.append("")
	lines.append(_head("WHAT IT ADDS"))
	_append_numbers(lines, ManifestationCatalog.stat_effects(imprint_id, on_item), "•", false)
	_append_scaling(lines, on_item, false)

	lines.append("")
	lines.append(_head("GOES ON"))
	lines.append(_slot_names(def.slots))
	if fitting.is_empty():
		lines.append("[color=%s]Nothing you wear or carry has one of those slots.[/color]" % QUIET_HEX)
	for index in range(mini(fitting.size(), LIST_LIMIT)):
		var candidate: Dictionary = fitting[index]
		var verdict: String = ("%d Followers" % int(candidate["price"])) if bool(candidate["ok"]) else String(candidate["reason"])
		lines.append("• %s  [color=%s]%s[/color]" % [_item_ref(candidate), QUIET_HEX if bool(candidate["ok"]) else NEG_HEX, verdict])
	if fitting.size() > LIST_LIMIT:
		lines.append("[color=%s]and %d more[/color]" % [QUIET_HEX, fitting.size() - LIST_LIMIT])

	_append_gear_fit(lines, def, fitting)
	lines.append("")
	lines.append("[color=%s]Hover an item on the right for the full before → after.[/color]" % QUIET_HEX)
	return {
		"title": def.display_name,
		"meta": "HELD IMPRINT  ·  %s" % _slot_names(def.slots).to_upper(),
		"meta_colour": ManifestationNouns.colour(def.primary_tag()) if def.primary_tag() != &"" else ManifestationNouns.LAYER,
		"kicker": "IMPRINT // HELD RULE",
		"lines": lines,
	}


## Header and lines for putting `imprint_id` onto one candidate from
## ImprintService.candidates(): {title, meta, meta_colour, kicker, lines,
## icon, rarity}. Empty when the rule or the item is gone.
static func preview(imprint_id: StringName, candidate: Dictionary, tip: ItemTooltip) -> Dictionary:
	var def := ManifestationCatalog.get_def(imprint_id)
	var inst: ItemInstance = candidate.get("inst", null)
	if def == null or inst == null or inst.data == null:
		return {}
	var worn_now: bool = String(candidate.get("where", "")) == "worn"
	var slot: int = int(inst.data.equip_slot)
	var after := _carrying(inst, imprint_id)
	var lines: Array[String] = []

	# The decision first: what it costs, or why it cannot happen.
	var price: int = int(candidate.get("price", 0))
	var wallet: int = int(Global.followers) if Global != null else 0
	if bool(candidate.get("ok", false)):
		lines.append("[color=%s]Imprint costs %d Followers  ·  %d → %d[/color]" % [PRICE_HEX, price, wallet, wallet - price])
	else:
		lines.append("[color=%s]Cannot apply: %s.[/color]  [color=%s]Price %d Followers.[/color]" % [NEG_HEX, String(candidate.get("reason", "")), QUIET_HEX, price])

	if not def.allows_slot(slot):
		lines.append("")
		lines.append("%s goes on %s; this is a %s item." % [def.display_name, _slot_names(def.slots), _slot_label(slot)])
		return _preview_header(inst, worn_now, lines)
	if inst.manifestation_id == imprint_id:
		lines.append("")
		lines.append(_head("ALREADY CARRIES IT"))
		_append_rule(lines, imprint_id, inst)
		_append_numbers(lines, ManifestationCatalog.stat_effects(imprint_id, inst), "•", false)
		return _preview_header(inst, worn_now, lines)

	lines.append("")
	lines.append(_head("RULE LOST"))
	if inst.has_manifestation():
		_append_rule(lines, inst.manifestation_id, inst)
		var kept: String = "Kept as an imprint; it can go back on later." if Global == null or not Global.attempt_imprints.has(inst.manifestation_id) else "Already held as an imprint."
		lines.append("[color=%s]%s[/color]" % [QUIET_HEX, kept])
	else:
		lines.append("[color=%s]None: this item carries no rule, so nothing is lost.[/color]" % QUIET_HEX)
	lines.append("")
	lines.append(_head("RULE GAINED"))
	_append_rule(lines, imprint_id, after)

	lines.append("")
	lines.append(_head("WHAT CHANGES"))
	if inst.has_manifestation():
		_append_numbers(lines, ManifestationCatalog.stat_effects(inst.manifestation_id, inst), "−", true)
	_append_numbers(lines, ManifestationCatalog.stat_effects(imprint_id, after), "+", false)
	_append_scaling(lines, inst, inst.has_manifestation())

	var worn := _worn_items()
	var equipped := worn.duplicate()
	if slot >= 0 and slot < equipped.size():
		equipped[slot] = after
	if worn_now:
		lines.append("")
		lines.append(_head("NOUNS & PAIRS · WHILE WORN"))
		_append_noun_diff(lines, worn, equipped, imprint_id, slot)
	else:
		lines.append("")
		lines.append(_head("IN THE BAG"))
		lines.append("[color=%s]Rules run only while worn: applying it changes nothing you wear until this item is equipped.[/color]" % NEUTRAL_HEX)
		var current: ItemInstance = worn[slot] if slot >= 0 and slot < worn.size() else null
		lines.append("")
		lines.append(_head("IF EQUIPPED · %s" % _slot_label(slot).to_upper()))
		if current != null and current.data != null:
			lines.append("Replaces %s (%s)." % [current.data.display_name, ManifestationCatalog.display_name(current.manifestation_id) if current.has_manifestation() else "no rule"])
			var rows: Array[String] = []
			if current.rolled_mods != null and after.rolled_mods != null:
				rows = tip.build_comparison_rows(current, after, Global.run_inventory, Global.permanent_augment_ids)
			if rows.is_empty():
				lines.append("[color=%s]No numeric stat change.[/color]" % NEUTRAL_HEX)
			for row in rows:
				lines.append(row)
			# The worn item's rule leaves with it; its numbers go too.
			if current.has_manifestation() and current.manifestation_id != imprint_id:
				_append_numbers(lines, ManifestationCatalog.stat_effects(current.manifestation_id, current), "−", true)
		else:
			lines.append("Fills the empty slot.")
			var stats: Array[String] = tip._format_delta(after.rolled_mods)
			if not stats.is_empty():
				lines.append("[color=%s]%s[/color]" % [POS_HEX, "  ·  ".join(stats)])
		_append_noun_diff(lines, worn, equipped, imprint_id, slot)

	lines.append("")
	lines.append(_head("THE ITEM"))
	var own: Array[String] = tip._format_delta(inst.rolled_mods)
	lines.append("[color=%s]An imprint swaps the rule only: rank, stats, roll, set and sell value stay as they are%s[/color]" % [
		NEUTRAL_HEX, (" (%s)." % "  ·  ".join(own)) if not own.is_empty() else ".",
	])
	return _preview_header(inst, worn_now, lines)


static func _preview_header(inst: ItemInstance, worn_now: bool, lines: Array[String]) -> Dictionary:
	return {
		"title": inst.data.display_name,
		"meta": "%s  ·  R%d  ·  %s" % [_slot_label(int(inst.data.equip_slot)).to_upper(), int(inst.rarity), "WORN" if worn_now else "IN THE BAG"],
		"meta_colour": ItemTooltip.POS if inst.polarity == ItemInstance.Polarity.POS else ItemTooltip.NEG,
		"kicker": "IMPRINT // BEFORE → AFTER",
		"lines": lines,
		"icon": inst.data.icon,
		"rarity": int(inst.rarity),
	}


# ------------------------------------------------------------------ the rule

## A copy of the item carrying the imprint: what the item would be after.
static func _carrying(inst: ItemInstance, imprint_id: StringName) -> ItemInstance:
	var copy := inst.snapshot_copy()
	copy.manifestation_id = imprint_id
	return copy


## The rule's name in its noun's colour, its nouns, and its whole text with
## this item's numbers.
static func _append_rule(lines: Array[String], rule_id: StringName, inst: ItemInstance) -> void:
	var hex := _rule_hex(rule_id)
	lines.append("[color=%s]%s[/color]  %s" % [hex, ManifestationCatalog.display_name(rule_id).to_upper(), _noun_line(ManifestationCatalog.tags_of(rule_id))])
	lines.append("[color=%s]%s[/color]" % [hex, ManifestationCatalog.describe(rule_id, inst)])


## One line per number (ManifestationCatalog.stat_effects()). Green helps the
## player and red costs them: gaining a benefit or losing a penalty is green.
static func _append_numbers(lines: Array[String], entries: Array[Dictionary], mark: String, lost: bool) -> void:
	for entry in entries:
		var helps: bool = bool(entry.get("good", true)) != lost
		var when := String(entry.get("when", ""))
		lines.append("[color=%s]%s %s  %s[/color]%s" % [
			POS_HEX if helps else NEG_HEX,
			mark,
			String(entry.get("stat", "")),
			String(entry.get("value", "")),
			("[color=%s] — %s[/color]" % [QUIET_HEX, when]) if not when.is_empty() else "",
		])


## How the item's rank bends the rule (ManifestationEffect's scaling curves).
static func _append_scaling(lines: Array[String], inst: ItemInstance, both: bool) -> void:
	var cap_rank: float = (ManifestationEffect.POTENCY_CAP - 1.0) / ManifestationEffect.POTENCY_PER_RANK
	var per_rank: String = "Each rank adds %.1f%% to effects (up to x%.2f by rank %.1f) and shortens waits and intervals %.0f%% (to x%.2f)." % [
		ManifestationEffect.POTENCY_PER_RANK * 100.0,
		ManifestationEffect.POTENCY_CAP,
		cap_rank,
		ManifestationEffect.THRESHOLD_EASE_PER_RANK * 100.0,
		ManifestationEffect.THRESHOLD_FLOOR,
	]
	if inst == null:
		lines.append("[color=%s]Rank 0 numbers. %s[/color]" % [QUIET_HEX, per_rank])
		return
	var scaling := ManifestationCatalog.scaling_on(inst)
	lines.append("[color=%s]%s this item's rank, %.2f: effects x%.2f, waits and intervals x%.2f. %s[/color]" % [
		QUIET_HEX,
		"Both rules read" if both else "It reads",
		float(scaling["rank"]),
		float(scaling["potency"]),
		float(scaling["threshold_scale"]),
		per_rank,
	])


# ------------------------------------------------------------------ nouns and pairs

## The eight worn slots (null where empty).
static func _worn_items() -> Array:
	var out: Array = []
	out.resize(Inventory.SLOT_COUNT)
	if Global == null or Global.run_inventory == null:
		return out
	for slot in range(Inventory.SLOT_COUNT):
		out[slot] = Global.run_inventory.get_at(slot)
	return out


## noun -> how many DISTINCT worn rules declare it, the way
## ManifestationRunner.get_noun_counts() counts: two copies of one rule are a
## duplicate, never a second claimer.
static func _noun_counts(items: Array) -> Dictionary:
	var counts: Dictionary = {}
	var seen: Dictionary = {}
	for value in items:
		var inst := value as ItemInstance
		if inst == null or inst.data == null or not inst.has_manifestation() or seen.has(inst.manifestation_id):
			continue
		seen[inst.manifestation_id] = true
		for tag in ManifestationCatalog.tags_of(inst.manifestation_id):
			counts[tag] = int(counts.get(tag, 0)) + 1
	return counts


static func _pair_ids(counts: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for def in ManifestationPairCatalog.active_for_counts(counts):
		out.append(def.id)
	return out


## A pair has no item, so it scales at the mean rank of the worn rules that
## speak either of its nouns (ManifestationRunner._mean_rarity_for()).
static func _pair_rank(items: Array, def: ManifestationPairDef) -> float:
	var total := 0.0
	var count := 0
	for value in items:
		var inst := value as ItemInstance
		if inst == null or not inst.has_manifestation():
			continue
		for tag in ManifestationCatalog.tags_of(inst.manifestation_id):
			if def.involves(tag):
				total += float(ManifestationCatalog.scaling_on(inst)["rank"])
				count += 1
				break
	return total / float(count) if count > 0 else 0.0


## What a change of worn rules does to the nouns, the noun-wide effects, the
## pairs and duplicates, from `before` to `after` (both full slot arrays).
static func _append_noun_diff(lines: Array[String], before: Array, after: Array, imprint_id: StringName, slot: int) -> void:
	var before_counts := _noun_counts(before)
	var after_counts := _noun_counts(after)
	var threshold := ManifestationPairCatalog.NOUN_THRESHOLD
	var parts := PackedStringArray()
	var passives: Array[String] = []
	for noun in ManifestationNouns.ORDER:
		var was := int(before_counts.get(noun, 0))
		var now := int(after_counts.get(noun, 0))
		if was == now:
			continue
		var change := ""
		if now >= threshold and was < threshold:
			change = " lit"
		elif was >= threshold and now < threshold:
			change = " unlit"
		parts.append("[color=%s]%s[/color] %d → %d%s" % [ManifestationNouns.hex(noun), ManifestationNouns.label(noun), was, now, change])
		var passive := _noun_passive(noun)
		if passive.is_empty():
			continue
		if was == 0:
			passives.append("[color=%s]+ %s[/color]" % [POS_HEX, passive])
		elif now == 0:
			passives.append("[color=%s]− %s[/color]" % [NEG_HEX, passive])
	if parts.is_empty():
		lines.append("[color=%s]No noun count changes.[/color]" % NEUTRAL_HEX)
	else:
		lines.append("Nouns  " + ("[color=%s]  ·  [/color]" % NEUTRAL_HEX).join(parts))
	lines.append_array(passives)

	var before_pairs := _pair_ids(before_counts)
	var after_pairs := _pair_ids(after_counts)
	var pair_lines := 0
	for id in after_pairs:
		if before_pairs.has(id):
			continue
		var def := ManifestationPairCatalog.get_def(id)
		lines.append("[color=%s]+ PAIR %s[/color]  %s" % [POS_HEX, def.display_name.to_upper(), _noun_line(def.nouns)])
		lines.append(ManifestationPairCatalog.describe(id, _pair_rank(after, def)))
		pair_lines += 1
	for id in before_pairs:
		if after_pairs.has(id):
			continue
		var def := ManifestationPairCatalog.get_def(id)
		lines.append("[color=%s]− PAIR %s goes dark: %s[/color]" % [NEG_HEX, def.display_name.to_upper(), def.rule])
		pair_lines += 1
	if pair_lines == 0:
		lines.append("[color=%s]No pair comes online or goes dark.[/color]" % NEUTRAL_HEX)

	# A second copy of a worn rule is a duplicate, not a second claimer.
	for other_slot in range(before.size()):
		var other := before[other_slot] as ItemInstance
		if other_slot != slot and other != null and other.manifestation_id == imprint_id:
			lines.append("[color=%s]Already worn on %s: a second copy lights no extra noun, and its multipliers count at %d%%.[/color]" % [
				NEG_HEX, other.data.display_name, int(round(ManifestationRunner.DUPLICATE_FALLOFF * 100.0)),
			])
			break

	var next := _next_pair(after_counts)
	if not next.is_empty():
		lines.append("[color=%s]%s[/color]" % [QUIET_HEX, next])


## The noun-wide effect any rule of that noun brings (ManifestationState), or
## "" for a noun whose resource only its rules can fill.
static func _noun_passive(noun: StringName) -> String:
	match noun:
		&"ward":
			return "Composure: after %.0fs unhurt, the next hit that lands is %d%% lighter (every WARD rule)" % [
				ManifestationState.COMPOSURE_SECONDS, int(round(ManifestationState.COMPOSURE_REDUCTION * 100.0)),
			]
		&"momentum":
			return "Momentum fills from %.0f m of unbroken travel (every MOMENTUM rule)" % (ManifestationState.MOMENTUM_BASE_FILL_DISTANCE / PIXELS_PER_METRE)
	return ""


## The pair one noun away, the Run Sheet's way: a lit noun and the unlit
## partner closest to lighting.
static func _next_pair(counts: Dictionary) -> String:
	var threshold := ManifestationPairCatalog.NOUN_THRESHOLD
	var best: ManifestationPairDef = null
	var best_noun: StringName = &""
	var best_count := -1
	for lit in ManifestationNouns.ORDER:
		if int(counts.get(lit, 0)) < threshold:
			continue
		for other in ManifestationNouns.ORDER:
			var n := int(counts.get(other, 0))
			if other == lit or n >= threshold or n <= best_count:
				continue
			var def := ManifestationPairCatalog.for_nouns(lit, other)
			if def == null:
				continue
			best = def
			best_noun = other
			best_count = n
	if best == null:
		return ""
	var missing := threshold - best_count
	return "Next pair: %s, with %s more %s rule%s." % [best.display_name.to_upper(), "one" if missing == 1 else str(missing), ManifestationNouns.label(best_noun), "" if missing == 1 else "s"]


## The held dossier's view of the wardrobe: the worn rules each noun joins,
## a duplicate warning, and what putting it onto each fitting item would do.
static func _append_gear_fit(lines: Array[String], def: ManifestationDef, fitting: Array[Dictionary]) -> void:
	var worn := _worn_items()
	var counts := _noun_counts(worn)
	lines.append("")
	lines.append(_head("WITH WHAT YOU WEAR"))
	for tag in def.tags:
		var mates := PackedStringArray()
		var seen: Dictionary = {}
		for value in worn:
			var inst := value as ItemInstance
			if inst == null or not inst.has_manifestation() or inst.manifestation_id == def.id or seen.has(inst.manifestation_id):
				continue
			if ManifestationCatalog.tags_of(inst.manifestation_id).has(tag):
				seen[inst.manifestation_id] = true
				mates.append(ManifestationCatalog.display_name(inst.manifestation_id))
		var noun := "[color=%s]%s[/color]" % [ManifestationNouns.hex(tag), ManifestationNouns.label(tag)]
		if mates.is_empty():
			lines.append("%s  [color=%s]no worn rule speaks it yet[/color]" % [noun, QUIET_HEX])
		else:
			lines.append("%s  %d worn: %s" % [noun, int(counts.get(tag, 0)), ", ".join(mates)])
	for slot in range(worn.size()):
		var other := worn[slot] as ItemInstance
		if other != null and other.manifestation_id == def.id:
			lines.append("[color=%s]Already worn on %s: a second copy lights no extra noun, and its multipliers count at %d%%.[/color]" % [
				NEG_HEX, other.data.display_name, int(round(ManifestationRunner.DUPLICATE_FALLOFF * 100.0)),
			])
			break
	var shown := 0
	for candidate in fitting:
		if shown >= LIST_LIMIT - 1:
			break
		var inst: ItemInstance = candidate["inst"]
		if inst.manifestation_id == def.id:
			continue
		var slot := int(inst.data.equip_slot)
		var after := worn.duplicate()
		after[slot] = _carrying(inst, def.id)
		var where := "On %s" % inst.data.display_name if String(candidate["where"]) == "worn" else "On %s, once equipped" % inst.data.display_name
		lines.append("%s: %s" % [where, _outcome(worn, after)])
		shown += 1


## One line for what a change of worn rules does: nouns lit or unlit and pairs
## gained or lost.
static func _outcome(before: Array, after: Array) -> String:
	var before_counts := _noun_counts(before)
	var after_counts := _noun_counts(after)
	var threshold := ManifestationPairCatalog.NOUN_THRESHOLD
	var parts := PackedStringArray()
	for noun in ManifestationNouns.ORDER:
		var was := int(before_counts.get(noun, 0))
		var now := int(after_counts.get(noun, 0))
		var label := "[color=%s]%s[/color]" % [ManifestationNouns.hex(noun), ManifestationNouns.label(noun)]
		if now >= threshold and was < threshold:
			parts.append("lights %s" % label)
		elif was >= threshold and now < threshold:
			parts.append("[color=%s]unlights[/color] %s" % [NEG_HEX, label])
	var before_pairs := _pair_ids(before_counts)
	var after_pairs := _pair_ids(after_counts)
	for id in after_pairs:
		if not before_pairs.has(id):
			parts.append("[color=%s]%s comes online[/color]" % [POS_HEX, ManifestationPairCatalog.get_def(id).display_name.to_upper()])
	for id in before_pairs:
		if not after_pairs.has(id):
			parts.append("[color=%s]%s goes dark[/color]" % [NEG_HEX, ManifestationPairCatalog.get_def(id).display_name.to_upper()])
	if parts.is_empty():
		return "[color=%s]no noun lights or pair changes[/color]" % QUIET_HEX
	return "; ".join(parts)


# ------------------------------------------------------------------ text

static func _head(text: String) -> String:
	return "[color=%s][b]%s[/b][/color]" % [HEAD_HEX, text]


static func _rule_hex(rule_id: StringName) -> String:
	var noun := ManifestationNouns.primary_of(rule_id)
	return ManifestationNouns.hex(noun) if noun != &"" else ManifestationNouns.LAYER_HEX


## The nouns in their own colours: the colour is the vocabulary that says
## which rules combine.
static func _noun_line(tags: Array) -> String:
	var names := PackedStringArray()
	for tag in tags:
		names.append("[color=%s]%s[/color]" % [ManifestationNouns.hex(tag), ManifestationNouns.label(tag)])
	return ("[color=%s] · [/color]" % NEUTRAL_HEX).join(names)


static func _slot_label(slot: int) -> String:
	if slot >= 0 and slot < Inventory.SLOT_COUNT:
		return Inventory.slot_label(slot)
	return "Equipment"


static func _slot_names(slots: Array) -> String:
	var names := PackedStringArray()
	for slot in slots:
		names.append(_slot_label(int(slot)))
	return ", ".join(names)


static func _item_ref(candidate: Dictionary) -> String:
	var inst: ItemInstance = candidate["inst"]
	return "%s · R%d · %s" % [inst.data.display_name, int(inst.rarity), "worn" if String(candidate["where"]) == "worn" else "in the bag"]
