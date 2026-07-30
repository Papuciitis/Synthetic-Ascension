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
	_apply_damage(amount, 1, source)

func apply_hit_ledger(ledger: HitLedger) -> void:
	if ledger == null:
		return
	_apply_damage(ledger.total_raw_damage, maxi(1, ledger.hit_count), ledger.source)
	if _owner == null or not is_instance_valid(_owner) or _owner.dead:
		return
	var combined_knockback := ledger.clamped_knockback()
	if combined_knockback != Vector2.ZERO:
		_owner.apply_knockback(combined_knockback)
	if ledger.burn_stacks > 0 and ledger.burn_duration > 0.0 and ledger.burn_damage_per_tick_per_stack > 0.0:
		var dot := _owner.get_node_or_null("BurnDot") as BurnDot
		if dot == null:
			dot = BurnDot.new()
			dot.name = "BurnDot"
			_owner.add_child(dot)
		dot.setup(_owner, ledger.source, ledger.burn_stacks, ledger.burn_duration, ledger.burn_tick, ledger.burn_damage_per_tick_per_stack)

func _apply_damage(amount: float, hit_count: int, source: Node = null) -> void:
	if _owner == null:
		return
	if _owner.dead:
		return

	var dmg := amount
	# Boss tuning hooks (set by arenas via metadata):
	# - damage_taken_mul: float (e.g. 0.55)
	# - hit_cap_ratio: float (e.g. 0.08 means max 8% of max_hp per hit)
	if _owner.has_meta("damage_taken_mul"):
		dmg *= float(_owner.get_meta("damage_taken_mul"))
	if _owner.has_meta("hit_cap_ratio"):
		var cap := float(_owner.max_hp) * float(_owner.get_meta("hit_cap_ratio"))
		if cap > 0.0:
			# A batch is several already-resolved hits, so boss per-hit caps scale by
			# hit_count instead of collapsing the entire frame into one capped hit.
			dmg = min(dmg, cap * float(maxi(1, hit_count)))

	_owner.hp -= dmg

	if source != null:
		RunEvents.damage_dealt.emit(source, dmg)

	if _owner.hp > 0.0:
		# Hurt SFX (rate-limited so a single enemy doesn't spam)
		var now := Time.get_ticks_msec()
		if now - _last_hurt_sfx_ms >= HURT_SFX_COOLDOWN_MS and _owner.is_inside_tree() and dmg >= 0.5:
			_last_hurt_sfx_ms = now
			if SfxManager != null:
				SfxManager.play_2d(&"enemy_hurt", _owner.global_position)
		return

	_die(source)

func _die(source: Node) -> void:
	if _owner == null:
		return

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

	if root_split_item:
		if split_children.is_empty():
			_drops.drop_entitled_item()
		else:
			var heir_index: int = Global._rng.randi_range(0, split_children.size() - 1)
			split_children[heir_index].set_meta("split_item_entitled", true)
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
		_owner.queue_free()
