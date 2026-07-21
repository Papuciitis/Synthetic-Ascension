extends Resource
class_name StashInventory

@export var slot_count: int = 24
@export var slots: Array[ItemInstance] = []

func _init() -> void:
	_ensure_size()

func _ensure_size() -> void:
	if slot_count <= 0:
		slot_count = 24
	if slots.size() != slot_count:
		slots.resize(slot_count)

func get_at(i: int) -> ItemInstance:
	_ensure_size()
	if i < 0 or i >= slots.size():
		return null
	return slots[i]

func remove_at(i: int) -> void:
	_ensure_size()
	if i < 0 or i >= slots.size():
		return
	slots[i] = null
	emit_changed()

# Duck-typed signature for routing/swap helpers.
# Keep origin optional (Inventory passes it; Bag doesn't).
func set_item(i: int, inst: ItemInstance, _origin: Variant = null) -> ItemInstance:
	_ensure_size()
	if i < 0 or i >= slots.size():
		return null
	var prev: ItemInstance = slots[i]
	slots[i] = inst
	emit_changed()
	return prev

func first_empty_slot() -> int:
	_ensure_size()
	for i in range(slots.size()):
		if slots[i] == null:
			return i
	return -1
