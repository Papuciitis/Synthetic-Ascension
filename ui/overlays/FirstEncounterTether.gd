extends Control
class_name FirstEncounterTether
## The thread from a first-encounter card to the enemy it names: a thin gold
## line with one elbow, a diamond where it leaves the card, and a ringed
## reticle with four diamond ticks on the target.

const GOLD := Color(0.9, 0.68, 0.4, 0.95)
const GOLD_GLOW := Color(1.0, 0.7, 0.36, 0.2)
const INK := Color(0.03, 0.024, 0.02, 0.9)

var _card_point := Vector2.ZERO
var _target_point := Vector2.ZERO
var _has_points := false


func set_points(card_point: Vector2, target_point: Vector2) -> void:
	if _has_points and card_point.is_equal_approx(_card_point) and target_point.is_equal_approx(_target_point):
		return
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
	draw_polyline(path, Color(0, 0, 0, 0.35), 4.0, true)
	draw_polyline(path, GOLD_GLOW, 5.0, true)
	draw_polyline(path, GOLD, 1.4, true)
	_diamond(_card_point, 4.5, true)
	# The reticle: a ring broken at the four quarters, each break a diamond.
	var radius := 18.0
	for i in range(4):
		var start := -PI * 0.5 + PI * 0.5 * float(i) + 0.32
		draw_arc(_target_point, radius, start, start + PI * 0.5 - 0.64, 12, GOLD, 1.4, true)
		_diamond(_target_point + Vector2.from_angle(start - 0.32) * radius, 3.2, false)
	draw_arc(_target_point, radius + 4.0, 0.0, TAU, 32, GOLD_GLOW, 2.0, true)
	_diamond(_target_point, 2.6, true)


func _diamond(c: Vector2, r: float, filled: bool) -> void:
	var points := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(points, GOLD if filled else INK)
	points.append(points[0])
	draw_polyline(points, GOLD, 1.2, true)
