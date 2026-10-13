extends RefCounted
## General instructions use live thresholds and no undiscovered item names.


static func pages() -> Array[Dictionary]:
	var noun_threshold := ManifestationPairCatalog.NOUN_THRESHOLD
	var growth := roundi(AugmentScaling.POTENCY_PER_LEVEL * 100.0)
	var guides: Array[Dictionary] = [
		{
			"id": "equipment_identity", "title": "Equipment, sets and rules",
			"subtitle": "Three ways to recognise a build",
			"body": "[b]Equipment identity[/b]\nAn item supplies its slot, base stats and polarity effects. Rank and polarity change the copy you carry.\n\n[b]Set identity[/b]\nA set counts equipped members of the same set. Its tiers reward the required piece counts shown on its page; their strength can grow with the set's mean rank.\n\n[b]Manifestation identity[/b]\nA Manifestation is the rule carried by an individual item. Its shared nouns describe how it connects to other rules. An item's set and its Manifestation are separate identities: choose equipment for the stats and set you need, then choose rules for their interactions.\n\nAcquire equipment to reveal its library page. A discovered member also reveals its set; reading never grants equipment or activates a bonus."
		},
		{
			"id": "nouns_and_pairs", "title": "Shared nouns and pairs",
			"subtitle": "Count distinct rules, then connect nouns",
			"body": "[b]Light a noun[/b]\nEquip %d distinct Manifestation rules carrying a noun to light it. Duplicate copies of the same rule do not increase this count. A rule carrying two nouns counts toward both.\n\n[b]Light a pair[/b]\nWhen two nouns are each lit, their pair becomes active. Pair payoffs come from equipped rules; pairs are never item drops.\n\n[b]Plan the equipment[/b]\nCheck the allowed slots on a discovered rule's page. Assemble distinct rules that fit the slots you can wear, then inspect the active pair in play. Rank strengthens individual rules; it does not replace the distinct-rule requirement." % noun_threshold
		},
		{
			"id": "merges_and_imprints", "title": "Merges and spare imprints",
			"subtitle": "Choose which rule the surviving item keeps",
			"body": "[b]Merge deliberately[/b]\nUnlocked copies of the same item and polarity can merge. The destination keeps its Manifestation even when the incoming copy has a higher rank. A destination with no rule adopts the incoming rule. If both carry different rules, the incoming rule becomes a spare imprint.\n\n[b]Keep options for the Hub[/b]\nThe imprint pouch holds up to %d distinct rules; duplicates do not add another copy and the oldest is forgotten when it exceeds the limit. At the Hub's imprinter, a held rule can be placed on compatible worn or bagged equipment for Followers. Locked equipment cannot be imprinted.\n\n[b]Change a rule[/b]\nImprinting consumes the held imprint. The replaced rule returns to the pouch, subject to its limit. Read the compatibility and price before applying; between Hubs, the rule you wear is the one you committed to." % Global.IMPRINT_CAP
		},
		{
			"id": "augment_growth", "title": "Augment growth and combinations",
			"subtitle": "Levels, Facets, Duos and Transcendence",
			"body": "[b]Levels[/b]\nAugment levels run from 1 to %d. Payload potency gains %d%% of its level-1 value per level above 1; count-type growth uses at most %d steps. Other effects follow the augment's own scaling.\n\n[b]Facets[/b]\nA compatible augment can be offered a choice of Facet from level %d. This attempt currently requires level %d. A Facet chooses a branch of that augment's effect.\n\n[b]Duos[/b]\nA Duo can be offered when both member augments are equipped at level %d or above. This attempt currently requires level %d. Its rule acts only while both members remain equipped.\n\n[b]Transcendence[/b]\nThe base offer threshold is level %d plus a qualifying catalyst; this attempt currently requires level %d. A catalyst may be another equipped augment, a stat threshold or another build condition. Recipes preserve the game's ingredient clues and reveal each payoff once reached.\n\nA recipe clue can be saved as a research target. It does not satisfy ingredients or grant its result." % [AugmentScaling.MAX_LEVEL, growth, AugmentScaling.COUNT_STEP_CAP, AugmentFacets.LEVEL_REQUIRED, Global.facet_level_required(), AugmentDuos.LEVEL_REQUIRED, Global.duo_level_required(), AugmentScaling.TRANSCEND_LEVEL, Global.augment_transcend_level()]
		},
		{
			"id": "doctrine_families", "title": "Doctrine families and commitments",
			"subtitle": "Circuit, Vessel and Archive",
			"body": _doctrine_body()
		},
	]
	var subjects := {
		"equipment_identity": ["Items", "Sets", "Manifestations"],
		"nouns_and_pairs": ["Manifestations", "Pairs"],
		"merges_and_imprints": ["Items", "Manifestations"],
		"augment_growth": ["Augments", "Recipes"],
		"doctrine_families": ["Recipes"],
	}
	for guide: Dictionary in guides:
		var links := PackedStringArray()
		for subject: String in subjects[guide["id"]]:
			links.append("[url=book:%s]%s[/url]" % [subject, subject])
		guide["body"] += "\n\n[b]Continue reading[/b]\n" + " · ".join(links)
	return guides


static func _doctrine_body() -> String:
	var body := "[b]Choose a direction[/b]\nMethod, Doctrine and Apotheosis plates each belong to a family. Circuit develops augment output and Bindings; Vessel develops Power and the body's prices; Archive develops Binding quality and choices. Each plate has its own gift, price and consequence: inspect all three before inscribing.\n\n[b]Build within a family[/b]\n%d held plates of one family inscribe its Thesis; %d inscribe its Canon. These count the plates held this attempt. Mixing families keeps their individual gifts, but may delay a family threshold." % [DoctrineFamilies.THESIS_AT, DoctrineFamilies.CANON_AT]
	for family: StringName in [&"circuit", &"vessel", &"archive"]:
		body += "\n\n[b]%s direction[/b]\n" % String(family).capitalize()
		for kind: String in ["thesis", "canon"]:
			var key := kind + ":" + String(family)
			if Global.library_has(key):
				var rules: Dictionary = DoctrineFamilies.THESIS if kind == "thesis" else DoctrineFamilies.CANON
				body += "%s: %s.\n" % [kind.capitalize(), String(rules[family])]
			else:
				body += "%s payoff is recorded in Recipes after you reach it.\n" % kind.capitalize()
	return body.strip_edges()
