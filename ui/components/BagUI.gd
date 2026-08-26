extends PanelContainer
class_name BagUI

signal layout_changed
signal open_changed(is_open: bool)

const SIZE_CLOSED: Vector2 = Vector2(210, 78)
const SIZE_OPEN: Vector2 = Vector2(210, 260)

@export var slot_scene: PackedScene
@export var merge_ghost_time: float = 0.20
@export var toggle_action: StringName = &"bag_toggle"
@export var inv_bar_path: NodePath

@onready var vbox: VBoxContainer = $Margin/VBox
@onready var count_label: Label = $Margin/VBox/HeaderPill/HeaderMargin/Header/Count
@onready var quick_bar: HBoxContainer = $Margin/VBox/QuickBar
@onready var full_panel: PanelContainer = $Margin/VBox/FullPanel
@onready var grid: GridContainer = $Margin/VBox/FullPanel/FullMargin/Grid
@onready var merge_vfx: BagMergeVfx = get_node_or_null("MergeVfx") as BagMergeVfx

var _router: InventoryRouter = null
var _bag: BagInventory = null
var _core_inv: Inventory = null
var _inv_bar: InventoryBar = null

var _quick_slots: Array[BagSlot] = []
var _grid_slots: Array[BagSlot] = []

var _ghost_stacks: Dictionary = {} # int -> ItemInstance
var _ghost_ids: Dictionary = {}    # int -> int (instance_id)

# styles for slots (must be stored; we reuse them)
var _slot_sb_quick: StyleBoxFlat = null
var _slot_sb_grid: StyleBoxFlat = null


func _ready() -> void:
	_router = get_node_or_null("/root/InvRouter") as InventoryRouter
	if inv_bar_path != NodePath():
		_inv_bar = get_node_or_null(inv_bar_path) as InventoryBar
		
	_build_slot_styles()
	_build_slots()
	_apply_size()
	_refresh()

	# Always draw MergeVfx above the UI
	if merge_vfx != null:
		move_child(merge_vfx, get_child_count() - 1)
		merge_vfx.z_index = 999
		merge_vfx.z_as_relative = false


func is_open() -> bool:
	return full_panel != null and full_panel.visible


func bind_bag(bag: BagInventory) -> void:
	# Disconnect old bag signals
	if _bag != null:
		if _bag.changed.is_connected(_refresh):
			_bag.changed.disconnect(_refresh)
		if _bag.stack_merged.is_connected(_on_stack_merged):
			_bag.stack_merged.disconnect(_on_stack_merged)
		if _bag.stack_fed.is_connected(_on_stack_fed):
			_bag.stack_fed.disconnect(_on_stack_fed)
		if _bag.stack_added.is_connected(_on_stack_added):
			_bag.stack_added.disconnect(_on_stack_added)

	# Assign new bag
	_bag = bag

	# Connect new bag signals
	if _bag != null:
		if not _bag.changed.is_connected(_refresh):
			_bag.changed.connect(_refresh)
		if not _bag.stack_merged.is_connected(_on_stack_merged):
			_bag.stack_merged.connect(_on_stack_merged)
		if not _bag.stack_fed.is_connected(_on_stack_fed):
			_bag.stack_fed.connect(_on_stack_fed)
		if not _bag.stack_added.is_connected(_on_stack_added):
			_bag.stack_added.connect(_on_stack_added)

	# Bind router (if available)
	if _router != null and _bag != null:
		_router.bind_bag(_bag)

	_refresh()


func _on_stack_added(slot: int, inst: ItemInstance) -> void:
	if inst == null or merge_vfx == null:
		return

	var target: Control = _vfx_target_for_slot(slot)
	var origin: Variant = _consume_bag_origin()

	# allow VFX even if bag is closed (we want feedback)
	merge_vfx.call_deferred("play_feed", target, inst, true, false, origin)


func _on_stack_fed(slot: int, inst: ItemInstance, _roll_pct: float, upgraded: bool, _old_rarity: int) -> void:
	if inst == null or merge_vfx == null:
		return

	var target: Control = _vfx_target_for_slot(slot)
	var origin: Variant = _consume_bag_origin()

	merge_vfx.call_deferred("play_feed", target, inst, true, upgraded, origin)

func _consume_bag_origin() -> Variant:
	if _bag == null:
		return null

	if _bag.has_method("consume_pending_ui_origin"):
		var v: Variant = _bag.call("consume_pending_ui_origin")

		if v is Dictionary:
			return v

		if v is Vector2:
			return {"type": 1, "pos": v}

	return null


# IMPORTANT: call this from HUD.gd bind_inventory(inv)
func bind_core_inventory(inv: Inventory) -> void:
	_core_inv = inv

	if _router != null and _core_inv != null:
		_router.bind_equipped(_core_inv)


func _get_core_inventory() -> Inventory:
	if _core_inv != null:
		return _core_inv
	# fallback (still works if you rely on Global)
	return Global.run_inventory as Inventory


# ----------------------------
# build + styles
# ----------------------------

func _build_slot_styles() -> void:
	_slot_sb_quick = StyleBoxFlat.new()
	_slot_sb_quick.bg_color = Color(0, 0, 0, 0.25)
	_slot_sb_quick.border_color = Color(0.14, 0.14, 0.14, 1.0)
	_slot_sb_quick.set_border_width_all(2)
	_slot_sb_quick.corner_radius_top_left = 2
	_slot_sb_quick.corner_radius_top_right = 2
	_slot_sb_quick.corner_radius_bottom_left = 2
	_slot_sb_quick.corner_radius_bottom_right = 2

	_slot_sb_grid = StyleBoxFlat.new()
	_slot_sb_grid.bg_color = Color(0, 0, 0, 0.20)
	_slot_sb_grid.border_color = Color(0.14, 0.14, 0.14, 1.0)
	_slot_sb_grid.set_border_width_all(2)
	_slot_sb_grid.corner_radius_top_left = 2
	_slot_sb_grid.corner_radius_top_right = 2
	_slot_sb_grid.corner_radius_bottom_left = 2
	_slot_sb_grid.corner_radius_bottom_right = 2


func _style_slot(s: BagSlot, is_quick: bool) -> void:
	if s == null:
		return
	s.add_theme_stylebox_override("panel", (_slot_sb_quick if is_quick else _slot_sb_grid))


func _build_slots(grid_slot_count: int = BagInventory.SLOT_COUNT) -> void:
	if slot_scene == null:
		push_error("[BagUI] slot_scene is null (and fallback load failed)")
		return

	for c in quick_bar.get_children():
		c.queue_free()
	for c2 in grid.get_children():
		c2.queue_free()

	_quick_slots.clear()
	_grid_slots.clear()

	var cb_toggle := Callable(self, "_toggle_full")
	var cb_discard := Callable(self, "_on_discard_requested")
	var cb_equip := Callable(self, "_on_equip_requested")

	# 4 quick slots
	for i in range(4):
		var s: BagSlot = slot_scene.instantiate() as BagSlot
		quick_bar.add_child(s)
		_quick_slots.append(s)
		_style_slot(s, true)
		if not s.clicked.is_connected(cb_toggle):
			s.clicked.connect(cb_toggle)

	# Base slots plus any attempt-scoped Expanded Satchel slots.
	for j in range(maxi(BagInventory.SLOT_COUNT, grid_slot_count)):
		var g: BagSlot = slot_scene.instantiate() as BagSlot
		grid.add_child(g)
		_grid_slots.append(g)
		_style_slot(g, false)

		if not g.discard_requested.is_connected(cb_discard):
			g.discard_requested.connect(cb_discard)
		if not g.equip_requested.is_connected(cb_equip):
			g.equip_requested.connect(cb_equip)
		var cb_interact := Callable(self, "_on_slot_interaction")
		if not g.interaction_requested.is_connected(cb_interact):
			g.interaction_requested.connect(cb_interact)

	# clicking empty space in quick bar toggles too
	if not quick_bar.gui_input.is_connected(_on_quickbar_gui_input):
		quick_bar.gui_input.connect(_on_quickbar_gui_input)


func _on_quickbar_gui_input(ev: InputEvent) -> void:
	var mb: InputEventMouseButton = ev as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_toggle_full()


# ----------------------------
# open/close
# ----------------------------

func toggle_open() -> void:
	_toggle_full()


func set_open(v: bool) -> void:
	if full_panel == null:
		return
	if full_panel.visible == v:
		return
	full_panel.visible = v
	_notify_augment_input_lock(v)
	_apply_size()
	open_changed.emit(full_panel.visible)
	_refresh()


func _toggle_full() -> void:
	full_panel.visible = not full_panel.visible
	_notify_augment_input_lock(full_panel.visible)
	_apply_size()
	open_changed.emit(full_panel.visible)
	_refresh()


var _augment_lock_held: bool = false

func _notify_augment_input_lock(open: bool) -> void:
	# While the bag is open, number keys belong to the bag — not to active
	# augment hotkeys (pressing "2" mid-sort used to Hex-Blink the player).
	if open == _augment_lock_held:
		return
	_augment_lock_held = open
	if Global != null and Global.has_method("set_active_augment_input_locked"):
		Global.set_active_augment_input_locked(open)


func _exit_tree() -> void:
	_notify_augment_input_lock(false)


func _apply_size() -> void:
	var target: Vector2 = SIZE_CLOSED
	if full_panel.visible:
		var row_count: int = ceili(float(maxi(1, _grid_slots.size())) / 4.0)
		var extra_rows: int = maxi(0, row_count - 4)
		target = SIZE_OPEN + Vector2(0.0, float(extra_rows * 48))
	custom_minimum_size = target
	size = target
	layout_changed.emit()


func _vfx_target_for_slot(slot: int) -> Control:
	# When open, we can target the exact 4x4 slot.
	if is_open() and slot >= 0 and slot < _grid_slots.size():
		return _grid_slots[slot]

	# When closed, we don’t know where that stack appears (quick bar is “best 4”),
	# so we just aim at the bag area.
	if quick_bar != null:
		return quick_bar

	return self


# ----------------------------
# bag callbacks
# ----------------------------

func _on_discard_requested(slot_index: int) -> void:
	if _bag == null or _router == null:
		return

	# Use mouse position for now; world listener decides final spawn position
	var mouse: Vector2 = get_viewport().get_mouse_position()
	_router.drop_from(_bag, slot_index, mouse)


func _on_slot_interaction(slot_index: int, button: int, _double_click: bool, _shift: bool, ctrl: bool) -> void:
	# Lock toggling in the RUN bag, not just the hub screens: BagSlot
	# reserves Ctrl and refuses locked stacks, but nothing listened, so
	# locked items were silently inert in-run.
	if _bag == null or slot_index < 0 or slot_index >= _bag.get_slot_count():
		return
	var inst: ItemInstance = _bag.get_at(slot_index)
	if inst == null:
		return
	if ctrl and button == MOUSE_BUTTON_LEFT:
		inst.toggle_locked()
		if RunEvents != null and RunEvents.has_signal("tutorial_tip"):
			RunEvents.tutorial_tip.emit(
				"Item locked · protected from equip, discard and sale." if inst.locked else "Item unlocked.",
				2.0
			)
		_refresh()
	elif inst.locked and button == MOUSE_BUTTON_LEFT:
		if RunEvents != null and RunEvents.has_signal("tutorial_tip"):
			RunEvents.tutorial_tip.emit("Item locked · Ctrl-click to unlock.", 2.0)


func _on_equip_requested(bag_slot_index: int) -> void:
	if _bag == null:
		return
	if bag_slot_index < 0 or bag_slot_index >= _bag.get_slot_count():
		return

	var inv: Inventory = _get_core_inventory()
	if inv == null:
		push_warning("[BagUI] equip FAILED: core inventory not bound")
		return

	# --- bag -> equip origin (this is for UiFlyVfx on the inventory bar)
	var origin_screen: Vector2
	if is_open() and bag_slot_index >= 0 and bag_slot_index < _grid_slots.size() and _grid_slots[bag_slot_index] != null:
		var rr: Rect2 = _grid_slots[bag_slot_index].get_global_rect()
		origin_screen = rr.position + rr.size * 0.5
	else:
		var br: Rect2 = get_global_rect()
		origin_screen = br.position + br.size * 0.5

	# Tell Inventory where the item came from (so bag->equip flies)
	inv.set_pending_ui_origin_ui(origin_screen)

	# ------------------------------------------------------------
	# ✅ STEP 3: if this equip will SWAP, set bag origin from equip slot
	# so equip->bag VFX doesn't come from (0,0)
	# ------------------------------------------------------------
	var inst: ItemInstance = _bag.get_at(bag_slot_index)
	if inst != null and inst.data != null:
		var equip_slot: int = inst.data.equip_slot
		if equip_slot >= 0 and equip_slot < Inventory.SLOT_COUNT:
			var prev: ItemInstance = inv.get_at(equip_slot)
			if prev != null and _inv_bar != null:
				var equip_center: Vector2 = _inv_bar.get_slot_center_global(equip_slot)
				_bag.set_pending_ui_origin({"type": 1, "pos": equip_center})
	# ------------------------------------------------------------

	if _router != null:
		_router.bind_bag(_bag)
		_router.bind_equipped(inv)
		_router.equip_from_bag(_bag, bag_slot_index, inv) # <-- ONLY 3 args

func _on_stack_merged(from_slot: int, to_slot: int, src: ItemInstance) -> void:
	if src == null:
		return
	if from_slot < 0 or from_slot >= _grid_slots.size():
		return
	if to_slot < 0 or to_slot >= _grid_slots.size():
		return

	# ghost at "from"
	var id: int = src.get_instance_id()
	_ghost_stacks[from_slot] = src
	_ghost_ids[from_slot] = id

	_refresh()

	# VFX (defer so layout is correct)
	if merge_vfx != null:
		merge_vfx.call_deferred("play_merge", _grid_slots[from_slot], _grid_slots[to_slot], src, is_open())

	await get_tree().create_timer(merge_ghost_time).timeout
	if int(_ghost_ids.get(from_slot, 0)) == id:
		_ghost_ids.erase(from_slot)
		_ghost_stacks.erase(from_slot)
		_refresh()


func _set_inv_origin_from_bag_slot(bag_slot_index: int, inv: Inventory) -> void:
	if inv == null:
		return

	# Prefer the exact grid slot when bag is open.
	var origin_screen: Vector2
	if is_open() and bag_slot_index >= 0 and bag_slot_index < _grid_slots.size() and _grid_slots[bag_slot_index] != null:
		var r: Rect2 = _grid_slots[bag_slot_index].get_global_rect()
		origin_screen = r.position + r.size * 0.5
	else:
		# Fallback: center of the whole bag UI
		var br: Rect2 = get_global_rect()
		origin_screen = br.position + br.size * 0.5

	# Tell inventory UI where this item came from (Vector2 is enough)
	if inv.has_method("set_pending_ui_origin_ui"):
		inv.call("set_pending_ui_origin_ui", origin_screen)
	elif inv.has_method("set_pending_ui_origin"):
		inv.call("set_pending_ui_origin", origin_screen)


# ----------------------------
# refresh drawing
# ----------------------------

func _refresh() -> void:
	if count_label == null:
		return

	var desired_slots: int = BagInventory.SLOT_COUNT
	if _bag != null:
		desired_slots = _bag.get_slot_count()
	if desired_slots != _grid_slots.size():
		_build_slots(desired_slots)
		_apply_size()

	if _bag == null:
		count_label.text = "(0/%d)" % desired_slots
		# wipe UI
		for i in range(_quick_slots.size()):
			var ui: BagSlot = _quick_slots[i]
			if ui != null:
				ui.set_stack(null, -1, false)
		for j in range(_grid_slots.size()):
			var ui2: BagSlot = _grid_slots[j]
			if ui2 != null:
				ui2.set_stack(null, j, false)
		return

	# count used
	var used: int = 0
	for s in _bag.slots:
		if s != null and s.data != null:
			used += 1
	count_label.text = "(%d/%d)" % [used, desired_slots]

	# quick: 4 best stacks
	var quick: Array[ItemInstance] = _bag.get_best(4)
	for i in range(_quick_slots.size()):
		var ui: BagSlot = _quick_slots[i]
		var st: Variant = null
		if i < quick.size():
			st = quick[i]
		if ui != null:
			ui.set_stack(st, -1, false)

	# grid: exact slots (with ghost)
	var can_discard: bool = full_panel.visible
	for j in range(_grid_slots.size()):
		var ui2: BagSlot = _grid_slots[j]
		var st2: Variant = null

		if _ghost_stacks.has(j):
			st2 = _ghost_stacks[j]
		else:
			st2 = _bag.slots[j]

		if ui2 != null:
			var is_ghost: bool = _ghost_stacks.has(j)
			ui2.set_stack(st2, j, can_discard, is_ghost)
