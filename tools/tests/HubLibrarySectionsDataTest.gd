extends Node
## Content updates and ribbon chapters use live definitions without leaking knowledge.
const DATA := preload("res://ui/screens/HubLibraryData.gd")
var _passes := 0
var _failures := 0

func _ready() -> void:
	SaveManager.save_dir = "user://saves_test_library_section_data/"
	SaveManager.current_save = null
	call_deferred(&"_run")

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error("HubLibrarySectionsDataTest: " + message)

func _find(entries: Array[Dictionary], key: String) -> Dictionary:
	for entry: Dictionary in entries:
		if String(entry.key) == key:
			return entry
	return {}

func _run() -> void:
	Global.start_new_attempt()
	var entries := DATA.build_entries()
	_check(not entries.is_empty() and entries[0].get("ribbon", {}) is Dictionary and not entries[0].get("ribbon", {}).is_empty(), "the catalogue exposes public ribbon chapter metadata")
	if entries.is_empty() or entries[0].get("ribbon", {}).is_empty():
		_finish()
		return
	var rng_before := Global._rng.state
	var inventory_before := Global.run_inventory.items.duplicate()
	var followers_before := Global.followers
	var writes_before := SaveManager.debug_save_writes
	var items_before := Global.item_db.duplicate()
	var sets_before := Global.set_db.duplicate()
	var knowledge_before := Global.library_discoveries.duplicate()
	var read_before := Global.library_read_entries.duplicate()
	_test_chapters(entries)
	_test_live_updates()
	Global.item_db = items_before
	Global.set_db = sets_before
	Global.library_discoveries.assign(knowledge_before)
	Global.library_read_entries.assign(read_before)
	_check(Global._rng.state == rng_before and Global.run_inventory.items == inventory_before and Global.followers == followers_before, "rebuilding and classifying reference pages preserves gameplay")
	_check(SaveManager.debug_save_writes == writes_before, "catalogue refresh and metadata never save or award discoveries")
	_finish()

func _test_chapters(entries: Array[Dictionary]) -> void:
	for category: String in DATA.CATEGORIES:
		var previous := ""
		var previous_order := -1
		var completed: Array[String] = []
		var contiguous := true
		var ordered := true
		for entry: Dictionary in DATA.filter_entries(entries, category, ""):
			var chapter: Dictionary = entry.ribbon
			var id := String(chapter.id)
			if id != previous:
				contiguous = contiguous and not completed.has(id)
				completed.append(id)
				previous = id
			ordered = ordered and int(chapter.order) >= previous_order
			previous_order = int(chapter.order)
		_check(contiguous and ordered, category + " keeps chapter pages together in a deterministic order")
	var recipes := DATA.filter_entries(entries, "Recipes", "")
	var types: Array[String] = []
	for entry: Dictionary in recipes:
		if not types.has(String(entry.ribbon.id)):
			types.append(String(entry.ribbon.id))
	_check(types.size() == 5, "the recipe volume has its five existing ingredient/recipe types")
	var rules := DATA.filter_entries(entries, "Manifestations", "")
	_check(rules.all(func(entry: Dictionary) -> bool: return String(entry.ribbon.id).begins_with("noun:") and not String(entry.ribbon.label).is_empty()), "rules use the nouns already exposed by public clues")

func _fixture_item(id: String, slot: ItemData.EquipSlot, set_id: String = "") -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = "Future " + id.capitalize()
	item.description = "The first authored description."
	item.equip_slot = slot
	item.set_id = set_id
	item.mods = StatDelta.new()
	return item

func _test_live_updates() -> void:
	var set_data := SetData.new()
	set_data.id = &"library_future_set_fixture"
	set_data.display_name = "FUTURE SECRET SET"
	set_data.identity_sentence = "A new authored set identity."
	set_data.accent_color = Color(0.18, 0.62, 0.51)
	Global.set_db[set_data.id] = set_data
	var ring := _fixture_item("library_future_ring_fixture", ItemData.EquipSlot.RING)
	var offhand := _fixture_item("library_future_offhand_fixture", ItemData.EquipSlot.OFFHAND)
	var cursed := _fixture_item("curse_library_future_fixture", ItemData.EquipSlot.RING, String(set_data.id))
	for item: ItemData in [ring, offhand, cursed]:
		Global.item_db[item.id] = item
	var snapshot := DATA.build_entries()
	var sealed_ring := _find(snapshot, "item:" + ring.id)
	var sealed_offhand := _find(snapshot, "item:" + offhand.id)
	var sealed_curse := _find(snapshot, "item:" + cursed.id)
	var sealed_set := _find(snapshot, "set:" + String(set_data.id))
	_check(not sealed_ring.is_empty() and not sealed_set.is_empty(), "new registered item and set definitions appear without hand-added book pages")
	_check(not sealed_ring.discovered and not sealed_set.discovered, "new content begins sealed")
	_check(String(sealed_ring.ribbon.label) == "Rings" and String(sealed_offhand.ribbon.label) == "Offhands" and sealed_ring.ribbon.color != sealed_offhand.ribbon.color, "public slot groups distinguish offhands and rings before their names are known")
	_check(sealed_curse.ribbon.marks.is_empty() and not str(sealed_curse.ribbon).contains(set_data.display_name), "sealed items do not reveal curse status or set membership through ribbon metadata")
	_check(sealed_set.ribbon.color != set_data.accent_color, "an unknown set does not expose its authored identity color")
	Global.library_discoveries.append("item:" + cursed.id)
	var known_curse := _find(DATA.build_entries(), "item:" + cursed.id)
	_check(known_curse.ribbon.marks.size() == 1 and String(known_curse.ribbon.marks[0].kind) == "curse", "a discovered cursed item gains its curse marker while an unknown set stays hidden")
	Global.library_discoveries.append("set:" + String(set_data.id))
	var known_snapshot := DATA.build_entries()
	known_curse = _find(known_snapshot, "item:" + cursed.id)
	var marks: Array = known_curse.ribbon.marks
	_check(marks.size() == 2 and marks.any(func(mark: Dictionary) -> bool: return mark.kind == "set" and mark.label == set_data.display_name and mark.color == set_data.accent_color), "a known set adds its authored membership mark alongside the curse")
	_check(known_curse.ribbon.id == sealed_ring.ribbon.id and known_curse.ribbon.color == sealed_ring.ribbon.color, "a cursed set ring retains the same primary ring chapter color")
	_check(_find(known_snapshot, "set:" + String(set_data.id)).ribbon.color == set_data.accent_color, "recorded set accounts use their native set accent color")
	_check(DATA.filter_entries(known_snapshot, "Items", "rings curse").any(func(entry: Dictionary) -> bool: return entry.key == "item:" + cursed.id), "known ribbon traits are searchable without exposing unknown traits")
	Global.library_discoveries.append("item:" + ring.id)
	Global.library_read_entries.append("item:" + ring.id)
	var before_update := DATA.build_entries()
	ring.description = "Updated authored balance description."
	ring.display_name = "Updated ring name"
	var updated := _find(DATA.build_entries(), "item:" + ring.id)
	_check(updated.discovered and not updated.unread and updated.title == ring.display_name and String(updated.body).contains(ring.description), "same-ID updates refresh content while retaining discovery and read status")
	_check(not String(_find(before_update, "item:" + ring.id).body).contains(ring.description), "an already-built reader is a snapshot until the catalogue is rebuilt")
	ring.runtime_enabled = false
	_check(_find(DATA.build_entries(), "item:" + ring.id).is_empty(), "runtime-disabled items are excluded automatically")
	Global.item_db.erase(ring.id)
	_check(Global.library_has("item:" + ring.id), "temporary removed-content knowledge remains keyed by stable ID")

func _finish() -> void:
	print("HubLibrarySectionsDataTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
