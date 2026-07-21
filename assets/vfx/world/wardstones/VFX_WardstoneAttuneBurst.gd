extends Node2D
class_name WardstoneAttuneBurst

@export var duration: float = 0.62
@export var line_width: float = 10.0
@export var dash_count: int = 12
@export var dash_gap: float = 0.26
@export var z: int = 210

var _radius: float = 76.0
var _t: float = 0.0

func setup(pos: Vector2, radius: float) -> void:
	global_position = pos
	_radius = maxf(radius, 1.0)

func _ready() -> void:
	z_index = z
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
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
	var p: float = clampf(_t / duration, 0.0, 1.0)
	var k: float = 1.0 - p
	k = k * k

	var r0: float = _radius * 0.35
	var r: float = lerpf(r0, _radius * 1.25, _ease_out(p))
	var w: float = lerpf(line_width, line_width * 0.35, p)

	# Core flash
	var flash := clampf(1.0 - (p / 0.32), 0.0, 1.0)
	if flash > 0.0:
		draw_circle(Vector2.ZERO, r * 0.52, Color(0.55, 0.88, 1.0, 0.22 * flash * k))

	# Dashed outer ring
	var base_col := Color(0.92, 0.98, 1.0, 0.85 * k)
	var dash_len: float = TAU / float(max(dash_count, 1))
	for i in range(dash_count):
		var a0: float = i * dash_len + p * 0.35
		var a1: float = a0 + dash_len * (1.0 - dash_gap)
		draw_arc(Vector2.ZERO, r, a0, a1, 24, base_col, w, true)

	# Inner ring
	var r2 := r * 0.72
	draw_arc(Vector2.ZERO, r2, 0.0, TAU, 96, Color(0.55, 0.85, 1.0, 0.22 * k), maxf(2.0, w * 0.25), true)

	# Spokes burst
	var spoke_n := 9
	var spoke_len := r * 0.44
	var spoke_col := Color(0.75, 0.93, 1.0, 0.55 * k)
	for j in range(spoke_n):
		var a := (TAU / float(spoke_n)) * float(j) + p * 0.65
		var d := Vector2(cos(a), sin(a))
		var s0 := d * (r * 0.15)
		var s1 := d * (r * 0.15 + spoke_len)
		draw_line(s0, s1, spoke_col, maxf(1.5, w * 0.18), true)

	# Tiny center kick
	draw_circle(Vector2.ZERO, maxf(3.0, w * 0.20), Color(0.95, 0.99, 1.0, 0.55 * k))
