extends Node2D
class_name VFX_SpiritSlash

@export var duration: float = 0.18
@export var fade_out: float = 0.12

@export var size: float = 56.0
@export var finger_count: int = 5
@export var spread: float = 1.0          # radians fan width
@export var jaggedness: float = 0.22     # wobble strength

@export var core_width: float = 3.0
@export var glow_width: float = 14.0

@export var color_core: Color = Color(0.70, 0.95, 1.0, 1.0)
@export var color_glow: Color = Color(0.25, 0.65, 1.0, 0.65)

var _t: float = 0.0

func setup(from_pos: Vector2, to_pos: Vector2, is_crit: bool = false) -> void:
	global_position = to_pos

	var d: Vector2 = to_pos - from_pos
	if d.length_squared() < 0.001:
		d = Vector2.RIGHT
	rotation = d.angle()

	if is_crit:
		color_core = Color(1.00, 0.70, 0.35, 1.0)
		color_glow = Color(0.78, 0.22, 1.00, 0.75)
		size *= 1.15
		core_width *= 1.1
		glow_width *= 1.15

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4095

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
	var remain: float = duration - _t
	var fade: float = 1.0
	if remain < fade_out:
		fade = clampf(remain / maxf(fade_out, 0.001), 0.0, 1.0)
		fade = fade * fade

	var p: float = clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var swell: float = 0.82 + 0.18 * sin(p * PI)
	var base_len: float = size * swell

	# Pixel-art kit (Batch B, 2026-09-27): a faint disc sprite replaces the bloom circle; one claw sprite from the origin along local +X replaces the five jagged glow+core finger polylines and the two crossing glow+core slash lines (the crit variant keeps its colours and 1.15x size from setup).
	VfxKit.draw_disc(self, Vector2.ZERO, base_len * 0.35, Color(color_glow.r, color_glow.g, color_glow.b, 0.10 * fade))
	VfxKit.draw_claw(self, Vector2.ZERO, 0.0, base_len, Color(color_core.r, color_core.g, color_core.b, fade))
