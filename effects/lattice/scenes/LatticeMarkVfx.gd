extends Node2D
class_name LatticeMarkVfx

var _mirrored: bool = false
var _life: float = 1.0
var _maximum: float = 1.0

func setup(world_position: Vector2, mirrored: bool, lifetime: float) -> void:
	global_position = world_position
	_mirrored = mirrored
	_life = maxf(0.05, lifetime)
	_maximum = _life
	queue_redraw()

func _process(delta: float) -> void:
	_life = maxf(0.0, _life - delta)
	queue_redraw()
	if _life <= 0.0:
		queue_free()

func _draw() -> void:
	var alpha: float = clampf(_life / _maximum, 0.0, 1.0)
	var color := Color(0.86, 0.50, 1.0, 0.85 * alpha) if _mirrored else Color(0.50, 0.92, 1.0, 0.85 * alpha)
	if _mirrored:
		var diamond := PackedVector2Array([Vector2(0, -15), Vector2(15, 0), Vector2(0, 15), Vector2(-15, 0), Vector2(0, -15)])
		draw_polyline(diamond, color, 2.2, true)
		draw_line(Vector2(-8, 0), Vector2(8, 0), color, 1.4, true)
		draw_line(Vector2(0, -8), Vector2(0, 8), color, 1.4, true)
	else:
		draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, color, 2.0, true)
		for angle in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
			draw_line(Vector2.RIGHT.rotated(angle) * 9.0, Vector2.RIGHT.rotated(angle) * 17.0, color, 1.6, true)
	var remaining_angle: float = TAU * alpha
	draw_arc(Vector2.ZERO, 19.0, -PI * 0.5, -PI * 0.5 + remaining_angle, 24, Color(color.r, color.g, color.b, 0.45 * alpha), 1.0, true)
