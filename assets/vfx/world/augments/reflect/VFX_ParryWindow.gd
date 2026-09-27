extends Node2D
class_name VFX_ParryFlash

@export var duration: float = 0.10
@export var fade_out: float = 0.06

@export var radius: float = 48.0
@export var arc_degrees: float = 210.0
@export var thickness: float = 12.0
@export var rim_width: float = 2.5
@export var spin_speed: float = 16.0

@export var color_core: Color = Color(0.95, 0.98, 1.0, 1.0)
@export var color_glow: Color = Color(0.35, 0.75, 1.0, 0.60)

var _t := 0.0

func _ready() -> void:
	z_as_relative = false
	z_index = 4092
	top_level = true
	material = null  # pixel-art kit (Batch B): the sprite blends normally
	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if _t >= duration:
		queue_free()
		return
	rotation += spin_speed * dt
	queue_redraw()

func _draw() -> void:
	var remain := duration - _t
	var fade := 1.0
	if remain < fade_out:
		fade = clampf(remain / maxf(fade_out, 0.001), 0.0, 1.0)
		fade = fade * fade

	var p := clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var k := 1.0 - pow(1.0 - p, 3.0)

	var r_outer := lerpf(radius * 0.85, radius, k)

	var half := deg_to_rad(arc_degrees) * 0.5

	# Pixel-art kit (Batch B, 2026-09-27): one crescent sprite in the core colour replaces the filled glow band polygon and its core rim arc; the node's rotation supplies the spin.
	VfxKit.draw_crescent(self, Vector2.ZERO, 0.0, r_outer, half, Color(color_core.r, color_core.g, color_core.b, color_core.a * fade), rim_width)
