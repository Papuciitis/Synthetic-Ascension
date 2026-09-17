extends ManifestationPairEffect

## Bad Fortune Engine - fortune x shard.
##
## The converter that makes a LOW-Luck run buildable. Lucky Crit chance is hard
## capped at 8% by LuckResolver, so the overwhelming majority of attacks MISS
## their Luck roll - and this turns that stream of nothing into ammunition,
## paid for out of the only other thing a missed roll produces.
##
## WHY IT SPENDS THE BANK RATHER THAN INTERCEPTING IT.
## Broken Providence banks its point from its own on_lucky_crit_failed, and a
## pair is dispatched AFTER every slotted rule, so by the time this runs the
## point is already banked and no hook exists that could have stopped it.
## "Instead of banking Misfortune" is therefore expressed as an immediate
## withdrawal of exactly what one forge cost. The field is written directly
## because consume_misfortune() drains the WHOLE bank, which is the one thing
## this must never do: Providence's jackpot is the other half of the choice the
## player is being asked to make. resource_spent is emitted by hand so the HUD
## pulse and anything else listening still see the withdrawal.
##
## The withdrawal happens ONLY when a shard was actually forged. At a full orbit
## the failed roll banks Misfortune exactly as it always did, so one economy's
## overflow is the other's input rather than being thrown away - and the engine
## only really bites next to something that drains the orbit (Vector Halo, the
## Loom), because that is what keeps making room for the next forge.

## Two per success, as authored. take_shards() clamps to what is in orbit, so a
## crit landing on a single shard fires that one rather than being swallowed.
const SPEND_PER_CRIT: int = 2

## A launched shard hits for the SHARED orbit damage times this. Deliberately
## routed through state.shard_damage_mult() rather than a flat weapon
## multiplier: Orbiting Testament's sharpening feeds this pair without either
## knowing the other exists, which is the whole point of the shard noun.
const STRIKE_SCALE: float = 1.30

## Read statically so describe() can quote the real floor from the detached node
## it renders on.
const BASE_SHARD_DAMAGE: float = ManifestationState.BASE_SHARD_DAMAGE_MULT

const LAUNCH_SPEED: float = 1180.0
const LAUNCH_LIFETIME: float = 0.85
const LAUNCH_PIERCE: int = 3
const LAUNCH_OFFSET: float = 18.0
const LAUNCH_SPREAD_DEG: float = 9.0

## Where the forged shard is drawn coming from - just off the player, so the
## missed roll reads as having been caught rather than as having happened.
const FORGE_DISTANCE: float = 42.0

## Seconds between forges.
##
## Lucky Crit chance caps at 8%, so about 92% of attacks miss - which at a 0.22s
## weapon cooldown is roughly 4.5 forges a SECOND, forever. Two things went
## wrong with that. Anything draining the orbit (Reliquary Guard spends at most
## one per 0.25s) could never out-drink the tap, so "a health bar made of
## shards" simply never emptied. And the forge spark became wallpaper - a node
## every fifth of a second for a whole run, which is the opposite of a missed
## roll being CAUGHT.
##
## Rate-limited below any consumer's drain, so the orbit is something you can
## still run dry. The point stays banked whenever a forge is refused, exactly as
## it does at a full orbit, so nothing is thrown away by waiting.
const FORGE_COOLDOWN: float = 0.45

var _forge_cd: float = 0.0


func _on_manifestation_ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if _forge_cd > 0.0:
		_forge_cd = maxf(0.0, _forge_cd - delta)


func strike_multiplier() -> float:
	var orbit: float = state.shard_damage_mult() if (state != null and is_instance_valid(state)) else BASE_SHARD_DAMAGE
	return orbit * STRIKE_SCALE * potency()


# ---------------------------------------------------------------------------
# The producer half: a missed Luck roll becomes a shard, billed to the bank.
# ---------------------------------------------------------------------------

func on_lucky_crit_failed() -> void:
	if state == null or not is_instance_valid(state):
		return
	if _forge_cd > 0.0:
		return
	# add_shard() enforces the shared cap itself; a refusal means the orbit is
	# full, and a full orbit is exactly when the point should stay banked.
	if state.add_shard(1) <= 0:
		return
	_forge_cd = FORGE_COOLDOWN
	_withdraw_one_misfortune()
	_spawn_forge_spark()


## One point, never the bank. See the header for why this writes the field.
func _withdraw_one_misfortune() -> void:
	if state == null or not is_instance_valid(state) or state.misfortune <= 0:
		return
	state.misfortune -= 1
	state.resource_spent.emit(&"fortune", 1.0)
	# Broken Providence's owner watches the bank tick DOWN a point at a time,
	# which with nothing said reads as a Providence bug. Merge-keyed: at the
	# forge cadence this repeats a couple of times a second and says the same
	# thing each time.
	if BattleText != null:
		BattleText.progress(player_position(), "-1 MISFORTUNE → SHARD", int(get_instance_id()), noun_colour(&"fortune"))


func _spawn_forge_spark() -> void:
	# Only fires while the orbit has room, so this is a couple of nodes per
	# Lucky Crit rather than one per attack - the cap does the rate limiting.
	var here := player_position()
	var direction := aim_direction()
	if direction.length_squared() < 0.0001:
		direction = Vector2.RIGHT
	var from := here + direction * FORGE_DISTANCE
	var vfx := VFX_ShardForge.new()
	vfx.setup(from, here, 1, noun_colour(&"shard"))
	spawn_world_node(vfx, from)


# ---------------------------------------------------------------------------
# The consumer half: a hit Luck roll spends two shards down the aim line.
# ---------------------------------------------------------------------------

func on_lucky_crit(at: Vector2) -> void:
	if state == null or not is_instance_valid(state):
		return
	var spent := state.take_shards(SPEND_PER_CRIT)
	# An empty orbit pays nothing. That is the drama of a Luck build wearing
	# this: the crits it fishes for are what empties the engine that feeds them.
	if spent <= 0:
		return
	_fire(at, spent)


func _fire(from: Vector2, count: int) -> void:
	var facing := aim_direction()
	if facing.length_squared() < 0.0001:
		facing = Vector2.RIGHT
	var tint := noun_colour(&"shard")
	var damage := attack_damage(strike_multiplier())
	var spread := deg_to_rad(LAUNCH_SPREAD_DEG * float(count - 1))

	for i in range(count):
		var t: float = 0.5 if count <= 1 else float(i) / float(count - 1)
		var direction := facing.rotated(lerpf(-spread * 0.5, spread * 0.5, t))
		var shard := ManifestationShardProjectile.new()
		shard.speed = LAUNCH_SPEED
		shard.max_life = LAUNCH_LIFETIME
		shard.max_hits = LAUNCH_PIERCE
		shard.tint = tint
		shard.launch(direction, damage, player)
		spawn_world_node(shard, from + direction * LAUNCH_OFFSET)

	var vfx := VFX_ShardLaunch.new()
	vfx.setup(from, facing, count, ManifestationState.SHARD_ORBIT_RADIUS)
	spawn_world_node(vfx, from)
	popup("BAD FORTUNE x%d" % count, noun_colour(&"fortune"), 1.35)


func describe() -> String:
	return (
		"Every attack that misses its Lucky Crit forges a shard into orbit and withdraws 1 banked Misfortune to pay for it, at most one forge every %.2fs - with the orbit full or the forge still hot, the point stays banked instead. Every Lucky Crit spends %d shards, firing them along your aim for %d%% of your attack damage each (more as your shards sharpen), piercing %d."
		% [
			FORGE_COOLDOWN,
			SPEND_PER_CRIT,
			int(round(BASE_SHARD_DAMAGE * STRIKE_SCALE * potency() * 100.0)),
			LAUNCH_PIERCE,
		]
	)
