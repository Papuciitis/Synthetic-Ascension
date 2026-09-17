extends ManifestationEffect

## Predestination Sigil - mark.
##
## The first hit on an elite Marks it. The Mark takes enormous extra damage,
## everything else takes less, and killing the Mark detonates it. The global
## penalty is the point of the rule: it turns "shoot the nearest thing" into
## "go find the elite", and it is why this is a choice rather than a stat.

const MARK_BASE_DURATION: float = 12.0
## Bonus damage on the Mark, as a fraction of the hit that landed - so it
## scales with the player's own build instead of inventing a damage source.
const BONUS_PER_POTENCY: float = 1.25
const OFF_MARK_POWER: float = 0.88

const DETONATE_BASE_RADIUS: float = 170.0
const DETONATE_PER_POTENCY: float = 3.5
const DETONATE_KNOCKBACK: float = 260.0

const SHARD_RELEASE_MULT: float = 2.0
const SHARD_BURST_RADIUS: float = 78.0

## RunEvents.player_hit_landed is emitted from INSIDE
## EnemyCombatService.apply_damage, so every bonus hit this rule applies calls
## on_hit() again. The latch that stops the recursion lives on the shared
## state (see on_hit) so it covers all equipped copies, not just this one.
##
## The Mark's world marker is NOT owned here - the state owns it, because the
## Mark outlives any single copy of this rule.


func mark_duration() -> float:
	# threshold_scale() eases requirements; here the eased requirement is how
	# long you have to reach the elite you just tagged.
	return MARK_BASE_DURATION / maxf(threshold_scale(), 0.5)


func bonus_fraction() -> float:
	return BONUS_PER_POTENCY * potency()


func detonate_multiplier() -> float:
	return DETONATE_PER_POTENCY * potency()


func detonate_radius() -> float:
	return DETONATE_BASE_RADIUS * (0.85 + 0.30 * potency())


func get_power_multiplier() -> float:
	if state == null or not is_instance_valid(state) or state.mark_time_left <= 0.0:
		return 1.0
	return OFF_MARK_POWER


func on_hit(handle: int, at: Vector2, amount: float, _is_crit: bool, is_elite: bool) -> void:
	if state == null or not is_instance_valid(state):
		return
	# The latch lives on the shared state, not on this node: this rule can roll
	# on Power, Haste and Ring at once, and a per-instance flag only stops a
	# copy re-entering ITSELF. Two copies would then cross-trigger through
	# player_hit_landed and each pay out its bonus on the other's bonus hit.
	if state.is_exclusive_held(&"sigil_bonus"):
		return

	var mark_live: bool = state.mark_time_left > 0.0
	if mark_live and handle == state.marked_handle:
		var bonus: float = amount * bonus_fraction()
		if bonus > 0.0 and EnemyCombat != null and state.begin_exclusive(&"sigil_bonus"):
			# The bonus can kill the Mark, which runs on_kill (and its
			# detonation) inside this call, so the latch has to survive it.
			EnemyCombat.apply_damage(handle, bonus, 1, player)
			state.end_exclusive(&"sigil_bonus")
		return

	if not is_elite or mark_live:
		return
	_place_mark(handle, at)


func on_kill(context: EnemyDeathContext) -> void:
	if context == null or state == null or not is_instance_valid(state):
		return
	if state.mark_time_left <= 0.0 or context.handle != state.marked_handle:
		return

	var at: Vector2 = context.position
	var radius: float = detonate_radius()
	# Cleared before the blast: the detonation kills more enemies and every one
	# of those re-enters this hook.
	# Detonating clears the Mark first, so the enemies this blast kills cannot
	# re-enter on_kill against a Mark that still looks live.
	state.detonate_mark(at, radius)

	# The clear above already rejects every re-entrant on_kill, so this is
	# belt-and-braces against a second copy detonating the same death.
	var held: bool = state.begin_exclusive(&"sigil_bonus")
	damage_radius(at, radius, attack_damage(detonate_multiplier()), DETONATE_KNOCKBACK)
	var spent: int = _spend_shards(at, radius)
	if held:
		state.end_exclusive(&"sigil_bonus")

	var text: String = "PREDESTINED" if spent <= 0 else ("PREDESTINED +%d" % spent)
	popup(text, Color(1.0, 0.80, 0.30, 1.0), 1.45)


func describe() -> String:
	return (
		"Your first hit on an elite Marks it for %.0fs: +%d%% damage to the Mark, -%d%% to everything else. Killing the Mark detonates it for x%.1f weapon damage in a %dpx radius, spending any orbiting shards."
		% [
			mark_duration(),
			int(round(bonus_fraction() * 100.0)),
			int(round((1.0 - OFF_MARK_POWER) * 100.0)),
			detonate_multiplier(),
			int(round(detonate_radius())),
		]
	)


func _place_mark(handle: int, _at: Vector2) -> void:
	var duration: float = mark_duration()
	# set_mark() is a no-op if nothing claims the resource, and it owns the
	# marker visual, so there is nothing for this rule to draw or adopt.
	state.set_mark(handle, duration)
	if state.marked_handle != handle:
		return
	popup("MARKED", Color(0.86, 0.52, 1.0, 1.0), 1.25)


## Deliberate cross-family hook: an orbit built by an unrelated shard rule is
## spent by this detonation. Nothing requires it - a run with no shard producer
## simply takes this branch as a no-op.
func _spend_shards(at: Vector2, radius: float) -> int:
	if state.shard_count() <= 0:
		return 0
	var count: int = state.take_shards()
	if count <= 0:
		return 0
	var damage: float = attack_damage(state.shard_damage_mult() * SHARD_RELEASE_MULT * potency())
	var ring: float = radius * 0.72
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		damage_radius(at + Vector2(cos(angle), sin(angle)) * ring, SHARD_BURST_RADIUS, damage, 140.0)
	return count
