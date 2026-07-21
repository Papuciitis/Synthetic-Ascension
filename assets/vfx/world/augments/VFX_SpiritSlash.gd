extends Node2D
class_name VFX_SpiritSlash

@export var duration: float = 0.18
@export var fade_out: float = 0.12

@export var size: float = 56.0
@export var finger_count: int = 5
@export var spread: float = 1.0          # radians fan width
@export var jaggedness: float = 0.22     # wobble strength

@export var core_width: float = 3.0
@export var glow_width: float = 14.0

@export var color_core: Color = Color(0.70, 0.95, 1.0, 1.0)
@export var color_glow: Color = Color(0.25, 0.65, 1.0, 0.65)

var _t: float = 0.0

func setup(from_pos: Vector2, to_pos: Vector2, is_crit: bool = false) -> void:
	global_position = to_pos

	var d: Vector2 = to_pos - from_pos
	if d.length_squared() < 0.001:
		d = Vector2.RIGHT
	rotation = d.angle()

	if is_crit:
		color_core = Color(1.00, 0.70, 0.35, 1.0)
		color_glow = Color(0.78, 0.22, 1.00, 0.75)
		size *= 1.15
		core_width *= 1.1
		glow_width *= 1.15

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4095

	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if _t >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var remain: float = duration - _t
	var fade: float = 1.0
	if remain < fade_out:
		fade = clampf(remain / maxf(fade_out, 0.001), 0.0, 1.0)
		fade = fade * fade

	var p: float = clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var swell: float = 0.82 + 0.18 * sin(p * PI)
	var base_len: float = size * swell

	# soft bloom
	draw_circle(Vector2.ZERO, base_len * 0.35, Color(color_glow.r, color_glow.g, color_glow.b, 0.10 * fade))

	# “hand” fan (multiple claw strokes)
	var fc: int = maxi(3, finger_count)
	var half: float = spread * 0.5
	for i in range(fc):
		var u: float = (float(i) / float(fc - 1)) if fc > 1 else 0.5
		var ang: float = lerpf(-half, half, u)
		var dir: Vector2 = Vector2.RIGHT.rotated(ang)
		var finger_len: float = base_len * lerpf(0.85, 1.05, abs(u - 0.5) * 2.0)
		_draw_jagged(Vector2.ZERO, dir, finger_len, fade)


	# “cross cut” so it reads like a Spirit Slash at distance
	var cross_len: float = base_len * 0.62
	_draw_slash(Vector2.ZERO, Vector2.RIGHT.rotated(0.75), cross_len, fade, 0.9)
	_draw_slash(Vector2.ZERO, Vector2.RIGHT.rotated(-0.75), cross_len, fade, 0.9)

func _draw_slash(origin: Vector2, dir: Vector2, length: float, fade: float, alpha_mul: float) -> void:
	var a: float = alpha_mul * fade
	var p1: Vector2 = origin + dir.normalized() * length

	draw_line(origin, p1, Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * a), glow_width, true)
	draw_line(origin, p1, Color(color_core.r, color_core.g, color_core.b, a), core_width, true)

func _draw_jagged(origin: Vector2, dir: Vector2, length: float, fade: float) -> void:
	var seg: int = 8
	var pts := PackedVector2Array()
	pts.append(origin)

	var ndir: Vector2 = dir.normalized()
	var perp: Vector2 = Vector2(-ndir.y, ndir.x)

	for s in range(1, seg + 1):
		var u: float = float(s) / float(seg)
		var p: Vector2 = origin + ndir * (length * u)

		var wob: float = sin((u * TAU * 1.25) + (_t * 24.0)) * (jaggedness * 10.0) * (1.0 - u)
		p += perp * wob

		pts.append(p)

	draw_polyline(pts, Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * fade), glow_width, true)
	draw_polyline(pts, Color(color_core.r, color_core.g, color_core.b, fade), core_width, true)
