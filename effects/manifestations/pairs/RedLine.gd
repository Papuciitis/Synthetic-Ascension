extends ManifestationPairEffect

## Red Line - momentum x ward.
##
## Wounded, Momentum stops being ammunition and becomes escape. Every rule that
## spends the pool keeps doing exactly what it does - Sunder Wake still throws
## its shockwave, Impact Scripture still detonates, Pilgrim's Momentum still
## fires twice. This converts the SPEND itself: the same bank that was about to
## be damage also pays out a burst of speed and one hit you are allowed to
## ignore, and it charges your weapon for the privilege while the burst lasts.
## That last part is the "instead of damage" clause - the Momentum went into
## your legs, so the pair is a disengage rather than a free buff stapled onto
## the blast that triggered it.
##
## It listens to state.resource_spent rather than implementing a hook because
## there is no hook for "the other noun's payoff just happened". A pair is
## dispatched AFTER every slotted rule, so by the time on_attack or
## on_damage_taken reaches this node the pool is already empty and the amount
## that was in it is gone. That signal is the state's own and exists for exactly
## this case; it is disconnected in _exit_tree.

## "Wounded" is a property of the ward NOUN, not of this pair - Martyr Circuit
## reads the same line, and two ward rules that each picked their own threshold
## would disagree about the same word in front of the same player.
const WOUNDED_TIER: int = 2
const WOUNDED_AT: float = ManifestationState.WOUND_WOUNDED

## A dribble of Momentum must not buy a full guard, or a rule that spends the
## pool on contact would hand out an ignored hit every time anything touched
## you.
const MIN_SPEND: float = 0.25

const SURGE_MIN: float = 1.2
const SURGE_MAX: float = 2.6
const SPEED_PER_POTENCY: float = 0.45

## Paid out of the weapon for as long as the surge runs. Deliberately a cost on
## the payoff and not a standing multiplier: it exists only in the window the
## player themselves opened, and only while wounded.
const POWER_DURING_SURGE: float = 0.78

## The ignored hit waits this long. Long enough to survive the run to cover,
## short enough that it cannot be banked across a fight.
const GUARD_TIME: float = 6.0

const GUARD_FLASH: float = 0.34
const RING_RADIUS: float = 30.0

var _surge_left: float = 0.0
var _surge_time: float = 0.0
var _surge_peak: float = 0.0
## Momentum spends re-armed the guard on any spend >= 25%, and with a Momentum
## producer a wounded running player cleared that every ~0.6s - so the cost
## (-22% Power for a couple of seconds) bought outright immunity rather than one
## ignored hit. It is one ignored hit per this, now, which is what the tooltip
## always claimed it was.
const REARM_COOLDOWN: float = 5.0

var _rearm_cd: float = 0.0
var _guard_left: float = 0.0
var _guard_flash: float = 0.0
var _connected: bool = false
var _t: float = 0.0
var _heading: Vector2 = Vector2.RIGHT
var _was_painting: bool = false


func _on_manifestation_ready() -> void:
	# World-space draw: the player rotates to face its movement vector, and a
	# guard ring that spun with it would read as a different effect every frame.
	top_level = true
	z_as_relative = false
	z_index = 4064
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	if player != null and is_instance_valid(player):
		global_position = player.global_position
	if state != null and is_instance_valid(state) and not state.resource_spent.is_connected(_on_resource_spent):
		state.resource_spent.connect(_on_resource_spent)
		_connected = true
	set_process(true)


func _exit_tree() -> void:
	if not _connected:
		return
	_connected = false
	if state == null or not is_instance_valid(state):
		return
	if state.resource_spent.is_connected(_on_resource_spent):
		state.resource_spent.disconnect(_on_resource_spent)


func speed_bonus() -> float:
	return SPEED_PER_POTENCY * potency()


func _on_resource_spent(noun: StringName, amount: float) -> void:
	if noun != &"momentum":
		return
	if state == null or not is_instance_valid(state):
		return
	if state.wound_tier() < WOUNDED_TIER:
		return
	# Momentum is a 0..1 fraction; anything else on that channel is not a bank
	# this pair knows how to price.
	var spent: float = clampf(amount, 0.0, 1.0)
	if spent < MIN_SPEND:
		return

	_surge_time = lerpf(SURGE_MIN, SURGE_MAX, spent)
	_surge_left = _surge_time
	_surge_peak = speed_bonus() * spent
	if _rearm_cd <= 0.0:
		_guard_left = GUARD_TIME
		_rearm_cd = REARM_COOLDOWN
		popup("RED LINE", noun_colour(&"ward"), 1.30)
	else:
		popup("RED LINE", noun_colour(&"momentum"), 1.10)


func _process(delta: float) -> void:
	_t += delta
	if _surge_left > 0.0:
		_surge_left = maxf(0.0, _surge_left - delta)
	if _rearm_cd > 0.0:
		_rearm_cd = maxf(0.0, _rearm_cd - delta)
	if _guard_left > 0.0:
		_guard_left = maxf(0.0, _guard_left - delta)
	_guard_flash = maxf(0.0, _guard_flash - delta)
	_follow_player()

	# Nothing to paint while the pair is dormant, which is most of a run. The
	# trailing frame wipes the last ring instead of leaving it burnt in.
	var painting: bool = _surge_left > 0.0 or _guard_left > 0.0 or _guard_flash > 0.0
	if painting or _was_painting:
		_was_painting = painting
		queue_redraw()


func _follow_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	var here: Vector2 = player.global_position
	var step: Vector2 = here - global_position
	if step.length_squared() > 1.0:
		_heading = step.normalized()
	global_position = here


# ---------------------------------------------------------------------------
# Passive contributions
# ---------------------------------------------------------------------------

func get_move_speed_multiplier() -> float:
	if _surge_left <= 0.0 or _surge_time <= 0.0:
		return 1.0
	# Decays across the window: the burst is a shove out of the fight, not a
	# movement stat that happens to switch on when you are hurt.
	return 1.0 + _surge_peak * (_surge_left / _surge_time)


func get_power_multiplier() -> float:
	return POWER_DURING_SURGE if _surge_left > 0.0 else 1.0


func get_damage_taken_multiplier() -> float:
	return 0.0 if _guard_left > 0.0 else 1.0


func on_damage_taken(_amount: float, _at: Vector2) -> void:
	# The multiplier above is polled INSIDE the player's damage path and this
	# hook fires at the end of that same call, so the guard is spent by exactly
	# one hit. A plain timed window would eat a whole swarm's worth of contacts
	# in a bad second and read as invulnerability rather than as one ignored hit.
	if _guard_left <= 0.0:
		return
	_guard_left = 0.0
	_guard_flash = GUARD_FLASH
	popup("SHRUGGED", noun_colour(&"ward"), 1.20)


func describe() -> String:
	return (
		"While below %d%% HP, spending at least %d%% Momentum turns it into escape: up to +%d%% move speed for %.1fs, decaying, and the next hit within %.0fs is ignored outright. Your attacks deal %d%% less for as long as the burst lasts."
		% [
			int(round(WOUNDED_AT * 100.0)),
			int(round(MIN_SPEND * 100.0)),
			int(round(speed_bonus() * 100.0)),
			SURGE_MAX,
			GUARD_TIME,
			int(round((1.0 - POWER_DURING_SURGE) * 100.0)),
		]
	)


func _draw() -> void:
	# The runner binds the player one frame after this node enters the tree.
	if player == null or not is_instance_valid(player):
		return
	var ward: Color = noun_colour(&"ward")
	var momentum: Color = noun_colour(&"momentum")

	if _surge_left > 0.0 and _surge_time > 0.0:
		var left: float = _surge_left / _surge_time
		draw_arc(
			Vector2.ZERO,
			RING_RADIUS,
			-PI * 0.5,
			-PI * 0.5 + TAU * left,
			36,
			Color(momentum.r, momentum.g, momentum.b, 0.30 + 0.45 * left),
			2.6,
			true
		)
		# Chevrons streaming off the back of the run, MOMENTUM coloured, because
		# the speed IS the Momentum - visibly leaving through your legs instead
		# of through your weapon.
		var back: Vector2 = -_heading
		var side := Vector2(-back.y, back.x)
		var trail := Color(momentum.r, momentum.g, momentum.b, 0.45 * left)
		for i in range(3):
			var step: float = float(i + 1)
			var tip: Vector2 = back * (18.0 + 12.0 * step)
			var arm: Vector2 = tip + back * 8.0
			draw_line(tip, arm + side * 8.0, trail, 2.2, true)
			draw_line(tip, arm - side * 8.0, trail, 2.2, true)

	if _guard_left > 0.0:
		# The held hit: a WARD hexagon that breathes until something spends it.
		# Seven points of draw_arc closes a hexagon without building a
		# PackedVector2Array, and this repaints every frame the guard is up.
		var pulse: float = 0.82 + 0.18 * sin(_t * 7.0)
		draw_arc(
			Vector2.ZERO,
			RING_RADIUS * 1.24 * pulse,
			-PI * 0.5,
			-PI * 0.5 + TAU,
			7,
			Color(ward.r, ward.g, ward.b, 0.55 + 0.30 * pulse),
			2.0,
			true
		)

	if _guard_flash > 0.0:
		var f: float = _guard_flash / GUARD_FLASH
		draw_arc(
			Vector2.ZERO,
			RING_RADIUS * (1.2 + 1.1 * (1.0 - f)),
			0.0,
			TAU,
			40,
			Color(1.0, 0.95, 0.90, 0.85 * f),
			2.6,
			true
		)
