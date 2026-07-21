extends GridContainer
class_name ShopBagGrid

signal slot_clicked(slot: int)

@export var slot_scene: PackedScene = preload("res://ui/bag/BagSlot.tscn")
@export var slot_count: int = 16

var _bag: BagInventory = null
var _slots: Array[BagSlot] = []

# Slots that should render as empty (visual-only).
var _hidden_slots: Dictionary = {}  # int -> true

func set_hidden_slots(m: Dictionary) -> void:
	_hidden_slots = (m if m != null else {})
	_refresh_slots_only()
var _building_slots: bool = false

func _ready() -> void:
	columns = 4
	_build_slots()

func bind_bag(bag: BagInventory) -> void:
	if _bag != null:
		var cb := Callable(self, "_refresh")
		if _bag.changed.is_connected(cb):
			_bag.changed.disconnect(cb)

	_bag = bag

	if _bag != null:
		var cb2 := Callable(self, "_refresh")
		if not _bag.changed.is_connected(cb2):
			_bag.changed.connect(cb2)

	_refresh()

func get_slot_control(i: int) -> Control:
	if i < 0 or i >= _slots.size():
		return null
	return _slots[i] as Control

func _build_slots() -> void:
	if _building_slots:
		return
	_building_slots = true

	for c in get_children():
		c.queue_free()

	_slots.clear()

	for i in range(slot_count):
		var s: BagSlot = slot_scene.instantiate() as BagSlot
		add_child(s)
		_slots.append(s)

		# Capture index (avoid closure capturing the loop var)
		var slot_i: int = i
		s.equip_requested.connect(func(_idx: int) -> void:
			slot_clicked.emit(slot_i)
		)

	_building_slots = false
	_refresh_slots_only()

func _refresh() -> void:
	var desired_count: int = slot_count
	if _bag != null:
		_bag._ensure_size()
		desired_count = _bag.slots.size()

	if desired_count != slot_count:
		slot_count = desired_count
		_build_slots()
		return

	_refresh_slots_only()

func _refresh_slots_only() -> void:
	for i in range(_slots.size()):
		var inst: ItemInstance = null
		if _bag != null and i < _bag.slots.size():
			inst = _bag.slots[i]

		# Visual-only hide (used by HubShop cart selection to avoid "duplicate" feel).
		if _hidden_slots.has(i):
			inst = null

		_slots[i].set_stack(inst, i, false, false)
