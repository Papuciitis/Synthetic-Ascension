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
	material = null  # pixel-art kit (Batch B): the sprite blends normally
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

	var kk: float = 0.65 + 0.35 * sin(_t * 12.0)
	var L: float = length * lerpf(0.65, 1.05, 1.0 - fade)

	# Pixel-art kit (Batch B, 2026-09-27): one three-ray fan sprite along local +X (setup rotates the node to the charge direction), squeezed to spread_deg and in the core colour, replaces the three glow+core rays and the faint dot.
	VfxKit.draw_fan(self, Vector2.ZERO, 0.0, L * (0.85 + 0.15 * kk), Color(color_core.r, color_core.g, color_core.b, color_core.a * fade), spread_deg)
