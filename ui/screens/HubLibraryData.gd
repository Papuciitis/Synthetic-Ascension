extends RefCounted
## Read-only reference entries built from the same definitions as the game.
## Detached item/effect previews avoid inventory, discovery and RNG changes.

const GUIDES := preload("res://ui/screens/HubLibraryGuides.gd")
const SECTIONS := preload("res://ui/widgets/library/LibrarySections.gd")
const CATEGORIES: Array[String] = ["Buildcraft", "Manifestations", "Pairs", "Enemies", "Items", "Augments", "Sets", "Recipes", "Chronicles"]
const PREFIXES := {"Buildcraft": "guide", "Manifestations": "manifestation", "Pairs": "pair", "Enemies": "enemy", "Items": "item", "Augments": "augment", "Sets": "set"}
const CLUES := {
	"Enemies": "Encounter this opponent in the field to record its behaviour.",
	"Augments": "Acquire this augment to study its base effects and growth.",
	"Sets": "Acquire a member of this equipment set to study its shared identity.",
}
const STAT_LABELS := {
	"max_hp": "Health", "armor": "Armor", "move_speed": "Move Speed",
	"power": "Power", "haste": "Haste", "luck": "Luck",
}


static func build_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for guide: Dictionary in GUIDES.pages():
		entries.append(_entry("Buildcraft", guide["id"], guide["title"], guide["subtitle"], guide["body"]))
	for id: StringName in ManifestationCatalog.all_ids():
		var def := ManifestationCatalog.get_def(id)
		var slots := PackedStringArray()
		for slot: int in def.slots:
			slots.append(Inventory.slot_label(slot))
		var body := "[b]The rule[/b]\n%s\n\n[b]Goes on[/b]\n%s\n\n[b]Shared nouns[/b]\n%s\n\nNumbers shown at rank 0; item rank strengthens the rule." % [ManifestationCatalog.describe(id, null), ", ".join(slots), _nouns(def.tags)]
		var hint := "Find a rule for these slots: %s. Shared nouns: %s. Acquire the equipment or preserve its imprint to record the rule." % [", ".join(slots), _nouns(def.tags)]
		entries.append(_entry("Manifestations", String(id), def.display_name, _nouns(def.tags), body, null, "", hint))
	for id: StringName in ManifestationPairCatalog.all_ids():
		var pair := ManifestationPairCatalog.get_def(id)
		var body := "[b]The payoff[/b]\n%s\n\n[b]Activation[/b]\nWear %d distinct rules of each noun: %s. A rule with both nouns counts toward both.\n\nPairs arise from equipped rules; they are never item drops. Numbers shown at mean rank 0." % [ManifestationPairCatalog.describe(id), ManifestationPairCatalog.NOUN_THRESHOLD, _nouns(pair.nouns)]
		var hint := "Light both %s with %d distinct rules of each. Duplicate copies do not add to the count." % [_nouns(pair.nouns).replace(" + ", " and "), ManifestationPairCatalog.NOUN_THRESHOLD]
		entries.append(_entry("Pairs", String(id), pair.display_name, _nouns(pair.nouns), body, null, "", hint))
	# ResourceLoader preserves original resource names in exported builds too.
	var enemy_files := ResourceLoader.list_directory("res://core/actors/enemy")
	enemy_files.sort()
	for file: String in enemy_files:
		if not file.begins_with("EnemySpec_") or not file.ends_with(".tres"):
			continue
		var spec := load("res://core/actors/enemy/" + file) as EnemySpec
		if spec == null:
			continue
		var dossier := EnemyDossierCatalog.get_entry(spec.id)
		var body := "%s\n\n[b]Base stats[/b]\nHealth: %s\nMove Speed: %s\n\nStats can change with difficulty and elite modifiers." % [EnemyDossierCatalog.ratings(spec), String.num(spec.max_hp, 1), String.num(spec.speed, 1)]
		for section: Array in [["behaviour", "Behaviour"], ["expect", "What to expect"], ["counter", "How to respond"]]:
			var text := String(dossier.get(section[0], ""))
			if not text.is_empty():
				body += "\n\n[b]%s[/b]\n%s" % [section[1], text]
		entries.append(_entry("Enemies", String(spec.id), String(dossier.get("name", spec.display_name)), String(dossier.get("role", "Enemy")), body, spec.portrait_texture()))
	if Global != null:
		for data: ItemData in Global.item_db.values():
			if data == null or not data.runtime_enabled:
				continue
			var slot := Inventory.slot_label(int(data.equip_slot)) if int(data.equip_slot) >= 0 else "Bag item"
			var body := data.description
			if not data.set_id.is_empty():
				var set_data := Global.set_db.get(StringName(data.set_id), null) as SetData
				var set_known := set_data != null and Global.library_has("set:" + data.set_id)
				if set_data != null and not set_known:
					# Authored item descriptions also carry a named set-piece line.
					body = body.replacen(set_data.display_name, "Undiscovered")
				body += "\n\n[b]Set[/b]\n" + (set_data.display_name if set_known else "An undiscovered set. Acquire a member to record its identity.")
			# Never use from_data(): it rolls an imprint and consumes live RNG.
			var sample := ItemInstance.new()
			sample.data = data
			sample.rarity = 0
			sample.rolled_mods = ItemScaling.flat_mods(sample)
			body += "\n\n[b]Base stats · rank 0, positive polarity[/b]\n" + _stats(sample.rolled_mods)
			for polarity: int in [ItemInstance.Polarity.POS, ItemInstance.Polarity.NEG]:
				sample.polarity = polarity
				sample.rolled_mods = ItemScaling.flat_mods(sample)
				var effects := data.get_effects_short(sample)
				if not effects.is_empty():
					body += "\n\n[b]%s effects · rank 0[/b]\n%s" % ["Positive" if polarity > 0 else "Negative", "\n".join(effects)]
			body += "\n\nRolled polarity, rank and Manifestations can change an individual item's effects."
			var hint := "Find equipment for the %s slot; acquire it to record its identity and properties." % slot if int(data.equip_slot) >= 0 else "Acquire this bag item to record its identity and properties."
			entries.append(_entry("Items", data.id, data.display_name, slot, body, data.icon, "", hint))
		for data: AugmentData in Global.augment_db.values():
			if data == null:
				continue
			var body := data.description
			if not data.details.is_empty():
				body += "\n\n" + data.details
			body += "\n\n[b]Base stat changes · level 1[/b]\n" + _stats(data.mods)
			entries.append(_entry("Augments", String(data.id), data.display_name, data.card_blurb, body, data.icon))
		for data: SetData in Global.set_db.values():
			if data == null:
				continue
			var body := data.identity_sentence
			for section: Array in [["Playstyle", data.playstyle], ["Best with", data.best_with], ["Active ability", data.active_ability_name], ["Requirements", data.active_ability_requirements]]:
				if not String(section[1]).is_empty():
					body += "\n\n[b]%s[/b]\n%s" % section
			for tier: SetTier in data.sorted_tiers():
				if tier == null:
					continue
				body += "\n\n[b]%d pieces · %s[/b]\n%s" % [tier.required_count, tier.display_name, tier.mechanical_description if not tier.mechanical_description.is_empty() else tier.plain_description]
			entries.append(_entry("Sets", String(data.id), data.display_name, data.identity_sentence, body))
	for row: Dictionary in Grimoire.catalogue(Global.augment_db):
		var category := "Chronicles" if row["section"] == "RECORDS" else "Recipes"
		var key := String(row["key"])
		var body := String(row["rule"])
		if category == "Recipes":
			body = "[b]Base requirements[/b]\n%s\n\n[b]Payoff[/b]\n%s" % [row["hint"], row["rule"]]
		entries.append(_entry(category, key, row["name"], String(row["section"]).capitalize(), body, AugmentArt.grimoire_texture(key, Global.augment_db), key, row["hint"]))
	# Sanitize before sorting, filtering or handing any dictionaries to the UI.
	# Ordinals follow catalog order, never the unrevealed display names.
	var ordinals := {}
	for entry: Dictionary in entries:
		var category := String(entry["category"])
		ordinals[category] = int(ordinals.get(category, 0)) + 1
		_present(entry, int(ordinals[category]))
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["category"] != b["category"]:
			return CATEGORIES.find(a["category"]) < CATEGORIES.find(b["category"])
		if a["category"] == "Buildcraft":
			return int(a["folio"]) < int(b["folio"])
		# The book and its edge tabs share the same contiguous chapters.
		# Folios were assigned before this sort and remain stable on discovery.
		var a_section: Dictionary = a["ribbon"]
		var b_section: Dictionary = b["ribbon"]
		if int(a_section["order"]) != int(b_section["order"]):
			return int(a_section["order"]) < int(b_section["order"])
		if a_section["id"] != b_section["id"]:
			return String(a_section["label"]).naturalnocasecmp_to(String(b_section["label"])) < 0
		if a["discovered"] != b["discovered"]:
			return bool(a["discovered"])
		return String(a["title"]).naturalnocasecmp_to(String(b["title"])) < 0)
	return entries


static func filter_entries(entries: Array[Dictionary], category: String, query: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var terms := query.strip_edges().to_lower().split(" ", false)
	for entry: Dictionary in entries:
		if category != "All" and entry["category"] != category:
			continue
		var matches := true
		for term: String in terms:
			if not String(entry["search"]).contains(term):
				matches = false
				break
		if matches:
			found.append(entry)
	return found


## Live planning stays separate from searchable reference text. Counting mirrors
## ManifestationRunner.get_noun_counts(): one contribution per distinct worn rule.
## No effect nodes are created, so a completed loadout cannot award discovery.
static func research_notes(entry: Dictionary) -> String:
	if String(entry.get("category", "")) != "Pairs":
		return ""
	var pair := ManifestationPairCatalog.get_def(StringName(entry.get("id", "")))
	if pair == null:
		return ""
	var counts := _equipped_noun_counts()
	var lines := PackedStringArray(["[b]Your current equipment[/b]"])
	for noun: StringName in pair.nouns:
		lines.append("%s: %d/%d distinct rules" % [ManifestationNouns.label(noun).capitalize(), int(counts.get(noun, 0)), ManifestationPairCatalog.NOUN_THRESHOLD])
	lines.append("Duplicates, bag items and spare imprints do not add to these counts.")
	var known_worn := PackedStringArray()
	var seen := {}
	if Global.run_inventory != null:
		for slot: int in range(mini(Inventory.SLOT_COUNT, Global.run_inventory.items.size())):
			var inst: ItemInstance = Global.run_inventory.items[slot]
			if inst == null or inst.data == null or seen.has(inst.manifestation_id):
				continue
			seen[inst.manifestation_id] = true
			var rule := ManifestationCatalog.get_def(inst.manifestation_id)
			if rule != null and rule.logic != null and _shares_noun(rule.tags, pair.nouns) and Global.library_has("manifestation:" + String(rule.id)):
				known_worn.append(rule.display_name)
	if not known_worn.is_empty():
		lines.append("\n[b]Known rules you wear[/b]\n" + " · ".join(known_worn))
	var missing := _missing_pair_rules(counts, pair.nouns)
	if missing == 0:
		lines.append("\nBoth nouns meet the equipment threshold. The pair is recorded when it becomes active in play.")
		return "\n".join(lines)
	var suggestions := PackedStringArray()
	seen.clear()
	for id: StringName in Global.attempt_imprints:
		if seen.has(id) or not Global.library_has("manifestation:" + String(id)):
			continue
		seen[id] = true
		var rule := ManifestationCatalog.get_def(id)
		if rule == null or rule.logic == null or not _shares_noun(rule.tags, pair.nouns) or Global.run_inventory == null:
			continue
		var slots := PackedStringArray()
		for slot: int in rule.slots:
			if slot < 0 or slot >= mini(Inventory.SLOT_COUNT, Global.run_inventory.items.size()):
				continue
			var inst: ItemInstance = Global.run_inventory.items[slot]
			if inst == null or inst.data == null or inst.locked or int(inst.data.equip_slot) != slot:
				continue
			var after := _equipped_noun_counts(slot, id)
			if _missing_pair_rules(after, pair.nouns) < missing:
				slots.append(Inventory.slot_label(slot))
		if not slots.is_empty():
			suggestions.append("%s → %s" % [rule.display_name, " / ".join(slots)])
	if not suggestions.is_empty():
		lines.append("\n[b]Spare imprints to try[/b]\n" + "\n".join(suggestions))
		lines.append("These replacements advance this pair's counts. Check the price and other build effects at the Imprinter.")
	return "\n".join(lines)


static func _equipped_noun_counts(replaced_slot: int = -1, replacement: StringName = &"") -> Dictionary:
	var counts := {}
	var seen := {}
	if Global.run_inventory == null:
		return counts
	for slot: int in range(mini(Inventory.SLOT_COUNT, Global.run_inventory.items.size())):
		var inst: ItemInstance = Global.run_inventory.items[slot]
		if inst == null or inst.data == null:
			continue
		var id := replacement if slot == replaced_slot else inst.manifestation_id
		if seen.has(id):
			continue
		var rule := ManifestationCatalog.get_def(id)
		if rule == null or rule.logic == null:
			continue
		seen[id] = true
		for noun: StringName in rule.tags:
			counts[noun] = int(counts.get(noun, 0)) + 1
	return counts


static func _shares_noun(tags: Array[StringName], nouns: Array[StringName]) -> bool:
	for noun: StringName in nouns:
		if tags.has(noun):
			return true
	return false


static func _missing_pair_rules(counts: Dictionary, nouns: Array[StringName]) -> int:
	var missing := 0
	for noun: StringName in nouns:
		missing += maxi(0, ManifestationPairCatalog.NOUN_THRESHOLD - int(counts.get(noun, 0)))
	return missing


static func _entry(category: String, id: String, title: String, subtitle: String, body: String, icon: Texture2D = null, key: String = "", hint: String = "") -> Dictionary:
	return {
		"category": category, "id": id, "title": title, "subtitle": subtitle,
		"body": body.strip_edges(), "icon": icon,
		"key": key if not key.is_empty() else String(PREFIXES[category]) + ":" + id,
		"hint": hint if not hint.is_empty() else String(CLUES.get(category, "")),
	}


static func _present(entry: Dictionary, ordinal: int) -> void:
	entry["folio"] = ordinal
	var key := String(entry["key"])
	var discovered: bool = entry["category"] == "Buildcraft" or Global.library_has(key)
	entry["discovered"] = discovered
	entry["unread"] = discovered and not Global.library_read_entries.has(key)
	entry["trackable"] = entry["category"] != "Buildcraft"
	if not discovered:
		entry["title"] = "Undiscovered page · %02d" % ordinal
		entry["subtitle"] = entry["hint"]
		entry["body"] = entry["hint"]
		entry["icon"] = null
		entry["search"] = (String(entry["category"]) + " " + String(entry["title"]) + " " + String(entry["hint"])).to_lower()
	else:
		entry["search"] = (String(entry["category"]) + " " + String(entry["title"]) + " " + String(entry["subtitle"]) + " " + String(entry["body"])).to_lower()
	# Classify only after discovery sanitization. This helper permits public
	# slot/noun/recipe clues while withholding hidden set and curse identities.
	var ribbon := SECTIONS.describe(entry)
	entry["ribbon"] = ribbon
	entry["search"] += " " + String(ribbon["label"]).to_lower()
	for mark: Dictionary in ribbon["marks"]:
		entry["search"] += " " + String(mark["label"]).to_lower()


static func _nouns(nouns: Array[StringName]) -> String:
	var labels := PackedStringArray()
	for noun: StringName in nouns:
		labels.append(ManifestationNouns.label(noun).capitalize())
	return " + ".join(labels)


static func _stats(mods: StatDelta) -> String:
	var lines := PackedStringArray()
	if mods != null:
		for property: String in STAT_LABELS:
			var value := float(mods.get(property))
			if not is_zero_approx(value):
				var percent := property in ["power", "haste", "luck"]
				var displayed := value * 100.0 if percent else value
				var number := str(roundi(displayed)) if is_equal_approx(displayed, roundf(displayed)) else String.num(displayed, 2)
				number += "%" if percent else ""
				lines.append("%s: %s%s" % [STAT_LABELS[property], "+" if value > 0.0 else "", number])
	return "\n".join(lines) if not lines.is_empty() else "No flat stat changes."
