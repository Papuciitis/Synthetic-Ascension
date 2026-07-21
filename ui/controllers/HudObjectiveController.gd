extends Node
class_name HudObjectiveController

@export var panel_path: NodePath
@export var title_path: NodePath
@export var detail_path: NodePath
@export var bag_controller_path: NodePath

var _panel: PanelContainer = null
var _title: Label = null
var _detail: Label = null
var _bag_controller: HudBagController = null
var _bag_ui: Control = null
var _has_objective: bool = false
var _management_open: bool = false

func _enter_tree() -> void:
	_hook_events()

func _ready() -> void:
	_resolve_nodes()
	_hook_bag_controller()
	_apply_visibility()
	call_deferred("_bind_bag_layout")

func _hook_events() -> void:
	if RunEvents != null and RunEvents.has_signal("objective_changed"):
		var cb := Callable(self, "_on_objective_changed")
		if not RunEvents.objective_changed.is_connected(cb):
			RunEvents.objective_changed.connect(cb)

func _resolve_nodes() -> void:
	if _panel == null and panel_path != NodePath():
		_panel = get_node_or_null(panel_path) as PanelContainer
	if _title == null and title_path != NodePath():
		_title = get_node_or_null(title_path) as Label
	if _detail == null and detail_path != NodePath():
		_detail = get_node_or_null(detail_path) as Label
	if _bag_controller == null and bag_controller_path != NodePath():
		_bag_controller = get_node_or_null(bag_controller_path) as HudBagController

func _hook_bag_controller() -> void:
	_resolve_nodes()
	if _bag_controller == null:
		return
	_management_open = _bag_controller.is_management_mode()
	var cb := Callable(self, "_on_management_mode_changed")
	if not _bag_controller.management_mode_changed.is_connected(cb):
		_bag_controller.management_mode_changed.connect(cb)
	call_deferred("_bind_bag_layout")

func _bind_bag_layout() -> void:
	if not is_inside_tree() or _bag_controller == null:
		return
	_bag_ui = _bag_controller.get_bag_ui()
	if _bag_ui == null:
		return
	if _bag_ui.has_signal("layout_changed"):
		var cb := Callable(self, "_on_bag_layout_changed")
		if not _bag_ui.is_connected("layout_changed", cb):
			_bag_ui.connect("layout_changed", cb)
	_position_below_bag()

func _on_bag_layout_changed() -> void:
	call_deferred("_position_below_bag")

func _position_below_bag() -> void:
	if _panel == null or _bag_ui == null or not is_instance_valid(_bag_ui):
		return
	var bag_rect: Rect2 = _bag_ui.get_global_rect()
	var panel_width: float = maxf(482.0, _panel.get_combined_minimum_size().x)
	var panel_height: float = maxf(94.0, _panel.get_combined_minimum_size().y)
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	_panel.size = Vector2(panel_width, panel_height)
	_panel.global_position = Vector2(bag_rect.end.x - panel_width, bag_rect.end.y + 12.0)

func _on_management_mode_changed(is_open: bool) -> void:
	_management_open = is_open
	if not is_open:
		call_deferred("_position_below_bag")
	_apply_visibility()

func _apply_visibility() -> void:
	if _panel != null:
		_panel.visible = _has_objective and not _management_open

func _on_objective_changed(title: String, detail: String) -> void:
	_resolve_nodes()
	if _panel == null or _title == null or _detail == null:
		return
	var clean_title := title.strip_edges()
	if clean_title == "":
		_has_objective = false
		_apply_visibility()
		return
	_title.text = clean_title
	_detail.text = detail.strip_edges()
	_has_objective = true
	_position_below_bag()
	call_deferred("_position_below_bag")
	_apply_visibility()
