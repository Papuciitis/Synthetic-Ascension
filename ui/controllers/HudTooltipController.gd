extends Node
class_name HudTooltipController

@export var tooltip_scene: PackedScene
@export var inv_bar_path: NodePath
@export var bag_ui_path: NodePath            # point to BagUI (Control) OR leave empty
@export var bag_controller_path: NodePath    # point to HudBagController OR leave empty

var _inv_bar: Node = null
var _bag_ui: Control = null
var _bag_ctl: Node = null

var _tooltip: Control = null


func _ready() -> void:
	_inv_bar = (get_node_or_null(inv_bar_path) if inv_bar_path != NodePath() else null)
	_bag_ui = (get_node_or_null(bag_ui_path) as Control if bag_ui_path != NodePath() else null)
	_bag_ctl = (get_node_or_null(bag_controller_path) if bag_controller_path != NodePath() else null)

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


func _process(_delta: float) -> void:
	if _tooltip == null or not is_instance_valid(_tooltip):
		return
	if not _tooltip.is_inside_tree() or not _tooltip.is_node_ready():
		return

	var hovered := get_viewport().gui_get_hovered_control() as Control
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

	_show_tooltip(inst)
	_position_tooltip_near_mouse()


func _is_bag_open() -> bool:
	# Prefer controller method if present
	if _bag_ctl != null:
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


func _hide_tooltip() -> void:
	if _tooltip == null:
		return
	if _tooltip.has_method("hide_tooltip"):
		_tooltip.call("hide_tooltip")
	_tooltip.visible = false


func _position_tooltip_near_mouse() -> void:
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

	var mouse := get_viewport().get_mouse_position()
	var pad := Vector2(14, 14)

	var pos := mouse + pad
	var screen := get_viewport().get_visible_rect().size

	if pos.x + _tooltip.size.x > screen.x - 8.0:
		pos.x = screen.x - _tooltip.size.x - 8.0
	if pos.y + _tooltip.size.y > screen.y - 8.0:
		pos.y = screen.y - _tooltip.size.y - 8.0
	if pos.x < 8.0: pos.x = 8.0
	if pos.y < 8.0: pos.y = 8.0

	_tooltip.position = pos


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
