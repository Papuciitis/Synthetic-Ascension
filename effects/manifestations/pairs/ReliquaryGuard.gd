extends ManifestationPairEffect

## Reliquary Guard - shard x ward.
##
## A converter: the orbit stops being ambient damage and becomes a health bar.
## Every other shard rule answers "when does the orbit go off?"; this one turns
## every launch, weave and detonation into a question about how much armour the
## player is willing to throw away. Vector Halo's dash, Loom's beat and the
## Sigil's Mark all read differently the moment their ammunition is also the
## thing keeping you alive.
##
## Ordering is the load-bearing detail. player._take_damage() polls
## get_damage_taken_multiplier() BEFORE the damage is applied and emits
## player_damage_taken - which is what reaches on_damage_taken - only after. So
## the multiplier is where the guard COMMITS and the hook is where it PAYS, and
## the multiplier has to already know a shard is available. A latch carries that
## one decision across the few lines between them, which is also what makes one
## poll cost exactly one shard.

## Why NOT state.try_retaliate().
##
## That gate exists so several ward rules answer ONE contact exactly once -
## Retaliation Writ's nova and Impact Scripture's detonation share it
## deliberately. This is not an answer to a hit, it is the hit not landing, and
## taking the shared gate would make the two steal each other's frame: a nova
## that fired first would leave the player unguarded for that instant, and a
## guard that absorbed first would swallow the nova. Its 0.12s is also a
## same-frame de-duplicator rather than an economy - eight absorbs a second
## would empty a full orbit in half a second of contact.
##
## So the guard keeps its own, longer gate. 0.25s still absorbs every contact
## tick (player.contact_tick is 0.5s) so the authored promise holds against the
## threat it is written for, while a burst of projectiles arriving in one
## instant costs one shard rather than the whole reliquary.
const SHATTER_COOLDOWN: float = 0.25
const MIN_SHATTER_COOLDOWN: float = 0.10

## The guard makes the orbit worth more, so it also makes it bigger: "an empty
## orbit is an unguarded one" is only a real decision while there is a bar to
## spend. Registered through the shared ledger keyed by this pair, exactly like
## Vector Halo's, so ranking a contributor re-levels it in place.
const BASE_CAP_BONUS: int = 1
## Every full step of potency above 1.0 adds one more slot: +1 / +2 / +3.
const CAP_BONUS_POTENCY_STEP: float = 0.30

const ORBIT_RADIUS: float = ManifestationState.SHARD_ORBIT_RADIUS

## The latch must not outlive the hit it was armed for. It normally lives a few
## statements; anything longer means a damage path polled without emitting, and
## a stale latch would spend a shard on an unrelated hit that was never guarded.
const LATCH_TIMEOUT: float = 0.25

var _latched: bool = false
var _latch_age: float = 0.0
var _cooldown: float = 0.0
var _flash: float = 0.0
var _drawn_guarded: bool = false


func _on_manifestation_ready() -> void:
	# World-space overlay: the player rotates to face its movement vector and a
	# ward ring must not spin with it.
	top_level = true
	z_as_relative = false
	z_index = 4077
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)
	_apply_cap_bonus()


func _exit_tree() -> void:
	if state == null or not is_instance_valid(state):
		return
	# Shards already orbiting above the shrunken cap are left alone: losing the
	# pair should never confiscate the halo the player earned.
	state.clear_contributions(contribution_key())


func set_contributor_rarity(mean_rarity: float) -> void:
	super.set_contributor_rarity(mean_rarity)
	# A contributor ranking up re-levels the bonus in place. The ledger is keyed
	# by this pair, so re-registering IS the whole update - no delta to unwind.
	_apply_cap_bonus()


func _apply_cap_bonus() -> void:
	if state == null or not is_instance_valid(state):
		return
	state.set_contribution(
		ManifestationState.CHANNEL_SHARD_CAP,
		contribution_key(),
		float(cap_bonus())
	)


func cap_bonus() -> int:
	return BASE_CAP_BONUS + int(floor((potency() - 1.0) / CAP_BONUS_POTENCY_STEP))


func shatter_cooldown() -> float:
	# threshold_scale() eases requirements, and the requirement here is how long
	# the reliquary needs before it can spend another shard.
	return maxf(MIN_SHATTER_COOLDOWN, SHATTER_COOLDOWN * threshold_scale())


func is_guarding() -> bool:
	if state == null or not is_instance_valid(state):
		return false
	return _cooldown <= 0.0 and state.shard_count() > 0


func get_damage_taken_multiplier() -> float:
	if not is_guarding():
		return 1.0
	# Committed here, paid in on_damage_taken. Nothing between this line and the
	# emit can cancel the hit, so the pairing is exact.
	_latched = true
	_latch_age = 0.0
	return 0.0


func on_damage_taken(_amount: float, _at: Vector2) -> void:
	if not _latched:
		# A hit this guard did not nullify: the orbit was empty, the reliquary
		# was still re-arming, or the damage reached the player by a path that
		# never polled the multiplier. Not ours to charge for.
		return
	_latched = false
	if state == null or not is_instance_valid(state):
		return
	if state.take_shards(1) <= 0:
		return
	_cooldown = shatter_cooldown()
	_flash = 0.30
	var shard := noun_colour(&"shard")
	var vfx := VFX_PairShatter.new()
	vfx.setup(player_position(), ORBIT_RADIUS, shard)
	spawn_world_node(vfx, player_position())
	# Announced every time, unlike the shard trickle. A hit that dealt exactly
	# nothing has to say why, or the player reads it as an enemy that missed.
	popup("WARDED", noun_colour(&"ward"), 1.20)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)
	_flash = maxf(0.0, _flash - delta)
	if _latched:
		_latch_age += delta
		if _latch_age > LATCH_TIMEOUT:
			_latched = false

	global_position = player_position()

	# Moving a Node2D does not need a repaint, so the ring is redrawn only when
	# the guarded state flips or while the shatter flash is running.
	var guarded := is_guarding()
	if _flash > 0.0 or guarded != _drawn_guarded:
		queue_redraw()
	_drawn_guarded = guarded


func describe() -> String:
	return (
		"While your orbit holds shards, a hit that would land on you shatters one instead and deals you nothing - at most one shatter every %.2fs. Your orbit holds %d more. An empty orbit is an unguarded one."
		% [shatter_cooldown(), cap_bonus()]
	)


func _draw() -> void:
	# The runner binds the player one frame after this node enters the tree.
	if player == null or not is_instance_valid(player):
		return
	var ward := noun_colour(&"ward")
	var shard := noun_colour(&"shard")

	if _flash > 0.0:
		var f := _flash / 0.30
		draw_arc(Vector2.ZERO, ORBIT_RADIUS * (1.30 - 0.24 * f), 0.0, TAU, 32,
			Color(ward.r, ward.g, ward.b, 0.55 * f), 3.0, true)
		draw_arc(Vector2.ZERO, ORBIT_RADIUS * 1.30, 0.0, TAU, 32,
			Color(shard.r, shard.g, shard.b, 0.30 * f), 1.4, true)

	if not is_guarding():
		return

	# A hexagonal ward outside the orbit: the shards are the bar, this says the
	# bar is currently the thing standing between the player and the next hit.
	var points := PackedVector2Array()
	for i in range(7):
		var angle := TAU * float(i) / 6.0
		points.append(Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS * 1.26)
	draw_polyline(points, Color(ward.r, ward.g, ward.b, 0.26), 1.6, true)
