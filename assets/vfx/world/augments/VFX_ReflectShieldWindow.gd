extends Node2D
class_name VFX_ReflectShieldWindow

@export var duration: float = 0.14
@export var fade_out: float = 0.06

@export var padding: float = 6.0
@export var segments: int = 72

# wavy/rolling feel
@export var wave_amp: float = 3.5
@export var wave_freq: float = 4.0
@export var roll_speed: float = 10.0
@export var pulse_speed: float = 3.0

# thickness
@export var core_width: float = 2.6
@export var glow_width: float = 14.0
@export var fill_alpha: float = 0.10

@export var color_core: Color = Color(0.92, 0.98, 1.0, 1.0)
@export var color_glow: Color = Color(0.25, 0.65, 1.0, 0.65)
@export var color_fill: Color = Color(0.35, 0.55, 1.0, 0.25)

var hurtbox: Area2D = null
var _t: float = 0.0
var _r: float = 36.0

func setup(hb: Area2D, dur: float = -1.0) -> void:
	hurtbox = hb
	if dur > 0.0:
		duration = dur

func _ready() -> void:
	z_as_relative = false
	z_index = 4090
	top_level = true

	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if _t >= duration:
		queue_free()
		return

	if hurtbox != null and is_instance_valid(hurtbox):
		global_position = hurtbox.global_position
		_r = _get_hurtbox_radius(hurtbox) + padding

	queue_redraw()

func _get_hurtbox_radius(hb: Area2D) -> float:
	var csn: CollisionShape2D = null
	for c in hb.get_children():
		csn = c as CollisionShape2D
		if csn != null:
			break
	if csn == null or csn.shape == null:
		return 36.0

	var sh := csn.shape
	if sh is CircleShape2D:
		return (sh as CircleShape2D).radius
	if sh is RectangleShape2D:
		var sz := (sh as RectangleShape2D).size
		return maxf(sz.x, sz.y) * 0.5
	if sh is CapsuleShape2D:
		var cap := sh as CapsuleShape2D
		return maxf(cap.radius, cap.height * 0.5 + cap.radius)
	if sh is ConvexPolygonShape2D:
		var pts := (sh as ConvexPolygonShape2D).points
		var m := 0.0
		for p in pts:
			m = maxf(m, p.length())
		return maxf(m, 24.0)

	return 36.0

func _draw() -> void:
	var remain := duration - _t
	var fade := 1.0
	if remain < fade_out:
		fade = clampf(remain / maxf(fade_out, 0.001), 0.0, 1.0)
		fade = fade * fade

	var pulse := 0.85 + 0.15 * sin(_t * TAU * pulse_speed)
	var r := _r * (0.98 + 0.02 * pulse)

	if fill_alpha > 0.0:
		draw_circle(Vector2.ZERO, r * 0.98, Color(color_fill.r, color_fill.g, color_fill.b, color_fill.a * fill_alpha * fade))

	var pts := PackedVector2Array()
	var seg: int = maxi(24, int(segments))

	for i in range(seg + 1):
		var a := TAU * float(i) / float(seg)
		var w := sin(a * wave_freq + _t * roll_speed) * wave_amp
		var rr := r + w * pulse
		pts.append(Vector2(cos(a), sin(a)) * rr)

	draw_polyline(pts, Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * fade), glow_width, true)
	draw_polyline(pts, Color(color_core.r, color_core.g, color_core.b, color_core.a * fade), core_width, true)
