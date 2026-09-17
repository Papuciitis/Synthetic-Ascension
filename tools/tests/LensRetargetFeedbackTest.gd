extends Node

# Observability audit 2026-08-30 §5 #3: two stat drops that used to happen in
# silence. An Inversion Lens moving to a deeper curse snaps the old curse's
# whole penalty back; a Corruption Engine auto-feed deepens the worn roll.
# Both recompute at once, so the word has to come from the code that already
# holds the before and the after - the stat pass and the feed toast - never
# from the Run Sheet's refresh, which only runs while the bag is open.
#
# Run: <godot> --headless --path . res://tools/tests/LensRetargetFeedbackTest.tscn

const PlayerScript = preload("res://core/actors/player/player.gd")
const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const PICKUP_SCENE = preload("res://scenes/world/pickups/ItemPickup.tscn")

const LENS := &"augment_inversion_lens"
const ENGINE := &"augment_corruption_engine"
const RETARGET := "LENS: Health curse returns — Power curse inverted"

var _passes := 0
var _failures := 0
var _tips: Array[String] = []


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
	_test_helper_speaks_only_on_a_retarget()
	await _test_stat_pass_announces_the_retarget_once()
	_test_feed_toast_names_the_deepened_roll()
	_test_worn_pickup_feed_reaches_the_toast()
	_test_dropped_instance_feed_reaches_the_toast()
	print("LensRetargetFeedbackTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _make_data(item_id: String, slot: int) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.display_name = item_id
	data.equip_slot = slot as ItemData.EquipSlot
	data.pct_min = -0.95
	data.pct_max = 0.95
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	return data


func _cursed(slot: int, severity: float) -> ItemInstance:
	return ItemInstance.from_roll(
		_make_data("curse_%d_%d" % [slot, int(severity * 100.0)], slot),
		0, ItemInstance.Polarity.NEG, -severity, false
	)


func _on_tip(text: String, _duration: float) -> void:
	_tips.append(text)


# ---------------------------------------------------------------------------

## The diff is pure over two snapshots. It speaks for exactly one shape of
## change: the Lens left a curse that is still worn. Everything else the
## sheet's Lens line and the tooltip already cover.
func _test_helper_speaks_only_on_a_retarget() -> void:
	var inv := Inventory.new()
	var none := BurdenResolver.resolve(inv, [LENS])
	inv.set_item(0, _cursed(0, 0.80))
	var first := BurdenResolver.resolve(inv, [LENS])
	_check(first.suppressed_slot == 0, "fixture: the Health curse is the Lens target (slot %d)" % first.suppressed_slot)
	_check(PlayerScript.lens_retarget_message(null, first) == "", "no previous reading, nothing to compare")
	_check(PlayerScript.lens_retarget_message(none, first) == "", "the first curse suppressed returns nothing, so nothing is said")

	inv.set_item(3, _cursed(3, 0.90))
	var moved := BurdenResolver.resolve(inv, [LENS])
	_check(moved.suppressed_slot == 3, "a deeper Power curse takes the Lens (slot %d)" % moved.suppressed_slot)
	var message: String = PlayerScript.lens_retarget_message(first, moved)
	_check(message == RETARGET, "the retarget names the curse that came back and the one inverted (%s)" % message)
	_check(
		PlayerScript.lens_retarget_message(moved, moved) == "",
		"an unchanged wardrobe is silent, so the two recomputes per inventory change say it once"
	)

	# Same slot, another item: the old target is gone from the wardrobe.
	inv.set_item(3, _cursed(3, 0.95))
	var replaced := BurdenResolver.resolve(inv, [LENS])
	_check(replaced.suppressed_slot == 3, "fixture: the replacement is still the target")
	_check(
		PlayerScript.lens_retarget_message(moved, replaced) == "",
		"swapping the target for another curse in its slot returns no penalty, so it is not a retarget"
	)

	# Removing the target hands the Lens back to the Health curse. Its penalty
	# is not returning - it is being suppressed again - and the Power curse
	# is gone, so nothing 'returns'.
	inv.set_item(3, null)
	var handed_back := BurdenResolver.resolve(inv, [LENS])
	_check(handed_back.suppressed_slot == 0, "fixture: the Lens falls back to the Health curse")
	_check(
		PlayerScript.lens_retarget_message(replaced, handed_back) == "",
		"unequipping the target says nothing - the curse that would 'return' is the one that left"
	)

	# Removing the previous target while a milder curse remains: the Lens
	# moves, but the curse it left is not worn any more.
	inv.set_item(3, _cursed(3, 0.40))
	var two := BurdenResolver.resolve(inv, [LENS])
	inv.set_item(0, null)
	var one := BurdenResolver.resolve(inv, [LENS])
	_check(two.suppressed_slot == 0 and one.suppressed_slot == 3, "fixture: the Lens moves to the Power curse when the Health curse leaves")
	_check(
		PlayerScript.lens_retarget_message(two, one) == "",
		"a target the player removed does not 'return'"
	)

	# The last curse gone, and no Lens at all.
	inv.set_item(3, null)
	var empty := BurdenResolver.resolve(inv, [LENS])
	_check(PlayerScript.lens_retarget_message(one, empty) == "", "the last curse removed says nothing")
	inv.set_item(0, _cursed(0, 0.80))
	var plain_first := BurdenResolver.resolve(inv, [])
	inv.set_item(3, _cursed(3, 0.90))
	var plain_moved := BurdenResolver.resolve(inv, [])
	_check(PlayerScript.lens_retarget_message(plain_first, plain_moved) == "", "without a Lens there is no target to move")


## Through the real player: the stat pass runs on every inventory change
## (the player binds run_inventory.changed itself; game.gd binds it again),
## and the tip must come out exactly once, with the augment owned.
func _test_stat_pass_announces_the_retarget_once() -> void:
	var saved_inventory: Inventory = Global.run_inventory
	var saved_augments: Array[StringName] = Global.permanent_augment_ids.duplicate()
	var tip_cb := Callable(self, "_on_tip")
	RunEvents.tutorial_tip.connect(tip_cb)

	# Without the Lens the same wardrobe change is silent.
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.run_inventory = Inventory.new()
	var plain: CharacterBody2D = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(plain)
	await get_tree().process_frame
	_tips.clear()
	Global.run_inventory.set_item(0, _cursed(0, 0.80))
	Global.run_inventory.set_item(3, _cursed(3, 0.90))
	_check(_tips.is_empty(), "no Lens, no announcement (%d tips)" % _tips.size())
	remove_child(plain)
	plain.free()

	Global.permanent_augment_ids = [LENS, StringName(), StringName()]
	Global.run_inventory = Inventory.new()
	var player: CharacterBody2D = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(player)
	await get_tree().process_frame
	_tips.clear()

	Global.run_inventory.set_item(0, _cursed(0, 0.80))
	_check(_tips.is_empty(), "the first curse suppressed emits no tip (%d)" % _tips.size())
	var first_snapshot: BurdenSnapshot = player.get("last_burden") as BurdenSnapshot
	_check(first_snapshot != null and first_snapshot.suppressed_slot == 0, "fixture: the player's reading suppresses the Health curse")

	Global.run_inventory.set_item(3, _cursed(3, 0.90))
	_check(_tips.size() == 1, "the deeper Power curse moves the Lens and the stat pass says so once (%d tips)" % _tips.size())
	_check(not _tips.is_empty() and _tips[0] == RETARGET, "the tip is the retarget line (%s)" % (_tips[0] if not _tips.is_empty() else "<none>"))
	var moved_snapshot: BurdenSnapshot = player.get("last_burden") as BurdenSnapshot
	_check(moved_snapshot != null and moved_snapshot.suppressed_slot == 3, "and the reading the sheet shows agrees")

	player.call("recompute_run_stats", null, null)
	# The Run Sheet's ledger is this pass recorded step by step: base plus every
	# row must land exactly on the final stat, for every field the sheet shows.
	var base: Stats = player.get("base_stats") as Stats
	var final_stats: Stats = player.get("stats") as Stats
	_check(not Global.last_stat_ledger.is_empty(), "the real pass fills the ledger (%d rows)" % Global.last_stat_ledger.size())
	var ledger_ok := base != null and final_stats != null
	for field in Global.STAT_LEDGER_FIELDS:
		var total := float(base.get(field)) if base != null else 0.0
		for row in Global.last_stat_ledger:
			if StringName(row.get("stat", &"")) == field:
				total += float(row["after"]) - float(row["before"])
		if final_stats != null and not is_equal_approx(total, float(final_stats.get(field))):
			ledger_ok = false
			push_error("ledger %s: base + rows = %.4f, final %.4f" % [field, total, float(final_stats.get(field))])
	_check(ledger_ok, "base + every ledger row equals the final stat on all six fields")
	_check(Global.last_stat_ledger.any(func(r: Dictionary) -> bool: return String(r.get("label", "")).ends_with("INVERTED")), "the Lens slot records itself as INVERTED")
	_check(_tips.size() == 1, "a recompute over the same wardrobe does not repeat it (%d tips)" % _tips.size())

	Global.run_inventory.set_item(3, null)
	_check(_tips.size() == 1, "unequipping the target says nothing - the Health curse is being suppressed, not returned (%d tips)" % _tips.size())

	RunEvents.tutorial_tip.disconnect(tip_cb)
	remove_child(player)
	player.free()
	Global.run_inventory = saved_inventory
	Global.permanent_augment_ids = saved_augments


## The toast line for an auto-feed. Under the Engine a same-id pickup deepens
## the worn curse; the line must say where the roll went, and only then.
func _test_feed_toast_names_the_deepened_roll() -> void:
	var saved_augments: Array[StringName] = Global.permanent_augment_ids.duplicate()
	Global.permanent_augment_ids = [ENGINE, StringName(), StringName()]

	var inv := Inventory.new()
	var worn := _cursed(0, 0.40)
	inv.set_item(0, worn)
	var rank_before := int(worn.rarity)
	var pct_before := worn.active_pct()
	inv.feed_roll_into(0, -0.60)
	_check(is_equal_approx(worn.active_pct(), -0.60), "fixture: the Engine deepened the worn roll (%.2f)" % worn.active_pct())
	var line: String = ItemPickup.feed_toast_text(worn, rank_before, pct_before)
	_check(line.begins_with(worn.data.display_name + " "), "the line still leads with the item and its rank (%s)" % line)
	_check(line.ends_with(" · deepened to −60%"), "and says the worn roll deepened to −60%% (%s)" % line)
	_check(
		not ItemPickup.feed_toast_text(worn, rank_before).contains("deepened"),
		"a feed with no worn roll in hand (a bag stack) never claims a deepening"
	)

	# A milder pickup under the Engine leaves the deep roll where it was.
	var deep := _cursed(1, 0.60)
	inv.set_item(1, deep)
	var deep_before := deep.active_pct()
	inv.feed_roll_into(1, -0.40)
	_check(is_equal_approx(deep.active_pct(), -0.60), "fixture: the milder roll changed nothing")
	_check(
		not ItemPickup.feed_toast_text(deep, int(deep.rarity), deep_before).contains("deepened"),
		"a feed that did not deepen the roll does not say it did"
	)

	# A blessing never deepens.
	var blessed := ItemInstance.from_roll(_make_data("bless_3", 3), 0, ItemInstance.Polarity.POS, 0.40, false)
	inv.set_item(3, blessed)
	var bless_before := blessed.active_pct()
	inv.feed_roll_into(3, 0.60)
	_check(
		not ItemPickup.feed_toast_text(blessed, 0, bless_before).contains("deepened"),
		"a POS roll growing is not a deepening"
	)

	# Without the Engine the merge stabilises, and the line stays as it was.
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	var stable := _cursed(2, 0.40)
	inv.set_item(2, stable)
	var stable_before := stable.active_pct()
	inv.feed_roll_into(2, -0.60)
	_check(is_equal_approx(stable.active_pct(), -0.40), "fixture: without the Engine the mildest roll survives (%.2f)" % stable.active_pct())
	_check(
		not ItemPickup.feed_toast_text(stable, 0, stable_before).contains("deepened"),
		"without the Engine the toast is the plain progress line"
	)

	Global.permanent_augment_ids = saved_augments


## End to end: a ground pickup of the worn curse's id auto-feeds it, and the
## combat feed line that reaches BattleText carries the deepened roll.
func _test_worn_pickup_feed_reaches_the_toast() -> void:
	var saved_inventory: Inventory = Global.run_inventory
	var saved_bag: BagInventory = Global.run_bag
	var saved_augments: Array[StringName] = Global.permanent_augment_ids.duplicate()
	Global.run_inventory = Inventory.new()
	Global.run_bag = BagInventory.new()
	Global.permanent_augment_ids = [ENGINE, StringName(), StringName()]

	# Every roll of this fixture is exactly -60%, so the pickup is deterministic.
	var data := _make_data("toast_fixture", 0)
	data.pct_min = -0.60
	data.pct_max = -0.60
	Global.item_db["toast_fixture"] = data
	var worn := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.NEG, -0.40, false)
	Global.run_inventory.set_item(0, worn)

	var pickup: ItemPickup = PICKUP_SCENE.instantiate() as ItemPickup
	pickup.pickup_delay = 0.0
	pickup.item_id = "toast_fixture"
	add_child(pickup)
	var lines_before: int = BattleText._count
	pickup._try_pickup()
	_check(is_equal_approx(worn.active_pct(), -0.60), "the ground roll fed and deepened the worn curse (%.2f)" % worn.active_pct())
	_check(BattleText._count == lines_before + 1, "one feed line reached the combat text (%d)" % (BattleText._count - lines_before))
	var line: String = BattleText._texts[lines_before] if BattleText._count > lines_before else ""
	_check(line.contains("deepened to −60%"), "and it says the worn roll deepened (%s)" % line)

	Global.item_db.erase("toast_fixture")
	Global.run_inventory = saved_inventory
	Global.run_bag = saved_bag
	Global.permanent_augment_ids = saved_augments


## MODE A of the pickup: a dropped ItemInstance (not an id) of the worn curse
## feeds the equipped copy through add_or_feed, and its toast carries the
## deepened roll too. Review of 67c0eee: this path was unpinned.
func _test_dropped_instance_feed_reaches_the_toast() -> void:
	var saved_inventory: Inventory = Global.run_inventory
	var saved_bag: BagInventory = Global.run_bag
	var saved_augments: Array[StringName] = Global.permanent_augment_ids.duplicate()
	Global.run_inventory = Inventory.new()
	Global.run_bag = BagInventory.new()
	Global.permanent_augment_ids = [ENGINE, StringName(), StringName()]

	var data := _make_data("toast_fixture", 0)
	data.pct_min = -0.60
	data.pct_max = -0.60
	Global.item_db["toast_fixture"] = data
	var worn := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.NEG, -0.40, false)
	Global.run_inventory.set_item(0, worn)

	var pickup: ItemPickup = PICKUP_SCENE.instantiate() as ItemPickup
	pickup.pickup_delay = 0.0
	# A dropped instance enforces drop_pickup_delay in _ready (anti re-pickup);
	# the test wants the pickup live at once.
	pickup.drop_pickup_delay = 0.0
	pickup.item_instance = ItemInstance.from_roll(data, 0, ItemInstance.Polarity.NEG, -0.60, false)
	add_child(pickup)
	var lines_before: int = BattleText._count
	pickup._try_pickup()
	_check(is_equal_approx(worn.active_pct(), -0.60), "the dropped instance fed and deepened the worn curse (%.2f)" % worn.active_pct())
	_check(BattleText._count == lines_before + 1, "one feed line reached the combat text (%d)" % (BattleText._count - lines_before))
	var line: String = BattleText._texts[lines_before] if BattleText._count > lines_before else ""
	_check(line.contains("deepened to −60%"), "and the instance path says the worn roll deepened (%s)" % line)

	Global.item_db.erase("toast_fixture")
	Global.run_inventory = saved_inventory
	Global.run_bag = saved_bag
	Global.permanent_augment_ids = saved_augments
