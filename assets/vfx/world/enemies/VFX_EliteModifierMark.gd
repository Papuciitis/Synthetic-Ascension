extends Node2D
class_name VFX_EliteModifierMark

## The tell for roadmap §9 elite modifiers, drawn on the body as a child of the
## elite (the Bomber's hazard ring is the pattern): a plate ring for ARMOURED,
## a hexagon at the shield radius for SHIELDED, a seam across the body for
## SPLITTING, a streak behind a moving FAST, and the VAMPIRIC pulse on the
## sprite's own tint. Under accessibility reduced_motion the pulse and the
## streak stop and the static marks stay, so the modifier is still readable,
## just still: FAST then draws its chevrons, as it does whenever another
## modifier owns the body tint.

@export var line_width: float = 3.0
@export var glow_width: float = 9.0
@export var plate_count: int = 6
@export var plate_gap: float = 0.18
@export var body_radius: float = 26.0
@export var streak_length: float = 34.0
@export var vampiric_pulse_hz: float = 1.6
# FAST's still tell: a row of chevrons under the body, the fast-forward glyph.
@export var fast_chevron_count: int = 3
@export var fast_chevron_size: float = 10.0
@export var fast_chevron_spacing: float = 9.0
@export var fast_chevron_offset: float = 6.0

# Beyond this distance the mark cannot matter to the player; skip drawing
# rather than tessellating rings for the elite's whole lifetime.
const DRAW_MAX_PLAYER_DIST := 1200.0
const REDRAW_INTERVAL := 1.0 / 30.0
# last_drawn_bits flag for the streak, outside the EliteModifiers bit range:
# the streak is motion, not the FAST mark that survives reduced_motion.
const DRAWN_STREAK := 1 << 8

# What the last draw pass put on the canvas: each modifier's bit when its
# mark drew (FAST for the chevrons), plus DRAWN_STREAK.
var last_drawn_bits: int = 0

var _enemy: EnemyActor = null
var _sprite: CanvasItem = null
var _ids: Array[StringName] = []
var _bits: int = 0
var _base_tint: Color = Color.WHITE
var _t: float = 0.0
var _redraw_accum: float = 0.0
var _reduced_motion: bool = false
var _drawn_static: bool = false
var _feed_flash: float = 0.0
var _released: bool = false


func setup(enemy: EnemyActor, ids: Array[StringName], base_tint: Color) -> void:
	_enemy = enemy
	_ids = ids.duplicate()
	_bits = 0
	for id in _ids:
		_bits |= EliteModifiers.bit_for(id)
	_base_tint = base_tint
	_sprite = enemy.get_node_or_null("Sprite2D") as CanvasItem if enemy != null else null


## VAMPIRIC just fed: brighten the ring for a beat so the feed is visible.
func note_feed() -> void:
	_feed_flash = 0.35
	if not _animated():
		queue_redraw()


## The enemy is dropping the mark. A queued free lands at the end of the
## frame; from here on no step writes the sprite's modulate, so the colour
## the enemy restores stays.
func release() -> void:
	_released = true
	set_process(false)


func _ready() -> void:
	# As child of the enemy: local position is fine, drawn under the sprite.
	position = Vector2.ZERO
	z_index = -1
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_reduced_motion = (
		SettingsManager != null
		and bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))
	)
	set_process(true)
	queue_redraw()


func is_animated() -> bool:
	return _animated()


func _animated() -> bool:
	# Only the pulse and the streak move; plate ring, hexagon, seam and
	# chevrons draw once.
	return not _reduced_motion and (_bits & (EliteModifiers.BIT_VAMPIRIC | EliteModifiers.BIT_FAST)) != 0


func _fast_needs_still_tell() -> bool:
	# FAST as the first modifier owns the body tint and, moving, the streak.
	# Under reduced_motion the streak never draws, and behind another
	# modifier's tint FAST has no colour of its own: the chevrons are the tell.
	return (_bits & EliteModifiers.BIT_FAST) != 0 and (_reduced_motion or _ids[0] != EliteModifiers.FAST)


func _process(dt: float) -> void:
	if _released:
		return
	if _enemy == null or not is_instance_valid(_enemy) or _enemy.dead:
		release()
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
		_drawn_static = false
	_t += dt
	if _feed_flash > 0.0:
		_feed_flash = maxf(_feed_flash - dt, 0.0)
	if _animated():
		_redraw_accum += dt
		if _redraw_accum >= REDRAW_INTERVAL:
			_redraw_accum = 0.0
			_pulse_tint()
			queue_redraw()
	elif not _drawn_static:
		_drawn_static = true
		queue_redraw()


func _pulse_tint() -> void:
	if _sprite == null or not is_instance_valid(_sprite) or (_bits & EliteModifiers.BIT_VAMPIRIC) == 0:
		return
	# From the body's tint toward a hot red and back; brightness pulses even
	# when the body is already red.
	var hot := EliteModifiers.tint(EliteModifiers.VAMPIRIC)
	var bright := Color(hot.r * 1.4, hot.g * 1.4, hot.b * 1.4, 1.0)
	var k := 0.5 + 0.5 * sin(_t * vampiric_pulse_hz * TAU)
	_sprite.modulate = _base_tint.lerp(bright, 0.25 + 0.75 * k)


func _draw() -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	# The mark inherits the body's scale; world-sized marks (the shield radius)
	# divide it back out, body-sized marks scale with the body on purpose.
	var world_scale := maxf(absf(global_scale.x), 0.01)
	last_drawn_bits = 0
	if (_bits & EliteModifiers.BIT_SHIELDED) != 0:
		_draw_shield_hexagon(EliteModifiers.SHIELD_RADIUS / world_scale)
		last_drawn_bits |= EliteModifiers.BIT_SHIELDED
	if (_bits & EliteModifiers.BIT_ARMOURED) != 0:
		_draw_plate_ring()
		last_drawn_bits |= EliteModifiers.BIT_ARMOURED
	if (_bits & EliteModifiers.BIT_VAMPIRIC) != 0:
		_draw_vampiric_ring()
		last_drawn_bits |= EliteModifiers.BIT_VAMPIRIC
	if (_bits & EliteModifiers.BIT_SPLITTING) != 0:
		_draw_seam()
		last_drawn_bits |= EliteModifiers.BIT_SPLITTING
	if _fast_needs_still_tell():
		_draw_fast_chevrons()
		last_drawn_bits |= EliteModifiers.BIT_FAST
	if (_bits & EliteModifiers.BIT_FAST) != 0 and not _reduced_motion:
		_draw_streak(world_scale)


func _draw_shield_hexagon(radius: float) -> void:
	var tint := EliteModifiers.tint(EliteModifiers.SHIELDED)
	var points := PackedVector2Array()
	for i in range(7):
		points.append(Vector2.RIGHT.rotated(TAU * float(i % 6) / 6.0 + PI / 6.0) * radius)
	draw_colored_polygon(points.slice(0, 6), Color(tint.r, tint.g, tint.b, 0.05))
	draw_polyline(points, Color(tint.r, tint.g, tint.b, 0.30), glow_width, true)
	draw_polyline(points, Color(tint.r, tint.g, tint.b, 0.85), line_width, true)


func _draw_plate_ring() -> void:
	var tint := EliteModifiers.tint(EliteModifiers.ARMOURED)
	var r := body_radius + 4.0
	var plate_len := TAU / float(maxi(plate_count, 1))
	for i in range(plate_count):
		var a0 := float(i) * plate_len
		var a1 := a0 + plate_len * (1.0 - plate_gap)
		draw_arc(Vector2.ZERO, r, a0, a1, 6, Color(tint.r, tint.g, tint.b, 0.35), glow_width, true)
		draw_arc(Vector2.ZERO, r, a0, a1, 6, Color(tint.r, tint.g, tint.b, 0.95), line_width * 2.0, true)


func _draw_vampiric_ring() -> void:
	var tint := EliteModifiers.tint(EliteModifiers.VAMPIRIC)
	var k := 0.5 if _reduced_motion else 0.5 + 0.5 * sin(_t * vampiric_pulse_hz * TAU)
	var alpha := lerpf(0.25, 0.75, k) + _feed_flash
	var r := body_radius - 4.0 + (0.0 if _reduced_motion else 3.0 * k)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(tint.r, tint.g, tint.b, minf(alpha * 0.5, 1.0)), glow_width, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(tint.r, tint.g, tint.b, minf(alpha, 1.0)), line_width, true)


func _draw_seam() -> void:
	# A jagged crack across the body: where it will come apart.
	var tint := EliteModifiers.tint(EliteModifiers.SPLITTING)
	var r := body_radius
	var seam := PackedVector2Array([
		Vector2(-r, -r * 0.35),
		Vector2(-r * 0.45, r * 0.05),
		Vector2(-r * 0.1, -r * 0.2),
		Vector2(r * 0.2, r * 0.3),
		Vector2(r * 0.55, 0.0),
		Vector2(r, r * 0.4),
	])
	draw_polyline(seam, Color(tint.r, tint.g, tint.b, 0.35), glow_width * 0.6, true)
	draw_polyline(seam, Color(tint.r, tint.g, tint.b, 0.95), line_width, true)


func _draw_fast_chevrons() -> void:
	var tint := EliteModifiers.tint(EliteModifiers.FAST)
	var y := body_radius + fast_chevron_offset
	var half := fast_chevron_size * 0.5
	var first_x := -fast_chevron_spacing * float(fast_chevron_count - 1) * 0.5
	for i in range(fast_chevron_count):
		var x := first_x + fast_chevron_spacing * float(i)
		var chevron := PackedVector2Array([
			Vector2(x - half, y - half),
			Vector2(x + half, y),
			Vector2(x - half, y + half),
		])
		draw_polyline(chevron, Color(tint.r, tint.g, tint.b, 0.35), glow_width * 0.6, true)
		draw_polyline(chevron, Color(tint.r, tint.g, tint.b, 0.95), line_width, true)


func _draw_streak(world_scale: float) -> void:
	var velocity := _enemy.velocity
	var speed := velocity.length()
	if speed < 20.0:
		return
	last_drawn_bits |= DRAWN_STREAK
	var tint := EliteModifiers.tint(EliteModifiers.FAST)
	var back := -(velocity / speed)
	var length := streak_length * clampf(speed / 300.0, 0.4, 1.6) / world_scale
	var side := back.orthogonal()
	for i in range(3):
		var offset := side * (float(i) - 1.0) * 7.0
		var fade := 1.0 - absf(float(i) - 1.0) * 0.35
		var from := offset + back * (body_radius * 0.6)
		var to := from + back * length * fade
		draw_line(from, to, Color(tint.r, tint.g, tint.b, 0.30 * fade), glow_width * 0.6, true)
		draw_line(from, to, Color(tint.r, tint.g, tint.b, 0.85 * fade), line_width, true)
