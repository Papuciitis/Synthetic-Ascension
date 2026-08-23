extends Node

# Pins the NEG ecosystem: three archetypes that must genuinely DISAGREE about
# the same wardrobe. If they ever converge on one shopping list, cursed loot
# stops being a decision and becomes a stat, which is the failure this whole
# slice exists to prevent.
#
# Run: <godot> --headless --path . res://tools/tests/BurdenSystemTest.tscn

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


func _run() -> void:
	_test_deep_curses_exist()
	_test_curses_have_shapes_not_just_magnitudes()
	_test_snapshot_reads_polarity_and_severity()
	_test_inversion_suppresses_exactly_one()
	_test_archetypes_disagree()
	_test_suppressed_item_stays_neg()
	_test_drop_weighting()
	print("BurdenSystemTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _make_data(item_id: String, slot: int) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.display_name = item_id
	data.equip_slot = slot as ItemData.EquipSlot
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	return data


func _cursed(slot: int, severity: float) -> ItemInstance:
	var inst := ItemInstance.from_roll(
		_make_data("curse_%d_%d" % [slot, int(severity * 100.0)], slot),
		3, ItemInstance.Polarity.NEG, -severity, false
	)
	return inst


func _blessed(slot: int, roll: float) -> ItemInstance:
	return ItemInstance.from_roll(
		_make_data("bless_%d" % slot, slot), 3, ItemInstance.Polarity.POS, roll, false
	)


# ---------------------------------------------------------------------------

func _test_deep_curses_exist() -> void:
	# The choice "two catastrophes or six scratches" cannot exist until the
	# catastrophes do. Before these were authored, the worst curse in the game
	# was -50%, so every archetype valued the same items identically.
	var worst := 0.0
	var always_neg := true
	var authored := 0
	for id in Global.item_db.keys():
		var data: ItemData = Global.item_db[id] as ItemData
		if data == null or not String(data.id).begins_with("curse_"):
			continue
		authored += 1
		worst = minf(worst, data.pct_min)
		if data.pct_max > 0.0:
			always_neg = false
	_check(authored >= 4, "the game contains authored deep-curse items (%d)" % authored)
	_check(worst <= -0.75, "at least one curse is genuinely catastrophic (%.2f)" % worst)
	_check(always_neg, "an authored curse can never roll positive")

	# Severity is tuned per stat family: -95% Armour is survivable, -95% Max HP
	# or Move Speed is not a build, it is a death sentence.
	# Deepest curse per slot - several curses can share a slot now that shape
	# matters as much as magnitude.
	var by_slot: Dictionary = {}
	for id in Global.item_db.keys():
		var data: ItemData = Global.item_db[id] as ItemData
		if data == null or not String(data.id).begins_with("curse_"):
			continue
		var slot := int(data.equip_slot)
		by_slot[slot] = minf(float(by_slot.get(slot, 0.0)), data.pct_min)
	var move_floor: float = float(by_slot.get(2, -1.0))
	var hp_floor: float = float(by_slot.get(0, -1.0))
	var armour_floor: float = float(by_slot.get(1, 0.0))
	_check(move_floor > -0.6, "the movement curse is capped for playability (%.2f)" % move_floor)
	_check(hp_floor > -0.7, "the Max HP curse is capped for playability (%.2f)" % hp_floor)
	_check(armour_floor < move_floor, "a mitigation stat takes a far deeper cut than movement")


## The correction that matters most. A pool where every curse is "-X% stat"
## cannot support archetypes that disagree, because there is only one axis to
## disagree along. A curse whose SHAPE is a rate cap, a currency tax or a biased
## loot table is bad in a way no stat penalty can express - and is the only way
## one player's poison becomes another player's supply line.
func _test_curses_have_shapes_not_just_magnitudes() -> void:
	var shaped: PackedStringArray = PackedStringArray()
	var flat := 0
	for id in Global.item_db.keys():
		var data: ItemData = Global.item_db[id] as ItemData
		if data == null or not String(data.id).begins_with("curse_"):
			continue
		if not data.negative_effect_scenes.is_empty():
			shaped.append(String(data.id))
		else:
			flat += 1
	_check(shaped.size() >= 3, "several curses carry a BEHAVIOUR, not just a penalty (%s)" % ", ".join(shaped))
	_check(flat >= 3, "and several are still plain severity, so the two kinds coexist (%d)" % flat)

	# Those behaviours only exist if scripted effects can run outside the two
	# accessory slots - they could not until the runner was widened.
	var runner_slots: Array = ItemEffectRunner.new().watched_slots
	_check(
		runner_slots.size() >= Inventory.SLOT_COUNT,
		"scripted item effects run in every equipped slot (%d)" % runner_slots.size()
	)


func _test_snapshot_reads_polarity_and_severity() -> void:
	var inv := Inventory.new()
	inv.set_item(0, _cursed(0, 0.50))
	inv.set_item(1, _cursed(1, 0.20))
	inv.set_item(3, _blessed(3, 0.30))

	var snap := BurdenResolver.resolve(inv, [])
	_check(snap.neg_count == 2, "the snapshot counts NEG items (%d)" % snap.neg_count)
	_check(snap.pos_count == 1, "and POS items (%d)" % snap.pos_count)
	_check(is_equal_approx(snap.total_active, 0.70), "active burden totals (%.2f)" % snap.total_active)
	_check(is_equal_approx(snap.heaviest(1), 0.50), "the worst curse is first (%.2f)" % snap.heaviest(1))
	_check(is_equal_approx(snap.heaviest(2), 0.70), "and heaviest(2) sums the top two")
	_check(snap.qualifying_count == 2, "both curses clear the qualifying floor")

	# A curse too mild to matter must not qualify a count-based build.
	inv.set_item(4, _cursed(4, 0.02))
	var snap2 := BurdenResolver.resolve(inv, [])
	_check(snap2.neg_count == 3, "a trivial curse is still NEG")
	_check(snap2.qualifying_count == 2, "but does not qualify as a burden")


func _test_inversion_suppresses_exactly_one() -> void:
	var inv := Inventory.new()
	inv.set_item(0, _cursed(0, 0.30))
	inv.set_item(1, _cursed(1, 0.80))
	inv.set_item(2, _cursed(2, 0.40))

	var plain := BurdenResolver.resolve(inv, [])
	_check(plain.suppressed_slot == -1, "no suppression without the Lens")
	_check(plain.active_count == 3, "all three curses weigh on the player")

	var lensed := BurdenResolver.resolve(inv, [&"augment_inversion_lens"])
	_check(lensed.suppressed_slot == 1, "the Lens suppresses the MOST severe curse (slot %d)" % lensed.suppressed_slot)
	_check(is_equal_approx(lensed.suppressed_severity, 0.80), "and records what it was")
	_check(lensed.active_count == 2, "exactly one curse is suppressed, never all of them")
	_check(is_equal_approx(lensed.total_active, 0.70), "the suppressed curse contributes no burden")
	_check(
		BurdenResolver.inverted_return(0.80) < 0.80,
		"the conversion returns less than the curse took - a suppressed curse is worth carrying, never strictly better than a blessing"
	)


func _test_archetypes_disagree() -> void:
	# The whole point. Two wardrobes of identical TOTAL severity that the three
	# archetypes must value completely differently.
	var concentrated := Inventory.new()
	concentrated.set_item(0, _cursed(0, 0.80))
	concentrated.set_item(1, _cursed(1, 0.70))

	var spread := Inventory.new()
	for slot in range(5):
		spread.set_item(slot, _cursed(slot, 0.30))

	var conc := BurdenResolver.resolve(concentrated, [])
	var spr := BurdenResolver.resolve(spread, [])
	_check(
		is_equal_approx(conc.total_active, 1.50) and is_equal_approx(spr.total_active, 1.50),
		"both wardrobes carry identical total severity (%.2f / %.2f)" % [conc.total_active, spr.total_active]
	)

	# Corruption Engine reads the top two only.
	_check(
		conc.heaviest(2) > spr.heaviest(2),
		"Corruption Engine prefers the two catastrophes (%.2f vs %.2f)" % [conc.heaviest(2), spr.heaviest(2)]
	)
	# The Doctrine counts and never weighs.
	_check(
		spr.qualifying_count > conc.qualifying_count,
		"the Doctrine prefers the five scratches (%d vs %d)" % [spr.qualifying_count, conc.qualifying_count]
	)
	# The Lens wants one horror, so it gets more back from the concentrated set.
	var conc_lens := BurdenResolver.resolve(concentrated, [&"augment_inversion_lens"])
	var spr_lens := BurdenResolver.resolve(spread, [&"augment_inversion_lens"])
	_check(
		conc_lens.suppressed_severity > spr_lens.suppressed_severity,
		"the Lens prefers one horror (%.2f vs %.2f)" % [conc_lens.suppressed_severity, spr_lens.suppressed_severity]
	)

	# And the anti-synergy that makes the three a real choice rather than a
	# stack: suppressing your worst curse starves the Engine that ate it.
	_check(
		conc_lens.heaviest(2) < conc.heaviest(2),
		"a Lens and an Engine fight over the same curse (%.2f vs %.2f)" % [conc_lens.heaviest(2), conc.heaviest(2)]
	)


func _test_suppressed_item_stays_neg() -> void:
	# Polarity is what an item IS; active burden is what it is doing to you.
	# An inverted item must stay NEG for parity, sets and acquisition.
	var inv := Inventory.new()
	inv.set_item(0, _cursed(0, 0.90))
	inv.set_item(3, _blessed(3, 0.30))

	var snap := BurdenResolver.resolve(inv, [&"augment_inversion_lens"])
	_check(snap.neg_count == 1, "a suppressed item is still counted as NEG")
	_check(snap.active_count == 0, "while contributing no active burden")
	_check(snap.is_balanced(), "so exact POS/NEG parity still sees it")
	_check(
		inv.get_at(0).polarity == ItemInstance.Polarity.NEG,
		"and the item's own polarity is untouched"
	)


func _test_drop_weighting() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var curse_hits := 0
	var samples := 6000
	for _i in range(samples):
		var id := Global.pick_weighted_item_id(rng)
		if id.begins_with("curse_"):
			curse_hits += 1
	var rate := float(curse_hits) / float(samples)
	var uniform_rate := 0.0
	var curses := 0
	for id in Global.item_db.keys():
		if String(id).begins_with("curse_"):
			curses += 1
	if not Global.item_db.is_empty():
		uniform_rate = float(curses) / float(Global.item_db.size())
	print("  CURSE DROPS  weighted=%.3f  uniform would be=%.3f" % [rate, uniform_rate])
	_check(rate > 0.005, "a deep curse is findable (%.3f)" % rate)
	_check(rate < uniform_rate, "but rarer than an ordinary item, so it stays memorable")
