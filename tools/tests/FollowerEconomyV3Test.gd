extends Node

# The follower economy pass (follower economy audit 2026-10-04): one
# kill-reward settlement for both death paths, where an authored zero pays 0
# and Overtime settles as a fraction with a carry (P1); the stage price scale
# on vendor buys and restocks (P2/P3) and on the per-visit services (P4); the
# Congregation behind belief's cap, the Hub crowd and the save (P5); the one
# reserve rule the tithes obey (P7); V5 rank downgrades at the refund share
# (P9); and the recorder's per-segment economy (P10).
#
# No save slot is touched: SaveManager.current_save stays null and the round
# trips use in-memory SaveData.
#
# Run: <godot> --headless --path . res://tools/tests/FollowerEconomyV3Test.tscn

const EnemyScene := preload("res://core/actors/enemy/enemy.tscn")
const PickupScene := preload("res://scenes/world/pickups/ItemPickup.tscn")
const ShopScript := preload("res://ui/screens/HubShop.gd")
const HUB_WORLD := preload("res://scenes/hub/HubWorld.tscn")
const Ledger := preload("res://core/systems/telemetry/BalanceLedger.gd")
const RecorderScript := preload("res://autoload/BalanceRecorder.gd")
const FurnaceScript := preload("res://effects/manifestations/logic/TitheFurnace.gd")
const CENSUS_PATH := "res://data/major_choices/doctrines/method_census_of_souls.tres"

var _passes := 0
var _failures := 0


func _ready() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	PerformanceFlightRecorder.enabled = false
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _near(a: float, b: float, eps: float = 0.0001) -> bool:
	return absf(a - b) <= eps


func _run() -> void:
	ThreatDirector.set_process(false)
	_fresh_attempt()
	await _test_settlement()
	_test_market_scale()
	_test_services()
	await _test_congregation()
	_test_reserve_floor()
	_test_rank_downgrades()
	_test_recorder()
	print("FollowerEconomyV3Test: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _fresh_attempt(segment: int = 2) -> void:
	Global.start_new_attempt()
	SaveManager.current_save = null
	Global.attempt_segment = segment
	Global.attempt_deaths_this_segment = 0
	Global.run_luck = 0.0
	var empty: Array[StringName] = [StringName(), StringName(), StringName()]
	Global.permanent_augment_ids = empty
	Global.attempt_augment_transcended = {}
	Global.attempt_doctrine_rules = {}
	ThreatDirector.gate_unsealed = false
	ThreatDirector.overtime = 0.0
	ThreatDirector.belief_defiance = 0.0
	Global._kill_reward_carry = 0.0


# ---------------------------------------------------------------- P1

func _actor_kill(reward_min: int, reward_max: int, elite: bool = false, elite_bonus: int = 0) -> int:
	var enemy := EnemyScene.instantiate() as EnemyActor
	var spec := EnemySpec.new()
	spec.id = &"economy_v3_fixture"
	spec.follower_reward_min = reward_min
	spec.follower_reward_max = reward_max
	spec.elite_follower_bonus = elite_bonus
	spec.drop_chance = 0.0
	spec.item_pickup_scene = PickupScene
	enemy.spec = spec
	enemy.drop_chance = 0.0
	enemy.health_drop_chance = 0.0
	add_child(enemy)
	enemy.is_elite = elite
	var before := Global.followers
	enemy.take_damage(1000000.0, null)
	return Global.followers - before


func _proxy_kill(reward_min: int, reward_max: int, elite: bool = false, elite_bonus: int = 0) -> int:
	var state := EnemySpawnState.new(
		&"economy_v3_fixture", "", Vector2.ZERO, 5.0, 0.0, 10.0, 0,
		EnemyWorldTypes.Flags.ELITE if elite else 0,
		{"follower_reward_min": reward_min, "follower_reward_max": reward_max, "elite_follower_bonus": elite_bonus}
	)
	var handle := EnemyWorld.create_enemy(state)
	var before := Global.followers
	EnemyCombat.apply_damage(handle, 1000000.0, 1, null)
	return Global.followers - before


func _kills(path: String, count: int, reward: int) -> int:
	var total := 0
	for i in range(count):
		total += _actor_kill(reward, reward) if path == "actor" else _proxy_kill(reward, reward)
	return total


func _test_settlement() -> void:
	_fresh_attempt()
	Global.set_followers(1000)
	_check(_near(ThreatDirector.overtime_reward_multiplier(), 1.0), "fixture: the gate is sealed, Overtime pays in full")

	# An authored zero pays nothing on either path, whatever would ride on it.
	Global.run_luck = 1000000.0
	Global.set_doctrine_rule(&"kill_follower_chance", 1.0)
	var actor_zero := 0
	var proxy_zero := 0
	for i in range(20):
		actor_zero += _actor_kill(0, 0)
		proxy_zero += _proxy_kill(0, 0)
	actor_zero += _actor_kill(0, 0, true, 3)
	proxy_zero += _proxy_kill(0, 0, true, 3)
	_check(actor_zero == 0, "an actor authored at 0 pays 0 Followers, with Luck and Census maxed and as an elite (%d)" % actor_zero)
	_check(proxy_zero == 0, "a data-only proxy authored at 0 pays 0 Followers too (%d)" % proxy_zero)
	_check(Global.settle_kill_reward(0, 0, 3, true, 1.0) == 0, "the settlement itself pays 0 for an authored zero")
	Global.run_luck = 0.0
	Global.attempt_doctrine_rules = {}

	# Outside Overtime a reward settles whole and identically on both paths.
	_check(_kills("actor", 10, 3) == 30 and _kills("proxy", 10, 3) == 30, "a 3-Follower body pays exactly 3 on both paths at x1.0")

	# Overtime at its floor: fractions with a carry, no floor of one.
	ThreatDirector.gate_unsealed = true
	ThreatDirector.overtime = 1000000.0
	ThreatDirector.belief_defiance = 0.0
	var floor_mul := ThreatDirector.overtime_reward_multiplier()
	_check(_near(floor_mul, 0.35), "fixture: deep Overtime decays rewards to x0.35 (%.3f)" % floor_mul)
	Global._kill_reward_carry = 0.0
	var actor_paid := _kills("actor", 100, 1)
	_check(absi(actor_paid - 35) <= 1, "base 1 at x0.35 pays 35 +/- 1 over 100 actor kills (%d; was 100)" % actor_paid)
	Global._kill_reward_carry = 0.0
	var proxy_paid := _kills("proxy", 100, 1)
	_check(absi(proxy_paid - 35) <= 1, "and 35 +/- 1 over 100 proxy kills (%d; was 100)" % proxy_paid)
	Global._kill_reward_carry = 0.0
	var mixed := _kills("actor", 50, 1) + _kills("proxy", 50, 1)
	_check(absi(mixed - 35) <= 1, "the carry is shared: 50 actor + 50 proxy kills pay 35 +/- 1 (%d)" % mixed)
	Global._kill_reward_carry = 0.0
	var big := _kills("proxy", 20, 5)
	_check(absi(big - 35) <= 1, "a 5-Follower body pays 1.75 a kill, 35 +/- 1 over 20 (%d; the old round paid 40)" % big)

	# Overtime Gospel's full defiance refuses the toll: x1.0 again.
	ThreatDirector.belief_defiance = 1.0
	_check(_kills("actor", 20, 1) == 20 and _kills("proxy", 20, 1) == 20, "Overtime Gospel at full defiance keeps every kill whole")
	ThreatDirector.belief_defiance = 0.0

	# Kill income is recruitment: the Congregation grows with the wallet.
	var congregation_before := Global.attempt_congregation
	var wallet_before := Global.followers
	_kills("proxy", 10, 2)
	_check(Global.attempt_congregation - congregation_before == Global.followers - wallet_before and Global.followers > wallet_before, "kill rewards raise the Congregation by what they pay")

	# A segment boundary drops Overtime's unpaid fraction with the segment.
	Global._kill_reward_carry = 0.6
	Global.on_segment_completed(2)
	SaveManager.current_save = null
	_check(_near(Global._kill_reward_carry, 0.0), "the carry resets when a segment completes")
	ThreatDirector.gate_unsealed = false
	ThreatDirector.overtime = 0.0
	await get_tree().process_frame


# ---------------------------------------------------------------- P2 / P3

func _sample_items() -> Array:
	var out: Array = []
	var ids: Array = []
	for id in Global.item_db:
		if String(id) != "item_test":
			ids.append(String(id))
	ids.sort()
	var step := maxi(1, int(float(ids.size()) / 12.0))
	for i in range(0, ids.size(), step):
		var data: ItemData = Global.item_db[ids[i]]
		for rank in [0, 3, 8]:
			var roll := data.pct_min if data.pct_min < 0.0 else data.pct_max
			var polarity := ItemInstance.Polarity.NEG if roll < 0.0 else ItemInstance.Polarity.POS
			out.append(ItemInstance.from_roll(data, rank, polarity, roll, false))
	return out


func _test_market_scale() -> void:
	_fresh_attempt()
	var scales := [Global.market_scale(1), Global.market_scale(2), Global.market_scale(3), Global.market_scale(4), Global.market_scale(10), Global.market_scale(20)]
	_check(_near(scales[0], 1.0) and _near(scales[1], 1.0) and _near(scales[2], 1.25) and _near(scales[3], 1.5) and _near(scales[4], 3.0) and _near(scales[5], 5.5), "the stage scale: x1.0 through Hub 1, +25%% a segment after (%s)" % str(scales))
	Global.attempt_segment = 10
	_check(_near(Global.market_scale(), 3.0), "and it reads attempt_segment by default")

	var items := _sample_items()
	_check(items.size() >= 12, "fixture: a spread of real items (%d)" % items.size())
	var hub_one_same := true
	var deep_scaled := true
	var sell_unscaled := true
	var buyback_loses := true
	for luck in [0.0, 100.0]:
		Global.run_luck = luck
		for inst in items:
			var value := Global.compute_item_value(inst)
			var buy_mul := LuckResolver.buy_multiplier(luck)
			Global.attempt_segment = 2
			var buy_hub1 := Global.compute_buy_value(inst)
			var sell_hub1 := Global.compute_sell_value(inst)
			Global.attempt_segment = 10
			var buy_deep := Global.compute_buy_value(inst)
			var sell_deep := Global.compute_sell_value(inst)
			hub_one_same = hub_one_same and buy_hub1 == maxi(0, int(ceil(float(value) * buy_mul)))
			deep_scaled = deep_scaled and buy_deep == maxi(0, int(ceil(float(value) * buy_mul * 3.0)))
			sell_unscaled = sell_unscaled and sell_hub1 == sell_deep
			buyback_loses = buyback_loses and (value <= 0 or (sell_hub1 < buy_hub1 and sell_deep < buy_deep))
	Global.run_luck = 0.0
	_check(hub_one_same, "vendor buy prices at Hub 1 are exactly today's")
	_check(deep_scaled, "at Hub 9 they are x3.0")
	_check(sell_unscaled, "sell prices never move with the stage")
	_check(buyback_loses, "selling and buying back still always loses, at Hub 1 and Hub 9, with and without Luck")

	var shop := ShopScript.new()
	Global.attempt_segment = 2
	var hub_one: Array = []
	for n in range(12):
		Global.attempt_vendor_refreshes = n
		hub_one.append(int(shop.call("_get_refresh_cost")))
	_check(hub_one == [3, 5, 9, 16, 28, 49, 86, 151, 264, 462, 808, 1414], "Hub 1 restocks keep 3 x 1.75^n and lose the 999 cap (%s)" % str(hub_one))
	var first_eight := 0
	for n in range(8):
		first_eight += hub_one[n]
	_check(first_eight == 347, "eight Hub 1 restocks still cost 347 (%d)" % first_eight)
	Global.attempt_segment = 10
	var deep: Array = []
	for n in range(3):
		Global.attempt_vendor_refreshes = n
		deep.append(int(shop.call("_get_refresh_cost")))
	Global.attempt_vendor_refreshes = 11
	var deep_eleventh := int(shop.call("_get_refresh_cost"))
	_check(deep == [9, 16, 28] and deep_eleventh == int(round(3.0 * pow(1.75, 11.0) * 3.0)), "Hub 9 restocks ride the same x3.0 (%s, then %d)" % [str(deep), deep_eleventh])
	Global.attempt_vendor_refreshes = 200
	_check(int(shop.call("_get_refresh_cost")) > 1000000000, "a dev-sized refresh count prices huge, never wraps to the floor")
	Global.attempt_vendor_refreshes = 0
	shop.free()


# ---------------------------------------------------------------- P4

func _test_services() -> void:
	_fresh_attempt()
	var items := _sample_items()
	var inst: ItemInstance = items[items.size() - 1]
	var value := Global.compute_item_value(inst)
	Global.attempt_segment = 2
	var imprint_hub1 := ImprintService.price(inst)
	Global.attempt_segment = 10
	var imprint_deep := ImprintService.price(inst)
	_check(imprint_hub1 == maxi(20, int(round(float(value) * 0.25))), "an imprint at Hub 1 costs today's quarter of the value (%d)" % imprint_hub1)
	_check(imprint_deep == maxi(20, int(round(float(value) * 0.25 * 3.0))), "and x3.0 at Hub 9 (%d)" % imprint_deep)

	_check(AugmentRites.transfusion_cost_per_level(1) == 40 and AugmentRites.transfusion_cost_per_level(2) == 40, "Transfusion keeps 40 a level through the second Binding")
	_check(AugmentRites.transfusion_cost_per_level(3) == 60 and AugmentRites.transfusion_cost_per_level(10) == 200, "then 20 x the Binding's segment (60 at Hub 3, 200 at Hub 10)")
	var augs: Array[StringName] = [&"augment_tesla_aura", StringName(), StringName()]
	Global.permanent_augment_ids = augs
	Global.init_owned_augments()
	if not Global.owned_augment_ids.has(&"augment_lucky_charm"):
		Global.owned_augment_ids.append(&"augment_lucky_charm")
	Global.attempt_augment_levels = {"augment_tesla_aura": 3, "augment_lucky_charm": 5}
	Global.attempt_augment_corruptions = {}
	Global.set_followers(10000)
	Global.attempt_segment = 11
	var preview := Global.transfusion_preview(&"augment_tesla_aura", &"augment_lucky_charm")
	_check(bool(preview["ok"]) and int(preview["gain"]) == 2 and int(preview["cost"]) == 400 and int(preview["per_level"]) == 200, "the Reliquary quotes 2 levels at Hub 10 for 400, 200 a level (%s)" % str(preview))

	_check(Vouchers.price(1) == 300 and Vouchers.price(2) == 400 and Vouchers.price(5) == 700 and Vouchers.price(10) == 1200, "Vouchers: 300 at Hub 1 as before, then +100 a segment")
	Global.attempt_segment = 2
	_check(Global.voucher_price() == 300, "the first Hub's Voucher price is today's 300")

	var stakes_hub1: Array = []
	var stakes_deep: Array = []
	for tier in range(WagerShrineObjective.TIERS.size()):
		Global.attempt_segment = 2
		stakes_hub1.append(WagerShrineObjective.tier_stake(tier))
		Global.attempt_segment = 10
		stakes_deep.append(WagerShrineObjective.tier_stake(tier))
	_check(stakes_hub1 == [20, 35, 55], "wager stakes stay 20 / 35 / 55 through segment 2 (%s)" % str(stakes_hub1))
	_check(stakes_deep == [60, 105, 165], "and x3.0 in segment 10 (%s)" % str(stakes_deep))

	Global.set_doctrine_rule(&"manufactured_witness", true)
	var witness_prices: Array = []
	for wallet in [150, 1250, 1251, 5000]:
		Global.set_followers(wallet)
		witness_prices.append(Global.manufactured_witness_price())
	_check(witness_prices == [100, 100, 101, 400], "Manufactured Witness costs 100, or 8%% of a wallet above 1,250 (%s)" % str(witness_prices))
	Global.attempt_segment = 9
	Global.attempt_witness_used_segment = 0
	Global.set_followers(5000)
	_check(Global.try_consume_manufactured_witness() and Global.followers == 4600, "and a rescue at 5,000 consumes 400 (%d left)" % Global.followers)
	Global.attempt_doctrine_rules = {}


# ---------------------------------------------------------------- P5

func _test_congregation() -> void:
	_fresh_attempt()
	_check(Global.attempt_congregation == 0, "a new attempt starts an empty Congregation")
	var recruits := {&"combat_influence": 10, &"secondary_objective": 15, &"boss_victory": 25, &"miniboss_victory": 8, &"mass_conversion": 40, &"loaded_dice": 1, &"gamblers_rite": 2}
	var expected := 0
	for reason in recruits:
		Global.transaction_followers(int(recruits[reason]), reason, {}, false, false)
		expected += int(recruits[reason])
	_check(Global.attempt_congregation == expected, "kills, objectives, arenas, Mass Conversion, Loaded Dice and Gambler's Rite recruit (%d of %d)" % [Global.attempt_congregation, expected])
	for reason in [&"trade", &"trade_undo", &"ascension_refund", &"binding_abstain", &"dev_grant", &"developer_grant", &"manifestation_pair_tithe_return"]:
		Global.transaction_followers(100, reason, {}, false, false)
	Global.set_followers(Global.followers + 500)
	Global.add_followers(50)
	_check(Global.attempt_congregation == expected, "trades, undo, refunds, Abstain, syncs, legacy calls and developer grants recruit nobody (%d)" % Global.attempt_congregation)
	Global.transaction_followers(-600, &"ascension_purchase", {}, false, false)
	Global.transaction_followers(-200, &"reconstruction", {}, false, false)
	_check(Global.attempt_congregation == expected, "spending and dying never shrink it")

	# Segment 1 before the assistant commits: combat is suppressed and
	# recruits nobody; Bren is the first.
	_fresh_attempt(1)
	Global.transaction_followers(5, &"combat_influence", {}, false, false)
	_check(Global.attempt_congregation == 0 and Global.followers == 0, "segment 1's suppressed kills recruit nobody")
	Global.transaction_followers(1, &"bren_first_follower", {}, false, false)
	_check(Global.attempt_congregation == 1, "Bren is the first recruit")

	# Belief's cap follows the Congregation; Power still needs Followers held.
	var caps: Array = []
	var expected_caps := [0.15, 0.15, 0.20, 0.25, 0.30, 0.30]
	var caps_ok := true
	for i in range(expected_caps.size()):
		var recruited: int = [0, 2500, 5000, 10000, 20000, 1000000000][i]
		var cap := Global.belief_congregation_cap(recruited)
		caps.append(snappedf(cap, 0.001))
		caps_ok = caps_ok and _near(cap, float(expected_caps[i]))
	_check(caps_ok, "cap +15%% to 2,500 recruited, +5%% a doubling, at most +30%% (%s)" % str(caps))
	Global.attempt_congregation = 20000
	Global.set_followers(100)
	_check(_near(Global.belief_power_cap(), 0.30) and _near(Global.follower_belief_power(), 0.10), "20,000 recruited: cap +30%, but 100 held is still +10%")
	Global.set_followers(900)
	_check(_near(Global.follower_belief_power(), 0.30), "900 held fills the +30% cap")
	Global.attempt_congregation = 0
	Global.set_followers(10000)
	_check(_near(Global.follower_belief_power(), 0.15), "a hoard on a new Congregation stops at +15%")

	var cult: Array[StringName] = [&"augment_cult_of_personality", StringName(), StringName()]
	Global.permanent_augment_ids = cult
	Global.attempt_augment_transcended = {"augment_cult_of_personality": true}
	_check(_near(Global.belief_power_cap(), 0.30), "Prophet adds +15% to the Congregation's cap")
	var census := load(CENSUS_PATH) as MajorChoiceDef
	for effect in census.effects:
		effect.apply(Global)
	_check(_near(float(Global.get_doctrine_rule(&"belief_power_cap_bonus", 0.0)), 0.20), "Census of Souls writes its +20% lift")
	_check(_near(Global.belief_power_cap(), 0.50), "Prophet and Census on a new Congregation: +50%")
	Global.attempt_congregation = 20000
	_check(_near(Global.belief_power_cap(), 0.60), "and the ceiling holds at +60% (0.30 + 0.15 + 0.20)")
	Global.attempt_augment_transcended = {}
	Global.attempt_doctrine_rules = {"belief_power_cap": 0.4}
	_check(_near(Global.belief_power_cap(), 0.50), "a pre-Congregation save's Census rule keeps its +20% lift")
	Global.attempt_doctrine_rules = {}
	var empty: Array[StringName] = [StringName(), StringName(), StringName()]
	Global.permanent_augment_ids = empty

	# The save carries it; a pre-Congregation save starts from its wallet.
	_fresh_attempt()
	Global.attempt_congregation = 12345
	Global.set_followers(678)
	var save := SaveData.new()
	Global.write_save(save)
	_check(save.attempt_congregation == 12345, "write_save stores the Congregation with the attempt (%d)" % save.attempt_congregation)
	Global.attempt_congregation = 0
	Global.apply_save(save)
	SaveManager.current_save = null
	_check(Global.attempt_congregation == 12345 and Global.followers == 678, "apply_save restores it; the wallet sync recruits nobody (%d)" % Global.attempt_congregation)
	var legacy := SaveData.new()
	Global.write_save(legacy)
	legacy.attempt_congregation = -1
	legacy.attempt_followers = 777
	Global.apply_save(legacy)
	SaveManager.current_save = null
	_check(Global.attempt_congregation == 777, "a save from before the field starts it from the Followers held (%d)" % Global.attempt_congregation)
	_check(SaveData.new().attempt_congregation == -1, "the field's default marks a save written before it existed")
	Global.on_attempt_failed_die_die()
	SaveManager.current_save = null
	_check(Global.attempt_congregation == 0, "a failed attempt clears it")
	var closed := SaveData.new()
	Global.write_save(closed)
	_check(closed.attempt_congregation == 0, "and a closed attempt saves 0")
	Global.attempt_congregation = 99
	Global.start_new_attempt()
	SaveManager.current_save = null
	_check(Global.attempt_congregation == 0, "so does a new attempt")

	# The Hub's crowd: sized from the Congregation, so spending at the last Hub
	# never shrinks this one.
	_fresh_attempt(3)
	Global.attempt_congregation = 4000
	Global.followers = 100
	_check(Global.congregation_crowd_basis() == 4000, "the crowd basis is the Congregation when the wallet is spent")
	Global.attempt_congregation = 100
	Global.followers = 4000
	_check(Global.congregation_crowd_basis() == 4000, "and the wallet when a sale holds more")
	Global.attempt_congregation = 4000
	Global.followers = 100
	var hub: HubWorld = HUB_WORLD.instantiate()
	hub.departure_scene_change_enabled = false
	hub.crowd_seed = 7
	add_child(hub)
	await get_tree().process_frame
	await get_tree().physics_frame
	_check(hub.crowd != null and hub.crowd.believers.size() == 15, "4,000 recruited and 100 held still fill the square with 15 people (%d)" % (hub.crowd.believers.size() if hub.crowd != null else -1))
	hub.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------- P7

func _test_reserve_floor() -> void:
	_fresh_attempt()
	var flat := Global.reconstruction_cost_for(1)
	_check(flat == 12, "fixture: a segment 2 death costs 12 at a small balance (%d)" % flat)
	Global.set_followers(13)
	_check(not Global.spend_survivable(1), "spending 1 of 13 would leave exactly the cost: refused")
	Global.set_followers(14)
	_check(Global.spend_survivable(1) and Global.spend_survivable(0), "spending 1 of 14 leaves a reconstruction")
	Global.set_followers(1000)
	_check(Global.spend_survivable(900) and not Global.spend_survivable(990), "a big wallet may spend down to a survivable balance, never past it")

	var furnace := FurnaceScript.new()
	add_child(furnace)
	Global.set_followers(13)
	furnace.call("_try_tithe")
	_check(Global.followers == 13, "Tithe Furnace refuses a tithe that would leave exactly the cost (%d)" % Global.followers)
	furnace.call("_refresh_affordability")
	_check(not bool(furnace.get("_can_afford")), "and its glow says it cannot afford one")
	Global.set_followers(14)
	furnace.call("_try_tithe")
	_check(Global.followers == 13 and Global.reconstruction_survivable(Global.followers), "with one more it tithes and still leaves a reconstruction")
	furnace.queue_free()


# ---------------------------------------------------------------- P9

func _test_rank_downgrades() -> void:
	_fresh_attempt()
	Global.selected_style_id = "ranged"
	Global.new_run_tree_version = "v5_ranged"
	Global.attempt_ascension = {}
	Global.set_followers(1000000)
	for id in ["BR01", "BR02", "BR04", "BR01", "BR01"]:
		var verdict := Global.ascension_buy(id)
		if not bool(verdict.get("ok", false)):
			_check(false, "fixture: %s buys (%s)" % [id, String(verdict.get("reason", ""))])
	var ledger := Global.ascension_ledger()
	_check(ledger.tree_version() == "v5_ranged" and ledger.rank("BR01") == 3 and ledger.rank_receipts("BR01") == [0, 350, 750], "fixture: BR01 at rank 3 on the V5 tree (%s)" % str(ledger.rank_receipts("BR01")))
	Global.ascension_refund_context_hub = false
	_check(Global.ascension_downgrade("BR01") == 0, "a downgrade outside the Hub does nothing")
	Global.ascension_refund_context_hub = true
	Global.attempt_segment = 2
	var before := Global.followers
	var back := Global.ascension_downgrade("BR01")
	_check(back == 375 and Global.followers - before == 375 and ledger.rank("BR01") == 2, "at Hub 1 a downgrade returns half of the 750 receipt (%d)" % back)
	Global.attempt_segment = 7
	before = Global.followers
	back = Global.ascension_downgrade("BR01")
	var share := AscensionLedger.refund_share(7)
	_check(back == int(round(350.0 * share)) and Global.followers - before == back, "at Hub 6 the share has shrunk to %.0f%% (%d of 350)" % [share * 100.0, back])
	Global.ascension_refund_context_hub = false

	# The V4 control's refunds are untouched.
	var v4 := AscensionLedger.new(AscensionTreeDB.shared_for("v4"), AscensionLedger.fresh_state("ranged"))
	var bought := 0
	for id in ["BR01", "BR02"]:
		var verdict := v4.can_buy(id, 1000000)
		if bool(verdict["ok"]):
			v4.record_purchase(id, int(verdict["cost"]))
			bought += int(verdict["cost"])
	var paid_br02 := int((v4.state["paid"] as Dictionary).get("BR02", 0))
	_check(paid_br02 > 0 and v4.refund("BR02", 0.5) == int(round(float(paid_br02) * 0.5)), "a V4 refund still returns the share of what was paid (%d paid)" % paid_br02)


# ---------------------------------------------------------------- P10

func _test_recorder() -> void:
	var reasons: Dictionary = RecorderScript._recruit_reasons()
	var same := reasons.size() == Global.CONGREGATION_REASONS.size()
	for reason in Global.CONGREGATION_REASONS:
		same = same and reasons.has(String(reason))
	_check(same, "the recorder counts exactly Global's recruitment reasons (%d)" % reasons.size())
	var ledger: RefCounted = Ledger.new()
	ledger.set("recruit_reasons", reasons)
	ledger.call("start", {}, 100, 2)
	ledger.call("transaction", 100, 30, 130, "combat_influence", {})
	ledger.call("transaction", 130, 50, 180, "trade", {"sell_value": 50, "buy_value": 0})
	ledger.call("transaction", 180, -80, 100, "ascension_purchase", {})
	ledger.call("transaction", 100, 5, 105, "secondary_objective", {})
	ledger.call("transaction", 105, 200, 305, "dev_grant", {})
	ledger.call("change_segment", 3, "completed")
	ledger.call("mark_hub_departure", 290)
	ledger.call("transaction", 305, 10, 315, "combat_influence", {})
	var summary: Dictionary = ledger.call("summary")
	var segments: Array = summary["segments"]
	var first: Dictionary = segments[0]
	var second: Dictionary = segments[1]
	_check(int(first["followers_recruited"]) == 35 and int(first["followers_peak"]) == 305, "a segment records Followers recruited (35) and its peak wallet (305): %d / %d" % [int(first["followers_recruited"]), int(first["followers_peak"])])
	_check(first.get("hub_departure_wallet") == null and int(second["hub_departure_wallet"]) == 290, "the Hub's departure wallet lands on the segment it opens")
	_check(int(second["followers_recruited"]) == 10 and int(second["followers_peak"]) == 315, "the next segment counts from its own opening")
	var totals: Dictionary = summary["totals"]
	_check(int(totals["followers_recruited"]) == 45 and int(totals["followers_peak"]) == 315, "the totals row adds them up")
	var by_reason: Dictionary = first["followers_by_reason"]
	_check(int((by_reason["ascension_purchase"] as Dictionary)["spent"]) == 80, "spend by sink stays in followers_by_reason")
