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

	Global.run_inventory = _saved_inventory
	for i in range(mini(3, _saved_augments.size())):
		Global.permanent_augment_ids[i] = _saved_augments[i]
	print("ItemTooltipLensTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


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
