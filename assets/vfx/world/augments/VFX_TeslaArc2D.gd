extends Node2D
class_name VFX_TeslaArc2D

@export var duration: float = 0.10
@export var redraw_hz: float = 28.0

@export var segments: int = 10
@export var jaggedness: float = 10.0
@export var taper: float = 0.55

@export var branch_count: int = 1
@export var branch_chance: float = 0.65

@export var core_width: float = 2.0
@export var glow_width: float = 10.0
@export var alpha: float = 0.95

@export var color_core: Color = Color(0.95, 0.98, 1.0, 1.0)
@export var color_glow: Color = Color(0.25, 0.65, 1.0, 0.60)

@export var z: int = 4000

var start_node: Node2D = null
var end_node: Node2D = null
var start_pos: Vector2 = Vector2.ZERO
var end_pos: Vector2 = Vector2.ZERO

var _t: float = 0.0
var _accum: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _main_pts: PackedVector2Array = PackedVector2Array()
var _branch_pts: Array[PackedVector2Array] = []

func setup_positions(a: Vector2, b: Vector2, dur: float = -1.0) -> void:
	start_node = null
	end_node = null
	start_pos = a
	end_pos = b
	if dur > 0.0:
		duration = dur
	_regen()

func setup_nodes(a: Node2D, b: Node2D, dur: float = -1.0) -> void:
	start_node = a
	end_node = b
	if dur > 0.0:
		duration = dur
	_sync_node_positions()
	_regen()

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = z

	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_rng.randomize()
	set_process(true)

func _process(dt: float) -> void:
	_t += dt
	if _t >= duration:
		queue_free()
		return

	_sync_node_positions()

	_accum += dt
	var step: float = 1.0 / maxf(redraw_hz, 1.0)
	if _accum >= step:
		_accum = fmod(_accum, step)
		_regen()

	queue_redraw()

func _sync_node_positions() -> void:
	if start_node != null and is_instance_valid(start_node):
		start_pos = start_node.global_position
	if end_node != null and is_instance_valid(end_node):
		end_pos = end_node.global_position

func _regen() -> void:
	global_position = start_pos
	var local_end: Vector2 = end_pos - start_pos

	_main_pts = _make_bolt(Vector2.ZERO, local_end, segments, jaggedness)

	_branch_pts.clear()
	var want: int = maxi(0, branch_count)
	if want <= 0:
		return

	for _i in range(want):
		if _rng.randf() > branch_chance:
			continue

		var pick: int = _rng.randi_range(2, maxi(2, segments - 2))
		var base: Vector2 = _main_pts[pick]

		var to_end: Vector2 = local_end - base
		if to_end.length_squared() < 1.0:
			continue

		var branch_len: float = to_end.length() * _rng.randf_range(0.25, 0.55)
		var ang: float = to_end.angle() + _rng.randf_range(-1.2, 1.2)
		var tip: Vector2 = base + Vector2.RIGHT.rotated(ang) * branch_len

		_branch_pts.append(_make_bolt(base, tip, maxi(4, int(round(segments * 0.5))), jaggedness * 0.75))

func _make_bolt(a: Vector2, b: Vector2, seg: int, amp: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var v: Vector2 = b - a
	var dist: float = v.length()
	if dist < 0.001:
		pts.append(a)
		pts.append(b)
		return pts

	var dir: Vector2 = v / dist
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	pts.append(a)
	for i in range(1, seg):
		var t: float = float(i) / float(seg)
		var w: float = 1.0 - absf(t - 0.5) * 2.0
		w = lerpf(1.0 - taper, 1.0, w)

		var off: float = _rng.randf_range(-amp, amp) * w
		var p: Vector2 = a + dir * (dist * t) + perp * off
		pts.append(p)
	pts.append(b)
	return pts

func _draw() -> void:
	var p: float = clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var fade: float = 1.0 - p
	fade = fade * fade

	var core := Color(color_core.r, color_core.g, color_core.b, alpha * fade)
	var glow := Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * fade)

	draw_polyline(_main_pts, glow, glow_width, true)
	draw_polyline(_main_pts, core, core_width, true)

	for bp in _branch_pts:
		draw_polyline(bp, Color(glow.r, glow.g, glow.b, glow.a * 0.75), glow_width * 0.7, true)
		draw_polyline(bp, Color(core.r, core.g, core.b, core.a * 0.9), core_width * 0.7, true)

	draw_circle(Vector2.ZERO, maxf(2.0, core_width * 1.2), core)
	draw_circle(end_pos - start_pos, maxf(2.0, core_width * 1.2), core)
