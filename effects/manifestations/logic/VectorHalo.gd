extends ManifestationEffect

## Both halves of the shard engine on one item: a slow feed, and a wide orbit
## that empties itself down the aim line the instant it fills.
##
## The authored intent was "your ranged projectiles no longer immediately fire
## forward, they accumulate in an orbit around Syn'Tek; dashing launches them".
## There is no dash, so the launch trigger is the orbit FILLING - but the
## accumulation half is real: every STORE_INTERVAL attacks one shot is pulled
## back into the halo instead of leaving.
##
## Worn alone that is a complete loop, deliberately slow: one volley per ~15s of
## sustained ranged fire, at every rank. Worn next to Orbiting Testament or
## Splinter Dividend their shards land in this same orbit, so the trickle becomes
## a feed - 1.4x to 1.8x the launch rate - and each of those launches is wider,
## because the cap bonus made the room the producer is filling. The producer also
## makes the waiting halo hit harder (Testament's shared damage bonus) and land
## on the right beat (Splinter's elite deaths), so the pair changes when and how
## hard the volley goes off, not just how often.
##
## The interval is deliberately slower than the orbit drains. The halo launches
## the frame it fills, so a producer's shards are essentially never rejected for
## want of room; a fast self-feed would eat the ammunition it exists to
## complement.

## One stored shard per this many attacks. At ranged_cooldown 0.22 that is a
## shard every ~2.2s; magic (0.55) is proportionally slower, which is the price
## of the heavier style.
const STORE_INTERVAL: int = 10
## threshold_scale() eases requirements by at most 22%: a maxed instance stores
## every eighth attack instead of every tenth.
const MIN_STORE_INTERVAL: int = 8
## How far ahead of the player the withheld shot is drawn curling back from, so
## the feed reads as "that projectile did not leave".
const STORE_DRAW_DISTANCE: float = 54.0

const BASE_CAP_BONUS: int = 3
## Every full step of potency above 1.0 adds one more slot: +3 / +4 / +5.
const CAP_BONUS_POTENCY_STEP: float = 0.30

const LAUNCH_DAMAGE_MULT: float = 0.80
const LAUNCH_SPEED: float = 1180.0
const LAUNCH_LIFETIME: float = 0.85
const LAUNCH_PIERCE: int = 3
const LAUNCH_OFFSET: float = 18.0
const SPREAD_PER_SHARD_DEG: float = 6.0
const MAX_SPREAD_DEG: float = 54.0

## Long enough that a halo refilled by the same volley's kills cannot re-fire
## before the player has seen the first one leave.
const REARM_TIME: float = 0.35

const HALO_TINT: Color = Color(0.72, 0.95, 1.0)

var _claimed: bool = false
var _rearm: float = 0.0
var _announced_full: bool = false
## Join marker into the shared attack counter. Deliberately NOT reset on a
## rank-up: a shorter interval should pay out sooner, never restart progress the
## player already earned.
var _cycle_start: int = 0


func _on_manifestation_ready() -> void:
	if state == null or not is_instance_valid(state):
		return
	_claimed = true
	_apply_cap_bonus()


func _exit_tree() -> void:
	if not _claimed:
		return
	_claimed = false
	if state == null or not is_instance_valid(state):
		return
	# Shards already in orbit above the shrunken cap are left alone rather than
	# deleted - unequipping should never confiscate the player's halo.
	state.clear_contributions(contribution_key())


## Registers what THIS copy widens the shared orbit by. Two Halos may be worn
## and either may be removed first, so each owns its own entry rather than
## adding into a running total nobody can unwind correctly.
func _apply_cap_bonus() -> void:
	if state == null or not is_instance_valid(state):
		return
	state.set_contribution(
		ManifestationState.CHANNEL_SHARD_CAP,
		contribution_key(),
		float(cap_bonus())
	)


func set_item_instance(inst: ItemInstance) -> void:
	super.set_item_instance(inst)
	if _claimed:
		_apply_cap_bonus()
	# The join marker is deliberately NOT reset: a rank-up that shortens the interval
	# should pay out sooner, never restart the charge the player already earned.


func cap_bonus() -> int:
	return BASE_CAP_BONUS + int(floor((potency() - 1.0) / CAP_BONUS_POTENCY_STEP))


func _attacks_since_join() -> int:
	if state == null or not is_instance_valid(state):
		return 0
	return maxi(0, state.attack_index - _cycle_start)


func store_interval() -> int:
	return clampi(
		int(round(float(STORE_INTERVAL) * threshold_scale())),
		MIN_STORE_INTERVAL,
		STORE_INTERVAL
	)


# ---------------------------------------------------------------------------
# The producer half: a shot withheld instead of fired.
# ---------------------------------------------------------------------------

func on_attack(
	_style_id: StringName,
	_origin: Vector2,
	target: Vector2,
	_power_mul: float,
	_haste_mul: float
) -> void:
	if state == null or not is_instance_valid(state):
		return
	if _attacks_since_join() < store_interval():
		return
	# The counter is NOT cleared on a refused store. If the orbit was full - or
	# sitting in the re-arm window with a launch already spent - the charge is
	# held and the next attack retries, so the one shot in ten this rule keeps
	# is never silently swallowed by the volley it was about to trigger.
	if state.add_shard(1) <= 0:
		return
	_cycle_start = state.attack_index if state != null and is_instance_valid(state) else 0
	_spawn_store_spark(target)


func _spawn_store_spark(target: Vector2) -> void:
	var here := player_position()
	var direction := target - here
	if direction.length_squared() < 0.0001:
		direction = aim_direction()
	else:
		direction = direction.normalized()
	# No popup: at sustained fire this fires every couple of seconds and the
	# SHARDS meter on the Run Sheet already counts it. The shot curling back
	# into the orbit is the whole read.
	var from := here + direction * STORE_DRAW_DISTANCE
	var vfx := VFX_ShardForge.new()
	vfx.setup(from, here, 1, HALO_TINT)
	spawn_world_node(vfx, from)


# ---------------------------------------------------------------------------
# The consumer half: a full orbit empties down the aim line.
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _rearm > 0.0:
		_rearm = maxf(0.0, _rearm - delta)
	if state == null or not is_instance_valid(state):
		return

	# The halo no longer fires itself. But add_shard() refuses at the cap, so a
	# full orbit with the dash on cooldown silently rejects every incoming shard
	# and the producers stop paying out with no feedback. This turns that silent
	# waste into a legible "dash now", which is the authored loop.
	var full := state.shards_full()
	if full and not _announced_full:
		_announced_full = true
		popup("HALO FULL", Color(0.72, 0.95, 1.0, 1.0), 1.30)
	elif not full and state.shard_count() <= maxi(1, state.shard_cap() - 2):
		_announced_full = false


## The dash IS the trigger. Launching at any shard count rather than only at the
## cap is deliberate: gating on full would make most dashes a no-op and leave
## "the orbit filled" as the real trigger, which is the thing being replaced.
func on_dash(from: Vector2, direction: Vector2) -> void:
	if _rearm > 0.0 or state == null or not is_instance_valid(state):
		return
	var launched := state.take_shards()
	# A second Vector Halo reacting to the same dash finds an emptied orbit and
	# no-ops, so two copies can never double-fire one halo.
	if launched <= 0:
		return
	_rearm = REARM_TIME
	_announced_full = false
	_launch(launched, from, direction)


func _launch(count: int, origin: Vector2, facing: Vector2) -> void:
	# Along the dash vector, not the aim vector: the halo leaves WITH you.
	if facing.length_squared() < 0.0001:
		facing = aim_direction()
	if facing.length_squared() < 0.0001:
		facing = Vector2.RIGHT
	var spread := deg_to_rad(minf(SPREAD_PER_SHARD_DEG * float(count - 1), MAX_SPREAD_DEG))
	var damage := attack_damage(LAUNCH_DAMAGE_MULT * potency())

	for i in range(count):
		var t: float = 0.5 if count <= 1 else float(i) / float(count - 1)
		var direction := facing.rotated(lerpf(-spread * 0.5, spread * 0.5, t))
		var shard := ManifestationShardProjectile.new()
		shard.speed = LAUNCH_SPEED
		shard.max_life = LAUNCH_LIFETIME
		shard.max_hits = LAUNCH_PIERCE
		shard.tint = HALO_TINT
		shard.launch(direction, damage, player)
		spawn_world_node(shard, origin + direction * LAUNCH_OFFSET)

	var vfx := VFX_ShardLaunch.new()
	vfx.setup(origin, facing, count, ManifestationState.SHARD_ORBIT_RADIUS * 2.0)
	spawn_world_node(vfx, origin)
	popup("VECTOR HALO", HALO_TINT, 1.35)


func describe() -> String:
	var interval := store_interval()
	return (
		"One attack in %d curls back into orbit instead of firing, and your orbit holds %d more shards. Dashing launches the whole orbit along your dash for %d%% of your attack damage each, piercing %d enemies."
		% [
			interval,
			cap_bonus(),
			int(round(LAUNCH_DAMAGE_MULT * potency() * 100.0)),
			LAUNCH_PIERCE,
		]
	)
