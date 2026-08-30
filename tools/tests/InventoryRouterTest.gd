extends Node

# Audit 2026-08-28 (test coverage gaps), HIGH row 1 / Top-15 gap #1:
# InventoryRouter (autoload InvRouter) is the single choke point for every
# equip/bag/stash/drop move in the game (BagUI, InventoryBar, HubShop, hud.gd,
# InventoryStash, WorldDropSpawner - 7 production call sites) and had zero
# tests; item loss or duplication would be invisible to the suite.
#
# Pins the routing behaviour the player relies on, using the exact call
# shapes of the production callers:
#   - equip_from_bag(bag, i, inv)            (BagUI.gd:368)
#   - eject_equipped_to_bag(slot, origin)    (InventoryBar.gd:311)
#   - move_between(src, i, dst, j, null)     (HubShop.gd:832/856/878,
#                                             InventoryStash.gd:509/528/553)
#   - drop_from(inv_or_bag, slot, mouse)     (InventoryBar.gd:319, BagUI.gd:303)
#   - dropped_to_world -> world spawner stub (WorldDropSpawner.gd:28)
# After every operation the conservation invariant is asserted: the total
# number of instances across equip + bag + stash + world stub is constant
# (or drops by exactly one on a deliberate same-id feed, with the feed
# visible as progress on the surviving instance).

var _passes := 0
var _failures := 0

# World-drop stub: stands in for WorldDropSpawner, which only listens to
# dropped_to_world and spawns a pickup for the handed instance.
var _world_drops: Array = [] # [[ItemInstance, Vector2], ...]
var _routed: Array = []      # [[StringName, ItemInstance, Dictionary], ...]

var _saved_equipped: Inventory = null
var _saved_bag: Object = null


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


# ---------------------------------------------------------------------------
# Fixtures (same shape as BuildIdentityTest._make_data)
# ---------------------------------------------------------------------------

func _make_data(item_id: String, slot: int) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.display_name = item_id
	data.equip_slot = slot as ItemData.EquipSlot
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	return data


func _make_item(item_id: String, slot: int, rarity: int = 0, pol: int = ItemInstance.Polarity.POS) -> ItemInstance:
	# roll_manifestation=false: fixtures must not consume Global RNG state.
	return ItemInstance.from_roll(_make_data(item_id, slot), rarity, pol, 0.5, false)


func _fill_bag(bag: BagInventory, from_slot: int = 0) -> void:
	# Distinct ids so BagInventory auto-consolidation never merges fillers.
	for i in range(from_slot, bag.get_slot_count()):
		if bag.get_at(i) == null:
			bag.set_at(i, _make_item("filler_%d" % i, ItemData.EquipSlot.NONE))


func _bag_find(bag: BagInventory, inst: ItemInstance) -> int:
	for i in range(bag.get_slot_count()):
		if bag.get_at(i) == inst:
			return i
	return -1


func _total(inv: Inventory, bag: BagInventory, stash: StashInventory = null) -> int:
	var n: int = _world_drops.size()
	if inv != null:
		for i in range(Inventory.SLOT_COUNT):
			if inv.get_at(i) != null:
				n += 1
	if bag != null:
		for i in range(bag.get_slot_count()):
			if bag.get_at(i) != null:
				n += 1
	if stash != null:
		for i in range(stash.slot_count):
			if stash.get_at(i) != null:
				n += 1
	return n


func _occurrences(target: ItemInstance, inv: Inventory, bag: BagInventory, stash: StashInventory = null) -> int:
	var n := 0
	if inv != null:
		for i in range(Inventory.SLOT_COUNT):
			if inv.get_at(i) == target:
				n += 1
	if bag != null:
		for i in range(bag.get_slot_count()):
			if bag.get_at(i) == target:
				n += 1
	if stash != null:
		for i in range(stash.slot_count):
			if stash.get_at(i) == target:
				n += 1
	for entry in _world_drops:
		if entry[0] == target:
			n += 1
	return n


func _on_dropped(inst: ItemInstance, world_pos: Vector2) -> void:
	_world_drops.append([inst, world_pos])


func _on_routed(action: StringName, inst: ItemInstance, info: Dictionary) -> void:
	_routed.append([action, inst, info])


# ---------------------------------------------------------------------------
# equip_from_bag
# ---------------------------------------------------------------------------

func _test_equip_into_empty_slot() -> void:
	_world_drops.clear()
	var inv := Inventory.new()
	var bag := BagInventory.new()
	var ring := _make_item("ring_a", ItemData.EquipSlot.RING)
	bag.set_at(0, ring)

	var ok := InvRouter.equip_from_bag(bag, 0, inv)
	_check(ok, "equip_from_bag into an empty slot succeeds")
	_check(inv.get_at(ItemData.EquipSlot.RING) == ring, "the very same instance is equipped in its deterministic slot")
	_check(bag.get_at(0) == null, "and its bag slot is now empty")
	_check(_occurrences(ring, inv, bag) == 1, "the instance exists exactly once - moved, not copied")
	_check(_total(inv, bag) == 1, "conservation: one item before, one item after")


func _test_equip_swap_occupied() -> void:
	_world_drops.clear()
	var inv := Inventory.new()
	var bag := BagInventory.new()
	var worn := _make_item("hp_worn", ItemData.EquipSlot.HP)
	var incoming := _make_item("hp_new", ItemData.EquipSlot.HP)
	inv.set_item(ItemData.EquipSlot.HP, worn)
	bag.set_at(0, incoming)

	var ok := InvRouter.equip_from_bag(bag, 0, inv)
	_check(ok, "equip_from_bag onto an occupied slot (distinct item) succeeds as a swap")
	_check(inv.get_at(ItemData.EquipSlot.HP) == incoming, "the incoming item took the equip slot")
	_check(_bag_find(bag, worn) >= 0, "the displaced item landed in the bag")
	_check(_occurrences(worn, inv, bag) == 1 and _occurrences(incoming, inv, bag) == 1, "neither side of the swap was duplicated")
	_check(_total(inv, bag) == 2, "conservation: two items before, two after")


func _test_equip_swap_with_full_bag() -> void:
	_world_drops.clear()
	var inv := Inventory.new()
	var bag := BagInventory.new()
	var worn := _make_item("hp_worn2", ItemData.EquipSlot.HP)
	var incoming := _make_item("hp_new2", ItemData.EquipSlot.HP)
	inv.set_item(ItemData.EquipSlot.HP, worn)
	bag.set_at(0, incoming)
	_fill_bag(bag, 1) # every other bag slot occupied

	var ok := InvRouter.equip_from_bag(bag, 0, inv)
	_check(ok, "a swap still succeeds when the bag is otherwise full")
	_check(inv.get_at(ItemData.EquipSlot.HP) == incoming, "incoming equipped despite the full bag")
	_check(_bag_find(bag, worn) >= 0, "the displaced item took the slot the incoming one vacated")
	_check(_total(inv, bag) == bag.get_slot_count() + 1, "conservation across the full-bag swap")


func _test_equip_same_id_feeds_instead_of_swapping() -> void:
	_world_drops.clear()
	var inv := Inventory.new()
	var bag := BagInventory.new()
	var worn := _make_item("ring_dup", ItemData.EquipSlot.RING)
	var copy := _make_item("ring_dup", ItemData.EquipSlot.RING)
	inv.set_item(ItemData.EquipSlot.RING, worn)
	bag.set_at(0, copy)
	var progress_before: int = worn.progress

	var ok := InvRouter.equip_from_bag(bag, 0, inv)
	_check(ok, "equipping a duplicate of the equipped item succeeds")
	_check(inv.get_at(ItemData.EquipSlot.RING) == worn, "the same-id route MERGES: the equipped instance keeps its identity")
	_check(bag.get_at(0) == null, "the bag copy was consumed by the merge")
	_check(worn.progress == progress_before + 1, "and its mass arrived as feed progress on the survivor")
	_check(_total(inv, bag) == 1, "two copies became one fed instance - consumed by design, never lost")


func _test_bag_only_item_wont_equip() -> void:
	_world_drops.clear()
	var inv := Inventory.new()
	var bag := BagInventory.new()
	var trinket := _make_item("bag_only", ItemData.EquipSlot.NONE)
	bag.set_at(0, trinket)

	var ok := InvRouter.equip_from_bag(bag, 0, inv)
	_check(not ok, "an item with no equip slot refuses to equip")
	_check(bag.get_at(0) == trinket, "and stays exactly where it was")
	_check(_total(inv, bag) == 1, "conservation on the refusal")


# ---------------------------------------------------------------------------
# move_between (HubShop / InventoryStash call shape)
# ---------------------------------------------------------------------------

func _test_move_between_bag_and_equip_both_ways() -> void:
	_world_drops.clear()
	_routed.clear()
	var inv := Inventory.new()
	var bag := BagInventory.new()
	var mov := _make_item("mov_a", ItemData.EquipSlot.MOVE)
	bag.set_at(3, mov)

	var ok := InvRouter.move_between(bag, 3, inv, ItemData.EquipSlot.MOVE, null)
	_check(ok, "move_between bag -> equip succeeds")
	_check(inv.get_at(ItemData.EquipSlot.MOVE) == mov, "the instance is now equipped")
	_check(bag.get_at(3) == null, "and gone from the bag")
	_check(_total(inv, bag) == 1, "conservation after bag -> equip")
	_check(_routed.size() == 1 and _routed[0][0] == &"move_between" and _routed[0][1] == mov, "ui_item_routed reported the move with the moved instance")
	_check(int(_routed[0][2].get("from_i", -99)) == 3 and int(_routed[0][2].get("to_i", -99)) == int(ItemData.EquipSlot.MOVE), "with the correct from/to indices")

	_routed.clear()
	ok = InvRouter.move_between(inv, ItemData.EquipSlot.MOVE, bag, 5, null)
	_check(ok, "move_between equip -> bag succeeds")
	_check(bag.get_at(5) == mov, "the instance is back in the requested bag slot")
	_check(inv.get_at(ItemData.EquipSlot.MOVE) == null, "and the equip slot is empty")
	_check(_total(inv, bag) == 1, "conservation after equip -> bag")


func _test_move_between_wrong_equip_slot_refused() -> void:
	_world_drops.clear()
	_routed.clear()
	var inv := Inventory.new()
	var bag := BagInventory.new()
	var mov := _make_item("mov_b", ItemData.EquipSlot.MOVE)
	bag.set_at(0, mov)

	var ok := InvRouter.move_between(bag, 0, inv, ItemData.EquipSlot.HP, null)
	_check(not ok, "moving into the WRONG equip slot is refused")
	_check(bag.get_at(0) == mov and inv.get_at(ItemData.EquipSlot.HP) == null, "and nothing moved")
	_check(_routed.is_empty(), "a refused move emits no ui_item_routed")


func _test_move_between_equip_to_equip_blocked() -> void:
	_world_drops.clear()
	var inv := Inventory.new()
	var worn := _make_item("hp_fixed", ItemData.EquipSlot.HP)
	inv.set_item(ItemData.EquipSlot.HP, worn)

	var ok := InvRouter.move_between(inv, ItemData.EquipSlot.HP, inv, ItemData.EquipSlot.ARMOR, null)
	_check(not ok, "equipped -> equipped moves are blocked entirely")
	_check(inv.get_at(ItemData.EquipSlot.HP) == worn, "and the item stays equipped")


func _test_move_between_same_id_feeds() -> void:
	_world_drops.clear()
	var inv := Inventory.new()
	var bag := BagInventory.new()
	var worn := _make_item("ring_dup2", ItemData.EquipSlot.RING)
	var copy := _make_item("ring_dup2", ItemData.EquipSlot.RING)
	inv.set_item(ItemData.EquipSlot.RING, worn)
	bag.set_at(0, copy)
	var progress_before: int = worn.progress

	var ok := InvRouter.move_between(bag, 0, inv, ItemData.EquipSlot.RING, null)
	_check(ok, "move_between of a duplicate onto its equipped copy succeeds")
	_check(inv.get_at(ItemData.EquipSlot.RING) == worn and bag.get_at(0) == null, "same-id route merges instead of swapping")
	_check(worn.progress == progress_before + 1, "the feed registered on the surviving instance")
	_check(_total(inv, bag) == 1, "conservation: the duplicate was consumed, not lost")


func _test_move_between_distinct_id_swaps() -> void:
	_world_drops.clear()
	var inv := Inventory.new()
	var bag := BagInventory.new()
	var worn := _make_item("ring_w", ItemData.EquipSlot.RING)
	var incoming := _make_item("ring_x", ItemData.EquipSlot.RING)
	inv.set_item(ItemData.EquipSlot.RING, worn)
	bag.set_at(2, incoming)

	var ok := InvRouter.move_between(bag, 2, inv, ItemData.EquipSlot.RING, null)
	_check(ok, "move_between bag -> occupied equip slot (distinct item) succeeds")
	_check(inv.get_at(ItemData.EquipSlot.RING) == incoming, "the distinct-item route SWAPS: incoming equipped")
	_check(bag.get_at(2) == worn, "and the displaced item took the source bag slot")
	_check(_total(inv, bag) == 2, "conservation across the swap")


func _test_stash_bag_both_ways() -> void:
	_world_drops.clear()
	var bag := BagInventory.new()
	var stash := StashInventory.new()
	var keepsake := _make_item("keepsake", ItemData.EquipSlot.RING)
	bag.set_at(2, keepsake)

	var ok := InvRouter.move_between(bag, 2, stash, 5, null)
	_check(ok, "move_between bag -> stash succeeds")
	_check(stash.get_at(5) == keepsake and bag.get_at(2) == null, "the instance moved into the stash slot")
	_check(_total(null, bag, stash) == 1, "conservation after bag -> stash")

	ok = InvRouter.move_between(stash, 5, bag, 4, null)
	_check(ok, "move_between stash -> bag succeeds")
	_check(bag.get_at(4) == keepsake and stash.get_at(5) == null, "the instance moved back to the bag")
	_check(_total(null, bag, stash) == 1, "conservation after stash -> bag")


func _test_full_stash_exchange_conserves() -> void:
	_world_drops.clear()
	var bag := BagInventory.new()
	var stash := StashInventory.new()
	for i in range(stash.slot_count):
		stash.set_item(i, _make_item("sfill_%d" % i, ItemData.EquipSlot.NONE))
	var outgoing := _make_item("outgoing", ItemData.EquipSlot.RING)
	var resident: ItemInstance = stash.get_at(0)
	bag.set_at(0, outgoing)

	var ok := InvRouter.move_between(bag, 0, stash, 0, null)
	_check(ok, "moving onto an occupied slot of a FULL stash succeeds as an exchange")
	_check(stash.get_at(0) == outgoing and _bag_find(bag, resident) >= 0, "the two items traded places")
	_check(_total(null, bag, stash) == stash.slot_count + 1, "conservation: nothing lost against a full stash")


func _test_equip_to_occupied_bag_slot_redirects() -> void:
	_world_drops.clear()
	_routed.clear()
	var inv := Inventory.new()
	var bag := BagInventory.new()
	var worn := _make_item("mov_r", ItemData.EquipSlot.MOVE)
	var resident := _make_item("resident", ItemData.EquipSlot.NONE)
	inv.set_item(ItemData.EquipSlot.MOVE, worn)
	bag.set_at(0, resident)

	var ok := InvRouter.move_between(inv, ItemData.EquipSlot.MOVE, bag, 0, null)
	_check(ok, "unequipping onto an occupied bag slot whose item cannot swap back succeeds via redirect")
	_check(bag.get_at(0) == resident, "the resident bag item was not displaced")
	_check(_bag_find(bag, worn) == 1, "the unequipped item was redirected to the first empty slot")
	_check(inv.get_at(ItemData.EquipSlot.MOVE) == null, "no unsafe swap-back into the equip slot")
	_check(_total(inv, bag) == 2, "conservation across the redirect")
	_check(_routed.size() == 1 and int(_routed[0][2].get("to_i", -99)) == 1, "ui_item_routed reports the redirected destination index")


func _test_equip_to_occupied_bag_slot_safe_swap_back() -> void:
	_world_drops.clear()
	var inv := Inventory.new()
	var bag := BagInventory.new()
	var worn := _make_item("mov_worn", ItemData.EquipSlot.MOVE)
	var candidate := _make_item("mov_cand", ItemData.EquipSlot.MOVE)
	inv.set_item(ItemData.EquipSlot.MOVE, worn)
	bag.set_at(0, candidate)

	var ok := InvRouter.move_between(inv, ItemData.EquipSlot.MOVE, bag, 0, null)
	_check(ok, "unequipping onto a bag item valid for the same slot succeeds")
	_check(bag.get_at(0) == worn and inv.get_at(ItemData.EquipSlot.MOVE) == candidate, "and performs the safe swap-back")
	_check(_total(inv, bag) == 2, "conservation across the safe swap")


func _test_equip_to_full_bag_refused() -> void:
	_world_drops.clear()
	var inv := Inventory.new()
	var bag := BagInventory.new()
	var worn := _make_item("hp_stuck", ItemData.EquipSlot.HP)
	inv.set_item(ItemData.EquipSlot.HP, worn)
	_fill_bag(bag)
	var at_5: ItemInstance = bag.get_at(5)

	var ok := InvRouter.move_between(inv, ItemData.EquipSlot.HP, bag, 5, null)
	_check(not ok, "unequipping into a FULL bag is refused")
	_check(inv.get_at(ItemData.EquipSlot.HP) == worn, "the item is still equipped - not lost")
	_check(bag.get_at(5) == at_5, "and the bag is untouched")
	_check(_total(inv, bag) == bag.get_slot_count() + 1, "conservation on the full-bag refusal")


# ---------------------------------------------------------------------------
# eject_equipped_to_bag (InventoryBar call shape, uses the router bindings)
# ---------------------------------------------------------------------------

func _test_eject_equipped_to_bag() -> void:
	_world_drops.clear()
	var inv := Inventory.new()
	var bag := BagInventory.new()
	var worn := _make_item("hp_eject", ItemData.EquipSlot.HP)
	inv.set_item(ItemData.EquipSlot.HP, worn)
	InvRouter.bind_equipped(inv)
	InvRouter.bind_bag(bag)

	var ok := InvRouter.eject_equipped_to_bag(ItemData.EquipSlot.HP, {"type": 1, "pos": Vector2(12, 34)})
	_check(ok, "eject_equipped_to_bag succeeds")
	_check(inv.get_at(ItemData.EquipSlot.HP) == null, "the equip slot is empty")
	_check(_bag_find(bag, worn) >= 0, "and the same instance is in the bag")
	_check(_total(inv, bag) == 1, "conservation after the eject")


func _test_eject_to_full_bag_rolls_back() -> void:
	_world_drops.clear()
	var inv := Inventory.new()
	var bag := BagInventory.new()
	var worn := _make_item("hp_eject2", ItemData.EquipSlot.HP)
	inv.set_item(ItemData.EquipSlot.HP, worn)
	_fill_bag(bag)
	InvRouter.bind_equipped(inv)
	InvRouter.bind_bag(bag)

	# DEFECT (reported, not pinned): InventoryRouter.gd:71-72 arms the bag's
	# pending VFX origin before this add; the rollback below (line 79) never
	# disarms it, unlike the disarm equip_from_bag performs on its merge path
	# (lines 106-112) - the next origin-less bag add plays its fly-in from
	# this stale origin.
	var ok := InvRouter.eject_equipped_to_bag(ItemData.EquipSlot.HP, {"type": 1, "pos": Vector2(12, 34)})
	_check(not ok, "ejecting into a FULL bag is refused")
	_check(inv.get_at(ItemData.EquipSlot.HP) == worn, "the rollback re-equips the very same instance")
	_check(_occurrences(worn, inv, bag) == 1, "exactly once - the failed add did not duplicate it")
	_check(_total(inv, bag) == bag.get_slot_count() + 1, "conservation on the full-bag eject refusal")


func _test_eject_same_id_feeds_bag_stack() -> void:
	_world_drops.clear()
	var inv := Inventory.new()
	var bag := BagInventory.new()
	var worn := _make_item("ring_dup3", ItemData.EquipSlot.RING)
	var stack := _make_item("ring_dup3", ItemData.EquipSlot.RING)
	inv.set_item(ItemData.EquipSlot.RING, worn)
	bag.set_at(0, stack)
	var progress_before: int = stack.progress
	InvRouter.bind_equipped(inv)
	InvRouter.bind_bag(bag)

	var ok := InvRouter.eject_equipped_to_bag(ItemData.EquipSlot.RING)
	_check(ok, "ejecting a duplicate of a bag stack succeeds")
	_check(bag.get_at(0) == stack and stack.progress == progress_before + 1, "the player-bag stack absorbed it as feed")
	_check(inv.get_at(ItemData.EquipSlot.RING) == null and _total(inv, bag) == 1, "consumed into the stack, never lost")


# ---------------------------------------------------------------------------
# drop_from + world spawner stub
# ---------------------------------------------------------------------------

func _test_drop_from_equip_and_bag() -> void:
	_world_drops.clear()
	_routed.clear()
	var inv := Inventory.new()
	var bag := BagInventory.new()
	var worn := _make_item("hp_drop", ItemData.EquipSlot.HP)
	var carried := _make_item("bag_drop", ItemData.EquipSlot.RING)
	inv.set_item(ItemData.EquipSlot.HP, worn)
	bag.set_at(1, carried)

	var ok := InvRouter.drop_from(inv, ItemData.EquipSlot.HP, Vector2(100, 50))
	_check(ok, "drop_from an equipped slot succeeds")
	_check(inv.get_at(ItemData.EquipSlot.HP) == null, "the equip slot is empty")
	_check(_world_drops.size() == 1 and _world_drops[0][0] == worn, "the world spawner listener received the very same instance")
	_check(_world_drops[0][1] == Vector2(100, 50), "at the requested world position")
	_check(_total(inv, bag) == 2, "conservation: the dropped item lives on in the world")
	_check(_routed.size() == 1 and _routed[0][0] == &"drop" and _routed[0][1] == worn, "ui_item_routed reported the drop")

	ok = InvRouter.drop_from(bag, 1, Vector2(-7, 9))
	_check(ok, "drop_from a bag slot succeeds")
	_check(bag.get_at(1) == null, "the bag slot is empty")
	_check(_world_drops.size() == 2 and _world_drops[1][0] == carried and _world_drops[1][1] == Vector2(-7, 9), "the bag item reached the world too")
	_check(_total(inv, bag) == 2, "conservation after both drops")


# ---------------------------------------------------------------------------
# locked items refuse every route
# ---------------------------------------------------------------------------

func _test_locked_items_refuse_moves() -> void:
	_world_drops.clear()
	var inv := Inventory.new()
	var bag := BagInventory.new()
	var stash := StashInventory.new()
	var worn := _make_item("hp_locked", ItemData.EquipSlot.HP)
	worn.locked = true
	inv.set_item(ItemData.EquipSlot.HP, worn)
	InvRouter.bind_equipped(inv)
	InvRouter.bind_bag(bag)

	_check(not InvRouter.eject_equipped_to_bag(ItemData.EquipSlot.HP), "a locked equipped item refuses eject")
	_check(not InvRouter.drop_from(inv, ItemData.EquipSlot.HP, Vector2.ZERO), "refuses drop")
	_check(not InvRouter.move_between(inv, ItemData.EquipSlot.HP, bag, 0, null), "refuses move_between")
	_check(inv.get_at(ItemData.EquipSlot.HP) == worn and _world_drops.is_empty(), "and never left its slot")

	var carried := _make_item("ring_locked", ItemData.EquipSlot.RING)
	carried.locked = true
	bag.set_at(0, carried)
	_check(not InvRouter.equip_from_bag(bag, 0, inv), "a locked bag item refuses equip_from_bag")
	_check(not InvRouter.move_between(bag, 0, inv, ItemData.EquipSlot.RING, null), "refuses move_between")
	_check(not InvRouter.drop_from(bag, 0, Vector2.ZERO), "refuses drop")
	_check(bag.get_at(0) == carried, "and stayed in its bag slot")

	# Locked DESTINATIONS protect what is already there.
	var inv2 := Inventory.new()
	var bag2 := BagInventory.new()
	var protected := _make_item("ring_protected", ItemData.EquipSlot.RING)
	protected.locked = true
	inv2.set_item(ItemData.EquipSlot.RING, protected)
	var challenger := _make_item("ring_chal", ItemData.EquipSlot.RING)
	bag2.set_at(0, challenger)
	_check(not InvRouter.equip_from_bag(bag2, 0, inv2), "a locked equipped item refuses being swapped out by equip_from_bag")
	_check(not InvRouter.move_between(bag2, 0, inv2, ItemData.EquipSlot.RING, null), "and by move_between")
	_check(inv2.get_at(ItemData.EquipSlot.RING) == protected and bag2.get_at(0) == challenger, "both items kept their places")

	var locked_res := _make_item("stash_locked", ItemData.EquipSlot.NONE)
	locked_res.locked = true
	stash.set_item(0, locked_res)
	var mover := _make_item("mover", ItemData.EquipSlot.NONE)
	bag.set_at(1, mover)
	_check(not InvRouter.move_between(bag, 1, stash, 0, null), "a locked stash resident refuses being exchanged")
	_check(stash.get_at(0) == locked_res and bag.get_at(1) == mover, "and both items kept their places")


# ---------------------------------------------------------------------------
# invalid input refusals
# ---------------------------------------------------------------------------

func _test_invalid_slots_and_containers_refused() -> void:
	_world_drops.clear()
	var inv := Inventory.new()
	var bag := BagInventory.new()
	var ring := _make_item("ring_z", ItemData.EquipSlot.RING)
	bag.set_at(0, ring)

	_check(not InvRouter.equip_from_bag(bag, 99, inv), "equip_from_bag refuses an out-of-range bag slot")
	_check(not InvRouter.equip_from_bag(bag, -1, inv), "and a negative one")
	_check(not InvRouter.equip_from_bag(null, 0, inv), "and a null bag")
	_check(not InvRouter.move_between(bag, 99, inv, ItemData.EquipSlot.RING, null), "move_between refuses an empty/out-of-range source")
	_check(not InvRouter.move_between(null, 0, inv, 0, null), "and a null source container")
	_check(not InvRouter.drop_from(bag, 99, Vector2.ZERO), "drop_from refuses an out-of-range slot")
	_check(bag.get_at(0) == ring and _total(inv, bag) == 1, "no refusal touched the item")


# ---------------------------------------------------------------------------

func _run() -> void:
	_saved_equipped = InvRouter.equipped
	_saved_bag = InvRouter.bag
	InvRouter.dropped_to_world.connect(_on_dropped)
	InvRouter.ui_item_routed.connect(_on_routed)

	_test_equip_into_empty_slot()
	_test_equip_swap_occupied()
	_test_equip_swap_with_full_bag()
	_test_equip_same_id_feeds_instead_of_swapping()
	_test_bag_only_item_wont_equip()
	_test_move_between_bag_and_equip_both_ways()
	_test_move_between_wrong_equip_slot_refused()
	_test_move_between_equip_to_equip_blocked()
	_test_move_between_same_id_feeds()
	_test_move_between_distinct_id_swaps()
	_test_stash_bag_both_ways()
	_test_full_stash_exchange_conserves()
	_test_equip_to_occupied_bag_slot_redirects()
	_test_equip_to_occupied_bag_slot_safe_swap_back()
	_test_equip_to_full_bag_refused()
	_test_eject_equipped_to_bag()
	_test_eject_to_full_bag_rolls_back()
	_test_eject_same_id_feeds_bag_stack()
	_test_drop_from_equip_and_bag()
	_test_locked_items_refuse_moves()
	_test_invalid_slots_and_containers_refused()

	InvRouter.dropped_to_world.disconnect(_on_dropped)
	InvRouter.ui_item_routed.disconnect(_on_routed)
	InvRouter.bind_equipped(_saved_equipped)
	InvRouter.bind_bag(_saved_bag)

	print("InventoryRouterTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
