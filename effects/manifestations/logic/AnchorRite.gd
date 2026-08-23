extends ManifestationEffect

## Anchor Rite - the deliberate counterweight to the Momentum family.
##
## Standing still builds Stability; at full Stability every attack lands far
## harder. Firing does NOT spend it: standing still IS the cost, so a planted
## player keeps the payoff for as long as they refuse to move. State already
## drains Stability while moving, which is what makes wearing this alongside
## Pilgrim's Momentum a real decision instead of a stacking bonus.

const FILL_SECONDS: float = 1.4
const FULL_BONUS: float = 0.85

## The other half of the rite: a planted shot carries through bodies and
## reaches further. Only ranged shots have a pierce concept, so melee and
## magic keep the damage payoff alone.
const FULL_PIERCE: int = 2
const FULL_RANGE_BONUS: float = 0.35

const RING_RADIUS: float = 34.0
const SPIN_SPEED: float = 1.35
const RE_ANNOUNCE_BELOW: float = 0.60

var _last_still: float = 0.0
var _drawn: float = -1.0
var _spin: float = 0.0
var _was_full: bool = false


func _on_manifestation_ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4058

	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	if state != null:
		# Seed from the running clock: equipping this while already parked must
		# not hand over a full rite for stillness the item was not present for.
		_last_still = state.still_time
	if player != null and is_instance_valid(player):
		global_position = player.global_position

	set_process(true)


func _process(delta: float) -> void:
	if state == null or not is_instance_valid(state):
		return

	if player != null and is_instance_valid(player):
		global_position = player.global_position

	_build()

	var s: float = state.stability
	var full: bool = s >= 0.999
	# Hysteresis on the callout only: a one-frame twitch really does cost the
	# bonus, but it must not re-announce the rite twenty times a second.
	if full and not _was_full:
		popup("ANCHORED", Color(0.62, 0.84, 1.0, 1.0), 1.2)
		_was_full = true
	elif s < RE_ANNOUNCE_BELOW:
		_was_full = false

	# Idle cost matters here - this node outlives every enemy on screen. Only
	# the locked state animates; while building we repaint on real change.
	if full:
		_spin = fposmod(_spin + SPIN_SPEED * delta, TAU)
		_drawn = s
		queue_redraw()
	elif absf(s - _drawn) > 0.004 or (s <= 0.0 and _drawn > 0.0):
		_drawn = s
		queue_redraw()


func _build() -> void:
	var still: float = state.still_time
	# State zeroes still_time the instant the player moves; rebase rather than
	# crediting the same second of stillness twice. Crediting the DELTA (not the
	# absolute progress) means a one-frame twitch costs only the decay it caused,
	# not the whole rite.
	if still < _last_still:
		_last_still = 0.0
	if still <= _last_still:
		return
	var required: float = maxf(0.05, FILL_SECONDS * threshold_scale())
	state.add_stability((still - _last_still) / required)
	_last_still = still


## Reported through the one-shot channel, but deliberately NOT one-shot: the
## bonus is not cleared on firing. Standing still is what pays for it.
func consume_attack_bonus() -> float:
	if state == null or not is_instance_valid(state):
		return 1.0
	if state.stability < 0.999:
		return 1.0
	return 1.0 + FULL_BONUS * potency()


func _is_planted() -> bool:
	return state != null and is_instance_valid(state) and state.stability >= 0.999


func pierce_at_full() -> int:
	return FULL_PIERCE + int(floor((potency() - 1.0) / 0.30))


func apply_to_hit_profile(profile: HitProfileAdapter, style_id: StringName) -> void:
	if profile == null or style_id != &"ranged" or not _is_planted():
		return
	# maxi, not assignment: another effect may already have granted pierce and
	# the rite should never take it away.
	profile.pierce = maxi(profile.pierce, pierce_at_full())
	profile.max_range *= 1.0 + FULL_RANGE_BONUS


func apply_to_ranged_bullet(bullet: Node, _style_id: StringName) -> void:
	# Compatibility path only. The node bullet has no pierce concept, so a
	# planted shot gets the reach half and nothing else.
	if bullet == null or not _is_planted():
		return
	var reach: Variant = bullet.get("max_range")
	if reach is float or reach is int:
		bullet.set("max_range", float(reach) * (1.0 + FULL_RANGE_BONUS))


func describe() -> String:
	return "Stand still for %.2fs to reach full Stability, then your attacks deal %d%% damage and ranged shots carry through %d more enemies at %d%% range. Firing never spends it; moving drains it." % [
		FILL_SECONDS * threshold_scale(),
		int(round((1.0 + FULL_BONUS * potency()) * 100.0)),
		pierce_at_full(),
		int(round((1.0 + FULL_RANGE_BONUS) * 100.0)),
	]


func _draw() -> void:
	var s: float = clampf(_drawn, 0.0, 1.0)
	if s <= 0.001:
		return

	# Deliberately NOT noun_colour(). Anchor Rite claims `momentum`, but it
	# paints Stability - the OPPOSITE pole of that noun - and painting it
	# momentum orange would make standing still look identical to running.
	# The opposition is the read; the HUD counter and the tooltip say which
	# noun it belongs to.
	var cold := Color(0.42, 0.72, 1.0, 1.0)
	var lock := Color(0.74, 0.90, 1.0, 1.0)

	# The ring closes as the rite takes hold, so "how planted am I" is readable
	# in the world without looking at the HUD meter.
	draw_arc(
		Vector2.ZERO,
		RING_RADIUS,
		-PI * 0.5,
		-PI * 0.5 + TAU * s,
		48,
		Color(cold.r, cold.g, cold.b, 0.30 + 0.45 * s),
		2.6,
		true
	)

	# Four stakes driven into the ground; they reach full length exactly as the
	# rite completes.
	var reach: float = 8.0 + 12.0 * s
	var stake := Color(cold.r, cold.g, cold.b, 0.25 + 0.50 * s)
	for i in range(4):
		var ang: float = PI * 0.25 + PI * 0.5 * float(i)
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(dir * (RING_RADIUS - 4.0), dir * (RING_RADIUS + reach), stake, 2.2, true)

	if s < 0.999:
		return

	# Locked is a different picture, not a brighter one: a second ring, a core,
	# and chevrons turning inward on the spot the player has claimed.
	var pulse: float = 0.80 + 0.20 * sin(_spin * 3.0)
	var bright := Color(lock.r, lock.g, lock.b, 0.55 * pulse)
	draw_arc(Vector2.ZERO, RING_RADIUS + 7.0, 0.0, TAU, 56, bright, 3.4, true)
	draw_arc(Vector2.ZERO, RING_RADIUS * 0.42, 0.0, TAU, 32, Color(lock.r, lock.g, lock.b, 0.42 * pulse), 2.0, true)

	var arrow := Color(lock.r, lock.g, lock.b, 0.75 * pulse)
	for i in range(6):
		var a: float = _spin + TAU * float(i) / 6.0
		var facing := Vector2(cos(a), sin(a))
		var side := Vector2(-facing.y, facing.x)
		var tip: Vector2 = facing * (RING_RADIUS + 15.0)
		var tail: Vector2 = facing * (RING_RADIUS + 25.0)
		draw_line(tip, tail + side * 7.0, arrow, 2.4, true)
		draw_line(tip, tail - side * 7.0, arrow, 2.4, true)
