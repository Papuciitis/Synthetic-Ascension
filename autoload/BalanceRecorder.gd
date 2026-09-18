extends Node

const Ledger := preload("res://core/systems/telemetry/BalanceLedger.gd")
const Writer := preload("res://core/systems/telemetry/BalanceCaptureWriter.gd")
const WriteQueue := preload("res://autoload/performance/PerformanceIncidentWriteQueue.gd")
const Build := preload("res://core/systems/telemetry/BuildInfo.gd")
const History := preload("res://core/systems/telemetry/BalanceRecentHistory.gd")
const Types := preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const STAT_FIELDS := ["max_hp", "armor", "move_speed", "power", "haste", "luck"]
const PRESSURE_FIELDS := ["threat", "heat", "overtime", "resonance", "enemy_hp_mul", "enemy_damage_mul", "enemy_speed_mul", "spawn_interval_mul", "elite_bonus", "segment_phase", "rite_channel_active", "power_contrast_active"]
## Recorder contract revision, separate from the item-balance revision so an
## instrumentation-only capture can never be mistaken for a tuned build.
const RECORDER_REVISION := 2
const BALANCE_REVISION := 1
## What this recorder measures; an omitted feature reads as unavailable, not 0.
const FEATURES := {"pure_snapshots": true, "health_reconciliation": true, "source_attribution": true,
	"incidents": true, "exit_detail": true, "progression": false}
## Incident history: cheap state at 5 Hz during live gameplay, enemies counted
## by archetype inside NEARBY_RADIUS px through the bounded spatial query, and
## a serialized ceiling per persisted incident (oldest history trimmed first).
const HISTORY_SAMPLE_INTERVAL := 0.2
const NEARBY_RADIUS := 240.0
const NEARBY_QUERY_CAP := 256
const INCIDENT_BYTE_CEILING := 2 * 1024 * 1024
const HISTORY_PRESSURE_FIELDS := ["threat", "heat", "overtime", "resonance", "enemy_hp_mul", "enemy_damage_mul", "spawn_interval_mul", "elite_bonus", "segment_phase", "rite_channel_active"]
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
var _history: RefCounted = History.new()
var _history_left := HISTORY_SAMPLE_INTERVAL
var _player_subscriptions: Array = []
var _nearby: Array[int] = []
var _incidents: Dictionary = _empty_incidents()

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
			"coverage": "observed_session", "starting_debug": _debug_snapshot(),
			"recorder_revision": RECORDER_REVISION, "balance_revision": BALANCE_REVISION,
			"tuning_stages": [], "tuning_hash": "", "features": FEATURES.duplicate()}
		_ledger = Ledger.new()
		_ledger.start(metadata, Global.followers, Global.attempt_segment)
		if "hp" in player and "max_hp" in player:
			_ledger.begin_life(float(player.get("hp")), float(player.get("max_hp")), "capture_start")
		_active = true
		_writer_failures = 0
		_last_error = ""
		_max_callback_usec = 0
		_sample_left = 1.0
		_summary_left = 15.0
		_last_build = {}
		_build_index = 0
		_history.reset(_ledger.current_life_id(), 0.0)
		_history_left = HISTORY_SAMPLE_INTERVAL
		_incidents = _empty_incidents()
		_connect_runtime()
		print("[BalanceRecorder] Recording to ", capture_directory)
	_connect_player(player)
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
	if mode == "gameplay":
		_history_left -= delta
		if _history_left <= 0.0:
			_history_left = HISTORY_SAMPLE_INTERVAL
			_history.push_sample(_history_sample(player))
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
	_subscribe(RunEvents, &"balance_health_changed", _on_health_changed)
	_subscribe(RunEvents, &"player_life_event", _on_life_event)
	_subscribe(RunEvents, &"player_stats_recomputed", _on_stats_changed)
	_subscribe(RunEvents, &"segment_phase_changed", _on_phase)
	_subscribe(RunEvents, &"healing_lock_changed", _on_healing_lock)
	_subscribe(RunEvents, &"power_threshold_crossed", _on_power_threshold)
	_subscribe(RunEvents, &"player_ability_activated", _on_ability_activated)
	_subscribe(RunEvents, &"player_dashed", _on_dashed)
	_subscribe(RunEvents, &"exit_rite_event", _on_exit_event)
	_subscribe(RunEvents, &"spawn_request_resolved", _on_spawn_resolved)
	_subscribe(RunEvents, &"encounter_event", _on_encounter_event)
	_subscribe(RunEvents, &"overtime_pressure_injected", _on_overtime_injected)
	_subscribe(ThreatDirector, &"rite_channel_changed", _on_rite_channel)

func _subscribe(object: Object, signal_name: StringName, callback: Callable) -> void:
	object.connect(signal_name, callback)
	_subscriptions.append([object, signal_name, callback])

## Per-player signals (guard and resource spends live on the Manifestation
## state under the player, not on an autoload); rebound on every gameplay entry.
func _connect_player(player: Node) -> void:
	_disconnect_player()
	var runner := player.get_node_or_null(^"ManifestationRunner")
	var state: Variant = runner.get("state") if runner != null else null
	if state is Object and (state as Object).has_signal("resource_spent"):
		state.connect(&"resource_spent", _on_resource_spent)
		state.connect(&"resource_filled", _on_resource_filled)
		_player_subscriptions.append([state, &"resource_spent", _on_resource_spent])
		_player_subscriptions.append([state, &"resource_filled", _on_resource_filled])

func _disconnect_player() -> void:
	for entry in _player_subscriptions:
		if is_instance_valid(entry[0]) and entry[0].is_connected(entry[1], entry[2]):
			entry[0].disconnect(entry[1], entry[2])
	_player_subscriptions.clear()

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
	_disconnect_player()
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
	result["wall_seconds"] = _wall_seconds()
	result["incidents"] = _incidents.duplicate()
	var ring: Dictionary = _history.stats()
	ring["retain_seconds"] = _history.retain_seconds
	ring["event_cap"] = _history.event_cap
	ring["sample_cap"] = _history.sample_cap
	result["history"] = ring
	return result

func _wall_seconds() -> float:
	return float(Time.get_ticks_usec() - _started_usec) / 1000000.0

static func _empty_incidents() -> Dictionary:
	return {"deaths": 0, "captures": 0, "bytes": 0, "ceiling": INCIDENT_BYTE_CEILING, "trimmed_events": 0, "trimmed_samples": 0, "history_incomplete": 0}

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

func _on_enemy_damaged(handle: int, applied: float, adjusted: float, health_before: float, source: Node, payload: Variant) -> void:
	var hit := payload as HitLedger
	# Provenance is normalized from the payload only (tags or a telemetry-only
	# object); a tagless hit is unknown even when the player owns the node.
	var provenance := BalanceAttribution.from_payload(payload)
	_ledger.enemy_damage(handle, applied, adjusted, hit.hit_count if hit != null else 1, hit.critical_hits if hit != null else 0, source != null and source == _player(), provenance, applied >= health_before - 0.000001)

func _on_enemy_defeated(context: RefCounted) -> void:
	_ledger.enemy_defeated(int(context.get("handle")))

func _on_weapon_fired(player: Node, _style: StringName, _origin: Vector2, _target: Vector2, _power: float, _haste: float) -> void:
	if player == _player():
		_ledger.add_metric("attacks")

func _on_player_damage(player: Node, raw: float, adjusted: float, applied: float, source: Node, kind: StringName, outcome: StringName) -> void:
	if player != _player():
		return
	var source_id := _source_id(source, kind)
	_ledger.player_damage(raw, adjusted, applied, source_id, String(outcome))
	_push_history("damage", {"source": source_id, "attack": String(kind), "outcome": String(outcome), "raw": raw, "adjusted": adjusted, "applied": applied})

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
	if player != _player():
		return
	_ledger.player_heal(requested, modified, applied, String(source), blocked)
	# Applied heals reach the ring through their health-change record; a heal
	# that moved no HP leaves none, so it is kept here (lock, full health).
	if blocked or applied <= 0.0:
		_push_history("heal_refused", {"source": String(source), "requested": requested, "blocked": blocked, "key": String(source)})

## The canonical health-change record. Costs feed the hp_paid metric here
## (once); hits and heals keep their metrics from the resolved signals.
func _on_health_changed(player: Node, change: Dictionary) -> void:
	if player != _player():
		return
	var record := change.duplicate()
	var source_node: Variant = record.get("source_node", null)
	record.erase("source_node")
	if String(record.get("source_id", "")).is_empty():
		record["source_id"] = _source_id(source_node as Node if source_node is Node else null, StringName(String(record.get("reason", "unknown"))))
	record["wall_seconds"] = _wall_seconds()
	_ledger.record_health_change(Writer.json_safe(record))
	var category := String(record.get("category", ""))
	if category == "respawn":
		# The death context was frozen at the death event; the new life starts
		# with an empty ring whose first record is the reconstruction itself.
		_history.reset(_ledger.current_life_id(), _ledger.gameplay_seconds())
	var entry := {"category": category, "source": String(record.get("source_id", "")), "reason": String(record.get("reason", "")),
		"hp_before": float(record.get("hp_before", 0.0)), "hp_after": float(record.get("hp_after", 0.0)),
		"max_hp": float(record.get("max_hp_after", 0.0)), "requested": float(record.get("requested", 0.0)),
		"delta": float(record.get("hp_after", 0.0)) - float(record.get("hp_before", 0.0)), "life": _ledger.current_life_id()}
	if category == "heal":
		entry["key"] = entry["source"]
	_push_history("health", entry)

func _on_life_event(player: Node, kind: StringName) -> void:
	if player != _player():
		return
	var metric: String = {"death": "deaths", "respawn": "respawns", "rescue": "rescues"}.get(String(kind), "")
	if not metric.is_empty():
		_ledger.add_metric(metric)
	_push_history("life", {"event": String(kind), "hp": float(player.get("hp")), "max_hp": float(player.get("max_hp"))})
	var record := {"hp": player.get("hp"), "max_hp": player.get("max_hp"), "followers": Global.followers}
	if kind == &"death":
		# Frozen here, inside die(), before the reconstruction card, the
		# respawn or a scene change can touch the player or the ring.
		_persist_incident("death_context", "death", player)
		_incidents["deaths"] = int(_incidents["deaths"]) + 1
		_ledger.note_death(bool(_exit_snapshot().get("inside", false)))
		_ledger.end_life("death")
	elif kind == &"respawn":
		# The reconstruction anchor and its protection, and how far the exit is.
		_ledger.note_respawn()
		var anchor: Vector2 = player.get("spawn_pos")
		record["anchor"] = [anchor.x, anchor.y]
		record["invulnerable"] = float(player.get("invulnerable_time"))
		record["phase_left"] = float(player.get("respawn_phase_left"))
		record["exit_distance"] = player.global_position.distance_to(Global.exit_gate_pos) if Global.exit_gate_pos != Vector2.INF else null
	_ledger.event("player_" + String(kind), record)
	_capture_sample()

func _on_stats_changed(player: Node) -> void:
	if player == _player():
		_build_dirty = true

func _on_phase(phase: StringName, label: String) -> void:
	_ledger.event("phase", {"phase": String(phase), "label": label})
	_push_history("phase", {"phase": String(phase), "label": label})

func _on_healing_lock(seconds: float, reason: StringName) -> void:
	_ledger.event("healing_lock", {"seconds": seconds, "reason": String(reason)})
	_push_history("healing_lock", {"seconds": seconds, "reason": String(reason)})

func _on_ability_activated(player: Node, slot: StringName, id: String, cooldown: float) -> void:
	if player == _player():
		_push_history("ability", {"slot": String(slot), "id": id, "cooldown": cooldown})

func _on_dashed(player: Node, from: Vector2, direction: Vector2) -> void:
	if player == _player():
		_push_history("dash", {"pos": [from.x, from.y], "dir": [direction.x, direction.y]})

func _on_resource_spent(noun: StringName, amount: float) -> void:
	_push_history("resource_spent", {"noun": String(noun), "amount": amount})

func _on_resource_filled(noun: StringName) -> void:
	_push_history("resource_filled", {"noun": String(noun)})

func _on_exit_event(_rite: Node, kind: StringName, data: Dictionary) -> void:
	_ledger.exit_event(String(kind), Writer.json_safe(data))
	_push_history("exit", {"event": String(kind), "hold": float(data.get("hold", 0.0)), "progress": float(data.get("progress", 0.0)), "inside": bool(data.get("inside", false))})

func _on_spawn_resolved(source: StringName, outcome: StringName, count: int, _data: Dictionary) -> void:
	_ledger.spawn_resolved(String(source), String(outcome), count)
	_push_history("spawn", {"source": String(source), "outcome": String(outcome), "count": count})

func _on_encounter_event(kind: StringName, data: Dictionary) -> void:
	_ledger.encounter_event(String(kind), Writer.json_safe(data))
	_push_history("encounter", {"event": String(kind), "beat": String(data.get("beat", "")), "members": int(data.get("members", 0))})

func _on_overtime_injected(contributor: String, seconds: float, unseal_seconds: float, overtime: float) -> void:
	_ledger.overtime_injection(contributor, seconds, unseal_seconds, overtime)
	_push_history("overtime", {"contributor": contributor, "seconds": seconds, "unseal_seconds": unseal_seconds, "overtime": overtime})

func _on_rite_channel(active: bool) -> void:
	_ledger.event("rite_channel", {"active": active, "pressure": _pressure_snapshot()})
	_push_history("rite_channel", {"active": active})

func _pressure_snapshot() -> Dictionary:
	if ThreatDirector.has_method("balance_snapshot"):
		return ThreatDirector.balance_snapshot()
	var result := {}
	for field in PRESSURE_FIELDS:
		result[field] = ThreatDirector.get(field)
	return result

## Living and pending exit reinforcements as their owners count them: the
## encounter director's formations by beat id and the spawner's reservations.
func _reinforcements() -> Dictionary:
	var result := {}
	var director := get_tree().get_first_node_in_group(&"encounter_director")
	if director != null and director.has_method("balance_snapshot"):
		result["encounters"] = director.call("balance_snapshot")
	var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")
	if spawner != null and spawner.has_method("balance_snapshot"):
		result["spawner"] = spawner.call("balance_snapshot")
	return result

## Public: freeze the current context on request (developer overlay, tests).
## Persisted only here and on death, never on a normal tick.
func capture_incident(reason: StringName = &"manual") -> void:
	if not _active:
		return
	_persist_incident("incident_context", String(reason), _player())
	_incidents["captures"] = int(_incidents["captures"]) + 1

func _push_history(kind: String, data: Dictionary) -> void:
	data["kind"] = kind
	data["t"] = _ledger.gameplay_seconds()
	data["wall"] = _wall_seconds()
	_history.push_event(data)

# ---------------------------------------------------------------- incident context

func _persist_incident(record_kind: String, reason: String, player: Node) -> void:
	var context := _build_incident(reason, player)
	_incidents["bytes"] = int(_incidents["bytes"]) + int(context.get("serialized_bytes", 0))
	var trimmed: Dictionary = context.get("trimmed", {})
	_incidents["trimmed_events"] = int(_incidents["trimmed_events"]) + int(trimmed.get("events", 0))
	_incidents["trimmed_samples"] = int(_incidents["trimmed_samples"]) + int(trimmed.get("samples", 0))
	if not bool(context.history.get("complete", true)):
		_incidents["history_incomplete"] = int(_incidents["history_incomplete"]) + 1
	# Owned: the snapshot is already an immutable copy. Critical: the pending
	# cap protects against per-frame floods, not one record per death.
	_ledger.event(record_kind, context, true, true)
	_submit(false)

## Everything a reader needs to explain this moment from the incident alone.
## The history is a deep copy at this instant; the effect snapshot is the
## runners' pure report; the build is referenced by index and copied once.
func _build_incident(reason: String, player: Node) -> Dictionary:
	var now: float = _ledger.gameplay_seconds()
	var life: Dictionary = _ledger.life_info()
	var alive := is_instance_valid(player) and "hp" in player
	var history: Dictionary = _history.snapshot(now)
	var context := {"reason": reason, "life_id": int(life.life_id), "t": now, "wall": _wall_seconds(),
		"segment": Global.attempt_segment, "segment_phase": String(ThreatDirector.segment_phase), "mode": _mode,
		"paused": get_tree().paused, "followers": Global.followers,
		"terminal": _terminal_event(), "history": history,
		"state": _history_sample(player) if alive else {}, "effects": _effects(player) if alive else {},
		"build_index": _build_index, "build": _last_build.duplicate(true),
		"health": {"expected_hp": float(life.expected_hp), "residual": float(life.residual),
			"unexplained_checks": int(life.unexplained_checks), "changes": int(life.changes)},
		"reconstruction_age": now - float(life.started_gameplay), "debug": _debug_snapshot()}
	context["trimmed"] = History.fit_to_bytes(context, INCIDENT_BYTE_CEILING)
	return context

## The exact terminal health change (the last record that left HP at 0) and
## the resolved-damage record that followed it, if any; null while alive.
func _terminal_event() -> Variant:
	var lethal: Dictionary = _history.find_last("health", func(record: Dictionary) -> bool: return float(record.get("hp_after", 1.0)) <= 0.0)
	if lethal.is_empty():
		return null
	var following: Dictionary = _history.event_after(int(lethal.get("seq", 0)))
	var resolution: Variant = following.duplicate(true) if String(following.get("kind", "")) == "damage" else null
	return {"event": lethal.duplicate(true), "resolution": resolution}

## Cheap live state at 5 Hz: no runner snapshots, no inventory copies (the
## build is referenced by index) and one bounded spatial query.
func _history_sample(player: Node) -> Dictionary:
	var now: float = _ledger.gameplay_seconds()
	var life: Dictionary = _ledger.life_info()
	var stats: Variant = player.get("stats")
	var sample := {"t": now, "wall": _wall_seconds(), "hp": float(player.get("hp")), "max_hp": float(player.get("max_hp")),
		"armor": float(stats.get("armor")) if stats is Resource else null,
		"pos": [player.global_position.x, player.global_position.y],
		"dash_ready": player.call("dash_ready") if player.has_method("dash_ready") else null,
		"dash_cooldown": player.call("dash_cooldown_left") if player.has_method("dash_cooldown_left") else null,
		"dashing": player.call("is_dashing") if player.has_method("is_dashing") else null,
		"invulnerable": float(player.get("invulnerable_time")), "phase_left": float(player.get("respawn_phase_left")),
		"healing_lock": player.call("healing_locked_seconds") if player.has_method("healing_locked_seconds") else null,
		"life": int(life.life_id), "since_life_start": now - float(life.started_gameplay), "expected_hp": float(life.expected_hp),
		"enemies_alive": EnemyWorld.active_count(), "nearby": _nearby_counts(player.global_position),
		"pressure": {}, "exit": _exit_snapshot(), "build_index": _build_index}
	for field in HISTORY_PRESSURE_FIELDS:
		sample.pressure[field] = ThreatDirector.get(field)
	return sample

func _nearby_counts(origin: Vector2) -> Dictionary:
	var result := {"radius": NEARBY_RADIUS, "total": 0, "elite": 0, "by_spec": {}, "truncated": false}
	if EnemyCombat == null or not EnemyCombat.has_method("gather_in_radius"):
		return result
	EnemyCombat.gather_in_radius(origin, NEARBY_RADIUS, _nearby)
	result["total"] = _nearby.size()
	var counted := 0
	for handle in _nearby:
		if counted >= NEARBY_QUERY_CAP:
			result["truncated"] = true
			break
		counted += 1
		var spec := String(EnemyWorld.get_spec_id(handle))
		result.by_spec[spec] = int(result.by_spec.get(spec, 0)) + 1
		if Types.has_flag(EnemyWorld.get_flags(handle), Types.Flags.ELITE):
			result["elite"] = int(result["elite"]) + 1
	return result

func _exit_snapshot() -> Dictionary:
	var rite := get_tree().get_first_node_in_group(&"exit_rite")
	if rite == null or not rite.has_method("balance_snapshot"):
		return {}
	return rite.call("balance_snapshot")

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
		"followers": Global.followers, "enemies_alive": EnemyWorld.active_count(), "pressure": _pressure_snapshot(),
		"exit": _exit_snapshot(), "reinforcements": _reinforcements(), "debug": _debug_snapshot()}
	_ledger.observe_pressure(sample.pressure)
	var player := _player()
	if player != null and _mode == "gameplay":
		if not bool(player.get("is_dead")):
			_ledger.observe_hp(float(player.get("hp")), float(player.get("max_hp")))
		sample["player"] = {"hp": player.get("hp"), "max_hp": player.get("max_hp"), "stats": _stats(player.get("stats")),
			"position": [player.global_position.x, player.global_position.y], "dead": player.get("is_dead"), "healing_lock_seconds": player.call("healing_locked_seconds")}
		sample["effects"] = _effects(player)
	_ledger.event("sample", sample)

## Observation only. The runners' get_*_multiplier() getters are combat
## operations (ManifestationRunner's spends the banked Composure guard and
## Reliquary Guard's arms the latch that pays a shard), so a sample never
## calls them; each runner reports through its pure get_balance_snapshot()
## and a runner without one is recorded as unavailable, not as 1.0.
func _effects(player: Node) -> Dictionary:
	var effects := {}
	for runner_name in ["ItemEffectRunner", "ManifestationRunner", "AscensionRunner"]:
		var runner := player.get_node_or_null(NodePath(runner_name))
		if runner == null:
			continue
		effects[runner_name] = runner.call("get_balance_snapshot") if runner.has_method("get_balance_snapshot") else null
	return effects
