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
	# Pixel-art kit (Batch C, 2026-09-27): one double shield-arc sprite (inner arc baked in) replaces the outer and inner draw_arc pair; the node's rotation carries the facing.
	VfxKit.draw_shield_arc(self, Vector2.ZERO, 0.0, RADIUS, _half_angle, COLOR, 3.0)
