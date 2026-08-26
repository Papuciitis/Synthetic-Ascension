extends ManifestationEffect

## Stored Violence - charge.
##
## Not attacking is the resource. The charge climbs while the trigger is idle
## and the next attack spends all of it, so the intended pattern is
## dash - dash - dash - one enormous hit rather than a continuous stream.
##
## Ordering: `consume_attack_bonus()` runs before the attack spawns, `on_attack`
## after it. The charge is therefore read in consume and cleared in on_attack -
## the two always come in that order for a shot that actually fires.

const CHARGE_SECONDS: float = 3.5
const PAYOUT_PER_POTENCY: float = 2.2
## Below this the release is not worth announcing; it would spam the battle text
## on every ordinary shot.
const ANNOUNCE_AT: float = 0.55

const AURA_RADIUS: float = 26.0

## Charge is DERIVED from the shared cadence clock rather than kept privately.
## Third Litany reads the same clock for the opposite purpose - it wants you to
## wait a beat, this wants you to wait far longer - so the two rules are two
## readings of one noun instead of two coincidentally similar timers.
var _charge: float = 0.0
var _release_flash: float = 0.0
var _released_at: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	# Drawn in world space: the player rotates to face its movement and a
	# charge aura that rotated with it would read as spinning debris.
	top_level = true
	z_as_relative = false
	z_index = 4062
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	_charge = clampf(since_attack() / charge_seconds(), 0.0, 1.0)
	_release_flash = maxf(0.0, _release_flash - delta)
	global_position = player_position()
	pulse_redraw()


func since_attack() -> float:
	if state == null or not is_instance_valid(state):
		return 0.0
	return state.time_since_attack


func charge_seconds() -> float:
	return maxf(0.25, CHARGE_SECONDS * threshold_scale())


func full_multiplier() -> float:
	return 1.0 + PAYOUT_PER_POTENCY * potency()


func consume_attack_bonus() -> float:
	# Linear payout on purpose: a curve would make the meter lie about what the
	# next shot is worth, and the meter is the whole read.
	var bonus := PAYOUT_PER_POTENCY * potency() * _charge
	if _charge >= ANNOUNCE_AT:
		_released_at = _charge
		_release_flash = 0.40
		popup("VIOLENCE x%.1f" % (1.0 + bonus), Color(1.0, 0.42, 0.30, 1.0), 1.10 + 0.35 * _charge)
	return 1.0 + bonus


func on_attack(
	_style_id: StringName,
	_origin: Vector2,
	_target: Vector2,
	_power_mul: float,
	_haste_mul: float
) -> void:
	_charge = 0.0


func describe() -> String:
	return (
		"Holding fire stores Violence over %.1fs. Your next attack spends all of it - a full release hits for x%.2f, a partial one pays out in proportion."
		% [charge_seconds(), full_multiplier()]
	)


func _draw() -> void:
	# The runner binds the player one frame after this node enters the tree.
	if player == null or not is_instance_valid(player):
		return
	if _release_flash > 0.0:
		var t := _release_flash / 0.40
		var burst := AURA_RADIUS + (52.0 + 40.0 * _released_at) * (1.0 - t)
		draw_arc(Vector2.ZERO, burst, 0.0, TAU, 26, Color(1.0, 0.40, 0.22, 0.55 * t), 3.0, true)

	if _charge <= 0.02:
		return

	var full := _charge >= 0.999
	var pulse := 1.0 if not full else (0.92 + 0.08 * sin(_t * 9.0))
	var radius := AURA_RADIUS + 16.0 * _charge * pulse
	# Identity hue from the noun registry. It used to be the same orange as
	# Pilgrim's Momentum, which made two rules about opposite things look
	# identical on the same player. Charge still brightens it - toward white
	# rather than up one channel, so the ramp works for any hue.
	var core := noun_colour().lerp(Color.WHITE, 0.35 * _charge)
	core.a = 0.20 + 0.40 * _charge
	draw_circle(Vector2.ZERO, radius, Color(core.r, core.g, core.b, core.a * 0.30))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 26, core, 1.4 + 2.2 * _charge, true)

	# Spokes converging inward: the count is the read, so the meter is legible
	# at a glance without a number.
	var spokes := 3 + int(round(_charge * 5.0))
	var spin := _t * (0.7 + 2.2 * _charge)
	for i in range(spokes):
		var angle := spin + TAU * float(i) / float(spokes)
		var dir := Vector2(cos(angle), sin(angle))
		var outer := radius + 9.0 * _charge
		draw_line(dir * (outer - 7.0 * _charge - 3.0), dir * outer, Color(1.0, 0.72, 0.38, 0.35 + 0.55 * _charge), 1.8, true)

	if full:
		draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 30, Color(1.0, 0.88, 0.55, 0.55 * pulse), 1.6, true)
