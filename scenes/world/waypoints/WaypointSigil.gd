extends Node2D
class_name WaypointSigil

@export var base_alpha: float = 0.16
@export var active_alpha: float = 0.26
@export var spin_deg_per_sec: float = 7.5
@export var sparkle_radius: float = 30.0
@export var sparkle_count: int = 7
@export var sparkle_alpha: float = 0.18
@export var z: int = -40

## Shared 30 Hz wall-clock bucket, the same idiom as
## ManifestationEffect.pulse_redraw: every idle painter lands on the same frames
## instead of drifting out of phase with the rest.
const PULSE_REDRAW_MS: int = 33

## Beyond this a sigil cannot reach the screen: half of a 1920x1080 viewport's
## diagonal is ~1101 px, plus the sparkle ring and HitFeel's 18 px camera punch.
## The camera is a child of the player, so player distance is camera distance.
## The model is VFX_BomberHazardRing.
const DRAW_MAX_PLAYER_DIST: float = 1400.0

var _t: float = 0.0
var _spark: Array = []
var _last_pulse_bucket: int = -1
var _player: Node2D = null

@onready var sigil: Sprite2D = $Sigil

func _ready() -> void:
	z_index = z
	if sigil != null:
		sigil.modulate = Color(1, 1, 1, base_alpha)
		sigil.material = CanvasItemMaterial.new()
		(sigil.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 1000.0) ^ int(global_position.y * 1000.0) ^ 0xBADC0DE
	for i in range(max(0, sparkle_count)):
		_spark.append({
			"a": rng.randf_range(0.0, TAU),
			"r": rng.randf_range(sparkle_radius * 0.35, sparkle_radius),
			"s": rng.randf_range(0.7, 1.6),
			"p": rng.randf_range(0.0, TAU),
		})

	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if sigil != null:
		sigil.rotation_degrees += spin_deg_per_sec * dt
		# subtle breathing
		var k := 0.5 + 0.5 * sin(_t * 1.2)
		sigil.modulate.a = lerpf(base_alpha, active_alpha, k)

	# Nine of these light Segment 1 and every one of them redrew fourteen circles
	# a frame, wherever the player was. Off-screen they paint nothing anyone can
	# see, and on-screen seven twinkling sparks look identical on the shared
	# 30 Hz bucket. _t keeps running either way, so a sigil walked back up to
	# resumes its twinkle in phase.
	if not _in_draw_range():
		if visible:
			visible = false
		return
	if not visible:
		visible = true
	var bucket := floori(float(Time.get_ticks_msec()) / float(PULSE_REDRAW_MS))
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
	var col: Color = Color(0.55, 0.85, 1.0, sparkle_alpha)

	for s in _spark:
		var a: float = float(s.a) + float(_t) * float(s.s)
		var p: Vector2 = Vector2(cos(a), sin(a)) * float(s.r)

		var tw: float = 0.55 + 0.45 * sin(float(s.p) + float(_t) * 3.2)
		var c: Color = Color(col.r, col.g, col.b, col.a * tw)

		draw_circle(p, 1.5, c)
		draw_circle(p, 3.2, Color(c.r, c.g, c.b, c.a * 0.35))
