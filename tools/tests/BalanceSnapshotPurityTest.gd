extends Node

# Recording must be observation only. The runners' get_*_multiplier() getters
# are combat operations: ManifestationRunner.get_damage_taken_multiplier()
# spends the banked Composure guard and Reliquary Guard's getter arms the
# latch that pays a shard on the next hit, so a sample that polled them spent
# the player's next-hit defence with no hit landing. This suite lights both on
# a real player through the real inventory path, takes a hundred samples
# (live, paused and dead), asserts nothing moved, and then lands one real hit
# that must consume exactly what a hit consumes.
#
# Run: <godot> --headless --path . res://tools/tests/BalanceSnapshotPurityTest.tscn

const PLAYER = preload("res://core/actors/player/player.tscn")
const SAMPLES := 100

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _make_data(item_id: String, slot: int) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.display_name = item_id
	data.equip_slot = slot as ItemData.EquipSlot
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	return data


func _make_instance(data: ItemData, rarity: int, roll: float, manifestation: StringName) -> ItemInstance:
	var inst := ItemInstance.from_roll(data, rarity, ItemInstance.Polarity.POS, roll, false)
	inst.manifestation_id = manifestation
	return inst


## Every piece of gameplay state a sample could touch, read without calling
## anything that consumes.
func _state_of(player: Node, mstate: ManifestationState, guard: Node) -> Dictionary:
	return {
		"hp": float(player.get("hp")), "invulnerable": float(player.get("invulnerable_time")),
		"time_since_hit": mstate.time_since_hit, "composure_ready": mstate.composure_ready(),
		"shards": mstate.shard_count(), "time_since_attack": mstate.time_since_attack,
		"attack_index": mstate.attack_index, "misfortune": mstate.misfortune, "momentum": mstate.momentum,
		"latched": bool(guard.get("_latched")), "cooldown": float(guard.get("_cooldown")),
		"guarding": bool(guard.call("is_guarding")), "rng_state": Global._rng.state,
	}


func _last_sample(recorder: Node) -> Dictionary:
	var found := {}
	for record in recorder._ledger.take_records():
		if String(record.get("kind", "")) == "sample":
			found = record.get("data", {})
	return found


func _run() -> void:
	var recorder := get_node_or_null("/root/BalanceRecorder")
	_check(recorder != null, "runtime balance recorder is installed")
	if recorder == null:
		_finish()
		return
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.debug_player_god_mode = false
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.run_luck = 0.0
	Global.set_followers(100)
	# The real inventory path: a noun lights when two distinct rules claim it,
	# and lit ward + shard is what instantiates the Reliquary Guard pair when
	# the runner binds on the player's _ready.
	var inventory: Inventory = Global.run_inventory
	inventory.set_item(ItemData.EquipSlot.HP, _make_instance(_make_data("purity_ward_a", ItemData.EquipSlot.HP), 3, 0.2, &"scar_tissue"))
	inventory.set_item(ItemData.EquipSlot.ARMOR, _make_instance(_make_data("purity_ward_b", ItemData.EquipSlot.ARMOR), 3, 0.2, &"martyr_circuit"))
	inventory.set_item(ItemData.EquipSlot.POWER, _make_instance(_make_data("purity_shard_a", ItemData.EquipSlot.POWER), 3, 0.2, &"predestination_sigil"))
	inventory.set_item(ItemData.EquipSlot.OFFHAND, _make_instance(_make_data("purity_shard_b", ItemData.EquipSlot.OFFHAND), 3, 0.2, &"splinter_dividend"))
	var player = PLAYER.instantiate()
	add_child(player)
	await get_tree().process_frame
	player.set_process(false)
	player.set_physics_process(false)
	player.stats = Stats.new()
	player.stats.armor = 0.0
	player.max_hp = 100.0
	player.hp = 100.0
	player.invulnerable_time = 0.0
	var mrunner := player.get_node("ManifestationRunner") as ManifestationRunner
	mrunner.set_process(false)
	var mstate: ManifestationState = mrunner.state
	mstate.set_process(false)
	var guard: Node = (mrunner.get("_pairs") as Dictionary).get(&"reliquary_guard", null)
	_check(guard != null and mstate.has_source(&"ward") and mstate.has_source(&"shard"), "fixture: ward and shard rules light Reliquary Guard through the real inventory path")
	if guard == null:
		player.free()
		_finish()
		return
	mstate.time_since_hit = 999.0
	var added := mstate.add_shard(1)
	_check(added == 1 and mstate.composure_ready() and bool(guard.call("is_guarding")), "fixture: one ready Composure guard and one orbiting shard")

	# Gameplay RNG: the wallet/luck generator by state, the global one by the
	# next value it would produce.
	seed(20260918)
	var expected_global := randi()
	seed(20260918)
	var before := _state_of(player, mstate, guard)

	var dir := "user://balance_purity_test_%s" % Time.get_ticks_usec()
	recorder.report_directory = dir
	recorder.record_headless = true
	recorder.begin_gameplay(player)
	recorder.set_process(false)
	_check(recorder.is_recording(), "explicit headless capture starts")
	for _i in range(SAMPLES):
		recorder._capture_sample()
	get_tree().paused = true
	recorder._capture_sample()
	get_tree().paused = false
	player.is_dead = true
	recorder._capture_sample()
	player.is_dead = false
	var after := _state_of(player, mstate, guard)
	for key in before:
		_check(after[key] == before[key], "%d samples (live, paused, dead) leave %s unchanged (%s -> %s)" % [SAMPLES + 2, key, str(before[key]), str(after[key])])
	_check(randi() == expected_global, "sampling draws nothing from the global RNG")
	var sample := _last_sample(recorder)
	var effects: Dictionary = sample.get("effects", {})
	var mani: Dictionary = effects.get("ManifestationRunner", {})
	_check(bool(mani.get("composure_ready", false)) and float(mani.get("passive_damage_taken_multiplier", 0.0)) == 1.0, "the sample reports Composure as a ready guard, not as a 0.55 multiplier")
	var reliquary_ready := false
	for entry in mani.get("conditional_guards", []):
		if String(entry.get("id", "")) == "manifestation_pair:reliquary_guard" and bool(entry.get("ready", false)) and int(entry.get("resource", 0)) == 1:
			reliquary_ready = true
	_check(reliquary_ready, "the sample lists Reliquary Guard as ready with one shard, without latching it")
	_check(effects.has("ItemEffectRunner") and effects.has("AscensionRunner"), "item and tree runners report through the same observational API")

	# One real hit: the shard shatters, Composure is spent, exactly once each.
	var attacker := Node2D.new()
	add_child(attacker)
	player.take_damage(40.0, attacker)
	var after_hit := _state_of(player, mstate, guard)
	_check(after_hit.hp == 100.0 and after_hit.shards == 0 and not after_hit.latched, "a real hit is nullified by the guard and pays exactly one shard (hp %.1f, shards %d)" % [after_hit.hp, after_hit.shards])
	_check(after_hit.time_since_hit == 0.0 and not after_hit.composure_ready, "the same hit spends the banked Composure")
	for _i in range(SAMPLES):
		recorder._capture_sample()
	var after_more := _state_of(player, mstate, guard)
	for key in after_hit:
		_check(after_more[key] == after_hit[key], "samples after the hit still change nothing (%s)" % key)

	var capture_path: String = recorder.capture_directory
	recorder.end_capture("suspended")
	recorder.flush_reports()
	attacker.free()
	player.free()
	Global.run_inventory.clear()
	for name in ["events.jsonl", "summary.json", "report.md", "segments.csv"]:
		DirAccess.remove_absolute(capture_path.path_join(name))
	DirAccess.remove_absolute(capture_path)
	_finish()


func _finish() -> void:
	print("BalanceSnapshotPurityTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
