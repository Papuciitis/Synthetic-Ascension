extends ManifestationEffect

## Fever Litany - the anti-Third-Litany.
##
## Every other cadence rule pays you for WAITING: Third Litany wants you to let
## a beat resolve, Stored Violence wants you not to attack at all. This one pays
## for the opposite, so the cadence noun contains a real argument rather than
## three variations on patience. Rolling this next to Stored Violence is a
## deliberate conflict, the same way Anchor Rite and Pilgrim's Momentum are.

## Consecutive attacks inside this window stack Fever. Deliberately shorter than
## Third Litany's resolve window, so the two cannot both be satisfied.
const CHAIN_WINDOW: float = ManifestationState.CADENCE_CHAIN_WINDOW
const HASTE_PER_STACK: float = 0.06
const MAX_STACKS: int = 6

const FEVER_TINT: Color = Color(1.0, 0.44, 0.22, 1.0)

var _stacks: int = 0
var _last_seen_attack: int = -1
var _drawn_stacks: int = -1


func _on_manifestation_ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4059
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)


func max_haste() -> float:
	return HASTE_PER_STACK * potency() * float(MAX_STACKS)


func chain_window() -> float:
	# threshold_scale() eases requirements, and here the requirement is how
	# quickly you have to keep firing - so a ranked item is more forgiving.
	return CHAIN_WINDOW / maxf(threshold_scale(), 0.01)


func get_haste_multiplier() -> float:
	return 1.0 + HASTE_PER_STACK * potency() * float(_stacks)


func on_attack(
	_style_id: StringName,
	_origin: Vector2,
	_target: Vector2,
	_power_mul: float,
	_haste_mul: float
) -> void:
	if state == null or not is_instance_valid(state):
		return
	# The counter has already advanced for this attack, so time_since_attack is
	# 0.0 here and testing it answered "true" unconditionally. state.last_attack_gap
	# is the gap that preceded this attack, which is the gap actually being judged.
	_stacks = mini(_stacks + 1, MAX_STACKS) if _chain_held() else 1
	_last_seen_attack = state.attack_index


func _chain_held() -> bool:
	if _last_seen_attack < 0:
		return false
	return state.last_attack_gap <= chain_window()


func _process(delta: float) -> void:
	if state == null or not is_instance_valid(state):
		return
	global_position = player_position()

	# Letting the chain lapse DISCHARGES it. Without this the rule was a pure
	# stat wearing a condition: "keep attacking" is what every build already
	# does, so the Haste was unconditional, the advertised cost did not exist,
	# and on melee (cooldown 0.0, so haste_mul never applies) it did nothing at
	# all. Now the fever is a decision - ride it for the attack rate, or break
	# rhythm on purpose to spend it - and the discharge is damage, which melee
	# feels exactly as much as anything else does.
	if _stacks > 0 and state.time_since_attack > chain_window():
		_discharge(_stacks)
		_stacks = 0

	if _stacks != _drawn_stacks:
		_drawn_stacks = _stacks
		queue_redraw()
	elif _stacks > 0:
		queue_redraw()

	_pulse += delta


var _pulse: float = 0.0


## Radius and damage both scale with the stacks you were holding, so breaking
## rhythm at six is a real payout and breaking it at one is barely a flinch.
const BREAK_RADIUS: float = 92.0
const BREAK_RADIUS_PER_STACK: float = 22.0
const BREAK_DAMAGE_PER_STACK: float = 0.55
const BREAK_KNOCKBACK: float = 190.0


func break_radius(stacks: int) -> float:
	return BREAK_RADIUS + BREAK_RADIUS_PER_STACK * float(stacks)


func _discharge(stacks: int) -> void:
	if stacks <= 0:
		return
	var centre := player_position()
	var radius := break_radius(stacks)
	var multiplier: float = BREAK_DAMAGE_PER_STACK * float(stacks) * potency()
	damage_radius(centre, radius, attack_damage(multiplier), BREAK_KNOCKBACK)
	var vfx := VFX_RetaliationNova.new()
	vfx.setup(centre, radius)
	spawn_world_node(vfx, centre)
	popup("FEVER BREAK x%d" % stacks, noun_colour(&"cadence"), 1.10 + 0.06 * float(stacks))


func describe() -> String:
	return (
		"Attacks fired within %.2fs of the last stack Fever: +%d%% Haste each, up to +%d%%. Let the chain lapse and the whole fever breaks at once - %d%% of your attack damage per stack in a %d px burst."
		% [
			chain_window(),
			int(round(HASTE_PER_STACK * potency() * 100.0)),
			int(round(max_haste() * 100.0)),
			int(round(BREAK_DAMAGE_PER_STACK * potency() * 100.0)),
			int(round(break_radius(MAX_STACKS))),
		]
	)


func _draw() -> void:
	if _stacks <= 0:
		return
	var fill := float(_stacks) / float(MAX_STACKS)
	var breathe := 0.80 + 0.20 * sin(_pulse * (4.0 + 6.0 * fill))
	var tint := Color(FEVER_TINT.r, FEVER_TINT.g, FEVER_TINT.b, (0.22 + 0.42 * fill) * breathe)

	# A ring that closes as the chain builds, and ticks that burn off with it.
	draw_arc(Vector2.ZERO, 21.0, -PI * 0.5, -PI * 0.5 + TAU * fill, 32, tint, 2.6, true)
	for i in range(_stacks):
		var angle := -PI * 0.5 + TAU * (float(i) / float(MAX_STACKS))
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(dir * 22.0, dir * (26.0 + 4.0 * breathe), tint, 2.0, true)
