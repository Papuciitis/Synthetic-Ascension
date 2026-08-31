extends Node

# Observability audit 2026-08-30 §5 #1, §5 #5, §6 #8 and Run Sheet audit
# 2026-08-28 §4 #10: the slot label, the item tooltip and its swap preview
# must say what a slot PAYS under an Inversion Lens - the resolver's own
# arithmetic, not the stored roll - and what a POS roll does to its slot.
# Exercises the real widgets headless with a fixture wardrobe.
#
# Run: <godot> --headless --path . res://tools/tests/ItemTooltipLensTest.tscn

var _passes := 0
var _failures := 0

var _saved_inventory: Inventory = null
var _saved_augments: Array = []


func _ready() -> void:
	call_deferred(&"_run")


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


func _cursed(slot: int, severity: float) -> ItemInstance:
	return ItemInstance.from_roll(
		_make_data("curse_%d_%d" % [slot, int(severity * 100.0)], slot),
		3, ItemInstance.Polarity.NEG, -severity, false
	)


func _blessed(slot: int, roll: float) -> ItemInstance:
	return ItemInstance.from_roll(
		_make_data("bless_%d_%d" % [slot, int(roll * 100.0)], slot),
		3, ItemInstance.Polarity.POS, roll, false
	)


func _set_augments(ids: Array) -> void:
	Global.init_permanent_augments()
	for i in range(3):
		Global.permanent_augment_ids[i] = StringName(ids[i]) if i < ids.size() else StringName()


## A body long enough that a pre-layout measurement is unmistakable: an
## autowrapped RichTextLabel that has never had a width reports tens of
## thousands of pixels for this description, against ~1100 once laid out.
func _wordy(slot: int) -> ItemInstance:
	var desc := ""
	for i in range(24):
		desc += "Sentence number %d of a description long enough to wrap many times. " % i
	var data := _make_data("wordy_%d" % slot, slot)
	data.description = desc
	return ItemInstance.from_roll(data, 3, ItemInstance.Polarity.POS, 0.25, false)


## The host/controller rig both hover tests drive by hand.
func _make_hover_rig() -> Array:
	var host := Control.new()
	host.name = "TipHost"
	host.size = Vector2(900.0, 600.0)
	add_child(host)

	var bar := Control.new()
	bar.name = "InvBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(bar)

	var slot_a := Control.new()
	slot_a.name = "SlotA"
	slot_a.position = Vector2(40.0, 40.0)
	slot_a.size = Vector2(48.0, 48.0)
	bar.add_child(slot_a)

	var slot_b := Control.new()
	slot_b.name = "SlotB"
	slot_b.position = Vector2(140.0, 40.0)
	slot_b.size = Vector2(48.0, 48.0)
	bar.add_child(slot_b)

	var controller := HudTooltipController.new()
	controller.name = "TipController"
	controller.tooltip_scene = load("res://ui/widgets/ItemTooltip.tscn") as PackedScene
	controller.inv_bar_path = NodePath("../InvBar")
	host.add_child(controller)
	# _ensure_tooltip and its add_child are both deferred.
	await get_tree().process_frame
	await get_tree().process_frame
	# The suite drives the hover by hand: a headless viewport never reports a
	# hovered control, so _process would do nothing.
	controller.set_process(false)
	return [host, controller, slot_a, slot_b]


func _make_tooltip() -> ItemTooltip:
	var scene := load("res://ui/widgets/ItemTooltip.tscn") as PackedScene
	var tooltip := scene.instantiate() as ItemTooltip if scene != null else null
	if tooltip == null:
		_check(false, "the item tooltip scene loads as an ItemTooltip")
		return null
	add_child(tooltip)
	return tooltip


func _run() -> void:
	_saved_inventory = Global.run_inventory
	_saved_augments = Global.permanent_augment_ids.duplicate()

	# The Lens wardrobe: a -80% Health curse (the one it suppresses), a -40%
	# Power curse that stays active, a +25% Armour blessing.
	var inv := Inventory.new()
	var health_curse := _cursed(0, 0.80)
	var power_curse := _cursed(3, 0.40)
	var armour_bless := _blessed(1, 0.25)
	inv.set_item(0, health_curse)
	inv.set_item(3, power_curse)
	inv.set_item(1, armour_bless)
	Global.run_inventory = inv
	_set_augments([&"augment_inversion_lens"])

	_test_slot_label_prints_the_return(health_curse, power_curse)
	_test_tooltip_burden_and_roll_lines(health_curse, power_curse, armour_bless)
	_test_swap_preview_under_the_lens(inv, health_curse, power_curse)
	await _test_hover_rebuild_cache(inv)
	await _test_first_tooltip_measures_itself()
	await _test_lock_toggle_refreshes_the_open_tooltip()

	Global.run_inventory = _saved_inventory
	for i in range(mini(3, _saved_augments.size())):
		Global.permanent_augment_ids[i] = _saved_augments[i]
	print("ItemTooltipLensTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


# Performance hygiene audit 2026-08-28 §2 #1: hovering an item rebuilt the whole
# tooltip - every formatted line, the comparison rows, the join, the RichTextLabel
# assignment and two Control relayouts - on EVERY frame the cursor sat still. The
# cache keys on the hovered control AND the item in it, because a paused bag can
# swap either one under a motionless cursor.
func _test_hover_rebuild_cache(inv: Inventory) -> void:
	var rig: Array = await _make_hover_rig()
	var host: Control = rig[0]
	var controller: HudTooltipController = rig[1]
	var slot_a: Control = rig[2]
	var slot_b: Control = rig[3]

	_check(
		controller.has_method("debug_rebuild_count") and controller.has_method("_update_for_hovered"),
		"the tooltip controller counts its rebuilds and exposes one hover step"
	)
	if not (controller.has_method("debug_rebuild_count") and controller.has_method("_update_for_hovered")):
		host.queue_free()
		await get_tree().process_frame
		return

	var first := inv.get_at(1)
	var second := inv.get_at(3)
	_check(first != null and second != null, "the fixture wardrobe has two items to hover")
	if first == null or second == null:
		host.queue_free()
		return
	slot_a.set_meta("item_instance", first)
	slot_b.set_meta("item_instance", second)

	var built := func() -> int: return int(controller.call("debug_rebuild_count"))

	var before: int = built.call()
	for _frame in range(12):
		controller.call("_update_for_hovered", slot_a)
	_check(
		built.call() - before == 1,
		"twelve motionless frames over one item build the tooltip once (%d)" % [built.call() - before]
	)

	before = built.call()
	controller.call("_update_for_hovered", slot_b)
	controller.call("_update_for_hovered", slot_b)
	_check(built.call() - before == 1, "moving to another slot rebuilds once (%d)" % [built.call() - before])

	# A paused bag swap: same control under the cursor, different instance in it.
	before = built.call()
	slot_b.set_meta("item_instance", first)
	controller.call("_update_for_hovered", slot_b)
	controller.call("_update_for_hovered", slot_b)
	_check(
		built.call() - before == 1,
		"swapping the item inside the hovered slot rebuilds (%d)" % [built.call() - before]
	)

	# ...and the same instance dragged to another slot is a different hover.
	before = built.call()
	controller.call("_update_for_hovered", slot_a)
	_check(
		built.call() - before == 1,
		"the same item under a different slot rebuilds (%d)" % [built.call() - before]
	)

	# Feeding a duplicate ranks the hovered item up in place; the tooltip has to
	# notice even though neither the control nor the instance changed.
	before = built.call()
	controller.call("_update_for_hovered", slot_a)
	_check(built.call() - before == 0, "and settles again")
	inv.emit_changed()
	controller.call("_update_for_hovered", slot_a)
	controller.call("_update_for_hovered", slot_a)
	_check(
		built.call() - before == 1,
		"an inventory change rebuilds the tooltip under a motionless cursor (%d)" % [built.call() - before]
	)

	# Leaving the bar hides the tooltip and drops the cache with it.
	before = built.call()
	controller.call("_update_for_hovered", null)
	controller.call("_update_for_hovered", slot_a)
	_check(built.call() - before == 1, "coming back to a slot rebuilds (%d)" % [built.call() - before])

	host.queue_free()
	await get_tree().process_frame


# §5 #1: the single most bug-shaped moment - "the Lens isn't working, the
# slot still says -80" - on a slot contributing +44%.
func _test_slot_label_prints_the_return(health_curse: ItemInstance, power_curse: ItemInstance) -> void:
	var scene := load("res://ui/components/InventorySlotView.tscn") as PackedScene
	var slot := scene.instantiate() as InventorySlotView if scene != null else null
	if slot == null:
		_check(false, "the slot view scene loads as an InventorySlotView")
		return
	add_child(slot)

	slot.slot_index = 0
	slot.set_item(health_curse)
	_check(slot.value_label.text == "+44", "the suppressed slot prints what it pays, +44, not the stored -80 (%s)" % slot.value_label.text)
	_check(slot.value_label.has_theme_color_override("font_color"), "and in the positive colour")
	_check(slot._pol_tint.color == InventorySlotView.NEG_TINT, "while the slot stays tinted NEG - the item is still a curse")

	slot.slot_index = 3
	slot.set_item(power_curse)
	_check(slot.value_label.text == "-40", "an active curse keeps its roll (%s)" % slot.value_label.text)
	_check(not slot.value_label.has_theme_color_override("font_color"), "in the default colour")

	# A bag duplicate of the suppressed curse is not the equipped instance.
	slot.slot_index = 0
	slot.set_item(_cursed(0, 0.80))
	_check(slot.value_label.text == "-80", "only the equipped instance may claim the return (%s)" % slot.value_label.text)

	# Without the Lens the same wardrobe reads as it always did.
	_set_augments([])
	slot.set_item(health_curse)
	_check(slot.value_label.text == "-80", "no Lens, no return (%s)" % slot.value_label.text)
	_check(not slot.value_label.has_theme_color_override("font_color"), "and the colour is released with it")
	_set_augments([&"augment_inversion_lens"])

	slot.set_item(null)
	_check(not slot.value_label.has_theme_color_override("font_color"), "an emptied slot drops the colour too")
	slot.queue_free()


# §4 #10 (census wording, POS roll line) and §6 #8 (Lens-aware feed line).
func _test_tooltip_burden_and_roll_lines(health_curse: ItemInstance, power_curse: ItemInstance, armour_bless: ItemInstance) -> void:
	var tooltip := _make_tooltip()
	if tooltip == null:
		return

	tooltip.show_item(health_curse)
	var body: String = tooltip.body_label.text
	_check(body.contains("SUPPRESSED — 80% curse inverted to +44%"), "the suppressed curse is read as the Lens reads it")
	_check(body.contains("polarity census") and not body.contains("parity and sets"), "the census claim names what actually reads it")
	_check(body.contains("Feeding stabilizes the curse (mildest roll survives) — a milder roll shrinks your inverted return"), "and the feed line says a stabilising feed shrinks the return")

	tooltip.show_item(power_curse)
	body = tooltip.body_label.text
	_check(body.contains("ACTIVE BURDEN 40%"), "an active curse is a burden")
	_check(body.contains("Feeding stabilizes the curse (mildest roll survives)") and not body.contains("inverted return"), "its feed line says nothing about a return it does not have")
	_check(not body.contains("EFFECT ROLL"), "a curse gets the burden line, not the POS roll line")

	tooltip.show_item(armour_bless)
	body = tooltip.body_label.text
	_check(body.contains("EFFECT ROLL +25% — ARM ×1.25 on this slot"), "a POS roll on a multiplied slot names the multiplier (%s)" % body)
	_check(not body.contains("BURDEN") and not body.contains("Feeding"), "and no burden or feed line")

	tooltip.show_item(_blessed(4, 0.12))
	body = tooltip.body_label.text
	_check(body.contains("EFFECT ROLL +12% — HST +12% on this slot"), "a POS roll on an added slot says it adds (%s)" % body)

	tooltip.show_item(_blessed(7, 0.20))
	body = tooltip.body_label.text
	_check(body.contains("ACCESSORY ROLL +20% — read by this item's scripted effect; not a stat."), "an accessory's POS roll is not a stat (%s)" % body)

	tooltip.show_item(_cursed(7, 0.20))
	body = tooltip.body_label.text
	_check(body.contains("ACCESSORY CURSE 20% — counts as NEG in the polarity census; not a stat Burden."), "an accessory curse is census-only, in the census's own name (%s)" % body)

	tooltip.queue_free()


# §5 #5: the comparison used to diff the stored rolls, so under a Lens every
# colour could be the inverse of the truth.
func _test_swap_preview_under_the_lens(inv: Inventory, health_curse: ItemInstance, power_curse: ItemInstance) -> void:
	var tooltip := _make_tooltip()
	if tooltip == null:
		return
	var lens: Array = [&"augment_inversion_lens"]

	# A deeper curse for the suppressed slot: the raw diff said -10% in red.
	var deeper := _cursed(0, 0.90)
	var rows := tooltip.build_comparison_rows(health_curse, deeper, inv, lens)
	var joined := "\n".join(rows)
	_check(joined.contains("would be suppressed → +49.5% returned"), "a deeper curse for the suppressed slot is a bigger return (%s)" % joined)
	_check(joined.contains("[color=%s]Effect roll" % ItemTooltip.CMP_POS_HEX), "and reads as an improvement")
	_check(not joined.contains("-10.0%"), "the raw roll diff is gone")
	_check(not joined.contains("Lens leaves") and not joined.contains("Lens moves"), "the Lens stays where it is")

	# A deep curse for another slot: it takes the Lens; the Health curse weighs again.
	var power_horror := _cursed(3, 0.90)
	rows = tooltip.build_comparison_rows(power_curse, power_horror, inv, lens)
	joined = "\n".join(rows)
	_check(joined.contains("would be suppressed → +49.5% returned"), "a curse the Lens would take costs its slot nothing (%s)" % joined)
	_check(joined.contains("Lens leaves HEALTH — its 80% curse weighs again"), "and the swap says which curse comes back")

	# A blessing over the suppressed curse: measured against the +44% return.
	var health_bless := _blessed(0, 0.30)
	rows = tooltip.build_comparison_rows(health_curse, health_bless, inv, lens)
	joined = "\n".join(rows)
	_check(joined.contains("Effect roll  -14.0% (ends the +44.0% return)"), "replacing the suppressed curse is measured against the return, not the stored roll (%s)" % joined)
	_check(joined.contains("[color=%s]Effect roll" % ItemTooltip.CMP_NEG_HEX), "and reads as the loss it is")
	_check(joined.contains("Lens moves to POWER — its 40% curse → +22% returned"), "and names where the Lens goes next")

	# No Lens: the raw diff, as before.
	rows = tooltip.build_comparison_rows(health_curse, deeper, inv, [])
	joined = "\n".join(rows)
	_check(joined.contains("Effect roll  -10.0%") and not joined.contains("suppressed"), "without a Lens the roll diff is the truth (%s)" % joined)

	tooltip.queue_free()


# Repair of the §2 #1 cache: the cache kept whatever the BUILD frame measured,
# and the first tooltip of a HUD is measured before the engine has laid its
# RichTextLabel out - an autowrapped label that has never had a width reports a
# height of tens of thousands of pixels. The per-frame placement the cache
# replaced used to re-measure on the next hovered frame, which silently
# corrected it; without that, the first item a player looks at in a run is
# covered by a screen-tall panel for the whole hover. Measuring twice in the
# SAME frame does not help - only a later frame does - so the fix re-measures on
# following hovered frames until the number stops moving.
func _test_first_tooltip_measures_itself() -> void:
	var rig: Array = await _make_hover_rig()
	var host: Control = rig[0]
	var controller: HudTooltipController = rig[1]
	var slot_a: Control = rig[2]
	var tip: Control = controller.get("_tooltip") as Control
	_check(tip != null, "the hover rig owns a tooltip")
	if tip == null:
		host.queue_free()
		await get_tree().process_frame
		return

	slot_a.set_meta("item_instance", _wordy(1))
	var built := func() -> int: return int(controller.call("debug_rebuild_count"))
	var before: int = built.call()

	# Hover it the way _process does: one call per frame, real frames between.
	controller.call("_update_for_hovered", slot_a)
	for _frame in range(3):
		await get_tree().process_frame
		controller.call("_update_for_hovered", slot_a)

	# What is on screen must be what a fresh measurement gives. Before the fix
	# the settled size was the pre-layout blow-up and this re-measure shrank it
	# by an order of magnitude.
	var settled: Vector2 = tip.size
	controller.call("_measure_tooltip")
	_check(
		tip.size.is_equal_approx(settled),
		"the first tooltip of a HUD settles on its real height, not the pre-layout one (%s vs %s)" % [settled, tip.size]
	)
	_check(
		built.call() - before == 1,
		"and settling re-measures without rebuilding the body again (%d builds)" % [built.call() - before]
	)

	# Once settled it stays settled: no further measurement moves it.
	var quiet: Vector2 = tip.size
	for _frame in range(3):
		await get_tree().process_frame
		controller.call("_update_for_hovered", slot_a)
	_check(tip.size.is_equal_approx(quiet), "and a motionless hover leaves it alone afterwards")

	host.queue_free()
	await get_tree().process_frame


# Ctrl+LeftClick in the run bag calls ItemInstance.toggle_locked() and repaints
# the same BagSlot Control with set_stack() (BagUI._on_slot_interaction /
# _refresh), so neither half of the cache key - the hovered control, the item in
# it - moves and no inventory emits `changed`. The open tooltip kept a stale
# lock state until the cursor left the slot.
func _test_lock_toggle_refreshes_the_open_tooltip() -> void:
	var rig: Array = await _make_hover_rig()
	var host: Control = rig[0]
	var controller: HudTooltipController = rig[1]
	var slot_a: Control = rig[2]
	var tip: ItemTooltip = controller.get("_tooltip") as ItemTooltip
	_check(tip != null, "the lock rig owns an ItemTooltip")
	if tip == null:
		host.queue_free()
		await get_tree().process_frame
		return

	var item := _blessed(1, 0.25)
	slot_a.set_meta("item_instance", item)
	var built := func() -> int: return int(controller.call("debug_rebuild_count"))

	controller.call("_update_for_hovered", slot_a)
	await get_tree().process_frame
	controller.call("_update_for_hovered", slot_a)
	_check(not tip.meta_label.text.contains("LOCKED"), "an unlocked item says nothing about locks (%s)" % tip.meta_label.text)
	_check(not tip.body_label.text.contains("LOCKED —"), "and neither does its body")

	var before: int = built.call()
	item.toggle_locked()
	# BagSlot.set_stack re-sets the same meta on the same Control: both cache
	# keys are unchanged, and no inventory emitted `changed`.
	slot_a.set_meta("item_instance", item)
	controller.call("_update_for_hovered", slot_a)
	controller.call("_update_for_hovered", slot_a)
	_check(
		tip.meta_label.text.contains("LOCKED"),
		"locking the hovered item refreshes the header under a motionless cursor (%s)" % tip.meta_label.text
	)
	_check(tip.body_label.text.contains("LOCKED —"), "and the body's protection line appears with it")
	_check(built.call() - before == 1, "on exactly one rebuild (%d)" % [built.call() - before])

	# ...and unlocking takes it away again.
	before = built.call()
	item.toggle_locked()
	slot_a.set_meta("item_instance", item)
	controller.call("_update_for_hovered", slot_a)
	controller.call("_update_for_hovered", slot_a)
	_check(not tip.meta_label.text.contains("LOCKED"), "unlocking takes the header line away (%s)" % tip.meta_label.text)
	_check(built.call() - before == 1, "on one rebuild too (%d)" % [built.call() - before])

	# A hover that never sees a lock toggle still builds once.
	before = built.call()
	for _frame in range(6):
		controller.call("_update_for_hovered", slot_a)
	_check(built.call() - before == 0, "and a quiet cursor rebuilds nothing (%d)" % [built.call() - before])

	host.queue_free()
	await get_tree().process_frame
