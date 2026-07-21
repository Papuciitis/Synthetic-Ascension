extends Node2D
class_name VFX_Shockwave

@export var duration: float = 0.22
@export var max_radius: float = 220.0

var _t: float = 0.0
var _r: float = 0.0

func setup(pos: Vector2, radius: float) -> void:
	global_position = pos
	max_radius = radius

func _process(dt: float) -> void:
	_t += dt
	var k := clampf(_t / max(duration, 0.001), 0.0, 1.0)
	_r = lerpf(0.0, max_radius, k)
	queue_redraw()
	if _t >= duration:
		queue_free()

func _draw() -> void:
	# clean expanding ring
	var alpha := 1.0 - clampf(_t / max(duration, 0.001), 0.0, 1.0)
	draw_arc(Vector2.ZERO, _r, 0.0, TAU, 64, Color(1, 1, 1, 0.6 * alpha), 3.0, true)
