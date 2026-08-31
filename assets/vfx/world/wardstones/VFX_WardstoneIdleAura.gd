extends Node2D
class_name WardstoneIdleAura

@export var base_radius: float = 72.0
@export var inner_radius: float = 34.0
@export var line_width: float = 3.0
@export var intensity: float = 0.35 # 0..1
@export var sparkle_count: int = 10
@export var z: int = -15

## Shared 30 Hz wall-clock bucket, the same idiom as
## ManifestationEffect.pulse_redraw: every idle painter lands on the same frames
## instead of drifting out of phase with the rest.
const PULSE_REDRAW_MS: int = 33

## Beyond this the aura cannot reach the screen: half of a 1920x1080 viewport's
## diagonal is ~1101 px, plus the outer ring's radius and HitFeel's 18 px camera
## punch. The camera is a child of the player, so player distance is camera
## distance. The model is VFX_BomberHazardRing.
const DRAW_MAX_PLAYER_DIST: float = 1400.0

var _t: float = 0.0
var _spark: Array = []
var _last_pulse_bucket: int = -1
var _player: Node2D = null

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
	# The wardstone re-asserts its idle level every frame; only a level that
	# actually moved is worth a repaint.
	var clamped := clampf(v, 0.0, 1.0)
	if clamped == intensity:
		return
	intensity = clamped
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	# Off-screen the aura paints nothing anyone can see, and on-screen it is an
	# ambient breathe: 96- and 64-segment arcs plus ten twinkling sparks look
	# identical at the shared 30 Hz bucket. _t keeps running either way, so
	# walking back into range resumes the animation in phase.
	if not _in_draw_range():
		if visible:
			visible = false
		return
	if not visible:
		visible = true
	var bucket := int(Time.get_ticks_msec() / PULSE_REDRAW_MS)
	if bucket == _last_pulse_bucket:
		return
	_last_pulse_bucket = bucket
	queue_redraw()

func _in_draw_range() -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	if _player == null:
		# No player, no camera to be off: never cull on a guess.
		return true
	return global_position.distance_squared_to(_player.global_position) \
		<= DRAW_MAX_PLAYER_DIST * DRAW_MAX_PLAYER_DIST

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
