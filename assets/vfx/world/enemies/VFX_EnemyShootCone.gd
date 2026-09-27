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
	material = null  # pixel-art kit (Batch C): the sprite blends normally
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
	var r1: float = _len * lerpf(0.85, 1.0, 1.0 - p)

	# Pixel-art kit (Batch C, 2026-09-27): one cone sprite (apex at the origin, outer arc baked in) in the core colour replaces the glow wedge polygon and the core arc.
	VfxKit.draw_cone(self, Vector2.ZERO, a, r1, Color(_core.r, _core.g, _core.b, _core.a * fade), rad_to_deg(_half_angle))
