extends ManifestationEffect

## Sunder Wake - a CONSUMER of the shared `momentum` resource.
##
## Pilgrim's Momentum banks the metres, this rule cashes them at the point of
## impact. Neither needs the other: on its own Sunder Wake still claims the pool
## (so the HUD meter exists) but nothing fills it, which is exactly the "half an
## engine" a lone roll is supposed to feel like.

const VFX_TEAR := preload("res://assets/vfx/world/manifestations/VFX_SunderTear.gd")

# The world is authored on a 32 px grid (VisionRig.cell_size_px).
const PIXELS_PER_METRE: float = 32.0

## Below this a tear is more screen noise than payoff, and refusing the dregs
## stops a barely-shuffling player from firing a free wave with every click.
const MOMENTUM_FLOOR: float = 0.20

const RADIUS_MIN: float = 72.0
const RADIUS_MAX: float = 188.0
const DAMAGE_MULT: float = 1.35
const KNOCKBACK: float = 420.0

## Rarity may make the tear hit harder, but only half as much wider: area grows
## with the square of the radius, so paying full potency into both would let an
## R20 roll quietly become the entire build.
const RADIUS_POTENCY_SHARE: float = 0.5

const TEAR_TINT := Color(1.0, 0.55, 0.18, 1.0)


func on_attack(
	_style_id: StringName,
	_origin: Vector2,
	target: Vector2,
	_power_mul: float,
	_haste_mul: float
) -> void:
	if state == null or not is_instance_valid(state):
		return
	if state.momentum < MOMENTUM_FLOOR:
		return

	var spent: float = state.consume_momentum()
	var radius: float = lerpf(RADIUS_MIN, RADIUS_MAX, spent) * _radius_potency()
	damage_radius(target, radius, attack_damage(DAMAGE_MULT * spent * potency()), KNOCKBACK * spent)
	_spawn_tear(target, radius, spent)


func _radius_potency() -> float:
	return 1.0 + (potency() - 1.0) * RADIUS_POTENCY_SHARE


func _spawn_tear(center: Vector2, radius: float, spent: float) -> void:
	var tear := VFX_TEAR.new() as Node2D
	if tear == null:
		return
	tear.call(&"setup", radius, spent, TEAR_TINT)
	spawn_world_node(tear, center)


func describe() -> String:
	return "Attacking spends all Momentum (needs %d%%) and tears the ground open where it lands: up to a %.1f m rip for %d%% weapon damage, both scaled by the Momentum spent." % [
		int(round(MOMENTUM_FLOOR * 100.0)),
		(RADIUS_MAX * _radius_potency()) / PIXELS_PER_METRE,
		int(round(DAMAGE_MULT * potency() * 100.0)),
	]
