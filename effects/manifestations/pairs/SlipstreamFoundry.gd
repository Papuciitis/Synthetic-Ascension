extends ManifestationPairEffect

## Slipstream Foundry - momentum x shard.
##
## Running strips the orbit. Every stride pulls one shard out of the halo and
## leaves it standing where you were, biting whatever walks into it, until it
## snaps back into orbit behind you. A shard in the trail is genuinely gone from
## the orbit - take_shards() removes it and add_shard() gives it back - so the
## halo visibly thins while you run and refills when you stop, and every rule
## that spends the orbit sees the smaller number this rule really left it.
##
## SCOPE NOTE, deliberate. The authored line is "your shards stop orbiting and
## string out behind you". The orbit is simulated, damaged and DRAWN by
## ManifestationState itself (`shards`, `_shard_spin`, `_tick_shards`, its
## `_draw`), so a pair that re-positioned those entries every frame would be
## fighting their owner: the sweep would go on damaging from the orbit ring
## while the art sat somewhere else, and the state's next `_tick_shards` would
## put them back. This owns the half a pair CAN own honestly. Making the trail
## the shards' real positions needs an anchored position per shard inside
## ManifestationState - a change to the owner, not to this file.

const MOTE_VFX := preload("res://assets/vfx/world/manifestations/VFX_PairSlipstreamMote.gd")

# The world is authored on a 32 px grid (VisionRig.cell_size_px), so a design
# "metre" is 32 px of travel.
const PIXELS_PER_METRE: float = 32.0
const DROP_METRES: float = 3.0
const DROP_DISTANCE: float = DROP_METRES * PIXELS_PER_METRE

## How many shards may be on the ground at once. The cap is what keeps the pair
## from emptying the halo outright: a player who never stops still has shards in
## orbit for Vector Halo to launch or Reliquary Guard to spend.
const MAX_TRAIL: int = 3
const HOLD_TIME: float = 1.25

const MOTE_RADIUS: float = 34.0
const MOTE_TICK: float = 0.30
## A share of the SHARD damage the loadout has actually built, not a damage
## number of its own - the trail is the orbit standing still, so every shard
## producer's contribution comes with it.
const MOTE_DAMAGE_SHARE: float = 0.85

var _motes: Array[Dictionary] = []
var _last_distance: float = 0.0
var _progress: float = 0.0
var _heading: Vector2 = Vector2.RIGHT
var _last_player_position: Vector2 = Vector2.ZERO
var _has_last_position: bool = false


func _on_manifestation_ready() -> void:
	if state != null and is_instance_valid(state):
		# Seed from the running odometer: coming online mid-sprint must not drop
		# a mote for metres the pair was not live through.
		_last_distance = state.distance_since_stop
	set_process(true)


func _exit_tree() -> void:
	# Held shards are the player's. Hand them back rather than confiscating them
	# because the pair went offline mid-stride.
	if _motes.is_empty():
		return
	var held: int = _motes.size()
	_motes.clear()
	if state != null and is_instance_valid(state):
		state.add_shard(held)


func drop_distance() -> float:
	return maxf(1.0, DROP_DISTANCE * threshold_scale())


func mote_damage_share() -> float:
	return MOTE_DAMAGE_SHARE * potency()


func _process(delta: float) -> void:
	if state == null or not is_instance_valid(state):
		return
	_track_heading()
	_tick_motes(delta)
	_drop_if_travelled()


## This node paints nothing of its own - the motes are separate world nodes - so
## it tracks the player in a field rather than dragging its own transform along
## behind one for no reason.
func _track_heading() -> void:
	if player == null or not is_instance_valid(player):
		return
	var here: Vector2 = player.global_position
	if _has_last_position:
		var step: Vector2 = here - _last_player_position
		if step.length_squared() > 1.0:
			_heading = step.normalized()
	_last_player_position = here
	_has_last_position = true


# ---------------------------------------------------------------------------
# Dropping
# ---------------------------------------------------------------------------

func _drop_if_travelled() -> void:
	var travelled: float = state.distance_since_stop
	# The state zeroes the odometer once the player has actually stopped;
	# rebase rather than reading that drop as a negative stride.
	if travelled < _last_distance:
		_last_distance = travelled
	if not state.is_moving or travelled <= _last_distance:
		return

	var stride: float = drop_distance()
	# Clamped so a lag spike or a teleport cannot bank several strides and then
	# dump the whole halo onto three points in three frames.
	_progress = minf(_progress + (travelled - _last_distance), stride * 2.0)
	_last_distance = travelled
	if _progress < stride:
		return

	if _motes.size() >= MAX_TRAIL:
		# Held AT the gate rather than spent: the next drop should follow as
		# soon as a slot frees, not a full stride after it.
		_progress = stride
		return
	_progress -= stride
	_drop_mote()


func _drop_mote() -> void:
	if state.shard_count() <= 0:
		return
	# The shard really leaves the orbit. That is the whole conversion: the halo
	# thins as you run and thickens when you stop.
	if state.take_shards(1) <= 0:
		return
	var at: Vector2 = player_position()
	_motes.append({"pos": at, "life": HOLD_TIME, "tick": 0.0})

	var vfx := MOTE_VFX.new() as Node2D
	if vfx == null:
		return
	vfx.call(&"setup", HOLD_TIME, MOTE_RADIUS, _heading, noun_colour(&"shard"))
	spawn_world_node(vfx, at)


# ---------------------------------------------------------------------------
# Holding, and snapping back
# ---------------------------------------------------------------------------

func _tick_motes(delta: float) -> void:
	if _motes.is_empty():
		return
	# One damage figure for the whole pass: shard_damage_mult() reads the shared
	# ledger and cannot change between two motes in the same frame.
	var damage: float = attack_damage(state.shard_damage_mult() * mote_damage_share())
	# Backwards, so removing an expired mote cannot skip the next one.
	for index in range(_motes.size() - 1, -1, -1):
		var mote: Dictionary = _motes[index]
		var tick: float = float(mote["tick"]) - delta
		if tick <= 0.0:
			tick = MOTE_TICK
			if damage > 0.0:
				var at: Vector2 = mote["pos"]
				damage_radius(at, MOTE_RADIUS, damage)
		mote["tick"] = tick

		var life: float = float(mote["life"]) - delta
		mote["life"] = life
		if life > 0.0:
			continue
		_motes.remove_at(index)
		# Snapped back. add_shard refuses at the cap, which can only happen if a
		# producer filled the orbit while this shard was on the ground - the same
		# rejection every shard producer in the layer already lives with.
		state.add_shard(1)


func describe() -> String:
	return (
		"While you are moving, every %.1f m pulls a shard out of your orbit and leaves it where you stood: it burns everything within %d px for %d%% of a shard's damage every %.2fs, then snaps back into orbit after %.2fs. Up to %d shards can be strung out at once."
		% [
			drop_distance() / PIXELS_PER_METRE,
			int(round(MOTE_RADIUS)),
			int(round(mote_damage_share() * 100.0)),
			MOTE_TICK,
			HOLD_TIME,
			MAX_TRAIL,
		]
	)
