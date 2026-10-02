extends GridContainer
class_name ShopBagGrid
## A bag shown as a grid of slots, for the Exchange only: the backpack, the
## Exchanger's stock and the two pans of the Balance.
##
## The slots are the shared BagSlot scene; the Exchange dresses its own
## instances (a square, gold-ruled socket; brighter under the cursor) by
## setting a stylebox override on each, so the in-run bag keeps its look.
## fit_within() picks a slot size and column count that fill a given area.

const ExchangeStyle := preload("res://ui/widgets/exchange/ExchangeStyle.gd")

signal slot_clicked(slot: int, button: int, double_click: bool, shift: bool, ctrl: bool)

@export var slot_scene: PackedScene = preload("res://ui/bag/BagSlot.tscn")
@export var slot_count: int = 16
## A pan of the Balance: its empty slots are faint sockets.
@export var pan: bool = false
## Gap between slots, px.
@export var gap: int = 10
## Side of a slot, px; 0 keeps the slot scene's own size.
@export var cell_size: float = 0.0:
	set(value):
		if is_equal_approx(cell_size, value):
			return
		cell_size = value
		_apply_cell_size()

var _bag: BagInventory = null
var _slots: Array[BagSlot] = []
## What each slot is showing (ExchangeStyle.Slot), so a style is only set
## when it changes.
var _styled: Array[int] = []
var _hovered := -1

# Slots that should render as empty (visual-only).
var _hidden_slots: Dictionary = {}  # int -> true

func set_hidden_slots(m: Dictionary) -> void:
	_hidden_slots = (m if m != null else {})
	_refresh_slots_only()
var _building_slots: bool = false

func _ready() -> void:
	columns = 4
	add_theme_constant_override(&"h_separation", gap)
	add_theme_constant_override(&"v_separation", gap)
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


## Chooses the largest slot (up to `max_cell`) and a column count in
## [min_cols, max_cols] so `count` slots fit inside `area`; never below
## `min_cell`. Fewer columns win a tie.
func fit_within(area: Vector2, count: int, max_cell: float, min_cell: float, min_cols: int = 4, max_cols: int = 6) -> void:
	if area.x <= 0.0 or area.y <= 0.0:
		return
	var best_cell := -1.0
	var best_cols := clampi(columns, min_cols, max_cols)
	for cols in range(min_cols, max_cols + 1):
		var rows := ceili(float(maxi(1, count)) / float(cols))
		var by_w := (area.x - float((cols - 1) * gap)) / float(cols)
		var by_h := (area.y - float((rows - 1) * gap)) / float(rows)
		var cell := floorf(minf(max_cell, minf(by_w, by_h)))
		if cell > best_cell + 0.5:
			best_cell = cell
			best_cols = cols
	if columns != best_cols:
		columns = best_cols
	cell_size = maxf(min_cell, best_cell)


func _apply_cell_size() -> void:
	if cell_size <= 0.0:
		return
	var s := Vector2(cell_size, cell_size)
	for slot in _slots:
		if slot != null and slot.custom_minimum_size != s:
			slot.custom_minimum_size = s

func _build_slots() -> void:
	if _building_slots:
		return
	_building_slots = true

	for c in get_children():
		c.queue_free()

	_slots.clear()
	_styled.clear()
	_hovered = -1

	for i in range(slot_count):
		var s: BagSlot = slot_scene.instantiate() as BagSlot
		add_child(s)
		_slots.append(s)
		_styled.append(-1)

		# Capture index (avoid closure capturing the loop var)
		var slot_i: int = i
		s.interaction_requested.connect(func(_idx: int, button: int, double_click: bool, shift: bool, ctrl: bool) -> void:
			slot_clicked.emit(slot_i, button, double_click, shift, ctrl)
		)
		s.mouse_entered.connect(func() -> void: _set_hovered(slot_i, true))
		s.mouse_exited.connect(func() -> void: _set_hovered(slot_i, false))
		if pan:
			s.draw.connect(func() -> void: _draw_socket(slot_i))

	_building_slots = false
	_apply_cell_size()
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
		_style_slot(i)


func _shown_item(i: int) -> bool:
	if _bag == null or i < 0 or i >= _bag.slots.size() or _hidden_slots.has(i):
		return false
	return _bag.slots[i] != null


func _set_hovered(i: int, on: bool) -> void:
	if on:
		_hovered = i
	elif _hovered == i:
		_hovered = -1
	_style_slot(i)


func _style_slot(i: int) -> void:
	if i < 0 or i >= _slots.size():
		return
	var filled := _shown_item(i)
	var state: int = ExchangeStyle.Slot.FILLED if filled else (ExchangeStyle.Slot.PAN_EMPTY if pan else ExchangeStyle.Slot.EMPTY)
	if filled and _bag.slots[i] is ItemInstance and (_bag.slots[i] as ItemInstance).locked:
		state = ExchangeStyle.Slot.LOCKED
	if filled and _hovered == i:
		state = ExchangeStyle.Slot.HOVER
	if _styled[i] == state:
		return
	_styled[i] = state
	_slots[i].add_theme_stylebox_override(&"panel", ExchangeStyle.slot(state))
	if pan:
		_slots[i].queue_redraw()


## An empty pan socket carries a small engraved diamond.
func _draw_socket(i: int) -> void:
	if i < 0 or i >= _slots.size() or _shown_item(i):
		return
	var s := _slots[i]
	var c := s.size * 0.5
	var pts := ExchangeStyle.diamond(c, 4.0)
	pts.append(pts[0])
	s.draw_polyline(pts, Color(ExchangeStyle.GOLD_DIM, 0.32), 1.0, true)
