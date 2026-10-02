@tool
class_name ArcaneRule
extends Control
## A thin gold rule in the main-menu mock-up's manner: fading at both ends,
## with an optional diamond (or a diamond flanked by short ticks) at its centre.
## Purely drawn, so it stays crisp at any size and needs no art.

enum Ornament { NONE, DIAMOND, STAR }

@export var ornament: Ornament = Ornament.DIAMOND:
	set(value):
		if ornament == value:
			return
		ornament = value
		queue_redraw()
@export var colour: Color = Color(0.66, 0.5, 0.31, 0.75):
	set(value):
		if colour == value:
			return
		colour = value
		queue_redraw()
## 0 = centred ornament, otherwise the ornament sits at this fraction of the width.
@export_range(0.0, 1.0) var ornament_at: float = 0.5:
	set(value):
		if ornament_at == value:
			return
		ornament_at = value
		queue_redraw()
@export var fade_ends: bool = true:
	set(value):
		if fade_ends == value:
			return
		fade_ends = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size.y < 8.0:
		custom_minimum_size.y = 12.0


func _draw() -> void:
	var w := size.x
	var y := roundf(size.y * 0.5) + 0.5
	var at := w * ornament_at
	var gap := 0.0 if ornament == Ornament.NONE else (7.0 if ornament == Ornament.DIAMOND else 11.0)
	var steps := 32
	for i in range(steps):
		var a := float(i) / steps
		var b := float(i + 1) / steps
		var xa := w * a
		var xb := w * b
		if gap > 0.0 and xb > at - gap and xa < at + gap:
			continue
		var fade := 1.0
		if fade_ends:
			fade = clampf(minf(a, 1.0 - b) * 6.0, 0.0, 1.0)
		draw_line(Vector2(xa, y), Vector2(xb, y), Color(colour, colour.a * fade), 1.0, true)
	if ornament == Ornament.NONE:
		return
	var c := Vector2(at, y)
	var r := 4.0 if ornament == Ornament.DIAMOND else 3.5
	draw_polyline(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)]), colour, 1.2, true)
	if ornament == Ornament.STAR:
		var s := 9.0
		draw_line(c + Vector2(0, -s), c + Vector2(0, -r - 1), colour, 1.0, true)
		draw_line(c + Vector2(0, r + 1), c + Vector2(0, s), colour, 1.0, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -1.6), c + Vector2(1.6, 0), c + Vector2(0, 1.6), c + Vector2(-1.6, 0)]), colour)
