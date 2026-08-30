extends Node

# Observability audit 2026-08-30 §5 #3: a stat drop that used to happen in
# silence. An Inversion Lens moving to a deeper curse snaps the old curse's
# whole penalty back and recomputes at once, so the word has to come from the
# code that already holds the before and the after - the stat pass - never
# from the Run Sheet's refresh, which only runs while the bag is open.
#
# Run: <godot> --headless --path . res://tools/tests/LensRetargetFeedbackTest.tscn

const PlayerScript = preload("res://core/actors/player/player.gd")
const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")

const LENS := &"augment_inversion_lens"
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
	_check(_tips.size() == 1, "a recompute over the same wardrobe does not repeat it (%d tips)" % _tips.size())

	Global.run_inventory.set_item(3, null)
	_check(_tips.size() == 1, "unequipping the target says nothing - the Health curse is being suppressed, not returned (%d tips)" % _tips.size())

	RunEvents.tutorial_tip.disconnect(tip_cb)
	remove_child(player)
	player.free()
	Global.run_inventory = saved_inventory
	Global.permanent_augment_ids = saved_augments
