extends Node2D
class_name VFX_StaminaCoreAura

@export var duration: float = 4.0
@export var fade_out: float = 0.25

@export var padding: float = 6.0
@export var segments: int = 72

@export var wave_amp: float = 4.5
@export var wave_freq: float = 5.0
@export var roll_speed: float = 7.5
@export var pulse_speed: float = 2.2

@export var core_width: float = 3.4
@export var glow_width: float = 14.0
@export var fill_alpha: float = 0.18

@export var color_core: Color = Color(1.0, 0.55, 0.20, 0.95)
@export var color_glow: Color = Color(0.85, 0.20, 1.0, 0.60)
@export var color_fill: Color = Color(0.60, 0.05, 0.10, 0.55)

# ✅ If you still can’t see it, flip this ON to force normal blending.
@export var force_mix_blend: bool = false

var hurtbox: Area2D = null
var _t: float = 0.0
var _r: float = 32.0
var _seed: float = 0.0

func setup(hb: Area2D, dur: float = -1.0) -> void:
	hurtbox = hb
	if dur > 0.0:
		duration = dur

func _ready() -> void:
	_seed = randf() * 1000.0

	z_as_relative = false
	z_index = 4095
	visible = true

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX if force_mix_blend else CanvasItemMaterial.BLEND_MODE_ADD
	material = mat

	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if _t >= duration:
		queue_free()
		return

	if hurtbox != null and is_instance_valid(hurtbox):
		# we are parented to hurtbox; stay centered
		position = Vector2.ZERO
		global_rotation = 0.0
		_r = _get_hurtbox_radius(hurtbox) + padding

	queue_redraw()

func _get_hurtbox_radius(hb: Area2D) -> float:
	# Find a CollisionShape2D under hurtbox (direct child)
	var csn: CollisionShape2D = null
	for c in hb.get_children():
		csn = c as CollisionShape2D
		if csn != null:
			break

	if csn == null or csn.shape == null:
		return 41.0 # your 82x82-ish default

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

	return 41.0

func _draw() -> void:
	var remain := duration - _t
	var fade := 1.0
	if remain < fade_out:
		fade = clampf(remain / maxf(fade_out, 0.001), 0.0, 1.0)
		fade *= fade

	# stronger pulse so it reads on gray
	var pulse := 0.80 + 0.20 * sin(_t * TAU * pulse_speed)
	var r := _r * (0.98 + 0.02 * pulse)

	# fill
	if fill_alpha > 0.0:
		draw_circle(Vector2.ZERO, r * 0.98,
			Color(color_fill.r, color_fill.g, color_fill.b, color_fill.a * fill_alpha * fade))

	# wavy ring points
	var seg: int = max(24, segments)
	var pts := PackedVector2Array()
	for i in range(seg + 1):
		var a := TAU * float(i) / float(seg)
		var w := sin(a * wave_freq + _t * roll_speed + _seed) * wave_amp
		var w2 := sin(a * (wave_freq * 0.5) - _t * (roll_speed * 1.35) + _seed * 0.7) * (wave_amp * 0.45)
		var rr := r + (w + w2) * pulse
		pts.append(Vector2(cos(a), sin(a)) * rr)

	# glow + core
	draw_polyline(pts, Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * fade), glow_width, true)
	draw_polyline(pts, Color(color_core.r, color_core.g, color_core.b, color_core.a * fade), core_width, true)

	# rolling packets
	for k in range(2):
		var aa := fmod(_t * 2.9 + float(k) * (TAU / 2.0), TAU)
		var rr2 := r + sin(aa * wave_freq + _t * roll_speed + _seed) * wave_amp
		var p := Vector2(cos(aa), sin(aa)) * rr2
		draw_circle(p, 3.2, Color(1, 1, 1, 0.22 * fade))
