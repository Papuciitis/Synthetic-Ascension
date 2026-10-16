extends Node

## Controlled mechanics comparison, not a city completion or fun test.
## Uses the real player's stat pass, AugmentRunner, Tesla and EnemyCombat.
## Only the stationary crowd and deterministic effect clock are fixtures.
## Run headless; CITY_DEVELOPMENT_PROBE_OUT selects the JSON destination.
## For a real matched city run, launch this scene windowed with user argument
## --city-development-human=baseline|trained|defensive|offensive. No input is automated.
const PLAYER := preload("res://core/actors/player/player.tscn")
const EXPERIMENTS := preload("res://core/systems/balance/CityBalanceExperiments.gd")
const WRITER := preload("res://core/systems/telemetry/BalanceCaptureWriter.gd")
const SPAWN := preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const TESLA := &"augment_tesla_aura"
const OTHER := &"augment_stamina_core"
const NO_DEVELOPMENT := "--city-no-permanent-development"
const SEED := 81919
const STEP := 1.0 / 60.0
const SECONDS := 10.0
const CROWD_COUNT := 40
const CROWD_RADIUS := 260.0
const CROWD_HP := 10000.0
const VARIANTS := ["baseline", "trained", "defensive", "offensive"]
const BUILDS := [
	{"id": "early_start", "item_rank": 1, "earned_levels": 0, "absolute_level": 0},
	{"id": "late_fixed_level", "item_rank": 12, "earned_levels": 0, "absolute_level": 12},
	{"id": "late_equal_earned", "item_rank": 12, "earned_levels": 11, "absolute_level": 0},
]
const STAT_FIELDS := ["max_hp", "armor", "move_speed", "power", "haste", "luck"]

var _passes := 0
var _failures := 0
var _crowd: Array[int] = []
var _original_args := PackedStringArray()
var _isolated_dir := ""
var _report := {}

func _enter_tree() -> void:
	# No active slot is bound, even while the real attempt reset runs.
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	Global.debug_disable_autosave = true
	_isolated_dir = "user://city_development_probe_%d/" % Time.get_ticks_usec()
	SaveManager.save_dir = _isolated_dir + "profiles/"
	BalanceRecorder.report_directory = _isolated_dir + "balance/"
	PerformanceFlightRecorder.report_directory = _isolated_dir + "performance/"

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _profile(variant: String) -> Dictionary:
	var ten_choices := variant != "trained"
	var claimed: Array[int] = []
	for segment in range(1, 11 if ten_choices else 2):
		claimed.append(segment)
	var ranks := {"health": 0, "armor": 0, "bag": 0, "augment": 1,
		"power": 0, "haste": 0, "luck": 0, "speed": 0, "range": 0, "size": 0}
	if variant in ["baseline", "defensive"]:
		for id in ["health", "armor", "bag"]:
			ranks[id] = 3
	elif variant == "offensive":
		for id in ["power", "haste", "size"]:
			ranks[id] = 3
	return {"revision": 1, "claimed_segments": claimed,
		"ranks": ranks, "augment_id": String(TESLA)}

func _prepare(variant: String, build: Dictionary) -> void:
	EXPERIMENTS._arguments = _original_args.duplicate()
	while EXPERIMENTS._arguments.has(NO_DEVELOPMENT):
		EXPERIMENTS._arguments.remove_at(EXPERIMENTS._arguments.find(NO_DEVELOPMENT))
	if variant == "baseline":
		EXPERIMENTS._arguments.append(NO_DEVELOPMENT)
	# Explicit fixture grants: no Rite callback or earned-progress claim.
	Global.set("city_development", _profile(variant))
	Global.owned_augment_ids = [TESLA, OTHER]
	Global.permanent_augment_ids = [TESLA, &"", &""]
	Global.selected_race_id = "human"
	Global.selected_style_id = "ranged"
	Global.selected_weapon_id = "ranged"
	Global.debug_dev_mode = false
	Global.debug_dev_segment = false
	Global.debug_player_god_mode = false
	Global.start_new_attempt()
	Global.attempt_world_seed = SEED
	Global._rng.seed = SEED
	seed(SEED)
	Global.pending_augment_pick = false
	Global.set_followers(0)
	var floor_level := Global.get_augment_level(TESLA)
	var absolute_level := int(build["absolute_level"])
	Global.set_augment_level(TESLA, absolute_level if absolute_level > 0 else floor_level + int(build["earned_levels"]))
	var lens := Global.get_item_data("conduit_lens")
	if lens != null:
		var item := ItemInstance.from_roll(lens, int(build["item_rank"]), ItemInstance.Polarity.POS, 0.0, false)
		Global.run_inventory.set_item(ItemData.EquipSlot.POWER, item)

func _freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_freeze(child)

func _stats(player: Node) -> Dictionary:
	var stats := player.get("stats") as Stats
	var result := {}
	for field in STAT_FIELDS:
		result[field] = stats.get(field)
	return result

func _augment_passives(level: int) -> Dictionary:
	# Training changes the whole authored augment, including its passive Haste.
	# Read that passive through its production level application, rather than
	# assuming the starting level affects only Tesla's damage callback.
	var data := Global.augment_db.get(TESLA) as AugmentData
	var stats := Stats.new()
	var before := stats.copy()
	data.apply_to_stats_at_level(stats, level)
	var result := {}
	for field in STAT_FIELDS:
		result[field] = float(stats.get(field)) - float(before.get(field))
	return result

func _native_projectile(player: Node) -> Dictionary:
	# Observe the projectile emitted by the real player hook, including later
	# range/size consumers. No target exists and the projectile is never stepped.
	ProjectileManager.clear_for_run_end()
	player.call("_spawn_ranged_bullet", Vector2.ZERO, Vector2.RIGHT, AugmentScaling.native_d(player))
	var profile := player.get("_managed_hit_profile") as HitProfileAdapter
	var count := ProjectileManager.active_count()
	_check(count == 1 and profile != null, "prepared player emits one real managed native projectile")
	var result := {}
	if count == 1 and profile != null:
		var radii: PackedFloat32Array = ProjectileManager.get("_radii")
		var ranges: PackedFloat32Array = ProjectileManager.get("_max_range")
		result = {"damage": profile.damage, "collision_radius": float(radii[0]), "max_range": float(ranges[0]),
			"profile_collision_radius": profile.collision_radius, "profile_max_range": profile.max_range}
	ProjectileManager.clear_for_run_end()
	return result

func _spawn_crowd() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for _i in range(CROWD_COUNT):
		var at := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * CROWD_RADIUS
		_crowd.append(EnemyWorld.create_enemy(SPAWN.new(&"city_development_dummy", "", at, CROWD_HP, 0.0, 4.0, 0)))

func _clear_crowd() -> void:
	for handle in _crowd:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"city_development_probe")
	_crowd.clear()

func _measure(variant: String, build: Dictionary) -> Dictionary:
	_prepare(variant, build)
	var player = PLAYER.instantiate()
	add_child(player)
	_freeze(player)
	player.refresh_run_state()
	_freeze(player)
	var runner: Node = player.get_node("AugmentRunner")
	var effect := runner.call("effect_for", TESLA) as TeslaAuraEffect
	_check(effect != null, "%s %s binds the production Tesla effect" % [variant, build["id"]])
	if effect == null:
		player.free()
		return {}
	# Presentation does not affect damage; avoid accumulating unprocessed VFX
	# while the production damage callback is stepped synchronously.
	effect.vfx_arc_scene = null
	effect.vfx_pulse_scene = null
	effect._t = 0.0
	var native_projectile := _native_projectile(player)
	_spawn_crowd()
	BalanceRecorder.record_headless = true
	BalanceRecorder.set_process(false)
	BalanceRecorder.begin_gameplay(player)
	var metadata: Dictionary = Global.call("city_development_capture_metadata")
	var row := {"variant": variant, "build": build.duplicate(true), "stats": _stats(player),
		"native_hit": AugmentScaling.native_d(player), "augment_level": Global.get_augment_level(TESLA),
		"augment_passives": _augment_passives(Global.get_augment_level(TESLA)),
		"native_projectile": native_projectile,
		"effect_level": int(effect.get_meta("augment_level", 0)), "bag_slots": Global.run_bag.get_slot_count(),
		"development": metadata, "farming_experiments": EXPERIMENTS.metadata(),
		"effect": {"radius": effect.current_radius(), "tick_interval": effect.current_tick_interval(), "max_targets": effect.max_targets},
		"equipment": {"id": "conduit_lens", "rank": build["item_rank"], "polarity": 1, "roll": 0.0, "manifestation": ""}}
	_check(int(row["effect_level"]) == int(row["augment_level"]), "%s %s runner applies the effective level" % [variant, build["id"]])
	_check(bool(metadata.get("enabled", true)) == (variant != "baseline"), "%s capture reports effective development policy" % variant)
	_check(metadata.get("profile", {}).get("ranks", {}).get("augment", 0) == 1 and metadata.get("attempt", {}).get("ranks", {}).get("augment", 0) == 1,
		"%s capture preserves the trained profile and frozen attempt" % variant)
	var before: Dictionary = row["stats"].duplicate(true)
	for _i in range(int(SECONDS / STEP)):
		effect._process(STEP)
		BalanceRecorder._process(STEP)
	var damage := 0.0
	var alive := 0
	for handle in _crowd:
		if EnemyWorld.is_valid_handle(handle):
			alive += 1
			damage += CROWD_HP - EnemyWorld.get_health(handle)
	_check(alive == CROWD_COUNT, "all stationary crowd targets remain alive")
	row["damage"] = damage
	row["damage_per_second"] = damage / SECONDS
	row["native_hits_per_second"] = damage / SECONDS / float(row["native_hit"])
	_check(damage > 0.0 and _stats(player) == before, "%s %s deals real damage without changing the prepared stats" % [variant, build["id"]])
	var summary: Dictionary = BalanceRecorder.get_summary()
	_check(summary.get("metadata", {}).get("city_development", {}) == WRITER.json_safe(metadata), "recorder captures sanitized development state")
	BalanceRecorder.end_capture("suspended")
	BalanceRecorder.flush_reports()
	row["balance_capture"] = BalanceRecorder.capture_directory
	var persisted: Variant = JSON.parse_string(FileAccess.get_file_as_string(BalanceRecorder.capture_directory.path_join("summary.json")))
	# JSON numbers parse as floats, while the live snapshot retains integers.
	# Compare both sides after the same serialization boundary.
	var expected_persisted: Variant = JSON.parse_string(JSON.stringify(WRITER.json_safe(metadata)))
	_check(persisted is Dictionary and persisted.get("metadata", {}).get("city_development", {}) == expected_persisted, "persisted comparison retains development metadata")
	_clear_crowd()
	player.free()
	return row

func _check_rows(rows: Array) -> void:
	for build in BUILDS:
		var matched := {}
		for row in rows:
			if row.get("build", {}).get("id", "") == build["id"]:
				matched[row["variant"]] = row
		_check(matched.size() == VARIANTS.size(), "%s has all four matched variants" % build["id"])
		if matched.size() != VARIANTS.size():
			continue
		var baseline: Dictionary = matched["baseline"]
		var trained: Dictionary = matched["trained"]
		var defensive: Dictionary = matched["defensive"]
		var offensive: Dictionary = matched["offensive"]
		_check(is_equal_approx(float(defensive["stats"]["max_hp"]), float(trained["stats"]["max_hp"]) + 15.0)
			and is_equal_approx(float(defensive["stats"]["armor"]), float(trained["stats"]["armor"]) + 3.0), "%s defensive ten-choice allocation applies HP+15 and armor+3 through the real stat pass" % build["id"])
		var training_matches := true
		for field in STAT_FIELDS:
			var passive_delta := float(trained["augment_passives"][field]) - float(baseline["augment_passives"][field])
			training_matches = training_matches and is_equal_approx(float(trained["stats"][field]), float(baseline["stats"][field]) + passive_delta)
		_check(training_matches and int(baseline["bag_slots"]) == 16 and int(trained["bag_slots"]) == 16 and int(defensive["bag_slots"]) == 19,
			"%s training applies its authored level passives and defensive allocation adds three real bag slots" % build["id"])
		_check(is_equal_approx(float(trained["native_hit"]), float(defensive["native_hit"])) and trained["stats"]["power"] == defensive["stats"]["power"] and trained["stats"]["luck"] == defensive["stats"]["luck"],
			"%s defensive allocation adds no permanent Power, Luck or native damage" % build["id"])
		_check(is_equal_approx(float(trained["damage"]), float(defensive["damage"])), "%s defensive allocation adds no damage beyond training" % build["id"])
		_check(is_equal_approx(float(offensive["stats"]["power"]), float(trained["stats"]["power"]) + 0.06)
			and is_equal_approx(float(offensive["stats"]["haste"]), float(trained["stats"]["haste"]) + 0.06), "%s offensive allocation applies Power+6%% and Haste+6%% through the real stat pass" % build["id"])
		_check(offensive["stats"]["max_hp"] == trained["stats"]["max_hp"] and offensive["stats"]["armor"] == trained["stats"]["armor"]
			and offensive["stats"]["luck"] == trained["stats"]["luck"] and int(offensive["bag_slots"]) == 16,
			"%s offensive choices grant no unchosen defensive, Luck or bag benefit" % build["id"])
		_check(float(offensive["native_hit"]) > float(trained["native_hit"]) and float(offensive["damage"]) > float(trained["damage"]), "%s offensive choices increase actual native and Tesla output" % build["id"])
		_check(absf(float(offensive["native_projectile"]["collision_radius"]) - float(baseline["native_projectile"]["collision_radius"]) * 1.15) < 0.0001
			and is_equal_approx(float(offensive["native_projectile"]["max_range"]), float(baseline["native_projectile"]["max_range"])), "%s size+15%% reaches the real native projectile without granting unchosen range" % build["id"])
		if int(build["absolute_level"]) > 0:
			_check(is_equal_approx(float(baseline["damage"]), float(trained["damage"])), "fixed absolute level isolates identical late augment output")
		else:
			_check(float(trained["damage"]) > float(baseline["damage"]), "%s paid starting level increases native augment output" % build["id"])

func _verify_reset(variant: String) -> Dictionary:
	_prepare(variant, BUILDS[0])
	Global.set_augment_level(TESLA, 17)
	Global.attempt_augment_transcended = {String(TESLA): true}
	Global.attempt_augment_facets = {String(TESLA): "overcharge"}
	Global.attempt_augment_corruptions = {String(TESLA): "probe"}
	Global.run_bag.extra_slots += 2
	var profile: Variant = Global.get("city_development").duplicate(true)
	Global.start_new_attempt()
	var level := Global.get_augment_level(TESLA)
	var expected_level := 1 if variant == "baseline" else 2
	var expected_slots := 19 if variant == "defensive" else 16
	_check(level == expected_level and Global.run_bag.get_slot_count() == expected_slots, "%s new attempt resets earned levels and temporary bag capacity to the prepared floor" % variant)
	_check(Global.attempt_augment_transcended.is_empty() and Global.attempt_augment_facets.is_empty() and Global.attempt_augment_corruptions.is_empty(), "%s new attempt clears temporary augment forms" % variant)
	_check(Global.get("city_development") == profile, "%s new attempt retains all cumulative purchases" % variant)
	return {"variant": variant, "level_after_reset": level, "bag_slots_after_reset": Global.run_bag.get_slot_count(), "profile_preserved": Global.get("city_development") == profile}

func _gate_rows() -> Array:
	var rows: Array = []
	for version in ["v4", "v5_ranged"]:
		var db := AscensionTreeDB.shared_for(version)
		for completed in [7, 8, 9]:
			var state := AscensionLedger.fresh_state(db.core_of("MOV"), db.variant, 1)
			var ledger := AscensionLedger.new(db, state)
			for index in range(1, 7):
				ledger.record_purchase("MO%02d" % index, 400)
			ledger.record_purchase("MOC", 3000)
			ledger.note_segment_completed(completed)
			var revelation := bool(ledger.can_buy("MOV", 2000000000)["ok"])
			ledger.record_purchase("MOV", 4800)
			var mutation := bool(ledger.can_buy("MOV1", 2000000000)["ok"])
			_check(revelation == (completed >= 8) and mutation == (completed >= 9), "%s fresh gates remain S8 Revelation / S9 mutation at completed %d" % [version, completed])
			rows.append({"tree": version, "completed_segment": completed, "revelation": revelation, "mutation": mutation})
	return rows

func _run() -> void:
	_original_args = EXPERIMENTS._arguments.duplicate()
	var writes_before := SaveManager.debug_save_writes
	_check(Global.has_method("city_development_capture_metadata"), "development capture API exists")
	if not Global.has_method("city_development_capture_metadata"):
		_finish()
		return
	for argument in _original_args:
		if argument.begins_with("--city-development-human="):
			_launch_human(argument.trim_prefix("--city-development-human="))
			return
	_check(Global.get_item_data("conduit_lens") != null, "authored neutral-roll Power fixture exists")
	ThreatDirector.set_process(false)
	PerformanceFlightRecorder.set_enabled(false)
	var rows: Array = []
	for build in BUILDS:
		for variant in VARIANTS:
			rows.append(_measure(variant, build))
	_check_rows(rows)
	var resets: Array = []
	for variant in VARIANTS:
		resets.append(_verify_reset(variant))
	var gates := _gate_rows()
	_check(SaveManager.debug_save_writes == writes_before, "controlled comparison writes zero save slots")
	_report = {"schema_version": 1, "kind": "controlled_city_development_mechanics_comparison",
		"seed": SEED, "race": "human", "style": "ranged", "owned_augments": [String(TESLA), String(OTHER)],
		"equipped_augments": [String(TESLA), "", ""], "seconds_per_row": SECONDS,
		"crowd": {"count": CROWD_COUNT, "radius": CROWD_RADIUS, "hp_each": CROWD_HP, "moves": false, "attacks": false},
		"rows": rows, "resets": resets, "acquisition_gates": gates, "save_writes": SaveManager.debug_save_writes - writes_before,
		"fixture_profiles": {"baseline": _profile("baseline"), "trained": _profile("trained"), "defensive": _profile("defensive"), "offensive": _profile("offensive")},
		"variant_scope": {"baseline": "Defensive ten-choice profile with effective bonuses disabled; stored profile and attempt retained.",
			"trained": "One research point, one chosen owned augment starts at Lv.2.",
			"defensive": "Defensive ten-choice allocation after ten distinct city Rites: HP3, armor3, bag3, training1; never a single reward.",
			"offensive": "Offensive ten-choice allocation after ten distinct city Rites: Power3, Haste3, native attack size3, training1; never a largest-output claim."},
		"matched_human_run": {"scene": "res://tools/tests/CityDevelopmentPacingProbe.tscn", "argument": "--city-development-human=baseline|trained|defensive|offensive",
			"seed": SEED, "equipment_rank": 1, "recorders": ["BalanceRecorder", "PerformanceFlightRecorder"], "save_slots": "none; in-memory fixture only"},
		"limits": ["Stationary immortal crowd; the production Tesla callback is stepped at 60 Hz with presentation disabled.",
			"No city traversal, objective timing, enemy attacks, human choices, encounter completion or fun claims.",
			"Late fixed-level rows isolate equal Lv.12; equal-earned rows compare eleven temporary levels above each starting floor.",
			"Offensive size is observed on the real emitted native projectile; Tesla's radius is not native attack size.",
			"Prepared fixture grants are explicit and do not auto-complete Rites or claim organically earned progress."]}
	_finish()

func _launch_human(variant: String) -> void:
	_check(VARIANTS.has(variant), "human comparison selects a declared variant")
	if not VARIANTS.has(variant):
		_finish()
		return
	_prepare(variant, BUILDS[0])
	BalanceRecorder.set_enabled(true)
	PerformanceFlightRecorder.set_enabled(true)
	var config := {"kind": "matched_human_city_development_fixture", "variant": variant, "seed": SEED,
		"development": Global.call("city_development_capture_metadata"), "farming_experiments": EXPERIMENTS.metadata(),
		"race": "human", "style": "ranged", "equipped_augments": [String(TESLA), "", ""],
		"owned_augments": [String(TESLA), String(OTHER)], "equipment": {"id": "conduit_lens", "rank": 1, "polarity": 1, "roll": 0.0},
		"profile_directory": SaveManager.save_dir, "balance_directory": BalanceRecorder.report_directory,
		"performance_directory": PerformanceFlightRecorder.report_directory,
		"scope": "Prepared profile grants; human movement, choices, combat and Rites. Defensive allocation represents ten separate prior choices.",
		"save_slots": "No active slot; autosaves disabled and all recorder paths isolated."}
	var config_path := ProjectSettings.globalize_path(_isolated_dir + "human_fixture.json")
	DirAccess.make_dir_recursive_absolute(config_path.get_base_dir())
	var config_file := FileAccess.open(config_path, FileAccess.WRITE)
	if config_file == null:
		push_error("Could not preserve human comparison fixture: " + config_path)
		get_tree().quit(1)
		return
	config_file.store_string(JSON.stringify(WRITER.json_safe(config), "\t"))
	config_file.close()
	print("CITY_DEVELOPMENT_HUMAN_FIXTURE=", config_path)
	get_tree().change_scene_to_file(Global.PATH_GAME)

func _finish() -> void:
	EXPERIMENTS._arguments = _original_args
	_report["passes"] = _passes
	_report["failures"] = _failures
	var output := OS.get_environment("CITY_DEVELOPMENT_PROBE_OUT")
	if output.is_empty():
		output = _isolated_dir + "comparison.json"
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Could not write comparison: " + output)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(WRITER.json_safe(_report), "\t"))
	file.close()
	print("CITY_DEVELOPMENT_COMPARISON=", output)
	print("CityDevelopmentPacingProbe: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
