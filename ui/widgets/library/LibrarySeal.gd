extends Control
## A simple pixel wax seal stamped with the diamond on the Chronicler's cloth.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var unit := minf(size.x, size.y) / 16.0
	var origin := (size - Vector2.ONE * unit * 16.0) * 0.5
	var wax := Color(0.53, 0.20, 0.15)
	var edge := Color(0.32, 0.12, 0.09)
	var seal := PackedVector2Array([Vector2(5, 1), Vector2(11, 1), Vector2(11, 3), Vector2(14, 3), Vector2(14, 6), Vector2(15, 6), Vector2(15, 11), Vector2(13, 11), Vector2(13, 14), Vector2(10, 14), Vector2(10, 15), Vector2(5, 15), Vector2(5, 13), Vector2(2, 13), Vector2(2, 10), Vector2(1, 10), Vector2(1, 5), Vector2(3, 5), Vector2(3, 3), Vector2(5, 3)])
	for i: int in range(seal.size()):
		seal[i] = origin + seal[i] * unit
	draw_colored_polygon(seal, edge)
	draw_rect(Rect2(origin + Vector2(4, 4) * unit, Vector2(9, 8) * unit), wax)
	# Four stepped corners, without decorative writing or an invented emblem.
	for step: int in range(4):
		var width := (step * 2 + 1) * unit
		draw_rect(Rect2(origin + Vector2(8 * unit - width * 0.5, (4 + step) * unit), Vector2(width, unit)), Color(0.77, 0.54, 0.32))
		draw_rect(Rect2(origin + Vector2(8 * unit - width * 0.5, (10 - step) * unit), Vector2(width, unit)), Color(0.77, 0.54, 0.32))
	draw_rect(Rect2(origin + Vector2(7, 7) * unit, Vector2(2, 2) * unit), wax)
