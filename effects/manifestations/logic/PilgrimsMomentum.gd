extends ManifestationEffect

## Pilgrim's Momentum - travelling without stopping banks Momentum; a full bank
## makes the next attack fire twice.
##
## This is the PRODUCER for the shared `momentum` resource. Sunder Wake and
## Impact Scripture spend the same pool without either side knowing the other
## exists; they only agree on the noun. Rolling this plus one of those is how a
## non-set build accidentally becomes an engine.

# The world is authored on a 32 px grid (VisionRig.cell_size_px), so a design
# "metre" is 32 px of travel.
const PIXELS_PER_METRE: float = 32.0
const FILL_METRES: float = 15.0
const FILL_DISTANCE: float = FILL_METRES * PIXELS_PER_METRE

## The echo is held back a beat so a full bank reads as a double tap instead of
## one fat shot landing on the same frame as the original.
const ECHO_DELAY: float = 0.09
const FLARE_TIME: float = 0.30

const RING_RADIUS: float = 26.0

var _last_distance: float = 0.0
var _echo_delay_left: float = 0.0
var _echo_style: StringName = &""
var _echo_target: Vector2 = Vector2.ZERO
var _echo_damage: float = 1.0
var _flare: float = 0.0
var _heading: Vector2 = Vector2.RIGHT
var _drawn_momentum: float = -1.0
var _flare_painted: bool = false


func _on_manifestation_ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4060

	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	if state != null:
		# Seed from the running odometer: equipping mid-sprint must not pay out
		# for metres this item was not carried through.
		_last_distance = state.distance_since_stop
	if player != null and is_instance_valid(player):
		global_position = player.global_position

	set_process(true)


func _process(delta: float) -> void:
	if state == null or not is_instance_valid(state):
		return

	_follow_player()
	_bank_travel()
	_tick_echo(delta)

	if _flare > 0.0:
		_flare = maxf(0.0, _flare - delta)

	# This node lives for the whole run alongside hundreds of enemies, so it only
	# repaints when the meter actually moved or the release flare is animating.
	# `_flare_painted` buys the one extra repaint that wipes the last flare frame.
	var m: float = state.momentum
	var animating: bool = _flare > 0.0
	if animating or _flare_painted or absf(m - _drawn_momentum) > 0.004 or (m <= 0.0 and _drawn_momentum > 0.0):
		_flare_painted = animating
		_drawn_momentum = m
		queue_redraw()


# ---------------------------------------------------------------------------
# Banking
# ---------------------------------------------------------------------------

func _bank_travel() -> void:
	var travelled: float = state.distance_since_stop
	# State zeroes distance_since_stop once the player has actually stopped;
	# rebase instead of paying for the same metres a second time.
	if travelled < _last_distance:
		_last_distance = travelled
	if not state.is_moving or travelled <= _last_distance:
		return
	state.add_momentum((travelled - _last_distance) / fill_distance())
	_last_distance = travelled


func fill_distance() -> float:
	return maxf(1.0, FILL_DISTANCE * threshold_scale())


## Pixels of unbroken travel that actually fill the bar. The noun fills itself
## from travel for ANY claimer (ManifestationState.MOMENTUM_BASE_FILL_DISTANCE)
## and this rule's own fill runs on top of it, so the bar fills at the combined
## rate - two taps into one bucket, 1 / (1/own + 1/passive) - never at
## FILL_DISTANCE alone. Quoting FILL_DISTANCE read 15 m against a bar that
## really filled in about 9.
func combined_fill_distance() -> float:
	return 1.0 / (1.0 / fill_distance() + 1.0 / ManifestationState.MOMENTUM_BASE_FILL_DISTANCE)


func on_attack(
	style_id: StringName,
	_origin: Vector2,
	target: Vector2,
	_power_mul: float,
	_haste_mul: float
) -> void:
	if state == null or not is_instance_valid(state):
		return
	# A consumer rolled on another item may already have drained the pool this
	# frame; that is the intended friction, not a bug to work around.
	if state.momentum < 0.999:
		return
	state.consume_momentum()
	_echo_style = style_id
	_echo_target = target
	_echo_damage = potency()
	_echo_delay_left = ECHO_DELAY
	_flare = FLARE_TIME
	popup("TWICE", Color(1.0, 0.72, 0.28, 1.0), 1.25)


func _tick_echo(delta: float) -> void:
	if _echo_delay_left <= 0.0:
		return
	_echo_delay_left -= delta
	if _echo_delay_left > 0.0:
		return
	repeat_player_attack(_echo_style, _echo_target, _echo_damage)


# ---------------------------------------------------------------------------
# Presentation
# ---------------------------------------------------------------------------

func _follow_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	var here: Vector2 = player.global_position
	var step: Vector2 = here - global_position
	if step.length_squared() > 1.0:
		_heading = step.normalized()
	global_position = here


func describe() -> String:
	var metres: float = combined_fill_distance() / PIXELS_PER_METRE
	var own_metres: float = fill_distance() / PIXELS_PER_METRE
	var passive_metres: float = ManifestationState.MOMENTUM_BASE_FILL_DISTANCE / PIXELS_PER_METRE
	return (
		"Travel %.1f m without stopping to fill Momentum - this rule's own %.1f m fill running alongside the %.0f m travel fill any Momentum rule gets. At full Momentum your next attack fires a second time at %d%% damage, spending all of it."
		% [metres, own_metres, passive_metres, int(round(potency() * 100.0))]
	)


func _draw() -> void:
	var m: float = clampf(_drawn_momentum, 0.0, 1.0)
	if m <= 0.001 and _flare <= 0.0:
		return

	# Identity hue from the noun registry; the alphas and the flare geometry
	# stay authored. See ManifestationEffect.noun_colour().
	var warm := noun_colour()
	var full: bool = m >= 0.999

	if m > 0.001:
		draw_arc(
			Vector2.ZERO,
			RING_RADIUS,
			-PI * 0.5,
			-PI * 0.5 + TAU * m,
			40,
			Color(warm.r, warm.g, warm.b, 0.28 + 0.42 * m),
			3.0,
			true
		)

	# Chevrons streaming off the back of the run. They only show up once there
	# are real metres banked, so a shuffling player is not permanently on fire.
	if m > 0.15:
		var back: Vector2 = -_heading
		var side := Vector2(-back.y, back.x)
		var trail := Color(warm.r, warm.g, warm.b, (0.45 if full else 0.28) * m)
		for i in range(3):
			var t: float = float(i + 1)
			var tip: Vector2 = back * (16.0 + 13.0 * t)
			var arm: Vector2 = tip + back * 8.0
			draw_line(tip, arm + side * 8.0, trail, 2.4, true)
			draw_line(tip, arm - side * 8.0, trail, 2.4, true)

	if _flare > 0.0:
		var x: float = 1.0 - (_flare / FLARE_TIME)
		var fade: float = (1.0 - x) * (1.0 - x)
		draw_arc(
			Vector2.ZERO,
			RING_RADIUS * 0.85 + 48.0 * x,
			0.0,
			TAU,
			44,
			Color(warm.r, warm.g, warm.b, 0.85 * fade),
			3.2,
			true
		)
