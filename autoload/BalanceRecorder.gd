extends Node

const Ledger := preload("res://core/systems/telemetry/BalanceLedger.gd")
const Writer := preload("res://core/systems/telemetry/BalanceCaptureWriter.gd")
const WriteQueue := preload("res://autoload/performance/PerformanceIncidentWriteQueue.gd")
const Build := preload("res://core/systems/telemetry/BuildInfo.gd")
const Types := preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const STAT_FIELDS := ["max_hp", "armor", "move_speed", "power", "haste", "luck"]
const PRESSURE_FIELDS := ["threat", "heat", "overtime", "resonance", "enemy_hp_mul", "enemy_damage_mul", "enemy_speed_mul", "spawn_interval_mul", "elite_bonus", "segment_phase", "rite_channel_active", "power_contrast_active"]
const DEBUG_FIELDS := ["debug_dev_mode", "debug_dev_segment", "debug_player_god_mode", "debug_enemy_hp_scale", "debug_ascension_revelations_enabled", "enemy_proxy_rollout", "debug_opening_mode_override"]

var enabled := true
var record_headless := false
var report_directory := "res://balance_captures" if OS.has_feature("editor") else "user://balance_captures"
var capture_directory := ""
var _active := false
var _ledger: RefCounted = null
var _player_ref: WeakRef = null
var _queue: RefCounted = WriteQueue.new(Writer.write_batch)
var _subscriptions: Array = []
var _mode := "loading"
var _destination := ""
var _sample_left := 1.0
var _summary_left := 15.0
var _build_dirty := false
var _last_build: Dictionary = {}
var _build_index := 0
var _started_usec := 0
var _serial := 0
var _writer_failures := 0
var _last_error := ""
var _max_callback_usec := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Global.balance_attempt_boundary.connect(_on_boundary)
	Global.balance_segment_completed.connect(_on_segment_completed)
	Global.balance_scene_requested.connect(_on_scene_requested)

func is_recording() -> bool:
	return _active

func set_enabled(value: bool) -> void:
	if not value:
		end_capture("disabled")
	enabled = value

func begin_gameplay(player: Node) -> void:
	if not enabled or (DisplayServer.get_name() == "headless" and not record_headless):
		return
	if not is_instance_valid(player):
		return
	_player_ref = weakref(player)
	_mode = "gameplay"
	_destination = ""
	if not _active:
		flush_reports()
		_serial += 1
		_started_usec = Time.get_ticks_usec()
		var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
		var capture_id := "%s_%d_%d_%d" % [stamp, OS.get_process_id(), _started_usec, _serial]
		capture_directory = ProjectSettings.globalize_path(report_directory.path_join(stamp.substr(0, 10)).path_join(capture_id))
		var slot: int = SaveManager.current_save.slot_index if SaveManager.current_save != null else -1
		var metadata := {"capture_id": capture_id, "run_key": "%d:%s" % [slot, str(Global.attempt_world_seed)],
			"save_slot": slot, "build": Build.describe(Global.attempt_world_seed), "start_segment": Global.attempt_segment,
			"coverage": "observed_session", "starting_debug": _debug_snapshot()}
		_ledger = Ledger.new()
		_ledger.start(metadata, Global.followers, Global.attempt_segment)
		_active = true
		_writer_failures = 0
		_last_error = ""
		_max_callback_usec = 0
		_sample_left = 1.0
		_summary_left = 15.0
		_last_build = {}
		_build_index = 0
		_connect_runtime()
		print("[BalanceRecorder] Recording to ", capture_directory)
	var handles: Array[int] = []
	EnemyWorld.active_handles(handles)
	for handle in handles:
		_observe_enemy(handle, true)
	_capture_build()
	_capture_sample()
	_submit(true)

func _process(delta: float) -> void:
	_accept(_queue.poll_completed())
	if not _active:
		return
	var began := Time.get_ticks_usec()
	if not _destination.is_empty():
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == _destination:
			_mode = "hub" if _destination == Global.PATH_HUB_SHOP else "gameplay"
			_destination = ""
	var mode := _mode
	var player := _player()
	if get_tree().paused:
		mode = "paused"
	elif mode == "gameplay" and (player == null or bool(player.get("is_dead"))):
		mode = "loading"
	_ledger.advance(delta, mode)
	if _build_dirty:
		_capture_build()
	_sample_left -= delta
	_summary_left -= delta
	if _sample_left <= 0.0:
		_sample_left = 1.0
		# Hub changes have no live player to emit a stats callback.
		_capture_build()
		_capture_sample()
		_ledger.flush_window()
		_submit(_summary_left <= 0.0)
		if _summary_left <= 0.0:
			_summary_left = 15.0
	_max_callback_usec = maxi(_max_callback_usec, Time.get_ticks_usec() - began)

func _connect_runtime() -> void:
	_subscribe(Global, &"balance_transaction", _on_transaction)
	_subscribe(EnemyWorld, &"enemy_registered", _on_enemy_registered)
	_subscribe(EnemyWorld, &"enemy_profile_changed", _on_enemy_registered)
	_subscribe(EnemyWorld, &"enemy_removing", _on_enemy_removing)
	_subscribe(RunEvents, &"enemy_damaged", _on_enemy_damaged)
	_subscribe(RunEvents, &"enemy_defeated", _on_enemy_defeated)
	_subscribe(RunEvents, &"weapon_fired", _on_weapon_fired)
	_subscribe(RunEvents, &"player_damage_resolved", _on_player_damage)
	_subscribe(RunEvents, &"player_heal_resolved", _on_player_heal)
	_subscribe(RunEvents, &"player_paid_health", _on_health_paid)
	_subscribe(RunEvents, &"player_life_event", _on_life_event)
	_subscribe(RunEvents, &"player_stats_recomputed", _on_stats_changed)
	_subscribe(RunEvents, &"segment_phase_changed", _on_phase)
	_subscribe(RunEvents, &"healing_lock_changed", _on_healing_lock)
	_subscribe(RunEvents, &"power_threshold_crossed", _on_power_threshold)

func _subscribe(object: Object, signal_name: StringName, callback: Callable) -> void:
	object.connect(signal_name, callback)
	_subscriptions.append([object, signal_name, callback])

func _on_boundary(reason: StringName) -> void:
	end_capture(String(reason))

func _on_scene_requested(path: String) -> void:
	if not _active:
		return
	if path not in [Global.PATH_GAME, Global.PATH_HUB_SHOP]:
		end_capture("suspended")
		return
	_ledger.event("scene_transition", {"target": path})
	_mode = "loading"
	_destination = path
	_capture_build()
	_submit(true)

func _on_segment_completed(segment: int) -> void:
	if not _active:
		return
	_capture_build()
	_capture_sample()
	_ledger.change_segment(segment + 1, "completed")
	_mode = "hub"
	_submit(true)

func end_capture(outcome: String = "suspended") -> void:
	if not _active:
		return
	_capture_build()
	_capture_sample()
	_ledger.finish(outcome)
	for entry in _subscriptions:
		if is_instance_valid(entry[0]) and entry[0].is_connected(entry[1], entry[2]):
			entry[0].disconnect(entry[1], entry[2])
	_subscriptions.clear()
	# Boundaries are safe points; drain the bounded queue before final output.
	flush_reports()
	_submit(true)
	_active = false
	flush_reports()
	print("[BalanceRecorder] ", outcome, " — ", capture_directory.path_join("report.md"))

func _exit_tree() -> void:
	end_capture("application_closed")
	flush_reports()

func flush_reports() -> void:
	_accept(_queue.shutdown())

func _submit(include_summary: bool) -> void:
	# Two outstanding immutable batches plus the bounded ledger buffer. Never
	# block a combat frame on disk, and never grow an unbounded write backlog.
	if _queue.pending_count() >= 2:
		return
	var records: Array[Dictionary] = _ledger.take_records()
	var batch := {"records": records}
	if include_summary:
		batch["summary"] = get_summary()
	if not records.is_empty() or include_summary:
		_queue.enqueue(batch, capture_directory)

func _accept(completions: Array) -> void:
	for completion in completions:
		var result: Dictionary = completion.get("result", {})
		if not bool(result.get("ok", false)):
			_writer_failures += 1
			_last_error = str(result.get("error", "Unknown balance writer failure"))
			push_warning("[BalanceRecorder] Capture incomplete: " + _last_error)

func get_summary() -> Dictionary:
	if _ledger == null:
		return {}
	var result: Dictionary = _ledger.summary()
	result["writer_failures"] = _writer_failures
	result["last_error"] = _last_error
	result["max_sample_callback_usec"] = _max_callback_usec
	result["wall_seconds"] = float(Time.get_ticks_usec() - _started_usec) / 1000000.0
	return result

func _player() -> Node:
	return _player_ref.get_ref() as Node if _player_ref != null else null

func _on_transaction(before: int, change: int, after: int, reason: StringName, context: Dictionary) -> void:
	_ledger.transaction(before, change, after, String(reason), Writer.json_safe(context))

func _observe_enemy(handle: int, at_entry: bool = false) -> void:
	if not EnemyWorld.is_valid_handle(handle):
		return
	_ledger.enemy_seen(handle, String(EnemyWorld.get_spec_id(handle)), Types.has_flag(EnemyWorld.get_flags(handle), Types.Flags.ELITE), EnemyWorld.get_max_health(handle), at_entry)

func _on_enemy_registered(handle: int) -> void:
	_observe_enemy(handle)

func _on_enemy_removing(handle: int, reason: StringName) -> void:
	_ledger.enemy_removed(handle, String(reason))

func _on_enemy_damaged(handle: int, applied: float, adjusted: float, _health_before: float, source: Node, payload: Variant) -> void:
	var hit := payload as HitLedger
	_ledger.enemy_damage(handle, applied, adjusted, hit.hit_count if hit != null else 1, hit.critical_hits if hit != null else 0, source != null and source == _player())

func _on_enemy_defeated(context: RefCounted) -> void:
	_ledger.enemy_defeated(int(context.get("handle")))

func _on_weapon_fired(player: Node, _style: StringName, _origin: Vector2, _target: Vector2, _power: float, _haste: float) -> void:
	if player == _player():
		_ledger.add_metric("attacks")

func _on_player_damage(player: Node, raw: float, adjusted: float, applied: float, source: Node, kind: StringName, outcome: StringName) -> void:
	if player == _player():
		_ledger.player_damage(raw, adjusted, applied, _source_id(source, kind), String(outcome))

func _source_id(source: Node, fallback: StringName) -> String:
	if not is_instance_valid(source):
		return String(fallback)
	if "spec" in source:
		var spec: Variant = source.get("spec")
		if spec != null and "id" in spec:
			return String(spec.get("id"))
	# Actors bound to an EnemyWorld handle (proxies, plain bodies) carry their
	# archetype in the world record rather than on the node.
	if EnemyCombat != null and EnemyCombat.has_method("handle_for_actor"):
		var handle := int(EnemyCombat.handle_for_actor(source))
		if handle != 0 and EnemyWorld.is_valid_handle(handle):
			var spec_id := String(EnemyWorld.get_spec_id(handle))
			if not spec_id.is_empty():
				return spec_id
	var script := source.get_script() as Script
	return script.resource_path if script != null else String(fallback)

func _on_player_heal(player: Node, requested: float, modified: float, applied: float, source: StringName, blocked: bool) -> void:
	if player == _player():
		_ledger.player_heal(requested, modified, applied, String(source), blocked)

func _on_health_paid(player: Node, amount: float, reason: StringName) -> void:
	if player == _player():
		_ledger.add_metric("hp_paid", amount)
		_ledger.event("health_paid", {"amount": amount, "reason": String(reason)})

func _on_life_event(player: Node, kind: StringName) -> void:
	if player != _player():
		return
	var metric: String = {"death": "deaths", "respawn": "respawns", "rescue": "rescues"}.get(String(kind), "")
	if not metric.is_empty():
		_ledger.add_metric(metric)
	_ledger.event("player_" + String(kind), {"hp": player.get("hp"), "max_hp": player.get("max_hp"), "followers": Global.followers})
	_capture_sample()

func _on_stats_changed(player: Node) -> void:
	if player == _player():
		_build_dirty = true

func _on_phase(phase: StringName, label: String) -> void:
	_ledger.event("phase", {"phase": String(phase), "label": label})

func _on_healing_lock(seconds: float, reason: StringName) -> void:
	_ledger.event("healing_lock", {"seconds": seconds, "reason": String(reason)})

func _on_power_threshold(id: StringName, label: String) -> void:
	_ledger.event("power_threshold", {"id": String(id), "label": label})

func _debug_snapshot() -> Dictionary:
	var result := {}
	for field in DEBUG_FIELDS:
		result[field] = Global.get(field)
	result["time_scale"] = Engine.time_scale
	return result

func _stats(resource: Resource) -> Dictionary:
	var result := {}
	if resource != null:
		for field in STAT_FIELDS:
			result[field] = resource.get(field)
	return result

func _capture_build() -> void:
	_build_dirty = false
	var snapshot := {"race": Global.selected_race_id, "style": Global.selected_style_id,
		"weapon": Global.selected_weapon_id, "spells": Global.equipped_spell_ids.duplicate(),
		"items": [], "augments": [], "ascension": {}, "doctrine_rules": Global.attempt_doctrine_rules.duplicate(true)}
	if Global.run_inventory != null:
		for item in Global.run_inventory.items:
			if item == null:
				snapshot.items.append(null)
			else:
				snapshot.items.append({"id": String(item.data.id) if item.data != null else "unknown", "rarity": item.rarity,
					"polarity": item.polarity, "best_pct": item.best_pct, "upgrade_meter": item.upgrade_meter,
					"manifestation": String(item.manifestation_id), "mods": _stats(item.rolled_mods)})
	for id in Global.permanent_augment_ids:
		snapshot.augments.append({"id": String(id), "level": Global.get_augment_level(id)})
	for key in ["native_core", "cores", "owned", "equipped", "disabled_mutations"]:
		snapshot.ascension[key] = Global.attempt_ascension.get(key, null)
	var player := _player()
	if player != null and _mode == "gameplay":
		snapshot["stats"] = _stats(player.get("stats"))
		snapshot["stat_contributions"] = Global.last_stat_ledger.duplicate(true)
	if snapshot != _last_build:
		_build_index += 1
		_last_build = snapshot.duplicate(true)
		snapshot["build_index"] = _build_index
		_ledger.event("build", snapshot)

func _capture_sample() -> void:
	var sample := {"mode": _mode, "paused": get_tree().paused, "build_index": _build_index,
		"followers": Global.followers, "enemies_alive": EnemyWorld.active_count(), "pressure": {}, "debug": _debug_snapshot()}
	for field in PRESSURE_FIELDS:
		sample.pressure[field] = ThreatDirector.get(field)
	var player := _player()
	if player != null and _mode == "gameplay":
		sample["player"] = {"hp": player.get("hp"), "max_hp": player.get("max_hp"), "stats": _stats(player.get("stats")),
			"position": [player.global_position.x, player.global_position.y], "dead": player.get("is_dead"), "healing_lock_seconds": player.call("healing_locked_seconds")}
		var effects := {}
		for name in ["ItemEffectRunner", "ManifestationRunner", "AscensionRunner"]:
			var runner := player.get_node_or_null(NodePath(name))
			if runner == null:
				continue
			var row := {}
			for method in ["get_power_multiplier", "get_haste_multiplier", "get_damage_taken_multiplier"]:
				if runner.has_method(method):
					row[method] = runner.call(method)
			effects[name] = row
		sample["effect_multipliers"] = effects
	_ledger.event("sample", sample)
