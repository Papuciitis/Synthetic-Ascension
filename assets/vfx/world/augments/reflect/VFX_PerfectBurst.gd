extends Node2D
class_name VFX_PerfectFlash

@export var duration: float = 0.12
@export var fade_out: float = 0.07

@export var radius: float = 34.0
@export var ring_width: float = 2.4

# lightning feel
@export var bolts: int = 3
@export var bolt_len: float = 54.0
@export var segments: int = 10
@export var jaggedness: float = 7.0

@export var color_core: Color = Color(1.00, 0.80, 0.45, 1.0)
@export var color_glow: Color = Color(0.78, 0.22, 1.00, 0.75)

var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _bolts: Array[PackedVector2Array] = []

func _ready() -> void:
	z_as_relative = false
	z_index = 4094
	top_level = true
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_rng.randomize()

	_build_bolts()

	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if _t >= duration:
		queue_free()
		return
	queue_redraw()

func _build_bolts() -> void:
	_bolts.clear()
	for i in range(max(1, bolts)):
		var a := _rng.randf() * TAU
		var dir := Vector2(cos(a), sin(a))
		_bolts.append(_make_bolt(Vector2.ZERO, dir * bolt_len, max(4, segments), jaggedness))

func _make_bolt(a: Vector2, b: Vector2, segs: int, jag: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(a)

	var ab := b - a
	var n := Vector2(-ab.y, ab.x).normalized()
	for i in range(1, segs):
		var t := float(i) / float(segs)
		var base := a + ab * t
		var off := n * _rng.randf_range(-jag, jag)
		pts.append(base + off)

	pts.append(b)
	return pts

func _draw() -> void:
	var remain := duration - _t
	var fade := 1.0
	if remain < fade_out:
		fade = clampf(remain / maxf(fade_out, 0.001), 0.0, 1.0)
		fade = fade * fade

	var p := clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var k := 1.0 - pow(1.0 - p, 3.0)

	var r := lerpf(radius * 0.7, radius, k)

	# ring
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * fade), ring_width * 3.4, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(color_core.r, color_core.g, color_core.b, 0.95 * fade), ring_width, true)

	# bolts
	for pts in _bolts:
		draw_polyline(pts, Color(color_glow.r, color_glow.g, color_glow.b, 0.35 * fade), 9.0, true)
		draw_polyline(pts, Color(color_core.r, color_core.g, color_core.b, 0.95 * fade), 2.4, true)

	draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1, 0.22 * fade))
