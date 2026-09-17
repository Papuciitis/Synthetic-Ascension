extends Node

## Read-only economy diagnostic: uses production pricing, stock generation and
## both real death paths. Does not load a profile or change gameplay formulas.
## Run its companion scene headlessly. AUDIT_JSON contains the measurements.

const ShopScript = preload("res://ui/screens/HubShop.gd")
const EnemyScene = preload("res://core/actors/enemy/enemy.tscn")
const SAMPLES_PER_SEGMENT := 100

var _report: Dictionary = {}


func _ready() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	PerformanceFlightRecorder.enabled = false
	call_deferred("_run")


func _distribution(values: Array[int]) -> Dictionary:
	values.sort()
	return {
		"count": values.size(),
		"min": values[0],
		"median": values[values.size() / 2],
		"p90": values[int(values.size() * 0.90)],
		"max": values[-1],
	}


func _run() -> void:
	Global.run_luck = 0.0
	Global.permanent_augment_ids.clear()
	Global.run_inventory = Inventory.new()
	Global.attempt_world_seed = 20260913
	Global.attempt_segment = 2
	ThreatDirector.set_process(false)
	ThreatDirector.gate_unsealed = false
	_report["conditions"] = {
		"seed": Global.attempt_world_seed,
		"luck": Global.run_luck,
		"stock_samples_per_segment": SAMPLES_PER_SEGMENT,
		"equipped_items": 0,
		"note": "Synthetic price/reward fixtures, not a timed gameplay or income sample.",
	}
	var shop := ShopScript.new()
	var bag := BagInventory.new()
	bag.auto_consolidate = false
	bag.slots.resize(16)
	shop.set("_vendor_bag", bag)
	var markets: Array[Dictionary] = []
	for segment in [2, 3, 5, 10, 20, 40]:
		Global.attempt_segment = segment
		Global.attempt_vendor_seed = 0
		shop.set("_vendor_seed", 0)
		var buys: Array[int] = []
		var sells: Array[int] = []
		var stock_totals: Array[int] = []
		for sample in range(SAMPLES_PER_SEGMENT):
			shop.call("_generate_vendor_stock", sample > 0)
			var total := 0
			for item: ItemInstance in bag.slots:
				if item == null:
					continue
				var buy := Global.compute_buy_value(item)
				buys.append(buy)
				sells.append(Global.compute_sell_value(item))
				total += buy
			stock_totals.append(total)
		markets.append({
			"hub_next_segment": segment,
			"buy": _distribution(buys),
			"sell": _distribution(sells),
			"whole_stock": _distribution(stock_totals),
		})
	_report["markets"] = markets
	var refreshes: Array[int] = []
	for index in range(15):
		Global.attempt_vendor_refreshes = index
		refreshes.append(int(shop.call("_get_refresh_cost")))
	_report["refresh_prices"] = refreshes
	shop.free()

	Global.attempt_segment = 2
	Global.attempt_deaths_this_segment = 0
	var wallets: Array[Dictionary] = []
	for followers in [12, 100, 225, 4000, 1000000, 1000000000]:
		Global.set_followers(followers)
		wallets.append({
			"followers": followers,
			"belief_power": Global.follower_belief_power(),
			"reconstruction_cost": Global.compute_respawn_cost(),
		})
	_report["wallets_segment_2"] = wallets

	var rewards: Array[Dictionary] = []
	for overtime in [false, true]:
		ThreatDirector.gate_unsealed = overtime
		ThreatDirector.overtime = 1000000.0 if overtime else 0.0
		ThreatDirector.belief_defiance = 0.0
		for reward in [0, 1, 2, 3, 5]:
			Global._rng.seed = 99
			var materialized := _materialized_reward(reward)
			Global._rng.seed = 99
			var proxy := _proxy_reward(reward)
			rewards.append({
				"base_reward": reward,
				"overtime_multiplier": ThreatDirector.overtime_reward_multiplier(),
				"materialized_reward": materialized,
				"proxy_reward": proxy,
			})
	_report["death_path_rewards"] = rewards

	Global.attempt_segment = 2
	Global.attempt_deaths_this_segment = 0
	Global.set_followers(12)
	_report["exact_reconstruction_reserve"] = {
		"before": Global.followers,
		"quoted_cost": Global.compute_respawn_cost(),
	}
	Global.consume_respawn_cost()
	_report["exact_reconstruction_reserve"]["after"] = Global.followers
	_report["exact_reconstruction_reserve"]["player_die_would_respawn"] = Global.followers > 0

	Global.set_followers(1000000000)
	Global.attempt_active = true
	var save := SaveData.new()
	Global.write_save(save)
	_report["billion_save_snapshot"] = save.attempt_followers
	_report["doctrine_stage_at_12"] = String(Global.doctrine_stage_for_completed_segment(12))
	print("AUDIT_JSON=" + JSON.stringify(_report))
	await get_tree().process_frame
	get_tree().quit()


func _materialized_reward(reward: int) -> int:
	var enemy := EnemyScene.instantiate() as EnemyActor
	var spec := EnemySpec.new()
	spec.id = &"economy_audit_fixture"
	spec.follower_reward_min = reward
	spec.follower_reward_max = reward
	spec.elite_follower_bonus = 0
	spec.drop_chance = 0.0
	spec.item_pickup_scene = preload("res://scenes/world/pickups/ItemPickup.tscn")
	enemy.spec = spec
	enemy.drop_chance = 0.0
	enemy.health_drop_chance = 0.0
	add_child(enemy)
	var before := Global.followers
	enemy.take_damage(1000000.0, null)
	return Global.followers - before


func _proxy_reward(reward: int) -> int:
	var state := EnemySpawnState.new(
		&"economy_audit_fixture", "", Vector2.ZERO, 5.0, 0.0, 10.0, 0, 0,
		{"follower_reward_min": reward, "follower_reward_max": reward, "elite_follower_bonus": 0}
	)
	var handle := EnemyWorld.create_enemy(state)
	var before := Global.followers
	EnemyCombat.apply_damage(handle, 1000000.0, 1, null)
	return Global.followers - before
