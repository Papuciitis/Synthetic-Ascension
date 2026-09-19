extends Node

# Manifestation imprints: a merge never refuses and never destroys a rule.
# The worn copy keeps its rule, a rule-less copy adopts one, and a rule the
# merge dissolves is held as an imprint the Hub's imprinter can put onto a
# compatible item for Followers. Imprints ride the save.
#
# Run: <godot> --headless --path . --quit-after 8000 res://tools/tests/ManifestationImprintTest.tscn

const IMPRINT_SCREEN := preload("res://ui/screens/ImprintScreen.gd")

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _make_data(item_id: String, slot: int) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.display_name = item_id
	data.equip_slot = slot as ItemData.EquipSlot
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	return data


func _item(data: ItemData, rarity: int, rule: StringName = &"") -> ItemInstance:
	var inst := ItemInstance.from_roll(data, rarity, ItemInstance.Polarity.POS, 0.5, false)
	inst.manifestation_id = rule
	return inst


func _run() -> void:
	Global.start_new_attempt()
	Global.attempt_active = true
	Global.attempt_imprints.clear()
	var ring_pool: Array = ManifestationCatalog.pool_for_slot(ItemData.EquipSlot.RING)
	_check(ring_pool.size() >= 2, "the catalog offers at least two rules for rings (%d)" % ring_pool.size())
	var rule_a: StringName = ring_pool[0].id
	var rule_b: StringName = ring_pool[1].id
	var ring := _make_data("imprint_ring", ItemData.EquipSlot.RING)

	# 1. Merges keep the destination's rule and hold the dissolved one.
	var worn := _item(ring, 2, rule_a)
	var copy := _item(ring, 2, rule_b)
	var progress_before: int = worn.progress
	_check(worn.merge_from(copy), "two copies with different rules still merge")
	_check(worn.manifestation_id == rule_a and worn.progress > progress_before, "the destination keeps its rule and grows")
	_check(Global.attempt_imprints == [rule_b], "the dissolved rule is held as an imprint")
	var plain := _item(ring, 2)
	worn.merge_from(plain)
	_check(Global.attempt_imprints.size() == 1, "a rule-less copy leaves no imprint")
	var bare := _item(ring, 2)
	bare.merge_from(_item(ring, 2, rule_a))
	_check(bare.manifestation_id == rule_a and Global.attempt_imprints.size() == 1, "a rule-less destination adopts the incoming rule instead of dissolving it")
	worn.merge_from(_item(ring, 2, rule_b))
	_check(Global.attempt_imprints.size() == 1, "an imprint is held once, however many copies carried it")

	# 2. The pouch is bounded, oldest first.
	Global.attempt_imprints.clear()
	var all_defs: Array = ManifestationCatalog.pool_for_slot(ItemData.EquipSlot.RING) + ManifestationCatalog.pool_for_slot(ItemData.EquipSlot.OFFHAND) + ManifestationCatalog.pool_for_slot(ItemData.EquipSlot.POWER)
	var distinct: Array[StringName] = []
	for def in all_defs:
		if not distinct.has(def.id):
			distinct.append(def.id)
	_check(distinct.size() > Global.IMPRINT_CAP, "enough distinct rules exist to overflow the pouch (%d)" % distinct.size())
	for id in distinct:
		Global.store_imprint(id)
	_check(Global.attempt_imprints.size() == Global.IMPRINT_CAP and not Global.attempt_imprints.has(distinct[0]) and Global.attempt_imprints.has(distinct[distinct.size() - 1]), "the pouch holds %d and forgets the oldest" % Global.IMPRINT_CAP)
	_check(not Global.store_imprint(&"no_such_rule"), "an unknown rule is refused")

	# 3. The imprinter.
	Global.attempt_imprints.clear()
	Global.store_imprint(rule_b)
	Global.set_followers(1000)
	var target := _item(ring, 3, rule_a)
	var boot := _item(_make_data("imprint_boot", ItemData.EquipSlot.MOVE), 3)
	var cost := ImprintService.price(target)
	_check(cost >= ImprintService.PRICE_MIN, "an imprint costs at least %d Followers (%d)" % [ImprintService.PRICE_MIN, cost])
	var boot_verdict := ImprintService.can_apply(rule_b, boot)
	_check(not bool(boot_verdict.get("ok", true)) or ring_pool[1].allows_slot(ItemData.EquipSlot.MOVE), "a rule that does not allow the slot is refused (%s)" % String(boot_verdict.get("reason", "")))
	_check(not bool(ImprintService.can_apply(rule_a, target).get("ok", true)), "a rule that is not held is refused")
	Global.set_followers(cost - 1)
	_check(not bool(ImprintService.can_apply(rule_b, target).get("ok", true)), "too few Followers refuses")
	Global.set_followers(1000)
	var result := ImprintService.apply(rule_b, target)
	_check(bool(result.get("ok", false)) and target.manifestation_id == rule_b and int(Global.followers) == 1000 - cost, "applying puts the rule on the item and charges the price")
	_check(not Global.attempt_imprints.has(rule_b) and Global.attempt_imprints.has(rule_a), "the applied imprint is spent and the replaced rule is held in turn")
	_check(bool(ImprintService.can_apply(rule_a, target).get("ok", false)) and String(ImprintService.can_apply(rule_b, target).get("reason", "")) == "not held", "the replaced rule can go back on for a price; the spent one is no longer held")
	Global.run_inventory.set_item(ItemData.EquipSlot.RING, target)
	var candidates := ImprintService.candidates(rule_a)
	var found := false
	for candidate in candidates:
		if candidate["inst"] == target and String(candidate["where"]) == "worn":
			found = true
	_check(found, "the worn ring is listed as a candidate for the held rule")

	# 4. Save round trip.
	var save := SaveData.new()
	Global.write_save(save)
	_check(save.attempt_imprints.size() == 1 and String(save.attempt_imprints[0]) == String(rule_a), "the pouch rides the save")
	Global.attempt_imprints.clear()
	Global.apply_save(save)
	_check(Global.attempt_imprints == [rule_a], "and comes back on load")

	# 5. The screen builds against the live pouch.
	var screen := IMPRINT_SCREEN.new()
	add_child(screen)
	await get_tree().process_frame
	var rows := 0
	for child in screen.get_node("Root").find_children("Imprint_*", "", true, false):
		rows += 1
	_check(rows == 1, "the imprinter lists the held imprint (%d rows)" % rows)
	var candidate_rows := screen.get_node("Root").find_children("Candidate_*", "", true, false).size()
	_check(candidate_rows >= 1, "and the items it could go onto (%d)" % candidate_rows)
	screen.close()
	Global.attempt_imprints.clear()
	Global.run_inventory.set_item(ItemData.EquipSlot.RING, null)
	print("ManifestationImprintTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
