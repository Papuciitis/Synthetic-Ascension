extends ManifestationEffect

## Overtime Gospel - once the Exit Rite is ready, every moment you refuse to
## leave makes you stronger and hunted faster.
##
## Power is delivered through get_power_multiplier(), which the player polls
## once per attack in _fire_weapon(). No stat recompute is needed for it, so the
## halo can escalate on a timer without ever paying for a recompute.
##
## Arming has two doors on purpose. on_gate_ready() only fires on the checklist
## TRANSITION into `ready`, and ManifestationRunner latches that transition - an
## item equipped after the Exit Rite opened would never hear it. So we also poll
## ThreatDirector.gate_unsealed, which is a single autoload bool read. Either
## door opens the gospel; add_overtime_pressure() itself no-ops until the gate
## is genuinely unsealed, so preaching early can never fabricate Threat.

const TICK_SECONDS: float = 25.0
const POWER_PER_TICK: float = 0.07
const POWER_ESCALATION: float = 0.15
## Was 1.50 - the biggest single number in the layer by a wide distance, and a
## plain damage stat standing in for what should be a risk decision. Most of the
## payoff moved to DEFIANCE below, which is a structure rather than a number.
const POWER_CAP: float = 0.80

## Fraction of Overtime's belief decay this refuses, per tick, and its ceiling.
##
## Overtime devalues every kill the longer you refuse to leave, so greed pays
## progressively less. This rule's whole argument is that staying is correct -
## so what it grants is that the argument becomes TRUE for you: your kills keep
## paying while everyone else's stop. That makes the Gospel the one loadout that
## can actually farm Overtime, which is an archetype the game did not have, and
## it stays honest because the same ticks are shovelling Threat onto the curve.
const DEFIANCE_PER_TICK: float = 0.18
const DEFIANCE_CAP: float = 0.90

## Seconds of unseal time pushed onto the Threat curve per tick. Deliberately
## NOT scaled by potency: rarity grows the reward, never the discount.
const PRESSURE_SECONDS: float = 20.0
const PRESSURE_ESCALATION: float = 0.25

## Luck per refused evacuation, and its ceiling. Deliberately smaller than the
## Power curve: this is a nudge that makes Luck rules worth wearing next to the
## Gospel, not a second damage stat.
const LUCK_PER_TICK: float = 0.06
const LUCK_CAP: float = 0.60

const WARNING: Color = Color(1.0, 0.42, 0.22, 1.0)

const VFX_PULSE: GDScript = preload("res://assets/vfx/world/manifestations/VFX_GospelPulse.gd")

var _open: bool = false
var _saw_unsealed: bool = false
var _ticks: int = 0
var _elapsed: float = 0.0
var _power_bonus: float = 0.0
## Fortune favours the reckless: every tick of refused evacuation also bends
## Luck, which is what makes this share an economy with Broken Providence and
## the Tithe Furnace instead of being a Power stat wearing a greed costume.
var _luck_bonus: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4065
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)


func tick_seconds() -> float:
	return TICK_SECONDS * threshold_scale()


func on_gate_ready() -> void:
	_open_gospel()


func get_power_multiplier() -> float:
	return 1.0 + _power_bonus


## Luck rides the shared fortune ledger, the same pool Heretical Cartography
## publishes into, so a run carrying both reads as one Luck number rather than
## two invisible ones. The runner applies the pool during the stat pass; nothing
## reads Luck per-frame, since LuckResolver only ever sees Global.run_luck.
func _publish_luck() -> void:
	if state == null or not is_instance_valid(state):
		return
	state.set_contribution(
		ManifestationState.CHANNEL_LUCK,
		contribution_key(),
		_luck_bonus
	)


func _exit_tree() -> void:
	# Unequipping must not leave the world permanently refusing its own economy.
	if ThreatDirector != null:
		ThreatDirector.belief_defiance = 0.0
	if state != null and is_instance_valid(state):
		state.clear_contributions(contribution_key())


func describe() -> String:
	return (
		"Once the Exit Rite is ready, every %.0fs you stay grants an escalating Power stack (+%.0f%% for the first, more for every one after, up to +%.0f%%) and +%.0f%% Luck (up to +%.0f%%) - and refuses Overtime's toll on your belief, up to %.0f%% of it, so your kills keep paying when everyone else's have stopped. Each sermon shoves the hunt %.0fs further into Overtime."
		% [
			tick_seconds(),
			POWER_PER_TICK * potency() * 100.0,
			POWER_CAP * 100.0,
			LUCK_PER_TICK * potency() * 100.0,
			LUCK_CAP * 100.0,
			DEFIANCE_CAP * 100.0,
			PRESSURE_SECONDS,
		]
	)


# ---------------------------------------------------------------------------

func _silence() -> void:
	_saw_unsealed = false
	_open = false
	_ticks = 0
	_luck_bonus = 0.0
	_publish_luck()
	_elapsed = 0.0
	_power_bonus = 0.0
	queue_redraw()


func _open_gospel() -> void:
	if _open:
		return
	_open = true
	_elapsed = 0.0
	popup("THE DOOR IS OPEN", WARNING, 1.4)


func _process(delta: float) -> void:
	var unsealed: bool = ThreatDirector != null and ThreatDirector.gate_unsealed
	if unsealed:
		_saw_unsealed = true
	elif _saw_unsealed:
		# The gate re-sealing only happens on a run reset. Silence the sermon
		# rather than carry a stale Power stack into the next attempt.
		_silence()
		return

	if not _open:
		if unsealed:
			_open_gospel()
		else:
			return

	_pulse += delta
	_elapsed += delta
	if _elapsed >= tick_seconds():
		_elapsed -= tick_seconds()
		_preach()

	if _ticks > 0:
		global_position = player_position()
		pulse_redraw()


## One writer, so unequipping the rule cannot leave the world permanently
## refusing its own economy.
func _publish_defiance() -> void:
	if ThreatDirector == null:
		return
	ThreatDirector.belief_defiance = minf(
		DEFIANCE_CAP, DEFIANCE_PER_TICK * float(_ticks) * potency()
	) if _ticks > 0 else 0.0


func _preach() -> void:
	_ticks += 1
	var escalation: float = 1.0 + POWER_ESCALATION * float(_ticks - 1)

	var before: float = _power_bonus
	_power_bonus = minf(POWER_CAP, _power_bonus + POWER_PER_TICK * potency() * escalation)

	if ThreatDirector != null and ThreatDirector.has_method("add_overtime_pressure"):
		ThreatDirector.add_overtime_pressure(PRESSURE_SECONDS * (1.0 + PRESSURE_ESCALATION * float(_ticks - 1)))

	# The warning is the point: the player must be able to feel the trade going
	# bad while the damage number is still going up.
	_luck_bonus = minf(LUCK_CAP, _luck_bonus + LUCK_PER_TICK * potency())
	_publish_defiance()
	_publish_luck()
	if player != null and is_instance_valid(player) and player.has_method("refresh_run_state"):
		player.call("refresh_run_state")

	if _power_bonus > before:
		popup("OVERTIME x%d  +%.0f%% POWER" % [_ticks, _power_bonus * 100.0], WARNING, 1.35 + 0.05 * float(mini(_ticks, 6)))
	else:
		popup("OVERTIME x%d  THEY ARE COMING" % _ticks, WARNING, 1.35)

	var pulse: Node2D = VFX_PULSE.new() as Node2D
	if pulse != null:
		pulse.call(&"setup", _ticks)
		spawn_world_node(pulse, player_position())


func _draw() -> void:
	if _ticks <= 0:
		return
	# A halo that grows with the sermon: harmless-looking at one stack, a lit
	# beacon by five - which is exactly what you have made yourself.
	var heat: float = clampf(_power_bonus / POWER_CAP, 0.0, 1.0)
	var radius: float = 42.0 + 46.0 * heat
	var breathe: float = 0.6 + 0.4 * sin(_pulse * (1.6 + 3.2 * heat))
	# Identity hue from the noun registry - the WARD one, not the primary. This
	# halo is the danger the sermon is buying, and painting it fortune gold
	# would read as a reward. The rule declares both nouns, so this is precise
	# rather than a fudge; the white inner ring and the rays stay authored.
	var base: Color = noun_colour(&"ward")
	var tint: Color = Color(base.r, base.g * (1.0 - 0.4 * heat), base.b * (1.0 - 0.5 * heat), 1.0)

	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color(tint.r, tint.g, tint.b, (0.10 + 0.22 * heat) * breathe), 6.0 + 6.0 * heat, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color(1.0, 0.92, 0.80, (0.18 + 0.30 * heat) * breathe), 1.6, true)

	# One ray per tick, so the count is readable without the popup.
	var rays: int = mini(_ticks, 12)
	for i in range(rays):
		var angle: float = _pulse * 0.35 + TAU * (float(i) / float(rays))
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		draw_line(dir * radius, dir * (radius + 7.0 + 9.0 * heat * breathe), Color(tint.r, tint.g, tint.b, 0.45 * breathe), 2.0, true)
