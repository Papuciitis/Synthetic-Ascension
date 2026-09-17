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
# Seconds the VAMPIRIC ring stays brightened after a feed.
@export var feed_flash_seconds: float = 0.35
# The plate ring sits this far outside the body radius.
@export var plate_ring_offset: float = 4.0
# The VAMPIRIC ring sits this far inside the body radius and swells by
# vampiric_ring_pulse_px at the top of the pulse.
@export var vampiric_ring_inset: float = 4.0
@export var vampiric_ring_pulse_px: float = 3.0
# The streak draws from streak_min_speed and reaches full length at
# streak_full_speed; streak_lines lines, streak_spacing px apart.
@export var streak_min_speed: float = 20.0
@export var streak_full_speed: float = 300.0
@export var streak_lines: int = 3
@export var streak_spacing: float = 7.0

# Beyond this distance the mark cannot matter to the player; skip drawing
# rather than tessellating rings for the elite's whole lifetime.
const DRAW_MAX_PLAYER_DIST := 1200.0
const REDRAW_INTERVAL := 1.0 / 30.0
# Line alphas: plate, seam and chevrons are solid marks; hexagon and streak
# sit lighter; the hexagon's fill is a wash.
const SOLID_LINE_ALPHA := 0.95
const SOLID_GLOW_ALPHA := 0.35
const LINE_ALPHA := 0.85
const GLOW_ALPHA := 0.30
const SHIELD_FILL_ALPHA := 0.05
# Seam, chevrons and streak carry a narrower glow than the rings.
const THIN_GLOW_WIDTH_MULT := 0.6
# The plate ring's line is this many times line_width.
const PLATE_LINE_WIDTH_MULT := 2.0
# Arc tessellation: per plate, and for the full VAMPIRIC ring.
const PLATE_ARC_SEGMENTS := 6
const RING_SEGMENTS := 24
# VAMPIRIC pulse on the sprite: the hot red scaled by PULSE_BRIGHTNESS, mixed
# in between TINT_MIX_MIN and TINT_MIX_MIN + TINT_MIX_RANGE.
const VAMPIRIC_PULSE_BRIGHTNESS := 1.4
const VAMPIRIC_TINT_MIX_MIN := 0.25
const VAMPIRIC_TINT_MIX_RANGE := 0.75
# VAMPIRIC ring alpha runs RING_ALPHA_MIN..MAX over the pulse, the glow at
# GLOW_ALPHA_MULT of it; under reduced_motion the pulse holds at STILL_PHASE.
const VAMPIRIC_RING_ALPHA_MIN := 0.25
const VAMPIRIC_RING_ALPHA_MAX := 0.75
const VAMPIRIC_GLOW_ALPHA_MULT := 0.5
const VAMPIRIC_STILL_PHASE := 0.5
# Streak length is streak_length x (speed / streak_full_speed) clamped to
# these; it starts START_FRACTION of the body radius behind centre and the
# outer lines fade by SIDE_FADE per line from the middle.
const STREAK_LENGTH_MIN_MULT := 0.4
const STREAK_LENGTH_MAX_MULT := 1.6
const STREAK_START_FRACTION := 0.6
const STREAK_SIDE_FADE := 0.35
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
	_feed_flash = feed_flash_seconds
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
	var bright := Color(
		hot.r * VAMPIRIC_PULSE_BRIGHTNESS,
		hot.g * VAMPIRIC_PULSE_BRIGHTNESS,
		hot.b * VAMPIRIC_PULSE_BRIGHTNESS,
		1.0,
	)
	var k := 0.5 + 0.5 * sin(_t * vampiric_pulse_hz * TAU)
	_sprite.modulate = _base_tint.lerp(bright, VAMPIRIC_TINT_MIX_MIN + VAMPIRIC_TINT_MIX_RANGE * k)


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
	draw_colored_polygon(points.slice(0, 6), Color(tint.r, tint.g, tint.b, SHIELD_FILL_ALPHA))
	draw_polyline(points, Color(tint.r, tint.g, tint.b, GLOW_ALPHA), glow_width, true)
	draw_polyline(points, Color(tint.r, tint.g, tint.b, LINE_ALPHA), line_width, true)


func _draw_plate_ring() -> void:
	var tint := EliteModifiers.tint(EliteModifiers.ARMOURED)
	var r := body_radius + plate_ring_offset
	var plate_len := TAU / float(maxi(plate_count, 1))
	for i in range(plate_count):
		var a0 := float(i) * plate_len
		var a1 := a0 + plate_len * (1.0 - plate_gap)
		draw_arc(Vector2.ZERO, r, a0, a1, PLATE_ARC_SEGMENTS, Color(tint.r, tint.g, tint.b, SOLID_GLOW_ALPHA), glow_width, true)
		draw_arc(Vector2.ZERO, r, a0, a1, PLATE_ARC_SEGMENTS, Color(tint.r, tint.g, tint.b, SOLID_LINE_ALPHA), line_width * PLATE_LINE_WIDTH_MULT, true)


func _draw_vampiric_ring() -> void:
	var tint := EliteModifiers.tint(EliteModifiers.VAMPIRIC)
	var k := VAMPIRIC_STILL_PHASE if _reduced_motion else 0.5 + 0.5 * sin(_t * vampiric_pulse_hz * TAU)
	var alpha := lerpf(VAMPIRIC_RING_ALPHA_MIN, VAMPIRIC_RING_ALPHA_MAX, k) + _feed_flash
	var r := body_radius - vampiric_ring_inset + (0.0 if _reduced_motion else vampiric_ring_pulse_px * k)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, RING_SEGMENTS, Color(tint.r, tint.g, tint.b, minf(alpha * VAMPIRIC_GLOW_ALPHA_MULT, 1.0)), glow_width, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, RING_SEGMENTS, Color(tint.r, tint.g, tint.b, minf(alpha, 1.0)), line_width, true)


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
	draw_polyline(seam, Color(tint.r, tint.g, tint.b, SOLID_GLOW_ALPHA), glow_width * THIN_GLOW_WIDTH_MULT, true)
	draw_polyline(seam, Color(tint.r, tint.g, tint.b, SOLID_LINE_ALPHA), line_width, true)


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
		draw_polyline(chevron, Color(tint.r, tint.g, tint.b, SOLID_GLOW_ALPHA), glow_width * THIN_GLOW_WIDTH_MULT, true)
		draw_polyline(chevron, Color(tint.r, tint.g, tint.b, SOLID_LINE_ALPHA), line_width, true)


func _draw_streak(world_scale: float) -> void:
	var velocity := _enemy.velocity
	var speed := velocity.length()
	if speed < streak_min_speed:
		return
	last_drawn_bits |= DRAWN_STREAK
	var tint := EliteModifiers.tint(EliteModifiers.FAST)
	var back := -(velocity / speed)
	var length := streak_length * clampf(speed / streak_full_speed, STREAK_LENGTH_MIN_MULT, STREAK_LENGTH_MAX_MULT) / world_scale
	var side := back.orthogonal()
	var middle := float(streak_lines - 1) * 0.5
	for i in range(streak_lines):
		var lines_from_middle := float(i) - middle
		var offset := side * lines_from_middle * streak_spacing
		var fade := 1.0 - absf(lines_from_middle) * STREAK_SIDE_FADE
		var from := offset + back * (body_radius * STREAK_START_FRACTION)
		var to := from + back * length * fade
		draw_line(from, to, Color(tint.r, tint.g, tint.b, GLOW_ALPHA * fade), glow_width * THIN_GLOW_WIDTH_MULT, true)
		draw_line(from, to, Color(tint.r, tint.g, tint.b, LINE_ALPHA * fade), line_width, true)
