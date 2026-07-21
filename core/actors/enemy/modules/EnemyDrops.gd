extends RefCounted
class_name EnemyDrops

const HEALTH_PICKUP_SCENE: PackedScene = preload("res://scenes/world/pickups/HealthPickup.tscn")

var _enemy: Enemy = null
var _pool: Array[String] = []

func setup(enemy: Enemy) -> void:
	_enemy = enemy

func build_drop_pool() -> void:
	_pool.clear()

	if _enemy == null:
		return

	var keys: Array = Global.item_db.keys()
	if keys.is_empty():
		return

	var prefixes: PackedStringArray = _enemy.drop_pool_prefixes

	# If no prefixes, allow everything.
	if prefixes.is_empty():
		for k in keys:
			_pool.append(str(k))
		return

	# Filter by prefixes.
	for k in keys:
		var ks: String = str(k)
		for pref in prefixes:
			if ks.begins_with(pref):
				_pool.append(ks)
				break

	# Fallback: allow everything if pool ended empty and fallback enabled.
	if _pool.is_empty() and _enemy.drop_fallback_to_all:
		for k in keys:
			_pool.append(str(k))


	# Debug: show pool composition after building (toggle with Enemy.debug_drops).
	if _enemy != null and _enemy.debug_drops:
		print("[DROP POOL] enemy=", _enemy.name,
			" prefixes=", _enemy.drop_pool_prefixes,
			" size=", _pool.size(),
			" fallback=", _enemy.drop_fallback_to_all
		)
		# Uncomment to print full pool (can be noisy):
		# print("[DROP POOL LIST] ", _pool)

func _pick_drop_id() -> String:
	if _pool.is_empty():
		build_drop_pool()
	if _pool.is_empty():
		return ""
	return _pool[Global._rng.randi_range(0, _pool.size() - 1)]


func try_drop_health_pickup() -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return

	var chance: float = clampf(_enemy.health_drop_chance, 0.0, 1.0)
	if chance <= 0.0 or Global._rng.randf() > chance:
		return

	var tree: SceneTree = _enemy.get_tree()
	if tree == null or tree.current_scene == null:
		return

	var pickup: HealthPickup = HEALTH_PICKUP_SCENE.instantiate() as HealthPickup
	if pickup == null:
		push_error("HealthPickup.tscn root is not HealthPickup")
		return

	var angle: float = Global._rng.randf() * TAU
	var distance: float = Global._rng.randf_range(8.0, maxf(8.0, _enemy.drop_spawn_radius))
	pickup.position = _enemy.global_position + Vector2.RIGHT.rotated(angle) * distance
	pickup.restore_fraction = clampf(_enemy.health_drop_restore_fraction, 0.01, 1.0)
	pickup.lifetime_seconds = maxf(1.0, _enemy.health_drop_lifetime)
	tree.current_scene.call_deferred("add_child", pickup)

func try_drop_item() -> void:
	if _enemy == null:
		return

	if _enemy.item_pickup_scene == null:
		push_warning("item_pickup_scene is null")
		return

	if Global.item_db.is_empty():
		push_warning("Global.item_db is EMPTY -> no items to drop")
		return

	var roll: float = Global._rng.randf()
	# Dynamic drop tuning:
	# - Early segment: fewer items (prevents full-set farming before the run even starts)
	# - Late segment + overtime: better drops (risk/reward)
	var eff_chance: float = _enemy.drop_chance
	var td_drop: Node = _enemy.get_node_or_null("/root/ThreatDirector")
	if td_drop != null:
		var r: float = clampf(float(td_drop.get("resonance")), 0.0, 1.0)
		var gate: bool = bool(td_drop.get("gate_unsealed"))
		var ot: float = float(td_drop.get("overtime")) if gate else 0.0
		var ramp: float = smoothstep(0.25, 0.85, r)
		var pre_mul: float = lerpf(0.20, 1.00, ramp)
		var ot_mul: float = (1.0 + minf(1.5, log(1.0 + ot) * 0.35)) if gate else 1.0
		eff_chance = _enemy.drop_chance * pre_mul * ot_mul
		eff_chance = clampf(eff_chance, 0.0, _enemy.drop_chance * 2.0)

	if _enemy.debug_drops:
		print("DROP ROLL:", snapped(roll, 0.01),
			" base=", _enemy.drop_chance, " eff=", eff_chance,
			" pool=", _pool.size(),
			" all=", Global.item_db.size()
		)

	if roll > eff_chance:
		return

	var pick_id: String = _pick_drop_id()
	if _enemy.debug_drops:
		print("[DROP PICK] enemy=", _enemy.name,
			" prefixes=", _enemy.drop_pool_prefixes,
			" pool_size=", _pool.size(),
			" pick_id=", pick_id
		)

	if pick_id == "":
		push_warning("Drop pool empty -> cannot drop")
		return

	var pickup: ItemPickup = _enemy.item_pickup_scene.instantiate() as ItemPickup
	if pickup == null:
		push_error("ItemPickup.tscn root is not ItemPickup (script/class_name missing?)")
		return

	var offset: Vector2 = Vector2.RIGHT.rotated(Global._rng.randf() * TAU) * _enemy.drop_spawn_radius
	pickup.global_position = _enemy.global_position + offset
	pickup.pickup_delay = _enemy.pickup_delay

	if _enemy.drop_instance_roll:
		var data: ItemData = Global.get_item_data(pick_id)
		if data == null:
			push_warning("Drop pick_id not found in DB: " + pick_id)
			return

		var elite_bonus: int = 0
		if _enemy.spec != null and _enemy.is_elite:
			elite_bonus = _enemy.spec.elite_rarity_bonus

		var td: Node = _enemy.get_node_or_null("/root/ThreatDirector")
		var loot_bonus: int = 0
		if td != null:
			loot_bonus = int(td.get("loot_rarity_bonus"))
		var rarity: int = Global._rng.randi_range(_enemy.drop_rarity_min, _enemy.drop_rarity_max) + elite_bonus + loot_bonus
		var roll_pct: float = Global.roll_percent(Global.run_luck, data.pct_min, data.pct_max)

		var pol: int = ItemInstance.Polarity.POS
		if _enemy.drop_force_polarity < 0:
			pol = ItemInstance.Polarity.NEG
		elif _enemy.drop_force_polarity > 0:
			pol = ItemInstance.Polarity.POS
		else:
			pol = (ItemInstance.Polarity.POS if roll_pct >= 0.0 else ItemInstance.Polarity.NEG)

		roll_pct = absf(roll_pct) * (1.0 if pol == ItemInstance.Polarity.POS else -1.0)

		var inst: ItemInstance = ItemInstance.from_roll(data, rarity, pol, roll_pct)
		pickup.item_instance = inst
		pickup.item_id = data.id
		pickup.amount = 1
	else:
		pickup.item_id = pick_id
		pickup.amount = Global._rng.randi_range(
			maxi(1, _enemy.drop_amount_min),
			maxi(1, _enemy.drop_amount_max)
		)

	_enemy.get_tree().current_scene.call_deferred("add_child", pickup)
