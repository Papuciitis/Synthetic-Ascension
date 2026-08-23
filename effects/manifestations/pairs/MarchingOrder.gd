extends ManifestationPairEffect

## Marching Order - momentum x cadence.
##
## Walking IS attacking, for rhythm purposes. Every stride of unbroken travel
## writes one beat into the SHARED counter with state.note_attack(), the same
## call an echo makes, so a player who keeps moving carries Third Litany's
## litany and the Tithe Furnace's eighth-attack cycle forward without pulling
## the trigger once.
##
## The forfeit is the other half, and it is what stops this being a free tick.
## Stopping does not cash the part-stride in early - it throws it away - because
## a pair built out of momentum and cadence must not reward the one thing both
## of its nouns exist to punish.
##
## Distance is the ONLY thing this turns into beats. It deliberately implements
## no on_attack: a real shot already advances the shared counter through its own
## path, and a beat added here would count that shot twice.

# The world is authored on a 32 px grid (VisionRig.cell_size_px), so a design
# "metre" is 32 px of travel.
const PIXELS_PER_METRE: float = 32.0
const STRIDE_METRES: float = 6.0
const STRIDE_DISTANCE: float = STRIDE_METRES * PIXELS_PER_METRE

## The state zeroes its own unbroken-run odometer at 0.18s of stillness, so the
## forfeit lands just after it rather than inventing a second, slightly
## different idea of "stopped" for the player to learn.
const FORFEIT_AFTER: float = 0.20

## A teleport or a long frame can cross several strides at once. Paying them all
## is correct, but bounded - a single hitch must not dump twenty beats into a
## counter every cadence rule is reading.
const MAX_BEATS_PER_FRAME: int = 4

const GAUGE_ORIGIN := Vector2(0.0, 46.0)
const GAUGE_RADIUS: float = 7.0
const BEAT_FLASH: float = 0.26
const FORFEIT_FLASH: float = 0.30

var _last_distance: float = 0.0
var _progress: float = 0.0
var _beat_flash: float = 0.0
var _forfeit_flash: float = 0.0
var _drawn_fraction: float = -1.0
var _flash_painted: bool = false


func _on_manifestation_ready() -> void:
	# World-space draw: the player rotates to face its movement vector and a
	# stride gauge that spun with it would be unreadable.
	top_level = true
	z_as_relative = false
	z_index = 4062
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if state != null and is_instance_valid(state):
		# Seed from the running odometer: a pair coming online mid-sprint must
		# not pay out for metres it was not live through.
		_last_distance = state.distance_since_stop
	if player != null and is_instance_valid(player):
		global_position = player.global_position
	set_process(true)


func stride_distance() -> float:
	return maxf(1.0, STRIDE_DISTANCE * threshold_scale())


func _process(delta: float) -> void:
	_beat_flash = maxf(0.0, _beat_flash - delta)
	_forfeit_flash = maxf(0.0, _forfeit_flash - delta)
	if state == null or not is_instance_valid(state):
		return
	global_position = player_position()
	_advance()
	_repaint_if_changed()


func _advance() -> void:
	var travelled: float = state.distance_since_stop
	# The state zeroes the odometer once the player has actually stopped;
	# rebase rather than reading that drop as a negative stride.
	if travelled < _last_distance:
		_last_distance = travelled

	if state.still_time >= FORFEIT_AFTER:
		if _progress > 0.0:
			_progress = 0.0
			_forfeit_flash = FORFEIT_FLASH
		return

	if not state.is_moving or travelled <= _last_distance:
		return
	_progress += travelled - _last_distance
	_last_distance = travelled

	var stride: float = stride_distance()
	var beats: int = 0
	while _progress >= stride and beats < MAX_BEATS_PER_FRAME:
		_progress -= stride
		beats += 1
		# The shared beat, not a private tally. This is the whole rule: every
		# cadence rule in the loadout reads the same counter, so a walked beat
		# advances all of them at once.
		state.note_attack()
	if beats > 0:
		_beat_flash = BEAT_FLASH
		# Whatever the bound refused is dropped rather than banked, so a hitch
		# cannot leave the gauge sitting full for the next several strides.
		_progress = minf(_progress, stride)


func _repaint_if_changed() -> void:
	# This node lives for the whole run alongside hundreds of enemies, so it
	# repaints only when the gauge actually moved or a flash is animating.
	# `_flash_painted` buys the one extra repaint that wipes the last flash.
	var fraction: float = clampf(_progress / stride_distance(), 0.0, 1.0)
	var animating: bool = _beat_flash > 0.0 or _forfeit_flash > 0.0
	if animating or _flash_painted or absf(fraction - _drawn_fraction) > 0.01:
		_flash_painted = animating
		_drawn_fraction = fraction
		queue_redraw()


func describe() -> String:
	return (
		"Every %.1f m of unbroken travel counts as an attack, advancing every rhythm you carry without firing. Stopping forfeits the stride you had banked instead of cashing it in early."
		% [stride_distance() / PIXELS_PER_METRE]
	)


func _draw() -> void:
	# The runner binds the player one frame after this node enters the tree.
	if player == null or not is_instance_valid(player):
		return
	var cadence: Color = noun_colour(&"cadence")
	var momentum: Color = noun_colour(&"momentum")
	var fraction: float = clampf(_drawn_fraction, 0.0, 1.0)

	draw_arc(GAUGE_ORIGIN, GAUGE_RADIUS, 0.0, TAU, 20, Color(cadence.r, cadence.g, cadence.b, 0.20), 1.4, true)
	# The fill is MOMENTUM coloured and the payout flashes CADENCE: the gauge
	# says out loud which noun is being spent and which one is being paid.
	if fraction > 0.01:
		draw_arc(
			GAUGE_ORIGIN,
			GAUGE_RADIUS,
			-PI * 0.5,
			-PI * 0.5 + TAU * fraction,
			22,
			Color(momentum.r, momentum.g, momentum.b, 0.35 + 0.50 * fraction),
			2.0,
			true
		)

	if _beat_flash > 0.0:
		var t: float = _beat_flash / BEAT_FLASH
		draw_arc(
			GAUGE_ORIGIN,
			GAUGE_RADIUS + 10.0 * (1.0 - t),
			0.0,
			TAU,
			22,
			Color(cadence.r, cadence.g, cadence.b, 0.80 * t),
			2.0,
			true
		)

	if _forfeit_flash > 0.0:
		# Struck through, not detonated: a forfeit must never look like a payout.
		var f: float = _forfeit_flash / FORFEIT_FLASH
		var arm := Vector2(GAUGE_RADIUS + 4.0, 0.0)
		draw_line(GAUGE_ORIGIN - arm, GAUGE_ORIGIN + arm, Color(1.0, 0.30, 0.26, 0.85 * f), 1.8, true)
