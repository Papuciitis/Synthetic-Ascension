extends Node
class_name HudTooltipController

@export var tooltip_scene: PackedScene
@export var inv_bar_path: NodePath
@export var bag_ui_path: NodePath            # point to BagUI (Control) OR leave empty
@export var bag_controller_path: NodePath    # point to HudBagController OR leave empty
@export var run_sheet_path: NodePath

var _inv_bar: Node = null
var _bag_ui: Control = null
var _bag_ctl: Node = null
var _run_sheet: Control = null

var _tooltip: Control = null
var _management_mode: bool = false

# --- what the tooltip currently shows -------------------------------------
# ItemTooltip.show_item() formats every line, joins them, sets a RichTextLabel
# and calls reset_size(); the placement step then measures the Control
# again. Doing that on every hovered frame rebuilt an identical tooltip 60
# times a second. The key is the hovered CONTROL and the ITEM in it, not just
# the item: swapping two stacks in a paused bag leaves the cursor over the same
# slot with a different instance, and dragging one item across two slots leaves
# the same instance under a different slot.
var _shown_source_id: int = 0
var _shown_item_id: int = 0
var _shown_source_rect: Rect2 = Rect2()
var _hooked_inventory: Object = null
var _hooked_bag: Object = null
## Tooltip rebuilds since this controller was created. The idle-cost pin reads
## it; nothing in the game does.
var _rebuilds: int = 0


func _ready() -> void:
	_inv_bar = (get_node_or_null(inv_bar_path) if inv_bar_path != NodePath() else null)
	_bag_ui = (get_node_or_null(bag_ui_path) as Control if bag_ui_path != NodePath() else null)
	_bag_ctl = (get_node_or_null(bag_controller_path) if bag_controller_path != NodePath() else null)
	_run_sheet = (get_node_or_null(run_sheet_path) as Control if run_sheet_path != NodePath() else null)

	# Defer, because parent is still instancing children when this _ready runs.
	call_deferred("_ensure_tooltip")
	set_process(true)


func _ensure_tooltip() -> void:
	if _tooltip != null and is_instance_valid(_tooltip):
		return
	if tooltip_scene == null:
		push_warning("[HudTooltipController] tooltip_scene is null")
		return

	var inst := tooltip_scene.instantiate()
	var tip := inst as Control
	if tip == null:
		push_warning("[HudTooltipController] tooltip scene root is not a Control")
		return

	tip.visible = false
	tip.z_index = 999
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# IMPORTANT: defer add_child to avoid: Parent node is busy setting up children
	var parent := get_parent()
	if parent != null:
		parent.call_deferred("add_child", tip)
	else:
		call_deferred("add_child", tip)

	_tooltip = tip
	_apply_dossier_mode()


func set_management_mode(enabled: bool) -> void:
	_management_mode = enabled
	_apply_dossier_mode()
	# Also drops the shown-item cache: the dossier lays the same item out
	# differently, so the next hover has to rebuild.
	_hide_tooltip()


## Tooltip rebuilds since this controller was created (perf pin).
func debug_rebuild_count() -> int:
	return _rebuilds


func _apply_dossier_mode() -> void:
	if _tooltip != null and is_instance_valid(_tooltip) and _tooltip.has_method("set_dossier_mode"):
		_tooltip.call("set_dossier_mode", _management_mode)


func _process(_delta: float) -> void:
	if _tooltip == null or not is_instance_valid(_tooltip):
		return
	if not _tooltip.is_inside_tree() or not _tooltip.is_node_ready():
		return
	_update_for_hovered(get_viewport().gui_get_hovered_control() as Control)


## One frame of hover handling, split from _process so a suite can drive it: a
## headless viewport never reports a hovered control, and this is where the
## rebuild cache lives.
func _update_for_hovered(hovered: Control) -> void:
	if hovered == null:
		_hide_tooltip()
		return

	if hovered == _tooltip or _is_descendant_of(hovered, _tooltip):
		return

	# Determine what areas are allowed
	var over_inv := (_inv_bar != null and _is_descendant_of(hovered, _inv_bar))
	var over_bag := false

	# bag ui can be direct, or retrieved from controller if you didn’t set bag_ui_path
	if _bag_ui == null and _bag_ctl != null and _bag_ctl.has_method("get_bag_ui"):
		_bag_ui = _bag_ctl.call("get_bag_ui") as Control

	if _bag_ui != null:
		over_bag = _is_descendant_of(hovered, _bag_ui)

	var bag_open := _is_bag_open()

	# same rule you had: inv always, bag only while “management mode” (open)
	var allow := over_inv or (over_bag and bag_open)
	if not allow:
		_hide_tooltip()
		return

	var inst: ItemInstance = _find_item_instance_in_parents(hovered)
	if inst == null:
		_hide_tooltip()
		return

	_hook_inventories()
	var source := _find_item_control_in_parents(hovered)
	var source_id: int = int(source.get_instance_id()) if source != null else 0
	var item_id: int = int(inst.get_instance_id())
	if source_id != _shown_source_id or item_id != _shown_item_id:
		_shown_source_id = source_id
		_shown_item_id = item_id
		_rebuilds += 1
		_show_tooltip(inst)
		_measure_tooltip()
		_place_tooltip(source)
		_shown_source_rect = _source_rect(source)
	else:
		# Same control, same item: the tooltip is already correct. It still
		# follows a source that moves (the mouse when there is no source rect,
		# an animating bar), but without re-measuring a body that has not
		# changed.
		var rect := _source_rect(source)
		if rect != _shown_source_rect:
			_shown_source_rect = rect
			_place_tooltip(source)
	# Not cached: inspect_set() early-outs on an unchanged id, and re-asserting
	# it every frame is the behaviour the dossier has always had.
	_inspect_set_for(inst)


func _is_bag_open() -> bool:
	# Prefer controller method if present
	if _bag_ctl != null:
		if _bag_ctl.has_method("is_management_mode"):
			return bool(_bag_ctl.call("is_management_mode"))
		if _bag_ctl.has_method("is_bag_open"):
			return bool(_bag_ctl.call("is_bag_open"))
		if _bag_ctl.has_method("is_open"):
			return bool(_bag_ctl.call("is_open"))

	# Fallback: if bag ui has is_open()
	if _bag_ui != null:
		if _bag_ui.has_method("is_open"):
			return bool(_bag_ui.call("is_open"))

	return false


func _show_tooltip(inst: ItemInstance) -> void:
	if _tooltip == null:
		return
	_tooltip.visible = true
	if _tooltip.has_method("show_item"):
		_tooltip.call("show_item", inst)


func _inspect_set_for(inst: ItemInstance) -> void:
	if not _management_mode or _run_sheet == null or inst == null or inst.data == null:
		return
	var set_id := StringName(str(inst.data.set_id))
	if set_id != &"" and _run_sheet.has_method("inspect_set"):
		_run_sheet.call("inspect_set", set_id)


## Anything that mutates an inventory can rewrite the item under the cursor in
## place - feeding a duplicate ranks it up, and the comparison rows read the
## whole equipped set - so a change there drops the cache whatever the cursor is
## doing. Both objects are replaced on a run reset, so the hook is re-checked
## from the hover path (two identity compares) rather than bound once.
func _hook_inventories() -> void:
	if Global == null:
		return
	var inventory: Object = Global.run_inventory
	var bag: Object = Global.run_bag
	if inventory == _hooked_inventory and bag == _hooked_bag:
		return
	var callback := Callable(self, "_on_inventory_changed")
	for previous in [_hooked_inventory, _hooked_bag]:
		if previous != null and is_instance_valid(previous) and previous.is_connected(&"changed", callback):
			previous.disconnect(&"changed", callback)
	_hooked_inventory = inventory
	_hooked_bag = bag
	for current in [inventory, bag]:
		if current != null and is_instance_valid(current) and not current.is_connected(&"changed", callback):
			current.connect(&"changed", callback)


func _on_inventory_changed() -> void:
	_shown_item_id = 0


func _hide_tooltip() -> void:
	_shown_source_id = 0
	_shown_item_id = 0
	if _tooltip == null:
		return
	if _tooltip.has_method("hide_tooltip"):
		_tooltip.call("hide_tooltip")
	_tooltip.visible = false


func _source_rect(source: Control) -> Rect2:
	if source != null:
		return source.get_global_rect()
	return Rect2(get_viewport().get_mouse_position(), Vector2.ONE)


## The full Control relayout. Only a tooltip whose body actually changed needs
## it, so it is split out of the placement below.
func _measure_tooltip() -> void:
	if _tooltip == null:
		return

	# Fix long-standing "first tooltip stretches vertically" bug:
	# On first show, the tooltip has width ~0, so autowrap can produce an absurd height.
	# Force a sane width BEFORE measuring minimum size.
	var w := _tooltip.custom_minimum_size.x
	if w <= 0.0:
		w = 360.0
	_tooltip.size = Vector2(w, 0)
	_tooltip.reset_size()
	var min_sz := _tooltip.get_combined_minimum_size()
	if min_sz.x > 0.0 and min_sz.y > 0.0:
		_tooltip.size = Vector2(maxf(w, min_sz.x), min_sz.y)


func _place_tooltip(source: Control) -> void:
	if _tooltip == null:
		return

	if _management_mode:
		_position_management_dossier()
		return

	if _tooltip.has_method("place_beside"):
		_tooltip.call("place_beside", _source_rect(source), get_viewport().get_visible_rect(), 12.0)


func _position_management_dossier() -> void:
	if _tooltip == null:
		return
	var viewport_rect := get_viewport().get_visible_rect()
	var margin := 8.0
	var gap := 12.0
	var bag_rect := Rect2(
		Vector2(viewport_rect.end.x - 218.0, viewport_rect.position.y + margin),
		Vector2(210.0, 260.0)
	)
	if _bag_ui != null and is_instance_valid(_bag_ui):
		bag_rect = _bag_ui.get_global_rect()
	var x := bag_rect.position.x - _tooltip.size.x - gap
	var max_x := viewport_rect.end.x - _tooltip.size.x - margin
	x = clampf(x, viewport_rect.position.x + margin, maxf(viewport_rect.position.x + margin, max_x))
	var max_y := viewport_rect.end.y - _tooltip.size.y - margin
	var y := clampf(bag_rect.position.y, viewport_rect.position.y + margin, maxf(viewport_rect.position.y + margin, max_y))
	_tooltip.global_position = Vector2(x, y)


func _is_descendant_of(n: Node, root: Node) -> bool:
	var cur: Node = n
	while cur != null:
		if cur == root:
			return true
		cur = cur.get_parent()
	return false


func _find_item_instance_in_parents(n: Node) -> ItemInstance:
	var cur: Node = n
	while cur != null:
		if cur.has_meta("item_instance"):
			var v: Variant = cur.get_meta("item_instance")
			if v is ItemInstance:
				return v as ItemInstance
		cur = cur.get_parent()
	return null


func _find_item_control_in_parents(n: Node) -> Control:
	var cur: Node = n
	while cur != null:
		if cur is Control and cur.has_meta("item_instance"):
			return cur as Control
		cur = cur.get_parent()
	return n as Control
