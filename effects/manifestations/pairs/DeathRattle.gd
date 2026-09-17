extends ManifestationPairEffect

## Death Rattle - cadence x ward.
##
## A mutator: it makes the layer's one authored failure state purchasable. The
## cadence noun is built on patience - the beat only pays if you let it resolve
## - and the exact moment a player stops being able to afford patience is the
## moment something is killing them. This does not delete that failure. It puts
## a price on it, payable only in the currency they have least of.
##
## Why it is written against the shared CLOCK and not against Third Litany.
##
## "Breaking your rhythm" is not a Third Litany concept. It is what the cadence
## noun means by a short `time_since_attack`: every cadence rule reads that one
## number and decides for itself what a short one costs it. A pair may not reach
## into a rule's private cycle - the loadout that lit cadence need not contain
## Third Litany at all - so the honest lever is the shared clock itself. While
## wounded, the rattle holds that clock open across the empowered beat, and
## every rule reading it sees a beat that resolved.
##
## Ordering forced the shape of it. consume_attack_bonus() is polled in
## _all_cache order and pairs are appended LAST, so by the time this pair would
## be asked, every rule has already read the clock and decided. The hold
## therefore has to be placed in on_attack for the NEXT shot, one beat ahead of
## the shot it protects. That in turn is why the cost is charged LAZILY: placing
## the hold is free, and it is only paid for once the player actually panic-
## fires into it. A hold the player never used changed nothing and costs
## nothing.

## The shared vocabulary this pair needs and does not have.
##
## ManifestationState owns "wounded" (WOUND_*) and "answered once"
## (RETALIATION_COOLDOWN) as shared constants precisely so two rules cannot
## disagree about a word. It does NOT own "the beat resolved": Third Litany
## picked 0.30s, Fever Litany 0.42s, Stored Violence 3.5s, each privately. A
## pair that has to speak about breaking a rhythm at the shared level therefore
## has to name its own threshold, and these two are chosen to sit in the one
## band where every current reading of the clock stays true:
##
##   RESOLVE_WINDOW  what counts as firing too soon. Third Litany's window is
##                   0.30s eased by rarity, so 0.30 is the widest any cadence
##                   rule currently calls a break - charge no earlier than that
##                   and the rattle can never bill for a beat nobody forfeited.
##   HELD_SECONDS    what the held clock reads. At or above the resolve window
##                   (the beat counts as resolved) and below Fever Litany's
##                   0.42s chain window (a Fever chain built by the same panic
##                   fire is not broken by the hold).
const RESOLVE_WINDOW: float = ManifestationState.CADENCE_RESOLVE_WINDOW
## Sits in the one band where every cadence reading stays true: at or above the
## shared resolve window (so the beat reads as held) and below the shared chain
## window (so a held beat is still distinguishable from an unbroken chain).
## Both bounds are owned by the noun now, so this cannot silently drift out of
## the band when either is retuned.
const HELD_SECONDS: float = (
	ManifestationState.CADENCE_RESOLVE_WINDOW
	+ (ManifestationState.CADENCE_CHAIN_WINDOW - ManifestationState.CADENCE_RESOLVE_WINDOW) * 0.5
)

## The pair layer's cycle, matching Loom and Tithe Rhythm. The rattle holds the
## clock across the EMPOWERED beat only: holding it on every attack would bill
## the player for beats no rule was going to forfeit and would leave the shared
## clock permanently ahead of itself for the rules that read it as idle time.
const BEATS: int = 3

## Where "wounded" is, is a property of the ward noun. wound_tier() returns 2 at
## or below ManifestationState.WOUND_WOUNDED and 3 below WOUND_DYING.
const WOUNDED_AT: float = ManifestationState.WOUND_WOUNDED
const WOUNDED_TIER: int = 2

## Price of one held beat, as a fraction of maximum HP. Wounded is at most 40%
## of the bar, so at 5% a player can hold roughly eight beats from the top of
## the wounded band - a fight's worth of panic, not an indefinite licence.
const COST_FRACTION: float = 0.05

## The rattle never takes the last point. It is a purchase, not a suicide pact:
## the player dies to what is chasing them, never to an item whose bill they
## could not see coming.
const MIN_HP_AFTER: float = 1.0

## Own clock, ticked here rather than read off the state, because this pair
## WRITES the shared one. Reading back a number it just wrote would make every
## hold look like a resolved beat and the cost would never be charged.
var _gap: float = 999.0
var _hold_armed: bool = false
var _flash: float = 0.0
var _t: float = 0.0


func _on_manifestation_ready() -> void:
	# World-space overlay: the player rotates to face its movement vector and a
	# held-beat mark must not spin with it.
	top_level = true
	z_as_relative = false
	z_index = 4075
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)


func cost_fraction() -> float:
	# threshold_scale() eases requirements, and here the requirement is the toll.
	return COST_FRACTION * threshold_scale()


func hold_cost() -> float:
	return player_max_hp() * cost_fraction()


func player_max_hp() -> float:
	if player == null or not is_instance_valid(player):
		return 100.0
	var raw: Variant = player.get("max_hp")
	if raw is float or raw is int:
		return maxf(1.0, float(raw))
	return 100.0


func player_hp() -> float:
	if player == null or not is_instance_valid(player):
		return 0.0
	var raw: Variant = player.get("hp")
	if raw is float or raw is int:
		return float(raw)
	return 0.0


func _process(delta: float) -> void:
	_t += delta
	_gap += delta
	_flash = maxf(0.0, _flash - delta)
	global_position = player_position()

	# Once the real gap has outrun the resolve window the hold is moot: a clock
	# nobody touched would already read as resolved. Hand the true value back
	# rather than leaving a permanent offset on a number Stored Violence reads
	# as "how long since you attacked". The write is one-shot; the hold is over.
	if _hold_armed and _gap >= RESOLVE_WINDOW:
		_hold_armed = false
		if state != null and is_instance_valid(state):
			# A proposal, not a write: if an echo reset the shared clock while
			# the hold stood, the fresher value is the true one and it wins.
			state.propose_time_since_attack(_gap)
		queue_redraw()
	elif _hold_armed or _flash > 0.0:
		queue_redraw()


func on_attack(
	_style_id: StringName,
	_origin: Vector2,
	_target: Vector2,
	_power_mul: float,
	_haste_mul: float
) -> void:
	var gap := _gap
	_gap = 0.0

	if _hold_armed:
		_hold_armed = false
		# Charged only where the hold actually did work. If the player waited the
		# window out anyway, an untouched clock would have read as resolved for
		# this shot too and the rattle sold them nothing.
		if gap < RESOLVE_WINDOW:
			_pay_for_the_beat()

	_arm_hold()


## Places the hold for the NEXT shot. Everything that could make it pointless is
## refused here rather than refunded later, because a hold that is armed is a
## hold that will be billed.
func _arm_hold() -> void:
	if state == null or not is_instance_valid(state):
		return
	if state.wound_tier() < WOUNDED_TIER:
		return
	# on_attack runs after the shared counter advanced for this shot, so the next
	# shot is the empowered beat exactly when the counter now sits on the last
	# beat of the cycle.
	if state.beat_in_cycle(BEATS) != BEATS - 1:
		return
	if hold_cost() > player_hp() - MIN_HP_AFTER:
		return
	# A clock that already reads resolved needs no holding, and arming on one
	# would bill for a hold that changed nothing. This is also what keeps the
	# rattle silent on any build where the shared clock is not actually being
	# driven by attacks: nothing to hold, nothing to charge.
	if state.time_since_attack >= HELD_SECONDS:
		return
	state.time_since_attack = HELD_SECONDS
	_hold_armed = true


func _pay_for_the_beat() -> void:
	if player == null or not is_instance_valid(player):
		return
	var hp := player_hp()
	# Clamped rather than refused: the beat has already been granted, so the toll
	# is collected down to the last point and no further.
	var cost := minf(hold_cost(), hp - MIN_HP_AFTER)
	if cost <= 0.0:
		return
	var left := hp - cost
	player.set("hp", left)
	# NOT player.take_damage(). That path rolls evasion, divides the amount by
	# armour and emits player_damage_taken, which would let a ward rule retaliate
	# against a cost the player charged to themselves - and would let armour
	# discount a toll that is not an attack. Self-inflicted, so it goes straight
	# to the number, and announces itself the way the player's own bar does.
	if player.has_signal(&"hp_changed"):
		player.emit_signal(&"hp_changed", left, player_max_hp())
	# A health cost is a damage number, not a callout: it rides the
	# damage_numbers setting, so with callouts off the bar no longer drops
	# with nothing near you and nothing said. The popup stays the callout half.
	if BattleText != null:
		BattleText.player_damage(player_position(), cost)
	_flash = 0.34
	popup("RATTLE -%d" % maxi(1, int(round(cost))), noun_colour(&"ward"), 1.25)


func describe() -> String:
	return (
		"At or below %d%% HP, your empowered beat (every %d beats) is held for you: firing it within %.2fs of the shot before no longer forfeits it, and the held beat costs %.1f%% of your maximum health. The beats between are not held and forfeit as usual. It never takes your last point."
		% [
			int(round(WOUNDED_AT * 100.0)),
			BEATS,
			RESOLVE_WINDOW,
			cost_fraction() * 100.0,
		]
	)


func _draw() -> void:
	# The runner binds the player one frame after this node enters the tree.
	if player == null or not is_instance_valid(player):
		return
	var ward := noun_colour(&"ward")
	var cadence := noun_colour(&"cadence")

	if _flash > 0.0:
		# The toll being taken, drawn as a ring closing inward: the cost arrives
		# on the same frame as the beat it bought, so it must not read as a hit.
		var f := _flash / 0.34
		draw_arc(Vector2.ZERO, 20.0 + 16.0 * f, 0.0, TAU, 26,
			Color(ward.r, ward.g, ward.b, 0.60 * f), 2.4, true)

	if not _hold_armed:
		return

	# The held beat: a bracket around the beat readout rather than another ring,
	# so it reads as "this one is being carried for you" instead of as an aura.
	var pulse := 0.78 + 0.22 * sin(_t * 12.0)
	var at := Vector2(0.0, 34.0)
	for side_index in range(2):
		var edge: float = 1.0 if side_index == 0 else -1.0
		var x := at.x + edge * 24.0
		draw_line(Vector2(x, at.y - 7.0), Vector2(x, at.y + 7.0),
			Color(cadence.r, cadence.g, cadence.b, 0.70 * pulse), 1.8, true)
		draw_line(Vector2(x, at.y - 7.0), Vector2(x - edge * 5.0, at.y - 7.0),
			Color(cadence.r, cadence.g, cadence.b, 0.70 * pulse), 1.8, true)
		draw_line(Vector2(x, at.y + 7.0), Vector2(x - edge * 5.0, at.y + 7.0),
			Color(cadence.r, cadence.g, cadence.b, 0.70 * pulse), 1.8, true)
	draw_circle(at, 3.0 * pulse, Color(ward.r, ward.g, ward.b, 0.55 * pulse))
