extends Node
class_name HudObjectiveController

@export var panel_path: NodePath
@export var title_path: NodePath
@export var detail_path: NodePath
@export var secondary_panel_path: NodePath
@export var secondary_title_path: NodePath
@export var secondary_detail_path: NodePath
@export var bag_controller_path: NodePath

var _panel: PanelContainer = null
var _title: Label = null
var _detail: Label = null
var _secondary_panel: PanelContainer = null
var _secondary_title: Label = null
var _secondary_detail: Label = null
var _bag_controller: HudBagController = null
var _has_objective: bool = false
var _has_secondary_objective: bool = false
var _management_open: bool = false
var _secondary_tween: Tween = null

const SECONDARY_NORMAL_COLOR := Color(0.25, 0.90, 0.82, 0.98)
const SECONDARY_COMPLETE_COLOR := Color(0.48, 1.00, 0.64, 1.00)

func _enter_tree() -> void:
	_hook_events()

func _ready() -> void:
	_resolve_nodes()
	_hook_bag_controller()
	_apply_visibility()

func _hook_events() -> void:
	if RunEvents != null and RunEvents.has_signal("objective_changed"):
		var cb := Callable(self, "_on_objective_changed")
		if not RunEvents.objective_changed.is_connected(cb):
			RunEvents.objective_changed.connect(cb)
	if RunEvents != null and RunEvents.has_signal("secondary_objective_changed"):
		var secondary_cb := Callable(self, "_on_secondary_objective_changed")
		if not RunEvents.secondary_objective_changed.is_connected(secondary_cb):
			RunEvents.secondary_objective_changed.connect(secondary_cb)

func _resolve_nodes() -> void:
	if _panel == null and panel_path != NodePath():
		_panel = get_node_or_null(panel_path) as PanelContainer
	if _title == null and title_path != NodePath():
		_title = get_node_or_null(title_path) as Label
	if _detail == null and detail_path != NodePath():
		_detail = get_node_or_null(detail_path) as Label
	if _secondary_panel == null and secondary_panel_path != NodePath():
		_secondary_panel = get_node_or_null(secondary_panel_path) as PanelContainer
	if _secondary_title == null and secondary_title_path != NodePath():
		_secondary_title = get_node_or_null(secondary_title_path) as Label
	if _secondary_detail == null and secondary_detail_path != NodePath():
		_secondary_detail = get_node_or_null(secondary_detail_path) as Label
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

func _on_management_mode_changed(is_open: bool) -> void:
	_management_open = is_open
	_apply_visibility()

func _apply_visibility() -> void:
	if _panel != null:
		_panel.visible = _has_objective and not _management_open
	if _secondary_panel != null:
		_secondary_panel.visible = _has_secondary_objective and not _management_open

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
	_apply_visibility()

func _on_secondary_objective_changed(title: String, detail: String) -> void:
	_resolve_nodes()
	if _secondary_panel == null or _secondary_title == null or _secondary_detail == null:
		return
	var clean_title := title.strip_edges()
	if clean_title == "":
		_has_secondary_objective = false
		_apply_visibility()
		return
	_secondary_title.text = clean_title
	_secondary_detail.text = detail.strip_edges()
	_has_secondary_objective = true
	_apply_visibility()
	_apply_secondary_feedback(clean_title.begins_with("✓ SECONDARY COMPLETE"))

func _apply_secondary_feedback(completed: bool) -> void:
	if _secondary_panel == null or _secondary_title == null:
		return
	if _secondary_tween != null:
		_secondary_tween.kill()
	_secondary_title.add_theme_color_override("font_color", SECONDARY_COMPLETE_COLOR if completed else SECONDARY_NORMAL_COLOR)
	_secondary_panel.modulate = Color.WHITE
	_secondary_panel.scale = Vector2.ONE
	if not completed:
		return
	_secondary_panel.pivot_offset = _secondary_panel.size * 0.5
	_secondary_panel.modulate = Color(1.0, 1.0, 1.0, 0.45)
	_secondary_panel.scale = Vector2(0.97, 0.97)
	_secondary_tween = create_tween().set_parallel(true)
	_secondary_tween.tween_property(_secondary_panel, "modulate", Color.WHITE, 0.18)
	_secondary_tween.tween_property(_secondary_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
