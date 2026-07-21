extends Node2D
class_name SpiderlingVisual

@export var body_scale: float = 1.0

@export var body_color: Color = Color(0.12, 0.75, 0.25, 1.0)      # poison-green
@export var outline_color: Color = Color(0.02, 0.10, 0.04, 1.0)
@export var leg_color: Color = Color(0.05, 0.22, 0.09, 1.0)
@export var glow_color: Color = Color(0.45, 1.0, 0.55, 0.20)

@export var wiggle_amp: float = 0.45
@export var wiggle_speed: float = 10.0
@export var z: int = 5

var _t: float = 0.0

func _ready() -> void:
	z_index = z
	set_process(true)

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()

func _draw() -> void:
	var s: float = body_scale

	# Body segments (compact = NOT sperm)
	var r_ab: float = 7.5 * s
	var r_th: float = 5.3 * s
	var r_hd: float = 3.6 * s

	var p_ab: Vector2 = Vector2(-3.6 * s, 0.0)  # abdomen
	var p_th: Vector2 = Vector2( 2.8 * s, 0.0)  # thorax
	var p_hd: Vector2 = Vector2( 6.8 * s, 0.0)  # head

	# Soft poison glow
	draw_circle(p_th, r_th * 2.25, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a))

	# Outline + fill (three circles)
	_draw_blob(p_ab, r_ab, s)
	_draw_blob(p_th, r_th, s)
	_draw_blob(p_hd, r_hd, s)

	# Eyes
	draw_circle(p_hd + Vector2(1.1 * s, -0.9 * s), 0.7 * s, Color(1, 1, 1, 0.85))
	draw_circle(p_hd + Vector2(1.1 * s,  0.9 * s), 0.7 * s, Color(1, 1, 1, 0.85))

	# Legs: 4 per side (8 total) with wiggle
	var base: Vector2 = p_th + Vector2(-0.6 * s, 0.0)
	var leg1: float = 9.0 * s
	var leg2: float = 6.5 * s

	for i in range(4):
		for side_sign_i in [-1, 1]:
			var side_sign: float = float(side_sign_i)

			# spread angles from front to back
			var ang0: float = deg_to_rad(20.0 + float(i) * 18.0) * side_sign
			var wig: float = sin(_t * wiggle_speed + float(i) * 1.35 + (0.0 if side_sign < 0.0 else 2.1)) * wiggle_amp
			var ang: float = ang0 + (wig * 0.20)

			var mid: Vector2 = base + Vector2(cos(ang), sin(ang)) * leg1
			var tip: Vector2 = mid + Vector2(cos(ang) * 0.75, sin(ang) * 0.75) * leg2

			draw_line(base, mid, leg_color, 1.3 * s, true)
			draw_line(mid, tip, leg_color, 1.1 * s, true)

func _draw_blob(pos: Vector2, r: float, s: float) -> void:
	draw_circle(pos, r + 1.0 * s, outline_color)
	draw_circle(pos, r, body_color)
