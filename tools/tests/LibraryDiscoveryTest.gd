extends Node

var _passes := 0
var _failures := 0


func _ready() -> void:
	SaveManager.save_dir = "user://saves_test_library_discovery/"
	SaveManager.current_save = null
	Global.debug_disable_autosave = true
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _has(key: String) -> bool:
	return bool(Global.call("library_has", key))


func _note(key: String) -> bool:
	return bool(Global.call("library_note", key))


func _fresh() -> void:
	SaveManager.current_save = null
	Global.apply_save(SaveData.new())


func _item(id: String, slot: int = 0, rule: StringName = &"", set_id: String = "") -> ItemInstance:
	var data := ItemData.new()
	data.id = id
	data.equip_slot = slot as ItemData.EquipSlot
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	data.set_id = set_id
	var inst := ItemInstance.from_roll(data, 0, 1, 0.2, false)
	inst.manifestation_id = rule
	return inst


func _test_keys_and_reader() -> void:
	_fresh()
	var rng_state: int = Global._rng.state
	var followers: int = Global.followers
	_check(_note("item:acquired") and not _note("item:acquired"), "ordinary discoveries are recorded exactly once")
	_check(not _note("") and not _note("item:") and not _note("junk:secret"), "malformed or unsupported keys cannot create discoveries")
	Global.mark_enemy_discovered(&"grunt")
	Global.grimoire_note("facet:augment_magic_missile:lance")
	_check(_has("enemy:grunt") and _has("facet:augment_magic_missile:lance"), "enemy and Grimoire knowledge reuse their existing records")
	Global.call("library_mark_read", "item:unknown")
	Global.call("library_mark_read", "item:acquired")
	Global.call("library_mark_read", "guide:merging")
	Global.call("library_mark_read", "item:acquired")
	var read: Array = Global.get("library_read_entries")
	_check(read.size() == 2 and read.has("item:acquired") and read.has("guide:merging"), "only known pages and guides can be marked read, without duplicate marks")
	Global.call("library_set_target", "manifestation:anchor_rite")
	_check(Global.get("library_target_key") == "manifestation:anchor_rite" and not _has("manifestation:anchor_rite"), "pinning an unknown clue never unlocks it")
	Global.call("library_set_target", "invalid:target")
	_check(Global.get("library_target_key") == "manifestation:anchor_rite", "invalid targets leave the existing bookmark intact")
	Global.call("library_set_target", "")
	_check(Global.get("library_target_key") == "", "an empty target clears the bookmark")
	_check(Global._rng.state == rng_state and Global.followers == followers, "discovery and reading consume no RNG or currency")


func _test_acquisition_boundaries() -> void:
	_fresh()
	Global.run_bag = BagInventory.new()
	Global.run_inventory = Inventory.new()
	var detached := BagInventory.new()
	var stock := _item("vendor_only", 0, &"anchor_rite", "vendor_set")
	Global.call("library_note_item", stock)
	_check(not _has("item:vendor_only"), "the item discovery API refuses a detached preview before acquisition")
	var op := BalanceItemContext.begin(&"vendor_stock")
	detached.add_instance(stock)
	BalanceItemContext.end(op)
	_check(not _has("item:vendor_only") and not _has("manifestation:anchor_rite") and not _has("set:vendor_set"), "vendor generation and detached previews reveal nothing")
	op = BalanceItemContext.begin(&"reward")
	detached.add_instance(_item("detached_reward"))
	BalanceItemContext.end(op)
	_check(not _has("item:detached_reward"), "an acquisition source alone cannot turn a detached container into player ownership")
	RunEvents.item_operation.emit(&"purchased", stock, {"source": "trade"})
	_check(not _has("item:vendor_only"), "a purchase report before successful placement reveals nothing")
	op = BalanceItemContext.begin(&"trade")
	_check(Global.run_bag.add_instance(stock), "fixture: the vendor item actually enters the player bag")
	BalanceItemContext.end(op)
	_check(_has("item:vendor_only") and _has("manifestation:anchor_rite") and _has("set:vendor_set"), "successful acquisition learns its item, manifestation and set")
	for i in range(1, Global.run_bag.get_slot_count()):
		Global.run_bag.slots[i] = _item("filler_%d" % i)
	var rejected := _item("rejected", 0, &"third_litany", "rejected_set")
	op = BalanceItemContext.begin(&"pickup")
	_check(not Global.run_bag.add_instance(rejected), "fixture: a full bag rejects the pickup")
	BalanceItemContext.end(op)
	_check(not _has("item:rejected") and not _has("manifestation:third_litany") and not _has("set:rejected_set"), "failed bag additions reveal nothing")
	var duplicate := _item("vendor_only", 0, &"predestination_sigil", "vendor_set")
	op = BalanceItemContext.begin(&"pickup")
	_check(Global.run_bag.add_instance(duplicate), "fixture: a duplicate successfully feeds the owned stack")
	BalanceItemContext.end(op)
	_check(_has("manifestation:predestination_sigil"), "a successfully dissolved incoming rule is discovered too")
	Global.run_inventory.set_item(1, _item("equipped_reward", 1, &"martyr_circuit"))
	_check(_has("item:equipped_reward") and _has("manifestation:martyr_circuit"), "successful direct equipment grants are discovered")
	Global.add_owned_augment(&"augment_tesla_aura")
	_check(_has("augment:augment_tesla_aura"), "new augment ownership records knowledge")
	Global.store_imprint(&"stored_violence")
	_note("manifestation:stored_violence")
	_check(_has("manifestation:stored_violence"), "an explicit held-imprint grant can record its manifestation")


func _test_detached_merge_does_not_discover_imprints() -> void:
	_fresh()
	var preview := _item("detached_merge", 0, &"anchor_rite")
	var material := _item("detached_merge", 0, &"third_litany")
	_check(preview.merge_from(material), "fixture: detached duplicate merge dissolves a competing rule")
	_check(not _has("item:detached_merge") and not _has("manifestation:anchor_rite") and not _has("manifestation:third_litany"), "a detached duplicate merge cannot discover its item or dissolved imprint")


func _test_owned_imprinting_remembers_replaced_rule() -> void:
	_fresh()
	Global.run_bag = BagInventory.new()
	# This owned historical item bypasses the acquisition hook, so neither
	# rule has been learned before the real successful imprint operation.
	var target := _item("imprint_owned", Inventory.SLOT_RING, &"anchor_rite")
	Global.run_bag.slots[0] = target
	Global.store_imprint(&"stored_violence")
	Global.set_followers(1000)
	var result := ImprintService.apply(&"stored_violence", target)
	_check(bool(result.get("ok", false)), "fixture: a held imprint successfully replaces a rule on an owned item")
	_check(_has("item:imprint_owned") and _has("manifestation:stored_violence") and _has("manifestation:anchor_rite"), "a successful owned imprint remembers both its applied and returned rules")


func _test_pair_activation() -> void:
	_fresh()
	Global.run_inventory = Inventory.new()
	Global.run_inventory.items[2] = _item("pair_move", 2, &"sunder_wake")
	Global.run_inventory.items[7] = _item("pair_ring", 7, &"pilgrims_momentum")
	Global.run_inventory.items[3] = _item("pair_power", 3, &"predestination_sigil")
	var host := Node2D.new()
	add_child(host)
	var runner := ManifestationRunner.new()
	host.add_child(runner)
	_check(not _has("pair:slipstream_foundry"), "a pair one rule short stays unknown")
	Global.run_inventory.set_item(6, _item("pair_offhand", 6, &"splinter_dividend"))
	_check(runner.active_pair_count() == 1 and _has("pair:slipstream_foundry"), "the gameplay runner discovers an actually active pair")
	Global.run_inventory.remove_at(6)
	_check(_has("pair:slipstream_foundry"), "removing a pair contributor does not erase knowledge")
	# A live player's refresh can run during apply_save's augment signal,
	# before the new profile's inventory has replaced the previous one.
	Global.run_inventory.set_item(6, _item("pair_offhand_again", 6, &"splinter_dividend"))
	var refresh_during_restore := func(_ids: Array[StringName]) -> void: runner.refresh_effects(Global.run_inventory)
	Global.permanent_augments_changed.connect(refresh_during_restore)
	Global.apply_save(SaveData.new())
	Global.permanent_augments_changed.disconnect(refresh_during_restore)
	_check(not _has("pair:slipstream_foundry"), "a live runner cannot backfill the previous profile's pairs during restore")
	host.free()


func _test_legacy_backfill_and_profiles() -> void:
	_fresh()
	var old := SaveData.new()
	old.meta_owned_augment_ids = ["augment_tesla_aura"]
	old.meta_stash = StashInventory.new()
	old.meta_stash.slots[0] = _item("old_stash", 0, &"anchor_rite", "old_set")
	old.attempt_active = true
	old.attempt_inventory = Inventory.new()
	old.attempt_inventory.items[1] = _item("old_equipped", 1)
	old.attempt_bag = BagInventory.new()
	old.attempt_bag.slots[0] = _item("old_bag")
	old.attempt_vendor_bag = BagInventory.new()
	old.attempt_vendor_bag.slots[0] = _item("old_vendor")
	old.attempt_imprints = PackedStringArray(["stored_violence"])
	old.meta_seen_manifestation_cards = ["pair:red_line", "noun:ward", "intro"]
	Global.apply_save(old)
	_check(_has("item:old_stash") and _has("set:old_set") and _has("manifestation:anchor_rite"), "old saves backfill actual stash evidence")
	_check(_has("item:old_equipped") and _has("item:old_bag") and _has("augment:augment_tesla_aura"), "old saves backfill player equipment, bag and owned augments")
	_check(_has("manifestation:stored_violence") and _has("pair:red_line"), "old saves backfill held imprints and seen pairs")
	_check(not _has("item:old_vendor") and not _has("item:historical_absent") and not _has("manifestation:ward"), "backfill invents neither vendor nor absent historical nor noun discoveries")
	Global.call("library_mark_read", "item:old_stash")
	Global.call("library_set_target", "pair:loom")
	Global.on_attempt_failed_die_die()
	_check(_has("item:old_bag") and _has("pair:red_line"), "knowledge survives final attempt death")
	var first := SaveData.new()
	Global.write_save(first)
	Global.apply_save(SaveData.new())
	_check(not _has("item:old_bag") and (Global.get("library_read_entries") as Array).is_empty() and Global.get("library_target_key") == "", "switching to a fresh profile isolates discoveries, read marks and target")
	Global.apply_save(first)
	_check(_has("item:old_bag") and (Global.get("library_read_entries") as Array).has("item:old_stash") and Global.get("library_target_key") == "pair:loom", "switching back restores only that profile's knowledge")


func _test_disk_and_autosave() -> void:
	_fresh()
	var save := SaveData.new()
	save.slot_index = 0
	SaveManager.current_save = save
	Global.debug_disable_autosave = false
	var writes := SaveManager.debug_save_writes
	_note("item:disk_evidence")
	Global.call("library_mark_read", "item:disk_evidence")
	Global.call("library_set_target", "pair:loom")
	_check(SaveManager.debug_save_writes == writes, "knowledge changes defer their save instead of writing immediately")
	Global.flush_pending_save()
	_check(SaveManager.debug_save_writes == writes + 1, "knowledge changes request one throttled autosave")
	var disk := SaveManager.load_slot(0)
	_check(disk != null, "isolated profile knowledge reaches disk")
	if disk != null:
		Global.apply_save(SaveData.new())
		Global.apply_save(disk)
		_check(_has("item:disk_evidence") and (Global.get("library_read_entries") as Array).has("item:disk_evidence") and Global.get("library_target_key") == "pair:loom", "discoveries, read marks and target survive a disk round trip")
	SaveManager.current_save = null
	Global.debug_disable_autosave = true
	SaveManager.delete_slot(0)


func _run() -> void:
	var available := true
	for method in ["library_has", "library_note", "library_mark_read", "library_set_target", "library_note_item"]:
		available = available and Global.has_method(method)
	_check(available, "Global supplies the profile library discovery API")
	if available:
		_test_keys_and_reader()
		_test_acquisition_boundaries()
		_test_detached_merge_does_not_discover_imprints()
		_test_owned_imprinting_remembers_replaced_rule()
		_test_pair_activation()
		_test_legacy_backfill_and_profiles()
		_test_disk_and_autosave()
	print("LibraryDiscoveryTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
