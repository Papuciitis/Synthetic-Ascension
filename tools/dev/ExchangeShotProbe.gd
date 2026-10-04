extends Node
## Renders the Exchange (HubShop) to PNGs with a lived-in fixture: worn gear,
## a part-full backpack, a cart with goods on both pans, an item hovered, the
## confirmation, the confirm flare mid-flight, and the embedded panel over the
## walkable hub. Needs a display (not --headless). A throwaway attempt with no
## current save, so nothing is written to the player's slots.
## Run: <godot> --path . res://tools/dev/ExchangeShotProbe.tscn -- --out=/abs/dir [--only=standalone|embedded|reduced|crowded]

const HUB_SHOP := preload("res://ui/screens/HubShop.tscn")
const HUB_WORLD := preload("res://scenes/hub/HubWorld.tscn")

var _out := "/tmp"
var _only := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(_out)
	SaveManager.current_save = null
	# No story card may stop an unattended run (StoryDirector.cards_allowed).
	StoryDirector.cards_override = 0
	if not Global.attempt_active:
		Global.start_new_attempt()
	Global.transaction_followers(6000 - Global.followers, &"dev_grant", {}, false, false)
	_fill_fixture()
	await _wait(0.3)
	if _want("standalone"):
		await _standalone()
	if _want("embedded"):
		await _embedded()
	if _want("reduced"):
		await _reduced()
	if _want("crowded"):
		await _crowded()
	print("ExchangeShotProbe: done -> ", _out)
	get_tree().quit(0)


func _want(area: String) -> bool:
	return _only == "" or _only == area


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [_out, shot_name])
	print("shot ", shot_name, " ", image.get_size())


## Worn gear in a few slots and a backpack two-thirds full.
## Moves the cursor there and tells the GUI, so hover states and the
## tooltip respond even when the window does not have the OS focus.
func _hover_at(point: Vector2) -> void:
	get_viewport().warp_mouse(point)
	var ev := InputEventMouseMotion.new()
	ev.position = point
	ev.global_position = point
	get_viewport().push_input(ev, true)


func _fill_fixture() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var keys: Array = Global.item_db.keys()
	keys.sort()
	var worn := 0
	var bagged := 0
	for key in keys:
		var data: ItemData = Global.get_item_data(String(key))
		if data == null:
			continue
		var inst := ItemInstance.from_data(data, 1, rng.randi_range(1, 4), (ItemInstance.Polarity.NEG if rng.randf() < 0.25 else ItemInstance.Polarity.POS))
		var slot := int(data.equip_slot)
		if worn < 5 and slot >= 0 and slot < Inventory.SLOT_COUNT and Global.run_inventory.is_slot_empty(slot):
			Global.run_inventory.set_item(slot, inst)
			worn += 1
		elif bagged < 10:
			if Global.run_bag.add_instance(inst):
				bagged += 1
		if worn >= 5 and bagged >= 10:
			break


func _backdrop() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.1, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	return bg


func _first_filled(bag: BagInventory, skip: int = 0) -> int:
	var seen := 0
	for i in range(bag.slots.size()):
		if bag.slots[i] != null:
			if seen == skip:
				return i
			seen += 1
	return -1


func _standalone() -> void:
	var bg := _backdrop()
	var shop: Control = HUB_SHOP.instantiate()
	add_child(shop)
	await _wait(0.12)
	await _shot("exchange_opening")
	await _wait(1.3)
	await _shot("exchange_empty_cart")
	# Goods on both pans.
	for k in [0, 2, 5]:
		var s := _first_filled(Global.run_bag, k)
		if s >= 0:
			shop._sell_bag[s] = true
	var vendor: BagInventory = Global.attempt_vendor_bag
	for k in [1, 3]:
		var v := _first_filled(vendor, k)
		if v >= 0:
			shop._buy_vendor[v] = true
	shop.call("_refresh_cart")
	shop.call("_refresh_overlays")
	await _wait(0.12)
	await _shot("exchange_cart_moving")
	await _wait(1.0)
	await _shot("exchange_cart")
	# Hover a vendor item for the tooltip.
	var vgrid: Control = shop.get("vendor_grid")
	var vslot := _first_filled(vendor, 0)
	var vctrl: Control = vgrid.call("get_slot_control", vslot) if vgrid != null and vslot >= 0 else null
	if vctrl != null:
		_hover_at(vctrl.get_global_rect().get_center())
		await _wait(0.5)
		await _shot("exchange_hover")
		_hover_at(Vector2(8, 8))
		await _wait(0.2)
	# The confirmation.
	shop.call("_barter_pressed")
	await _wait(0.1)
	await _shot("exchange_confirm_opening")
	await _wait(0.6)
	await _shot("exchange_confirm")
	var popup: Control = shop.get("confirm_trade")
	if popup != null:
		popup.call("_confirm")
	await _wait(0.12)
	await _shot("exchange_flare_mid")
	await _wait(0.35)
	await _shot("exchange_flare_late")
	await _wait(1.4)
	await _shot("exchange_after_trade")
	shop.queue_free()
	bg.queue_free()
	await _wait(0.3)


func _embedded() -> void:
	Global.followers = 6000
	var hub: HubWorld = HUB_WORLD.instantiate()
	hub.crowd_seed = 7
	hub.departure_scene_change_enabled = false
	add_child(hub)
	for i in range(30):
		await get_tree().process_frame
	hub._open_merchant()
	await _wait(0.12)
	await _shot("exchange_embedded_opening")
	await _wait(1.3)
	await _shot("exchange_embedded")
	var shop: Node = hub._open_panel
	if shop != null:
		shop.emit_signal("embedded_closed")
	await _wait(0.2)
	hub.queue_free()
	await _wait(0.3)


func _reduced() -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	var before: Variant = null
	if settings != null and settings.has_method("get_value") and settings.has_method("set_value"):
		before = settings.call("get_value", &"accessibility", &"reduced_motion", false)
		settings.call("set_value", &"accessibility", &"reduced_motion", true, false)
	var bg := _backdrop()
	var shop: Control = HUB_SHOP.instantiate()
	add_child(shop)
	await _wait(0.1)
	await _shot("exchange_reduced_opening")
	shop.queue_free()
	bg.queue_free()
	if settings != null and before != null:
		settings.call("set_value", &"accessibility", &"reduced_motion", before, false)
	await _wait(0.3)


## A grown satchel (24 slots, full) and a long shelf (buybacks past 16), to
## check the grids shrink to fit instead of spilling out of their panels; then
## a filtered shelf and a hovered backpack slot.
func _crowded() -> void:
	Global.run_bag.extra_slots = 8
	Global.run_bag._ensure_size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var keys: Array = Global.item_db.keys()
	keys.sort()
	var k := 0
	while Global.run_bag.first_empty_slot() >= 0 and k < keys.size():
		var data: ItemData = Global.get_item_data(String(keys[k]))
		k += 1
		if data != null:
			Global.run_bag.add_instance(ItemInstance.from_data(data, 1, rng.randi_range(1, 4)))
	var bg := _backdrop()
	var shop: Control = HUB_SHOP.instantiate()
	add_child(shop)
	await _wait(0.3)
	# A long shelf: the stock plus buybacks past the base sixteen places.
	var vendor: BagInventory = shop.get("_vendor_bag")
	if vendor != null:
		vendor.extra_slots = 8
		vendor._ensure_size()
		var j := keys.size() - 1
		while vendor.first_empty_slot() >= 0 and vendor.first_empty_slot() < 22 and j > 0:
			var d2: ItemData = Global.get_item_data(String(keys[j]))
			j -= 1
			if d2 != null:
				vendor.set_at(vendor.first_empty_slot(), ItemInstance.from_data(d2, 1, rng.randi_range(1, 4)))
		(shop.get("vendor_grid") as Node).call("bind_bag", vendor)
		shop.call("_apply_vendor_filters")
	await _wait(1.3)
	await _shot("exchange_crowded")
	var bgrid: Control = shop.get("bag_grid")
	var bctrl: Control = bgrid.call("get_slot_control", 5) if bgrid != null else null
	if bctrl != null:
		_hover_at(bctrl.get_global_rect().get_center())
		await _wait(0.5)
		await _shot("exchange_crowded_hover")
		_hover_at(Vector2(8, 8))
	var search: LineEdit = shop.get("vendor_search")
	if search != null:
		search.text = "a"
		search.text_changed.emit("a")
	shop.call("_set_vendor_category", 1)
	await _wait(0.6)
	await _shot("exchange_filtered")
	shop.call("_set_vendor_category", 0)
	if search != null:
		search.text = ""
		search.text_changed.emit("")
	shop.queue_free()
	bg.queue_free()
	await _wait(0.3)
