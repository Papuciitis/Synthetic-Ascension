extends Node2D
class_name VFX_ChargeWindup

@export var duration: float = 0.55
@export var length: float = 44.0
@export var spread_deg: float = 32.0
@export var core_width: float = 3.0
@export var glow_width: float = 14.0

@export var color_core: Color = Color(1.0, 0.85, 0.35, 1.0)
@export var color_glow: Color = Color(1.0, 0.20, 0.75, 0.65)

var _t: float = 0.0

func setup(dir: Vector2, dur: float) -> void:
	if dir.length_squared() > 0.0001:
		rotation = dir.angle()
	duration = maxf(dur, 0.05)

func _ready() -> void:
	z_index = 1
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
	var p: float = clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var fade: float = 1.0 - p
	fade = fade * fade

	var half: float = deg_to_rad(spread_deg) * 0.5
	var rays := [-half, 0.0, +half]

	var kk: float = 0.65 + 0.35 * sin(_t * 12.0)
	var L: float = length * lerpf(0.65, 1.05, 1.0 - fade)

	for a in rays:
		var d := Vector2.RIGHT.rotated(a)
		var end := d * (L * (0.85 + 0.15 * kk))

		draw_line(Vector2.ZERO, end, Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * fade), glow_width, true)
		draw_line(Vector2.ZERO, end, Color(color_core.r, color_core.g, color_core.b, color_core.a * fade), core_width, true)

	draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 1, 0.08 * fade))
