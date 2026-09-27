extends Node2D
class_name VFX_SpiderExplode

@export var duration: float = 0.28
@export var ring_width: float = 6.0
@export var glow_width: float = 22.0
@export var mist_alpha: float = 0.22
@export var droplet_count: int = 10
@export var droplet_len: float = 16.0

var _t: float = 0.0
var _radius: float = 52.0
var _core: Color = Color(0.75, 1.0, 0.25, 1.0)
var _glow: Color = Color(0.78, 0.22, 1.0, 0.7)
var _drops: PackedVector2Array = PackedVector2Array()

func setup(pos: Vector2, radius: float, core: Color, glow: Color) -> void:
	global_position = pos
	_radius = maxf(8.0, radius)
	_core = core
	_glow = glow

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4095

	material = null  # pixel-art kit (Batch B): the sprite blends normally

	_build_droplets()
	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if _t >= duration:
		queue_free()
		return
	queue_redraw()

func _build_droplets() -> void:
	_drops = PackedVector2Array()
	var n: int = maxi(0, droplet_count)
	for i in range(n):
		var ang: float = randf() * TAU
		var rr: float = randf_range(0.35, 1.0)
		_drops.append(Vector2(cos(ang), sin(ang)) * rr)

func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

func _draw() -> void:
	var u: float = clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var e: float = _ease_out(u)

	# expanding radius
	var r: float = _radius * e

	# fade out near the end
	var fade: float = 1.0 - u
	fade = fade * fade

	# Pixel-art kit (Batch B, 2026-09-27): a soft disc sprite replaces the mist circle, one ring sprite replaces the glow+core arc pair, and the centre flash circle is dropped.
	VfxKit.draw_disc(self, Vector2.ZERO, r * 0.92, Color(_core.r, _core.g, _core.b, mist_alpha * fade))
	VfxKit.draw_ring(self, Vector2.ZERO, r, Color(_core.r, _core.g, _core.b, 0.75 * fade), ring_width)

	# Pixel-art kit (Batch C, 2026-09-27): one splash sprite at the ring radius replaces the ten droplet streaks; the first seeded droplet direction gives each burst its own spin.
	var spin: float = _drops[0].angle() if _drops.size() > 0 else 0.0
	VfxKit.draw_splash(self, Vector2.ZERO, r, Color(_core.r, _core.g, _core.b, 0.55 * fade), spin)
