extends Node

# Item and encounter baseline probe (balance plan Task 1). Exports, before
# any number changes, what the current production formulas give: every
# runtime item's flat contributions, effect potency and market values at the
# laboratory ranks, the primary-hit damage each style's formula yields at
# those Power ranks with one real landed ranged hit as verification, the
# constant-EHP fixture fed through the real damage path, each set's mean
# rank, strength and tier bonuses when its six core items are worn, and the
# attribution coverage the recorder observed. Prints BASELINE_JSON=... and
# writes the same JSON to $PROBE_OUT (relative to the project) or user://.
#
# Run: PROBE_OUT=docs/audits/x.json <godot> --headless --path . res://tools/tests/ItemBalanceProbe.tscn

const PLAYER := preload("res://core/actors/player/player.tscn")
const SpawnState := preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const RANKS_PATH := "res://tools/tests/fixtures/item_balance/ranks.json"
const EHP_PATH := "res://tools/tests/fixtures/item_balance/ehp_fixture.json"
const STAT_FIELDS := ["max_hp", "armor", "move_speed", "power", "haste", "luck"]

## The "other damage multiplier" of the EHP fixture: one effect node in the
## real ItemEffectRunner, so the hit takes the real multiplier path.
class FixtureMultiplier:
	extends Node
	var multiplier := 0.8
	func get_damage_taken_multiplier() -> float:
		return multiplier

var _passes := 0
var _failures := 0
var _baseline := {}


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _stats(resource: Resource) -> Dictionary:
	var result := {}
	for field in STAT_FIELDS:
		result[field] = snappedf(float(resource.get(field)), 0.0001) if resource != null else null
	return result


func _instance(data: ItemData, rank: int, roll: float, meter: float = 0.0) -> ItemInstance:
	var inst := ItemInstance.from_roll(data, rank, ItemInstance.Polarity.POS if roll >= 0.0 else ItemInstance.Polarity.NEG, roll, false)
	if meter > 0.0:
		inst.upgrade_meter = meter
		inst._recompute_flat_mods()
	return inst


func _settle() -> void:
	for _i in range(600):
		await get_tree().process_frame
		if ProjectileManager.active_count() == 0:
			break
	await get_tree().process_frame


func _run() -> void:
	var ranks_fixture := _load_json(RANKS_PATH)
	var ehp_fixture := _load_json(EHP_PATH)
	_check(not ranks_fixture.is_empty() and not ehp_fixture.is_empty(), "probe fixtures load")
	var ranks: Array = ranks_fixture.get("ranks", [0, 1, 6, 15, 30])
	var neutral_roll := float(ranks_fixture.get("neutral_roll", 0.0))
	var recorder := get_node_or_null("/root/BalanceRecorder")
	Global.start_new_attempt()
	Global.attempt_segment = int(ranks_fixture.get("segment", 5))
	Global.debug_player_god_mode = false
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.run_luck = 0.0
	Global.set_followers(1000)
	Global.selected_race_id = "human"
	Global.selected_style_id = "ranged"
	var player = PLAYER.instantiate()
	add_child(player)
	await get_tree().process_frame
	player.set_process(false)
	player.set_physics_process(false)
	for runner_name in ["AscensionRunner", "ManifestationRunner", "ItemEffectRunner", "SetRunner"]:
		var runner := player.get_node_or_null(NodePath(runner_name))
		if runner != null:
			runner.set_process(false)
	ProjectileManager.clear_for_run_end()
	await get_tree().process_frame
	var dir := "user://item_balance_probe_%s" % Time.get_ticks_usec()
	recorder.report_directory = dir
	recorder.record_headless = true
	recorder.begin_gameplay(player)
	recorder.set_process(false)
	var race: RaceData = Global.race_db.get("human", null)
	var style: StyleData = Global.style_db.get("ranged", null)
	_check(race != null and style != null, "the human race and ranged style load")
	_baseline = {"balance_revision": recorder.balance_revision(), "tuning_stages": recorder.tuning_stages(), "recorder_revision": recorder.RECORDER_REVISION,
		"tuning_hash": recorder.tuning_hash(), "generated": Time.get_datetime_string_from_system(true, true),
		"segment": Global.attempt_segment, "ranks": ranks, "race": "human", "style_for_landed_hit": "ranged",
		"notes": ["Neutral positive rolls; no Manifestations, augments, doctrine or Ascension rules.",
			"Item flat values are ItemInstance.rolled_mods after _recompute_flat_mods (mods + rarity_base * (potency - 1)); the roll is applied later in the stat pipeline.",
			"Primary-hit damage is base_weapon_damage * style multiplier * (1 + Power) with luck 0 (no crit); only the ranged value is a landed hit, melee and magic are formula values.",
			"Set rows wear the set's six core items at the same rank; set effects run but no set attack was fired, so set origins are absent from attribution by construction."]}

	# --- Constant-EHP fixture through the real damage path.
	var ier := player.get_node("ItemEffectRunner")
	var fixture_effect := FixtureMultiplier.new()
	fixture_effect.multiplier = float(ehp_fixture.get("other_damage_multiplier", 0.8))
	ier.add_child(fixture_effect)
	ier._active_effects["probe_fixture"] = fixture_effect
	player.stats = Stats.new()
	player.stats.armor = float(ehp_fixture.get("armor", 50.0))
	player.max_hp = float(ehp_fixture.get("max_hp", 200.0))
	player.hp = player.max_hp
	player.invulnerable_time = 0.0
	var attacker := Node2D.new()
	# Off the +X firing line: the landed-hit check fires along it later.
	attacker.global_position = player.global_position + Vector2(-60, 90)
	add_child(attacker)
	var attacker_handle := EnemyWorld.create_enemy(SpawnState.new(&"probe_attacker", "res://probe_attacker.tscn", attacker.global_position, 1000.0, 10.0, 8.0, 0, 0))
	EnemyWorld.bind_actor(attacker_handle, attacker)
	var hp_before: float = player.hp
	player.take_damage(float(ehp_fixture.get("raw_hit", 50.0)), attacker)
	var loss: float = hp_before - player.hp
	var ehp: float = float(player.max_hp) * (1.0 + maxf(float(player.stats.armor), 0.0) / 100.0) / fixture_effect.multiplier
	_check(absf(loss - float(ehp_fixture.get("expected_hp_loss", 26.6667))) <= float(ehp_fixture.get("tolerance", 0.001)) and absf(ehp - float(ehp_fixture.get("expected_ehp", 375.0))) < 0.001, "the EHP fixture loses %.4f HP to a 50 raw hit (EHP %.1f)" % [loss, ehp])
	_baseline["ehp_fixture"] = {"max_hp": player.max_hp, "armor": player.stats.armor, "other_damage_multiplier": fixture_effect.multiplier,
		"raw_hit": float(ehp_fixture.get("raw_hit", 50.0)), "observed_hp_loss": loss, "constant_ehp": ehp,
		"formula": "HP * (1 + max(armor,0)/100) / product(other damage-taken multipliers); evasion, invulnerability and healing reported separately"}
	ier._active_effects.erase("probe_fixture")
	fixture_effect.free()

	# --- Every runtime item at the laboratory ranks.
	var items := {}
	var ids: Array = Global.item_db.keys()
	ids.sort()
	for id in ids:
		if String(id) == "item_test":
			continue
		var data: ItemData = Global.item_db[id]
		var row := {"slot": int(data.equip_slot), "set": String(data.set_id), "pct_range": [data.pct_min, data.pct_max], "by_rank": {}}
		for rank in ranks:
			var inst := _instance(data, int(rank), neutral_roll)
			row.by_rank[str(int(rank))] = {"flat": _stats(inst.rolled_mods), "effect_multiplier": snappedf(inst.rarity_effect_multiplier(), 0.0001),
				"value": Global.compute_item_value(inst), "buy": Global.compute_buy_value(inst), "sell": Global.compute_sell_value(inst)}
		var fractional := float(ranks_fixture.get("fractional_rank", 6.5))
		var half := _instance(data, int(floor(fractional)), neutral_roll, fractional - floor(fractional))
		row.by_rank[str(fractional)] = {"flat": _stats(half.rolled_mods), "effect_multiplier": snappedf(half.rarity_effect_multiplier(), 0.0001), "value": Global.compute_item_value(half)}
		items[String(id)] = row
	_baseline["items"] = items
	_check(items.size() >= 30 and items.has("conduit_heart") and float(items.conduit_heart.by_rank["15"].flat.max_hp) > float(items.conduit_heart.by_rank["1"].flat.max_hp), "%d runtime items exported with growing contributions" % items.size())
	_check(float(items.conduit_heart.by_rank["6.5"].flat.max_hp) > float(items.conduit_heart.by_rank["6"].flat.max_hp), "a banked half rank already moves the item's own stats")

	# --- Primary-hit damage by style at Power-item ranks; one landed ranged hit.
	var power_item: ItemData = Global.item_db.get(String(ranks_fixture.get("power_item", "conduit_lens")), null)
	var primary := {"base_weapon_damage": float(player.base_weapon_damage), "style_multipliers": {"melee": CombatStyleTuning.MELEE_DAMAGE_MULT, "ranged": CombatStyleTuning.RANGED_DAMAGE_MULT, "magic": CombatStyleTuning.MAGIC_DAMAGE_MULT}, "by_rank": {}}
	player.stats = Stats.new()
	for rank in ranks:
		var op := BalanceItemContext.begin(&"debug", {"tool": "probe"})
		Global.run_inventory.set_item(ItemData.EquipSlot.POWER, _instance(power_item, int(rank), neutral_roll), null)
		BalanceItemContext.end(op)
		player.recompute_run_stats(race, style, false)
		var power: float = player.stats.power
		var base: float = float(player.base_weapon_damage)
		primary.by_rank[str(int(rank))] = {"power": snappedf(power, 0.0001), "stats": _stats(player.stats),
			"melee": snappedf(base * CombatStyleTuning.MELEE_DAMAGE_MULT * (1.0 + power), 0.001),
			"ranged": snappedf(base * CombatStyleTuning.RANGED_DAMAGE_MULT * (1.0 + power), 0.001),
			"magic": snappedf(base * CombatStyleTuning.MAGIC_DAMAGE_MULT * (1.0 + power), 0.001), "measured": {}}
	var landed_rank := int(ranks_fixture.get("landed_hit_rank", 6))
	var op2 := BalanceItemContext.begin(&"debug", {"tool": "probe"})
	Global.run_inventory.set_item(ItemData.EquipSlot.POWER, _instance(power_item, landed_rank, neutral_roll), null)
	BalanceItemContext.end(op2)
	player.recompute_run_stats(race, style, false)
	player.invulnerable_time = 0.0
	var target_pos: Vector2 = player.global_position + Vector2(300, 0)
	# 1,000 HP: enemy health is stored in 32-bit floats, so a 100,000 HP
	# target would quantize the measured loss to about 0.008.
	var target := EnemyWorld.create_enemy(SpawnState.new(&"probe_target", "res://probe_target.tscn", target_pos, 1000.0, 0.0, 8.0, 0, 0, {"follower_reward_min": 0, "follower_reward_max": 0}))
	var target_before := EnemyWorld.get_health(target)
	player._weapon_cd = 0.0
	player._fire_weapon(target_pos)
	await _settle()
	var landed := target_before - EnemyWorld.get_health(target)
	var expected_landed: float = float(player.base_weapon_damage) * CombatStyleTuning.RANGED_DAMAGE_MULT * (1.0 + float(player.stats.power))
	_check(absf(landed - expected_landed) < 0.001 and landed > 0.0, "one real ranged primary hit lands the formula damage at R%d (%.4f vs %.4f)" % [landed_rank, landed, expected_landed])
	primary.by_rank[str(landed_rank)].measured = {"ranged_landed": landed, "formula": expected_landed, "target": "standard 1000 HP handle, no armour", "matches_formula": absf(landed - expected_landed) < 0.001}
	_baseline["primary_hit"] = primary
	EnemyWorld.remove_enemy(target, &"probe")

	# --- Sets: six core items at the same rank.
	var sets := {}
	var set_ids: Array = Global.set_db.keys()
	set_ids.sort()
	for set_id in set_ids:
		var sd: SetData = Global.set_db[set_id]
		var members: Array = []
		for id in ids:
			var data: ItemData = Global.item_db[id]
			if String(data.set_id) == String(set_id) and int(data.equip_slot) >= 0 and int(data.equip_slot) < Inventory.STAT_SLOT_COUNT:
				members.append(data)
		var set_row := {"members": members.map(func(d: ItemData) -> String: return d.id), "tiers": {}, "by_rank": {}}
		for tier in sd.tiers:
			set_row.tiers[str(tier.required_count)] = {"name": tier.display_name, "mods": _stats(tier.mods), "effects": tier.effect_scenes.size()}
		for rank in ranks:
			if int(rank) == 0:
				continue
			var op := BalanceItemContext.begin(&"debug", {"tool": "probe"})
			Global.run_inventory.clear()
			for data in members:
				Global.run_inventory.set_item(int(data.equip_slot), _instance(data, int(rank), neutral_roll), null)
			BalanceItemContext.end(op)
			player.recompute_run_stats(race, style, false)
			var runner := player.get_node("SetRunner")
			set_row.by_rank[str(int(rank))] = {"count": int(Global.run_inventory.get_set_counts().get(set_id, 0)),
				"mean_rank": Global.run_inventory.get_set_rarity_average(set_id), "strength": snappedf(Global.run_inventory.get_set_strength(set_id), 0.0001),
				"active_effects": runner.get_active_effect_keys().size(), "player_stats": _stats(player.stats)}
		sets[String(set_id)] = set_row
	_baseline["sets"] = sets
	_check(sets.size() == 3 and int(sets.values()[0].by_rank["6"].count) == 6, "the three sets are exported with all six core members worn")
	var op3 := BalanceItemContext.begin(&"debug", {"tool": "probe"})
	Global.run_inventory.clear()
	BalanceItemContext.end(op3)
	player.recompute_run_stats(race, style, false)

	# --- What the recorder attributed during the probe.
	var summary: Dictionary = recorder.get_summary()
	var origins: Array = (summary.totals.attribution.by_origin as Dictionary).keys()
	origins.sort()
	var set_origins: Array = origins.filter(func(key: String) -> bool: return key.begins_with("set:"))
	_baseline["attribution"] = {"coverage": summary.attribution_coverage, "origins_observed": origins, "set_origins_observed": set_origins,
		"note": "No set attack was fired by this probe; set root coverage is measured only in play or the controlled set-output probe."}
	_baseline["capture"] = {"schema_version": summary.schema_version, "features": summary.metadata.features, "health_unexplained_checks": summary.health.totals.unexplained_checks}
	_check(set_origins.is_empty() and float(summary.attribution_coverage.get("attributed", 0.0)) >= landed, "attribution reports the landed hit and no set origin, honestly")

	var text := JSON.stringify(recorder.Writer.json_safe(_baseline), "\t")
	var out := OS.get_environment("PROBE_OUT")
	var out_path := "user://item_balance_baseline.json" if out.is_empty() else (out if out.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out))
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
	_check(file != null, "baseline written to %s" % out_path)
	print("BASELINE_JSON=", JSON.stringify(recorder.Writer.json_safe(_baseline)))

	var capture_path: String = recorder.capture_directory
	recorder.end_capture("probe")
	recorder.flush_reports()
	EnemyWorld.remove_enemy(attacker_handle, &"probe")
	attacker.free()
	player.free()
	for name in ["events.jsonl", "summary.json", "report.md", "segments.csv"]:
		DirAccess.remove_absolute(capture_path.path_join(name))
	DirAccess.remove_absolute(capture_path)
	print("ItemBalanceProbe: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
