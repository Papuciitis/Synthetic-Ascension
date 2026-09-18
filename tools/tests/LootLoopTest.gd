extends Node

# Loot degenerate-loop pass (2026-09-19). Every Follower- or item-creating
# loop the item layer could offer, pinned on the real item database, the
# real pricing, the real merge law, the real bag consolidation and the real
# Ascension ledger:
#
#   1. Buyback never profits: the vendor's buy price for an instance is
#      above its sell price at every rank, roll and Luck.
#   2. Vendor buy -> merge -> sell never nets Followers on any real item at
#      the revision-2 curves (the AuditClosure fixture check, on the DB).
#   3. Bag auto-consolidation never creates sell value, in any order.
#   4. Ascension buy -> refund is neutral: the refund equals what was paid,
#      dependents included, sinks included, and a buy/refund cycle through
#      Global leaves the Followers exactly where they started.
#   5. The Hub's undo snapshot copies are worth exactly the originals.
#
# Run: <godot> --headless --path . --quit-after 3000 res://tools/tests/LootLoopTest.tscn

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


func _run() -> void:
	_test_buyback_never_profits()
	_test_vendor_merge_sell_is_lossy_on_real_items()
	_test_bag_consolidation_never_creates_value()
	_test_ascension_buy_refund_is_neutral()
	_test_undo_snapshots_keep_value()
	print("LootLoopTest: %d passed, %d failed" % [_passes, _failures])
	print("passes=%d failures=%d" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _item_ids() -> Array:
	var ids: Array = []
	for id in Global.item_db:
		if String(id) == "item_test":
			continue
		ids.append(String(id))
	ids.sort()
	return ids


func _rolls(data: ItemData) -> Array:
	var out: Array = [0.0]
	if data.pct_max > 0.0:
		out.append(data.pct_max)
		out.append(data.pct_max * 0.5)
	if data.pct_min < 0.0:
		out.append(data.pct_min)
	return out


func _instance(data: ItemData, rank: int, roll: float, meter: float = 0.0) -> ItemInstance:
	var polarity := ItemInstance.Polarity.NEG if roll < 0.0 else ItemInstance.Polarity.POS
	var inst := ItemInstance.from_roll(data, rank, polarity, roll, false)
	if meter > 0.0:
		inst.upgrade_meter = meter
		inst._recompute_flat_mods()
	return inst


# ---------------------------------------------------------------------------
# 1. Buyback
# ---------------------------------------------------------------------------

func _test_buyback_never_profits() -> void:
	var old_luck: float = Global.run_luck
	var worst_ratio := INF
	var worst_label := ""
	var checked := 0
	for id in _item_ids():
		var data: ItemData = Global.item_db[id]
		for rank in [0, 1, 3, 6, 10, 15, 30]:
			for roll in _rolls(data):
				for luck in [0.0, 25.0, 100.0, 100000.0]:
					Global.run_luck = luck
					var inst := _instance(data, rank, roll)
					var buy := Global.compute_buy_value(inst)
					var sell := Global.compute_sell_value(inst)
					checked += 1
					if sell > buy:
						worst_ratio = 0.0
						worst_label = "%s r%d roll %.2f luck %.0f" % [id, rank, roll, luck]
					elif buy > 0 and float(buy) / float(maxi(1, sell)) < worst_ratio:
						worst_ratio = float(buy) / float(maxi(1, sell))
						worst_label = "%s r%d roll %.2f luck %.0f (buy %d sell %d)" % [id, rank, roll, luck, buy, sell]
	Global.run_luck = old_luck
	_check(worst_ratio > 1.0, "selling and buying back the same item always loses (%d cases; tightest %s, x%.2f)" % [checked, worst_label, worst_ratio])


# ---------------------------------------------------------------------------
# 2. Vendor buy -> merge -> sell on every real item
# ---------------------------------------------------------------------------

func _test_vendor_merge_sell_is_lossy_on_real_items() -> void:
	var old_luck: float = Global.run_luck
	var worst := -INF
	var worst_label := ""
	var checked := 0
	var zero_cases := 0
	for id in _item_ids():
		var data: ItemData = Global.item_db[id]
		var rolls := _rolls(data)
		for dest_rank in [0, 1, 2, 3, 5, 8, 12, 15]:
			for dest_meter in [0.0, 0.5]:
				for dest_roll in rolls:
					for material_roll in rolls:
						if (dest_roll < 0.0) != (material_roll < 0.0):
							continue
						for material_rank in [maxi(0, dest_rank - 1), dest_rank, dest_rank + 1, dest_rank + 3]:
							for luck in [0.0, 100.0]:
								Global.run_luck = luck
								var dest := _instance(data, dest_rank, dest_roll, dest_meter)
								var material := _instance(data, material_rank, material_roll)
								var buy_cost := Global.compute_buy_value(material)
								var sell_before := Global.compute_sell_value(dest)
								if not dest.merge_from(material):
									continue
								var sell_after := Global.compute_sell_value(dest)
								var net := float(sell_after - sell_before - buy_cost)
								checked += 1
								if net == 0.0:
									zero_cases += 1
								if net > worst:
									worst = net
									worst_label = "%s dest r%d m%.1f roll %.2f + material r%d roll %.2f luck %.0f" % [id, dest_rank, dest_meter, dest_roll, material_rank, material_roll, luck]
	Global.run_luck = old_luck
	_check(worst <= 0.0, "no vendor buy -> merge -> sell sequence nets Followers on any real item (%d cases; %d break even to the Follower; worst %+.1f at %s)" % [checked, zero_cases, worst, worst_label])


# ---------------------------------------------------------------------------
# 3. Bag consolidation
# ---------------------------------------------------------------------------

func _bag_value(bag: BagInventory) -> int:
	var total := 0
	for inst in bag.slots:
		if inst != null:
			total += Global.compute_sell_value(inst)
	return total


func _test_bag_consolidation_never_creates_value() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260919
	var old_luck: float = Global.run_luck
	Global.run_luck = 0.0
	var ids := _item_ids()
	var worst := -INF
	var worst_label := ""
	var trials := 0
	for trial in range(60):
		var id: String = ids[rng.randi_range(0, ids.size() - 1)]
		var data: ItemData = Global.item_db[id]
		var pieces: Array[ItemInstance] = []
		var before := 0
		var count := rng.randi_range(2, 7)
		for i in range(count):
			var rank := rng.randi_range(0, 8)
			var roll := rng.randf_range(0.0, maxf(0.0, data.pct_max))
			var inst := _instance(data, rank, roll, rng.randf_range(0.0, 0.9))
			pieces.append(inst)
			before += Global.compute_sell_value(inst)
		var bag := BagInventory.new()
		bag._ensure_size()
		for inst in pieces:
			bag.add_instance(inst)
		var after := _bag_value(bag)
		trials += 1
		# Each merge rounds two prices into one; a single Follower per merge
		# is rounding, not a loop.
		var excess := (after - before) - (count - 1)
		if excess > worst:
			worst = excess
			worst_label = "%s x%d (%d -> %d)" % [id, count, before, after]
	Global.run_luck = old_luck
	_check(worst <= 0.0, "dropping same-id pieces into the bag in any order never raises their total sell value beyond one Follower of rounding per merge (%d trials; worst excess %+d at %s)" % [trials, int(worst), worst_label])


# ---------------------------------------------------------------------------
# 4. Ascension buy -> refund
# ---------------------------------------------------------------------------

func _test_ascension_buy_refund_is_neutral() -> void:
	var saved_state: Dictionary = Global.attempt_ascension.duplicate(true)
	var saved_followers := int(Global.followers)
	Global.attempt_ascension = AscensionLedger.fresh_state("melee")
	var ledger := Global.ascension_ledger()
	var start := 100000
	Global.followers = start
	# EX02 sits beside the Core and depends on nothing, so the sink's
	# four-local requirement survives the Spillover refund below.
	var chain := ["EX01", "EX02", "EX03", "EX04", "EX07", "EX09"]
	var spent := 0
	for id in chain:
		var verdict: Dictionary = Global.ascension_buy(id)
		_check(bool(verdict.get("ok", false)), "fixture: %s bought (%s)" % [id, String(verdict.get("reason", ""))])
		spent += int(verdict.get("cost", 0))
	var sink_paid := 0
	for i in range(3):
		var verdict: Dictionary = Global.ascension_buy("EXS1")
		_check(bool(verdict.get("ok", false)), "fixture: sink rank %d bought (%s)" % [i + 1, String(verdict.get("reason", ""))])
		sink_paid += int(verdict.get("cost", 0))
	spent += sink_paid
	_check(int(Global.followers) == start - spent and int(ledger.state.get("spent", 0)) == spent, "the ledger and the wallet agree on %d spent" % spent)
	var back_ex03 := Global.ascension_refund("EX03")
	_check(back_ex03 == 800 and not ledger.owns("EX07"), "refunding Spillover returns its 400 and Reservoir's 400 (%d) and removes the dependent" % back_ex03)
	_check(int(Global.followers) == start - spent + 800, "and the wallet gets exactly that back")
	var back_sink := Global.ascension_refund("EXS1")
	_check(back_sink == sink_paid, "refunding the sink returns every rank's price (%d of %d)" % [back_sink, sink_paid])
	var back_root := Global.ascension_refund("EX01")
	_check(not ledger.owns("EX04") and not ledger.owns("EX09") and ledger.owns("EX02"), "refunding Finish takes Bloodletting and Elite Sentence with it and leaves Mark, which never needed it")
	_check(back_root == spent - 800 - sink_paid - 200, "the root refund is the rest of what was paid except Mark's 200, no more (%d)" % back_root)
	Global.ascension_refund("EX02")
	_check(int(Global.followers) == start, "after refunding everything the wallet is exactly where it started (%d)" % int(Global.followers))
	_check(int(ledger.state.get("spent", 0)) == 0 and ledger.owned_ids().size() == 1, "and the ledger holds only the Core again (spent 0, refunded %d)" % int(ledger.state.get("refunded", 0)))
	for cycle in range(25):
		Global.ascension_buy("EX01")
		Global.ascension_buy("EX04")
		Global.ascension_refund("EX01")
	_check(int(Global.followers) == start, "25 buy/refund cycles create nothing (%d)" % int(Global.followers))
	Global.attempt_ascension = saved_state
	Global.ascension_ledger()
	Global.followers = saved_followers


# ---------------------------------------------------------------------------
# 5. Undo snapshots
# ---------------------------------------------------------------------------

func _test_undo_snapshots_keep_value() -> void:
	var ok := true
	var checked := 0
	for id in _item_ids():
		var data: ItemData = Global.item_db[id]
		for rank in [0, 4, 15]:
			for roll in _rolls(data):
				var inst := _instance(data, rank, roll, 0.37)
				inst.locked = rank == 4
				var copy := inst.snapshot_copy()
				checked += 1
				if Global.compute_item_value(copy) != Global.compute_item_value(inst) or copy.locked != inst.locked or copy.manifestation_id != inst.manifestation_id or not is_equal_approx(copy.upgrade_meter, inst.upgrade_meter):
					ok = false
	_check(ok, "a Hub undo snapshot is worth exactly the original, lock and meter included (%d cases)" % checked)
