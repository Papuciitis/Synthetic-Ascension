extends Node2D
class_name VFX_TeslaPulseRing

@export var duration: float = 0.14
@export var radius: float = 180.0
@export var line_width: float = 2.5
@export var glow_width: float = 12.0
@export var alpha: float = 0.75

@export var color_core: Color = Color(0.95, 0.98, 1.0, 1.0)
@export var color_glow: Color = Color(0.25, 0.65, 1.0, 0.55)

@export var z: int = 3999

var _t: float = 0.0

func setup(pos: Vector2, r: float) -> void:
	global_position = pos
	radius = r

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = z

	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if _t >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var p := clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var fade := 1.0 - p
	fade = fade * fade

	var r := lerpf(radius * 0.65, radius, p)
	var seg := 72

	draw_arc(Vector2.ZERO, r, 0.0, TAU, seg,
		Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * alpha * fade),
		glow_width, true)

	draw_arc(Vector2.ZERO, r, 0.0, TAU, seg,
		Color(color_core.r, color_core.g, color_core.b, alpha * fade),
		line_width, true)
