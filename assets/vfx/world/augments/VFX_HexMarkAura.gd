extends Node2D
class_name VFX_HexMarkAura

@export var padding: float = 10.0
@export var segments: int = 72

@export var wave_amp: float = 3.2
@export var wave_freq: float = 6.0
@export var roll_speed: float = 7.0
@export var pulse_speed: float = 2.0

@export var core_width: float = 2.8
@export var glow_width: float = 14.0

@export var color_core: Color = Color(1.00, 0.70, 0.35, 1.0)
@export var color_glow: Color = Color(0.78, 0.22, 1.00, 0.70)

var hurtbox: Area2D = null
var mark_owner: Node = null
var duration: float = 6.0

var _t: float = 0.0
var _r: float = 32.0
var _base_radius: float = -1.0
var _pts: PackedVector2Array = PackedVector2Array()

func setup(hb: Area2D, owner_in: Node, dur: float = 6.0) -> void:
	hurtbox = hb
	mark_owner = owner_in
	duration = dur
	_base_radius = -1.0

func _ready() -> void:
	z_as_relative = false
	z_index = 4095
	top_level = true

	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt

	if hurtbox != null and is_instance_valid(hurtbox):
		global_position = hurtbox.global_position
		# The hurtbox shape never changes; scanning its children every frame did.
		if _base_radius < 0.0:
			_base_radius = _get_hurtbox_radius(hurtbox)
		_r = _base_radius + padding

	# if mark meta is gone, kill instantly (stays in sync with gameplay)
	if mark_owner != null and is_instance_valid(mark_owner):
		if not mark_owner.has_meta("hex_mark_shots_left"):
			queue_free()
			return

	queue_redraw()

func _get_hurtbox_radius(hb: Area2D) -> float:
	var csn: CollisionShape2D = null
	for c in hb.get_children():
		csn = c as CollisionShape2D
		if csn != null:
			break
	if csn == null or csn.shape == null:
		return 32.0

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

	return 32.0

func _draw() -> void:
	var pulse: float = 0.90 + 0.10 * sin(_t * TAU * pulse_speed)
	var r: float = _r * (0.98 + 0.02 * pulse)

	# Build a slightly “hex-ish” wavy ring by biasing points toward 6 corners.
	# The point buffer is reused across frames instead of reallocated.
	var seg: int = max(24, segments)
	if _pts.size() != seg + 1:
		_pts.resize(seg + 1)

	for i in range(seg + 1):
		var a: float = TAU * float(i) / float(seg)

		# hex bias: 0..1 where 1 = near corner (cos 3a peaks at corners)
		var hex_bias: float = 0.78 + 0.22 * absf(cos(a * 3.0))

		var w1: float = sin(a * wave_freq + _t * roll_speed) * wave_amp
		var w2: float = sin(a * (wave_freq * 0.5) - _t * (roll_speed * 1.25)) * (wave_amp * 0.55)

		var rr: float = (r / hex_bias) + (w1 + w2) * pulse
		_pts[i] = Vector2(cos(a), sin(a)) * rr

	draw_polyline(_pts, Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a), glow_width, true)
	draw_polyline(_pts, Color(color_core.r, color_core.g, color_core.b, 1.0), core_width, true)

	# pips = shots left
	var shots_left: int = 0
	if mark_owner != null and is_instance_valid(mark_owner) and mark_owner.has_meta("hex_mark_shots_left"):
		shots_left = int(mark_owner.get_meta("hex_mark_shots_left"))

	var pip_n: int = clampi(shots_left, 0, 10)
	for k in range(pip_n):
		var aa: float = (TAU * float(k) / maxf(1.0, float(pip_n))) + (_t * 0.9)
		var p := Vector2(cos(aa), sin(aa)) * (r * 1.05)
		draw_circle(p, 2.6, Color(1, 1, 1, 0.55))
		draw_circle(p, 1.2, Color(color_core.r, color_core.g, color_core.b, 0.95))
