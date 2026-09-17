extends Node2D
class_name VFX_RetaliationNova

## The answer to an evade: a hard white core that throws a gold shock ring out
## to exactly the radius the nova damaged, so the player can read its reach.

@export var duration: float = 0.30
@export var radius: float = 150.0
@export var color_core: Color = Color(1.00, 0.95, 0.78, 1.0)
@export var color_glow: Color = Color(1.00, 0.62, 0.22, 0.85)

var _spokes: Array[float] = []
var _t: float = 0.0


func setup(origin: Vector2, nova_radius: float) -> void:
	global_position = origin
	radius = nova_radius
	_build()


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4074
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if _spokes.is_empty():
		_build()
	set_process(true)
	queue_redraw()


func _build() -> void:
	_spokes.clear()
	var offset := randf() * TAU
	for i in range(9):
		_spokes.append(offset + TAU * float(i) / 9.0 + randf_range(-0.10, 0.10))


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p := clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var fade := 1.0 - p
	fade *= fade
	var eased := 1.0 - pow(1.0 - p, 3.0)
	var r := lerpf(radius * 0.22, radius, eased)

	draw_circle(Vector2.ZERO, r, Color(color_glow.r, color_glow.g, color_glow.b, 0.14 * fade))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * fade), 14.0, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(color_core.r, color_core.g, color_core.b, 0.95 * fade), 3.0, true)

	for angle in _spokes:
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(dir * (r * 0.55), dir * (r * 1.12), Color(color_glow.r, color_glow.g, color_glow.b, 0.35 * fade), 7.0, true)
		draw_line(dir * (r * 0.55), dir * (r * 1.12), Color(color_core.r, color_core.g, color_core.b, 0.75 * fade), 1.8, true)

	draw_circle(Vector2.ZERO, lerpf(34.0, 6.0, p), Color(1.0, 1.0, 1.0, 0.70 * fade))
