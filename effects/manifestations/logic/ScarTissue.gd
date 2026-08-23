extends ManifestationEffect

## Scar Tissue - the rule that makes a health pickup a decision.
##
## Healing is the one resource the game hands you for free, so the ward noun was
## missing the obvious question: what if you did not want it? Every point of
## healing this rule refuses becomes armour that decays, which means topping up
## to full is actively worse than staying scarred.
##
## This is also the layer's only consumer of on_healed, a hook that was wired
## and had nothing listening to it.

## Fraction of incoming healing that is refused and converted.
const REFUSE_FRACTION: float = 0.55
## Armour granted per point refused, and how fast it bleeds off.
const ARMOUR_PER_POINT: float = 1.6
const ARMOUR_DECAY_PER_SEC: float = 1.1
const ARMOUR_CAP: float = 60.0

const SCAR_TINT: Color = Color(0.86, 0.34, 0.30, 1.0)

var _armour: float = 0.0
var _drawn: float = -1.0


func _on_manifestation_ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4057
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)


func _exit_tree() -> void:
	if state != null and is_instance_valid(state):
		state.clear_contributions(contribution_key())


func armour_per_point() -> float:
	return ARMOUR_PER_POINT * potency()


func on_healed(amount: float) -> void:
	if amount <= 0.0 or player == null or not is_instance_valid(player):
		return
	# The heal already landed by the time this fires, so the refusal is taken
	# back off rather than prevented - same arithmetic, and it keeps this rule
	# out of the player's healing path.
	var refused := amount * REFUSE_FRACTION
	var hp: Variant = player.get("hp")
	if hp is float or hp is int:
		player.set("hp", maxf(1.0, float(hp) - refused))
		if player.has_signal("hp_changed"):
			player.emit_signal("hp_changed", player.get("hp"), player.get("max_hp"))

	_armour = minf(ARMOUR_CAP, _armour + refused * armour_per_point())
	_publish()


func _publish() -> void:
	if player != null and is_instance_valid(player) and player.has_method("refresh_run_state"):
		# Armour only reaches the player through a stat recompute. Heals are
		# discrete events, not a per-frame stream, so this is affordable - but
		# the decay below deliberately does NOT recompute every tick.
		player.call("refresh_run_state")


func apply_to_stats(s: Stats) -> void:
	if s != null:
		s.armor += _armour


func _process(delta: float) -> void:
	if _armour <= 0.0:
		if _drawn > 0.0:
			_drawn = 0.0
			queue_redraw()
		return
	_armour = maxf(0.0, _armour - ARMOUR_DECAY_PER_SEC * delta)
	global_position = player_position()
	if absf(_armour - _drawn) > 0.5:
		_drawn = _armour
		queue_redraw()


func describe() -> String:
	return (
		"You refuse %d%% of all healing, and every point refused becomes %.1f Armour that slowly bleeds away (up to %d). Staying scarred is tougher than topping up."
		% [int(round(REFUSE_FRACTION * 100.0)), armour_per_point(), int(ARMOUR_CAP)]
	)


func _draw() -> void:
	if _armour <= 0.5:
		return
	var fill := clampf(_armour / ARMOUR_CAP, 0.0, 1.0)
	var tint := Color(SCAR_TINT.r, SCAR_TINT.g, SCAR_TINT.b, 0.20 + 0.35 * fill)
	# Overlapping plates rather than a ring: this is scar, not a meter.
	for i in range(3):
		var radius := 17.0 + 4.0 * float(i)
		var span := PI * (0.35 + 0.5 * fill)
		var phase := -PI * 0.5 + float(i) * 0.7
		draw_arc(Vector2.ZERO, radius, phase, phase + span, 20, tint, 2.2, true)
