extends Node
class_name HudInventoryController

# --- Toggle debug without spamming release ---
const DEBUG: bool = false
func _d(msg: String) -> void:
	if DEBUG:
		print(msg)

@export var inv_bar_path: NodePath
@export var router_path: NodePath
@export var fly_vfx_path: NodePath

# Behaviour flags
@export var allow_double_click_eject_always: bool = true

var _router: InventoryRouter = null
var _fly_vfx: UiFlyVfx = null
var _inv_bar: InventoryBar = null
var _inv: Inventory = null

var _management_mode: bool = false


func _ready() -> void:
	_resolve_router()
	_resolve_inv_bar()
	_resolve_fly_vfx()

	# Hook slot clicks
	if _inv_bar != null:
		var cb: Callable = Callable(self, "_on_inv_bar_slot_clicked")
		if not _inv_bar.slot_clicked.is_connected(cb):
			_inv_bar.slot_clicked.connect(cb)

	# Fallback bind if you forget to call bind_inventory()
	if _inv == null and Global != null:
		var ginv: Inventory = Global.run_inventory as Inventory
		if ginv != null:
			bind_inventory(ginv)


# ----------------------------
# Public API (HUD calls these)
# ----------------------------

func bind_inventory(inv: Inventory) -> void:
	# disconnect old
	if _inv != null:
		_disconnect_inventory_signals(_inv)

	_inv = inv

	if _inv_bar != null and _inv != null:
		_inv_bar.bind_inventory(_inv)

	if _inv != null:
		_connect_inventory_signals(_inv)

	_d("[HudInv] bound inv=%s" % str(_inv))

func set_management_mode(v: bool) -> void:
	_management_mode = v
	if _inv_bar != null:
		_inv_bar.set_management_mode(v)


# ----------------------------
# Resolve refs
# ----------------------------

func _resolve_router() -> void:
	_router = get_node_or_null("/root/InvRouter") as InventoryRouter
	if _router == null and router_path != NodePath():
		_router = get_node_or_null(router_path) as InventoryRouter
	if _router == null:
		push_warning("[HudInv] InventoryRouter not found (expected /root/InvRouter or router_path).")

func _resolve_inv_bar() -> void:
	if inv_bar_path != NodePath():
		_inv_bar = get_node_or_null(inv_bar_path) as InventoryBar
	if _inv_bar == null:
		# fallback: search under parent (HUD)
		var p: Node = get_parent()
		if p != null:
			_inv_bar = p.find_child("InventoryBar", true, false) as InventoryBar
	if _inv_bar == null:
		push_warning("[HudInv] InventoryBar not found. Set inv_bar_path.")

func _resolve_fly_vfx() -> void:
	if fly_vfx_path != NodePath():
		_fly_vfx = get_node_or_null(fly_vfx_path) as UiFlyVfx

	# fallback: group
	if _fly_vfx == null:
		var arr: Array[Node] = get_tree().get_nodes_in_group("ui_fly_vfx")
		if arr.size() > 0:
			_fly_vfx = arr[0] as UiFlyVfx

	if _fly_vfx == null:
		push_warning("[HudInv] UiFlyVfx not found. Set fly_vfx_path or add node to group 'ui_fly_vfx'.")


# ----------------------------
# Slot click handling
# ----------------------------

func _on_inv_bar_slot_clicked(slot: int, button: int, double_click: bool, shift: bool) -> void:
	if _inv == null or _router == null:
		return

	# Double-click (LMB) => eject to bag
	if button == MOUSE_BUTTON_LEFT and double_click:
		if _management_mode or allow_double_click_eject_always:
			_eject_equipped_to_bag(slot)
		return

	# Shift + Right click => drop to world (management only)
	if button == MOUSE_BUTTON_RIGHT and shift and _management_mode:
		_drop_equipped_to_world(slot)
		return


func _eject_equipped_to_bag(slot: int) -> void:
	if _inv == null or _router == null:
		return

	var inst: ItemInstance = _inv.get_at(slot) as ItemInstance
	if inst == null:
		return

	var origin_screen: Vector2 = _slot_center(slot)

	_router.bind_equipped(_inv)
	_router.eject_equipped_to_bag(slot, {"type": 1, "pos": origin_screen})
	_d("[HudInv] eject slot=%d origin=%s" % [slot, str(origin_screen)])


func _drop_equipped_to_world(slot: int) -> void:
	if _inv == null or _router == null:
		return

	var inst: ItemInstance = _inv.get_at(slot) as ItemInstance
	if inst == null:
		return

	_router.bind_equipped(_inv)

	var mouse: Vector2 = get_viewport().get_mouse_position()
	_router.drop_from(_inv, slot, mouse)
	_d("[HudInv] drop slot=%d mouse=%s" % [slot, str(mouse)])


func _slot_center(slot: int) -> Vector2:
	if _inv_bar != null:
		return _inv_bar.get_slot_center_global(slot)
	return Vector2.ZERO


# ----------------------------
# Inventory -> VFX hooks
# ----------------------------

func _connect_inventory_signals(inv: Inventory) -> void:
	# slot_set(slot, inst, prev, origin: Dictionary)
	if inv.has_signal("slot_set"):
		var cb_set: Callable = Callable(self, "_on_inv_slot_set")
		if not inv.is_connected("slot_set", cb_set):
			inv.connect("slot_set", cb_set)

	# slot_fed(slot, inst, upgraded, old_rarity, origin: Dictionary)
	if inv.has_signal("slot_fed"):
		var cb_fed: Callable = Callable(self, "_on_inv_slot_fed")
		if not inv.is_connected("slot_fed", cb_fed):
			inv.connect("slot_fed", cb_fed)

func _disconnect_inventory_signals(inv: Inventory) -> void:
	if inv.has_signal("slot_set"):
		var cb_set: Callable = Callable(self, "_on_inv_slot_set")
		if inv.is_connected("slot_set", cb_set):
			inv.disconnect("slot_set", cb_set)

	if inv.has_signal("slot_fed"):
		var cb_fed: Callable = Callable(self, "_on_inv_slot_fed")
		if inv.is_connected("slot_fed", cb_fed):
			inv.disconnect("slot_fed", cb_fed)


func _on_inv_slot_set(slot: int, inst: ItemInstance, _prev: ItemInstance, origin: Dictionary) -> void:
	if _fly_vfx == null or _inv_bar == null:
		return
	if inst == null:
		return
	if not origin.has("pos"):
		return
	var p: Variant = origin["pos"]
	if not (p is Vector2):
		return

	var target: Control = _inv_bar.get_slot_control(slot)
	if target == null:
		return

	# defer so layout is stable
	_fly_vfx.call_deferred("fly_to", target, inst, p, false)


func _on_inv_slot_fed(slot: int, inst: ItemInstance, upgraded: bool, _old_rarity: int, origin: Dictionary) -> void:
	if _fly_vfx == null or _inv_bar == null:
		return
	if inst == null:
		return
	if not origin.has("pos"):
		return
	var p: Variant = origin["pos"]
	if not (p is Vector2):
		return

	var target: Control = _inv_bar.get_slot_control(slot)
	if target == null:
		return

	_fly_vfx.call_deferred("fly_to", target, inst, p, upgraded)
