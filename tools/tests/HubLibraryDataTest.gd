extends Node

const LIBRARY := preload("res://ui/screens/HubLibraryData.gd")
var _reference: RefCounted = LIBRARY.new()
var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error("HubLibraryDataTest: " + message)


func _find(entries: Array[Dictionary], key: String) -> Dictionary:
	for entry: Dictionary in entries:
		if String(entry.get("key", "")) == key:
			return entry
	return {}


func _test_planning_clues(entries: Array[Dictionary]) -> void:
	var pair := _find(entries, "pair:red_line")
	_check(String(pair["hint"]).contains("Momentum") and String(pair["hint"]).contains("Ward"), "unknown pair clue identifies both nouns to build toward")
	_check(String(pair["hint"]).contains("%d distinct rules of each" % ManifestationPairCatalog.NOUN_THRESHOLD), "unknown pair clue explains the live distinct-rule threshold")
	_check(LIBRARY.filter_entries([pair], "Pairs", "momentum ward").size() == 1, "pair clue supports research by both shared nouns")
	_check(LIBRARY.filter_entries([pair], "Pairs", "Red Line").is_empty() and not String(pair["search"]).contains("ignored hit"), "planning a hidden pair does not reveal its name or payoff")
	var rule := _find(entries, "manifestation:pilgrims_momentum")
	_check(String(rule["hint"]).contains("Movement") and String(rule["hint"]).contains("Ring"), "unknown rule clue identifies its compatible equipment slots")
	_check(String(rule["hint"]).contains("Momentum") and String(rule["hint"]).contains("Cadence"), "unknown rule clue identifies its shared nouns")
	_check(LIBRARY.filter_entries([rule], "Manifestations", "ring cadence").size() == 1, "compatible-slot and noun clues are searchable together")
	_check(LIBRARY.filter_entries([rule], "Manifestations", "Pilgrim's Momentum").is_empty() and not String(rule["search"]).contains("fires twice"), "planning a hidden rule does not reveal its name or effect")
	var item := _find(entries, "item:beka")
	_check(String(item["hint"]).contains("Offhand"), "unknown equipment clue identifies its slot")
	_check(LIBRARY.filter_entries([item], "Items", "offhand").size() == 1 and LIBRARY.filter_entries([item], "Items", "beka").is_empty(), "equipment clue helps plan a slot without revealing the item name")


func _test_teaching_order_and_folios(entries: Array[Dictionary]) -> void:
	var guides := LIBRARY.filter_entries(entries, "Buildcraft", "")
	var ids: Array[String] = []
	for guide: Dictionary in guides:
		ids.append(String(guide["id"]))
	_check(ids == ["equipment_identity", "nouns_and_pairs", "merges_and_imprints", "augment_growth", "doctrine_families"], "Buildcraft teaches equipment before advanced combinations in authored order")
	var sealed := _find(entries, "item:beka")
	_check(int(sealed.get("folio", 0)) > 0, "a sealed page has a stable physical folio")
	Global.library_discoveries.append("item:beka")
	var discovered := _find(LIBRARY.build_entries(), "item:beka")
	Global.library_read_entries.append("item:beka")
	var read_page := _find(LIBRARY.build_entries(), "item:beka")
	_check(int(sealed.get("folio", 0)) > 0 and sealed.get("folio") == discovered.get("folio") and discovered.get("folio") == read_page.get("folio"), "discovery and read marks keep the same folio while changing page presentation")
	Global.library_discoveries.erase("item:beka")
	Global.library_read_entries.erase("item:beka")


func _research_item(slot: int, rule: StringName) -> ItemInstance:
	var data := ItemData.new()
	data.id = "research_fixture_%d" % slot
	data.equip_slot = slot as ItemData.EquipSlot
	var inst := ItemInstance.new()
	inst.data = data
	inst.manifestation_id = rule
	return inst


func _test_pair_research(entries: Array[Dictionary]) -> void:
	_check(_reference.has_method("research_notes"), "pair clues can report current equipment progress")
	if not _reference.has_method("research_notes"):
		return
	var saved_inventory := Global.run_inventory
	var saved_bag := Global.run_bag
	var saved_stash := Global.meta_stash
	var saved_imprints := Global.attempt_imprints.duplicate()
	var saved_knowledge := Global.library_discoveries.duplicate()
	Global.run_inventory = Inventory.new()
	Global.run_bag = BagInventory.new()
	Global.meta_stash = StashInventory.new()
	Global.run_inventory.items[2] = _research_item(2, &"pilgrims_momentum")
	Global.run_inventory.items[7] = _research_item(7, &"pilgrims_momentum")
	Global.run_inventory.items[1] = _research_item(1, &"martyr_circuit")
	Global.run_bag.slots[0] = _research_item(0, &"impact_scripture")
	Global.meta_stash.slots[0] = _research_item(1, &"retaliation_writ")
	Global.attempt_imprints.assign([&"anchor_rite", &"scar_tissue", &"third_litany", &"retaliation_writ"])
	Global.library_discoveries.assign(["manifestation:pilgrims_momentum", "manifestation:martyr_circuit", "manifestation:anchor_rite", "manifestation:scar_tissue", "manifestation:third_litany"])
	var pair := _find(entries, "pair:red_line")
	var inventory_before := Global.run_inventory.items.duplicate()
	var bag_before := Global.run_bag.slots.duplicate()
	var stash_before := Global.meta_stash.slots.duplicate()
	var imprints_before := Global.attempt_imprints.duplicate()
	var knowledge_before := Global.library_discoveries.duplicate()
	var grimoire_before := Global.grimoire_entries.duplicate()
	var read_before := Global.library_read_entries.duplicate()
	var rng_before := Global._rng.state
	var writes_before := SaveManager.debug_save_writes
	var followers_before := Global.followers
	var notes := String(_reference.call("research_notes", pair))
	_check(notes.contains("Momentum: 1/2") and notes.contains("Ward: 1/2"), "duplicates, bag items, stash items and spare imprints do not inflate worn noun progress")
	_check(notes.contains("Pilgrim's Momentum") and notes.contains("Martyr Circuit"), "the progress note identifies known worn contributing rules")
	_check(notes.contains("Anchor Rite") and notes.contains("Scar Tissue") and notes.contains("Ring"), "known spare imprints offer compatible worn slots that improve distinct-rule progress")
	_check(not notes.contains("Impact Scripture") and not notes.contains("Retaliation Writ") and not notes.contains("Third Litany"), "planning excludes bag and stash names, unknown imprints and unrelated nouns")
	_check(not notes.contains("Red Line") and not notes.contains("ignored hit"), "research progress does not expose the sealed pair's name or payoff")
	_check(not String(pair["search"]).contains("pilgrim"), "current equipment notes stay outside the sealed-page search contract")
	Global.run_inventory.items[7].locked = true
	Global.run_inventory.items[2].locked = true
	var locked_notes := String(_reference.call("research_notes", pair))
	_check(not locked_notes.contains("Anchor Rite") and not locked_notes.contains("Scar Tissue"), "spare suggestions omit locked items and replacements that cannot advance the pair")
	Global.run_inventory.items[7].locked = false
	Global.run_inventory.items[2].locked = false
	Global.run_inventory.items[0] = _research_item(0, &"impact_scripture")
	Global.library_discoveries.append("manifestation:impact_scripture")
	var complete := String(_reference.call("research_notes", pair))
	_check(complete.contains("Momentum: 2/2") and complete.contains("Ward: 2/2"), "one distinct dual-noun rule advances both hinted nouns to the live threshold")
	_check(not Global.library_has("pair:red_line"), "planning a complete loadout does not record a pair or instantiate its runner")
	Global.run_inventory.items[0] = null
	Global.library_discoveries.erase("manifestation:impact_scripture")
	Global.library_discoveries.erase("manifestation:martyr_circuit")
	var hidden_contributor := String(_reference.call("research_notes", pair))
	_check(hidden_contributor.contains("Ward: 1/2") and not hidden_contributor.contains("Martyr Circuit"), "unknown worn rules can count without revealing their identity")
	Global.library_discoveries.insert(1, "manifestation:martyr_circuit")
	_check(String(_reference.call("research_notes", _find(entries, "item:beka"))).is_empty(), "ordinary pages do not invent a research checklist")
	_check(String(_reference.call("research_notes", {"category": "Pairs", "id": "removed_pair"})).is_empty(), "removed pairs have no speculative progress")
	_check(Global.run_inventory.items == inventory_before and Global.run_bag.slots == bag_before and Global.meta_stash.slots == stash_before and Global.attempt_imprints == imprints_before, "research notes do not change equipment or consume imprints")
	_check(Global.library_discoveries == knowledge_before and Global.grimoire_entries == grimoire_before and Global.library_read_entries == read_before, "research notes do not discover or mark pages read")
	_check(Global._rng.state == rng_before and Global.followers == followers_before and SaveManager.debug_save_writes == writes_before, "research notes consume no gameplay RNG, currency or save writes")
	Global.run_inventory = saved_inventory
	Global.run_bag = saved_bag
	Global.meta_stash = saved_stash
	Global.attempt_imprints.assign(saved_imprints)
	Global.library_discoveries.assign(saved_knowledge)


func _run() -> void:
	SaveManager.save_dir = "user://saves_test_hub_library_data/"
	SaveManager.current_save = null
	Global.grimoire_entries.clear()
	Global.discovered_enemy_ids.clear()
	Global.library_discoveries.clear()
	Global.library_read_entries.clear()
	Global.library_target_key = ""
	var rng_before := Global._rng.state
	var inventory_before: Array = Global.run_inventory.items.duplicate() if Global.run_inventory != null else []
	var followers_before := Global.followers
	var knowledge_before: Array = Global.library_discoveries.duplicate()
	var writes_before := SaveManager.debug_save_writes
	var entries: Array[Dictionary] = LIBRARY.build_entries()
	_test_planning_clues(entries)
	_test_teaching_order_and_folios(entries)
	_test_pair_research(entries)
	_check(LIBRARY.CATEGORIES == ["Buildcraft", "Manifestations", "Pairs", "Enemies", "Items", "Augments", "Sets", "Recipes", "Chronicles"], "all nine subject books appear in shelf order")
	var guides := LIBRARY.filter_entries(entries, "Buildcraft", "")
	_check(guides.size() == 5, "five teaching pages are always available")
	for guide: Dictionary in guides:
		_check(bool(guide.get("discovered", false)) and not bool(guide.get("trackable", true)), "teaching pages are readable without a research target")
	for entry: Dictionary in entries:
		for field: String in ["key", "discovered", "unread", "hint", "trackable"]:
			_check(entry.has(field), "reader contract includes " + field)
		if entry["category"] in ["Buildcraft", "Recipes", "Chronicles"]:
			continue
		_check(not bool(entry.get("discovered", true)), "ordinary page starts hidden")
		_check(String(entry["title"]).begins_with("Undiscovered page · "), "hidden pages use a neutral ordinal")
		_check(entry["icon"] == null, "hidden pages have no revealing icon")
		_check(not String(entry["hint"] if entry.has("hint") else "").is_empty(), "hidden pages have a readable clue")
		_check(LIBRARY.filter_entries([entry], "All", String(entry["id"])).is_empty(), "hidden ID cannot be searched")
		var visible_terms := String(entry["category"]) + " " + String(entry["title"]) + " " + String(entry.get("hint", ""))
		visible_terms += " " + String(entry["ribbon"]["label"])
		for mark: Dictionary in entry["ribbon"]["marks"]:
			visible_terms += " " + String(mark["label"])
		_check(String(entry["search"]) == visible_terms.to_lower(), "hidden search contains only visible subject, ordinal, clue and public ribbon labels")
	var item := Global.item_db.get("beka", null) as ItemData
	_check(item != null, "fixture uses a live enabled item")
	_check(LIBRARY.filter_entries(entries, "Items", "beka").is_empty(), "unknown item name cannot be searched")
	var grimoire := Grimoire.catalogue(Global.augment_db)
	for row: Dictionary in grimoire:
		var page := _find(entries, row["key"])
		_check(not page.is_empty(), "every live Grimoire page has a library adaptation")
		if page.is_empty():
			continue
		_check(page["category"] == ("Chronicles" if row["section"] == "RECORDS" else "Recipes"), "records live in Chronicles and recipes in Recipes")
		_check(page["hint"] == row["hint"] and page["body"] == row["hint"], "locked Grimoire page shows only the authored clue")
		_check(page["title"] != row["name"] and not bool(page["discovered"]), "locked Grimoire page conceals its identity")
	_check(Global._rng.state == rng_before, "building pages never consumes gameplay RNG")
	_check(Global.followers == followers_before, "building pages never changes currency")
	_check((Global.run_inventory.items if Global.run_inventory != null else []) == inventory_before, "building pages never changes equipment")
	_check(SaveManager.debug_save_writes == writes_before, "building pages does not save or discover")
	_check(Global.library_discoveries == knowledge_before, "building pages does not grant knowledge")
	Global.library_note("item:beka")
	Global.library_note("duo:duo_lightning_rods")
	Global.library_note("record:accounts")
	entries = LIBRARY.build_entries()
	var beka := _find(entries, "item:beka")
	_check(beka.get("title", "") == item.display_name and bool(beka.get("unread", false)), "discovery reveals a named unread item page")
	_check(LIBRARY.filter_entries(entries, "Items", "  BEKA  ").size() == 1, "known name search trims whitespace and ignores case")
	var duo := _find(entries, "duo:duo_lightning_rods")
	_check(duo.get("title", "") == "Lightning Rods" and String(duo.get("body", "")).contains(AugmentDuos.rule(&"duo_lightning_rods")), "known recipe shows its live payoff")
	for row: Dictionary in grimoire:
		if row["key"] == "duo:duo_lightning_rods":
			_check(String(duo["body"]).contains(String(row["hint"])) and String(duo["body"]).contains(String(row["rule"])), "known recipe retains exact ingredient requirements alongside its payoff")
	var record := _find(entries, "record:accounts")
	_check(record.get("title", "") == "ACCOUNTS" and record.get("body", "") == StoryLines.RECORDS[0]["rule"], "known Chronicle preserves authored lore")
	Global.library_mark_read("item:beka")
	_check(not bool(_find(LIBRARY.build_entries(), "item:beka").get("unread", true)), "read marker removes the unread bookmark")
	# Naming a known item must not identify its undiscovered set.
	for data: ItemData in Global.item_db.values():
		if data != null and data.runtime_enabled and not data.set_id.is_empty():
			Global.library_note("item:" + data.id)
			var set_data := Global.set_db.get(StringName(data.set_id), null) as SetData
			if set_data != null and not Global.library_has("set:" + data.set_id):
				var page := _find(LIBRARY.build_entries(), "item:" + data.id)
				_check(not String(page["body"]).contains(set_data.display_name), "known item cross-reference conceals an unknown set")
				break
	_check(LIBRARY.filter_entries(entries, "All", "no matching phrase at all").is_empty(), "unmatched search has no pages")
	SaveManager.current_save = null
	print("HubLibraryDataTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
