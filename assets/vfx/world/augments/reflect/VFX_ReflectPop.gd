extends Node2D
class_name VFX_ReflectFlash

@export var duration: float = 0.08
@export var fade_out: float = 0.05

@export var spokes: int = 10
@export var radius: float = 18.0
@export var spoke_len: float = 16.0
@export var ring_width: float = 2.2

@export var color_core: Color = Color(0.95, 0.98, 1.0, 1.0)
@export var color_glow: Color = Color(0.35, 0.75, 1.0, 0.70)

var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _jitter: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	z_as_relative = false
	z_index = 4093
	top_level = true
	material = null  # pixel-art kit (Batch B): the sprite blends normally
	_rng.randomize()

	_jitter.resize(spokes)
	for i in range(spokes):
		_jitter[i] = _rng.randf_range(-0.15, 0.15)

	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if _t >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var remain := duration - _t
	var fade := 1.0
	if remain < fade_out:
		fade = clampf(remain / maxf(fade_out, 0.001), 0.0, 1.0)
		fade = fade * fade

	var p := clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var k := 1.0 - pow(1.0 - p, 3.0)

	var r := lerpf(radius * 0.65, radius, k)
	var sl := lerpf(spoke_len * 0.55, spoke_len, k)

	# Pixel-art kit (Batch B, 2026-09-27): one ring sprite replaces the glow+core arc pair; one spokes sprite (it carries its own centre dot) replaces the jittered glow+core spoke lines and the centre circle, the first jitter value giving it a per-instance spin.
	var spin := _jitter[0] if _jitter.size() > 0 else 0.0
	VfxKit.draw_ring(self, Vector2.ZERO, r, Color(color_core.r, color_core.g, color_core.b, 0.9 * fade), ring_width)
	VfxKit.draw_spokes(self, Vector2.ZERO, r * 0.55 + sl, Color(color_core.r, color_core.g, color_core.b, 0.85 * fade), spin)
