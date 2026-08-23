extends Node

var _failures: int = 0
var _passes: int = 0
var _global: Node


func _ready() -> void:
	_global = get_node("/root/Global")
	call_deferred("_run")


func _run() -> void:
	_test_development_item_is_not_runtime_eligible()
	_test_rarity_and_luck_math()
	_test_vendor_merge_arbitrage_is_lossy()
	_test_canonical_rarity_merging()
	_test_enemy_drops_use_instances_and_all_rarity_bonuses()
	_test_accessories_use_normal_progression()
	_test_polarity_hooks()
	_test_item_value_keeps_growing_after_r12()
	_test_item_value_counts_meaningful_contributions()
	_test_item_value_progress_and_polarity()
	_test_guaranteed_reward_delivery()
	_test_tooltip_compares_scripted_effects()
	_test_bag_debug_defaults_off()
	_test_profile_run_records()
	_test_resonance_pacing_defaults()
	_test_procedural_fallback_score_prefers_reachable_candidate()
	await get_tree().process_frame
	print("AuditClosureTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _test_development_item_is_not_runtime_eligible() -> void:
	var test_item := load("res://data/items/defs/item_test.tres") as ItemData
	_check(test_item != null, "development item remains directly loadable")
	_check(
		test_item != null and test_item.get("runtime_enabled") == false,
		"development item declares itself runtime-disabled"
	)
	_global.load_items_from_dir("res://data/items/defs")
	_check(not _global.item_db.has("item_test"), "runtime item database excludes development item")


func _test_rarity_and_luck_math() -> void:
	_check(is_equal_approx(RarityMath.potency(0.0), 1.0), "R0 potency is one")
	_check(
		is_equal_approx(RarityMath.potency(10.0), 1.0 + 0.45 * sqrt(10.0) + 0.5),
		"R10 potency uses the diminishing curve"
	)
	_check(is_equal_approx(RarityMath.potency(100.0), 10.5), "R100 potency remains bounded")
	_check(LuckResolver.drop_multiplier(0.5) > LuckResolver.drop_multiplier(0.0), "Luck improves drops")
	_check(LuckResolver.buy_multiplier(100.0) >= 0.88, "Luck buy discount is capped")
	_check(LuckResolver.sell_multiplier(100.0) <= 1.08, "Luck sell bonus is capped")
	_check(
		LuckResolver.positive_probability(100.0) < 0.80,
		"NEG items remain possible at extreme Luck"
	)

	# Luck must make NEG rolls MILDER, never more severe (regression guard:
	# the old negative branch lerped high quality toward min_pct).
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var neg_mean_unlucky := 0.0
	var neg_mean_lucky := 0.0
	var samples := 3000
	for _i in range(samples):
		neg_mean_unlucky += ItemGenerator.roll_signed_range(-1.0, 0.0, 0.0, rng)
	for _i in range(samples):
		neg_mean_lucky += ItemGenerator.roll_signed_range(-1.0, 0.0, 3.0, rng)
	neg_mean_unlucky /= float(samples)
	neg_mean_lucky /= float(samples)
	_check(
		neg_mean_lucky > neg_mean_unlucky + 0.02,
		"high Luck pulls NEG roll severity toward zero (%.3f vs %.3f)" % [neg_mean_lucky, neg_mean_unlucky]
	)
	var pos_mean_unlucky := 0.0
	var pos_mean_lucky := 0.0
	for _i in range(samples):
		pos_mean_unlucky += ItemGenerator.roll_signed_range(0.0, 1.0, 0.0, rng)
	for _i in range(samples):
		pos_mean_lucky += ItemGenerator.roll_signed_range(0.0, 1.0, 3.0, rng)
	pos_mean_unlucky /= float(samples)
	pos_mean_lucky /= float(samples)
	_check(
		pos_mean_lucky > pos_mean_unlucky + 0.02,
		"high Luck strengthens POS rolls (%.3f vs %.3f)" % [pos_mean_lucky, pos_mean_unlucky]
	)


func _test_canonical_rarity_merging() -> void:
	var data := ItemData.new()
	data.id = "merge_fixture"
	data.pct_min = -0.5
	data.pct_max = 0.5
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	var equal_dest := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.25)
	var equal_incoming := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.25)
	_check(equal_dest.merge_from(equal_incoming), "equal-rarity projects merge")
	_check(equal_dest.rarity == 1, "average equal-rarity merge gains one rarity")
	_check(is_equal_approx(equal_dest.best_pct, 0.25), "rarity upgrade preserves best roll")
	var high_dest := ItemInstance.from_roll(data, 10, ItemInstance.Polarity.POS, 0.25)
	var low_incoming := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.25)
	high_dest.merge_from(low_incoming)
	_check(high_dest.upgrade_meter > 0.0, "R0 retains non-zero merge value in R10")
	var strong_dest := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.1)
	var strong_incoming := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.5)
	strong_dest.merge_from(strong_incoming)
	_check(strong_dest.rarity == 1 and strong_dest.upgrade_meter > 0.0, "strong merge carries overflow")
	_check(is_equal_approx(strong_dest.best_pct, 0.5), "POS merge preserves strongest roll")
	var negative := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.NEG, -0.5)
	_check(not strong_dest.merge_from(negative), "POS and NEG projects never merge")

	# NEG merge direction: default STABILIZES (mildest roll survives);
	# Corruption Engine flips progression to DEEPEN the curse.
	var mild_neg := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.NEG, -0.1)
	var severe_neg := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.NEG, -0.45)
	var had_engine: bool = Global.permanent_augment_ids.has(&"augment_corruption_engine")
	Global.permanent_augment_ids.erase(&"augment_corruption_engine")
	mild_neg.merge_from(severe_neg)
	_check(
		is_equal_approx(mild_neg.best_pct, -0.1),
		"NEG merge stabilizes toward the mildest curse by default"
	)
	Global.init_permanent_augments()
	var engine_slot: int = Global.permanent_augment_ids.find(StringName())
	if engine_slot != -1:
		Global.permanent_augment_ids[engine_slot] = &"augment_corruption_engine"
	var mild_neg2 := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.NEG, -0.1)
	var severe_neg2 := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.NEG, -0.45)
	mild_neg2.merge_from(severe_neg2)
	_check(
		is_equal_approx(mild_neg2.best_pct, -0.45),
		"Corruption Engine makes NEG merges deepen the curse"
	)
	if engine_slot != -1 and not had_engine:
		Global.permanent_augment_ids[engine_slot] = StringName()

	# --- Merge-math v2 invariants (docs/design/RARITY_MERGE_SPEC.md §1) ---

	# Path-independence: pre-merging into a carrier must never create mass.
	var pi_direct := ItemInstance.from_roll(data, 5, ItemInstance.Polarity.POS, 0.25)
	pi_direct.merge_from(ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.0))
	pi_direct.merge_from(ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.0))
	var pi_carrier := ItemInstance.from_roll(data, 5, ItemInstance.Polarity.POS, 0.25)
	var carrier := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.0)
	carrier.merge_from(ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.0))
	pi_carrier.merge_from(carrier)
	_check(
		absf(pi_direct.upgrade_meter - pi_carrier.upgrade_meter) < 0.000001,
		"merge mass is path-independent (direct %.6f vs carrier %.6f)" % [pi_direct.upgrade_meter, pi_carrier.upgrade_meter]
	)

	# Auto-swap: the higher-rarity incoming becomes the mathematical
	# destination while THIS object keeps its identity.
	var low_stack := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.25)
	var low_stack_id := low_stack.get_instance_id()
	low_stack.merge_from(ItemInstance.from_roll(data, 4, ItemInstance.Polarity.POS, 0.25))
	_check(low_stack.rarity == 4, "auto-swap adopts the higher rarity (got R%d)" % low_stack.rarity)
	_check(low_stack.get_instance_id() == low_stack_id, "auto-swap preserves object identity")
	_check(
		low_stack.upgrade_meter > 0.0 and low_stack.upgrade_meter < 0.2,
		"auto-swap charges the low side as gap-priced material (meter %.3f)" % low_stack.upgrade_meter
	)

	# Overflow converts at the gap law's per-rank ratio 2^(-1/H).
	var of_dest := ItemInstance.from_roll(data, 3, ItemInstance.Polarity.POS, 0.25)
	of_dest.upgrade_meter = 0.9
	of_dest.merge_from(ItemInstance.from_roll(data, 3, ItemInstance.Polarity.POS, 0.25))
	var expected_overflow := 0.9 * pow(2.0, -1.0 / RarityMath.GAP_HALF_LIFE)
	_check(
		of_dest.rarity == 4 and absf(of_dest.upgrade_meter - expected_overflow) < 0.000001,
		"overflow uses the gap law's rank ratio (meter %.4f, expected %.4f)" % [of_dest.upgrade_meter, expected_overflow]
	)

	# Continuous rarity power: banked meter grants real stats.
	var cp_data := ItemData.new()
	cp_data.id = "continuous_fixture"
	cp_data.pct_min = -0.5
	cp_data.pct_max = 0.5
	cp_data.mods = StatDelta.new()
	cp_data.rarity_base = StatDelta.new()
	cp_data.rarity_base.max_hp = 20.0
	var cp := ItemInstance.from_roll(cp_data, 0, ItemInstance.Polarity.POS, 0.25)
	var hp_at_zero: float = cp.rolled_mods.max_hp
	cp.upgrade_meter = 0.5
	cp._recompute_flat_mods()
	_check(
		cp.rolled_mods.max_hp > hp_at_zero + 3.0,
		"banked meter grants real stats (continuous power: +%.1f HP at 50%%)" % (cp.rolled_mods.max_hp - hp_at_zero)
	)


func _test_enemy_drops_use_instances_and_all_rarity_bonuses() -> void:
	var spec := EnemySpec.new()
	_check(spec.drop_instance_roll, "enemy specs default to complete instance drops")
	var drops := EnemyDrops.new()
	_check(drops.has_method("finalize_rarity"), "enemy drops expose rarity finalization")
	if drops.has_method("finalize_rarity"):
		_check(
			int(drops.call("finalize_rarity", 2, 1, 3)) == 6,
			"enemy rarity includes rolled base, elite, and Threat bonuses"
		)


func _test_accessories_use_normal_progression() -> void:
	for path in [
		"res://data/items/defs/accessories/ring_crusher.tres",
		"res://data/items/defs/accessories/ring_regeneration.tres",
	]:
		var data := load(path) as ItemData
		_check(data.pct_min < 0.0 and data.pct_max > 0.0, "%s has meaningful POS/NEG rolls" % data.display_name)
		var instance := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.2)
		var incoming := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.2)
		instance.merge_from(incoming)
		_check(instance.rarity == 1, "%s uses normal equal-rarity progression" % data.display_name)
		_check(is_equal_approx(instance.active_pct(), 0.2), "%s preserves its effect roll on upgrade" % data.display_name)


func _test_polarity_hooks() -> void:
	var inv := Inventory.new()
	var negative_data := ItemData.new()
	negative_data.id = "negative_fixture"
	negative_data.equip_slot = ItemData.EquipSlot.HP
	negative_data.set_id = "fixture_set"
	negative_data.mods = StatDelta.new()
	negative_data.rarity_base = StatDelta.new()
	var negative := ItemInstance.from_roll(
		negative_data, 3, ItemInstance.Polarity.NEG, -0.4
	)
	inv.set_item(0, negative)
	_check(inv.get_negative_item_count() == 1, "inventory exposes NEG item count")
	_check(inv.get_negative_rarity_total() == 3, "inventory exposes NEG rarity total")
	_check(is_equal_approx(inv.get_negative_magnitude_total(), 0.4), "inventory exposes NEG magnitude")
	var composition := inv.get_set_polarity_composition(&"fixture_set")
	_check(int(composition.neg) == 1 and int(composition.pos) == 0, "set composition exposes polarity")


func _item_with(data: ItemData, rarity: int) -> ItemInstance:
	var instance := ItemInstance.new()
	instance.data = data
	instance.rarity = rarity
	instance.polarity = ItemInstance.Polarity.POS
	instance._recompute_flat_mods()
	return instance


func _test_vendor_merge_arbitrage_is_lossy() -> void:
	# Invariant (design ruling): no vendor buy -> merge -> sell sequence may
	# produce more Followers than it consumes, at any rarity, meter state,
	# roll quality or Luck. Followers are money AND lives AND power - a
	# repeatable positive loop here would be 'stand at merchant and
	# manufacture religion'.
	var data := ItemData.new()
	data.id = "arbitrage_fixture"
	data.pct_min = -0.5
	data.pct_max = 0.5
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	data.rarity_base.max_hp = 20.0
	var old_luck: float = _global.run_luck
	var worst: float = -INF
	for luck_value in [0.0, 100.0]:
		_global.run_luck = luck_value
		for dest_rarity in [0, 1, 2, 3, 5, 8]:
			for dest_meter in [0.0, 0.5]:
				for dest_roll in [0.0, 0.5]:
					for material_roll in [0.0, 0.5]:
						for material_rarity in [maxi(0, dest_rarity - 1), dest_rarity]:
							var dest := ItemInstance.from_roll(data, dest_rarity, ItemInstance.Polarity.POS, dest_roll)
							dest.upgrade_meter = dest_meter
							dest._recompute_flat_mods()
							var material := ItemInstance.from_roll(data, material_rarity, ItemInstance.Polarity.POS, material_roll)
							var buy_cost: int = int(_global.compute_buy_value(material))
							var sell_before: int = int(_global.compute_sell_value(dest))
							dest.merge_from(material)
							var sell_after: int = int(_global.compute_sell_value(dest))
							worst = maxf(worst, float(sell_after - sell_before - buy_cost))
	_global.run_luck = old_luck
	_check(worst < 0.0, "no vendor buy->merge->sell sequence nets Followers (worst case %+.1f)" % worst)


func _test_item_value_keeps_growing_after_r12() -> void:
	var data := ItemData.new()
	data.id = "value_fixture"
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	var r12: int = int(_global.compute_item_value(_item_with(data, 12)))
	var r13: int = int(_global.compute_item_value(_item_with(data, 13)))
	var r20: int = int(_global.compute_item_value(_item_with(data, 20)))
	var r21: int = int(_global.compute_item_value(_item_with(data, 21)))
	_check(r13 > r12, "item value grows from R12 to R13")
	_check(r21 > r20, "item value grows from R20 to R21")


func _test_item_value_counts_meaningful_contributions() -> void:
	var empty := ItemData.new()
	empty.id = "empty_fixture"
	empty.mods = StatDelta.new()
	empty.rarity_base = StatDelta.new()
	var flat := ItemData.new()
	flat.id = "flat_fixture"
	flat.mods = StatDelta.new()
	flat.mods.max_hp = 25.0
	flat.rarity_base = StatDelta.new()
	var scripted := ItemData.new()
	scripted.id = "scripted_fixture"
	scripted.mods = StatDelta.new()
	scripted.rarity_base = StatDelta.new()
	scripted.set("scripted_value_weight", 20.0)
	var set_item := ItemData.new()
	set_item.id = "set_fixture"
	set_item.mods = StatDelta.new()
	set_item.rarity_base = StatDelta.new()
	set_item.set_id = "conduit"
	var baseline: int = int(_global.compute_item_value(_item_with(empty, 2)))
	_check(
		_global.compute_item_value(_item_with(flat, 2)) > baseline,
		"flat stats increase item value"
	)
	_check(
		_global.compute_item_value(_item_with(scripted, 2)) > baseline,
		"scripted effects increase item value"
	)
	_check(
		_global.compute_item_value(_item_with(set_item, 2)) > baseline,
		"set membership increases item value"
	)


func _test_item_value_progress_and_polarity() -> void:
	var data := ItemData.new()
	data.id = "pricing_fixture"
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	var positive := ItemInstance.from_roll(data, 3, ItemInstance.Polarity.POS, 0.25)
	var negative := ItemInstance.from_roll(data, 3, ItemInstance.Polarity.NEG, -0.25)
	_check(
		_global.compute_item_value(positive) == _global.compute_item_value(negative),
		"equal-magnitude POS and NEG items have equal unexplained base value"
	)
	var progressed := positive.snapshot_copy()
	progressed.upgrade_meter = 0.8
	_check(
		_global.compute_item_value(progressed) > _global.compute_item_value(positive),
		"rarity progress contributes to item value"
	)
	var old_luck: float = _global.run_luck
	_global.run_luck = 100.0
	_check(
		_global.compute_sell_value(positive) < _global.compute_buy_value(positive),
		"maximum Luck cannot create a buy-resell profit loop"
	)
	_global.run_luck = old_luck


func _test_guaranteed_reward_delivery() -> void:
	var old_inventory: Inventory = _global.run_inventory
	var old_bag: BagInventory = _global.run_bag
	var old_stash: StashInventory = _global.meta_stash
	_global.run_inventory = Inventory.new()
	_global.run_bag = BagInventory.new()
	_global.meta_stash = StashInventory.new()
	var data := ItemData.new()
	data.id = "reward_fixture"
	data.equip_slot = ItemData.EquipSlot.RING
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	var reward := ItemInstance.from_roll(data, 2, ItemInstance.Polarity.POS, 0.2)
	_check(_global.deliver_guaranteed_item(reward, true), "guaranteed reward finds a destination")
	_check(_global.run_inventory.get_at(Inventory.SLOT_RING) == reward, "guaranteed reward prefers its empty equipment slot")
	_global.run_inventory = old_inventory
	_global.run_bag = old_bag
	_global.meta_stash = old_stash


func _test_tooltip_compares_scripted_effects() -> void:
	var ring := load("res://data/items/defs/accessories/ring_regeneration.tres") as ItemData
	var current := _item_with(ring, 0)
	var candidate := _item_with(ring, 2)
	var tooltip := ItemTooltip.new()
	var rows: Array[String] = tooltip.build_comparison_rows(current, candidate, Inventory.new())
	_check(
		rows.any(func(row: String) -> bool: return row.contains("SCRIPTED EFFECT CHANGES")),
		"tooltip comparison reports scripted effect changes"
	)
	tooltip.free()


func _test_bag_debug_defaults_off() -> void:
	_check(not BagInventory.new().debug_bag, "bag debug logging defaults off")


func _test_profile_run_records() -> void:
	var save := SaveData.new()
	save.total_runs = 4
	_check(_global.has_method("record_new_attempt"), "Global exposes new-attempt record helper")
	if _global.has_method("record_new_attempt"):
		_global.call("record_new_attempt", save)
		_check(save.total_runs == 5, "new attempt increments total runs exactly once")
	var previous_followers: int = _global.followers
	_global.followers = 12
	save.best_followers = 10
	_global.write_save(save)
	_check(save.best_followers == 12, "profile save records a new follower best")
	_global.followers = 5
	_global.write_save(save)
	_check(save.best_followers == 12, "profile save never lowers follower best")
	_global.followers = previous_followers


func _test_resonance_pacing_defaults() -> void:
	var builder_script := load("res://core/systems/world/SegmentProcBuilder.gd") as Script
	var builder: Node = builder_script.new()
	var ambient_rate: float = float(builder.get("resonance_per_sec"))
	var primary_reward: float = float(builder.get("primary_completion_resonance"))
	var low_action_seconds := (1.0 - primary_reward) / ambient_rate
	_check(
		low_action_seconds >= 225.0 and low_action_seconds <= 255.0,
		"ambient resonance finishes near four minutes after primary completion"
	)
	_check(
		is_equal_approx(float(builder.get("gate_marker_reveal_resonance")), 0.75),
		"gate marker threshold remains 75 percent"
	)
	builder.free()


func _test_procedural_fallback_score_prefers_reachable_candidate() -> void:
	var reachable := {
		"valid": false,
		"errors": ["exit_not_beyond_primary"],
		"start_to_primary": 5,
		"start_to_exit": 7,
		"primary_to_exit": 2,
		"secondary_count": 2,
	}
	var unreachable := {
		"valid": false,
		"errors": ["primary_unreachable_or_too_close"],
		"start_to_primary": -1,
		"start_to_exit": -1,
		"primary_to_exit": -1,
		"secondary_count": 3,
	}
	var district_script := load("res://core/systems/world/proc/DistrictPlan.gd") as Script
	_check(district_script.has_method("validation_score"), "DistrictPlan exposes deterministic fallback scoring")
	if district_script.has_method("validation_score"):
		_check(
			int(district_script.call("validation_score", reachable))
			> int(district_script.call("validation_score", unreachable)),
			"fallback scoring prioritizes reachable objective and exit"
		)
