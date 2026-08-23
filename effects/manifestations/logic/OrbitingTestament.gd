extends ManifestationEffect

## Lucky Crits forge a synthetic shard into the shared orbit.
##
## Pure producer: it never spends shards, so on its own it is a slow-building
## defensive shredder. Rolled next to Vector Halo it becomes the ammunition
## feed for a launcher neither item mentions.

## Added to the SHARED shard damage multiplier, so every orbiting shard hits
## harder - including shards this rule did not forge.
const SHARD_DAMAGE_BONUS: float = 0.10

const SPARK_TINT: Color = Color(0.72, 0.95, 1.0)

var _claimed: bool = false


func _on_manifestation_ready() -> void:
	if state == null or not is_instance_valid(state):
		return
	_claimed = true
	_apply_damage_bonus()


func _exit_tree() -> void:
	if not _claimed:
		return
	_claimed = false
	if state == null or not is_instance_valid(state):
		return
	state.clear_contributions(contribution_key())


## The shard damage multiplier is shared and two Testaments can legitimately be
## worn at once, so this registers what THIS copy contributes rather than
## adding to a running total. Re-registering the same key re-levels it, which
## is why a rank-up needs no delta arithmetic and no unwind bookkeeping.
func _apply_damage_bonus() -> void:
	if state == null or not is_instance_valid(state):
		return
	state.set_contribution(
		ManifestationState.CHANNEL_SHARD_DAMAGE,
		contribution_key(),
		(SHARD_DAMAGE_BONUS + luck_sharpening()) * potency()
	)


func set_item_instance(inst: ItemInstance) -> void:
	super.set_item_instance(inst)
	# The item ranked up under us; re-register at the new value.
	if _claimed:
		_apply_damage_bonus()


## Forged shards get sharper the luckier the run has been: the shared lucky-crit
## tally is what makes this a fortune rule as well as a shard one, so a Luck
## build feeds the orbit twice - more crits, and harder shards.
func luck_sharpening() -> float:
	if state == null or not is_instance_valid(state):
		return 0.0
	return minf(0.20, 0.01 * float(state.lucky_crits))


func on_lucky_crit(at: Vector2) -> void:
	if state == null or not is_instance_valid(state):
		return
	_apply_damage_bonus()
	if state.add_shard(1) <= 0:
		return
	# No popup: the player already gets a "LUCKY" one at this exact position on
	# the same frame, and two texts on one point read as neither.
	_spawn_forge_spark(at)


func _spawn_forge_spark(from: Vector2) -> void:
	var vfx := VFX_ShardForge.new()
	vfx.setup(from, player_position(), 1, SPARK_TINT)
	spawn_world_node(vfx, from)


func describe() -> String:
	return (
		"Every Lucky Crit forges a shard into orbit around you, and each orbiting shard carves for an extra %d%% of your attack damage."
		% int(round(SHARD_DAMAGE_BONUS * potency() * 100.0))
	)
