extends ManifestationEffect

## Elites shatter on death and throw fragments you have to go and collect.
##
## The other pure producer. It is deliberately blind to who marked or killed the
## elite, so Predestination Sigil's detonations feed this through the shared
## state without either rule knowing the other exists.
##
## WHY THE FRAGMENTS ARE NOT POSTED STRAIGHT INTO THE ORBIT.
## They used to be, and that made this a faucet with no verb: on a loadout with
## no shard consumer it was a passive damage trickle you could not influence, do
## wrong, or feel - a number that happened near you. A fragment you have to walk
## through turns an elite kill into a decision: break off and collect, or leave
## it and keep shooting. That is the shape every other rule in this noun already
## has, and it costs the rule nothing in power - the shards still arrive, you
## just have to want them.

const BASE_SHARDS: float = 2.0
const SHATTER_TINT: Color = Color(1.00, 0.80, 0.46)

## How far the fragments are thrown. Far enough that collecting is a movement
## decision, close enough that it is not a trek.
const SCATTER_DISTANCE: float = 118.0
const SCATTER_JITTER: float = 42.0


func on_kill(context: EnemyDeathContext) -> void:
	if context == null or not context.is_elite:
		return
	if state == null or not is_instance_valid(state):
		return
	_scatter(context.position, shard_yield())
	popup("%d SPLINTERS" % shard_yield(), SHATTER_TINT)


func shard_yield() -> int:
	return clampi(int(round(BASE_SHARDS * potency())), 2, 3)


func _scatter(at: Vector2, count: int) -> void:
	# Fanned from a random start so two elites dying in the same spot do not
	# stack their fragments on top of each other.
	var base: float = randf() * TAU
	for i in range(count):
		var angle: float = base + TAU * float(i) / float(maxi(1, count))
		var direction := Vector2(cos(angle), sin(angle))
		var splinter := ShardSplinter.new()
		splinter.setup(
			at,
			direction,
			SCATTER_DISTANCE + randf_range(-SCATTER_JITTER, SCATTER_JITTER),
			SHATTER_TINT
		)
		splinter.collected.connect(_on_splinter_collected)
		spawn_world_node(splinter, at)


## A collected fragment joins the shared orbit, or is lost if the orbit is full
## - the same refusal add_shard() gives every other producer.
func _on_splinter_collected(_splinter: ShardSplinter) -> void:
	if state == null or not is_instance_valid(state):
		return
	if state.add_shard(1) > 0:
		popup("+1 SHARD", SHATTER_TINT, 1.15)


func describe() -> String:
	return (
		"Elites shatter when they die, throwing %d fragments clear of the corpse. Walk through one within %ds and it joins your orbit; leave it and it is gone."
		% [shard_yield(), int(ShardSplinter.LIFETIME)]
	)
