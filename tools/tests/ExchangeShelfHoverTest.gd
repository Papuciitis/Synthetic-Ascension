extends Node

# A sale with more goods than the Exchanger has empty places grows his shelf
# past sixteen (the buyback), and the vendor grid then rebuilds every slot
# control. The Exchange hung its hover (tooltip, inspect line) and price marks
# on the old controls once, so after such a sale no stock item showed a
# tooltip (play session 2026-10-03: fourteen items sold, then eight restocks
# with no tooltips). Drives the real HubShop headless; the hover handlers run
# through each slot's own mouse_entered, since a headless viewport never
# reports a hovered control.
#
# Run: <godot> --headless --path . res://tools/tests/ExchangeShelfHoverTest.tscn

const HUB_SHOP := preload("res://ui/screens/HubShop.tscn")
const PACK := 14

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


## A fresh attempt with fourteen distinct items in the pack and no saved shelf.
func _fixture() -> void:
	SaveManager.current_save = null
	Global.start_new_attempt()
	Global.debug_disable_autosave = true
	Global.attempt_vendor_bag = null
	Global.attempt_vendor_segment = 0
	var keys: Array = Global.item_db.keys()
	keys.sort()
	var added := 0
	for key in keys:
		if added >= PACK:
			break
		var data: ItemData = Global.get_item_data(String(key))
		if data != null and Global.run_bag.add_instance(ItemInstance.from_data(data, 1, 2)):
			added += 1


## Places whose mouse_entered reaches the Exchange's vendor hover exactly once,
## bound to their own index.
func _hooked_places(shop: Node, grid: ShopBagGrid) -> int:
	var hooked := 0
	for i in range(grid.slot_count):
		var slot := grid.get_slot_control(i)
		if slot == null:
			continue
		var hooks := 0
		for connection in slot.mouse_entered.get_connections():
			var callable := connection["callable"] as Callable
			if callable.get_object() == shop and callable.get_method() == &"_on_hover_vendor" and callable.get_bound_arguments() == [i]:
				hooks += 1
		if hooks == 1:
			hooked += 1
	return hooked


func _marked_places(grid: ShopBagGrid) -> int:
	var marked := 0
	for i in range(grid.slot_count):
		var slot := grid.get_slot_control(i)
		if slot == null:
			continue
		var marks := 0
		for child in slot.get_children():
			if child is SellMarkOverlay and not child.is_queued_for_deletion():
				marks += 1
		if marks == 1:
			marked += 1
	return marked


## The highest absolute z any canvas item under the panels draws at.
func _panel_z_ceiling(node: Node, parent_z: int = 0) -> int:
	var z := parent_z
	if node is CanvasItem:
		var item := node as CanvasItem
		z = (parent_z + item.z_index) if item.z_as_relative else item.z_index
	var ceiling := z
	for child in node.get_children():
		ceiling = maxi(ceiling, _panel_z_ceiling(child, z))
	return ceiling


func _last_filled(bag: BagInventory) -> int:
	for i in range(bag.slots.size() - 1, -1, -1):
		if bag.slots[i] != null:
			return i
	return -1


## Hovers place `index` through its own signal and checks the tooltip names it.
func _hover(shop: Node, index: int, label: String) -> void:
	var grid: ShopBagGrid = shop.get("vendor_grid")
	var vendor: BagInventory = shop.get("_vendor_bag")
	var tip: ItemTooltip = shop.get("tooltip")
	var slot := grid.get_slot_control(index)
	var inst: ItemInstance = vendor.slots[index] if index >= 0 and index < vendor.slots.size() else null
	if slot == null or inst == null:
		_check(false, "%s: place %d holds a lot" % [label, index])
		return
	slot.mouse_entered.emit()
	var first_height := tip.size.y
	await _frames(2)
	_check(tip.visible, "%s: hovering place %d shows the tooltip" % [label, index])
	_check(tip.name_label != null and tip.name_label.text == inst.data.display_name, "%s: the tooltip names the hovered lot" % label)
	_check(is_equal_approx(first_height, tip.size.y), "%s: the first measurement is the settled one (%.0f px)" % [label, tip.size.y])
	_check(tip.get_viewport_rect().has_point(tip.get_global_rect().position), "%s: the tooltip's head is on screen" % label)
	slot.mouse_exited.emit()
	await _frames(1)
	_check(not tip.visible, "%s: leaving the place hides it" % label)


func _run() -> void:
	get_tree().root.size = Vector2i(1920, 1080)
	_fixture()
	var shop: Control = HUB_SHOP.instantiate()
	add_child(shop)
	await _frames(3)
	var grid: ShopBagGrid = shop.get("vendor_grid")
	var vendor: BagInventory = shop.get("_vendor_bag")
	var tip: ItemTooltip = shop.get("tooltip")
	_check(_hooked_places(shop, grid) == grid.slot_count, "every shelf place starts hooked (%d)" % grid.slot_count)

	var root_panels := shop.get_node("Root")
	_check(not tip.z_as_relative and tip.z_index > _panel_z_ceiling(root_panels), "the tooltip draws above everything in the Exchange's panels (z %d over %d)" % [tip.z_index, _panel_z_ceiling(root_panels)])
	var tip_layer := tip.get_canvas_layer_node()
	_check(tip_layer != null and tip_layer.layer > FollowerFeedbackUI.layer and shop.get_canvas_layer_node() == null, "the tooltip draws on a layer above the panels' canvas and the Followers notice")

	# The whole pack in one exchange: more goods than empty places.
	var places_before := vendor.slots.size()
	var empty_before := 0
	for inst in vendor.slots:
		if inst == null:
			empty_before += 1
	var sell: Dictionary = shop.get("_sell_bag")
	for i in range(Global.run_bag.slots.size()):
		if Global.run_bag.slots[i] != null:
			sell[i] = true
	_check(sell.size() > empty_before, "precondition: %d goods for %d empty places" % [sell.size(), empty_before])
	shop.call("_refresh_cart")
	shop.call("_perform_trade")
	await _frames(2)
	_check(vendor.slots.size() > places_before and grid.slot_count == vendor.slots.size(), "precondition: the sale grew the shelf and its grid (%d -> %d places)" % [places_before, grid.slot_count])
	_check(_hooked_places(shop, grid) == grid.slot_count, "every place of the grown shelf hovers into the Exchange (%d of %d)" % [_hooked_places(shop, grid), grid.slot_count])
	_check(_marked_places(grid) == grid.slot_count, "every place of the grown shelf carries one price mark")
	var buyback := _last_filled(vendor)
	_check(buyback >= BagInventory.SLOT_COUNT, "a buyback rests beyond the first sixteen places (%d)" % buyback)
	await _hover(shop, 0, "after the sale, the first lot")
	await _hover(shop, buyback, "after the sale, the last buyback")

	# Undo and a restock keep the shelf hooked.
	shop.call("_undo_last_trade")
	await _frames(2)
	_check(_hooked_places(shop, grid) == grid.slot_count, "after an undo every place still hovers")
	Global.transaction_followers(500 - Global.followers, &"developer_grant", {}, false, false)
	shop.call("_refresh_vendor_pressed")
	await _frames(2)
	_check(_hooked_places(shop, grid) == grid.slot_count and _marked_places(grid) == grid.slot_count, "after a restock every place still hovers and carries one mark")
	await _hover(shop, 0, "after a restock")

	# Sell again, leave and come back: the grown shelf persists for the segment.
	for i in range(Global.run_bag.slots.size()):
		if Global.run_bag.slots[i] != null:
			sell[i] = true
	shop.call("_refresh_cart")
	shop.call("_perform_trade")
	await _frames(2)
	shop.queue_free()
	await _frames(1)
	var reopened: Control = HUB_SHOP.instantiate()
	add_child(reopened)
	await _frames(3)
	var grid2: ShopBagGrid = reopened.get("vendor_grid")
	var vendor2: BagInventory = reopened.get("_vendor_bag")
	_check(grid2.slot_count > BagInventory.SLOT_COUNT, "precondition: the Exchange reopens on the grown shelf (%d places)" % grid2.slot_count)
	_check(_hooked_places(reopened, grid2) == grid2.slot_count and _marked_places(grid2) == grid2.slot_count, "reopened, every place hovers and carries a mark, not only the first sixteen")
	var last := _last_filled(vendor2)
	if last >= BagInventory.SLOT_COUNT:
		await _hover(reopened, last, "reopened, a buyback past sixteen")
	reopened.queue_free()
	await _frames(1)

	print("ExchangeShelfHoverTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
