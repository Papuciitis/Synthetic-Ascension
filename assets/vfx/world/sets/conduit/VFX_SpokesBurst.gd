extends Node2D
class_name SpokesBurst

@export var duration: float = 0.14
@export var spokes: int = 14
@export var inner: float = 8.0
@export var outer: float = 74.0
@export var width: float = 3.0
@export var alpha: float = 0.85
@export var rotate_speed: float = 8.0
@export var jitter_deg: float = 10.0
@export var z: int = 210

# NEW: color palette (defaults = your current tech-blue)
@export var color_core: Color = Color(0.95, 0.98, 1.0, 1.0)
@export var color_glow: Color = Color(0.25, 0.60, 1.0, 1.0)
@export var glow_mul: float = 0.35

var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _angles: PackedFloat32Array
var _lens: PackedFloat32Array

func setup(pos: Vector2) -> void:
	global_position = pos

func _ready() -> void:
	z_index = z
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_rng.randomize()
	_angles = PackedFloat32Array()
	_lens = PackedFloat32Array()

	var j := deg_to_rad(jitter_deg)
	for i in range(spokes):
		_angles.append(TAU * float(i) / float(max(spokes, 1)) + _rng.randf_range(-j, j))
		_lens.append(_rng.randf_range(0.65, 1.10))

	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if _t >= duration:
		queue_free()
		return

	rotation += rotate_speed * dt
	queue_redraw()

func _draw() -> void:
	var p := clampf(_t / duration, 0.0, 1.0)
	var k := 1.0 - p
	k = k * k

	var col := Color(color_core.r, color_core.g, color_core.b, alpha * k)
	var col2 := Color(color_glow.r, color_glow.g, color_glow.b, alpha * glow_mul * k)

	var out_r := lerpf(inner, outer, 1.0 - pow(1.0 - p, 3.0))

	for i in range(spokes):
		var a := _angles[i]
		var dir := Vector2(cos(a), sin(a))
		var o := out_r * _lens[i]
		draw_line(dir * inner, dir * o, col, width, true)

	draw_arc(Vector2.ZERO, inner * 1.15, 0.0, TAU, 40, col2, maxf(2.0, width * 0.55), true)
	draw_circle(Vector2.ZERO, maxf(2.0, width * 0.65), col)
