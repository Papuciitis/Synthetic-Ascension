extends ManifestationPairEffect

## Loom - cadence x shard.
##
## The keystone of the matrix: it closes a door. Your empowered beat stops being
## a large weapon hit and becomes the trigger that empties the orbit down your
## aim line. Cadence decides WHEN the volley leaves; the shard rules decide how
## much is in it. Neither noun can say that alone, which is the whole argument
## for authoring pairs at all.
##
## What it costs is the point. The orbit stops being ambient damage that happens
## to be circling you and becomes ammunition that is gone the moment the beat
## comes round, so every shard producer is now feeding a gun on a timer rather
## than topping up a halo. A player who wants the orbit to sit there and grind
## has to stop attacking, which is the one thing the cadence noun punishes.
##
## Ordering is the load-bearing detail. player._fire_weapon() reads
## consume_attack_bonus() BEFORE the attack spawns and emits weapon_fired only
## after it, so consume_attack_bonus() is both where the decision is made and
## the last place a shot can still be suppressed. Deciding in on_attack would
## fire the volley a beat late with the weapon damage already spent.

## The pair layer's reading of "the empowered beat", taken off the SHARED
## counter rather than off Third Litany. A pair must work on any loadout that
## lit its two nouns, and the loadout that lit cadence need not contain the
## rule whose cycle happens to be three long - so three is this layer's own
## authored cycle, the same one Tithe Rhythm's line speaks about.
const BEATS: int = 3

## Weapon damage on the woven beat. The attack still swings; only its damage is
## suppressed, so the shot reading as "nothing happened" is impossible - you see
## the weapon fire and the orbit leave with it.
##
## Zero rather than a small fraction because the runner MULTIPLIES every
## effect's one-shot bonus together: a Litany payout landing on the same beat is
## cancelled by the same zero. The empowered beat is spent on the orbit or on
## the weapon, never on both, and that is the door being closed.
const SUPPRESSED: float = 0.0

const LAUNCH_DAMAGE_MULT: float = 0.75
const LAUNCH_SPEED: float = 1240.0
const LAUNCH_LIFETIME: float = 0.90
const LAUNCH_PIERCE: int = 2
const LAUNCH_OFFSET: float = 20.0
## Aimed, so the weave is a tighter fan than Vector Halo's dash-launched spray -
## that one leaves along your escape, this one is a shot you pointed.
const SPREAD_PER_SHARD_DEG: float = 4.0
const MAX_SPREAD_DEG: float = 32.0

const ORBIT_RADIUS: float = ManifestationState.SHARD_ORBIT_RADIUS

var _flash: float = 0.0
var _armed_drawn: bool = false
var _t: float = 0.0


func _on_manifestation_ready() -> void:
	# World-space overlay. The player rotates to face its movement vector and a
	# ring that announces the next beat must not spin with it.
	top_level = true
	z_as_relative = false
	z_index = 4076
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	set_process(true)


func launch_damage_mult() -> float:
	return LAUNCH_DAMAGE_MULT * potency()


## True while the NEXT shot is the one that will be woven. Read by _draw() so
## the player can see the beat coming; a keystone that silently eats an attack
## once every three would read as a weapon bug.
func is_armed() -> bool:
	if state == null or not is_instance_valid(state):
		return false
	return state.beat_in_cycle(BEATS) == BEATS - 1 and state.shard_count() > 0


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	global_position = player_position()

	# Repaint only while there is something moving to paint, or on the frame the
	# armed state flips. Hundreds of enemies are already competing for the frame
	# and this overlay is idle most of the time.
	var armed := is_armed()
	if armed or _flash > 0.0 or armed != _armed_drawn:
		queue_redraw()
	_armed_drawn = armed


## Absorbs rather than scales: see ManifestationRunner.consume_attack_bonus().
## `carried` is the multiplier every other rule already paid for on this beat -
## the Follower Tithe Furnace burned, the litany Third Litany resolved - and the
## volley carries it, so the empowered beat closing the door still spends what
## was spent to arm it.
func absorb_attack_bonus(carried: float) -> float:
	if state == null or not is_instance_valid(state):
		return 1.0
	if state.beat_in_cycle(BEATS) != BEATS - 1:
		return 1.0
	# take_shards() is the test AND the claim in one call, so two reads of the
	# orbit cannot disagree about how many shards this volley is allowed.
	var count := state.take_shards()
	if count <= 0:
		# An empty orbit has nothing to weave. Suppressing anyway would spend the
		# empowered beat on nothing at all, which reads as a broken weapon rather
		# than as a closed door - and a door is only worth closing while there is
		# something behind it.
		return 1.0
	_launch(count, maxf(1.0, carried))
	return SUPPRESSED


func _launch(count: int, carried: float = 1.0) -> void:
	var origin := player_position()
	var facing := aim_direction()
	if facing.length_squared() < 0.0001:
		facing = Vector2.RIGHT
	var spread := deg_to_rad(minf(SPREAD_PER_SHARD_DEG * float(count - 1), MAX_SPREAD_DEG))
	var damage := attack_damage(launch_damage_mult() * carried)
	var tint := noun_colour(&"shard")

	for i in range(count):
		var t: float = 0.5 if count <= 1 else float(i) / float(count - 1)
		var direction := facing.rotated(lerpf(-spread * 0.5, spread * 0.5, t))
		var shard := ManifestationShardProjectile.new()
		shard.speed = LAUNCH_SPEED
		shard.max_life = LAUNCH_LIFETIME
		shard.max_hits = LAUNCH_PIERCE
		shard.tint = tint
		shard.launch(direction, damage, player)
		spawn_world_node(shard, origin + direction * LAUNCH_OFFSET)

	var vfx := VFX_ShardLaunch.new()
	vfx.setup(origin, facing, count, ORBIT_RADIUS * 2.0)
	spawn_world_node(vfx, origin)
	_flash = 0.30
	# Announced with the count, because the count is the whole decision: it tells
	# the player what the beat they just spent was actually worth.
	popup("LOOM x%d" % count, tint, 1.35)


func describe() -> String:
	return (
		"Every %d attacks, that beat deals no weapon damage of its own and fires your whole orbit along your aim - %d%% of your attack damage per shard, piercing %d. Anything else that empowered the beat is spent on the volley rather than lost. With an empty orbit the beat fires as normal."
		% [BEATS, int(round(launch_damage_mult() * 100.0)), LAUNCH_PIERCE]
	)


func _draw() -> void:
	# The runner binds the player one frame after this node enters the tree.
	if player == null or not is_instance_valid(player):
		return
	var shard := noun_colour(&"shard")
	var cadence := noun_colour(&"cadence")

	if _flash > 0.0:
		var f := _flash / 0.30
		draw_arc(Vector2.ZERO, ORBIT_RADIUS * (1.0 + 0.9 * (1.0 - f)), 0.0, TAU, 32,
			Color(shard.r, shard.g, shard.b, 0.45 * f), 2.4, true)

	if not is_armed():
		return

	# The armed read: the orbit is drawn as a bowstring rather than a halo, with
	# the loose direction marked. It says "this is pointed now", which is the one
	# thing the player has to know before pressing fire.
	var pulse := 0.80 + 0.20 * sin(_t * 10.0)
	draw_arc(Vector2.ZERO, ORBIT_RADIUS * 1.20, 0.0, TAU, 36,
		Color(cadence.r, cadence.g, cadence.b, 0.30 * pulse), 1.6, true)
	var facing := aim_direction()
	if facing.length_squared() < 0.0001:
		return
	var side := Vector2(-facing.y, facing.x)
	for sign_index in range(2):
		var edge: float = 1.0 if sign_index == 0 else -1.0
		draw_line(
			side * edge * ORBIT_RADIUS * 1.20,
			facing * ORBIT_RADIUS * (1.30 + 0.16 * pulse),
			Color(shard.r, shard.g, shard.b, 0.42 * pulse),
			1.8,
			true
		)
