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
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_rng.randomize()
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
		queue_free()
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
	var a0 := _dir.angle() - half
	var a1 := _dir.angle() + half

	var outer := radius
	var inner := maxf(0.0, radius - thickness)

	# filled crescent polygon
	var seg := 48
	var pts: PackedVector2Array = []
	for i in range(seg + 1):
		var a := lerpf(a0, a1, float(i) / float(seg))
		pts.append(Vector2(cos(a), sin(a)) * outer)
	for i in range(seg, -1, -1):
		var a := lerpf(a0, a1, float(i) / float(seg))
		pts.append(Vector2(cos(a), sin(a)) * inner)

	draw_colored_polygon(pts, Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * fade))

	# crisp rims
	draw_arc(Vector2.ZERO, outer, a0, a1, seg, Color(color_core.r, color_core.g, color_core.b, color_core.a * fade), 3.0, true)
	draw_arc(Vector2.ZERO, inner, a0, a1, seg, Color(color_core.r, color_core.g, color_core.b, color_core.a * 0.55 * fade), 2.0, true)

	# sparks
	for s in _sparks:
		var a := _dir.angle() + float(s["a"])
		var dir := Vector2(cos(a), sin(a))
		var start := dir * (inner + thickness * 0.65 + float(s["o"]))
		var end := start + dir * float(s["l"])
		draw_line(start, end, Color(1, 1, 1, 0.55 * fade), 2.0, true)
