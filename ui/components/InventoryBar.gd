extends GridContainer
class_name InventoryBar

signal slot_clicked(slot: int, button: int, double_click: bool, shift: bool)

@export var router_path: NodePath
@export var slot_scene: PackedScene = preload("res://ui/components/InventorySlotView.tscn")
@export_range(1, 8, 1) var grid_columns: int = 2
@export var allow_double_click_eject_always: bool = true

@export var fly_vfx_path: NodePath
var _fly_vfx: UiFlyVfx = null

var management_mode: bool = false

var _router: InventoryRouter = null
var _inv: Inventory = null
var _slots: Array[InventorySlotView] = []
var slot_count: int = Inventory.SLOT_COUNT

# Slots that should render as empty (visual-only; used by HubShop cart selection).
var _hidden_slots: Dictionary = {}  # int -> true

func set_hidden_slots(m: Dictionary) -> void:
	_hidden_slots = (m if m != null else {})
	_refresh()

# Hover frame styles (we apply them on the slot controls directly)
var _slot_style: Array[StyleBoxFlat] = []
var _hovered: Array[bool] = []

const BG := Color(0.08, 0.08, 0.08, 0.88)
const BG_HOVER := Color(0.10, 0.10, 0.10, 0.92)

const BORDER := Color(0.12, 0.12, 0.12, 1.0)
const BORDER_HOVER_STRONG := Color(1.0, 0.55, 0.20, 1.0)   # orange
const BORDER_HOVER_SOFT := Color(1.0, 0.55, 0.20, 0.55)

func set_fly_vfx(vfx: UiFlyVfx) -> void:
	_fly_vfx = vfx

func _ready() -> void:
	columns = maxi(1, grid_columns)
	_build_slots()
	_collect_slots()
	_refresh()

	_router = get_node_or_null("/root/InvRouter") as InventoryRouter
	if _router == null and router_path != NodePath():
		_router = get_node_or_null(router_path) as InventoryRouter

	_resolve_fly_vfx()
	call_deferred("_resolve_fly_vfx")

func _build_slots() -> void:
	# Scene-authored repeated slots were recovery-era debris. The data model is
	# authoritative, so changing Inventory.SLOT_COUNT cannot leave invisible UI.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	slot_count = Inventory.SLOT_COUNT
	for index in range(slot_count):
		var slot := slot_scene.instantiate() as InventorySlotView
		if slot == null:
			push_error("InventoryBar slot_scene root must be InventorySlotView")
			return
		slot.name = "Slot_%02d_%s" % [index, String(Inventory.slot_definition(index).get("id", &"slot"))]
		slot.slot_index = index
		slot.slot_hint = Inventory.slot_hint(index)
		slot.tooltip_text = "%s equipment slot" % Inventory.slot_label(index)
		slot.drag_host = _find_drag_host()
		add_child(slot)

func _find_drag_host() -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method("can_drop_item") and node.has_method("handle_drop_item"):
			return node
		node = node.get_parent()
	return null

func bind_inventory(inv: Inventory) -> void:
	# disconnect old
	if _inv != null:
		var cb_refresh := Callable(self, "_refresh")
		if _inv.changed.is_connected(cb_refresh):
			_inv.changed.disconnect(cb_refresh)

		var cb_set := Callable(self, "_on_inv_slot_set")
		if _inv.has_signal("slot_set") and _inv.is_connected("slot_set", cb_set):
			_inv.disconnect("slot_set", cb_set)

		var cb_fed := Callable(self, "_on_inv_slot_fed")
		if _inv.has_signal("slot_fed") and _inv.is_connected("slot_fed", cb_fed):
			_inv.disconnect("slot_fed", cb_fed)

	_inv = inv

	# connect new
	if _inv != null:
		var cb_refresh2 := Callable(self, "_refresh")
		if not _inv.changed.is_connected(cb_refresh2):
			_inv.changed.connect(cb_refresh2)

		# THESE are what you lost — and they are exactly the “collect/upgrade feedback” pipeline
		var cb_set2 := Callable(self, "_on_inv_slot_set")
		if _inv.has_signal("slot_set") and not _inv.is_connected("slot_set", cb_set2):
			_inv.connect("slot_set", cb_set2)

		var cb_fed2 := Callable(self, "_on_inv_slot_fed")
		if _inv.has_signal("slot_fed") and not _inv.is_connected("slot_fed", cb_fed2):
			_inv.connect("slot_fed", cb_fed2)

	_refresh()

func set_management_mode(v: bool) -> void:
	if management_mode == v:
		return
	management_mode = v
	_apply_all_slot_styles()

func _collect_slots() -> void:
	_slots.clear()
	_slot_style.clear()
	_hovered.clear()

	for ch: Node in get_children():
		var s: InventorySlotView = ch as InventorySlotView
		if s == null:
			continue

		s.slot_index = _slots.size()
		_slots.append(s)

		# click signal from slot view
		var cb_click := Callable(self, "_on_slot_clicked")
		if not s.clicked.is_connected(cb_click):
			s.clicked.connect(cb_click)

		# hover (orange border)
		var idx: int = s.slot_index
		var c: Control = s as Control

		_hovered.append(false)
		var st := _make_slot_style()
		_slot_style.append(st)
		c.add_theme_stylebox_override("panel", st)

		var cb_ent := Callable(self, "_on_slot_mouse_entered").bind(idx)
		if not c.mouse_entered.is_connected(cb_ent):
			c.mouse_entered.connect(cb_ent)

		var cb_ext := Callable(self, "_on_slot_mouse_exited").bind(idx)
		if not c.mouse_exited.is_connected(cb_ext):
			c.mouse_exited.connect(cb_ext)

		# apply initial style (will be corrected again in _refresh once inv is bound)
		_apply_slot_style(idx)

	# clamp safety
	if _slots.size() > slot_count:
		_slots.resize(slot_count)
		_slot_style.resize(slot_count)
		_hovered.resize(slot_count)

func _make_slot_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_color = BORDER
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	return sb

func _apply_all_slot_styles() -> void:
	for i in range(_slot_style.size()):
		_apply_slot_style(i)

func _apply_slot_style(i: int) -> void:
	if i < 0 or i >= _slot_style.size():
		return

	var sb: StyleBoxFlat = _slot_style[i]
	var is_hovered: bool = (i < _hovered.size() and _hovered[i])
	var has_item: bool = false
	var rarity: int = 0

	if _inv != null and i < slot_count:
		var inst: ItemInstance = _inv.get_at(i) as ItemInstance
		has_item = (inst != null and inst.data != null)
		if inst != null:
			rarity = int(inst.rarity)

	# Orange border only when hovering an item
	if is_hovered and has_item:
		sb.border_color = BORDER_HOVER_STRONG
	elif is_hovered:
		sb.border_color = BORDER_HOVER_SOFT
	else:
		if has_item and rarity != 0:
			sb.border_color = BORDER.lerp(_rarity_border_tint(rarity), 0.35)
		else:
			sb.border_color = BORDER

	sb.bg_color = (BG_HOVER if is_hovered else BG)

func _rarity_border_tint(r: int) -> Color:
	if r <= -2: return Color(0.45, 0.0, 0.0, 1)
	if r == -1: return Color(0.75, 0.1, 0.1, 1)
	if r == 0:  return BORDER
	if r == 1:  return Color(0.2, 0.9, 0.2, 1)
	if r == 2:  return Color(0.25, 0.45, 1.0, 1)
	if r == 3:  return Color(0.7, 0.25, 0.95, 1)
	return Color(1.0, 0.65, 0.15, 1)


func _on_slot_mouse_entered(slot: int) -> void:
	if slot >= 0 and slot < _hovered.size():
		_hovered[slot] = true
	_apply_slot_style(slot)

func _on_slot_mouse_exited(slot: int) -> void:
	if slot >= 0 and slot < _hovered.size():
		_hovered[slot] = false
	_apply_slot_style(slot)

func _resolve_fly_vfx() -> void:
	if _fly_vfx != null:
		return

	# 1) explicit path
	if fly_vfx_path != NodePath():
		_fly_vfx = get_node_or_null(fly_vfx_path) as UiFlyVfx
		if _fly_vfx != null:
			return

	# 2) group lookup (works after FlyVfx entered tree)
	var arr: Array[Node] = get_tree().get_nodes_in_group("ui_fly_vfx")
	if arr.size() > 0:
		_fly_vfx = arr[0] as UiFlyVfx

func _refresh() -> void:
	for i in range(_slots.size()):
		var inst: ItemInstance = (_inv.get_at(i) if _inv != null else null) as ItemInstance

		# Visual-only hide
		if _hidden_slots.has(i):
			inst = null
		var s: InventorySlotView = _slots[i]

		# keep meta for tooltip controller (works regardless of slot internals)
		if s != null:
			if s.has_meta("item_instance"):
				s.remove_meta("item_instance")
			if inst != null:
				s.set_meta("item_instance", inst)

			s.set_item(inst)

		# IMPORTANT: style depends on inventory contents (rarity tint etc.)
		_apply_slot_style(i)

func get_slot_center_global(slot: int) -> Vector2:
	var c := get_slot_control(slot)
	if c == null:
		return Vector2.ZERO
	var r: Rect2 = c.get_global_rect()
	return r.position + r.size * 0.5

func get_slot_control(slot: int) -> Control:
	if slot < 0 or slot >= _slots.size():
		return null
	return _slots[slot] as Control

# ----------------------------
# Restored behaviors you asked for
# ----------------------------

func _on_slot_clicked(slot: int, button: int, double_click: bool, shift: bool) -> void:
	# Double-click (LMB) eject to bag
	if double_click and button == MOUSE_BUTTON_LEFT:
		if management_mode or allow_double_click_eject_always:
			_move_equipped_to_bag(slot)
		slot_clicked.emit(slot, button, double_click, shift)
		return

	# Shift + Right click drop (management mode only)
	if button == MOUSE_BUTTON_RIGHT and shift and management_mode:
		_drop_equipped_to_world(slot)
		slot_clicked.emit(slot, button, double_click, shift)
		return

	slot_clicked.emit(slot, button, double_click, shift)

func _move_equipped_to_bag(slot: int) -> void:
	if _inv == null or _router == null:
		return

	var p: Control = get_slot_control(slot)
	if p == null:
		return
	var r: Rect2 = p.get_global_rect()
	var origin_screen: Vector2 = r.position + r.size * 0.5

	_router.bind_equipped(_inv)
	_router.eject_equipped_to_bag(slot, {"type": 1, "pos": origin_screen})

func _drop_equipped_to_world(slot: int) -> void:
	if _inv == null or _router == null:
		return

	_router.bind_equipped(_inv)
	var mouse: Vector2 = get_viewport().get_mouse_position()
	_router.drop_from(_inv, slot, mouse)

# ----------------------------
# Restored “collect/upgrade feedback”
# ----------------------------

func _on_inv_slot_set(slot: int, inst: ItemInstance, _prev: ItemInstance, origin: Dictionary) -> void:
	if _fly_vfx == null:
		return
	if inst == null:
		return
	if not origin.has("pos") or not (origin["pos"] is Vector2):
		return

	var target: Control = get_slot_control(slot)
	if target == null:
		return

	_fly_vfx.call_deferred("fly_to", target, inst, origin["pos"], false)

func _on_inv_slot_fed(slot: int, inst: ItemInstance, upgraded: bool, _old_rarity: int, origin: Dictionary) -> void:
	if _fly_vfx == null:
		return
	if inst == null:
		return
	if not origin.has("pos") or not (origin["pos"] is Vector2):
		return

	var target: Control = get_slot_control(slot)
	if target == null:
		return

	_fly_vfx.call_deferred("fly_to", target, inst, origin["pos"], upgraded)
