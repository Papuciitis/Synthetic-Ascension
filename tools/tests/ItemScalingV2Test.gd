extends Node

# Balance plan Task 2: item stat progression through explicit profiles.
# Pins the specification's exact anchors, continuity at every anchor,
# monotonic growth at a fixed roll, finite outputs far past the last anchor,
# the legacy fallback for items without a profile, resource isolation, the
# real player's stats through the roll pipeline, and save/load/save
# idempotence for equipped, bagged and stashed instances.
#
# Run: <godot> --headless --path . res://tools/tests/ItemScalingV2Test.tscn

const PLAYER := preload("res://core/actors/player/player.tscn")

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _item(id: String, rank: int, roll: float = 0.0, meter: float = 0.0, polarity: int = ItemInstance.Polarity.POS) -> ItemInstance:
	var data: ItemData = Global.item_db[id]
	var inst := ItemInstance.from_roll(data, rank, polarity, roll, false)
	if meter > 0.0:
		inst.upgrade_meter = meter
		inst._recompute_flat_mods()
	return inst


func _near(a: float, b: float, tolerance: float = 0.0005) -> bool:
	return absf(a - b) <= tolerance


func _run() -> void:
	_check(ItemScaling.load_profiles() and ItemScaling.errors().is_empty(), "the version 2 profile file loads and validates (%s)" % ", ".join(ItemScaling.errors()))
	# Every runtime item has a profile with each stat in exactly one channel.
	var missing: Array = []
	for id in Global.item_db:
		if String(id) == "item_test":
			continue
		if not ItemScaling.has_profile(String(id)):
			missing.append(String(id))
	_check(missing.is_empty() and not ItemScaling.has_profile("item_test"), "every runtime item except item_test has a profile (missing: %s)" % ", ".join(missing))
	var channels_ok := true
	for id in ItemScaling.profile_ids():
		var entry := ItemScaling.profile(String(id))
		var seen := {}
		for block in ["anchors", "rates", "flat"]:
			for stat in entry.get(block, {}):
				if seen.has(stat):
					channels_ok = false
				seen[stat] = true
		if seen.is_empty():
			channels_ok = false
	_check(channels_ok, "each profile names every stat channel exactly once")

	# Exact anchors from the specification.
	_check(_near(_item("conduit_heart", 6).rolled_mods.max_hp, 70.0) and _near(_item("conduit_heart", 15).rolled_mods.max_hp, 180.0), "Conduit Heart gives 70 HP at R6 and 180 at R15")
	_check(_near(_item("conduit_heart", 10, 0.0, 0.5).rolled_mods.max_hp, 125.0), "Conduit Heart gives 125 HP at R10.5 (linear between anchors)")
	_check(_near(_item("lattice_pulsecoil", 15).rolled_mods.max_hp, 150.0) and _near(_item("gravemarch_carapace", 15).rolled_mods.armor, 46.0), "Lattice Pulsecoil R15 = 150 HP, Gravemarch Carapace R15 = 46 armour")
	_check(_near(_item("conduit_heart", 0).rolled_mods.max_hp, 0.0) and _near(_item("conduit_heart", 1).rolled_mods.max_hp, 10.0) and _near(_item("lattice_pulsecoil", 1).rolled_mods.max_hp, 9.0), "R0 and R1 keep their pre-revision values")
	var six := _item("conduit_heart", 6)
	six.manifestation_id = &"scar_tissue"
	var six_half := _item("conduit_heart", 6, 0.0, 0.5)
	six_half.manifestation_id = &"scar_tissue"
	_check(six_half.rolled_mods.max_hp > six.rolled_mods.max_hp and six_half.best_pct == six.best_pct and six_half.manifestation_id == six.manifestation_id, "R6.5 exceeds R6 without changing roll or Manifestation (%.2f > %.2f)" % [six_half.rolled_mods.max_hp, six.rolled_mods.max_hp])
	_check(_near(_item("conduit_heart", 45).rolled_mods.max_hp, 380.0 + 15.0 * (200.0 / 15.0)), "above R30 the R15-to-R30 slope continues (R45 = %.1f)" % _item("conduit_heart", 45).rolled_mods.max_hp)
	# Rates: movement and haste approach their limits smoothly.
	var greaves_r1 := _item("conduit_greaves", 1).rolled_mods.move_speed
	var greaves_r6 := _item("conduit_greaves", 6).rolled_mods.move_speed
	_check(_near(greaves_r1, 5.0) and _near(greaves_r6, 5.0 + 40.0 * (1.0 - exp(-5.0 / 12.0)), 0.001) and _item("conduit_greaves", 200).rolled_mods.move_speed < 45.0, "Conduit Greaves follow the smooth rate toward the 45 limit (R6 = %.2f)" % greaves_r6)
	_check(_near(_item("conduit_greaves", 6).rolled_mods.max_hp, 8.0) and _near(_item("conduit_greaves", 15).rolled_mods.max_hp, 24.0), "utility items carry the secondary HP anchors")
	# Continuity at every anchor and monotonic growth at a fixed roll.
	var continuous := true
	var monotone := true
	var finite := true
	for id in ItemScaling.profile_ids():
		var data: ItemData = Global.item_db[String(id)]
		for rank in ItemScaling.anchor_ranks():
			if float(rank) <= 0.0:
				continue
			var below := ItemScaling.flat_mods_at(data, float(rank) - 0.0001)
			var above := ItemScaling.flat_mods_at(data, float(rank) + 0.0001)
			for stat in ItemScaling.STAT_KEYS:
				if absf(float(below.get(stat)) - float(above.get(stat))) > 0.01:
					continuous = false
		var previous: StatDelta = ItemScaling.flat_mods_at(data, 0.0)
		for step in range(1, 81):
			var current: StatDelta = ItemScaling.flat_mods_at(data, float(step) * 0.5)
			for stat in ItemScaling.STAT_KEYS:
				if float(current.get(stat)) < float(previous.get(stat)) - 0.000001:
					monotone = false
					print("non-monotone: %s %s at rank %.1f (%.4f -> %.4f)" % [id, stat, float(step) * 0.5, float(previous.get(stat)), float(current.get(stat))])
			previous = current
		for rank in [0.0, 1.0, 6.0, 15.0, 30.0, 50.0, 100.0]:
			var probe := ItemScaling.flat_mods_at(data, rank)
			for stat in ItemScaling.STAT_KEYS:
				if not is_finite(float(probe.get(stat))):
					finite = false
	_check(continuous, "every profile is continuous at every anchor")
	_check(monotone, "every stat is non-decreasing with rank at a fixed roll (negative Gravemarch rates improve)")
	_check(finite, "outputs are finite at R0/1/6/15/30/50/100")
	_check(_item("gravemarch_stompers", 0).rolled_mods.move_speed < 0.0 and _item("gravemarch_stompers", 15).rolled_mods.move_speed > 0.0, "Gravemarch Stompers overcome their initial drawback with rank")
	# Curses keep their authored roll ranges and grow the positive package.
	var crown := _item("curse_starving_crown", 15, -0.3, 0.0, ItemInstance.Polarity.NEG)
	_check(_near(crown.rolled_mods.max_hp, 220.0) and crown.polarity == ItemInstance.Polarity.NEG and crown.best_pct == -0.3, "a curse's flat profile grows while its NEG roll is untouched")
	# Legacy fallback: a fixture item without a profile keeps the old formula.
	var legacy_data := ItemData.new()
	legacy_data.id = "fixture_legacy"
	legacy_data.equip_slot = ItemData.EquipSlot.HP
	legacy_data.mods = StatDelta.new()
	legacy_data.rarity_base = StatDelta.new()
	legacy_data.rarity_base.max_hp = 20.0
	var legacy := ItemInstance.from_roll(legacy_data, 6, ItemInstance.Polarity.POS, 0.0, false)
	_check(_near(legacy.rolled_mods.max_hp, 20.0 * (RarityMath.potency(6.0) - 1.0)), "an item without a profile keeps the legacy potency formula (%.2f)" % legacy.rolled_mods.max_hp)
	# Resource isolation: ItemData is never mutated; instances never share.
	var data_heart: ItemData = Global.item_db["conduit_heart"]
	var mods_before := data_heart.mods.copy() if data_heart.mods != null else null
	var a := _item("conduit_heart", 6)
	var b := _item("conduit_heart", 6)
	a.upgrade_meter = 0.9
	a._recompute_flat_mods()
	_check(a.rolled_mods != b.rolled_mods and _near(b.rolled_mods.max_hp, 70.0) and (mods_before == null or data_heart.mods.equals(mods_before)), "recomputing one instance mutates neither its sibling nor the ItemData")
	# Effect factors for Task 3 are evaluated (not yet consumed by effects).
	_check(_near(ItemScaling.accessory_factor("acc_oakheart", 0.0), 1.0) and _near(ItemScaling.accessory_factor("ring_regeneration", 15.0), 1.5) and _near(ItemScaling.accessory_factor("acc_firestone", 6.0), 1.2) and _near(ItemScaling.accessory_factor("conduit_heart", 6.0), 1.0), "accessory effect factors follow their profiles and default to 1")

	# The real player: equipping Conduit Heart R15 adds 180 max HP through
	# the roll pipeline at a neutral roll.
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.run_luck = 0.0
	var player = PLAYER.instantiate()
	add_child(player)
	await get_tree().process_frame
	player.set_process(false)
	player.set_physics_process(false)
	var race: RaceData = Global.race_db.get("human", null)
	var style: StyleData = Global.style_db.get("ranged", null)
	Global.run_inventory.clear()
	player.recompute_run_stats(race, style, false)
	var hp_without: float = player.stats.max_hp
	Global.run_inventory.set_item(ItemData.EquipSlot.HP, _item("conduit_heart", 15), null)
	player.recompute_run_stats(race, style, false)
	_check(_near(float(player.stats.max_hp) - hp_without, 180.0, 0.01), "a worn R15 Conduit Heart adds 180 max HP to the real player (%.2f)" % (float(player.stats.max_hp) - hp_without))
	var r6: float = 0.0
	Global.run_inventory.set_item(ItemData.EquipSlot.HP, _item("conduit_heart", 6), null)
	player.recompute_run_stats(race, style, false)
	r6 = float(player.stats.max_hp) - hp_without
	_check(_near(r6, 70.0, 0.01) and (180.0 / 70.0) >= 1.25, "R6 to R15 on the HP item raises the item's contribution by far more than 25%% (%.0f -> 180)" % r6)

	# Save / load / save idempotence across equipped, bag and stash.
	Global.run_inventory.clear()
	var worn := _item("conduit_lens", 7, 0.25, 0.375)
	worn.manifestation_id = &"scar_tissue"
	worn.locked = true
	Global.run_inventory.set_item(ItemData.EquipSlot.POWER, worn, null)
	Global.run_bag.clear()
	var bagged := _item("lattice_pulsecoil", 3, 0.1, 0.5)
	Global.run_bag.set_at(0, bagged)
	Global.meta_stash = StashInventory.new()
	var stashed := _item("curse_tithe_bones", 4, -0.2, 0.25, ItemInstance.Polarity.NEG)
	Global.meta_stash.set_item(0, stashed)
	var lens_mods_before: StatDelta = Global.item_db["conduit_lens"].mods.copy()
	var first_save := SaveData.new()
	var was_active := Global.attempt_active
	Global.attempt_active = true
	Global.write_save(first_save)
	Global.apply_save(first_save)
	var loaded_worn: ItemInstance = Global.run_inventory.get_at(ItemData.EquipSlot.POWER)
	var loaded_bag: ItemInstance = Global.run_bag.get_at(0)
	var loaded_stash: ItemInstance = Global.meta_stash.get_at(0)
	_check(loaded_worn != null and loaded_worn.rarity == 7 and _near(loaded_worn.upgrade_meter, 0.375, 0.000001) and _near(loaded_worn.best_pct, 0.25, 0.000001) and loaded_worn.locked and loaded_worn.manifestation_id == &"scar_tissue" and loaded_worn.polarity == ItemInstance.Polarity.POS, "a load preserves id, rank, meter, roll, polarity, lock and Manifestation exactly")
	_check(loaded_worn != null and _near(loaded_worn.rolled_mods.power, ItemScaling.flat_mods_at(Global.item_db["conduit_lens"], 7.375).power, 0.000001), "a loaded item's derived stats are recomputed from the profile")
	_check(loaded_bag != null and _near(loaded_bag.upgrade_meter, 0.5, 0.000001) and _near(loaded_bag.rolled_mods.max_hp, ItemScaling.flat_mods_at(Global.item_db["lattice_pulsecoil"], 3.5).max_hp, 0.000001), "bagged items keep their fractional meter and adopt the profile")
	_check(loaded_stash != null and loaded_stash.polarity == ItemInstance.Polarity.NEG and _near(loaded_stash.best_pct, -0.2, 0.000001) and _near(loaded_stash.rolled_mods.armor, ItemScaling.flat_mods_at(Global.item_db["curse_tithe_bones"], 4.25).armor, 0.000001), "stashed curses keep their roll and adopt the profile")
	var second_save := SaveData.new()
	Global.write_save(second_save)
	Global.apply_save(second_save)
	var third_save := SaveData.new()
	Global.write_save(third_save)
	var again: ItemInstance = Global.run_inventory.get_at(ItemData.EquipSlot.POWER)
	_check(again != null and again.rarity == 7 and _near(again.upgrade_meter, 0.375, 0.000001) and _near(again.rolled_mods.power, loaded_worn.rolled_mods.power, 0.000001) and third_save.attempt_inventory.get_at(ItemData.EquipSlot.POWER).upgrade_meter == again.upgrade_meter, "load/save/load is idempotent")
	# In memory a save holds the live containers; on disk each load creates
	# fresh resources. What must hold either way: the item definitions are
	# never written to by a rebuild.
	_check(Global.item_db["conduit_lens"].mods.equals(lens_mods_before) and again.rolled_mods != Global.item_db["conduit_lens"].mods, "rebuilding on load never writes to the item definition")
	Global.attempt_active = was_active
	Global.meta_stash = null
	player.free()
	print("ItemScalingV2Test: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
