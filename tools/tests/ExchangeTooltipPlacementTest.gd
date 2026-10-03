extends Node

# Where the Exchange's item tooltip stands. Three playtest-review findings
# (2026-10-03): on the stock's right-hand columns the screen clamp put the
# tooltip back over the lot under the cursor; the Followers notice (layer 180)
# covered a top-clamped tooltip's header for 3.6 s after a trade or restock;
# and a long dossier stood taller than the screen, its comparison and equip
# preview cut off the bottom edge. Drives the real HubShop headless; hover
# runs through a slot's own mouse_entered, since a headless viewport never
# reports a hovered control.
#
# Run: <godot> --headless --path . res://tools/tests/ExchangeTooltipPlacementTest.tscn

const HUB_SHOP := preload("res://ui/screens/HubShop.tscn")
const SCREEN := Vector2(1920.0, 1080.0)

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


func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _fixture() -> void:
	SaveManager.current_save = null
	Global.start_new_attempt()
	Global.debug_disable_autosave = true
	Global.attempt_vendor_bag = null
	Global.attempt_vendor_segment = 0


## An item whose dossier, at the normal width, is far taller than the screen.
func _long_item() -> ItemInstance:
	var data := ItemData.new()
	data.id = "probe_long_dossier"
	data.display_name = "Probe Long Dossier"
	data.equip_slot = 1 as ItemData.EquipSlot
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	var desc := ""
	for i in range(30):
		desc += "Sentence number %d of a description long enough to wrap many times. " % i
	data.description = desc
	return ItemInstance.from_roll(data, 3, ItemInstance.Polarity.POS, 0.25, false)


func _first_filled(bag: BagInventory) -> int:
	for i in range(bag.slots.size()):
		if bag.slots[i] != null:
			return i
	return -1


func _run() -> void:
	get_tree().root.size = Vector2i(SCREEN)
	_fixture()
	var shop: Control = HUB_SHOP.instantiate()
	add_child(shop)
	await _frames(3)
	var tip: ItemTooltip = shop.get("tooltip")
	var grid: ShopBagGrid = shop.get("vendor_grid")
	var vendor: BagInventory = shop.get("_vendor_bag")

	# Layering: a layer of its own over the notice, with the Exchange's theme.
	var tip_layer := tip.get_canvas_layer_node()
	_check(tip_layer != null and tip_layer.layer > FollowerFeedbackUI.layer, "the tooltip's layer (%s) is above the Followers notice's (%d)" % [str(tip_layer.layer) if tip_layer != null else "none", FollowerFeedbackUI.layer])
	_check(tip_layer != null and tip_layer.layer < 230, "and below the tutorial cards and the loading scrim")
	_check(tip.theme == shop.theme, "the tooltip keeps the Exchange's theme across its layer")

	# Hover a lot: the hover frame already stands where _process keeps it.
	var lot := _first_filled(vendor)
	var slot := grid.get_slot_control(lot)
	slot.mouse_entered.emit()
	_check(tip.visible, "hovering a lot shows the tooltip")
	if not shop.has_method("_tooltip_pos_for_mouse"):
		_check(false, "the Exchange places its tooltip through _tooltip_pos_for_mouse")
		shop.queue_free()
		await _frames(1)
		_finish()
		return
	var mouse := get_viewport().get_mouse_position()
	_check(tip.global_position.is_equal_approx(shop.call("_tooltip_pos_for_mouse", mouse)), "the hover frame places it where the following frames keep it")

	# Placement across the screen: inside it, and never over the cursor.
	var bounds := Rect2(Vector2(8.0, 8.0), SCREEN - Vector2(16.0, 16.0))
	var covered := 0
	var outside := 0
	var probes := 0
	for x in range(20, 1920, 50):
		for y in [20.0, 300.0, 600.0, 900.0, 1060.0]:
			var m := Vector2(float(x), y)
			var rect := Rect2(shop.call("_tooltip_pos_for_mouse", m), tip.size)
			probes += 1
			if rect.has_point(m):
				covered += 1
			if not bounds.encloses(rect.grow(-0.01)):
				outside += 1
	_check(covered == 0, "the tooltip never covers the cursor (%d of %d positions)" % [covered, probes])
	_check(outside == 0, "and always stays inside the screen (%d of %d outside)" % [outside, probes])
	var right := Vector2(1880.0, 500.0)
	var flipped := Rect2(shop.call("_tooltip_pos_for_mouse", right), tip.size)
	_check(is_equal_approx(flipped.end.x, right.x - 16.0), "past the right edge it flips to the cursor's left")
	var left := Vector2(300.0, 500.0)
	_check(is_equal_approx((shop.call("_tooltip_pos_for_mouse", left) as Vector2).x, left.x + 16.0), "elsewhere it sits right of the cursor")
	# Every lot on the shelf, at its own centre.
	var lots_covered := 0
	var lots := 0
	for i in range(grid.slot_count):
		var c := grid.get_slot_control(i)
		if c == null or i >= vendor.slots.size() or vendor.slots[i] == null:
			continue
		c.mouse_entered.emit()
		var centre := c.get_global_rect().get_center()
		lots += 1
		if Rect2(shop.call("_tooltip_pos_for_mouse", centre), tip.size).has_point(centre):
			lots_covered += 1
		c.mouse_exited.emit()
	_check(lots > 0 and lots_covered == 0, "no lot's tooltip covers that lot's centre (%d of %d)" % [lots_covered, lots])

	# A dossier taller than the screen widens until it fits, from its first
	# measurement; the next short one is back at the normal width.
	var limit := SCREEN.y - 16.0
	tip.show_item(_long_item())
	var first := tip.size
	await _frames(2)
	_check(first.is_equal_approx(tip.size), "the long dossier's first measurement is the settled one (%s)" % tip.size)
	_check(tip.size.x > 360.0 and tip.size.y <= limit, "the long dossier widens to fit the screen (%s)" % tip.size)
	tip.show_item(vendor.slots[lot])
	await _frames(1)
	_check(is_equal_approx(tip.size.x, 360.0), "the next dossier is back at the normal width (%.0f)" % tip.size.x)
	_check(tip.size.y <= limit, "and fits the screen (%.0f)" % tip.size.y)
	# A long name widens the panel; the next dossier is still measured at the
	# width it is laid out at, not that one, or it grows after the hover frame.
	var named := _long_item()
	named.data.display_name = "Probe Item Carrying An Extraordinarily Long Display Name"
	named.data.description = "Short."
	tip.show_item(named)
	await _frames(1)
	_check(tip.size.x > 400.0, "precondition: a long name widens the panel (%.0f)" % tip.size.x)
	tip.show_item(_long_item())
	var hover_frame := tip.size
	await _frames(2)
	_check(hover_frame.is_equal_approx(tip.size), "after a long name, the hover frame's size is the settled one (%s, then %s)" % [hover_frame, tip.size])
	_check(tip.size.y <= limit, "and the long dossier still fits the screen (%.0f)" % tip.size.y)

	# The layer does not hide with the Exchange, so _process does.
	slot.mouse_entered.emit()
	shop.visible = false
	await _frames(2)
	_check(not tip.visible, "hiding the Exchange hides its tooltip")
	shop.visible = true

	shop.queue_free()
	await _frames(1)
	_finish()


func _finish() -> void:
	print("ExchangeTooltipPlacementTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
