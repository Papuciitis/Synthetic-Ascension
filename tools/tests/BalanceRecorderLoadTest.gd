extends Node

# Recording cost and robustness. The ledger under 100,000 hits; the runtime
# under a deliberately slow writer; then one seeded, scripted workload run
# with recording disabled, with the core recorder and with the extended
# diagnostics: the gameplay state must be identical (recording is passive),
# the cost of each configuration is measured as frame-time and callback
# percentiles, memory, queued bytes and output size, and failures, a scene
# change, shutdown and resume are exercised. Old schema-1 summaries must
# still render without claiming the new measurements.
#
# Run: <godot> --headless --path . res://tools/tests/BalanceRecorderLoadTest.tscn

const Ledger := preload("res://core/systems/telemetry/BalanceLedger.gd")
const Writer := preload("res://core/systems/telemetry/BalanceCaptureWriter.gd")
const Queue := preload("res://autoload/performance/PerformanceIncidentWriteQueue.gd")
const PLAYER := preload("res://core/actors/player/player.tscn")
const SpawnState := preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const WORKLOAD_FRAMES := 1200
const WORKLOAD_SEED := 424242

static var _queued_bytes := 0
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

static func slow_write(batch: Dictionary, directory: String) -> Dictionary:
	OS.delay_msec(100)
	return Writer.write_batch(batch, directory)

static func counting_write(batch: Dictionary, directory: String) -> Dictionary:
	_queued_bytes += JSON.stringify(Writer.json_safe(batch)).to_utf8_buffer().size()
	return Writer.write_batch(batch, directory)

static func failing_write(_batch: Dictionary, _directory: String) -> Dictionary:
	return {"ok": false, "error": "disk full (fixture)"}

static func _percentile(values: Array, fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[clampi(int(floor(fraction * (sorted.size() - 1))), 0, sorted.size() - 1)])

func _make_data(item_id: String, slot: int) -> ItemData:
	var data := ItemData.new()
	data.id = item_id
	data.display_name = item_id
	data.equip_slot = slot as ItemData.EquipSlot
	data.mods = StatDelta.new()
	data.rarity_base = StatDelta.new()
	data.rarity_base.power = 1.0
	return data

func _run() -> void:
	var ledger := Ledger.new()
	ledger.start({}, 0, 2)
	ledger.enemy_seen(1, "load_fixture", false, 1000000.0)
	var started := Time.get_ticks_usec()
	for i in range(100000):
		ledger.enemy_damage(1, 1.0, 1.0, 1, 0, true)
	var usec := Time.get_ticks_usec() - started
	ledger.flush_window()
	_check(ledger.summary().totals.enemy_hp_removed == 100000.0, "100,000 hits keep exact totals")
	_check(ledger.take_records().size() == 2, "100,000 hits retain one metrics window instead of per-hit records")
	print("Balance ledger: 100000 hits in %d usec (%.3f usec/hit)" % [usec, float(usec) / 100000.0])
	# Exercise the two-batch cap with real, deliberately slow writes. Only the
	# worker latency changes; its outputs are real files.
	var recorder := get_node("/root/BalanceRecorder")
	var player := PLAYER.instantiate()
	Global.start_new_attempt()
	Global.attempt_segment = 2
	add_child(player)
	await get_tree().process_frame
	player.set_process(false)
	player.set_physics_process(false)
	recorder.record_headless = true
	recorder.report_directory = "user://balance_load_test_%d" % Time.get_ticks_usec()
	recorder._queue = Queue.new(slow_write)
	recorder.begin_gameplay(player)
	recorder.set_process(false)
	var path: String = recorder.capture_directory
	for i in range(40):
		Global.transaction_followers(1, &"combat_influence")
		recorder._submit(false)
	_check(recorder._queue.pending_count() <= 2, "runtime caps outstanding writes under backpressure")
	recorder.end_capture("load_test")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("summary.json")))
	_check(saved is Dictionary and saved.totals.followers_earned == 40 and saved.dropped_records == 0 and saved.writer_failures == 0, "finalization drains pending history and saves exact totals")
	var transactions := 0
	for line in FileAccess.get_file_as_string(path.path_join("events.jsonl")).split("\n", false):
		var event: Dictionary = JSON.parse_string(line)
		if event.kind == "transaction":
			transactions += 1
	_check(transactions == 40, "slow writer preserves each transaction exactly once")
	_remove_capture(path)

	# --- The same seeded workload three times: recording changes nothing.
	var results := {}
	for config in ["disabled", "core", "extended"]:
		results[config] = await _workload(config, recorder, player)
	var disabled: Dictionary = results.disabled
	var core: Dictionary = results.core
	var extended: Dictionary = results.extended
	_check(disabled.fingerprint == core.fingerprint and disabled.fingerprint == extended.fingerprint, "recording disabled, core and extended leave identical HP, RNG, wallet, enemies, cooldowns and items (%s)" % JSON.stringify(extended.fingerprint))
	_check(int(disabled.fingerprint.deaths) >= 4 and float(disabled.fingerprint.hp) > 0.0, "the workload includes repeated deaths and reconstructions (%d)" % int(disabled.fingerprint.deaths))
	for config in results:
		var r: Dictionary = results[config]
		print("[balance cost] %-8s frame p50/p95/p99 %5.0f/%5.0f/%5.0f usec | recorder _process p50/p95/p99 %5.0f/%5.0f/%5.0f usec (max %d) | memory delta %d KB | queued %d bytes | output %d bytes | dropped %d | ring overwritten %d" % [config, r.frame_p50, r.frame_p95, r.frame_p99, r.process_p50, r.process_p95, r.process_p99, int(r.max_callback), int(r.memory_delta / 1024), int(r.queued_bytes), int(r.output_bytes), int(r.dropped), int(r.ring_overwritten)])
	_check(extended.process_p95 < 5000.0 and core.process_p95 < 5000.0, "recorder frame callbacks stay under 5 ms at p95 (core %.0f, extended %.0f usec)" % [core.process_p95, extended.process_p95])
	_check(int(extended.dropped) == 0 and int(core.dropped) == 0, "no records are dropped by the bounded buffers under the workload")
	_check(extended.output_bytes > core.output_bytes and core.output_bytes > 0, "the extended capture writes more than the core capture (%d > %d bytes)" % [int(extended.output_bytes), int(core.output_bytes)])
	_check(extended.summary.metadata.features.incidents and not core.summary.metadata.features.incidents and int(extended.summary.incidents.deaths) >= 4, "each configuration declares only what it measured; the extended capture froze every death")
	var t: Dictionary = extended.summary.totals
	_check(t.followers_open + t.followers_earned - t.followers_spent + t.followers_adjustments + t.followers_debug == t.followers_close and int(extended.summary.wallet_discontinuities) == 0, "the extended capture's wallet reconciles")
	var by_source := 0.0
	for value in t.player_damage_by_source.values():
		by_source += float(value)
	_check(absf(by_source - float(t.player_hp_lost)) < 0.01, "player HP lost equals the damage-by-source table (%.1f)" % by_source)
	var coverage: Dictionary = extended.summary.attribution_coverage
	_check(absf(float(coverage.get("attributed", 0.0)) + float(coverage.get("unknown", 0.0)) + float(coverage.get("mixed", 0.0)) - float(t.enemy_hp_removed)) < 0.01, "attributed, unknown and mixed enemy HP sum to the enemy HP removed")
	_check(float(extended.summary.health.totals.max_abs_residual) < 0.001 and int(extended.summary.health.totals.unexplained_checks) == 0, "every HP change in the workload reconciled (largest residual %.4f)" % float(extended.summary.health.totals.max_abs_residual))

	# --- Failure, scene change, shutdown, resume.
	recorder.extended = true
	recorder._queue = Queue.new(failing_write)
	recorder.report_directory = "user://balance_load_fail_%d" % Time.get_ticks_usec()
	recorder.begin_gameplay(player)
	recorder.flush_reports()
	var failed: Dictionary = recorder.get_summary()
	_check(int(failed.writer_failures) >= 1 and String(failed.last_error).contains("disk full"), "a write failure is reported in the summary instead of claimed complete")
	recorder._queue = Queue.new(Writer.write_batch)
	var first_capture: String = recorder.capture_directory
	var first_key: String = recorder.get_summary().metadata.run_key
	Global.balance_scene_requested.emit(Global.PATH_HUB_SHOP)
	_check(recorder.is_recording() and recorder._mode == "loading", "a hub transition keeps the capture and marks loading")
	Global.balance_scene_requested.emit("res://scenes/menus/MainMenu.tscn")
	_check(not recorder.is_recording(), "leaving the run suspends the capture")
	recorder.begin_gameplay(player)
	_check(recorder.is_recording() and recorder.capture_directory != first_capture and recorder.get_summary().metadata.run_key == first_key and int(recorder.get_summary().totals.kills) == 0, "resuming starts a separate capture with the same run key and fresh totals")
	var resumed: String = recorder.capture_directory
	recorder.end_capture("suspended")
	recorder.flush_reports()
	_check(FileAccess.file_exists(resumed.path_join("summary.json")), "shutdown writes the resumed capture")
	_remove_capture(first_capture)
	_remove_capture(resumed)

	# --- Schema-1 summaries still render, without the new measurements.
	var old_totals := {"followers_open": 100, "followers_close": 140, "followers_earned": 60, "followers_spent": 20, "followers_adjustments": 0, "followers_debug": 0,
		"followers_by_reason": {"combat_influence": {"count": 3, "gained": 60, "spent": 0, "net": 60}}, "enemies": {}, "player_damage_by_source": {"grunt": 12.0},
		"healing_by_source": {}, "seconds_gameplay": 30.0, "seconds_paused": 0.0, "seconds_hub": 0.0, "seconds_loading": 0.0, "kills": 3, "deaths": 0, "player_hp_lost": 12.0}
	var old_segment := old_totals.duplicate(true)
	old_segment["segment"] = 2
	old_segment["status"] = "suspended"
	var schema1 := {"schema_version": 1, "metadata": {"capture_id": "old", "run_key": "0:1", "build": {}}, "outcome": "suspended", "elapsed_seconds": 30.0,
		"totals": old_totals, "segments": [old_segment], "dropped_records": 0, "wallet_discontinuities": 0}
	var rendered: String = Writer.markdown(schema1)
	_check(rendered.contains("# Balance capture") and rendered.contains("## Economy") and not rendered.contains("## Incidents") and not rendered.contains("## Exit and pressure") and not rendered.contains("## Upgrade effort") and not rendered.contains("## Health reconciliation") and not rendered.contains("## Recorder coverage"), "a schema-1 summary renders without claiming the new measurements")
	var round_trip: Variant = JSON.parse_string(JSON.stringify(Writer.json_safe(schema1)))
	_check(round_trip is Dictionary and int(round_trip.schema_version) == 1 and int(round_trip.totals.followers_close) == 140 and Writer.segment_csv(schema1).split("\n").size() >= 2, "a schema-1 summary round-trips and exports its segment row")

	player.free()
	print("BalanceRecorderLoadTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)


## One deterministic, scripted run: a fixed RNG seed, tanks that never die,
## victims that do, regular hits, heals, costs, wallet income, item feeds and
## periodic lethal hits with immediate reconstruction. Returns the gameplay
## fingerprint (never timing) and the measured cost of the configuration.
func _workload(config: String, recorder: Node, player: Node) -> Dictionary:
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.debug_player_god_mode = false
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.run_luck = 0.0
	Global.set_followers(100000)
	player.stats = Stats.new()
	player.stats.armor = 0.0
	player.max_hp = 100.0
	player.hp = 100.0
	player.invulnerable_time = 0.0
	player.respawn_phase_left = 0.0
	var alpha := _make_data("load_alpha", ItemData.EquipSlot.POWER)
	var worn := ItemInstance.from_roll(alpha, 1, ItemInstance.Polarity.POS, 0.4, false)
	Global.run_inventory.set_item(ItemData.EquipSlot.POWER, worn, null)
	var attacker := Node2D.new()
	attacker.global_position = player.global_position + Vector2(40, 0)
	add_child(attacker)
	var tanks: Array[int] = []
	var actors: Array[Node2D] = [attacker]
	for index in range(4):
		var actor := Node2D.new()
		actor.global_position = player.global_position + Vector2(60 + 20 * index, 0)
		add_child(actor)
		actors.append(actor)
		var handle := EnemyWorld.create_enemy(SpawnState.new(&"load_tank", "res://load_tank.tscn", actor.global_position, 100000.0, 10.0, 8.0, 0, 0))
		EnemyWorld.bind_actor(handle, actor)
		tanks.append(handle)
	var attacker_handle := EnemyWorld.create_enemy(SpawnState.new(&"load_attacker", "res://load_attacker.tscn", attacker.global_position, 100000.0, 10.0, 8.0, 0, 0))
	EnemyWorld.bind_actor(attacker_handle, attacker)
	_queued_bytes = 0
	recorder.enabled = config != "disabled"
	recorder.extended = config == "extended"
	recorder.record_headless = true
	recorder.report_directory = "user://balance_load_%s_%d" % [config, Time.get_ticks_usec()]
	recorder._queue = Queue.new(counting_write)
	var memory_before := OS.get_static_memory_usage()
	recorder.begin_gameplay(player)
	recorder.set_process(false)
	Global._rng.seed = WORKLOAD_SEED
	var frame_usec: Array = []
	var process_usec: Array = []
	var kills := 0
	var victim := 0
	var deaths := 0
	for frame in range(WORKLOAD_FRAMES):
		var frame_start := Time.get_ticks_usec()
		EnemyCombat.apply_damage(tanks[frame % tanks.size()], 3.0, 1, player, null)
		if frame % 2 == 0:
			player.take_damage(1.0, attacker)
		if frame % 3 == 0:
			player.heal(1.5, &"regen")
		if frame % 10 == 0:
			Global.transaction_followers(1, &"combat_influence", {"enemy_id": "load_tank"})
		if frame % 60 == 30:
			player.pay_health(2.0, &"load_fixture")
		if frame % 100 == 50:
			if victim != 0 and EnemyWorld.is_valid_handle(victim):
				EnemyWorld.remove_enemy(victim, &"test")
			victim = EnemyWorld.create_enemy(SpawnState.new(&"load_victim", "res://load_victim.tscn", attacker.global_position, 5.0, 1.0, 8.0, 0, 0))
			EnemyCombat.apply_damage(victim, 9.0, 1, player, null)
			kills += 1
		if frame % 120 == 90:
			var op := BalanceItemContext.begin(&"pickup", {"pickup": "ground"})
			Global.run_inventory.add_or_feed(ItemInstance.from_roll(alpha, 0, ItemInstance.Polarity.POS, 0.0, false), {"type": 1, "pos": Vector2.ZERO})
			BalanceItemContext.end(op)
		if frame % 250 == 249:
			player.invulnerable_time = 0.0
			player.take_damage(1000.0, attacker)
			deaths += 1
			player.invulnerable_time = 0.0
			player.respawn_phase_left = 0.0
		var process_start := Time.get_ticks_usec()
		recorder._process(1.0 / 60.0)
		var now := Time.get_ticks_usec()
		process_usec.append(now - process_start)
		frame_usec.append(now - frame_start)
	var fingerprint := {"hp": player.hp, "max_hp": player.max_hp, "followers": Global.followers, "rng": Global._rng.state,
		"deaths": deaths, "attempt_deaths": Global.attempt_deaths_this_segment, "dash_cooldown": player.dash_cooldown_left(),
		"worn_rarity": worn.rarity, "worn_meter": worn.upgrade_meter, "kills": kills, "enemies": EnemyWorld.active_count(), "tank_hp": 0.0}
	for handle in tanks:
		fingerprint["tank_hp"] = float(fingerprint["tank_hp"]) + EnemyWorld.get_health(handle)
	var summary: Dictionary = recorder.get_summary()
	var capture: String = recorder.capture_directory
	if recorder.is_recording():
		recorder.end_capture("load_workload")
	recorder.flush_reports()
	var memory_after := OS.get_static_memory_usage()
	var output_bytes := 0
	var saved := {}
	if config != "disabled":
		for name in ["events.jsonl", "summary.json", "report.md", "segments.csv"]:
			var file_path := capture.path_join(name)
			if FileAccess.file_exists(file_path):
				output_bytes += FileAccess.get_file_as_bytes(file_path).size()
		saved = JSON.parse_string(FileAccess.get_file_as_string(capture.path_join("summary.json")))
		_remove_capture(capture)
	if victim != 0 and EnemyWorld.is_valid_handle(victim):
		EnemyWorld.remove_enemy(victim, &"test")
	for handle in tanks:
		EnemyWorld.remove_enemy(handle, &"test")
	EnemyWorld.remove_enemy(attacker_handle, &"test")
	for actor in actors:
		actor.free()
	recorder.enabled = true
	recorder.extended = true
	await get_tree().process_frame
	return {"fingerprint": fingerprint, "summary": saved if not saved.is_empty() else summary,
		"frame_p50": _percentile(frame_usec, 0.5), "frame_p95": _percentile(frame_usec, 0.95), "frame_p99": _percentile(frame_usec, 0.99),
		"process_p50": _percentile(process_usec, 0.5), "process_p95": _percentile(process_usec, 0.95), "process_p99": _percentile(process_usec, 0.99),
		"max_callback": int(summary.get("max_sample_callback_usec", 0)), "memory_delta": memory_after - memory_before,
		"queued_bytes": _queued_bytes, "output_bytes": output_bytes, "dropped": int(summary.get("dropped_records", 0)),
		"ring_overwritten": int(summary.get("history", {}).get("events_overwritten", 0)) + int(summary.get("history", {}).get("samples_overwritten", 0))}


func _remove_capture(path: String) -> void:
	for name in ["events.jsonl", "summary.json", "report.md", "segments.csv"]:
		if FileAccess.file_exists(path.path_join(name)):
			DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)
