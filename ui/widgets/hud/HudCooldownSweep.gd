extends Control
## The cooldown veil over an ability icon: the part of the square still
## cooling is shaded, and the shade withdraws clockwise from twelve o'clock as
## the ability recharges, with a thin gold edge on the sweep line. Purely a
## readout of `fraction` (1 = just used, 0 = ready); redraws only when the
## value it shows moves.

@export var veil: Color = Color(0.015, 0.012, 0.01, 0.72)
@export var edge: Color = Color(0.99, 0.84, 0.58, 0.85)

var fraction: float = 0.0:
	set(value):
		var next := clampf(value, 0.0, 1.0)
		if absf(next - fraction) < 0.002 and not (next == 0.0 and fraction != 0.0):
			return
		fraction = next
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if fraction <= 0.0 or size.x <= 1.0 or size.y <= 1.0:
		return
	var c := size * 0.5
	if fraction >= 0.999:
		draw_rect(Rect2(Vector2.ZERO, size), veil)
		return
	# The veil spans from the sweep line round to twelve o'clock.
	var start := -PI * 0.5 + TAU * (1.0 - fraction)
	var finish := PI * 1.5
	var angles: Array[float] = []
	var step := TAU / 72.0
	var a := start
	while a < finish:
		angles.append(a)
		a += step
	angles.append(finish)
	# The square's corners, so the fan meets them exactly.
	for k in range(4):
		var corner := -PI * 0.75 + float(k) * PI * 0.5
		while corner < start:
			corner += TAU
		if corner < finish:
			angles.append(corner)
	angles.sort()
	var pts := PackedVector2Array([c])
	for ang in angles:
		pts.append(_to_edge(c, ang))
	if pts.size() >= 3:
		draw_colored_polygon(pts, veil)
	draw_line(c, _to_edge(c, start), edge, 1.5, true)


func _to_edge(c: Vector2, ang: float) -> Vector2:
	var d := Vector2(cos(ang), sin(ang))
	var tx := c.x / maxf(absf(d.x), 0.0001)
	var ty := c.y / maxf(absf(d.y), 0.0001)
	return c + d * minf(tx, ty)
