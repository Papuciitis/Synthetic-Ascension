extends Node
class_name AugmentTooltipController

@export var tooltip_scene: PackedScene
@export var aug_panel_path: NodePath

var _aug_panel: Control = null
var _tooltip: Control = null
var _current_augment: AugmentData = null

func _ready() -> void:
	_aug_panel = (get_node_or_null(aug_panel_path) as Control) if aug_panel_path != NodePath() else null
	call_deferred("_ensure_tooltip")
	set_process(true)

func _ensure_tooltip() -> void:
	if _tooltip != null and is_instance_valid(_tooltip):
		return
	if tooltip_scene == null:
		push_warning("[AugmentTooltipController] tooltip_scene is null")
		return
	var inst := tooltip_scene.instantiate()
	var tip := inst as Control
	if tip == null:
		push_warning("[AugmentTooltipController] tooltip scene root is not a Control")
		return

	tip.visible = false
	tip.z_index = 1001
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE

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

	if _aug_panel == null:
		_hide_tooltip()
		return

	if not _is_descendant_of(hovered, _aug_panel):
		_hide_tooltip()
		return

	var a: AugmentData = _find_augment_in_parents(hovered)
	if a == null:
		_hide_tooltip()
		return

	_show_tooltip(a)
	_position_tooltip_near_mouse()


func _find_augment_in_parents(n: Node) -> AugmentData:
	var cur: Node = n
	while cur != null:
		if cur.has_meta("augment_data"):
			var v: Variant = cur.get_meta("augment_data")
			if v is AugmentData:
				return v as AugmentData
		if cur.has_meta("augment_id") and Global != null:
			var id := StringName(String(cur.get_meta("augment_id")))
			if id != StringName() and Global.augment_db.has(id):
				var obj: Variant = Global.augment_db.get(id)
				if obj is AugmentData:
					return obj as AugmentData
		cur = cur.get_parent()
	return null


func _show_tooltip(a: AugmentData) -> void:
	if _tooltip == null:
		return
	if a == _current_augment:
		return
	_current_augment = a

	var lvl: int = 1
	if a != null and Global != null and Global.has_method("get_augment_level"):
		var aid: StringName = a.id
		if aid != StringName():
			lvl = Global.get_augment_level(aid)

	if _tooltip.has_method("show_augment"):
		_tooltip.call("show_augment", a, lvl)
		# AugmentTooltip performs one deferred layout pass with a constrained text
		# width. Position it after that pass instead of measuring a zero-width label.
		call_deferred("_position_tooltip_near_mouse")

func _hide_tooltip() -> void:
	if _tooltip == null:
		return
	_current_augment = null
	if _tooltip.has_method("hide_tooltip"):
		_tooltip.call("hide_tooltip")
	_tooltip.visible = false

func _position_tooltip_near_mouse() -> void:
	if _tooltip == null or not _tooltip.visible:
		return

	var mouse := get_viewport().get_mouse_position()
	var pad := Vector2(14, 14)
	var pos := mouse + pad
	var screen := get_viewport().get_visible_rect().size

	if pos.x + _tooltip.size.x > screen.x - 8.0:
		pos.x = screen.x - _tooltip.size.x - 8.0
	if pos.y + _tooltip.size.y > screen.y - 8.0:
		pos.y = screen.y - _tooltip.size.y - 8.0
	if pos.x < 8.0:
		pos.x = 8.0
	if pos.y < 8.0:
		pos.y = 8.0

	_tooltip.position = pos

func _is_descendant_of(n: Node, root: Node) -> bool:
	var cur: Node = n
	while cur != null:
		if cur == root:
			return true
		cur = cur.get_parent()
	return false
