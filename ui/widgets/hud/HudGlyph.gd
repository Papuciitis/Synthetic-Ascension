@tool
extends Control
## A small drawn diamond in the register's manner: an outline with a filled
## heart, or solid. Drawn once; redraws only when its look changes.

@export var colour: Color = Color(1.0, 0.62, 0.30, 1.0):
	set(value):
		if colour == value:
			return
		colour = value
		queue_redraw()
@export var solid: bool = false:
	set(value):
		if solid == value:
			return
		solid = value
		queue_redraw()
## Half-diagonal in px; 0 fits the control.
@export var radius: float = 0.0:
	set(value):
		if radius == value:
			return
		radius = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var r := radius if radius > 0.0 else minf(size.x, size.y) * 0.42
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	if solid:
		draw_colored_polygon(pts, colour)
		return
	draw_colored_polygon(pts, Color(0.04, 0.034, 0.03, 0.9))
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, colour, 1.2, true)
	var i := r * 0.42
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -i), c + Vector2(i, 0), c + Vector2(0, i), c + Vector2(-i, 0)]), colour)
