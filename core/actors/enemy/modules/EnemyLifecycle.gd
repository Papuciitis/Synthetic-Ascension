extends RefCounted
class_name EnemyLifecycle

var _owner: EnemyActor = null
var _drops: EnemyDrops = null
var _bomber: EnemyBomber = null
var _splitter: EnemySplitter = null

var _last_hurt_sfx_ms: int = 0
const HURT_SFX_COOLDOWN_MS: int = 120

func setup(owner: EnemyActor, drops: EnemyDrops, bomber: EnemyBomber, splitter: EnemySplitter) -> void:
	_owner = owner
	_drops = drops
	_bomber = bomber
	_splitter = splitter

func take_damage(amount: float, source: Node = null) -> void:
	if _owner != null and is_instance_valid(_owner):
		_owner.take_damage(amount, source)

func apply_hit_ledger(ledger: HitLedger) -> void:
	if _owner != null and is_instance_valid(_owner):
		_owner.apply_hit_ledger(ledger)

func apply_damage_feedback(applied_damage: float, _source: Node, _payload: Variant) -> void:
	if _owner == null or not is_instance_valid(_owner) or _owner.dead:
		return

	# Hurt SFX (rate-limited so a single enemy doesn't spam).
	var now := Time.get_ticks_msec()
	if now - _last_hurt_sfx_ms >= HURT_SFX_COOLDOWN_MS and _owner.is_inside_tree() and applied_damage >= 0.5:
		_last_hurt_sfx_ms = now
		if SfxManager != null:
			SfxManager.play_2d(&"enemy_hurt", _owner.global_position)


func resolve_death(context: RefCounted) -> void:
	if _owner == null or not is_instance_valid(_owner) or _owner.dead:
		return
	var source: Node = context.get("source") as Node if context != null else null

	_owner.dead = true
	# Release population budgets immediately; queue_free unregisters later and
	# EnemyIndex guards against double-decrementing the counters.
	if _owner.has_method("_notify_enemy_index_dead"):
		_owner.call("_notify_enemy_index_dead")

	var explode_on_death: bool = _owner.spec != null and _owner.spec.ai == EnemySpec.AI.BOMBER and _owner.spec.explode_on_death
	var is_splitter: bool = _owner.spec != null and _owner.spec.ai == EnemySpec.AI.SPLITTER

	# Splitter loot belongs to the family, not every spawned body. The original
	# rolls once; when successful, exactly one immediate child inherits the item.
	# Descendants without that entitlement never perform independent item rolls.
	var split_generation: int = maxi(0, int(_owner.get_meta("split_generation", 0))) if is_splitter else 0
	var inherited_split_item: bool = is_splitter and bool(_owner.get_meta("split_item_entitled", false))
	var root_split_item: bool = is_splitter and split_generation == 0 and _drops != null and _drops.roll_item_entitlement()
	var split_children: Array[EnemyActor] = []
	if is_splitter and _splitter != null:
		split_children = _splitter.spawn_splitters(_owner.is_elite)
	elif _splitter != null and _owner.has_elite_modifier(EliteModifiers.SPLITTING):
		# Roadmap §9 SPLITTING on a non-splitting archetype. The elite's own
		# loot and reward roll below as for any elite; the copies carry none.
		var copies := _splitter.spawn_modifier_split(EliteModifiers.SPLIT_COUNT)
		if not copies.is_empty() and PerformanceFlightRecorder != null and bool(PerformanceFlightRecorder.get("enabled")):
			PerformanceFlightRecorder.record_counter_event(&"enemy", &"elite_split_spawned", copies.size(), {
				"enemy_id": String(_owner.spec.id) if _owner.spec != null else "",
			})

	if root_split_item:
		if split_children.is_empty():
			_drops.drop_entitled_item()
		else:
			var heir_index: int = Global._rng.randi_range(0, split_children.size() - 1)
			split_children[heir_index].set_meta("split_item_entitled", true)
			# Rarity context must reflect the parent that QUALIFIED for the
			# drop, not whichever small heir eventually dies holding it.
			split_children[heir_index].set_meta("split_item_entitled_elite", _owner.is_elite)
	elif inherited_split_item and _drops != null:
		_drops.drop_entitled_item()

	# kill event
	var p: Node = source
	if p == null:
		p = _owner.get_tree().get_first_node_in_group("player")

	RunEvents.enemy_killed.emit(p, _owner, _owner.global_position)

	# followers reward
	var gain: int = 1
	if _owner.spec != null:
		gain = Global._rng.randi_range(_owner.spec.follower_reward_min, _owner.spec.follower_reward_max)
		if _owner.is_elite:
			gain += _owner.spec.elite_follower_bonus
	# Luck: witnesses of a lucky kill are extra impressed (mirrors the
	# proxy-death path in EnemyCombatService).
	if gain > 0 and Global._rng.randf() < LuckResolver.extra_follower_chance(Global.run_luck):
		gain += 1
	# Cult of Personality: violence as recruitment seminar.
	if gain > 0 and Global.permanent_augment_ids.has(&"augment_cult_of_personality"):
		var cult_level: int = Global.get_augment_level(&"augment_cult_of_personality")
		var cult_chance: float = 0.10 + 0.05 * float(cult_level - 1) + LuckResolver.extra_follower_chance(Global.run_luck)
		if Global._rng.randf() < cult_chance:
			gain += 1

	# Belief earned during Overtime is worth less the longer you refuse to
	# leave. See ThreatDirector.overtime_reward_multiplier().
	var threat_director: Node = null
	if _owner != null and is_instance_valid(_owner) and _owner.is_inside_tree():
		threat_director = _owner.get_node_or_null("/root/ThreatDirector")
	if threat_director != null and threat_director.has_method("overtime_reward_multiplier"):
		gain = maxi(1, int(round(float(gain) * float(threat_director.call("overtime_reward_multiplier")))))
	Global.transaction_followers(gain, &"combat_influence", {"enemy_id": String(_owner.spec.id) if _owner.spec != null else ""}, true, true)

	# Health pickups keep their existing per-body behavior. Item loot for a
	# Splitter family was already resolved above and must not roll again here.
	if _drops != null:
		_drops.try_drop_health_pickup()
		if not is_splitter:
			_drops.try_drop_item()

	# Bomber destruction is only the visual/damage implementation. Kill events,
	# Followers and drops above are resolved first and exactly once.
	if explode_on_death and _bomber != null:
		_bomber.explode_now()
	else:
		_owner.despawn(&"death")
