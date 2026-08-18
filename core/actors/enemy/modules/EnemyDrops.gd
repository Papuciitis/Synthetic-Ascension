extends RefCounted
class_name EnemyDrops

const HEALTH_PICKUP_SCENE: PackedScene = preload("res://scenes/world/pickups/HealthPickup.tscn")

var _enemy: EnemyActor = null
var _pool: Array[String] = []

# Cache built pools by prefix signature: the result is identical for every
# enemy of the same type, and this used to re-walk the item db on every spawn
# and every pool reuse. Cached arrays are shared read-only — never mutate _pool.
static var _pool_cache: Dictionary = {}

func setup(enemy: EnemyActor) -> void:
	_enemy = enemy

func build_drop_pool() -> void:
	_pool = []

	if _enemy == null:
		return

	var keys: Array = Global.item_db.keys()
	if keys.is_empty():
		return

	var prefixes: PackedStringArray = _enemy.drop_pool_prefixes
	var signature := "%s|%d|%d" % [",".join(prefixes), int(_enemy.drop_fallback_to_all), keys.size()]
	var cached: Variant = _pool_cache.get(signature)
	if cached is Array:
		_pool = cached
		_debug_print_pool()
		return

	var built: Array[String] = []

	if prefixes.is_empty():
		# If no prefixes, allow everything.
		for k in keys:
			built.append(str(k))
	else:
		# Filter by prefixes.
		for k in keys:
			var ks: String = str(k)
			for pref in prefixes:
				if ks.begins_with(pref):
					built.append(ks)
					break

		# Fallback: allow everything if pool ended empty and fallback enabled.
		if built.is_empty() and _enemy.drop_fallback_to_all:
			for k in keys:
				built.append(str(k))

	_pool_cache[signature] = built
	_pool = built
	_debug_print_pool()


func _debug_print_pool() -> void:
	# Debug: show pool composition after building (toggle with EnemyActor.debug_drops).
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
	if not roll_item_entitlement():
		return
	drop_entitled_item()


func roll_item_entitlement() -> bool:
	if not _can_drop_item():
		return false
	return _roll_item_drop()


func drop_entitled_item() -> void:
	if not _can_drop_item():
		return
	var instance_count: int = Global._rng.randi_range(
		mini(maxi(1, _enemy.drop_amount_min), maxi(1, _enemy.drop_amount_max)),
		maxi(maxi(1, _enemy.drop_amount_min), maxi(1, _enemy.drop_amount_max))
	)
	for _i in range(instance_count):
		_spawn_rolled_instance_pickup()


func finalize_rarity(rolled_base: int, elite_bonus: int, threat_bonus: int) -> int:
	return maxi(0, rolled_base + elite_bonus + threat_bonus)


func _can_drop_item() -> bool:
	if _enemy == null or not is_instance_valid(_enemy):
		return false
	if _enemy.item_pickup_scene == null:
		push_warning("item_pickup_scene is null")
		return false
	if Global.item_db.is_empty():
		push_warning("Global.item_db is EMPTY -> no items to drop")
		return false
	return true


func _roll_item_drop() -> bool:
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

	return roll <= eff_chance


func _spawn_rolled_instance_pickup() -> bool:
	var pick_id: String = _pick_drop_id()
	if pick_id == "":
		push_warning("Drop pool empty -> cannot drop")
		return false

	var data: ItemData = Global.get_item_data(pick_id)
	if data == null:
		push_warning("Drop pick_id not found in DB: " + pick_id)
		return false

	var pickup: ItemPickup = _new_pickup()
	if pickup == null:
		return false

	var td: Node = _enemy.get_node_or_null("/root/ThreatDirector")
	var loot_bonus: int = int(td.get("loot_rarity_bonus")) if td != null else 0
	var rarity_min: int = _enemy.drop_rarity_min + loot_bonus
	var rarity_max: int = _enemy.drop_rarity_max + loot_bonus
	if _enemy.spec != null and _enemy.is_elite:
		rarity_min += _enemy.spec.elite_rarity_bonus
		rarity_max += _enemy.spec.elite_rarity_bonus
	var context := Global.build_item_drop_context(
		rarity_min,
		rarity_max,
		&"enemy",
		1 if _enemy.is_elite else 0,
		_enemy.is_elite
	)
	var generated := ItemGenerator.create_instance(data, context, Global._rng)
	if generated == null:
		pickup.free()
		return false
	if _enemy.drop_force_polarity != 0:
		generated.polarity = (
			ItemInstance.Polarity.NEG
			if _enemy.drop_force_polarity < 0
			else ItemInstance.Polarity.POS
		)
		generated.best_pct = absf(generated.best_pct) * float(generated.polarity)
	pickup.item_instance = generated
	pickup.item_id = str(data.id)
	pickup.amount = 1
	_defer_pickup(pickup)
	return true


func _new_pickup() -> ItemPickup:
	var pickup: ItemPickup = _enemy.item_pickup_scene.instantiate() as ItemPickup
	if pickup == null:
		push_error("ItemPickup.tscn root is not ItemPickup (script/class_name missing?)")
		return null
	var angle: float = Global._rng.randf() * TAU
	var distance: float = Global._rng.randf_range(6.0, maxf(6.0, _enemy.drop_spawn_radius))
	pickup.global_position = _enemy.global_position + Vector2.RIGHT.rotated(angle) * distance
	pickup.pickup_delay = _enemy.pickup_delay
	return pickup


func _defer_pickup(pickup: ItemPickup) -> void:
	if pickup == null:
		return
	var tree: SceneTree = _enemy.get_tree()
	if tree == null or tree.current_scene == null:
		pickup.free()
		return
	tree.current_scene.call_deferred("add_child", pickup)
