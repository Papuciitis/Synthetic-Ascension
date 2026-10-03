extends Node

# The imprinter's hover dossiers (ui/widgets/ImprintDossier.gd through
# ItemTooltip.show_lines()). A held imprint's dossier says what the rule adds:
# the whole rule with real numbers on an item it fits, the numbers one per
# line, its nouns, its slots and what it lights among the worn rules. An
# item's dossier is the full before -> after of applying it: the rule lost and
# gained with this item's numbers, the numbers that change, the nouns and
# pairs that change, the equip comparison for a bagged item, and the price.
# Drives the screen's own hover and focus handlers, since a headless viewport
# never reports a hovered control, and checks every dossier fits the screen
# beside its row without covering it.
#
# Run: <godot> --headless --path . res://tools/tests/ImprintDossierTest.tscn

const IMPRINT_SCREEN := preload("res://ui/screens/ImprintScreen.gd")
const SCREEN_MARGIN := 8.0

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _data(item_id: String, slot: int) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.display_name = item_id.capitalize()
	data.equip_slot = slot as ItemData.EquipSlot
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	return data


func _item(item_id: String, slot: int, rarity: int, rule: StringName, roll: float = 0.5) -> ItemInstance:
	var inst := ItemInstance.from_roll(_data(item_id, slot), rarity, ItemInstance.Polarity.POS, roll, false)
	inst.manifestation_id = rule
	return inst


func _run() -> void:
	SaveManager.current_save = null
	Global.start_new_attempt()
	Global.debug_disable_autosave = true
	Global.attempt_active = true
	Global.set_followers(5000)

	# 1. Every rule states its numbers, from the same helpers as its text.
	var probe := _item("probe_ring", ItemData.EquipSlot.RING, 4, &"")
	var silent: Array[String] = []
	for id_value in ManifestationCatalog.all_ids():
		var id := StringName(id_value)
		var entries := ManifestationCatalog.stat_effects(id, probe)
		var whole := not entries.is_empty()
		for entry in entries:
			whole = whole and not String(entry["stat"]).is_empty() and not String(entry["value"]).is_empty()
		if not whole:
			silent.append(String(id))
	_check(silent.is_empty(), "every rule lists its numbers for the imprinter (%s)" % ", ".join(silent))
	var low := ManifestationCatalog.stat_effects(&"retaliation_writ", _item("r0", ItemData.EquipSlot.RING, 0, &""))
	var high := ManifestationCatalog.stat_effects(&"retaliation_writ", _item("r9", ItemData.EquipSlot.RING, 9, &""))
	_check(String(low[0]["value"]) != String(high[0]["value"]), "and the numbers follow the item's rank (%s at R0, %s at R9)" % [low[0]["value"], high[0]["value"]])
	var martyr := ManifestationCatalog.stat_effects(&"martyr_circuit", probe)
	_check(not bool(martyr[0]["good"]) and bool(martyr[1]["good"]), "a penalty is marked as one (Martyr Circuit's healthy Haste)")

	# The wardrobe: a cadence ring, a momentum+cadence boot and a ward+cadence
	# chest; a rule-less boot and a power item in the bag.
	for slot in range(Inventory.SLOT_COUNT):
		Global.run_inventory.set_item(slot, null)
	for slot in range(Global.run_bag.get_slot_count()):
		Global.run_bag.set_item(slot, null)
	var ring := _item("tarnished_signet", ItemData.EquipSlot.RING, 3, &"stored_violence")
	var boots := _item("pilgrim_boots", ItemData.EquipSlot.MOVE, 2, &"pilgrims_momentum", 0.3)
	var chest := _item("martyr_mail", ItemData.EquipSlot.ARMOR, 1, &"martyr_circuit")
	Global.run_inventory.set_item(ItemData.EquipSlot.RING, ring)
	Global.run_inventory.set_item(ItemData.EquipSlot.MOVE, boots)
	Global.run_inventory.set_item(ItemData.EquipSlot.ARMOR, chest)
	var spare := _item("road_boots", ItemData.EquipSlot.MOVE, 1, &"", 0.8)
	var blade := _item("power_charm", ItemData.EquipSlot.POWER, 2, &"")
	Global.run_bag.set_item(0, spare)
	Global.run_bag.set_item(1, blade)
	Global.attempt_imprints.clear()
	Global.store_imprint(&"retaliation_writ")
	Global.store_imprint(&"third_litany")

	var screen := IMPRINT_SCREEN.new()
	add_child(screen)
	await _frames(3)
	var dossier: ItemTooltip = screen.get("_dossier")
	var imprint_list: Control = screen.get("_imprint_list")
	var item_list: Control = screen.get("_item_list")
	var viewport_rect := get_viewport().get_visible_rect()
	_check(dossier != null and not dossier.visible, "the screen owns a dossier, hidden until something is hovered")
	_check(not screen.is_processing() and not dossier.is_processing(), "and nothing polls per frame")
	# Every part that can be seen ignores the pointer (the body's hidden
	# internal scroll bar never shows: the body does not scroll).
	var transparent := true
	for node in [dossier] + dossier.find_children("*", "Control", true, false):
		var control := node as Control
		if control == dossier or control.visible:
			transparent = transparent and control.mouse_filter == Control.MOUSE_FILTER_IGNORE
	_check(transparent, "the dossier never takes the pointer")

	# 2. A held imprint.
	var held_row := imprint_list.get_node_or_null("Imprint_retaliation_writ") as Control
	_check(held_row != null, "the held imprint has a row")
	screen.call("_on_row_entered", held_row)
	var text := dossier.body_label.text
	var on_ring := ring.snapshot_copy()
	on_ring.manifestation_id = &"retaliation_writ"
	_check(dossier.visible and dossier.name_label.text == "Retaliation Writ", "hovering it shows its dossier")
	_check(text.contains(ManifestationCatalog.describe(&"retaliation_writ", on_ring)), "with the whole rule, numbered for the highest-ranked worn item it fits")
	_check(text.contains("Numbers as they read on Tarnished Signet · R3 · worn"), "and says which item the numbers are for")
	var evasion := ManifestationCatalog.stat_effects(&"retaliation_writ", on_ring)[0]
	_check(text.contains("Evasion  %s" % evasion["value"]), "listing what it adds (Evasion %s)" % evasion["value"])
	_check(text.contains("[color=%s]WARD[/color]" % ManifestationNouns.hex(&"ward")) and text.contains("[color=%s]MOMENTUM[/color]" % ManifestationNouns.hex(&"momentum")), "naming its nouns in their colours")
	_check(text.contains("Armor, Movement, Ring"), "and the slots it goes on")
	_check(text.contains("Martyr Circuit") and text.contains("Pilgrim's Momentum"), "naming the worn rules it shares a noun with")
	_check(text.contains("On Tarnished Signet: ") and text.contains("RED LINE comes online"), "and what it would light on each item it fits")
	_check(text.contains("On Road Boots, once equipped: "), "including a bagged item, once equipped")
	_fits(dossier, held_row, viewport_rect, "the held dossier")
	_check(dossier.body_label.size.x > 300.0, "measured at its wrap width on first show (%.0f px)" % dossier.body_label.size.x)
	screen.call("_on_row_exited", held_row)
	await _frames(1)
	_check(not dossier.visible, "leaving the row hides it")

	# 3. A worn item: the full before -> after.
	var ring_row := item_list.get_node_or_null("Candidate_worn_%d" % ItemData.EquipSlot.RING) as Control
	_check(ring_row != null, "the worn ring is a candidate")
	screen.call("_on_row_entered", ring_row)
	text = dossier.body_label.text
	var price := ImprintService.price(ring)
	_check(dossier.visible and dossier.name_label.text == "Tarnished Signet" and dossier.meta_label.text.contains("WORN"), "hovering it shows the item's before → after")
	_check(text.contains("Imprint costs %d Followers  ·  5000 → %d" % [price, 5000 - price]), "with the price and the wallet after it")
	_check(text.contains("RULE LOST") and text.contains(ManifestationCatalog.describe(&"stored_violence", ring)), "the rule lost, whole, with this item's numbers")
	_check(text.contains("Kept as an imprint"), "and that it is kept as an imprint")
	_check(text.contains("RULE GAINED") and text.contains(ManifestationCatalog.describe(&"retaliation_writ", on_ring)), "the rule gained, whole, with this item's numbers")
	var lost_entry := ManifestationCatalog.stat_effects(&"stored_violence", ring)[0]
	_check(text.contains("− %s  %s" % [lost_entry["stat"], lost_entry["value"]]), "every number lost (%s %s)" % [lost_entry["stat"], lost_entry["value"]])
	_check(text.contains("+ Evasion  %s" % evasion["value"]), "and every number gained")
	_check(text.contains("[color=%s]WARD[/color] 1 → 2 lit" % ManifestationNouns.hex(&"ward")) and text.contains("[color=%s]CADENCE[/color] 3 → 2" % ManifestationNouns.hex(&"cadence")), "the noun counts that change")
	_check(text.contains("+ PAIR RED LINE") and text.contains("+ PAIR MARCHING ORDER") and text.contains("+ PAIR DEATH RATTLE"), "the pairs that come online")
	# Red Line scales at the mean rank of the worn rules speaking its nouns:
	# the ring (R3), the boots (R2) and the chest (R1).
	_check(text.contains(ManifestationPairCatalog.describe(&"red_line", 2.0)), "with their own numbers, at their contributors' mean rank")
	_check(text.contains("An imprint swaps the rule only"), "and that the item's own stats stay as they are")
	_fits(dossier, ring_row, viewport_rect, "the worn item's dossier")

	# Content taller than the screen even at twice the width is drawn smaller,
	# never cut off.
	var flood: Array[String] = []
	for index in range(160):
		flood.append("Line %d of a dossier far longer than any rule needs." % index)
	dossier.show_lines("Flood", "", Color.WHITE, "", flood, null, 0, IMPRINT_SCREEN.DOSSIER_WIDTH)
	screen.call("_place_dossier")
	_fits(dossier, ring_row, viewport_rect, "an overlong dossier")
	screen.call("_show_dossier", ring_row)
	_check(is_equal_approx(dossier.scale.x, 1.0), "and a dossier that fits is drawn at full size")

	# A ward rule's arrival brings Composure, a noun-wide effect.
	chest.manifestation_id = &""
	screen.call("_show_dossier", ring_row)
	text = dossier.body_label.text
	_check(text.contains("+ Composure"), "a first WARD rule brings Composure with it")
	_check(text.contains("− PAIR") == false, "and a change that only adds lights nothing dark")
	chest.manifestation_id = &"martyr_circuit"

	# 4. A bagged item: what equipping it would change against what is worn.
	var spare_row := item_list.get_node_or_null("Candidate_bag_0") as Control
	screen.call("_on_row_entered", spare_row)
	text = dossier.body_label.text
	_check(dossier.meta_label.text.contains("IN THE BAG"), "a bagged item says where it is")
	_check(text.contains("RULE LOST") and text.contains("carries no rule"), "with nothing lost from a rule-less item")
	_check(text.contains("Rules run only while worn"), "says applying it changes nothing worn yet")
	_check(text.contains("IF EQUIPPED · MOVEMENT") and text.contains("Replaces Pilgrim Boots (Pilgrim's Momentum)"), "then what equipping it would replace")
	_check(text.contains("MANIFESTATION CHANGES"), "through the item tooltip's own comparison rows")
	_check(text.contains("− PAIR") or text.contains("+ PAIR") or text.contains("No pair comes online"), "and the pair changes of wearing it")
	_fits(dossier, spare_row, viewport_rect, "the bagged item's dossier")

	# 5. A slot the rule does not take.
	var blade_row := item_list.get_node_or_null("Candidate_bag_1") as Control
	screen.call("_on_row_entered", blade_row)
	text = dossier.body_label.text
	_check(text.contains("Cannot apply: wrong slot") and text.contains("goes on Armor, Movement, Ring; this is a Power item"), "a wrong slot says so instead of a before → after")
	_check(not text.contains("RULE GAINED"), "and promises nothing")

	# 6. Keyboard and pad focus show the same dossier; pointer focus does not.
	screen.call("_hide_dossier")
	var apply := ring_row.find_child("Apply", true, false) as Button
	apply.grab_focus()
	await _frames(1)
	_check(dossier.visible and screen.get("_dossier_row") == ring_row, "a visible focus on Apply shows the item's dossier")
	_fits(dossier, ring_row, viewport_rect, "the focused dossier")
	var pick := held_row.find_child("Pick", true, false) as Button
	pick.grab_focus(true)
	await _frames(2)
	_check(not dossier.visible, "focus taken by the pointer (hidden) shows none of its own")
	var press := InputEventAction.new()
	press.action = &"ui_down"
	press.pressed = true
	get_viewport().push_input(press)
	await _frames(1)
	_check(get_viewport().gui_get_focus_owner() == pick and pick.has_focus(true), "the first key shows that focus where it is instead of moving past it")
	_check(dossier.visible and screen.get("_dossier_row") == held_row, "and brings its dossier")
	var release := InputEventAction.new()
	release.action = &"ui_down"
	release.pressed = false
	get_viewport().push_input(release)
	var other_row := imprint_list.get_node("Imprint_third_litany") as Control
	(other_row.find_child("Pick", true, false) as Button).grab_focus()
	await _frames(1)
	_check(dossier.visible and screen.get("_dossier_row") == other_row and dossier.name_label.text == "Third Litany", "keyboard focus on an imprint shows its dossier")

	# 7. Applying rebuilds the lists; focus returns to the rebuilt twin.
	apply = item_list.get_node("Candidate_worn_%d" % ItemData.EquipSlot.RING).find_child("Apply", true, false) as Button
	apply.grab_focus()
	await _frames(1)
	apply.pressed.emit()
	await _frames(2)
	_check(ring.manifestation_id == &"retaliation_writ", "Apply still applies")
	var focus_owner := get_viewport().gui_get_focus_owner()
	_check(focus_owner != null and screen.is_ancestor_of(focus_owner) and focus_owner.has_focus(true), "and focus survives the rebuild (%s)" % (String(focus_owner.get_path()) if focus_owner != null else "none"))

	screen.close()
	Global.attempt_imprints.clear()
	for slot in range(Inventory.SLOT_COUNT):
		Global.run_inventory.set_item(slot, null)
	print("ImprintDossierTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


## On screen, no taller than it, and beside the row rather than over it.
func _fits(dossier: ItemTooltip, row: Control, viewport_rect: Rect2, label: String) -> void:
	var rect := dossier.get_global_rect()
	var inside := viewport_rect.grow(-SCREEN_MARGIN + 0.5).encloses(rect)
	_check(rect.size.y <= viewport_rect.size.y - 2.0 * SCREEN_MARGIN, "%s is no taller than the screen (%.0f px)" % [label, rect.size.y])
	_check(inside, "%s stays on screen (%s)" % [label, str(rect)])
	_check(not rect.intersects(row.get_global_rect()), "%s does not cover its row" % label)
