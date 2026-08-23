extends Node
class_name HudGateChecklistController

# Renders the structured Exit Rite requirement checklist
# (RunEvents.gate_checklist_changed). The emitting builder owns all state
# logic; this controller only draws what it is told - it must never infer
# readiness from the resonance bar (clamped at 0.998 while blocked).

@export var panel_path: NodePath
@export var header_path: NodePath
@export var rows_path: NodePath
@export var hint_path: NodePath
@export var bag_controller_path: NodePath

const STATE_COLORS := {
	&"locked": Color(0.95, 0.45, 0.40, 0.98),
	&"located": Color(1.0, 0.64, 0.28, 0.98),
	&"ready": Color(0.35, 0.85, 0.98, 1.0),
}
const ROW_DONE_COLOR := Color(0.48, 1.0, 0.64, 0.95)
const ROW_PENDING_COLOR := Color(1.0, 1.0, 1.0, 0.78)

var _panel: PanelContainer = null
var _header: Label = null
var _rows: VBoxContainer = null
var _hint: Label = null
var _bag_controller: HudBagController = null
var _has_items: bool = false
var _management_open: bool = false


func _enter_tree() -> void:
	if RunEvents != null and RunEvents.has_signal("gate_checklist_changed"):
		var cb := Callable(self, "_on_gate_checklist_changed")
		if not RunEvents.gate_checklist_changed.is_connected(cb):
			RunEvents.gate_checklist_changed.connect(cb)


func _ready() -> void:
	_resolve_nodes()
	_hook_bag_controller()
	_apply_visibility()


func _resolve_nodes() -> void:
	if _panel == null and panel_path != NodePath():
		_panel = get_node_or_null(panel_path) as PanelContainer
	if _header == null and header_path != NodePath():
		_header = get_node_or_null(header_path) as Label
	if _rows == null and rows_path != NodePath():
		_rows = get_node_or_null(rows_path) as VBoxContainer
	if _hint == null and hint_path != NodePath():
		_hint = get_node_or_null(hint_path) as Label
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
		_panel.visible = _has_items and not _management_open


func _on_gate_checklist_changed(state: StringName, items: Array, next_hint: String) -> void:
	_resolve_nodes()
	if _panel == null or _header == null or _rows == null:
		return
	if items.is_empty():
		_has_items = false
		_apply_visibility()
		return
	var state_label := String(state).to_upper()
	_header.text = "EXIT RITE • %s" % state_label
	_header.add_theme_color_override(
		"font_color",
		STATE_COLORS.get(state, STATE_COLORS[&"locked"]) as Color
	)
	_rebuild_rows(items)
	if _hint != null:
		_hint.text = next_hint.strip_edges()
		_hint.visible = _hint.text != ""
	_has_items = true
	_apply_visibility()


func _rebuild_rows(items: Array) -> void:
	for child in _rows.get_children():
		child.queue_free()
	for item_variant in items:
		var item := item_variant as Dictionary
		if item == null or item.is_empty():
			continue
		var done := bool(item.get("done", false))
		var row := Label.new()
		row.text = "%s %s" % ["✓" if done else "○", String(item.get("label", ""))]
		row.add_theme_color_override("font_color", ROW_DONE_COLOR if done else ROW_PENDING_COLOR)
		row.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		row.add_theme_constant_override("outline_size", 4)
		row.add_theme_font_size_override("font_size", 13)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows.add_child(row)
