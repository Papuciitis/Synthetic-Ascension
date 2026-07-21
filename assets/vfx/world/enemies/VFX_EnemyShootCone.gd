extends Node2D
class_name VFX_EnemyShootCone

@export var duration: float = 0.16
@export var z: int = 240

var _t: float = 0.0
var _len: float = 54.0
var _half_angle: float = deg_to_rad(18.0)
var _dir: Vector2 = Vector2.RIGHT

var _core: Color = Color(1, 1, 1, 0.35)
var _glow: Color = Color(1, 0.3, 0.1, 0.16)

func setup(pos: Vector2, dir: Vector2, length: float, half_angle_rad: float, dur: float, core: Color, glow: Color) -> void:
	global_position = pos
	_dir = dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
	_len = maxf(8.0, length)
	_half_angle = maxf(0.05, half_angle_rad)
	duration = maxf(0.05, dur)
	_core = core
	_glow = glow

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = z
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
	var p: float = clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var fade: float = 1.0 - p
	fade = fade * fade

	var a: float = _dir.angle()
	var a0: float = a - _half_angle
	var a1: float = a + _half_angle

	var r0: float = 10.0
	var r1: float = _len * lerpf(0.85, 1.0, 1.0 - p)

	# wedge polygon
	var pts: PackedVector2Array = PackedVector2Array()
	var seg: int = 18
	for i in range(seg + 1):
		var t: float = float(i) / float(seg)
		var aa: float = lerpf(a0, a1, t)
		pts.append(Vector2(cos(aa), sin(aa)) * r1)
	for i in range(seg, -1, -1):
		var t2: float = float(i) / float(seg)
		var aa2: float = lerpf(a0, a1, t2)
		pts.append(Vector2(cos(aa2), sin(aa2)) * r0)

	draw_colored_polygon(pts, Color(_glow.r, _glow.g, _glow.b, _glow.a * fade))
	draw_arc(Vector2.ZERO, r1, a0, a1, 32, Color(_core.r, _core.g, _core.b, _core.a * fade), 2.0, true)
