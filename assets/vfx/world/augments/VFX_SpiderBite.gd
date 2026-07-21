extends Node2D
class_name VFX_SpiderBite

@export var lifetime: float = 0.16
@export var fade_out: float = 0.06
@export var scale_mul: float = 1.0
@export var z: int = 4090

@export var color_poison: Color = Color(0.35, 1.0, 0.45, 0.85)
@export var color_dark: Color = Color(0.04, 0.16, 0.07, 0.90)
@export var color_glow: Color = Color(0.55, 1.0, 0.65, 0.22)

var _t: float = 0.0
var _rnd: float = 0.0

func setup(world_pos: Vector2, dir: Vector2 = Vector2.RIGHT) -> void:
	global_position = world_pos
	var d: Vector2 = dir.normalized()
	if d.length_squared() < 0.001:
		d = Vector2.RIGHT
	rotation = d.angle()
	_rnd = randf_range(-0.35, 0.35)

func _ready() -> void:
	top_level = true
	z_index = z
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)

func _process(dt: float) -> void:
	_t += dt
	if _t >= lifetime:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var remain: float = lifetime - _t
	var fade: float = 1.0
	if remain < fade_out:
		fade = clampf(remain / maxf(fade_out, 0.001), 0.0, 1.0)
		fade *= fade

	var s: float = scale_mul

	# glow puff
	draw_circle(Vector2.ZERO, 10.0 * s, Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * fade))

	# two fangs
	var fang_len: float = 7.0 * s
	var fang_ang: float = deg_to_rad(25.0)
	var start: Vector2 = Vector2(1.6 * s, 0.0)

	var a: float = -fang_ang + _rnd
	var b: float = +fang_ang + _rnd
	var p1: Vector2 = start + Vector2(cos(a), sin(a)) * fang_len
	var p2: Vector2 = start + Vector2(cos(b), sin(b)) * fang_len

	# punctures
	draw_circle(p1, 1.6 * s, Color(color_dark.r, color_dark.g, color_dark.b, 0.9 * fade))
	draw_circle(p2, 1.6 * s, Color(color_dark.r, color_dark.g, color_dark.b, 0.9 * fade))

	# fang slashes (compact, no tail)
	draw_line(start, p1, Color(color_poison.r, color_poison.g, color_poison.b, color_poison.a * fade), 2.4 * s, true)
	draw_line(start, p2, Color(color_poison.r, color_poison.g, color_poison.b, color_poison.a * fade), 2.4 * s, true)
	draw_line(start, p1, Color(1, 1, 1, 0.10 * fade), 5.0 * s, true)
	draw_line(start, p2, Color(1, 1, 1, 0.10 * fade), 5.0 * s, true)

	# little scratch “legs” makes it read insect-y
	for i in range(6):
		var ang: float = deg_to_rad(-70.0 + float(i) * 28.0) + _rnd * 0.5
		var pA: Vector2 = Vector2(cos(ang), sin(ang)) * (4.0 * s)
		var pB: Vector2 = Vector2(cos(ang), sin(ang)) * (10.0 * s)
		draw_line(pA, pB, Color(color_poison.r, color_poison.g, color_poison.b, 0.35 * fade), 1.3 * s, true)
