extends Node2D
class_name VFX_HexBlinkBurst

@export var lifetime: float = 0.18
@export var ring_radius: float = 10.0
@export var ring_expand: float = 44.0
@export var spokes: int = 10

@export var color_core: Color = Color(1.00, 0.70, 0.35, 1.0)
@export var color_glow: Color = Color(0.78, 0.22, 1.00, 0.75)

var _t: float = 0.0

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4095

	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if _t >= lifetime:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var x: float = clampf(_t / maxf(lifetime, 0.001), 0.0, 1.0)
	var fade: float = (1.0 - x)
	fade = fade * fade

	var r: float = ring_radius + ring_expand * x

	# ring glow + core
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * fade), 10.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(color_core.r, color_core.g, color_core.b, 0.95 * fade), 2.4)

	# spokes
	var n: int = maxi(6, spokes)
	for i in range(n):
		var a: float = (TAU * float(i) / float(n)) + (x * 0.6)
		var p0 := Vector2(cos(a), sin(a)) * (r * 0.35)
		var p1 := Vector2(cos(a), sin(a)) * (r * 1.05)
		draw_line(p0, p1, Color(color_glow.r, color_glow.g, color_glow.b, 0.30 * fade), 7.0, true)
		draw_line(p0, p1, Color(color_core.r, color_core.g, color_core.b, 0.85 * fade), 2.0, true)
