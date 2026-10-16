extends Node

# Behavioral fixture: removing a flag check, filtering a whole reward, or
# sharing a Gospel contribution key breaks an observable assertion here.
# Run this scene with no user args, each flag separately, and all four.
const EXPERIMENTS := preload("res://core/systems/balance/CityBalanceExperiments.gd")
const PLAYER := preload("res://core/actors/player/player.tscn")
const ENEMY := preload("res://core/actors/enemy/enemy.tscn")
var _passes := 0
var _failures := 0
var _args := OS.get_cmdline_user_args()

class GospelHost extends Node2D:
	func refresh_run_state() -> void:
		pass

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	# Neither these real producers nor any incidental callback may save a profile.
	SaveManager.save_dir = "user://city_farming_test_%d/" % Time.get_ticks_usec()
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	Global.debug_disable_autosave = true
	_test_independent_flag_metadata()
	Global.start_new_attempt()
	ThreatDirector.set_process(false)
	_test_drop_probability()
	_test_rarity()
	await _test_gospel([1, 3, 2])
	await _test_gospel([3, 1, 2])
	await _test_crossed_gospel(false)
	await _test_crossed_gospel(true)
	_test_pending_pressure_freeze()
	await _test_metadata()
	print("CityFarmingExperimentsTest: %d passed, %d failed; args=%s" % [_passes, _failures, str(_args)])
	get_tree().quit(1 if _failures else 0)

func _test_independent_flag_metadata() -> void:
	var saved := EXPERIMENTS._arguments.duplicate()
	var flags := {
		"no_overtime_drop_bonus": "--city-no-overtime-drop-bonus",
		"no_overtime_rarity_bonus": "--city-no-overtime-rarity-bonus",
		"gospel_strongest_rewards": "--city-gospel-strongest-rewards",
		"no_permanent_development": "--city-no-permanent-development",
	}
	EXPERIMENTS._arguments = PackedStringArray()
	var baseline := EXPERIMENTS.metadata()
	_check(baseline.size() == flags.size() and baseline.values().all(func(value: Variant) -> bool: return value == false), "baseline explicitly disables all four independent comparisons")
	for selected in flags:
		EXPERIMENTS._arguments = PackedStringArray([String(flags[selected])])
		var expected := {}
		for key in flags:
			expected[key] = key == selected
		_check(EXPERIMENTS.metadata() == expected, "selecting %s preserves every other comparison" % selected)
	EXPERIMENTS._arguments = saved

func _test_drop_probability() -> void:
	var enemy := ENEMY.instantiate() as EnemyActor
	add_child(enemy)
	enemy.set_process(false)
	enemy.set_physics_process(false)
	enemy.drop_chance = 0.25
	var drops := EnemyDrops.new()
	drops.setup(enemy)
	ThreatDirector.gate_unsealed = true
	ThreatDirector.resonance = 1.0
	ThreatDirector.overtime = 3.0
	Global.run_luck = 0.0
	var omit := _args.has("--city-no-overtime-drop-bonus")
	# Hand-calculated R=1, OT=3 fixture: 0.25 vs 0.3713007566.
	_sample_drop(drops, 0.25 if omit else 0.3713007566, "only overtime drop probability is omitted")
	Global.run_luck = 3.0
	_sample_drop(drops, 0.325 if omit else 0.4826909836, "positive Luck still bends probability")
	ThreatDirector.resonance = 0.0
	_sample_drop(drops, 0.065 if omit else 0.0965381967, "Resonance pre-multiplier is preserved")
	ThreatDirector.gate_unsealed = false
	ThreatDirector.resonance = 1.0
	_sample_drop(drops, 0.325, "sealed gate ignores overtime for every variant")
	_check(drops.finalize_rarity(18, 4, 3) == 25, "base, elite and threat rarity remain uncapped")
	enemy.free()

func _sample_drop(drops: EnemyDrops, threshold: float, label: String) -> void:
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = 81919
	Global._rng.seed = 81919
	var actual := 0
	var expected := 0
	for i in range(4096):
		actual += int(drops._roll_item_drop())
		expected += int(expected_rng.randf() <= threshold)
	_check(actual == expected, "%s: %d/4096, expected %d" % [label, actual, expected])

func _test_rarity() -> void:
	ThreatDirector.reset_run_state()
	Global.attempt_segment = 9
	ThreatDirector.gate_unsealed = true
	ThreatDirector.resonance = 1.0
	ThreatDirector.segment_phase = &"ascension"
	ThreatDirector.overtime = 3.0
	ThreatDirector._recompute()
	var expected := 3 if _args.has("--city-no-overtime-rarity-bonus") else 6
	_check(ThreatDirector.loot_rarity_bonus == expected, "segment 9 heat and OT=3 rarity bonus is %d (got %d)" % [expected, ThreatDirector.loot_rarity_bonus])
	ThreatDirector.overtime = 0.0
	ThreatDirector._recompute()
	_check(ThreatDirector.loot_rarity_bonus == 3, "segment and heat rarity remain when overtime is zero")
	ThreatDirector.gate_unsealed = false
	ThreatDirector.overtime = 3.0
	ThreatDirector._recompute()
	_check(ThreatDirector.loot_rarity_bonus == 3, "sealed gate keeps segment and heat rarity")

func _item(slot: int, id: StringName) -> ItemInstance:
	var data := ItemData.new()
	data.id = "city_fixture_%d" % slot
	data.equip_slot = slot as ItemData.EquipSlot
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	var item := ItemInstance.from_roll(data, 0, ItemInstance.Polarity.POS, 0.0)
	item.manifestation_id = id
	return item

func _test_gospel(ticks: Array) -> void:
	ThreatDirector.reset_run_state()
	ThreatDirector._on_resonance_changed(1.0)
	Global.run_inventory = Inventory.new()
	var gospel_slots := [0, 5, 6]
	for slot in gospel_slots:
		Global.run_inventory.set_item(slot, _item(slot, &"overtime_gospel"))
	var host := GospelHost.new()
	add_child(host)
	var runner := ManifestationRunner.new()
	host.add_child(runner)
	runner.set_process(false)
	runner.state.set_process(false)
	var strongest := _args.has("--city-gospel-strongest-rewards")
	var strongest_slot: int = gospel_slots[ticks.find(3)]
	var pressure_tags: Dictionary = {}
	var note_pressure := func(tag: String, seconds: float, _clock: float, _ot: float) -> void:
		pressure_tags[tag] = float(pressure_tags.get(tag, 0.0)) + seconds
	RunEvents.overtime_pressure_injected.connect(note_pressure)
	for effect: Node in runner._all_effects():
		effect.set_process(false)
		if effect is ManifestationEffect and effect.manifestation_id() == &"overtime_gospel":
			for i in range(int(ticks[gospel_slots.find(effect.slot_index)])):
				effect.call("_preach")
			if effect.slot_index == 0:
				_check(is_equal_approx(runner.get_power_multiplier(), 1.07 if int(ticks[0]) == 1 else 1.2415), "one Gospel retains its full Power")
				_check(is_equal_approx(runner.state.bonus_luck(), 0.06 if int(ticks[0]) == 1 else 0.18), "one Gospel retains its full Luck")
			elif effect.slot_index == 5:
				var pair_power := 1.1992025 if int(ticks[0]) == 1 else 1.2849525
				_check(is_equal_approx(runner.get_power_multiplier(), 1.2415 if strongest else pair_power), "two unequal Gospels use the selected Power policy")
				_check(is_equal_approx(runner.state.bonus_luck(), 0.18 if strongest else 0.24), "two unequal Gospels use the selected Luck policy")
	RunEvents.overtime_pressure_injected.disconnect(note_pressure)
	Global.run_inventory.set_item(1, _item(1, &"anchor_rite"))
	Global.run_inventory.set_item(2, _item(2, &"anchor_rite"))
	Global.run_inventory.set_item(7, _item(7, &"heretical_cartography"))
	runner.refresh_effects(Global.run_inventory)
	for effect: ManifestationEffect in runner._all_effects():
		effect.set_process(false)
		if effect.manifestation_id() == &"heretical_cartography":
			effect.call("on_building_entered", true)
	runner.state.stability = 1.0
	var baseline := 1.2443224941 if int(ticks[0]) == 1 else 1.3332988378
	_check(is_equal_approx(runner.get_power_multiplier(), 1.2415 if strongest else baseline), "unequal Gospel Power ticks %s: %.9f" % [str(ticks), runner.get_power_multiplier()])
	_check(is_equal_approx(runner.state.bonus_luck(), 0.24 if strongest else 0.42), "Gospel Luck plus independent Cartography: %.6f" % runner.state.bonus_luck())
	_check(is_equal_approx(runner.consume_attack_bonus(), 1.495), "other duplicate Manifestations keep their falloff: %.6f" % runner.consume_attack_bonus())
	_check(pressure_tags.size() == 3 and is_equal_approx(ThreatDirector._injected_seconds, 140.0), "all three Gospel copies inject their own pressure: %s" % str(pressure_tags))
	_check(is_equal_approx(ThreatDirector.belief_defiance, 0.36), "Gospel belief defiance remains the existing last publisher value")
	Global.run_inventory.set_item(strongest_slot, null)
	runner.refresh_effects(Global.run_inventory)
	await get_tree().process_frame
	if strongest:
		_check(is_equal_approx(runner.get_power_multiplier(), 1.1505), "removing strongest exposes next Gospel Power")
	_check(is_equal_approx(runner.state.bonus_luck(), 0.18 if strongest else 0.24), "removing strongest preserves next Luck and Cartography")
	for slot in gospel_slots:
		Global.run_inventory.set_item(slot, null)
	runner.refresh_effects(Global.run_inventory)
	await get_tree().process_frame
	_check(is_equal_approx(runner.state.bonus_luck(), 0.06), "all Gospel cleanup leaves the other instance's Luck")
	host.free()

# Rank can reverse which copy has the best Power and which has the best Luck.
# Each reward channel takes its own maximum, without a shared winner metric.
func _test_crossed_gospel(reverse: bool) -> void:
	ThreatDirector.reset_run_state()
	ThreatDirector._on_resonance_changed(1.0)
	Global.run_inventory = Inventory.new()
	var luck_slot := 5 if reverse else 0
	var power_slot := 0 if reverse else 5
	for slot in [0, 5]:
		var inst := _item(slot, &"overtime_gospel")
		inst.rarity = 14 if slot == luck_slot else 0
		Global.run_inventory.set_item(slot, inst)
	var host := GospelHost.new()
	add_child(host)
	var runner := ManifestationRunner.new()
	host.add_child(runner)
	runner.set_process(false)
	runner.state.set_process(false)
	for effect: ManifestationEffect in runner._all_effects():
		effect.set_process(false)
		var count := 2 if effect.slot_index == luck_slot else 3
		for i in range(count):
			effect.call("_preach")
	var strongest := _args.has("--city-gospel-strongest-rewards")
	var baseline := 1.3909766 if reverse else 1.3906266
	_check(is_equal_approx(runner.get_power_multiplier(), 1.2415 if strongest else baseline), "crossed-strength copies preserve selected Power policy (reverse=%s): %.9f" % [str(reverse), runner.get_power_multiplier()])
	_check(is_equal_approx(runner.state.bonus_luck(), 0.192 if strongest else 0.372), "crossed-strength copies independently preserve best Luck: %.6f" % runner.state.bonus_luck())
	_check(is_equal_approx(ThreatDirector._injected_seconds, 120.0), "crossed-strength copies both inject their full pressure")
	# Exercise both kinds of removal across the two slot orders.
	Global.run_inventory.set_item(luck_slot if reverse else power_slot, null)
	runner.refresh_effects(Global.run_inventory)
	await get_tree().process_frame
	_check(is_equal_approx(runner.get_power_multiplier(), 1.2415 if reverse else 1.2408), "crossed-strength removal keeps the surviving Power")
	_check(is_equal_approx(runner.state.bonus_luck(), 0.18 if reverse else 0.192), "crossed-strength removal keeps the surviving Luck")
	host.free()

# Pending continuation freezes the root director even after presentation unpauses
# the tree. Accepting a new city resumes it through the ordinary process path.
func _test_pending_pressure_freeze() -> void:
	ThreatDirector.reset_run_state()
	ThreatDirector._on_resonance_changed(1.0)
	ThreatDirector._process(0.2)
	ThreatDirector._process(0.1)
	Global.set_followers(0)
	Global.begin_peep_continuation()
	_check(Global.has_pending_peep(), "fixture creates a real terminal continuation")
	var frozen := ThreatDirector.balance_snapshot()
	var frozen_remainder: float = ThreatDirector._tick
	ThreatDirector._process(0.1)
	ThreatDirector._process(1.0)
	_check(ThreatDirector.balance_snapshot() == frozen and is_equal_approx(ThreatDirector._tick, frozen_remainder), "pending continuation freezes root pressure clocks, outputs and tick remainder")
	_check(Global.accept_peep_continuation(), "fixture accepts the pending city once")
	ThreatDirector._on_resonance_changed(1.0)
	ThreatDirector._process(0.2)
	_check(ThreatDirector._unseal_time > 0.0, "new attempt resumes director processing after continuation")

func _test_metadata() -> void:
	Global.run_inventory = Inventory.new()
	var player := PLAYER.instantiate()
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	BalanceRecorder.report_directory = "user://city_farming_captures_%d" % Time.get_ticks_usec()
	BalanceRecorder.record_headless = true
	BalanceRecorder.begin_gameplay(player)
	BalanceRecorder.set_process(false)
	var selected: Dictionary = BalanceRecorder.get_summary().metadata.get("city_farming_experiments", {})
	var expected := {
		"no_overtime_drop_bonus": _args.has("--city-no-overtime-drop-bonus"),
		"no_overtime_rarity_bonus": _args.has("--city-no-overtime-rarity-bonus"),
		"gospel_strongest_rewards": _args.has("--city-gospel-strongest-rewards"),
		"no_permanent_development": _args.has("--city-no-permanent-development"),
	}
	_check(selected == expected, "capture metadata declares each selected flag as plain data: %s" % str(selected))
	BalanceRecorder.end_capture("suspended")
	BalanceRecorder.flush_reports()
	var capture_path: String = BalanceRecorder.capture_directory
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(capture_path.path_join("summary.json")))
	_check(saved is Dictionary and saved.metadata.get("city_farming_experiments", {}) == expected, "persisted capture carries independent selected flags")
	for file in ["events.jsonl", "summary.json", "report.md", "segments.csv"]:
		DirAccess.remove_absolute(capture_path.path_join(file))
	DirAccess.remove_absolute(capture_path)
	player.free()
