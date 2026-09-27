extends Node2D
class_name VFX_HeraldPulseRing

@export var duration: float = 0.22
@export var line_width: float = 6.0
@export var glow_width: float = 18.0
@export var dash_count: int = 14
@export var dash_gap: float = 0.22

@export var color_core: Color = Color(1.0, 0.80, 0.45, 0.95)  # warm core
@export var color_glow: Color = Color(0.78, 0.22, 1.0, 0.60)  # violet glow
@export var fill_color: Color = Color(0.18, 0.02, 0.20, 0.25)  # dark-ish underfill

var _t: float = 0.0
var _r: float = 220.0

func setup(pos: Vector2, radius: float) -> void:
	global_position = pos
	_r = maxf(radius, 8.0)

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4085

	material = null  # pixel-art kit (Batch B): the sprite blends normally

	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if _t >= duration:
		queue_free()
		return
	queue_redraw()

func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

func _draw() -> void:
	var p: float = clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var fade: float = 1.0 - p
	fade = fade * fade

	var k: float = _ease_out(p)
	var r: float = lerpf(_r * 0.35, _r, k)
	var w_core: float = lerpf(line_width, line_width * 0.45, p)

	# soft fill early
	var fill_k: float = clampf(1.0 - (p / 0.55), 0.0, 1.0)
	if fill_k > 0.0:
		# Pixel-art kit (Batch B, 2026-09-27): the soft disc sprite replaces the dark under-fill circle.
		VfxKit.draw_disc(self, Vector2.ZERO, r, Color(fill_color.r, fill_color.g, fill_color.b, fill_color.a * fill_k * fade))

	# dashed ring
	# Pixel-art kit (Batch B, 2026-09-27): one dashed-ring sprite in the core colour, spun by the wobble phase, replaces the dash_count glow+core arc pairs.
	var phase: float = sin(_t * 16.0) * 0.12
	VfxKit.draw_ring_dashed(self, Vector2.ZERO, r, Color(color_core.r, color_core.g, color_core.b, color_core.a * fade), phase, w_core)
