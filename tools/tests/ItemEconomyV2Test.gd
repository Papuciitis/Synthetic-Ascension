extends Node

# Balance plan Task 5: merge effort and market prices (section 5).
#   5.1  GAP_HALF_LIFE 3.0 for mass and overflow; R0 into R6 at quality 1
#        gives mass 0.25; overflow keeps 2^(-1/3) of the excess.
#   5.2  rank_price(r) = 26 + 14r + r^2; a meter is the exact lerp to the
#        next rank (R6 146, R7 173, half-filled R6 159.5); one helper prices
#        both endpoints; stat weights; prices monotone and continuous.
#   Arbitrage: a set of purchased inputs merged in any order never sells for
#        more than it cost (LootLoopTest covers the DB; here the repeated
#        merge and the carrier paths), and the carrier path is reported.
#   Auto-swap keeps the destination's Manifestation.
#
# Run: <godot> --headless --path . --quit-after 3000 res://tools/tests/ItemEconomyV2Test.tscn

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _near(a: float, b: float, tolerance: float = 0.000001) -> bool:
	return absf(a - b) <= tolerance


func _fixture(with_stats: bool = false, set_id: String = "") -> ItemData:
	var data := ItemData.new()
	data.id = "economy_fixture"
	data.pct_min = -1.0
	data.pct_max = 1.0
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	data.set_id = set_id
	if with_stats:
		data.mods.max_hp = 10.0
		data.mods.armor = 5.0
		data.mods.move_speed = 4.0
		data.mods.power = 0.1
		data.mods.haste = 0.2
		data.mods.luck = 1.0
	return data


func _item(data: ItemData, rank: int, roll: float, meter: float = 0.0) -> ItemInstance:
	var polarity := ItemInstance.Polarity.NEG if roll < 0.0 else ItemInstance.Polarity.POS
	var inst := ItemInstance.from_roll(data, rank, polarity, roll, false)
	inst.upgrade_meter = meter
	inst._recompute_flat_mods()
	return inst


func _run() -> void:
	_test_merge_law()
	_test_prices()
	_test_repeated_merges_never_profit()
	_test_carrier_path_report()
	_test_auto_swap_keeps_manifestation()
	print("ItemEconomyV2Test: %d passed, %d failed" % [_passes, _failures])
	print("passes=%d failures=%d" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_merge_law() -> void:
	_check(is_equal_approx(RarityMath.GAP_HALF_LIFE, 3.0), "the gap half-life is three ranks")
	_check(_near(RarityMath.merge_mass(0, 6, 1.0), 0.25), "quality 1, R0 into R6: mass 0.25")
	_check(_near(RarityMath.merge_mass(6, 6, 1.0), 1.0) and _near(RarityMath.merge_mass(3, 6, 1.0), 0.5), "equal rank keeps a full peer, three ranks under keeps half")
	_check(_near(RarityMath.merge_mass(6, 0, 1.0), 4.0), "the law is symmetric in the gap (a higher incoming swaps first, so this only shapes overflow)")
	_check(_near(RarityMath.overflow_factor(), pow(2.0, -1.0 / 3.0)), "overflow keeps 2^(-1/3) of the excess")
	var data := _fixture()
	# quality = 0.75 + 0.5 * |roll| / extreme, so roll 0.5 is quality 1.
	var dest := _item(data, 6, 0.5)
	_check(dest.merge_from(_item(data, 0, 0.5)), "fixture: an R0 feeds an R6")
	_check(_near(dest.upgrade_meter, 0.25) and dest.rarity == 6, "and lands as a quarter of the meter (%.4f)" % dest.upgrade_meter)
	var crossing := _item(data, 3, 0.5, 0.9)
	crossing.merge_from(_item(data, 3, 0.5))
	_check(crossing.rarity == 4 and _near(crossing.upgrade_meter, 0.9 * pow(2.0, -1.0 / 3.0)), "a crossing keeps 2^(-1/3) of the excess meter (R4 at %.4f)" % crossing.upgrade_meter)
	var locked := _item(data, 2, 0.5)
	locked.locked = true
	_check(not locked.merge_from(_item(data, 2, 0.5)), "locks still refuse merges")
	_check(not _item(data, 2, 0.5).merge_from(_item(data, 2, -0.5)), "polarities still never merge")
	var swap := _item(data, 1, 0.2)
	swap.merge_from(_item(data, 4, 0.2))
	_check(swap.rarity == 4 and swap.upgrade_meter > 0.0, "a higher incoming still swaps in and leaves the lower as fractional material (R%d at %.4f)" % [swap.rarity, swap.upgrade_meter])


func _test_prices() -> void:
	_check(_near(RarityMath.rank_price(0), 26.0) and _near(RarityMath.rank_price(1), 41.0) and _near(RarityMath.rank_price(6), 146.0) and _near(RarityMath.rank_price(7), 173.0), "rank prices: R0 26, R1 41, R6 146, R7 173")
	_check(_near(RarityMath.fractional_rank_price(6, 0.5), 159.5), "a half-filled R6 is worth 159.5")
	_check(_near(RarityMath.fractional_rank_price(6, 0.0), RarityMath.rank_price(6)) and _near(RarityMath.fractional_rank_price(6, 1.0), RarityMath.rank_price(7)), "both endpoints come from the same helper")
	var data := _fixture()
	# |roll| 0.2 of extreme 1.0 makes the quality factor exactly 1.0.
	_check(Global.compute_item_value(_item(data, 6, 0.2)) == 146 and Global.compute_item_value(_item(data, 7, 0.2)) == 173, "a stat-less R6 / R7 at quality 1 sells to the market at 146 / 173")
	_check(Global.compute_item_value(_item(data, 6, 0.2, 0.5)) == 160, "and a half-filled R6 rounds 159.5 to 160")
	var monotone := true
	var continuous := true
	var previous := -1
	for rank in range(0, 31):
		for step in range(0, 10):
			var value := Global.compute_item_value(_item(data, rank, 0.2, float(step) / 10.0))
			if value < previous:
				monotone = false
			previous = value
		if absi(Global.compute_item_value(_item(data, rank, 0.2, 0.999999)) - Global.compute_item_value(_item(data, rank + 1, 0.2))) > 1:
			continuous = false
	_check(monotone, "value never falls as rank or meter rises, R0 to R30")
	_check(continuous, "and a nearly full meter is worth the next rank to the Follower")
	var bare := Global.compute_item_value(_item(_fixture(), 2, 0.2))
	var stats := _item(_fixture(true), 2, 0.2)
	var m := stats.rolled_mods
	var expected_stats := absf(m.max_hp) * 0.30 + absf(m.armor) * 0.80 + absf(m.move_speed) * 0.35 + absf(m.power) * 60.0 + absf(m.haste) * 50.0 + absf(m.luck) * 35.0
	_check(absi(Global.compute_item_value(stats) - bare - int(round(expected_stats))) <= 1, "stat weights HP 0.30, armour 0.80, movement 0.35, Power 60, Haste 50, Luck 35 (%d over bare %d)" % [Global.compute_item_value(stats) - bare, bare])
	_check(Global.compute_item_value(_item(_fixture(false, "conduit"), 2, 0.2)) == int(round(float(bare) * 1.15)), "the set premium is still 1.15")
	_check(Global.compute_item_value(_item(data, 2, 1.0)) == int(round(RarityMath.rank_price(2) * 1.4)) and Global.compute_item_value(_item(data, 2, -1.0)) == Global.compute_item_value(_item(data, 2, 1.0)), "quality still runs 0.9 to 1.4 on |roll| for either polarity")


func _test_repeated_merges_never_profit() -> void:
	var old_luck: float = Global.run_luck
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var worst := -INF
	var worst_label := ""
	var trials := 0
	for id in Global.item_db:
		if String(id) == "item_test":
			continue
		var data: ItemData = Global.item_db[id]
		for luck in [0.0, 100000.0]:
			Global.run_luck = luck
			for trial in range(6):
				var count := rng.randi_range(2, 6)
				var pieces: Array[ItemInstance] = []
				var cost := 0
				for i in range(count):
					var rank := rng.randi_range(0, 30)
					var roll := (data.pct_max if rng.randf() < 0.5 else data.pct_max * rng.randf()) if data.pct_max > 0.0 else 0.0
					var inst := ItemInstance.from_roll(data, rank, ItemInstance.Polarity.POS, roll, false)
					inst.upgrade_meter = rng.randf_range(0.0, 0.95)
					inst._recompute_flat_mods()
					cost += Global.compute_buy_value(inst)
					pieces.append(inst)
				pieces.shuffle()
				var dest: ItemInstance = pieces[0]
				for i in range(1, pieces.size()):
					dest.merge_from(pieces[i])
				var sale := Global.compute_sell_value(dest)
				trials += 1
				if sale - cost > worst:
					worst = sale - cost
					worst_label = "%s x%d luck %.0f (cost %d, sold %d)" % [id, count, luck, cost, sale]
	Global.run_luck = old_luck
	_check(worst < 0.0, "buying inputs and merging them in any order never sells for more than they cost (%d trials; worst %+d at %s)" % [trials, int(worst), worst_label])


func _test_carrier_path_report() -> void:
	# Section 5: the equal-quality, same-rank carrier case must match direct
	# feeding; rank crossings, mixed qualities and orders are reported, not
	# forced. What must hold is that no path is worth more Followers.
	var data := _fixture()
	# Two R5 peers at quality 1 fill the meter exactly; the carrier's banked
	# 0.4 is the only excess, and it crosses at the overflow ratio.
	var same := _item(data, 5, 0.5)
	same.merge_from(_item(data, 5, 0.5, 0.4))
	var direct := _item(data, 5, 0.5)
	direct.merge_from(_item(data, 5, 0.5))
	_check(direct.rarity == 6 and _near(direct.upgrade_meter, 0.0), "fixture: two equal peers at quality 1 land exactly on the next rank")
	_check(same.rarity == 6 and _near(same.upgrade_meter, RarityMath.merge_mass(5, 5, 0.4) * RarityMath.overflow_factor()), "an equal-rank carrier's banked meter transfers at full mass and crosses at the overflow ratio (%.4f)" % same.upgrade_meter)
	var worst_meter := 0.0
	var worst_value := 0
	var report: Array[String] = []
	for dest_rank in [3, 5, 8, 12]:
		for low_rank in [0, 1, 2]:
			for quality_roll in [0.0, 0.5, 1.0]:
				var direct_dest := _item(data, dest_rank, 0.5)
				direct_dest.merge_from(_item(data, low_rank, quality_roll))
				direct_dest.merge_from(_item(data, low_rank, quality_roll))
				var carrier := _item(data, low_rank, quality_roll)
				carrier.merge_from(_item(data, low_rank, quality_roll))
				var carrier_dest := _item(data, dest_rank, 0.5)
				carrier_dest.merge_from(carrier)
				var direct_eff := float(direct_dest.rarity) + direct_dest.upgrade_meter
				var carrier_eff := float(carrier_dest.rarity) + carrier_dest.upgrade_meter
				var value_gap := Global.compute_sell_value(carrier_dest) - Global.compute_sell_value(direct_dest)
				worst_meter = maxf(worst_meter, carrier_eff - direct_eff)
				worst_value = maxi(worst_value, value_gap)
				report.append("dest R%d + 2 x R%d roll %.1f: direct %.4f, carrier %.4f, sell gap %+d" % [dest_rank, low_rank, quality_roll, direct_eff, carrier_eff, value_gap])
	for line in report:
		print("[carrier] ", line)
	_check(worst_value <= 1, "pre-merging low ranks into a carrier is worth at most one Follower of rounding more than feeding them directly (worst %+d; largest effective-rank gain %.4f)" % [worst_value, worst_meter])


func _test_auto_swap_keeps_manifestation() -> void:
	var data := _fixture()
	var low := _item(data, 1, 0.5)
	low.manifestation_id = &"momentum"
	var high := _item(data, 4, 0.5)
	high.manifestation_id = &""
	_check(low.merge_from(high) and low.rarity == 4 and low.manifestation_id == &"momentum", "a higher-rank auto-swap keeps the destination's Manifestation")
	var other := _item(data, 4, 0.5)
	other.manifestation_id = &"stability"
	_check(not low.can_absorb_manifestation_of(other), "and a differing Manifestation is still refused by the containers' absorb rule")
