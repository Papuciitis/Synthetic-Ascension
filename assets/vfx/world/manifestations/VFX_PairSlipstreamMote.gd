extends Node2D
class_name VFX_PairSlipstreamMote

## One shard held out of the orbit and left standing where the player was, until
## it snaps back down the heading it was dropped along. Procedural and
## self-contained: Slipstream Foundry tells it a hold time, the radius it bites,
## the heading and a tint, and it owns its own death.
##
## Presentation only. The damage stays on the pair, which is also what does the
## shard accounting, so an unequip cannot leave an orphaned node still hurting
## things on the shared state's behalf.

@export var hold_time: float = 1.25
@export var radius: float = 34.0
@export var tint: Color = Color(0.72, 0.95, 1.0, 1.0)

## The last slice of the hold is the snap-back: the mote stretches along the
## heading and thins out instead of simply fading where it stands.
const SNAP_SHARE: float = 0.28
const SNAP_REACH: float = 96.0

var _heading: Vector2 = Vector2.RIGHT
var _t: float = 0.0
var _spin: float = 0.0
var _seed: float = 0.0


func setup(p_hold: float, p_radius: float, heading: Vector2, colour: Color) -> void:
	hold_time = maxf(0.05, p_hold)
	radius = maxf(6.0, p_radius)
	tint = colour
	if heading.length_squared() > 0.0001:
		_heading = heading.normalized()


func _ready() -> void:
	top_level = true
	z_as_relative = false
	# Under the orbit band the state paints at (4070), because this is a shard
	# the player has left behind, not one still flying with them.
	z_index = 4056
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# One seed per mote, so a trail of three does not read as the same stamp
	# printed three times.
	_seed = randf() * TAU
	_spin = randf_range(-2.6, 2.6)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t >= hold_time:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p: float = clampf(_t / maxf(hold_time, 0.001), 0.0, 1.0)
	var snap: float = clampf((p - (1.0 - SNAP_SHARE)) / SNAP_SHARE, 0.0, 1.0)
	var fade: float = 1.0 - snap * snap
	# Settles into place over the first few frames rather than appearing at full
	# size, so a mote reads as being SET DOWN.
	var settle: float = clampf(p / 0.12, 0.0, 1.0)
	var bite: float = radius * (0.55 + 0.45 * settle)

	# The ground it holds - the reach the pair actually damages, so the player
	# can read where standing is a bad idea.
	draw_arc(Vector2.ZERO, bite, 0.0, TAU, 30, Color(tint.r, tint.g, tint.b, 0.20 * fade), 1.6, true)
	draw_circle(Vector2.ZERO, bite * 0.42, Color(tint.r, tint.g, tint.b, 0.10 * fade))

	# The stranded shard itself, drawn as the state draws an orbiting one so the
	# trail and the halo are visibly the same object in two states.
	var angle: float = _seed + _spin * _t
	var facing := Vector2(cos(angle), sin(angle))
	var side := Vector2(-facing.y, facing.x)
	var stretch: float = 1.0 + 2.6 * snap
	var pull: Vector2 = _heading * (SNAP_REACH * snap * snap)
	var spark: float = 0.85 + 0.15 * sin(_t * 9.0 + _seed)

	draw_circle(pull, 8.0 * spark * fade, Color(tint.r, tint.g, tint.b, 0.36 * fade))
	draw_colored_polygon(PackedVector2Array([
		pull + facing * 7.5 * stretch,
		pull + side * 3.6,
		pull - facing * 7.5 * stretch,
		pull - side * 3.6,
	]), Color(1.0, 1.0, 1.0, 0.90 * fade))

	if snap <= 0.0:
		# A tether back toward the run, so a held shard reads as owed rather
		# than as dropped litter.
		var tail: Vector2 = -_heading * (bite * 0.9)
		draw_line(tail * 0.35, tail, Color(tint.r, tint.g, tint.b, 0.28 * fade), 1.6, true)
		return

	# Snapping back: a streak along the heading, drawn from where it stood.
	draw_line(Vector2.ZERO, pull, Color(tint.r, tint.g, tint.b, 0.55 * (1.0 - snap)), 2.4, true)
