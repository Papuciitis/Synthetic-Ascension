extends Node2D
class_name VFX_ProvidenceBurst

## Broken Providence cashing out: a gold shockwave with one spoke per banked
## point of Misfortune, so the size of the jackpot is legible at a glance.

@export var duration: float = 0.42
@export var radius: float = 120.0
@export var spokes: int = 8

const CORE: Color = Color(1.0, 0.95, 0.72, 1.0)
const GLOW: Color = Color(1.0, 0.72, 0.14, 0.85)

var _t: float = 0.0


func setup(r: float, banked: int) -> void:
	radius = r
	spokes = clampi(banked, 1, 25)


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 3998
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
	var fade: float = (1.0 - p) * (1.0 - p)
	var r: float = lerpf(radius * 0.25, radius, sqrt(p))

	draw_circle(Vector2.ZERO, r * 0.55, Color(GLOW.r, GLOW.g, GLOW.b, 0.22 * fade))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(GLOW.r, GLOW.g, GLOW.b, GLOW.a * fade), 11.0, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(CORE.r, CORE.g, CORE.b, fade), 2.5, true)

	# Spokes lag the ring slightly so the burst reads as thrown outward.
	var spoke_r: float = r * lerpf(0.35, 1.12, p)
	for i in range(spokes):
		var angle: float = TAU * (float(i) / float(spokes)) - PI * 0.5
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		draw_line(dir * (spoke_r * 0.45), dir * spoke_r, Color(CORE.r, CORE.g, CORE.b, 0.9 * fade), 3.0, true)
