extends Node2D
class_name PulseRing

@export var duration: float = 0.26
@export var line_width: float = 8.0
@export var fill_alpha: float = 0.09
@export var line_alpha: float = 0.65

@export var start_radius_mul: float = 0.18
@export var trailing_ring_mul: float = 0.86
@export var trailing_alpha_mul: float = 0.35

@export var dash_count: int = 10
@export var dash_gap: float = 0.22 # radians-ish gap amount
@export var z: int = 200

var _radius: float = 64.0
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

	# expanding shockwave radius
	var r0: float = _radius * start_radius_mul
	var r: float = lerpf(r0, _radius, _ease_out(p))

	# thickness shrinks a bit as it expands
	var w: float = lerpf(line_width, line_width * 0.35, p)

	# brief inner fill flash (only early)
	var fill_k: float = clampf(1.0 - (p / 0.55), 0.0, 1.0)
	if fill_k > 0.0 and fill_alpha > 0.0:
		draw_circle(Vector2.ZERO, r * 0.96, Color(0.25, 0.60, 1.0, fill_alpha * fill_k * k))

	# dashed main ring (reads as “force”, less like a UI circle)
	var segs := 24
	var base_col := Color(0.92, 0.97, 1.0, line_alpha * k)
	var dash_len: float = TAU / float(max(dash_count, 1))

	for i in range(dash_count):
		var a0: float = i * dash_len
		var a1: float = a0 + dash_len * (1.0 - dash_gap)
		draw_arc(Vector2.ZERO, r, a0, a1, segs, base_col, w, true)

	# trailing ring (gives depth)
	var r2: float = r * trailing_ring_mul
	var col2 := Color(0.70, 0.90, 1.0, line_alpha * trailing_alpha_mul * k)
	draw_arc(Vector2.ZERO, r2, 0.0, TAU, 64, col2, maxf(2.0, w * 0.35), true)

	# tiny center “kick”
	draw_circle(Vector2.ZERO, maxf(2.0, w * 0.22), Color(0.95, 0.98, 1.0, 0.40 * k))
