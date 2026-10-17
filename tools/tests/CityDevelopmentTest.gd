extends Node

# Research must follow completed city progress, survive failure, and affect only
# the next attempt. Removing snapshot isolation or the claimed-segment guard
# changes real stats, saved capacity, or the point budget asserted below.
const EXPERIMENTS = preload("res://core/systems/balance/CityBalanceExperiments.gd")
const TRAINED := &"augment_tesla_aura"
const OTHER := &"augment_stamina_core"
const NO_DEVELOPMENT := "--city-no-permanent-development"
const PLAYER = preload("res://core/actors/player/player.tscn")
var _passes := 0
var _failures := 0

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _summary() -> Dictionary:
	return Global.call("get_city_development_summary") as Dictionary

func _buy(id: StringName, target: StringName = &"") -> bool:
	return bool(Global.call("purchase_city_development", id, target))

func _fresh() -> SaveData:
	var save := SaveData.new()
	SaveManager.current_save = save
	Global.apply_save(save)
	Global.start_new_attempt()
	Global.owned_augment_ids = [TRAINED, OTHER]
	Global.permanent_augment_ids = [TRAINED, &"", &""]
	return save

func _clear(segment: int) -> void:
	Global.attempt_segment = segment
	_check(Global.begin_segment_completion(segment), "Rite %d starts" % segment)
	_check(Global.finish_segment_completion(segment), "Rite %d settles" % segment)

func _stats() -> Stats:
	var stats := Stats.new()
	Global.apply_permanent_augments_to_stats(stats)
	return stats

func _test_earning() -> void:
	var save := _fresh()
	_check(_summary()["points"] == 0 and _summary()["earned"] == 0, "legacy empty defaults grant no research")
	_check(not _buy(&"health"), "no purchase without earned research")
	Global.set_followers(100000)
	_check(_summary()["points"] == 0, "Followers do not become research")
	_clear(1)
	_check(_summary()["points"] == 1 and _summary()["claimed_segments"] == [1], "first city Rite grants one point")
	Global.on_segment_completed(1)
	_check(_summary()["points"] == 1, "duplicate callback cannot pay research twice")
	Global.start_new_attempt()
	_clear(1)
	_check(_summary()["points"] == 1, "restarting and clearing the same Rite cannot farm research")
	Global.debug_dev_segment = true
	_clear(2)
	_check(_summary()["points"] == 1, "developer segment clears grant no research")
	Global.debug_dev_segment = false
	Global.debug_dev_mode = true
	_clear(3)
	_check(_summary()["points"] == 1, "developer mode grants no research")
	Global.debug_dev_mode = false
	SaveManager.current_save = null
	_clear(4)
	_check(_summary()["points"] == 1, "unsaved developer attempts grant no research")
	SaveManager.current_save = save
	for segment in range(2, 11):
		_clear(segment)
	_clear(11)
	_check(_summary()["earned"] == 10 and _summary()["points"] == 10, "only ten city first clears earn research")

func _test_purchases_and_snapshot() -> void:
	_fresh()
	for segment in range(1, 11):
		_clear(segment)
	_check(not _buy(&"bogus") and not _buy(&"augment", &"missing"), "unknown upgrades and unowned training target rejected")
	var before := _stats()
	for id in [&"health", &"armor", &"bag"]:
		for rank in range(3):
			_check(_buy(id), "%s rank %d purchased" % [id, rank + 1])
			if id == &"health" and rank == 0:
				var first: Dictionary = _summary()
				_check(first["points"] == 9 and first["ranks"]["health"] == 1 and first["ranks"]["armor"] == 0 and first["ranks"]["bag"] == 0 and first["ranks"]["augment"] == 0, "one point chooses only health rather than automatically buying a bundle")
			if id == &"armor" and rank == 0:
				_check(_summary()["ranks"]["health"] == 3 and _summary()["ranks"]["armor"] == 1, "a later choice accumulates while preserving earlier improvements")
		_check(not _buy(id), "%s cap enforced" % id)
	_check(_buy(&"augment", TRAINED), "one owned augment can be trained")
	_check(_summary()["points"] == 0 and _summary()["earned"] == 10, "ten cumulative ranks spend exactly ten research")
	_check(_stats().max_hp == before.max_hp and _stats().armor == before.armor and Global.run_bag.extra_slots == 0 and Global.get_augment_level(TRAINED) == 1, "buying preparation cannot retrofit current stats bag or augment")
	var summary := _summary()
	summary["ranks"]["health"] = 0
	_check(_summary()["ranks"]["health"] == 3, "summary cannot mutate saved ranks")
	_check(bool(Global.call("select_trained_augment", OTHER)), "trained selection can change for next attempt")
	_check(not bool(Global.call("select_trained_augment", &"missing")), "trained target must remain owned")
	_check(Global.get_augment_level(OTHER) == 1, "training selection cannot change active attempt")
	Global.start_new_attempt()
	_check(_stats().max_hp == before.max_hp + 15 and _stats().armor == before.armor + 3 and Global.run_bag.extra_slots == 3, "new attempt accumulates all bought stat and bag ranks")
	_check(Global.get_augment_level(OTHER) == 2 and Global.get_augment_level(TRAINED) == 1, "snapshot trains only the chosen augment")
	Global.set_augment_level(OTHER, 8)
	_check(Global.get_augment_level(OTHER) == 8, "higher temporary augment levels survive starting floor")
	_check(bool(Global.call("select_trained_augment", TRAINED)) and Global.get_augment_level(TRAINED) == 1, "next target selection preserves active training snapshot")
	var snapshot := SaveData.new()
	Global.write_save(snapshot)
	Global.apply_save(snapshot)
	_check(Global.get_augment_level(OTHER) == 8 and Global.get_augment_level(TRAINED) == 1 and Global.run_bag.extra_slots == 3, "save reload preserves active snapshot and higher run levels")
	Global.run_bag.extra_slots += 2
	Global.run_bag.get_slot_count()
	var stored := ItemInstance.from_roll(load("res://data/items/defs/accessories/acc_firestone.tres") as ItemData, 24, 1, 0.6, false)
	Global.run_bag.slots[20] = stored
	Global.write_save(snapshot)
	Global.apply_save(snapshot)
	Global.apply_save(snapshot)
	_check(Global.run_bag.extra_slots == 5 and Global.run_bag.slots[20] != null and Global.run_bag.slots[20].rarity == 24, "reloading never adds capacity twice or discards temporary tail items")
	Global.set_followers(0)
	Global.begin_peep_continuation()
	var earned: int = _summary()["earned"]
	_check(Global.accept_peep_continuation() and _summary()["earned"] == earned and _summary()["ranks"]["health"] == 3, "terminal continuation retains purchases without death payout")
	_check(Global.get_augment_level(TRAINED) == 2 and Global.get_augment_level(OTHER) == 1 and Global.run_bag.extra_slots == 3, "terminal restart uses prepared target and resets run growth and temporary capacity")

func _test_transfusion() -> void:
	_fresh()
	_clear(1)
	_check(_buy(&"augment", TRAINED), "transfusion fixture buys training")
	Global.start_new_attempt()
	Global.permanent_augment_ids = [OTHER, &"", &""]
	Global.set_followers(100000)
	_check(not bool(Global.transfusion_preview(OTHER, TRAINED)["ok"]), "free trained starting level cannot be donated")
	Global.set_augment_level(TRAINED, 4)
	var preview := Global.transfusion_preview(OTHER, TRAINED)
	_check(int(preview["gain"]) == 1 and int(preview["donor_after"]) == 2, "the preview pours half of the earned levels and lands a trained donor on its floor, not Lv.1")
	_check(bool(Global.transfuse_augment(OTHER, TRAINED)["ok"]), "earned temporary levels can be donated")
	_check(Global.get_augment_level(TRAINED) == 2, "trained donor returns to its starting floor")
	_check(not bool(Global.transfusion_preview(OTHER, TRAINED)["ok"]), "training cannot repeatedly mint transfusion levels")

func _test_recovery() -> void:
	_fresh()
	Global.attempt_segment = 3
	_check(Global.begin_segment_completion(3), "interrupted Rite saves completion intent")
	var loaded := SaveManager.load_slot(0)
	SaveManager.current_save = loaded
	Global.apply_save(loaded)
	_check(_summary()["points"] == 1 and _summary()["claimed_segments"] == [3] and loaded.attempt_pending_segment_completion == 0 and loaded.attempt_segment == 4, "completion recovery saves research and advancement together")
	Global.apply_save(loaded)
	_check(_summary()["points"] == 1, "reloading settled completion cannot repeat research")
	var selected_state: Dictionary = loaded.get("meta_city_development").duplicate(true)
	var unselected := SaveData.new()
	unselected.attempt_active = true
	unselected.attempt_segment = 6
	unselected.attempt_pending_segment_completion = 6
	Global.apply_save(unselected)
	_check(_summary()["earned"] == 0 and loaded.get("meta_city_development") == selected_state, "unselected resource recovery cannot award or mutate selected profile research")
	SaveManager.current_save = loaded
	Global.apply_save(loaded)
	Global.meta_pending_peep = {"name": "Test", "segment": 4}
	Global.on_segment_completed(4)
	_check(_summary()["earned"] == 1, "pending terminal defeat cannot award research")
	Global.meta_pending_peep.clear()

func _test_legacy_and_malformed() -> void:
	var save := _fresh()
	Global.attempt_segment = 8
	Global.write_save(save)
	save.set("meta_city_development", {"claimed_segments": [1, 1, -1, 11, "2", 3], "ranks": {"health": 99, "armor": -2, "bag": "3", "unknown": 3}, "augment_id": "missing"})
	save.set("attempt_city_development", {})
	Global.apply_save(save)
	_check(_summary()["earned"] == 2 and _summary()["points"] >= 0 and _summary()["ranks"]["health"] <= 2 and _summary()["ranks"]["bag"] == 0, "malformed claims types caps and overspent ranks normalize safely")
	_check(_stats().max_hp == 100 and Global.run_bag.extra_slots == 0, "legacy active save with no snapshot retains original gameplay")
	_clear(8)
	_check(_summary()["earned"] == 3, "legacy progress receives only actual new clear without retrospective payout")
	var other_save := SaveData.new()
	Global.apply_save(other_save)
	_check(_summary()["earned"] == 0 and _summary()["points"] == 0, "switching profiles never leaks development")
	other_save.attempt_active = true
	other_save.set("attempt_city_development", {"revision": 1, "ranks": {"health": 3, "armor": 3, "bag": 3, "augment": 1, "power": 3, "haste": 3}, "augment_id": String(TRAINED)})
	Global.apply_save(other_save)
	_check(_stats().max_hp == 100 and _stats().armor == 0 and Global.get_augment_level(TRAINED) == 1, "impossible snapshot cannot invent ranks absent from its profile purchases")

func _test_comparison_flag() -> void:
	_fresh()
	_clear(1)
	_clear(2)
	_clear(3)
	_clear(4)
	_check(_buy(&"health") and _buy(&"armor") and _buy(&"bag") and _buy(&"augment", TRAINED), "flag fixture accumulates preparation")
	Global.start_new_attempt()
	var args := EXPERIMENTS._arguments.duplicate()
	EXPERIMENTS._arguments.append(NO_DEVELOPMENT)
	_check(_stats().max_hp == 100 and _stats().armor == 0 and Global.get_augment_level(TRAINED) == 1, "comparison flag disables effective stat and augment gains")
	var metadata := Global.call("city_development_capture_metadata") as Dictionary
	_check(not bool(metadata["enabled"]) and metadata["profile"]["ranks"]["health"] == 1 and metadata["attempt"]["ranks"]["health"] == 1, "comparison metadata retains profile and snapshot despite disabled bonuses")
	var save := SaveData.new()
	Global.write_save(save)
	Global.apply_save(save)
	_check(Global.run_bag.extra_slots == 1, "comparison load preserves already carried bag capacity")
	Global.start_new_attempt()
	_check(Global.run_bag.extra_slots == 0, "comparison fresh attempt does not seed bonus capacity")
	EXPERIMENTS._arguments = args

func _test_catalogue_choices() -> void:
	_fresh()
	var options: Array = Global.call("get_city_development_options")
	var ids: Array = []
	for option: Dictionary in options:
		ids.append(option["id"])
		_check(int(option["cost"]) == 1 and not String(option["name"]).is_empty() and not String(option["next_gain_text"]).is_empty(), "catalogue exposes usable one-point choice %s" % option["id"])
	for id in ["health", "armor", "bag", "augment", "haste", "speed", "luck", "power", "range", "size", "binding_echo"]:
		_check(ids.count(id) == 1, "catalogue contains one %s choice" % id)
	for id in [&"haste", &"speed", &"luck", &"power", &"range", &"size"]:
		_fresh()
		_clear(1)
		_check(_buy(id) and _summary()["points"] == 0 and _summary()["ranks"][String(id)] == 1, "%s consumes one research for its own rank" % id)
		var ranks: Dictionary = _summary()["ranks"]
		for other in ranks:
			if other != String(id):
				_check(ranks[other] == 0, "%s choice does not bundle %s" % [id, other])
		_check(not _buy(id), "%s needs another earned point for another rank" % id)

func _test_native_stats_and_geometry() -> void:
	for fixture in [{"id": "haste", "stat": "haste", "gain": 0.06}, {"id": "power", "stat": "power", "gain": 0.06}, {"id": "luck", "stat": "luck", "gain": 0.06}, {"id": "speed", "stat": "move_speed", "gain": 6.0}]:
		_fresh()
		var before := _stats()
		for segment in range(1, 4):
			_clear(segment)
			_check(_buy(StringName(fixture["id"])), "%s funded rank" % fixture["id"])
		_check(not _buy(StringName(fixture["id"])), "%s cap cannot be exceeded" % fixture["id"])
		_check(is_equal_approx(float(_stats().get(fixture["stat"])), float(before.get(fixture["stat"]))), "%s does not retrofit active stats" % fixture["id"])
		Global.start_new_attempt()
		_check(is_equal_approx(float(_stats().get(fixture["stat"])), float(before.get(fixture["stat"])) + float(fixture["gain"])), "%s applies its modest native additive step" % fixture["id"])
	_fresh()
	for segment in range(1, 7):
		_clear(segment)
	for index in range(3):
		_check(_buy(&"range") and _buy(&"size"), "reach and size are independent funded choices")
	Global.start_new_attempt()
	var player := PLAYER.instantiate()
	add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.call("_spawn_melee_slash", Vector2.ZERO, Vector2.RIGHT, 10.0)
	var slash: MeleeSlash = null
	for child in get_children():
		if child is MeleeSlash:
			slash = child
	_check(slash != null and is_equal_approx(slash.arc_radius, 62.0 * 1.15) and is_equal_approx(slash.arc_degrees, 145.0 * 1.15), "real native melee factory scales reach and arc geometry")
	if slash != null:
		slash.free()
	player.call("_spawn_magic_impact", Vector2(100, 100), 10.0)
	var impact: MagicImpact = null
	for child in get_children():
		if child is MagicImpact:
			impact = child
	_check(impact != null and is_equal_approx(impact.radius, 48.0 * 1.15), "real native magic factory scales burst geometry")
	if impact != null:
		impact.free()
	var manager := get_node("/root/ProjectileManager") as ProjectileSimulationManager
	manager.clear_for_run_end()
	player.call("_spawn_ranged_bullet", Vector2.ZERO, Vector2.RIGHT, 10.0)
	_check(manager.active_count() == 1 and is_equal_approx(manager._max_range[0], 520.0 * 1.15) and is_equal_approx(manager._radii[0], 6.0 * 1.15) and is_equal_approx(manager._body_width[0], 4.0 * 1.15), "real managed native projectile carries longer travel and wider collision and visuals")
	player.call("_spawn_ranged_bullet", Vector2.ZERO, Vector2.RIGHT, 10.0)
	_check(manager.active_count() == 2 and is_equal_approx(manager._radii[1], 6.0 * 1.15), "reused native projectile profile does not compound size")
	manager.clear_for_run_end()
	player.free()

func _test_death_farming() -> void:
	_fresh()
	_clear(1)
	_check(_buy(&"health"), "death-farming fixture spends its only Research")
	Global.start_new_attempt()
	var snapshot: Dictionary = Global.get("attempt_city_development").duplicate(true)
	Global.set_followers(100)
	var player := PLAYER.instantiate()
	add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.call("die")
	_check(Global.followers == 80 and not bool(player.get("is_dead")), "real ordinary paid reconstruction restores the character and pays Followers")
	_check(_summary()["earned"] == 1 and _summary()["points"] == 0 and Global.get("attempt_city_development") == snapshot, "reconstruction grants no Research and preserves prepared snapshot")
	player.free()
	for death in range(3):
		Global.set_followers(0)
		Global.begin_peep_continuation()
		var save := SaveData.new()
		Global.write_save(save)
		SaveManager.current_save = save
		Global.apply_save(save)
		_check(_summary()["earned"] == 1 and _summary()["points"] == 0, "terminal decision reload grants no Research")
		_check(Global.accept_peep_continuation(), "repeated terminal continuation accepts once per failed attempt")
		_clear(1)
		_check(_summary()["earned"] == 1 and _summary()["points"] == 0 and _summary()["ranks"]["health"] == 1, "death and same first clear never regenerate Research or erase the chosen improvement")
	_fresh()
	_clear(1)
	_clear(2)
	_check(_buy(&"augment", TRAINED), "failed-attempt preparation fixture owns training")
	Global.set_followers(0)
	Global.begin_peep_continuation()
	var failed_snapshot: Dictionary = Global.get("attempt_city_development").duplicate(true)
	_check(_buy(&"health") and bool(Global.call("select_trained_augment", OTHER)), "pending defeat permits profile preparation and target choice")
	_check(Global.has_pending_peep() and Global.get("attempt_city_development") == failed_snapshot and _stats().max_hp == 100, "preparing after failure cannot revive or improve the failed attempt")
	_check(Global.accept_peep_continuation() and _stats().max_hp == 105 and Global.get_augment_level(OTHER) == 2, "accepting continuation adopts the prepared single choices in its new attempt")

func _take_normal_binding() -> bool:
	var offer := Global.binding_offer()
	for card: Dictionary in offer:
		# Empty slots deliberately prioritize NEW cards before ranks. Consume
		# a real ordinary card from that table instead of assuming a rank exists.
		if card.get("kind", "") in [AugmentBinding.KIND_RANK, AugmentBinding.KIND_NEW]:
			if Global.apply_binding_card(card):
				return true
	return false

func _test_binding_echo() -> void:
	_fresh()
	_clear(1)
	_check(_buy(&"binding_echo"), "conditional rule is one separate funded choice")
	_clear(5)
	_check(Global.attempt_binding_rewards_remaining == 1, "purchase cannot retrofit S5 bonus into an active attempt")
	Global.start_new_attempt()
	Global.on_segment_completed(5)
	_check(Global.attempt_binding_rewards_remaining == 0 and not Global.attempt_binding_echo_claimed, "forged direct S5 callback before reaching it cannot mint Bindings or consume the conditional reward")
	Global.attempt_segment = 5
	_check(Global.begin_segment_completion(5), "Echo fixture saves genuine S5 intent")
	var saved := SaveManager.load_slot(0)
	SaveManager.current_save = saved
	Global.apply_save(saved)
	_check(Global.attempt_binding_rewards_remaining == 2 and Global.attempt_binding_echo_claimed and Global.pending_augment_pick, "genuine recovered S5 completion atomically queues two successive normal Bindings")
	_check(_take_normal_binding(), "first Echo Binding uses ordinary production card application")
	_check(Global.attempt_binding_rewards_remaining == 1 and Global.pending_augment_pick and Global.attempt_binding_offer.is_empty() and Global.attempt_binding_sequence == 1, "first choice consumes only one reward and clears the first table")
	var second := Global.binding_offer()
	Global.save_current_profile()
	saved = SaveManager.load_slot(0)
	SaveManager.current_save = saved
	Global.apply_save(saved)
	_check(Global.attempt_binding_rewards_remaining == 1 and Global.binding_offer() == second and Global.attempt_binding_sequence == 1, "second normal offer and its queue survive reload without reroll")
	Global.on_segment_completed(5)
	_check(Global.attempt_binding_rewards_remaining == 1 and Global.binding_offer() == second, "duplicate S5 callback cannot replace or replenish the second reward")
	_check(_take_normal_binding(), "second Echo Binding uses ordinary production card application")
	_check(not Global.pending_augment_pick and Global.attempt_binding_rewards_remaining == 0, "two choices exhaust the conditional reward")
	Global.on_segment_completed(5)
	_check(not Global.pending_augment_pick and Global.attempt_binding_rewards_remaining == 0, "duplicate completion after both choices cannot mint more Bindings")
	Global.start_new_attempt()
	_check(not Global.attempt_binding_echo_claimed and Global.attempt_binding_sequence == 0, "fresh attempt resets the conditional boundary once")
	var legacy := SaveData.new()
	legacy.attempt_active = true
	legacy.attempt_pending_augment_pick = true
	SaveManager.current_save = legacy
	Global.apply_save(legacy)
	_check(Global.attempt_binding_rewards_remaining == 1, "legacy pending Binding remains exactly one reward")
	legacy.attempt_pending_augment_pick = false
	legacy.attempt_binding_rewards_remaining = 99
	Global.apply_save(legacy)
	_check(Global.attempt_binding_rewards_remaining == 0, "stray malformed queue cannot revive a completed Binding")

func _test_s5_already_claimed_recovery() -> void:
	_fresh()
	Global.attempt_segment = 5
	Global.pending_augment_pick = true
	Global.attempt_binding_rewards_remaining = 1
	Global.attempt_binding_echo_claimed = true
	var retained_offer := Global.binding_offer()
	_check(Global.begin_segment_completion(5), "claimed S5 recovery fixture persists genuine completion intent")
	var saved := SaveManager.load_slot(0)
	SaveManager.current_save = saved
	Global.apply_save(saved)
	_check(Global.attempt_segment == 6 and saved.attempt_segment == 6 and saved.attempt_pending_segment_completion == 0, "genuine claimed S5 recovery advances and clears intent instead of stranding the city")
	_check(Global.attempt_binding_echo_claimed and Global.attempt_binding_rewards_remaining == 1 and Global.pending_augment_pick and Global.binding_offer() == retained_offer, "claimed S5 recovery preserves its already queued reward without replenishment or reroll")
	_fresh()
	_clear(1)
	_check(_buy(&"binding_echo"), "public-cadence fixture prepares Echo")
	Global.start_new_attempt()
	Global.attempt_segment = 5
	Global.on_segment_completed(5)
	_check(Global.attempt_segment == 6 and Global.attempt_binding_rewards_remaining == 1 and Global.attempt_binding_echo_claimed, "public current-S5 cadence settles one base Binding without a genuine pending marker")
	_check(_summary()["earned"] == 1, "public current-S5 cadence cannot mint research or the conditional extra Binding")

func _run() -> void:
	SaveManager.save_dir = "user://city_development_test_%d/" % Time.get_ticks_usec()
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	Global.debug_disable_autosave = true
	StoryDirector.cards_override = 0
	_check(Global.has_method("get_city_development_summary"), "city research backend exists")
	if Global.has_method("get_city_development_summary"):
		_test_s5_already_claimed_recovery()
		_test_earning()
		_test_purchases_and_snapshot()
		_test_transfusion()
		_test_recovery()
		_test_legacy_and_malformed()
		_test_comparison_flag()
		_test_catalogue_choices()
		_test_native_stats_and_geometry()
		_test_death_farming()
		_test_binding_echo()
	SaveManager.current_save = null
	print("CityDevelopmentTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
