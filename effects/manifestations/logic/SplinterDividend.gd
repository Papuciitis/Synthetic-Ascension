extends ManifestationEffect

## Elites shatter on death and their fragments join the shared orbit.
##
## The other pure producer. It is deliberately blind to who marked or killed the
## elite, so Predestination Sigil's detonations feed this through the shared
## state without either rule knowing the other exists.

const BASE_SHARDS: float = 2.0
const SHATTER_TINT: Color = Color(1.00, 0.80, 0.46)


func on_kill(context: EnemyDeathContext) -> void:
	if context == null or not context.is_elite:
		return
	if state == null or not is_instance_valid(state):
		return
	var added := state.add_shard(shard_yield())
	# The corpse shatters at full yield even when the orbit cannot take the
	# shards: the elite still broke apart, and swallowing the visual would read
	# as the rule having failed to fire.
	_spawn_shatter(context.position, shard_yield())
	if added > 0:
		popup("+%d SHARD" % added, SHATTER_TINT)


func shard_yield() -> int:
	return clampi(int(round(BASE_SHARDS * potency())), 2, 3)


func _spawn_shatter(at: Vector2, count: int) -> void:
	var vfx := VFX_ShardForge.new()
	vfx.setup(at, player_position(), count, SHATTER_TINT)
	spawn_world_node(vfx, at)


func describe() -> String:
	return (
		"Elites shatter when they die, throwing %d fragments into your orbit."
		% shard_yield()
	)
