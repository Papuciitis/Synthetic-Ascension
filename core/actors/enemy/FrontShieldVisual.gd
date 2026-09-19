extends Node2D

## The Warden's shield sector: an arc on the shielded side, hidden while the
## shield is down. Drawn once per state change, rotated with the facing.

const RADIUS := 30.0
const COLOR := Color(0.62, 0.82, 1.0, 0.85)

var _half_angle := 1.4
var _up := true


func _ready() -> void:
	z_index = 3
	queue_redraw()


func sync(facing: Vector2, up: bool, half_angle: float) -> void:
	rotation = facing.angle()
	if up != _up or not is_equal_approx(half_angle, _half_angle):
		_up = up
		_half_angle = half_angle
		queue_redraw()
	visible = up


func _draw() -> void:
	if not _up:
		return
	draw_arc(Vector2.ZERO, RADIUS, -_half_angle, _half_angle, 24, COLOR, 3.0, true)
	draw_arc(Vector2.ZERO, RADIUS - 5.0, -_half_angle * 0.9, _half_angle * 0.9, 20, Color(COLOR.r, COLOR.g, COLOR.b, 0.35), 2.0, true)
