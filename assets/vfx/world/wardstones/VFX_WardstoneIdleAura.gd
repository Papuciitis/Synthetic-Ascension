extends Node2D
class_name WardstoneIdleAura

@export var base_radius: float = 72.0
@export var inner_radius: float = 34.0
@export var line_width: float = 3.0
@export var intensity: float = 0.35 # 0..1
@export var sparkle_count: int = 10
@export var z: int = -15

var _t: float = 0.0
var _spark: Array = []

func _ready() -> void:
	z_index = z
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 100.0) ^ int(global_position.y * 100.0) ^ 0x51A7BEEF
	for i in range(max(0, sparkle_count)):
		_spark.append({
			"a": rng.randf_range(0.0, TAU),
			"r": rng.randf_range(inner_radius * 0.9, base_radius * 0.98),
			"s": rng.randf_range(0.6, 1.4),
			"p": rng.randf_range(0.0, TAU),
		})

	set_process(true)
	queue_redraw()

func set_intensity(v: float) -> void:
	intensity = clampf(v, 0.0, 1.0)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()

func _draw() -> void:
	if intensity <= 0.001:
		return

	var pulse: float = 0.55 + 0.45 * sin(_t * 1.25)
	var a0: float = 0.06 * intensity
	var a1: float = 0.18 * intensity

	var col1: Color = Color(0.55, 0.85, 1.0, a1 * pulse)
	var col2: Color = Color(0.25, 0.55, 1.0, a0)

	# Two rings with slight phase offset.
	var r1: float = base_radius
	var r2: float = inner_radius
	draw_arc(Vector2.ZERO, r1, _t * 0.25, _t * 0.25 + TAU, 96, col1, line_width, true)
	draw_arc(Vector2.ZERO, r2, -_t * 0.35, -_t * 0.35 + TAU, 64, col2, maxf(2.0, line_width * 0.6), true)

	# Orbiting sparkles.
	for s in _spark:
		var a: float = float(s.a) + float(_t) * float(s.s)
		var p: Vector2 = Vector2(cos(a), sin(a)) * float(s.r)
		var tw: float = 0.55 + 0.45 * sin(float(s.p) + float(_t) * 3.4)
		var ca: float = (0.06 + 0.10 * tw) * intensity
		var c: Color = Color(0.75, 0.93, 1.0, ca)
		draw_circle(p, 1.6, c)
		draw_circle(p, 3.8, Color(c.r, c.g, c.b, c.a * 0.35))
