extends Node

# Upgrade effort and benefit against the real containers, router, merge
# path and hub shop: a compatible auto-feed that moves only the meter, a
# manual merge, bag and stash feeds, a higher-rank incoming swap, a vendor
# offer that is not an acquisition, a completed purchase and its undo. Every
# recorded number is compared with the containers' own state, and the
# instrumentation is checked to reroll nothing, keep the destination's rule
# and lock, consume exactly one item per merge and leave stats alone.
#
# Run: <godot> --headless --path . res://tools/tests/BalanceUpgradeDiagnosticsTest.tscn

const PLAYER := preload("res://core/actors/player/player.tscn")
const HUB_SHOP: PackedScene = preload("res://ui/screens/HubShop.tscn")

var _passes := 0
var _failures := 0
var _records: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _make_data(item_id: String, slot: int) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.display_name = item_id
	data.equip_slot = slot as ItemData.EquipSlot
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	data.rarity_base.power = 1.0
	return data


func _make_item(data: ItemData, rarity: int = 0, pct: float = 0.5) -> ItemInstance:
	# roll_manifestation=false: fixtures must not consume Global RNG state.
	return ItemInstance.from_roll(data, rarity, ItemInstance.Polarity.POS, pct, false)


func _on_operation(kind: StringName, inst: ItemInstance, data: Dictionary) -> void:
	var copy := data.duplicate(true)
	copy["kind"] = String(kind)
	copy["inst"] = inst
	_records.append(copy)


func _last(kind: String) -> Dictionary:
	for index in range(_records.size() - 1, -1, -1):
		if String(_records[index].kind) == kind:
			return _records[index]
	return {}


func _count(kind: String) -> int:
	var n := 0
	for record in _records:
		if String(record.kind) == kind:
			n += 1
	return n


func _stats_of(player: Node) -> Dictionary:
	var stats: Resource = player.get("stats")
	var result := {}
	for field in ["max_hp", "armor", "move_speed", "power", "haste", "luck"]:
		result[field] = stats.get(field)
	return result


func _run() -> void:
	var recorder := get_node_or_null("/root/BalanceRecorder")
	_check(recorder != null, "runtime balance recorder is installed")
	if recorder == null:
		_finish()
		return
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.debug_player_god_mode = false
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.run_luck = 0.0
	Global.set_followers(100000)
	Global.meta_stash = StashInventory.new()
	var player = PLAYER.instantiate()
	add_child(player)
	await get_tree().process_frame
	player.set_process(false)
	player.set_physics_process(false)
	player.stats = Stats.new()
	var dir := "user://balance_upgrade_test_%s" % Time.get_ticks_usec()
	recorder.report_directory = dir
	recorder.record_headless = true
	recorder.begin_gameplay(player)
	recorder.set_process(false)
	RunEvents.item_operation.connect(_on_operation)
	_check(recorder.is_recording() and bool(recorder.get_summary().metadata.features.progression), "explicit headless capture starts with progression measured")
	var inventory: Inventory = Global.run_inventory
	var bag: BagInventory = Global.run_bag
	var upgrades: Dictionary = recorder._ledger._current.upgrades

	# A prepared fixture: equipped through a debug scope, so it is never
	# earned progression.
	var alpha := _make_data("alpha", ItemData.EquipSlot.POWER)
	# Worn at rank 1 so a rank-0 feed pays the gap and moves only the meter.
	var worn := _make_item(alpha, 1, 0.4)
	worn.manifestation_id = &"scar_tissue"
	var op := BalanceItemContext.begin(&"debug", {"tool": "test"})
	inventory.set_item(ItemData.EquipSlot.POWER, worn, null)
	BalanceItemContext.end(op)
	var equipped_record := _last("equipped")
	_check(String(equipped_record.get("source", "")) == "debug" and int(equipped_record.get("op", 0)) == op and int(upgrades.acquired.get("debug", 0)) == 1 and int(upgrades.debug_operations) == 1, "a debug grant is recorded under its own source with its operation id")

	# 1. A compatible ground pickup auto-feeds the worn copy: one merge that
	# moves only the fractional meter, with exact before/after values.
	var material := _make_item(alpha, 0, 0.0)
	op = BalanceItemContext.begin(&"pickup", {"pickup": "ground"})
	var fed: bool = inventory.add_or_feed(material, {"type": 1, "pos": Vector2.ZERO})
	BalanceItemContext.end(op)
	var merged := _last("merged")
	_check(fed and _count("merged") == 1 and merged.inst == worn, "an auto-feed reports exactly one merge on the worn instance")
	_check(float(merged.dest_before.meter) == 0.0 and float(merged.dest_after.meter) == worn.upgrade_meter and worn.upgrade_meter > 0.0 and worn.upgrade_meter < 1.0 and int(merged.dest_after.rarity) == 1 and not bool(merged.ranked_up), "the merge carries the exact meter before/after and no rank change (meter %.4f)" % worn.upgrade_meter)
	_check(String(merged.container.kind) == "equipped" and int(merged.container.slot) == ItemData.EquipSlot.POWER and String(merged.source) == "pickup" and int(merged.incoming.rarity) == 0 and float(merged.incoming.pct) == 0.0 and float(merged.mass) > 0.0, "the merge names its container, source, consumed material and mass")
	_check(int(upgrades.merges) == 1 and int(upgrades.merges_by_container.get("equipped", 0)) == 1 and absf(float(upgrades.meter_gained_equipped) - worn.upgrade_meter) < 0.000001 and int(upgrades.rank_ups_equipped) == 0 and int(upgrades.acquired.get("pickup", 0)) == 1, "the ledger counts the feed once as a pickup acquisition with the meter it added")
	_check(float(merged.dest_after.flat.power) > float(merged.dest_before.flat.power), "flat contributions before and after come from the instance's own mods")

	# 2. A manual merge through the router: the bag copy is dragged onto its
	# worn duplicate. A player move, not an acquisition.
	var spare := _make_item(alpha, 0, 0.0)
	op = BalanceItemContext.begin(&"pickup", {"pickup": "ground"})
	bag.add_instance(spare)
	BalanceItemContext.end(op)
	var spare_slot := -1
	for index in range(bag.get_slot_count()):
		if bag.get_at(index) == spare:
			spare_slot = index
	var acquired_before: int = int(upgrades.acquired_total)
	var meter_before_manual: float = worn.upgrade_meter
	_check(InvRouter.equip_from_bag(bag, spare_slot, inventory, null), "the router merges the bag copy into the worn one")
	merged = _last("merged")
	_check(_count("merged") == 2 and String(merged.source) == "player" and String(merged.container.kind) == "equipped" and float(merged.dest_before.meter) == meter_before_manual and float(merged.dest_after.meter) == worn.upgrade_meter, "the manual merge is recorded once with the player source and exact meters")
	_check(int(upgrades.acquired_total) == acquired_before and int(upgrades.merges) == 2 and bag.get_at(spare_slot) == null, "a player-driven merge is not an acquisition and consumed exactly the bag copy")

	# 3. Bag feed: a second copy of an unrelated item merges into its stack.
	var beta := _make_data("beta", ItemData.EquipSlot.ARMOR)
	op = BalanceItemContext.begin(&"pickup", {"pickup": "drop"})
	bag.add_instance(_make_item(beta, 0, 0.6))
	bag.add_instance(_make_item(beta, 0, 0.2))
	BalanceItemContext.end(op)
	merged = _last("merged")
	var beta_stacks := 0
	for index in range(bag.get_slot_count()):
		var stack: ItemInstance = bag.get_at(index)
		if stack != null and stack.data == beta:
			beta_stacks += 1
	_check(beta_stacks == 1 and String(merged.container.kind) == "bag" and int(upgrades.merges_by_container.get("bag", 0)) == 1 and int(upgrades.acquired.get("pickup", 0)) == 4, "a bag feed is recorded in the bag with both copies counted as pickups (%d pickups)" % int(upgrades.acquired.get("pickup", 0)))

	# 4. Stash: moving the beta stack to the stash is a move, not an acquisition.
	var beta_slot := -1
	for index in range(bag.get_slot_count()):
		var stack: ItemInstance = bag.get_at(index)
		if stack != null and stack.data == beta:
			beta_slot = index
	acquired_before = int(upgrades.acquired_total)
	_check(InvRouter.move_between(bag, beta_slot, Global.meta_stash, 0, null) and Global.meta_stash.get_at(0) != null, "the router moves the stack to the stash")
	_check(_count("stashed") == 1 and String(_last("stashed").source) == "player" and int(upgrades.stashed) == 1 and int(upgrades.moves) >= 1 and int(upgrades.acquired_total) == acquired_before, "a stash move is recorded as a move, never an acquisition")

	# 5. A higher-rank incoming copy: the worn instance keeps its identity,
	# rule and lock while the rank swaps to it.
	var strong := _make_item(alpha, 2, 0.7)
	var rarity_before: int = worn.rarity
	op = BalanceItemContext.begin(&"pickup", {"pickup": "drop"})
	fed = inventory.add_or_feed(strong, {"type": 1, "pos": Vector2.ZERO})
	BalanceItemContext.end(op)
	merged = _last("merged")
	_check(fed and merged.inst == worn and int(merged.dest_before.rarity) == rarity_before and int(merged.incoming.rarity) == 2 and int(merged.dest_after.rarity) == worn.rarity and worn.rarity >= 2 and bool(merged.swapped) and bool(merged.ranked_up), "a higher-rank incoming swap is recorded with the pre-swap material and the rank it produced (%d -> %d)" % [rarity_before, worn.rarity])
	_check(int(upgrades.rank_ups_equipped) == 1 and upgrades.rank_up_times.size() == 1 and int(upgrades.swaps_equipped) == 1 and inventory.get_at(ItemData.EquipSlot.POWER) == worn, "the rank-up is counted on the equipped item with its gameplay time")
	_check(worn.manifestation_id == &"scar_tissue" and not worn.locked and String(merged.dest_after.manifestation) == "scar_tissue", "instrumentation never changes the destination's rule or lock")
	# The player recomputes: the pending equipment operations link to the
	# stats and set ranks after them.
	RunEvents.player_stats_recomputed.emit(player)
	var linked := false
	var pending: Array = recorder._ledger._records
	for record in pending:
		if String(record.kind) == "upgrade_effect" and int(record.data.get("op", -1)) == int(merged.op):
			linked = record.data.has("stats_after") and record.data.has("sets_after") and int(record.data.build_after) >= int(record.data.build_before)
	_check(linked, "an equipped upgrade links before/after stat snapshots and set ranks after the recompute")

	# 6. The real hub shop: the stock is offered (not acquired), one purchase
	# is acquired with its own value inside the transaction, and the undo
	# reverses it without counting twice while the wallet reconciles.
	var shop := HUB_SHOP.instantiate()
	add_child(shop)
	await get_tree().process_frame
	await get_tree().process_frame
	var offered_count: int = int(upgrades.generated.offered)
	var vendor_slot := -1
	for index in range(shop._vendor_bag.slots.size()):
		if shop._vendor_bag.slots[index] != null:
			vendor_slot = index
			break
	_check(offered_count >= 1 and vendor_slot >= 0 and int(upgrades.acquired.get("trade", 0)) == 0, "vendor stock is recorded as %d offers and no acquisition" % offered_count)
	var offered: ItemInstance = shop._vendor_bag.slots[vendor_slot]
	var buy_value: int = Global.compute_buy_value(offered)
	var followers_before: int = Global.followers
	shop._on_vendor_slot_clicked(vendor_slot, MOUSE_BUTTON_LEFT, false, false, false)
	shop._perform_trade()
	var purchased := _last("purchased")
	_check(not purchased.is_empty() and purchased.inst == offered and int(purchased.value) == buy_value and String(purchased.source) == "trade" and Global.followers == followers_before - buy_value, "a completed purchase records the item and its value under the trade (%d Followers)" % buy_value)
	_check(int(upgrades.purchased) == 1 and int(upgrades.purchase_value) == buy_value and int(upgrades.acquired.get("trade", 0)) == 1, "the purchase is one trade acquisition")
	var transaction := {}
	for record in recorder._ledger._records:
		if String(record.kind) == "transaction" and String(record.data.reason) == "trade":
			transaction = record.data
	_check(not transaction.is_empty() and int(transaction.context.op) == int(purchased.op) and transaction.context.items.size() == 1 and int(transaction.context.items[0].value) == buy_value and int(transaction.change) == -buy_value, "the item-level value rides inside the wallet transaction with the operation id")
	shop._undo_last_trade()
	var undo := _last("undo")
	_check(not undo.is_empty() and int(undo.undoes) == int(purchased.op) and int(undo.bought_count) == 1 and Global.followers == followers_before and shop._vendor_bag.slots[vendor_slot] != null, "the undo is tied to the trade it reverses and restores the wallet and the shelf")
	var summary: Dictionary = recorder.get_summary()
	_check(int(upgrades.undone_purchases) == 1 and int(summary.upgrades.net_purchases) == 0 and int(upgrades.acquired.get("trade", 0)) == 1, "an undone purchase is not counted twice: one purchase, net zero")
	var t: Dictionary = summary.totals
	_check(t.followers_open + t.followers_earned - t.followers_spent + t.followers_adjustments + t.followers_debug == t.followers_close and int(summary.wallet_discontinuities) == 0, "the wallet still reconciles through the undo")
	_check(summary.upgrades.get("shop_cost_in_minutes") == null and summary.upgrades.get("organic_income_per_minute") == null, "with no organic income the time to afford is unavailable, not zero")

	# Purity: reporting rerolled nothing and changed no stats.
	var rng_state: int = Global._rng.state
	var stats_before := _stats_of(player)
	recorder._capture_build()
	recorder._capture_sample()
	recorder.get_summary()
	_check(Global._rng.state == rng_state, "instrumentation and reports never consume the run RNG")
	_check(_stats_of(player) == stats_before, "reports never apply a preview to the player's stats")

	var capture_path: String = recorder.capture_directory
	recorder.end_capture("suspended")
	recorder.flush_reports()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(capture_path.path_join("summary.json")))
	_check(saved is Dictionary and int(saved.upgrades.net_purchases) == 0 and int(saved.totals.upgrades.merges) == 4 and bool(saved.metadata.features.progression), "the saved summary carries the upgrade block")
	var report := FileAccess.get_file_as_string(capture_path.path_join("report.md"))
	_check(report.contains("## Upgrade effort and benefit") and report.contains("Compatible drops"), "the report explains upgrade effort")
	RunEvents.item_operation.disconnect(_on_operation)
	shop.queue_free()
	player.free()
	Global.meta_stash = null
	for name in ["events.jsonl", "summary.json", "report.md", "segments.csv"]:
		DirAccess.remove_absolute(capture_path.path_join(name))
	DirAccess.remove_absolute(capture_path)
	_finish()


func _finish() -> void:
	print("BalanceUpgradeDiagnosticsTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
