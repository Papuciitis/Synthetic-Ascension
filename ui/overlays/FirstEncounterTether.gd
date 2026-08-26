extends Control
class_name FirstEncounterTether

const COPPER := Color(0.82, 0.40, 0.13, 0.96)
const COPPER_GLOW := Color(0.95, 0.62, 0.25, 0.24)

var _card_point := Vector2.ZERO
var _target_point := Vector2.ZERO
var _has_points := false


func set_points(card_point: Vector2, target_point: Vector2) -> void:
	_card_point = card_point
	_target_point = target_point
	_has_points = true
	queue_redraw()

func clear_points() -> void:
	_has_points = false
	queue_redraw()


func _draw() -> void:
	if not _has_points:
		return
	var direction := signf(_target_point.x - _card_point.x)
	if is_zero_approx(direction):
		direction = 1.0
	var elbow := Vector2(_card_point.x + 28.0 * direction, _target_point.y)
	var path := PackedVector2Array([_card_point, elbow, _target_point])
	draw_polyline(path, COPPER_GLOW, 6.0, true)
	draw_polyline(path, COPPER, 1.5, true)
	draw_circle(_target_point, 18.0, Color(0, 0, 0, 0), false, 1.5, true)
	draw_arc(_target_point, 18.0, -PI * 0.42, PI * 0.42, 18, COPPER, 1.5, true)
	draw_arc(_target_point, 18.0, PI * 0.58, PI * 1.42, 18, COPPER, 1.5, true)
	draw_circle(_target_point, 3.0, COPPER)
