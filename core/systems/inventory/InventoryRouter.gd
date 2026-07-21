extends Node
class_name InventoryRouter

signal dropped_to_world(inst: ItemInstance, world_pos: Vector2)

# One place to observe all routing (UI can listen, debug can listen)
# action examples: &"equip_to_bag", &"bag_to_equip", &"drop"
signal ui_item_routed(action: StringName, inst: ItemInstance, info: Dictionary)

var equipped: Inventory = null
var bag: Object = null # BagInventory (duck typed)

const ORIGIN_SCREEN := 1

func bind_equipped(inv: Inventory) -> void:
	equipped = inv

func bind_bag(bag_inv: Object) -> void:
	bag = bag_inv

# --------------------------
# Helpers
# --------------------------

func _norm_origin(origin: Variant) -> Dictionary:
	# Accept {"type": int, "pos": Vector2}
	if origin is Dictionary:
		var d: Dictionary = origin
		if d.has("pos") and d["pos"] is Vector2:
			return {"type": int(d.get("type", ORIGIN_SCREEN)), "pos": d["pos"]}

	# Accept Vector2
	if origin is Vector2:
		return {"type": ORIGIN_SCREEN, "pos": origin}

	return {}

func _bag_set_origin(origin: Variant) -> void:
	if bag == null:
		return
	if bag.has_method("set_pending_ui_origin"):
		bag.call("set_pending_ui_origin", origin)

func _bag_clear_origin() -> void:
	if bag == null:
		return
	if bag.has_method("set_pending_ui_origin"):
		bag.call("set_pending_ui_origin", null)

func _emit_ui(action: StringName, inst: ItemInstance, info: Dictionary) -> void:
	ui_item_routed.emit(action, inst, info)

# --------------------------
# High level operations
# --------------------------

func eject_equipped_to_bag(slot: int, origin: Variant = null) -> bool:
	if equipped == null or bag == null:
		return false

	var inst: ItemInstance = equipped.get_at(slot) as ItemInstance
	if inst == null:
		return false

	# set bag VFX origin (so bag plays "fly in" from equip slot)
	if origin != null and bag.has_method("set_pending_ui_origin"):
		bag.call("set_pending_ui_origin", origin)

	# remove first, then rollback if add fails
	equipped.remove_at(slot)

	var ok: bool = _bag_add_instance(inst)
	if not ok:
		equipped.set_item(slot, inst) # rollback
		return false

	return true

func equip_from_bag(bag_inv: BagInventory, bag_slot_index: int, inv: Inventory, origin: Variant = null) -> bool:
	if bag_inv == null or inv == null:
		return false
	if bag_slot_index < 0 or bag_slot_index >= bag_inv.get_slot_count():
		return false

	var inst: ItemInstance = bag_inv.get_at(bag_slot_index)
	if inst == null or inst.data == null:
		return false

	# Prefer deterministic equip slot if the item defines it
	var equip_slot: int = -1
	var ev: Variant = inst.data.get("equip_slot")
	if ev is int or ev is float:
		equip_slot = int(ev)

	if equip_slot >= 0 and equip_slot < Inventory.SLOT_COUNT:
		# Free bag slot first
		bag_inv.remove_at(bag_slot_index)

		# IMPORTANT: pass origin into set_item so InventoryBar gets slot_set signal w/ origin
		var prev: ItemInstance = inv.set_item(equip_slot, inst, origin)

		if prev != null and prev.data != null:
			var ok_bag: bool = bag_inv.add_instance(prev)
			if not ok_bag:
				# rollback if bag full
				inv.set_item(equip_slot, prev)
				bag_inv.set_at(bag_slot_index, inst)
				return false

		return true

	# Fallback: add to first empty OR feed (pass origin so it can animate)
	var ok_inv: bool = inv.add_or_feed(inst, origin)
	if ok_inv:
		bag_inv.remove_at(bag_slot_index)
	return ok_inv

func move_between(src_inv: Object, src_i: int, dst_inv: Object, dst_i: int, origin: Variant = null) -> bool:
	if src_inv == null or dst_inv == null:
		return false
	if not src_inv.has_method("get_at"): return false
	if not src_inv.has_method("remove_at"): return false
	if not dst_inv.has_method("get_at"): return false
	if not dst_inv.has_method("set_item"): return false

	var inst: ItemInstance = src_inv.call("get_at", src_i) as ItemInstance
	if inst == null:
		return false

	# Block swapping between equipped slots entirely (items are fixed-slot anyway).
	if (src_inv is Inventory) and (dst_inv is Inventory):
		return false

	var dst: ItemInstance = dst_inv.call("get_at", dst_i) as ItemInstance

	# If moving INTO equipped inventory, enforce strict slot match.
	if dst_inv is Inventory:
		if inst.data == null:
			return false
		if int(inst.data.equip_slot) != int(dst_i):
			return false

	# CRITICAL: If moving FROM equipped inventory into an occupied non-equipped slot,
	# never swap back unless the destination item is valid for the equipped slot.
	if (src_inv is Inventory) and dst != null:
		var can_swap_back := (dst.data != null and int(dst.data.equip_slot) == int(src_i))
		if not can_swap_back:
			# Prefer moving to an empty slot in the destination container to avoid corrupting equipped slots.
			if dst_inv.has_method("first_empty_slot"):
				var alt: int = int(dst_inv.call("first_empty_slot"))
				if alt >= 0:
					dst_i = alt
					dst = dst_inv.call("get_at", dst_i) as ItemInstance
				else:
					return false
			else:
				return false

	# Perform the move.
	dst_inv.call("set_item", dst_i, inst, origin)
	src_inv.call("remove_at", src_i)

	# Swap back only if safe.
	if dst != null:
		src_inv.call("set_item", src_i, dst)

	_emit_ui(&"move_between", inst, {
		"from_i": src_i,
		"to_i": dst_i,
		"origin": _norm_origin(origin),
	})

	return true

func drop_from(src_inv: Object, src_i: int, world_pos: Vector2) -> bool:
	if src_inv == null or not src_inv.has_method("get_at") or not src_inv.has_method("remove_at"):
		return false

	var inst: ItemInstance = src_inv.call("get_at", src_i) as ItemInstance
	if inst == null:
		return false

	src_inv.call("remove_at", src_i)
	dropped_to_world.emit(inst, world_pos)

	_emit_ui(&"drop", inst, {
		"from_i": src_i,
		"world_pos": world_pos,
	})

	return true

# --------------------------
# Bag duck typing helpers
# --------------------------

func _bag_add_instance(inst: ItemInstance) -> bool:
	if bag == null:
		return false

	if bag.has_method("add_instance"):
		return bool(bag.call("add_instance", inst))

	if bag.has_method("add_item"):
		return bool(bag.call("add_item", inst))

	if bag.has_method("first_empty_slot") and bag.has_method("set_item"):
		var idx: int = int(bag.call("first_empty_slot"))
		if idx == -1:
			return false
		bag.call("set_item", idx, inst)
		return true

	return false
