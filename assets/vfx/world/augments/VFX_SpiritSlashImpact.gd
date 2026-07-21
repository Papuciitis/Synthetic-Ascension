extends Node2D
class_name VFX_SpiritSlashImpact

@export var lifetime: float = 0.20
@export var size: float = 54.0

@export var color_core: Color = Color(0.95, 0.98, 1.0, 1.0)
@export var color_glow: Color = Color(0.25, 0.65, 1.0, 0.70)

var _t: float = 0.0
var _ang: float = 0.0

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4095
	_ang = randf() * TAU

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

	var s: float = size * (0.85 + 0.25 * x)

	# two crossing slashes
	var a0: float = _ang
	var a1: float = _ang + TAU * 0.25

	var p0a := Vector2(cos(a0), sin(a0)) * s
	var p0b := -p0a
	var p1a := Vector2(cos(a1), sin(a1)) * (s * 0.85)
	var p1b := -p1a

	draw_line(p0a, p0b, Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * 0.55 * fade), 14.0, true)
	draw_line(p1a, p1b, Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * 0.45 * fade), 10.0, true)

	draw_line(p0a, p0b, Color(color_core.r, color_core.g, color_core.b, 0.95 * fade), 2.6, true)
	draw_line(p1a, p1b, Color(color_core.r, color_core.g, color_core.b, 0.85 * fade), 2.0, true)

	# small shock ring
	draw_arc(Vector2.ZERO, s * 0.35, 0.0, TAU, 48, Color(color_glow.r, color_glow.g, color_glow.b, 0.22 * fade), 8.0)
