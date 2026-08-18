extends Node2D
class_name PlayerAimReticle

const RETICLE_DISTANCE := 92.0


func _ready() -> void:
	top_level = true
	z_index = 350
	visible = false
	queue_redraw()


func set_aim(origin: Vector2, direction: Vector2, visible_for_controller: bool) -> void:
	visible = visible_for_controller
	if not visible:
		return
	global_position = origin + direction.normalized() * RETICLE_DISTANCE
	queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 20, Color(1.0, 0.55, 0.2, 0.92), 2.0, true)
	draw_line(Vector2(-12, 0), Vector2(-5, 0), Color(1.0, 0.85, 0.55, 0.9), 1.5, true)
	draw_line(Vector2(5, 0), Vector2(12, 0), Color(1.0, 0.85, 0.55, 0.9), 1.5, true)
	draw_line(Vector2(0, -12), Vector2(0, -5), Color(1.0, 0.85, 0.55, 0.9), 1.5, true)
	draw_line(Vector2(0, 5), Vector2(0, 12), Color(1.0, 0.85, 0.55, 0.9), 1.5, true)
