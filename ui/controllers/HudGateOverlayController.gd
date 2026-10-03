extends Node
class_name HudGateOverlayController

# Owns the Level 1 gate UI:
# - Edge arrow that points to the active primary objective, then the revealed exit
# - Gate ready popup when resonance reaches threshold
# - Updates the TopLeft resonance bar + gate status label

@export var gate_overlay_path: NodePath
@export var gate_arrow_path: NodePath
@export var gate_arrow_tex_path: NodePath
@export var gate_ready_overlay_path: NodePath

@export var resonance_bar_path: NodePath
@export var gate_status_label_path: NodePath

@export var ready_threshold: float = 0.999

## HUD panels along the screen edges. While one is shown the arrow stops short
## of it instead of sitting on it, so neither the arrow nor its distance covers
## the ability plates, the top-left panel, the backpack, the objective stack,
## the Run Sheet (bag open), a tutorial tip or the evac warning.
@export var keep_clear_paths: Array[NodePath] = [
	NodePath("../TopLeft"),
	NodePath("../BagUI"),
	NodePath("../BossBarHUD"),
	NodePath("../ActiveAbilityHud_Q"),
	NodePath("../ActiveAbilityHud_R"),
	NodePath("../ActiveAbilityHud_V"),
	NodePath("../GateOverlay/ContextStack"),
	NodePath("../RunSheetHUD"),
	NodePath("../GateOverlay/TutorialTip"),
	NodePath("../EvacOverlay/EvacWarning"),
]

## Space between the arrow plate and a HUD panel it stops against.
const KEEP_CLEAR_GAP := 8.0
## Space between the arrow plate and its distance.
const LABEL_GAP := 3.0
## Rounding the end of the ability plates or the boss bar moves the arrow's
## pin in one jump (under 200 px); it glides there at GLIDE_SPEED (px/s).
## Ordinary edge travel is slower, so the arrow still tracks it exactly. A
## longer jump is a new target elsewhere, and gliding that would drag the
## arrow across the middle of the screen, so it snaps. Reduced Motion snaps.
const GLIDE_SPEED := 2400.0
const GLIDE_MAX_JUMP := 240.0
## The pin follows the target's bearing with this much slack (radians, half a
## degree), so a jitter of the camera or the target right where the ray rounds
## a panel corner cannot flip the pin between panel and edge every frame. The
## glyph still turns to the true bearing.
const PIN_SLACK := 0.0087

const ArcaneMotion := preload("res://ui/widgets/ArcaneMotion.gd")

var _gate_overlay: Control = null
var _gate_arrow: Control = null
var _gate_arrow_tex: Control = null
var _gate_distance_label: Label = null
var _gate_ready_overlay: Control = null

var _res_bar: ProgressBar = null
var _gate_status: Label = null

var _keep_clear: Array[Control] = []
var _keep_clear_rects: Array[Rect2] = []
var _keep_clear_resolved: bool = false
## The panels' rects are re-read only after one of them moved, resized, showed
## or hid, not every frame.
var _keep_clear_dirty: bool = true
var _arrow_shown: bool = false
var _arrow_center: Vector2 = Vector2.ZERO
var _pin_bearing: float = 0.0
var _shown_meters: int = -1

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
	_hook_targets()
	_refresh_arrow_processing()


func _hook_targets() -> void:
	if Global == null or not Global.has_signal("hud_target_positions_changed"):
		# No signal to wake on: stay awake rather than sleep on a target that
		# can never announce itself.
		set_process(true)
		return
	var cb: Callable = Callable(self, "_on_hud_targets_changed")
	if not Global.hud_target_positions_changed.is_connected(cb):
		Global.hud_target_positions_changed.connect(cb)


func _on_hud_targets_changed() -> void:
	_refresh_arrow_processing()


## The arrow chases a moving camera, so with something to point at it genuinely
## needs every frame. With NEITHER target set there is nothing to point at, no
## distance to write and no pulse worth animating - it is hidden and stays
## hidden - so it sleeps until Global says a position appeared. Those two
## positions, the camera and the player are the only inputs to the arrow, and
## the other three cannot matter while there is no target.
func _refresh_arrow_processing() -> void:
	var has_target: bool = Global != null and (
		Global.objective_target_pos != Vector2.INF or Global.exit_gate_pos != Vector2.INF
	)
	set_process(has_target)
	if has_target:
		return
	_resolve_nodes()
	if _gate_arrow != null:
		_hide_arrow()


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

	if not _keep_clear_resolved:
		_keep_clear_resolved = true
		for path in keep_clear_paths:
			var panel := get_node_or_null(path) as Control
			if panel != null:
				_keep_clear.append(panel)
				# Shown or hidden (its own or a parent's), moved or resized, freed.
				panel.visibility_changed.connect(_on_keep_clear_changed)
				panel.item_rect_changed.connect(_on_keep_clear_changed)
				panel.tree_exiting.connect(_on_keep_clear_changed)
		_keep_clear_rects.resize(_keep_clear.size())

	_ensure_arrow_material()


func _on_keep_clear_changed() -> void:
	_keep_clear_dirty = true


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

	if Global == null:
		_hide_arrow()
		return
	var target_world: Vector2 = Global.objective_target_pos
	if target_world == Vector2.INF:
		target_world = Global.exit_gate_pos
	if target_world == Vector2.INF:
		_hide_arrow()
		return

	var gate_screen: Vector2 = _world_to_screen(target_world)
	if gate_screen == Vector2.INF:
		_hide_arrow()
		return

	var vp_size: Vector2 = _get_viewport_size()
	if vp_size == Vector2.ZERO:
		_hide_arrow()
		return

	var center: Vector2 = vp_size * 0.5
	var dir: Vector2 = gate_screen - center

	if dir.length() < 8.0:
		_hide_arrow()
		return

	# If the gate is on screen, hide the edge arrow.
	var margin: float = 26.0
	var inner: Rect2 = Rect2(Vector2(margin, margin), vp_size - Vector2(margin * 2.0, margin * 2.0))
	if inner.has_point(gate_screen):
		_hide_arrow()
		return

	var nd: Vector2 = dir.normalized()
	var half_arrow: Vector2 = _gate_arrow.size * 0.5
	if _keep_clear_dirty:
		_keep_clear_dirty = false
		for i in range(_keep_clear.size()):
			var panel: Control = _keep_clear[i] if is_instance_valid(_keep_clear[i]) else null
			_keep_clear_rects[i] = panel.get_global_rect() if panel != null and panel.is_inside_tree() and panel.is_visible_in_tree() else Rect2()
	var bearing: float = nd.angle()
	var slack_off: float = angle_difference(bearing, _pin_bearing)
	if not _arrow_shown:
		_pin_bearing = bearing
	elif absf(slack_off) > PIN_SLACK:
		_pin_bearing = bearing + signf(slack_off) * PIN_SLACK
	var pin_dir: Vector2 = Vector2.from_angle(_pin_bearing)
	var pin: Vector2 = edge_pin(center, pin_dir, inner, _keep_clear_rects, maxf(half_arrow.x, half_arrow.y) + KEEP_CLEAR_GAP)
	var jump: float = _arrow_center.distance_to(pin)
	if _arrow_shown and jump > GLIDE_SPEED * delta and jump <= GLIDE_MAX_JUMP and not ArcaneMotion.reduced():
		_arrow_center = _arrow_center.move_toward(pin, GLIDE_SPEED * delta)
	else:
		_arrow_center = pin
	_arrow_shown = true
	_gate_arrow.visible = true

	_gate_arrow.position = _arrow_center - half_arrow

	# Distance language: direction alone leaves the player guessing how far.
	var arrow_player := get_tree().get_first_node_in_group(&"player") as Node2D
	if arrow_player != null:
		if _gate_distance_label == null or not is_instance_valid(_gate_distance_label):
			_gate_distance_label = Label.new()
			_gate_distance_label.name = "GateDistance"
			# Garamond like before, stronger and tabular so the width holds as the
			# count runs; Cinzel has no lowercase and would read "78M".
			_gate_distance_label.theme_type_variation = &"BodyStrong"
			_gate_distance_label.add_theme_font_size_override("font_size", 15)
			_gate_distance_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			_gate_distance_label.add_theme_constant_override("outline_size", 4)
			_gate_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_gate_distance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Beside the arrow, not inside it: the arrow is a PanelContainer that
			# would lay the label out over the glyph.
			_gate_arrow.add_sibling(_gate_distance_label)
			_shown_meters = -1
		# 64px ≈ one world meter (cell size).
		var meters := int(arrow_player.global_position.distance_to(target_world) / 64.0)
		if meters != _shown_meters:
			_shown_meters = meters
			_gate_distance_label.text = "%dm" % meters
			_gate_distance_label.reset_size()
		_gate_distance_label.position = distance_label_position(
			_arrow_center, pin_dir, half_arrow.x, _gate_distance_label.size, Rect2(Vector2.ZERO, vp_size).grow(-4.0), LABEL_GAP
		)
		_gate_distance_label.visible = true
	elif _gate_distance_label != null and is_instance_valid(_gate_distance_label):
		_gate_distance_label.visible = false

	var target_rot: float = bearing + (PI * 0.5) # ▲ points up by default

	if _gate_arrow_tex != null and _gate_arrow_tex is Control:
		var c: Control = _gate_arrow_tex as Control
		c.rotation = lerp_angle(c.rotation, target_rot, minf(1.0, delta * 16.0))
	else:
		_gate_arrow.rotation = lerp_angle(_gate_arrow.rotation, target_rot, minf(1.0, delta * 16.0))

	# Pulse alpha; the distance pulses with the arrow, as it did as its child.
	var tt: float = float(Time.get_ticks_msec()) * 0.004
	_gate_arrow.modulate.a = 0.78 + 0.22 * (0.5 + 0.5 * sin(tt))
	if _gate_distance_label != null and is_instance_valid(_gate_distance_label):
		_gate_distance_label.modulate.a = _gate_arrow.modulate.a


func _hide_arrow() -> void:
	_arrow_shown = false
	_gate_arrow.visible = false
	if _gate_distance_label != null and is_instance_valid(_gate_distance_label):
		_gate_distance_label.visible = false


## Where the edge arrow's centre pins: where the ray from the screen centre
## along `dir` (unit) leaves `inner`, or first meets one of the `keep_clear`
## panels grown by `clearance`, whichever comes first. Empty rects are skipped.
static func edge_pin(center: Vector2, dir: Vector2, inner: Rect2, keep_clear: Array[Rect2], clearance: float) -> Vector2:
	var t: float = 1.0e9
	if absf(dir.x) > 0.0001:
		t = minf(t, ((inner.end.x if dir.x > 0.0 else inner.position.x) - center.x) / dir.x)
	if absf(dir.y) > 0.0001:
		t = minf(t, ((inner.end.y if dir.y > 0.0 else inner.position.y) - center.y) / dir.y)
	# Only a panel the ray's bounding box reaches can stop it, so most panels
	# are skipped without a ray test.
	var reach: Rect2 = Rect2(center, Vector2.ZERO).expand(center + dir * t)
	for rect in keep_clear:
		if rect.has_area():
			var grown: Rect2 = rect.grow(clearance)
			if reach.intersects(grown, true):
				t = minf(t, ray_entry(center, dir, grown))
	return center + dir * t


## How far along the ray from `origin` along `dir` it first enters `rect`:
## INF when it misses, or when it starts inside (nothing to stop short of).
static func ray_entry(origin: Vector2, dir: Vector2, rect: Rect2) -> float:
	if rect.has_point(origin):
		return INF
	var t_in: float = -INF
	var t_out: float = INF
	if absf(dir.x) > 0.0001:
		var tx1: float = (rect.position.x - origin.x) / dir.x
		var tx2: float = (rect.end.x - origin.x) / dir.x
		t_in = maxf(t_in, minf(tx1, tx2))
		t_out = minf(t_out, maxf(tx1, tx2))
	elif origin.x < rect.position.x or origin.x > rect.end.x:
		return INF
	if absf(dir.y) > 0.0001:
		var ty1: float = (rect.position.y - origin.y) / dir.y
		var ty2: float = (rect.end.y - origin.y) / dir.y
		t_in = maxf(t_in, minf(ty1, ty2))
		t_out = minf(t_out, maxf(ty1, ty2))
	elif origin.y < rect.position.y or origin.y > rect.end.y:
		return INF
	if t_in > t_out or t_in < 0.0:
		return INF
	return t_in


## Top-left of the distance label: upright, on the arrow's inward side along
## its line (above it on the bottom edge, left of it on the right edge,
## diagonally in at a corner), clear of the round plate of `arrow_radius`
## by `gap`, and kept inside `view`.
static func distance_label_position(arrow_center: Vector2, dir: Vector2, arrow_radius: float, label_size: Vector2, view: Rect2, gap: float) -> Vector2:
	var half: Vector2 = label_size * 0.5
	# The label box's reach towards the arrow, so it clears the plate at any angle.
	var reach: float = arrow_radius + gap + absf(dir.x) * half.x + absf(dir.y) * half.y
	var label_center: Vector2 = arrow_center - dir * reach
	label_center = label_center.clamp(view.position + half, view.end - half)
	return label_center - half


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
			tw.set_ignore_time_scale(true)
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
	# Hit-stop must not hold "RITE EXPOSED" on screen for many times its 2.4 s.
	_popup_tw.set_ignore_time_scale(true)
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
