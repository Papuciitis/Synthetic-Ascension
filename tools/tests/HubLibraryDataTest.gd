extends Node

const LIBRARY := preload("res://ui/screens/HubLibraryData.gd")
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
		_check(String(entry["search"]) == (String(entry["category"]) + " " + String(entry["title"]) + " " + String(entry.get("hint", ""))).to_lower(), "hidden search contains only visible subject, ordinal and clue")
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
