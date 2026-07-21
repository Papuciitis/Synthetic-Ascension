extends MajorChoiceEffect
class_name MCE_AddBackpackSlots

@export var amount: int = 4

func can_apply(g: Node) -> bool:
	return g != null and g.get("run_bag") != null

func apply(g: Node) -> void:
	var bag: BagInventory = g.get("run_bag") as BagInventory
	if bag == null:
		return
	bag.extra_slots = maxi(0, int(bag.extra_slots) + amount)
	bag._ensure_size()
	bag.emit_changed()

func get_preview_lines(_g: Node) -> PackedStringArray:
	var out := PackedStringArray()
	var n := maxi(0, amount)
	if n == 0:
		return out
	out.append("• +%d Backpack slot%s" % [n, ("" if n == 1 else "s")])
	return out
