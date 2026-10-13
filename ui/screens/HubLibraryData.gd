extends RefCounted
## Read-only reference entries built from the same definitions as the game.
## Detached item/effect previews avoid inventory, discovery and RNG changes.

const CATEGORIES: Array[String] = ["Manifestations", "Pairs", "Enemies", "Items", "Augments", "Sets"]
const STAT_LABELS := {
	"max_hp": "Health", "armor": "Armor", "move_speed": "Move Speed",
	"power": "Power", "haste": "Haste", "luck": "Luck",
}


static func build_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for id: StringName in ManifestationCatalog.all_ids():
		var def := ManifestationCatalog.get_def(id)
		var slots := PackedStringArray()
		for slot: int in def.slots:
			slots.append(Inventory.slot_label(slot))
		var body := "[b]The rule[/b]\n%s\n\n[b]Goes on[/b]\n%s\n\n[b]Shared nouns[/b]\n%s\n\nNumbers shown at rank 0; item rank strengthens the rule." % [ManifestationCatalog.describe(id, null), ", ".join(slots), _nouns(def.tags)]
		entries.append(_entry("Manifestations", String(id), def.display_name, _nouns(def.tags), body))
	for id: StringName in ManifestationPairCatalog.all_ids():
		var pair := ManifestationPairCatalog.get_def(id)
		var body := "[b]The payoff[/b]\n%s\n\n[b]Activation[/b]\nWear two distinct rules of each noun: %s. A rule with both nouns counts toward both.\n\nPairs arise from equipped rules; they are never item drops. Numbers shown at mean rank 0." % [ManifestationPairCatalog.describe(id), _nouns(pair.nouns)]
		entries.append(_entry("Pairs", String(id), pair.display_name, _nouns(pair.nouns), body))
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
				body += "\n\n[b]Set[/b]\n" + (set_data.display_name if set_data != null else data.set_id)
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
			entries.append(_entry("Items", data.id, data.display_name, slot, body, data.icon))
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
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["category"] != b["category"]:
			return CATEGORIES.find(a["category"]) < CATEGORIES.find(b["category"])
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


static func _entry(category: String, id: String, title: String, subtitle: String, body: String, icon: Texture2D = null) -> Dictionary:
	return {
		"category": category, "id": id, "title": title, "subtitle": subtitle,
		"body": body.strip_edges(), "icon": icon,
		"search": (category + " " + id + " " + title + " " + subtitle + " " + body).to_lower(),
	}


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
