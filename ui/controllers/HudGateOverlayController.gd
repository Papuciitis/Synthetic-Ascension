extends Node
class_name HudGateOverlayController

# Owns the Level 1 gate UI:
# - Edge arrow that points to Global.exit_gate_pos
# - Gate ready popup when resonance reaches threshold
# - Updates the TopLeft resonance bar + gate status label

@export var gate_overlay_path: NodePath
@export var gate_arrow_path: NodePath
@export var gate_arrow_tex_path: NodePath
@export var gate_ready_overlay_path: NodePath

@export var resonance_bar_path: NodePath
@export var gate_status_label_path: NodePath

@export var ready_threshold: float = 0.999

var _gate_overlay: Control = null
var _gate_arrow: Control = null
var _gate_arrow_tex: Control = null
var _gate_ready_overlay: Control = null

var _res_bar: ProgressBar = null
var _gate_status: Label = null

var _last_res: float = -1.0
var _popup_tw: Tween = null


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hook_run_events()


func _ready() -> void:
	_resolve_nodes()

	# Make sure arrow has sane size for edge placement.
	if _gate_arrow != null and _gate_arrow.size == Vector2.ZERO:
		_gate_arrow.size = _gate_arrow.custom_minimum_size

	call_deferred("_recenter_arrow")
	set_process(true)


func _hook_run_events() -> void:
	if RunEvents != null and RunEvents.has_signal("resonance_changed"):
		var cb: Callable = Callable(self, "_on_resonance_changed")
		if not RunEvents.resonance_changed.is_connected(cb):
			RunEvents.resonance_changed.connect(cb)


func _resolve_nodes() -> void:
	if _gate_overlay == null and gate_overlay_path != NodePath():
		_gate_overlay = get_node_or_null(gate_overlay_path) as Control
	if _gate_arrow == null and gate_arrow_path != NodePath():
		_gate_arrow = get_node_or_null(gate_arrow_path) as Control
	if _gate_arrow_tex == null and gate_arrow_tex_path != NodePath():
		_gate_arrow_tex = get_node_or_null(gate_arrow_tex_path) as Control
	if _gate_ready_overlay == null and gate_ready_overlay_path != NodePath():
		_gate_ready_overlay = get_node_or_null(gate_ready_overlay_path) as Control

	if _res_bar == null and resonance_bar_path != NodePath():
		_res_bar = get_node_or_null(resonance_bar_path) as ProgressBar
	if _gate_status == null and gate_status_label_path != NodePath():
		_gate_status = get_node_or_null(gate_status_label_path) as Label

	_ensure_arrow_material()


func _ensure_arrow_material() -> void:
	# Safety: ensure the arrow texture uses the gradient shader.
	var tex: TextureRect = _gate_arrow_tex as TextureRect
	if tex == null:
		return
	if tex.material != null:
		return

	var sh: Shader = load("res://ui/shaders/arrow_gradient.gdshader") as Shader
	if sh == null:
		return

	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = sh
	tex.material = mat


func _recenter_arrow() -> void:
	if _gate_arrow == null:
		return
	_gate_arrow.pivot_offset = _gate_arrow.size * 0.5

	if _gate_arrow_tex != null and _gate_arrow_tex is Control:
		var c: Control = _gate_arrow_tex as Control
		c.pivot_offset = c.size * 0.5


func _process(delta: float) -> void:
	_update_gate_arrow(delta)


func _get_viewport_size() -> Vector2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return Vector2.ZERO
	return vp.get_visible_rect().size


func _world_to_screen(world_pos: Vector2) -> Vector2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return Vector2.INF

	var cam: Camera2D = vp.get_camera_2d()
	if cam == null:
		return Vector2.INF

	var vp_size: Vector2 = vp.get_visible_rect().size
	var center_world: Vector2 = cam.get_screen_center_position()
	var z: Vector2 = cam.zoom
	return (world_pos - center_world) * z + (vp_size * 0.5)


func _update_gate_arrow(delta: float) -> void:
	_resolve_nodes()
	if _gate_arrow == null:
		return

	# Gate position is published by ExitRite (Level 1).
	if Global == null or Global.exit_gate_pos == Vector2.INF:
		_gate_arrow.visible = false
		return

	var gate_screen: Vector2 = _world_to_screen(Global.exit_gate_pos)
	if gate_screen == Vector2.INF:
		_gate_arrow.visible = false
		return

	var vp_size: Vector2 = _get_viewport_size()
	if vp_size == Vector2.ZERO:
		_gate_arrow.visible = false
		return

	var center: Vector2 = vp_size * 0.5
	var dir: Vector2 = gate_screen - center

	if dir.length() < 8.0:
		_gate_arrow.visible = false
		return

	# If the gate is on screen, hide the edge arrow.
	var margin: float = 26.0
	var inner: Rect2 = Rect2(Vector2(margin, margin), vp_size - Vector2(margin * 2.0, margin * 2.0))
	if inner.has_point(gate_screen):
		_gate_arrow.visible = false
		return

	_gate_arrow.visible = true

	var nd: Vector2 = dir.normalized()
	var half: Vector2 = vp_size * 0.5
	var t: float = 1.0e9

	if absf(nd.x) > 0.0001:
		t = minf(t, (half.x - margin) / absf(nd.x))
	if absf(nd.y) > 0.0001:
		t = minf(t, (half.y - margin) / absf(nd.y))

	var pos: Vector2 = center + nd * t

	_gate_arrow.position = pos - (_gate_arrow.size * 0.5)

	var target_rot: float = nd.angle() + (PI * 0.5) # ▲ points up by default

	if _gate_arrow_tex != null and _gate_arrow_tex is Control:
		var c: Control = _gate_arrow_tex as Control
		c.rotation = lerp_angle(c.rotation, target_rot, minf(1.0, delta * 16.0))
	else:
		_gate_arrow.rotation = lerp_angle(_gate_arrow.rotation, target_rot, minf(1.0, delta * 16.0))

	# Pulse alpha.
	var tt: float = float(Time.get_ticks_msec()) * 0.004
	_gate_arrow.modulate.a = 0.78 + 0.22 * (0.5 + 0.5 * sin(tt))


func _on_resonance_changed(v: float) -> void:
	_resolve_nodes()

	var vv: float = clampf(v, 0.0, 1.0)
	var was_ready: bool = (_last_res >= ready_threshold)

	if _res_bar != null:
		_res_bar.max_value = 1.0
		_res_bar.value = vv

	if _gate_status != null:
		_gate_status.text = "READY" if vv >= ready_threshold else "SEALED"

	if vv >= ready_threshold and (not was_ready):
		if _gate_status != null:
			_gate_status.modulate = Color(1, 1, 1, 1)
			var tw: Tween = create_tween()
			tw.tween_property(_gate_status, "modulate", Color(1, 1, 1, 0.85), 0.6)
		_show_gate_ready_popup()

	_last_res = vv


func _show_gate_ready_popup() -> void:
	if _gate_ready_overlay == null:
		return

	if _popup_tw != null and _popup_tw.is_running():
		_popup_tw.kill()

	_gate_ready_overlay.visible = true
	_gate_ready_overlay.modulate.a = 0.0

	var center: Control = _gate_ready_overlay.get_node_or_null("Center") as Control
	if center != null:
		center.pivot_offset = center.size * 0.5
		center.scale = Vector2.ONE * 0.93

	_popup_tw = create_tween()
	_popup_tw.set_trans(Tween.TRANS_QUAD)
	_popup_tw.set_ease(Tween.EASE_OUT)

	_popup_tw.tween_property(_gate_ready_overlay, "modulate:a", 1.0, 0.18)
	if center != null:
		_popup_tw.tween_property(center, "scale", Vector2.ONE, 0.18)

	_popup_tw.tween_interval(1.8)
	_popup_tw.tween_property(_gate_ready_overlay, "modulate:a", 0.0, 0.45)
	_popup_tw.tween_callback(Callable(self, "_on_gate_popup_done"))


func _on_gate_popup_done() -> void:
	if _gate_ready_overlay != null:
		_gate_ready_overlay.visible = false
