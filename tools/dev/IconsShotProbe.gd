extends Node
## Item icons at the sizes the game draws them. Renders the Exchange, Gear &
## Stash, the HUD inventory bar, an item tooltip and loot on the ground from
## one fixture, and lists every item icon on screen with its drawn size, the
## texture behind it (size, mipmaps) and the filter it is sampled with.
##
## --old=<dir> swaps every item icon, in memory only, for the PNG of the same
## file name in <dir>, loaded the way the old 32 px icons were imported (no
## mipmaps). A run with --old and a run without share the fixture pixel for
## pixel, so their shots crop side by side. Needs a display (not --headless).
## A throwaway attempt with no current save: nothing is written to the
## player's slots.
## Run: <godot> --path . res://tools/dev/IconsShotProbe.tscn -- --out=/abs/dir [--old=/abs/dir] [--only=exchange|stash|surfaces]

const HUB_SHOP := preload("res://ui/screens/HubShop.tscn")
const STASH := preload("res://ui/screens/InventoryStash.tscn")
const BAR := preload("res://ui/components/InventoryBar.tscn")
const TOOLTIP := preload("res://ui/widgets/ItemTooltip.tscn")
const PICKUP := preload("res://scenes/world/pickups/ItemPickup.tscn")
const WORLD := preload("res://assets/ui/menu/threshold_backdrop.jpg")
const ICON_DIR := "res://assets/textures/items/"
const LADDER := [24, 32, 44, 48, 60, 72, 84, 128]
const GROUND_ITEMS := [
	"conduit_lens", "curse_jinxed_coin", "gravemarch_censer", "lattice_tickspurs",
	"beka", "dignity", "seven_mile_boots", "bazinga", "grandmas_bazooka", "second_breakfast",
]

var _out := "/tmp"
var _old := ""
var _only := ""
## Texture2D -> icon file name, for every item icon in play.
var _icons: Dictionary = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--old="):
			_old = arg.trim_prefix("--old=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(_out)
	SaveManager.current_save = null
	if not Global.attempt_active:
		Global.start_new_attempt()
	_index_icons()
	_report_textures()
	_seed_items()
	await _wait(0.3)
	if _want("exchange"):
		await _exchange()
	if _want("stash"):
		await _stash()
	if _want("surfaces"):
		await _surfaces()
	print("IconsShotProbe: done -> ", _out)
	get_tree().quit(0)


func _want(what: String) -> bool:
	return _only == "" or _only == what


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [_out, label])
	print("shot ", label, " ", image.get_size())


func _move_mouse(at: Vector2) -> void:
	get_viewport().warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	var window_pos: Vector2 = get_viewport().get_final_transform() * at
	motion.position = window_pos
	motion.global_position = window_pos
	Input.parse_input_event(motion)


# ------------------------------------------------------------------ icons

## Collects every item icon, swapping in the old PNGs first when asked.
func _index_icons() -> void:
	var ids: Array = Global.item_db.keys()
	ids.sort()
	for id in ids:
		var data := Global.item_db[id] as ItemData
		if data == null or data.icon == null:
			continue
		var path := data.icon.resource_path
		if not path.begins_with(ICON_DIR):
			continue
		var file := path.get_file()
		if _old != "":
			var old_path := _old.path_join(file)
			if FileAccess.file_exists(old_path):
				var img := Image.load_from_file(old_path)
				if img != null and not img.is_empty():
					data.icon = ImageTexture.create_from_image(img)
		_icons[data.icon] = file


func _report_textures() -> void:
	var seen: Dictionary = {}
	for tex: Texture2D in _icons.keys():
		var img := tex.get_image()
		var key := "%dx%d mipmaps=%s" % [tex.get_width(), tex.get_height(), str(img != null and img.has_mipmaps())]
		seen[key] = int(seen.get(key, 0)) + 1
	for key: String in seen.keys():
		print("icons: %d textures %s" % [int(seen[key]), key])


const _FILTER_NAMES := {
	CanvasItem.TEXTURE_FILTER_NEAREST: "NEAREST",
	CanvasItem.TEXTURE_FILTER_LINEAR: "LINEAR (no mipmaps)",
	CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS: "NEAREST_MIPMAPS",
	CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS: "LINEAR_MIPMAPS",
	CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC: "NEAREST_MIPMAPS_ANISO",
	CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC: "LINEAR_MIPMAPS_ANISO",
}
const _DEFAULT_FILTER_NAMES := ["NEAREST", "LINEAR (no mipmaps)", "LINEAR_MIPMAPS", "NEAREST_MIPMAPS"]


func _filter_of(item: CanvasItem) -> String:
	var node: Node = item
	while node is CanvasItem:
		var f := (node as CanvasItem).texture_filter
		if f != CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			return String(_FILTER_NAMES.get(f, str(f)))
		node = node.get_parent()
	return "default " + String(_DEFAULT_FILTER_NAMES[int(get_viewport().canvas_item_default_texture_filter)])


## The nearest scripted ancestor names the widget an icon belongs to.
func _owner_widget(node: Node) -> String:
	var n: Node = node
	while n != null and n != self:
		var scr := n.get_script() as Script
		if scr != null:
			return scr.resource_path.get_file().get_basename()
		n = n.get_parent()
	return "(probe ladder)"


## Every item icon under root: who draws it, how large (logical and on the
## window), and with which filter.
func _report(label: String, root: Node) -> void:
	var px_scale: float = get_viewport().get_final_transform().get_scale().x
	var rows: Dictionary = {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for child in n.get_children():
			stack.append(child)
		var drawn := 0.0
		var tex: Texture2D = null
		var item: CanvasItem = null
		if n is TextureRect:
			var trect := n as TextureRect
			if not trect.is_visible_in_tree():
				continue
			tex = trect.texture
			drawn = minf(trect.size.x, trect.size.y) * trect.get_global_transform().get_scale().x
			item = trect
		elif n is Sprite2D:
			var sp := n as Sprite2D
			if not sp.is_visible_in_tree():
				continue
			tex = sp.texture
			if tex != null:
				drawn = float(maxi(tex.get_width(), tex.get_height())) * sp.get_global_transform().get_scale().x
			item = sp
		if tex == null or not _icons.has(tex):
			continue
		var key := "%-22s drawn %5.1f logical = %5.1f window px  from %dpx  %s" % [
			_owner_widget(n), drawn, drawn * px_scale, tex.get_width(), _filter_of(item)]
		rows[key] = int(rows.get(key, 0)) + 1
	var keys: Array = rows.keys()
	keys.sort()
	for key: String in keys:
		print("[%s] %s  x%d" % [label, key, int(rows[key])])


# ------------------------------------------------------------------ fixture

## Worn gear, a part-full backpack and a few kept items, every family shown.
func _seed_items() -> void:
	if Global.meta_stash == null:
		Global.meta_stash = StashInventory.new()
	var by_slot: Dictionary = {}
	var loose: Array = []
	var ids: Array = Global.item_db.keys()
	ids.sort()
	for id in ids:
		if String(id) == "item_test":
			continue
		var data := Global.item_db[id] as ItemData
		if data == null or data.icon == null:
			continue
		var slot := int(data.equip_slot)
		if slot >= 0 and slot < Inventory.SLOT_COUNT and not by_slot.has(slot):
			by_slot[slot] = data
		else:
			loose.append(data)
	var rarity := 0
	for slot in by_slot:
		var inst := ItemInstance.from_roll(by_slot[slot], rarity % 5, ItemInstance.Polarity.POS, 0.4, false)
		Global.run_inventory.set_item(int(slot), inst, {"player_driven": true})
		rarity += 1
	for i in range(mini(12, loose.size())):
		var pol := ItemInstance.Polarity.POS if i % 3 != 0 else ItemInstance.Polarity.NEG
		Global.run_bag.set_item(i, ItemInstance.from_roll(loose[i], (i + 1) % 5, pol, 0.3, false))
	for j in range(mini(12, loose.size() - 12)):
		Global.meta_stash.set_item(j, ItemInstance.from_roll(loose[12 + j], j % 4, ItemInstance.Polarity.POS, 0.5, false), null)


func _item(id_part: String) -> ItemInstance:
	var ids: Array = Global.item_db.keys()
	ids.sort()
	for id in ids:
		var data := Global.item_db[id] as ItemData
		if data == null or data.icon == null:
			continue
		if data.icon.resource_path.get_file().contains(id_part) or String(_icons.get(data.icon, "")).contains(id_part) or String(id).contains(id_part):
			return ItemInstance.from_roll(data, 2, ItemInstance.Polarity.POS, 0.5, false)
	return null


func _first_filled(bag: BagInventory, skip: int = 0) -> int:
	var seen := 0
	for i in range(bag.slots.size()):
		if bag.slots[i] != null:
			if seen == skip:
				return i
			seen += 1
	return -1


func _first_icon_rect(root: Node, widget: String) -> TextureRect:
	var stack: Array[Node] = [root]
	var found: Array[TextureRect] = []
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for child in n.get_children():
			stack.append(child)
		if n is TextureRect and _icons.has((n as TextureRect).texture) and _owner_widget(n) == widget and (n as TextureRect).is_visible_in_tree():
			found.append(n as TextureRect)
	found.sort_custom(func(a: TextureRect, b: TextureRect) -> bool:
		var pa := a.get_global_rect().position
		var pb := b.get_global_rect().position
		return pa.y < pb.y or (is_equal_approx(pa.y, pb.y) and pa.x < pb.x))
	return found[0] if not found.is_empty() else null


# ------------------------------------------------------------------ screens

func _exchange() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.1, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shop: Control = HUB_SHOP.instantiate()
	add_child(shop)
	await _wait(1.4)
	var sell := shop.get("_sell_bag") as Dictionary
	var buy := shop.get("_buy_vendor") as Dictionary
	if sell != null and buy != null:
		for k in [0, 2, 5]:
			var s := _first_filled(Global.run_bag, k)
			if s >= 0:
				sell[s] = true
		var vendor: BagInventory = Global.attempt_vendor_bag
		for k in [1, 3]:
			var v := _first_filled(vendor, k)
			if v >= 0:
				buy[v] = true
		shop.call("_refresh_cart")
		shop.call("_refresh_overlays")
	await _wait(1.2)
	await _shot("exchange")
	_report("exchange", shop)
	var target := _first_icon_rect(shop, "BagSlot")
	if target != null:
		_move_mouse(target.get_global_rect().get_center())
		await _wait(0.6)
		await _shot("exchange_hover")
		_report("exchange_hover", shop)
	_move_mouse(Vector2(4, 4))
	shop.queue_free()
	bg.queue_free()
	await _wait(0.2)


func _stash() -> void:
	var art := TextureRect.new()
	art.texture = WORLD
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var screen: Node = STASH.instantiate()
	add_child(screen)
	await _wait(1.4)
	await _shot("stash")
	_report("stash", screen)
	var target := _first_icon_rect(screen, "HubItemSlot")
	if target != null:
		_move_mouse(target.get_global_rect().get_center())
		await _wait(0.6)
		await _shot("stash_hover")
		_report("stash_hover", screen)
	_move_mouse(Vector2(4, 4))
	screen.queue_free()
	art.queue_free()
	await _wait(0.2)


## The HUD inventory bar, an item tooltip, a size ladder under both filters
## and loot on the ground, on a dark floor.
func _surfaces() -> void:
	var floor_rect := ColorRect.new()
	floor_rect.color = Color(0.085, 0.075, 0.068)
	floor_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(floor_rect)

	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	var bar: InventoryBar = BAR.instantiate()
	bar.position = Vector2(24, 24)
	hud.add_child(bar)
	bar.bind_inventory(Global.run_inventory)

	var tip: ItemTooltip = TOOLTIP.instantiate()
	hud.add_child(tip)
	tip.show_item(_item("conduit_lens"))
	tip.reset_size()
	tip.position = Vector2(220, 24)

	# The same icon at the sizes the UI uses, under the project default
	# (Linear Mipmap) and under plain Linear (what HubItemSlot forces).
	var sample := _item("conduit_charm")
	var x := 700.0
	for edge in LADDER:
		for row in 2:
			var trect := TextureRect.new()
			trect.texture = sample.data.icon if sample != null else null
			trect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			trect.position = Vector2(x, 40.0 + row * 150.0)
			trect.size = Vector2(edge, edge)
			if row == 1:
				trect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			hud.add_child(trect)
		x += float(edge) + 14.0

	var ground := Node2D.new()
	add_child(ground)
	var gx := 720.0
	for id_part: String in GROUND_ITEMS:
		var inst := _item(id_part)
		if inst == null:
			continue
		var pickup: ItemPickup = PICKUP.instantiate()
		pickup.item_instance = inst
		pickup.persistent_world_drop = true
		pickup.position = Vector2(gx, 560.0)
		ground.add_child(pickup)
		gx += 92.0
	# A dropped instance arms (and stops looking locked) after its drop delay.
	await _wait(2.0)
	await _shot("surfaces")
	_report("surfaces", self)
	hud.queue_free()
	ground.queue_free()
	floor_rect.queue_free()
	await _wait(0.2)
