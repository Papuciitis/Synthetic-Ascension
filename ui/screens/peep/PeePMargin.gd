extends Control
## A still painted mark, not a portrait or a view of a literal destination.
## The uneven gold edge is open; its displaced shadow quietly closes it.

func _ready() -> void:
	custom_minimum_size.y = 72.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var origin := Vector2(roundf(size.x * 0.5), 35.0)
	var shadow := PackedVector2Array([
		origin + Vector2(-29, 28), origin + Vector2(-31, -20),
		origin + Vector2(11, -19), origin + Vector2(36, 9),
		origin + Vector2(35, 28), origin + Vector2(-29, 28),
	])
	draw_polyline(shadow, Color(0.005, 0.004, 0.003, 0.85), 4.0, true)
	draw_polyline(PackedVector2Array([
		origin + Vector2(11, -19), origin + Vector2(9, 10), origin + Vector2(36, 9),
	]), Color(0.005, 0.004, 0.003, 0.85), 3.5, true)
	var gold_edge := PackedVector2Array([
		origin + Vector2(-35, 20), origin + Vector2(-36, -25),
		origin + Vector2(3, -24), origin + Vector2(29, 3), origin + Vector2(29, 21),
	])
	# Broad faint underpaint and broken, differently weighted edges keep the
	# small native mark rough beside the unfinished opening paintings.
	draw_polyline(gold_edge, Color(0.49, 0.35, 0.17, 0.22), 5.0, true)
	draw_polyline(gold_edge, Color(0.69, 0.54, 0.30, 0.8), 1.5, true)
	draw_polyline(PackedVector2Array([
		origin + Vector2(3, -24), origin + Vector2(2, 3), origin + Vector2(24, 3),
	]), Color(0.76, 0.62, 0.38, 0.72), 1.2, true)
	draw_line(origin + Vector2(-35, 20), origin + Vector2(-16, 20), Color(0.66, 0.50, 0.28, 0.65), 1.6, true)
	draw_line(origin + Vector2(17, 21), origin + Vector2(29, 21), Color(0.66, 0.50, 0.28, 0.65), 1.3, true)
	draw_line(origin + Vector2(-35, -20), origin + Vector2(-35, -6), Color(0.85, 0.73, 0.48, 0.6), 0.8, true)
	draw_line(origin + Vector2(-25, -24), origin + Vector2(-7, -23), Color(0.84, 0.71, 0.46, 0.55), 0.9, true)
