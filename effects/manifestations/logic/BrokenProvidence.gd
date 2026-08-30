extends ManifestationEffect

## Broken Providence - every attack that fails its Lucky Crit banks Misfortune,
## and the next Lucky Crit spends the whole bank at once.
##
## Payout channel, and why it is NOT consume_attack_bonus():
## player.gd _fire_weapon() consumes the attack bonus BEFORE it rolls the Lucky
## Crit, so by the time player_lucky_crit reaches us that channel has already
## been read for this shot. Arming it would quietly empower the *following*
## attack - a jackpot the player cannot connect to the crit that paid it, which
## kills the whole fantasy. The crit signal is emitted before the attack spawns,
## so instead we detonate the bank directly at the crit position: the burst and
## the lucky hit land in the same frame and read as one event.

## The bank cap belongs to the CHANNEL, not to this rule: a second Misfortune
## producer must clamp identically, or it banks past a limit only this rule
## knows about and consume_misfortune() throws the excess away.
##
## Beyond 25 the bank stops being a decision and starts being a savings account.
## At an 8% ceiling on lucky-crit chance that is already about as much bad luck
## as a player realistically strings together.
##
## Read statically, because describe() renders on a detached node with no state.
const MISFORTUNE_CAP: int = int(ManifestationState.CHANNELS[&"misfortune"]["cap"])

const BURST_BASE_MULT: float = 0.50
const BURST_MULT_PER_POINT: float = 0.22
const BURST_RADIUS_BASE: float = 70.0
const BURST_RADIUS_PER_POINT: float = 3.0
const BURST_KNOCKBACK: float = 210.0

const GOLD: Color = Color(1.0, 0.82, 0.20, 1.0)

const VFX_BURST: GDScript = preload("res://assets/vfx/world/manifestations/VFX_ProvidenceBurst.gd")

var _pulse: float = 0.0
var _tally_drawn: bool = false


func _ready() -> void:
	# Drawn in world space around the player rather than as a child transform,
	# so the tally never inherits the player's scaling or flip.
	top_level = true
	z_as_relative = false
	z_index = 4062
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)


func on_lucky_crit_failed() -> void:
	if state == null or not is_instance_valid(state):
		return
	# add_misfortune() enforces the cap itself; this rule does not second-guess
	# it, so a second producer clamps identically.
	state.add_misfortune(1)


func on_lucky_crit(at: Vector2) -> void:
	if state == null or not is_instance_valid(state):
		return
	# No mini() needed: add_misfortune() clamps to the noun's cap, so whatever
	# is banked is exactly what can be paid out.
	var banked: int = state.consume_misfortune()
	if banked <= 0:
		return

	var radius: float = BURST_RADIUS_BASE + BURST_RADIUS_PER_POINT * float(banked)
	damage_radius(at, radius, attack_damage(burst_multiplier(banked)), BURST_KNOCKBACK)

	popup("PROVIDENCE x%d" % banked, GOLD, 1.55 + 0.02 * float(banked))
	var burst: Node2D = VFX_BURST.new() as Node2D
	if burst != null:
		burst.call(&"setup", radius, banked)
		spawn_world_node(burst, at)


func burst_multiplier(banked: int) -> float:
	return (BURST_BASE_MULT + BURST_MULT_PER_POINT * float(banked)) * potency()


func describe() -> String:
	var per: float = BURST_MULT_PER_POINT * potency() * 100.0
	var jackpot: float = burst_multiplier(MISFORTUNE_CAP) * 100.0
	# The Luck ceiling quoted with a pure argument, the way Debt Collector does:
	# this renders detached and serves the shop and the stash, so this run's
	# Luck is not a number it may read. But a no-Luck build banks to the cap
	# and the payout never comes, so the ignition has to be named.
	var ceiling: int = int(round(LuckResolver.lucky_crit_chance(1.0e6) * 100.0))
	return (
		"Every attack that fails its Lucky Crit banks 1 Misfortune (max %d). Your next Lucky Crit spends the bank instantly: a burst around you dealing %.0f%% weapon damage per point (%.0f%% at a full bank) in a radius that grows with it. Needs Luck above 0: the roll never succeeds at or below it; the cap is %d%%."
		% [MISFORTUNE_CAP, per, jackpot, ceiling]
	)


func _process(delta: float) -> void:
	var banked: int = state.misfortune if (state != null and is_instance_valid(state)) else 0
	if banked <= 0:
		# One last redraw to wipe the tally the frame the bank cashes out; after
		# that an empty bank costs nothing per frame.
		if _tally_drawn:
			_tally_drawn = false
			queue_redraw()
		return
	_tally_drawn = true
	_pulse += delta
	global_position = player_position()
	queue_redraw()


func _draw() -> void:
	if state == null or not is_instance_valid(state):
		return
	var banked: int = state.misfortune
	if banked <= 0:
		return

	# One tick per banked point around a widening ring: the tally IS the meter,
	# so the player can read the jackpot without looking at the Run Sheet.
	var fill: float = clampf(float(banked) / float(MISFORTUNE_CAP), 0.0, 1.0)
	var radius: float = 26.0 + 8.0 * fill
	var breathe: float = 0.75 + 0.25 * sin(_pulse * (2.2 + 4.0 * fill))
	# Identity hue from the noun registry; the ramp toward red as the bank fills
	# is authored and stays.
	var base: Color = noun_colour()
	var tint: Color = Color(base.r, base.g * (1.0 - 0.35 * fill), base.b * (1.0 - 0.6 * fill), 0.30 + 0.45 * fill)

	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(tint.r, tint.g, tint.b, tint.a * 0.30 * breathe), 1.6, true)
	for i in range(banked):
		var angle: float = -PI * 0.5 + TAU * (float(i) / float(MISFORTUNE_CAP))
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		draw_line(dir * radius, dir * (radius + 5.0 + 3.0 * breathe), Color(tint.r, tint.g, tint.b, tint.a * breathe), 2.0, true)
