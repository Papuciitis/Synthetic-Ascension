extends Node2D
class_name VFX_FloatingPlus

@export var lifetime: float = 0.45
@export var rise_speed: float = 46.0
@export var drift: Vector2 = Vector2(10.0, 0.0)
@export var line_len: float = 10.0
@export var line_width: float = 2.6
@export var color: Color = Color(0.35, 1.0, 0.45, 1.0)

var _t: float = 0.0

func _ready() -> void:
	z_as_relative = false
	z_index = 4095
	material = null  # pixel-art kit (Batch D): the sprite blends normally
	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	position += Vector2(0.0, -rise_speed) * dt + drift * dt
	var k := clampf(_t / maxf(lifetime, 0.001), 0.0, 1.0)
	var s := lerpf(0.95, 1.20, k)
	scale = Vector2.ONE * s

	if _t >= lifetime:
		queue_free()
		return

	queue_redraw()

func _draw() -> void:
	var k := clampf(_t / maxf(lifetime, 0.001), 0.0, 1.0)
	var a := (1.0 - k)
	a = a * a
	var c := Color(color.r, color.g, color.b, color.a * a)

	# Pixel-art kit (Batch D, 2026-09-27): one plus sprite replaces the two
	# crossed lines and the centre dot. The node's own scale (set in _process)
	# still carries the 0.95 -> 1.20 growth, so the size is the bare cross width.
	VfxKit.draw_plus(self, Vector2.ZERO, line_len * 2.0, c, line_width)
