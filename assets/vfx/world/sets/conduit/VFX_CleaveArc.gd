extends Node2D
class_name VFX_CleaveArc

@export var duration := 0.15
@export var radius := 92.0
@export var arc_degrees := 150.0
@export var thickness := 24.0

@export var color_core := Color(0.95, 0.98, 1.0, 0.85)
@export var color_glow := Color(0.25, 0.65, 1.0, 0.30)

@export var spark_count := 10
@export var z := 212

var _t := 0.0
var _dir := Vector2.RIGHT
var _rng := RandomNumberGenerator.new()
var _sparks := [] # [{a,l,o}]

func setup(pos: Vector2, dir: Vector2, r: float = -1.0) -> void:
	global_position = pos
	if dir != Vector2.ZERO:
		_dir = dir.normalized()
	if r > 0.0:
		radius = r

func _ready() -> void:
	z_index = z
	material = null  # pixel-art kit (Batch B): the sprite blends normally
	_rng.randomize()
	_reset()

## Pooled reuse (PooledVfx): fresh sparks, first frame, unit scale.
func _on_pool_obtain() -> void:
	_reset()

func _reset() -> void:
	_t = 0.0
	scale = Vector2.ONE
	_sparks.clear()

	var half := deg_to_rad(arc_degrees) * 0.5
	for i in range(spark_count):
		_sparks.append({
			"a": _rng.randf_range(-half, half),
			"l": _rng.randf_range(10.0, 26.0),
			"o": _rng.randf_range(-6.0, 6.0),
		})

	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if _t >= duration:
		PooledVfx.release(self)
		return

	# slight punch scaling
	var p := clampf(_t / duration, 0.0, 1.0)
	var k := 1.0 - p
	scale = Vector2.ONE * lerpf(1.10, 0.92, 1.0 - k)
	queue_redraw()

func _draw() -> void:
	var p := clampf(_t / duration, 0.0, 1.0)
	var fade := 1.0 - p
	fade = fade * fade

	var half := deg_to_rad(arc_degrees) * 0.5

	var outer := radius
	var inner := maxf(0.0, radius - thickness)

	# Pixel-art kit (Batch B, 2026-09-27): one crescent sprite (tips on the +-half chord, convex edge on the outer radius, core colour) replaces the filled band polygon and the outer/inner rims.
	VfxKit.draw_crescent(self, Vector2.ZERO, _dir.angle(), outer, half, Color(color_core.r, color_core.g, color_core.b, color_core.a * fade), 3.0)

	# sparks
	# Pixel-art kit (Batch B, 2026-09-27): a streak sprite per spark, bright end outward, replaces the spark lines.
	for s in _sparks:
		var a := _dir.angle() + float(s["a"])
		var dir := Vector2(cos(a), sin(a))
		var start := dir * (inner + thickness * 0.65 + float(s["o"]))
		var end := start + dir * float(s["l"])
		VfxKit.draw_streak(self, start, end, 2.0, Color(1, 1, 1, 0.55 * fade))
