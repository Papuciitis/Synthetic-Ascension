extends Node
class_name HudGateChecklistController

# Renders the structured Exit Rite requirement checklist. Requirements expand
# when they change, then settle into a persistent one-line status. Holding the
# details action restores the full list without making it permanent combat UI.

@export var panel_path: NodePath
@export var header_path: NodePath
@export var rows_path: NodePath
@export var hint_path: NodePath
@export var bag_controller_path: NodePath
@export var details_action: StringName = &"hud_details"
@export_range(0.1, 10.0, 0.1) var expanded_duration: float = 3.0

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
var _details_requested: bool = false
var _transient_expanded: bool = false
var _change_revision: int = 0
var _last_expansion_signature: String = ""
var _header_base_text: String = ""
var _last_prompt: String = ""
## The keycode _last_prompt was rendered from, and the header text it was
## appended to. Godot has no "InputMap changed" notification, so the binding is
## still read every frame - but reading it now stops at an int compare instead
## of allocating a keycode String and formatting a header every frame.
var _prompt_keycode: int = -1
var _prompt_base_text: String = ""


func _enter_tree() -> void:
	if RunEvents != null and RunEvents.has_signal("gate_checklist_changed"):
		var cb := Callable(self, "_on_gate_checklist_changed")
		if not RunEvents.gate_checklist_changed.is_connected(cb):
			RunEvents.gate_checklist_changed.connect(cb)


func _ready() -> void:
	_resolve_nodes()
	_hook_bag_controller()
	_apply_visibility()
	_apply_detail_visibility()
	set_process(true)


func _process(_delta: float) -> void:
	if details_action != &"" and InputMap.has_action(details_action):
		set_details_requested(Input.is_action_pressed(details_action))
	_refresh_header_prompt()


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


func set_details_requested(requested: bool) -> void:
	if requested == _details_requested:
		return
	_details_requested = requested
	_apply_detail_visibility()


func _apply_detail_visibility() -> void:
	var expanded := _transient_expanded or _details_requested
	if _rows != null:
		_rows.visible = expanded
	if _hint != null:
		_hint.visible = expanded and _hint.text.strip_edges() != ""


func _on_gate_checklist_changed(state: StringName, items: Array, next_hint: String) -> void:
	_resolve_nodes()
	if _panel == null or _header == null or _rows == null:
		return
	if items.is_empty():
		_change_revision += 1
		_transient_expanded = false
		_last_expansion_signature = ""
		_header_base_text = ""
		_last_prompt = ""
		_prompt_keycode = -1
		_prompt_base_text = ""
		_has_items = false
		_apply_visibility()
		_apply_detail_visibility()
		return
	var state_label := String(state).to_upper()
	var done_count := 0
	for item_variant in items:
		var progress_item := item_variant as Dictionary
		if progress_item != null and bool(progress_item.get("done", false)):
			done_count += 1
	_header_base_text = "EXIT RITE  /  %s  /  %d/%d" % [state_label, done_count, items.size()]
	_last_prompt = ""
	_refresh_header_prompt()
	_header.add_theme_color_override(
		"font_color",
		STATE_COLORS.get(state, STATE_COLORS[&"locked"]) as Color
	)
	_rebuild_rows(items)
	if _hint != null:
		_hint.text = next_hint.strip_edges()
	_has_items = true
	_apply_visibility()
	var expansion_signature := _expansion_signature(state, items, next_hint)
	if expansion_signature != _last_expansion_signature:
		_last_expansion_signature = expansion_signature
		_transient_expanded = true
		_apply_detail_visibility()
		_change_revision += 1
		_collapse_after_delay(_change_revision)


func _collapse_after_delay(revision: int) -> void:
	await get_tree().create_timer(expanded_duration).timeout
	if revision != _change_revision:
		return
	_transient_expanded = false
	_apply_detail_visibility()


func _expansion_signature(state: StringName, items: Array, next_hint: String) -> String:
	var parts := PackedStringArray([String(state), next_hint.strip_edges()])
	for item_variant in items:
		var item := item_variant as Dictionary
		if item == null or item.is_empty():
			continue
		parts.append("%s:%s" % [String(item.get("id", item.get("label", ""))), str(bool(item.get("done", false)))])
	return "|".join(parts)


## The bound key as a number, so the per-frame read costs no String. 0 means
## "no key event on this action", which renders as HOLD.
func _details_keycode() -> int:
	if details_action == &"" or not InputMap.has_action(details_action):
		return 0
	for event in InputMap.action_get_events(details_action):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			return key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
	return 0


func _details_prompt() -> String:
	var code := _details_keycode()
	return OS.get_keycode_string(code) if code != 0 else "HOLD"


func _refresh_header_prompt() -> void:
	if _header == null or _header_base_text.is_empty():
		return
	var code := _details_keycode()
	if code == _prompt_keycode and _header_base_text == _prompt_base_text:
		return
	_prompt_keycode = code
	_prompt_base_text = _header_base_text
	_last_prompt = OS.get_keycode_string(code) if code != 0 else "HOLD"
	_header.text = "%s    [%s] INSPECT" % [_header_base_text, _last_prompt]


func _rebuild_rows(items: Array) -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
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
