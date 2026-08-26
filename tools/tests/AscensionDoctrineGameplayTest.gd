extends Node

const PLAYER_SCRIPT := preload("res://core/actors/player/player.gd")

var _passes: int = 0
var _failures: int = 0
var _saved_rules: Dictionary
var _saved_delta: StatDelta
var _saved_levels: Dictionary
var _saved_augments: Array[StringName]
var _saved_events: Array[String]


func _ready() -> void:
	_saved_rules = Global.attempt_doctrine_rules.duplicate(true)
	_saved_delta = Global.attempt_stat_delta
	_saved_levels = Global.attempt_augment_levels.duplicate(true)
	_saved_augments = Global.permanent_augment_ids.duplicate()
	_saved_events = Global.attempt_doctrine_events.duplicate()
	_test_method_rules()
	_test_doctrine_rules()
	_test_apotheosis_rules()
	_test_player_consumers()
	_restore()
	print("AscensionDoctrineGameplayTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _reset() -> void:
	Global.attempt_doctrine_rules = {}
	Global.attempt_stat_delta = null
	Global.attempt_augment_levels = {}
	Global.attempt_doctrine_events.clear()
	Global.permanent_augment_ids = [&"augment_blink_hex", &"", &""]


func _apply(id: StringName) -> void:
	var definition: MajorChoiceDef = Global.major_choice_db.get_def(id)
	_check(definition != null, "definition loads: %s" % String(id))
	if definition == null:
		return
	_check(not definition.effects.is_empty(), "definition has gameplay effects: %s" % String(id))
	for effect in definition.effects:
		if effect != null:
			effect.apply(Global)


func _test_method_rules() -> void:
	_reset()
	_apply(&"doctrine_method_open_circuit")
	_check(is_equal_approx(Global.attempt_stat_delta.haste, 0.20), "Open Circuit grants Haste")
	_check(is_equal_approx(float(Global.get_doctrine_rule(&"active_augment_cooldown_mul", 1.0)), 0.70), "Open Circuit shortens active cooldown")
	_check(is_equal_approx(Global.doctrine_active_cooldown(10.0), 7.0), "cooldown helper consumes Open Circuit")
	Global.notify_active_augment_used(0)
	_check(Global.active_augment_slot_blocked(1), "Open Circuit cross-locks another slot")
	_check(not Global.active_augment_slot_blocked(0), "Open Circuit does not self-lock")

	_reset()
	_apply(&"doctrine_method_frame_of_ash")
	_check(is_equal_approx(Global.attempt_stat_delta.power, 0.30), "Frame of Ash grants Power")
	_check(is_equal_approx(Global.attempt_stat_delta.move_speed, 15.0), "Frame of Ash grants movement")
	_check(is_equal_approx(float(Global.get_doctrine_rule(&"max_hp_mul", 1.0)), 0.75), "Frame of Ash reduces maximum health")
	var frame_stats := Stats.new()
	frame_stats.max_hp = 100.0
	Global.apply_attempt_modifiers_to_stats(frame_stats)
	frame_stats.max_hp += 40.0 # stand-in for later inventory/set/Burden HP
	_check(Global.has_method("apply_doctrine_final_stat_multipliers"), "Global exposes final Doctrine stat pricing")
	if Global.has_method("apply_doctrine_final_stat_multipliers"):
		Global.call("apply_doctrine_final_stat_multipliers", frame_stats)
	_check(is_equal_approx(frame_stats.max_hp, 105.0), "maximum-health price includes downstream HP sources")

	_reset()
	_apply(&"doctrine_method_black_archive")
	_check(is_equal_approx(Global.attempt_stat_delta.luck, 0.20), "Black Archive grants Luck")
	_check(int(Global.get_doctrine_rule(&"secondary_reward_rolls", 0)) == 1, "Black Archive adds a secondary reward")
	_check(is_equal_approx(float(Global.get_doctrine_rule(&"threat_gain_mul", 1.0)), 1.25), "Black Archive raises Threat")
	_check(is_equal_approx(float(ThreatDirector.call("apply_doctrine_threat", 80.0)), 100.0), "Threat Director consumes Black Archive")
	var saved_segment: int = Global.attempt_segment
	var saved_resonance: float = ThreatDirector.resonance
	var saved_phase: StringName = ThreatDirector.segment_phase
	Global.attempt_segment = 4
	ThreatDirector.resonance = 0.60
	ThreatDirector.segment_phase = &"recon"
	Global.attempt_doctrine_rules = {}
	Global.attempt_doctrine_threat_debt = 0.0
	ThreatDirector.call("_recompute", true)
	var baseline_hp_mul: float = ThreatDirector.enemy_hp_mul
	var baseline_spawn_mul: float = ThreatDirector.spawn_interval_mul
	_apply(&"doctrine_method_black_archive")
	Global.attempt_doctrine_threat_debt = 25.0
	ThreatDirector.call("_recompute", true)
	_check(ThreatDirector.enemy_hp_mul > baseline_hp_mul, "Threat Doctrine increases authoritative enemy durability")
	_check(ThreatDirector.spawn_interval_mul < baseline_spawn_mul, "Threat debt accelerates authoritative spawns")
	Global.attempt_segment = saved_segment
	ThreatDirector.resonance = saved_resonance
	ThreatDirector.segment_phase = saved_phase
	Global.attempt_doctrine_threat_debt = 0.0
	_check(Global.has_method("grant_doctrine_secondary_rewards"), "Global exposes the Black Archive reward delivery")
	if Global.has_method("grant_doctrine_secondary_rewards"):
		var saved_inventory: Inventory = Global.run_inventory
		var saved_bag: BagInventory = Global.run_bag
		Global.run_inventory = Inventory.new()
		Global.run_bag = BagInventory.new()
		_check(int(Global.call("grant_doctrine_secondary_rewards", &"test-secondary")) == 1, "Black Archive delivers one extra exploration item")
		var reward: ItemInstance = null
		for slot_item in Global.run_bag.slots:
			if slot_item != null:
				reward = slot_item
				break
		_check(reward != null and reward.polarity == ItemInstance.Polarity.POS, "Black Archive reward is always a Gift, never a curse")
		_check(reward != null and reward.rarity == clampi(Global.attempt_segment / 2, 1, 5), "Black Archive reward uses the authored segment rarity")
		_check(reward != null and is_equal_approx(reward.best_pct, 0.35), "Black Archive reward uses the authored positive roll")
		Global.run_inventory = saved_inventory
		Global.run_bag = saved_bag


func _test_doctrine_rules() -> void:
	_reset()
	_apply(&"doctrine_choir_of_recurrence")
	_check(Global.get_augment_level(&"augment_blink_hex") == 3, "Choir adds two augment levels")
	_check(is_equal_approx(Global.attempt_stat_delta.power, -0.15), "Choir taxes weapon Power")

	_reset()
	_apply(&"doctrine_vessel_without_mercy")
	_check(is_equal_approx(Global.doctrine_healing_multiplier(&"generic"), 0.50), "Vessel halves ordinary healing")
	_check(is_equal_approx(Global.doctrine_healing_multiplier(&"exit_rite"), 1.60), "Vessel amplifies Rite healing")
	_check(is_equal_approx(float(Global.get_doctrine_rule(&"rite_stun_bonus_seconds", 0.0)), 0.10), "Vessel strengthens seal stun")

	_reset()
	_apply(&"doctrine_pilgrim_engine")
	_check(is_equal_approx(Global.attempt_exit_hold_mul, 1.25), "Pilgrim lengthens Rite channel")
	_check(int(Global.get_doctrine_rule(&"rite_safeguard_capacity", 3)) == 5, "Pilgrim raises safeguard capacity")
	_check(int(Global.get_doctrine_rule(&"rite_safeguard_source_multiplier", 1)) == 2, "Pilgrim doubles exploration charges")
	Global.attempt_exit_hold_mul = 1.0


func _test_apotheosis_rules() -> void:
	_reset()
	_apply(&"doctrine_apotheosis_perfected_engine")
	_check(Global.get_augment_level(&"augment_blink_hex") == 3, "Perfected Engine adds two augment levels")
	_check(is_equal_approx(Global.attempt_stat_delta.power, 0.35), "Perfected Engine grants Power")
	_check(bool(Global.get_doctrine_rule(&"force_augment_identity", false)), "Perfected Engine seals augment identity")

	_reset()
	_apply(&"doctrine_apotheosis_law_of_admission")
	_check(int(Global.get_doctrine_rule(&"rite_initial_seals", 0)) == 1, "Law starts with one seal")
	_check(is_equal_approx(float(Global.get_doctrine_rule(&"rite_burst_count_mul", 1.0)), 1.50), "Law enlarges scripted bursts")

	_reset()
	_apply(&"doctrine_apotheosis_manufactured_witness")
	_check(bool(Global.get_doctrine_rule(&"manufactured_witness", false)), "Manufactured Witness enables rescue")
	var saved_followers: int = Global.followers
	var saved_segment: int = Global.attempt_segment
	var saved_used: int = Global.attempt_witness_used_segment
	var saved_debt: float = Global.attempt_doctrine_threat_debt
	Global.attempt_segment = 9
	Global.attempt_witness_used_segment = 0
	Global.attempt_doctrine_threat_debt = 0.0
	Global.set_followers(150)
	var doctrine_events: Array[String] = []
	var event_callback := func(_event_id: StringName, label: String) -> void:
		doctrine_events.append(label)
	RunEvents.doctrine_event_recorded.connect(event_callback)
	_check(Global.try_consume_manufactured_witness(), "Witness prevents the first eligible lethal event")
	_check(Global.followers == 50, "Witness consumes exactly 100 Followers")
	_check(is_equal_approx(Global.attempt_doctrine_threat_debt, 25.0), "Witness adds 25 Threat debt")
	_check(doctrine_events == ["WITNESS EXPENDED"], "Witness records its expenditure in the Run Sheet event channel")
	_check(not Global.try_consume_manufactured_witness(), "Witness can trigger only once per segment")
	RunEvents.doctrine_event_recorded.disconnect(event_callback)
	Global.attempt_segment = saved_segment
	Global.attempt_witness_used_segment = saved_used
	Global.attempt_doctrine_threat_debt = saved_debt
	Global.set_followers(saved_followers)


func _test_player_consumers() -> void:
	_reset()
	_apply(&"doctrine_vessel_without_mercy")
	var player := PLAYER_SCRIPT.new()
	player.max_hp = 100.0
	player.hp = 50.0
	player.heal(10.0)
	_check(is_equal_approx(player.hp, 55.0), "player applies the ordinary-healing tithe")
	player.heal(10.0, &"exit_rite")
	_check(is_equal_approx(player.hp, 71.0), "player applies the amplified Rite healing")
	Global.attempt_doctrine_rules["ritual_healing_mul"] = 0.60
	player.hp = 0.0
	player.wardstone_full_restore()
	_check(is_equal_approx(player.hp, 60.0), "Wardstone restoration routes through ritual healing")
	player.free()

	_reset()
	_apply(&"doctrine_apotheosis_manufactured_witness")
	var saved_followers: int = Global.followers
	var saved_segment: int = Global.attempt_segment
	var saved_used: int = Global.attempt_witness_used_segment
	Global.attempt_segment = 9
	Global.attempt_witness_used_segment = 0
	Global.set_followers(150)
	var witness_player := PLAYER_SCRIPT.new()
	witness_player.max_hp = 100.0
	witness_player.hp = 0.0
	_check(witness_player.has_method("_try_doctrine_death_intercept"), "player exposes the Witness death intercept")
	if witness_player.has_method("_try_doctrine_death_intercept"):
		_check(bool(witness_player.call("_try_doctrine_death_intercept")), "player consumes Witness on lethal damage")
		_check(is_equal_approx(witness_player.hp, 50.0), "Witness restores half maximum health")
	witness_player.free()
	Global.attempt_segment = saved_segment
	Global.attempt_witness_used_segment = saved_used
	Global.set_followers(saved_followers)


func _restore() -> void:
	Global.attempt_doctrine_rules = _saved_rules
	Global.attempt_stat_delta = _saved_delta
	Global.attempt_augment_levels = _saved_levels
	Global.permanent_augment_ids = _saved_augments
	Global.attempt_doctrine_events = _saved_events
	Global.attempt_exit_hold_mul = 1.0


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
