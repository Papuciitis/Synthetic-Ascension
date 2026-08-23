extends ManifestationEffect

## Third Litany - rhythm.
##
## Every third attack is empowered, but only if the second one was allowed to
## resolve. Panic-firing forfeits the payout, which is the whole point: Haste
## shortens the weapon cooldown below the resolve window and stops being
## automatically good.
##
## The hook ordering is the non-obvious part. `consume_attack_bonus()` runs
## BEFORE the attack spawns and `on_attack` (weapon_fired) only after it, so the
## beat counter is always one behind at payout time: when consume sees two
## completed beats, the shot it is being asked about IS the third one.

const BEATS: int = 3
## Owned by the cadence noun, so the rule that BREAKS a rhythm (the Death
## Rattle pair) speaks about the same threshold this one defines.
const RESOLVE_WINDOW: float = ManifestationState.CADENCE_RESOLVE_WINDOW
const PAYOUT_PER_POTENCY: float = 1.6

const PIP_ORIGIN := Vector2(0.0, 34.0)
const PIP_SPACING: float = 13.0

## The beat is a JOIN MARKER into the shared counter, not a private tally: it
## records where in state.attack_index this rule's cycle started. That is what
## lets an echo from an unrelated rule carry the litany forward - and it is why
## two Litanies in different slots share one rhythm instead of drifting apart.
var _cycle_start: int = 0
var _payout_armed: bool = false
var _payout_flash: float = 0.0
var _break_flash: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	# The player rotates to face its movement vector; a beat readout that spun
	# with it would be unreadable, so this draws in world space and tracks the
	# player position itself.
	top_level = true
	z_as_relative = false
	z_index = 4078
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	_payout_flash = maxf(0.0, _payout_flash - delta)
	_break_flash = maxf(0.0, _break_flash - delta)
	global_position = player_position()
	queue_redraw()


func resolve_window() -> float:
	return RESOLVE_WINDOW * threshold_scale()


func payout_multiplier() -> float:
	return 1.0 + PAYOUT_PER_POTENCY * potency()


func beat() -> int:
	if state == null or not is_instance_valid(state):
		return 0
	return mini(state.attack_index - _cycle_start, BEATS - 1)


func since_attack() -> float:
	if state == null or not is_instance_valid(state):
		return 999.0
	return state.time_since_attack


func is_armed() -> bool:
	return beat() >= BEATS - 1 and since_attack() >= resolve_window()


func consume_attack_bonus() -> float:
	if beat() < BEATS - 1:
		return 1.0
	if since_attack() < resolve_window():
		# The second beat never resolved. Restart the cycle here rather than in
		# on_attack so the forfeited shot still counts as its first beat.
		_restart_cycle()
		_break_flash = 0.32
		return 1.0
	_payout_armed = true
	return payout_multiplier()


func _restart_cycle() -> void:
	# -1 because the shot being resolved right now is the new cycle's beat 1;
	# the shared counter has not been advanced for it yet.
	_cycle_start = (state.attack_index if state != null and is_instance_valid(state) else 0) - 1


func on_attack(
	_style_id: StringName,
	_origin: Vector2,
	_target: Vector2,
	_power_mul: float,
	_haste_mul: float
) -> void:
	if _payout_armed:
		_payout_armed = false
		_cycle_start = state.attack_index if state != null and is_instance_valid(state) else 0
		_payout_flash = 0.45
		popup("LITANY x%.1f" % payout_multiplier(), Color(1.0, 0.86, 0.35, 1.0), 1.35)


func describe() -> String:
	return (
		"Every 3rd attack hits for x%.2f - but only if you let the 2nd resolve for %.2fs first. Firing sooner forfeits the litany."
		% [payout_multiplier(), resolve_window()]
	)


func _draw() -> void:
	# The runner binds the player one frame after this node enters the tree.
	if player == null or not is_instance_valid(player):
		return
	var armed := is_armed()
	var dim := Color(0.34, 0.38, 0.48, 0.50)
	# The filled pips ARE the litany, so they carry the noun's identity hue.
	# `hot` stays gold: it marks the armed beat and the payout, which is a
	# different statement from "this pip is counted".
	var lit := noun_colour()
	lit.a = 0.92
	var hot := Color(1.00, 0.86, 0.35, 1.00)
	var first := PIP_ORIGIN - Vector2(PIP_SPACING, 0.0)

	if _payout_flash > 0.0:
		var t := _payout_flash / 0.45
		draw_arc(PIP_ORIGIN, 18.0 + 14.0 * (1.0 - t), 0.0, TAU, 20, Color(hot.r, hot.g, hot.b, 0.55 * t), 2.0, true)
	if _break_flash > 0.0:
		var b := _break_flash / 0.32
		draw_arc(PIP_ORIGIN, 16.0, 0.0, TAU, 18, Color(1.0, 0.24, 0.22, 0.60 * b), 2.0, true)

	for i in range(BEATS):
		var at := first + Vector2(PIP_SPACING * float(i), 0.0)
		var filled := i < beat()
		var color := lit if filled else dim
		var radius := 3.2 if filled else 2.2
		if i == BEATS - 1 and armed:
			var pulse := 0.78 + 0.22 * sin(_t * 11.0)
			draw_circle(at, 9.5 * pulse, Color(hot.r, hot.g, hot.b, 0.22))
			color = hot
			radius = 4.4 * pulse
		draw_circle(at, radius, color)

	# While the second beat is still resolving, the third pip fills as a wedge
	# so the wait reads as progress instead of dead time.
	if beat() >= BEATS - 1 and not armed:
		var window := maxf(resolve_window(), 0.001)
		var fraction := clampf(since_attack() / window, 0.0, 1.0)
		var third := first + Vector2(PIP_SPACING * float(BEATS - 1), 0.0)
		draw_arc(third, 6.5, -PI * 0.5, -PI * 0.5 + TAU * fraction, 14, Color(hot.r, hot.g, hot.b, 0.65), 1.6, true)
