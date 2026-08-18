extends Node2D
class_name VFX_BomberHazardRing

@export var base_alpha: float = 0.18
@export var hot_alpha: float = 0.55
@export var line_width: float = 3.0
@export var glow_width: float = 10.0
@export var dash_count: int = 18
@export var dash_gap: float = 0.25

@export var color_core: Color = Color(1.00, 0.35, 0.20, 1.0)
@export var color_glow: Color = Color(1.00, 0.15, 0.85, 0.60)

var _enemy: EnemyActor = null
var _r: float = 96.0
var _trigger_d: float = 80.0
var _t: float = 0.0
var _redraw_accum: float = 0.0

# Beyond this distance the telegraph cannot matter to the player; skip drawing
# entirely instead of tessellating dashed arcs every frame for the bomber's
# whole lifetime.
const DRAW_MAX_PLAYER_DIST := 1200.0
const REDRAW_INTERVAL := 1.0 / 30.0

func setup(e: EnemyActor) -> void:
	_enemy = e
	if _enemy != null and _enemy.spec != null:
		_r = maxf(_enemy.spec.explode_radius, 8.0)
		_trigger_d = maxf(_enemy.spec.explode_trigger_distance, 8.0)

func _ready() -> void:
	# As child of enemy: local position is fine
	position = Vector2.ZERO
	z_index = -1

	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	if _enemy == null or not is_instance_valid(_enemy) or _enemy.dead:
		queue_free()
		return
	var player := _enemy.player
	if player == null or not is_instance_valid(player):
		return
	var dist_sq := _enemy.global_position.distance_squared_to(player.global_position)
	if dist_sq > DRAW_MAX_PLAYER_DIST * DRAW_MAX_PLAYER_DIST:
		if visible:
			visible = false
		return
	if not visible:
		visible = true
	_redraw_accum += dt
	if _redraw_accum >= REDRAW_INTERVAL:
		_redraw_accum = 0.0
		queue_redraw()

func _draw() -> void:
	if _enemy == null or _enemy.player == null or not is_instance_valid(_enemy.player):
		return

	var dist: float = _enemy.global_position.distance_to(_enemy.player.global_position)

	# hotter when player is near trigger distance
	var hot: float = 1.0 - clampf(dist / maxf(_trigger_d, 0.001), 0.0, 1.0)
	hot = hot * hot

	var fade: float = lerpf(base_alpha, hot_alpha, hot)
	var pulse: float = 0.85 + 0.15 * sin(_t * lerpf(2.0, 7.0, hot) * TAU)
	var r: float = _r * pulse

	# dashed ring; each dash spans ~20 degrees, so a handful of segments per
	# dash is visually identical at a fraction of the tessellation cost.
	var segs: int = 8
	var dash_len: float = TAU / float(max(dash_count, 1))
	var phase: float = _t * lerpf(0.35, 1.35, hot)

	for i in range(dash_count):
		var a0 := i * dash_len + phase
		var a1 := a0 + dash_len * (1.0 - dash_gap)

		draw_arc(Vector2.ZERO, r, a0, a1, segs,
			Color(color_glow.r, color_glow.g, color_glow.b, fade * 0.65),
			glow_width, true)

		draw_arc(Vector2.ZERO, r, a0, a1, segs,
			Color(color_core.r, color_core.g, color_core.b, fade),
			line_width, true)
