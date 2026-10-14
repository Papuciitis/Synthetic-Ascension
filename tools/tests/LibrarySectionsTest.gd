extends Node

const HELPER_PATH := "res://ui/widgets/library/LibrarySections.gd"
var _helper: Script
var _passes := 0
var _failures := 0


func _ready() -> void:
	SaveManager.save_dir = "user://saves_test_library_sections/"
	SaveManager.current_save = null
	call_deferred(&"_run")


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error("LibrarySectionsTest: " + message)


func _entry(category: String, id: String, known: bool = false) -> Dictionary:
	return {"category": category, "id": id, "key": id, "folio": 1,
		"title": "Known account" if known else "Undiscovered page · 01",
		"subtitle": "Public clue", "hint": "Public clue", "body": "Public clue", "discovered": known}


func _run() -> void:
	_check(ResourceLoader.exists(HELPER_PATH), "a read-only section classifier exists")
	if not ResourceLoader.exists(HELPER_PATH):
		_finish()
		return
	_helper = load(HELPER_PATH) as Script
	var knowledge := Global.library_discoveries.duplicate()
	var read := Global.library_read_entries.duplicate()
	var rng_before := Global._rng.state
	var writes_before := SaveManager.debug_save_writes
	Global.library_discoveries.clear()
	_test_slots_and_discovery()
	_test_nouns()
	_test_recipe_and_guide_order()
	_test_neutral_and_sets()
	_check(Global.library_discoveries.is_empty() and Global.library_read_entries == read, "classification never awards discovery or marks accounts read")
	_check(Global._rng.state == rng_before, "classification never consumes gameplay RNG")
	_check(SaveManager.debug_save_writes == writes_before, "classification never writes a profile")
	Global.library_discoveries.assign(knowledge)
	_finish()


func _test_slots_and_discovery() -> void:
	# A newly shipped item must classify from its resource without a bespoke ID list.
	var labels := ["Health", "Armor", "Movement", "Power", "Haste", "Luck", "Offhands", "Rings", "Bag items"]
	var colors := {}
	var keys_before := Global.item_db.keys()
	for slot: int in range(-1, 8):
		var item := ItemData.new()
		item.id = "library_section_fixture_%d" % slot
		item.equip_slot = slot as ItemData.EquipSlot
		Global.item_db[item.id] = item
		var source := _entry("Items", item.id)
		var untouched := source.duplicate(true)
		var section: Dictionary = _helper.describe(source)
		var index := slot if slot >= 0 else 8
		_check(section["id"] == ("slot:%d" % slot if slot >= 0 else "slot:bag"), "new equipment groups by native slot even before discovery")
		_check(section["label"] == labels[index] and int(section["order"]) == index, "public slot groups retain equipment order")
		_check((section["marks"] as Array).is_empty(), "sealed equipment has no hidden curse or set marks")
		_check(source == untouched, "classification does not mutate its sanitized input")
		colors[section["color"]] = true
		Global.item_db.erase(item.id)
	_check(colors.size() == 9, "slot families have distinct cloth colors")
	_check(Global.item_db.keys() == keys_before, "classification leaves the item database unchanged")
	var cursed := ItemData.new()
	cursed.id = "curse_library_fixture"
	cursed.equip_slot = ItemData.EquipSlot.RING
	cursed.set_id = "library_fixture_set"
	var set_data := SetData.new()
	set_data.id = &"library_fixture_set"
	set_data.display_name = "Secret fixture set"
	set_data.accent_color = Color("3e8a81")
	Global.item_db[cursed.id] = cursed
	Global.set_db[set_data.id] = set_data
	var sealed: Dictionary = _helper.describe(_entry("Items", cursed.id))
	_check(sealed["label"] == "Rings" and (sealed["marks"] as Array).is_empty(), "a sealed cursed set ring exposes only its public slot")
	var known: Dictionary = _helper.describe(_entry("Items", cursed.id, true))
	_check((known["marks"] as Array).size() == 1 and known["marks"][0]["kind"] == "curse", "a known curse has its mark while its unknown set stays hidden")
	Global.library_discoveries.append("set:library_fixture_set")
	var recorded: Dictionary = _helper.describe(_entry("Items", cursed.id, true))
	_check(recorded["marks"].size() == 2 and recorded["marks"][1]["kind"] == "set", "known curse and discovered set each get a secondary mark")
	_check(recorded["marks"][1]["label"] == "Secret fixture set" and recorded["marks"][1]["color"] == set_data.accent_color, "a discovered set mark uses its authored name and color")
	_check(recorded["color"] == sealed["color"] and recorded["id"] == "slot:7", "a cursed set ring keeps its ring section identity")
	_check(not str(sealed).contains("Secret fixture") and not str(sealed).contains("library_fixture_set"), "sealed metadata retains no raw set ID or set name")
	Global.library_discoveries.erase("set:library_fixture_set")
	Global.item_db.erase(cursed.id)
	Global.set_db.erase(set_data.id)


func _test_nouns() -> void:
	var rule: Dictionary = _helper.describe(_entry("Manifestations", "pilgrims_momentum"))
	_check(rule["id"] == "noun:momentum" and rule["label"] == "Momentum" and rule["order"] == 1, "a rule respects its authored primary noun and canonical order")
	_check(rule["color"] == ManifestationNouns.colour(&"momentum"), "noun cloth uses the existing game's noun palette")
	_check(rule["marks"].size() == 1 and rule["marks"][0]["label"] == "Cadence", "a sealed rule may show its second already-public clue noun")
	var pair: Dictionary = _helper.describe(_entry("Pairs", "red_line"))
	_check(pair["id"] == "noun:ward" and pair["marks"].size() == 1 and pair["marks"][0]["label"] == "Momentum", "a pair uses its native first noun and preserves the second noun mark")
	_check(not str(rule).contains("Pilgrim") and not str(pair).contains("Red Line"), "public noun classification does not retain hidden rule or payoff names")
	for category: String in ["Manifestations", "Pairs"]:
		var ids: Array = ManifestationCatalog.all_ids() if category == "Manifestations" else ManifestationPairCatalog.all_ids()
		for id: StringName in ids:
			var section: Dictionary = _helper.describe(_entry(category, String(id)))
			_check(String(section["id"]).begins_with("noun:") and section["order"] >= 0 and section["order"] < 5, "all live noun accounts classify without a hand-maintained account list")


func _test_recipe_and_guide_order() -> void:
	var kinds := ["transcend", "duo", "facet", "thesis", "canon"]
	var labels := ["Transcendence", "Duo", "Facet", "Thesis", "Canon"]
	for index: int in kinds.size():
		var source := _entry("Recipes", kinds[index] + ":a_new_future_account")
		var section: Dictionary = _helper.describe(source)
		_check(section["id"] == "recipe:" + kinds[index] and section["label"] == labels[index] and section["order"] == index, "new recipe accounts inherit their public Grimoire section")
	var topics := ["equipment_identity", "nouns_and_pairs", "merges_and_imprints", "augment_growth", "doctrine_families"]
	for index: int in topics.size():
		var source := _entry("Buildcraft", topics[index], true)
		source["folio"] = index + 1
		var section: Dictionary = _helper.describe(source)
		_check(section["id"] == "guide:" + topics[index] and section["order"] == index, "Buildcraft retains its authored teaching sequence")


func _test_neutral_and_sets() -> void:
	for category: String in ["Augments", "Enemies", "Chronicles", "Future category"]:
		var sealed: Dictionary = _helper.describe(_entry(category, "secret_new_name"))
		var known: Dictionary = _helper.describe(_entry(category, "secret_new_name", true))
		_check(sealed["label"].begins_with("Sealed") and known["label"].begins_with("Recorded"), "uncategorized content uses honest recorded/sealed sections")
		_check(sealed["marks"].is_empty() and not str(sealed).contains("secret_new_name"), "fallback classification has no invented role or hidden ID")
	var fixture := SetData.new()
	fixture.id = &"library_set_color_fixture"
	fixture.display_name = "Fixture name"
	fixture.accent_color = Color("477866")
	Global.set_db[fixture.id] = fixture
	var sealed: Dictionary = _helper.describe(_entry("Sets", String(fixture.id)))
	var known: Dictionary = _helper.describe(_entry("Sets", String(fixture.id), true))
	_check(sealed["id"] == "sealed" and sealed["order"] == 1 and sealed["label"] == "Sealed sets", "unknown sets share an identity-free section")
	_check(known["id"] == "recorded" and known["order"] == 0 and known["label"] == "Recorded sets" and known["color"] == fixture.accent_color, "known sets use authored accent without splitting each set into a category")
	_check(sealed["color"] != fixture.accent_color and not str(sealed).contains("Fixture name"), "a sealed set reveals neither its accent nor name")
	Global.set_db.erase(fixture.id)
	for category: String in ["Items", "Sets", "Manifestations", "Pairs", "Recipes", "Buildcraft"]:
		var missing: Dictionary = _helper.describe(_entry(category, "missing_definition"))
		_check(not String(missing["id"]).is_empty() and not String(missing["label"]).is_empty() and missing["marks"].is_empty(), "missing definitions fall back without errors or raw IDs")


func _finish() -> void:
	print("LibrarySectionsTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
