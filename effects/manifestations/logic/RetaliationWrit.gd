extends ManifestationEffect

## More evasion, and every evade answers with a nova.
##
## The evasion half is passive (the runner sums it and the player clamps the
## total); the nova half is what changes how the item is played - it rewards
## standing in the swarm instead of kiting it.
##
## The nova is fuelled by banked Momentum, the same pool Impact Scripture spends
## when something connects with you. Both rules are the same behaviour with a
## different trigger, so they share the economy rather than each inventing one:
## wearing both means competing for one bank, which is the friction, not a bug.

const BASE_EVASION: float = 0.06
const EVASION_PER_POTENCY: float = 0.06

const NOVA_RADIUS: float = 150.0
const NOVA_RADIUS_PER_POTENCY: float = 90.0
const NOVA_DAMAGE_MULT: float = 1.35
const NOVA_KNOCKBACK: float = 300.0

## Spent Momentum scales the nova on top of its floor, so a running player is
## answered harder than a planted one.
const NOVA_MOMENTUM_BONUS: float = 1.10

func _on_manifestation_ready() -> void:
	# The evasion budget is a ward resource with one shared clamp, so this
	# registers a contribution instead of reporting a number the runner sums.
	if state != null and is_instance_valid(state):
		state.set_contribution(
			ManifestationState.CHANNEL_EVASION,
			contribution_key(),
			BASE_EVASION + EVASION_PER_POTENCY * potency()
		)


func set_item_instance(inst: ItemInstance) -> void:
	super.set_item_instance(inst)
	_on_manifestation_ready()


func bonus_evasion() -> float:
	return BASE_EVASION + EVASION_PER_POTENCY * potency()


func on_evaded(_position: Vector2) -> void:
	# `_position` is the player's own position at emit time; player_position()
	# is the same point and stays correct if the hook is ever re-routed.
	#
	# A packed swarm resolves many contacts in one frame. The gate is shared
	# across every ward rule, so two of them answer one instant once between
	# them rather than once each.
	if state == null or not is_instance_valid(state) or not state.try_retaliate():
		return

	var centre := player_position()
	var spent: float = state.consume_momentum() if (state != null and is_instance_valid(state)) else 0.0
	var radius := nova_radius() * (1.0 + 0.35 * spent)
	var multiplier: float = (NOVA_DAMAGE_MULT + NOVA_MOMENTUM_BONUS * spent) * potency()
	damage_radius(centre, radius, attack_damage(multiplier), NOVA_KNOCKBACK)

	var vfx := VFX_RetaliationNova.new()
	vfx.setup(centre, radius)
	spawn_world_node(vfx, centre)


func nova_radius() -> float:
	return NOVA_RADIUS + NOVA_RADIUS_PER_POTENCY * (potency() - 1.0)


func describe() -> String:
	return (
		"You evade %d%% more often, and every evade answers with a retaliation nova for %d%% of your attack damage in a %dpx radius - spending any banked Momentum to hit as hard as %d%% over a wider ring."
		% [
			int(round(bonus_evasion() * 100.0)),
			int(round(NOVA_DAMAGE_MULT * potency() * 100.0)),
			int(round(nova_radius())),
			int(round((NOVA_DAMAGE_MULT + NOVA_MOMENTUM_BONUS) * potency() * 100.0)),
		]
	)
