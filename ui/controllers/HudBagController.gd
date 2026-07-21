extends Node
class_name HudBagController

signal management_mode_changed(is_open: bool)

@export var bag_ui_scene: PackedScene
@export var inv_bar_path: NodePath
@export var top_left_path: NodePath
@export var run_sheet_path: NodePath
@export var manage_overlay_path: NodePath

var bag_ui: Control = null
var management_mode: bool = false

var _inv_bar: Node = null
var _top_left: Control = null
var _run_sheet: Control = null
var _overlay: ColorRect = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var host := get_parent()
	if host == null:
		return

	_inv_bar = _resolve_node(inv_bar_path, "InventoryBar")
	_top_left = _resolve_node(top_left_path, "TopLeft") as Control
	_run_sheet = _resolve_node(run_sheet_path, "RunSheetHUD") as Control
	_overlay = _resolve_node(manage_overlay_path, "ManageOverlay") as ColorRect

	_ensure_overlay()
	_ensure_bag_ui()

	# Default: hidden until bag opens
	if _run_sheet != null:
		_run_sheet.visible = false

	call_deferred("_ensure_bag_ui_positioned")
	call_deferred("_position_run_sheet_under_top_left")

func get_bag_ui() -> Control:
	return bag_ui

func is_management_mode() -> bool:
	return management_mode

func bind_core_inventory(inv: Inventory) -> void:
	_ensure_bag_ui()
	if bag_ui != null and bag_ui.has_method("bind_core_inventory"):
		bag_ui.call("bind_core_inventory", inv)

func bind_bag(bag: BagInventory) -> void:
	_ensure_bag_ui()
	if bag_ui != null and bag_ui.has_method("bind_bag"):
		bag_ui.call("bind_bag", bag)
	_ensure_bag_ui_positioned()

func toggle_bag_open() -> void:
	_ensure_bag_ui()
	if bag_ui == null:
		return
	if bag_ui.has_method("toggle_open"):
		bag_ui.call("toggle_open")
	else:
		# fallback (your BagUI has _toggle_full)
		bag_ui.call("_toggle_full")

# ----------------------------
# internals
# ----------------------------

func _resolve_node(path: NodePath, fallback_name: String) -> Node:
	var host := get_parent()
	if host == null:
		return null

	if path != NodePath():
		return get_node_or_null(path)

	# fallback search by name (safe if you forget to set NodePath)
	return host.find_child(fallback_name, true, false)

func _ensure_overlay() -> void:
	var host := get_parent()
	if host == null:
		return

	if _overlay != null and is_instance_valid(_overlay):
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.visible = false
		_overlay.z_index = 50
		_overlay.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		_overlay.color = Color(0, 0, 0, 0.12)
		return

	_overlay = ColorRect.new()
	_overlay.name = "ManageOverlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	_overlay.z_index = 50
	_overlay.color = Color(0, 0, 0, 0.12)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	host.add_child(_overlay)

func _ensure_bag_ui() -> void:
	var host := get_parent()
	if host == null:
		return

	if bag_ui != null and is_instance_valid(bag_ui):
		return

	# already in scene?
	var found := host.get_node_or_null("BagUI") as Control
	if found != null:
		bag_ui = found
		_hook_bag_ui()
		_position_bag_ui_right(bag_ui)
		return

	if bag_ui_scene == null:
		push_error("[HudBagController] bag_ui_scene is not assigned")
		return

	var inst := bag_ui_scene.instantiate() as Control
	if inst == null:
		push_error("[HudBagController] BagUI root is not a Control")
		return

	inst.name = "BagUI"
	host.add_child(inst)
	bag_ui = inst

	_hook_bag_ui()
	_position_bag_ui_right(bag_ui)

func _hook_bag_ui() -> void:
	if bag_ui == null:
		return

	# reposition on size changes
	if bag_ui.has_signal("layout_changed"):
		var cb := Callable(self, "_ensure_bag_ui_positioned")
		if not bag_ui.is_connected("layout_changed", cb):
			bag_ui.connect("layout_changed", cb)

	# management mode on open/close
	if bag_ui.has_signal("open_changed"):
		var cb2 := Callable(self, "_on_bag_open_changed")
		if not bag_ui.is_connected("open_changed", cb2):
			bag_ui.connect("open_changed", cb2)

func _position_bag_ui_right(ui: Control) -> void:
	if ui == null:
		return

	ui.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)

	var ms := ui.get_combined_minimum_size()
	var w: float = (ms.x if ms.x > 0.0 else 210.0)
	var h: float = (ms.y if ms.y > 0.0 else 78.0)

	var right_margin := 8.0
	var top_margin := 8.0

	ui.offset_right = -right_margin
	ui.offset_left = ui.offset_right - w
	ui.offset_top = top_margin
	ui.offset_bottom = ui.offset_top + h

func _ensure_bag_ui_positioned() -> void:
	if bag_ui == null:
		return
	_position_bag_ui_right(bag_ui)

func _on_bag_open_changed(is_open: bool) -> void:
	management_mode = is_open

	if _overlay != null:
		_overlay.visible = management_mode

	if _inv_bar != null and _inv_bar.has_method("set_management_mode"):
		_inv_bar.call("set_management_mode", management_mode)

	if _run_sheet != null:
		_run_sheet.visible = management_mode
		if management_mode:
			_position_run_sheet_under_top_left()


	management_mode_changed.emit(management_mode)

func _position_run_sheet_under_top_left() -> void:
	if _run_sheet == null or _top_left == null:
		return

	_run_sheet.set_anchors_preset(Control.PRESET_TOP_LEFT, true)

	var r: Rect2 = _top_left.get_global_rect()
	_run_sheet.position = Vector2(r.position.x, r.position.y + r.size.y + 8.0)
