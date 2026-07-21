extends Node2D
class_name VFX_ExplosiveT

@export var out_time := 0.14
@export var impact_pause := 0.06
@export var return_time := 0.18

@export var width := 10.0
@export var glow_width := 22.0
@export var z := 206

@export var color_core := Color(0.92, 0.98, 1.0, 0.85)
@export var color_glow := Color(0.25, 0.65, 1.0, 0.22)

var _t := 0.0
var _to := Vector2.RIGHT * 120.0
var _len := 120.0
var _dir := Vector2.RIGHT

func setup(origin: Vector2, target: Vector2) -> void:
	global_position = origin
	_to = target - origin
	_len = _to.length()
	_dir = _to.normalized() if _len > 0.001 else Vector2.RIGHT

func _ready() -> void:
	z_index = z
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if _t >= (out_time + impact_pause + return_time):
		queue_free()
		return
	queue_redraw()

func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

func _draw_beam(from: Vector2, to: Vector2, base_a: float, w: float, fade: float) -> void:
	var seg := 18
	for i in range(seg):
		var t0 := float(i) / float(seg)
		var t1 := float(i + 1) / float(seg)
		var p0 := from.lerp(to, t0)
		var p1 := from.lerp(to, t1)

		var a := base_a * (1.0 - t0) * fade
		var ww := lerpf(w, w * 0.40, t0)

		draw_line(p0, p1, Color(color_glow.r, color_glow.g, color_glow.b, a * 0.75), ww * 1.6, true)
		draw_line(p0, p1, Color(color_core.r, color_core.g, color_core.b, a), ww, true)

func _draw() -> void:
	var total := out_time + impact_pause + return_time
	var p := clampf(_t / total, 0.0, 1.0)
	var fade := 1.0 - p
	fade = fade * fade

	var t_out := minf(_t, out_time)
	var t_imp := clampf(_t - out_time, 0.0, impact_pause)
	var t_ret := clampf(_t - out_time - impact_pause, 0.0, return_time)

	var end := _to

	# outbound head
	if _t <= out_time:
		var u := _ease_out(t_out / maxf(out_time, 0.001))
		var head := _dir * (_len * u)
		_draw_beam(Vector2.ZERO, head, 0.95, width, fade)
		draw_circle(head, width * 0.55, Color(0.95, 0.99, 1.0, 0.55 * fade))

	# impact pop (brief)
	elif _t <= out_time + impact_pause:
		_draw_beam(Vector2.ZERO, end, 0.55, width * 0.85, fade)
		var pop_k := 1.0 - (t_imp / maxf(impact_pause, 0.001))
		draw_circle(end, glow_width * lerpf(0.55, 1.05, pop_k), Color(0.35, 0.75, 1.0, 0.35 * pop_k))
		draw_arc(end, glow_width * lerpf(0.35, 1.25, pop_k), 0.0, TAU, 48, Color(0.95, 0.98, 1.0, 0.55 * pop_k), 3.0, true)

	# return beam (wider / more dangerous read)
	else:
		var u := _ease_out(t_ret / maxf(return_time, 0.001))
		var head := end.lerp(Vector2.ZERO, u)
		_draw_beam(end, head, 0.95, width * 1.15, fade)
		draw_circle(head, width * 0.65, Color(0.95, 0.99, 1.0, 0.45 * fade))
