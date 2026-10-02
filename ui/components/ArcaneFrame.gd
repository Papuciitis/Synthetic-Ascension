@tool
class_name ArcaneFrame
extends Control
## The ornament layer for front-end panels and Archive cards: a thin outer
## rule, an inner rule inset from it, diamonds at the corners and a small star
## crowning the top edge. Drawn over (or under) a panel; it never takes input.
## `glow` warms the rules toward the selection gold, 0..1, for hover/selected.

@export var inset: float = 7.0:
	set(value):
		if inset == value:
			return
		inset = value
		queue_redraw()
@export var colour: Color = Color(0.58, 0.44, 0.27, 0.85):
	set(value):
		if colour == value:
			return
		colour = value
		queue_redraw()
@export var glow_colour: Color = Color(1.0, 0.78, 0.45, 1.0)
@export_range(0.0, 1.0) var glow: float = 0.0:
	set(value):
		if glow == value:
			return
		glow = value
		queue_redraw()
@export var crown: bool = true:
	set(value):
		if crown == value:
			return
		crown = value
		queue_redraw()
@export var outer_rule: bool = true:
	set(value):
		if outer_rule == value:
			return
		outer_rule = value
		queue_redraw()
@export var corners: bool = true:
	set(value):
		if corners == value:
			return
		corners = value
		queue_redraw()
## Arched top on the inner rule (the Archive card's portrait window).
@export var arch_height: float = 0.0:
	set(value):
		if arch_height == value:
			return
		arch_height = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var col := colour.lerp(glow_colour, glow * 0.85)
	var outer := Rect2(Vector2(0.5, 0.5), size - Vector2.ONE)
	if outer_rule:
		draw_rect(outer, Color(col, col.a * 0.9), false, 1.0, true)
	var inner := outer.grow(-inset)
	var inner_col := Color(col, col.a * (0.55 if outer_rule else 0.9))
	if arch_height > 0.0:
		_draw_arched(inner, inner_col)
	else:
		draw_rect(inner, inner_col, false, 1.0, true)
	if corners:
		for corner in [outer.position, Vector2(outer.end.x, outer.position.y), outer.end, Vector2(outer.position.x, outer.end.y)]:
			_diamond(corner, 4.5 + glow * 1.5, col, true)
	if crown:
		var top := Vector2(size.x * 0.5, 0.5)
		_diamond(top, 6.0 + glow * 2.0, col, false)
		draw_line(top + Vector2(0, -10 - glow * 4.0), top + Vector2(0, -7), col, 1.0, true)
		draw_line(top + Vector2(-16 - glow * 6.0, 0), top + Vector2(-8, 0), col, 1.0, true)
		draw_line(top + Vector2(8, 0), top + Vector2(16 + glow * 6.0, 0), col, 1.0, true)
	if glow > 0.01 and outer_rule:
		# A soft bloom just outside the frame while it is held.
		for i in range(4):
			var g := outer.grow(1.5 + i * 2.0)
			draw_rect(g, Color(glow_colour, 0.07 * glow * (4 - i) / 4.0), false, 2.0, true)


func _draw_arched(rect: Rect2, col: Color) -> void:
	var points := PackedVector2Array()
	points.append(Vector2(rect.position.x, rect.end.y))
	var steps := 40
	for i in range(steps + 1):
		var x := float(i) / steps
		points.append(rect.position + Vector2(x * rect.size.x, arch_y(x, arch_height, rect.size.x)))
	points.append(rect.end)
	points.append(Vector2(rect.position.x, rect.end.y))
	draw_polyline(points, col, 1.0, true)


## The pointed arch's top edge, in px below the rect top, at fraction x of the
## width. Each half is a quadratic Bezier from the spring (vertical tangent)
## to the apex, where the halves meet at an angle. card_portrait.gdshader
## evaluates the same curve to clip the portrait.
static func arch_y(x: float, height: float, _width: float) -> float:
	var half := minf(x, 1.0 - x)
	var t := sqrt(clampf(half * 2.0, 0.0, 1.0))
	var control := height * 0.45
	return (1.0 - t) * (1.0 - t) * height + 2.0 * (1.0 - t) * t * control


func _diamond(c: Vector2, r: float, col: Color, filled: bool) -> void:
	var points := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	if filled:
		draw_colored_polygon(points, Color(0.04, 0.034, 0.03, 1.0))
	points.append(points[0])
	draw_polyline(points, col, 1.2, true)
	if filled:
		var i := r * 0.4
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -i), c + Vector2(i, 0), c + Vector2(0, i), c + Vector2(-i, 0)]), col)
