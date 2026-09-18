extends Node

# Bounded incident history. First the pure buffer under an injected gameplay
# clock (expiry, a stalled clock, coalescing, both caps, immutable snapshots,
# the byte ceiling); then the runtime recorder against the real player through
# a heal, a cost, a refused heal and a lethal hit, with the death context
# frozen before the immediate reconstruction and read back after an immediate
# capture shutdown.
#
# Run: <godot> --headless --path . res://tools/tests/BalanceIncidentHistoryTest.tscn

const PLAYER := preload("res://core/actors/player/player.tscn")
const SpawnState := preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const History := preload("res://core/systems/telemetry/BalanceRecentHistory.gd")

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


func _event(t: float, kind: String, extra: Dictionary = {}) -> Dictionary:
	var record := {"kind": kind, "t": t, "wall": t * 2.0}
	record.merge(extra)
	return record


func _run() -> void:
	_buffer_checks()
	await _runtime_checks()
	_finish()


func _buffer_checks() -> void:
	var history = History.new()
	# Injected clock: one event every half second through seconds 0..10.
	for i in range(21):
		history.push_event(_event(i * 0.5, "tick", {"i": i}))
	var snap: Dictionary = history.snapshot(10.0)
	var events: Array = snap.events
	_check(events.size() == 11 and float(events[0].t) == 5.0 and float(events[-1].t) == 10.0 and int(events[0].i) == 10, "at time 10 only seconds 5..10 remain (%d events, first t=%.1f)" % [events.size(), float(events[0].t) if not events.is_empty() else -1.0])
	_check(absf(float(snap.retained_seconds) - 5.0) < 0.000001 and int(snap.events_expired) == 10 and int(snap.events_overwritten) == 0 and bool(snap.complete), "expiry runs on the gameplay clock and is counted apart from overwrite")
	# A pause: the clock stands still, so nothing more expires however long it lasts.
	var again: Dictionary = history.snapshot(10.0)
	_check(again.events.size() == 11 and int(again.events_expired) == 10, "a stalled gameplay clock keeps the whole window")
	_check(float(snap.wall_span_seconds) == 10.0, "wall time is carried separately from the gameplay clock")
	# Immutability: the copy the worker would receive never changes.
	snap.events[0]["i"] = 999
	history.push_event(_event(10.2, "tick", {"i": 99}))
	var third: Dictionary = history.snapshot(10.2)
	_check(snap.events.size() == 11 and int(snap.events[-1].i) == 20, "an earlier snapshot is unchanged by later pushes")
	_check(int(third.events[0].i) == 11 and int(third.events[-1].i) == 99 and third.events.size() == 11, "the live ring is unchanged by edits to a snapshot (first i=%d)" % int(third.events[0].i))

	# Coalescing: identical same-step heals merge exactly, never across damage.
	var steps = History.new()
	steps.push_event(_event(1.0, "health", {"key": "heal:regen", "category": "heal", "delta": 1.5, "hp_after": 51.5}))
	steps.push_event(_event(1.0, "health", {"key": "heal:regen", "category": "heal", "delta": 1.5, "hp_after": 53.0}))
	steps.push_event(_event(1.0, "damage", {"applied": 10.0}))
	steps.push_event(_event(1.0, "health", {"key": "heal:regen", "category": "heal", "delta": 1.5, "hp_after": 44.5}))
	steps.push_event(_event(1.2, "health", {"key": "heal:regen", "category": "heal", "delta": 1.5, "hp_after": 46.0}))
	var merged: Dictionary = steps.snapshot(1.2)
	_check(merged.events.size() == 4 and int(merged.events[0].n) == 2 and float(merged.events[0].delta) == 3.0 and float(merged.events[0].hp_after) == 53.0 and int(merged.coalesced) == 1, "identical same-step heals coalesce exactly and never across a damage record or a step boundary (%d events)" % merged.events.size())

	# Both caps independently, with the loss counted.
	var dense = History.new()
	for i in range(3000):
		dense.push_event(_event(1.0, "tick", {"i": i}))
	for i in range(40):
		dense.push_sample({"t": 1.0, "i": i})
	var full: Dictionary = dense.snapshot(1.0)
	_check(full.events.size() == 2048 and int(full.events_overwritten) == 952 and int(full.events[0].i) == 952 and int(full.events[-1].i) == 2999, "the event cap keeps the newest 2,048 and counts the 952 overwritten")
	_check(full.samples.size() == 32 and int(full.samples_overwritten) == 8 and int(full.samples[-1].i) == 39 and not bool(full.complete), "the sample cap keeps the newest 32 and marks the history incomplete")

	# Byte ceiling: the oldest history goes first; the terminal event and the
	# latest state never do, and the trim is reported inside the context.
	var context := {"terminal": {"event": {"kind": "health", "hp_after": 0.0}}, "history": full, "state": {"hp": 0.0}}
	var trimmed: Dictionary = History.fit_to_bytes(context, 20 * 1024)
	var bytes := JSON.stringify(context).to_utf8_buffer().size()
	_check(bytes <= 20 * 1024 and int(trimmed.events) > 0 and context.history.events.size() < 2048 and int(context.history.events[-1].i) == 2999, "the ceiling trims the oldest events first and keeps the newest (%d bytes, %d events trimmed)" % [bytes, int(trimmed.events)])
	_check(context.history.samples.size() == 32 and float(context.terminal.event.hp_after) == 0.0 and float(context.state.hp) == 0.0, "samples, the terminal event and the state survive an event-only trim")
	_check(int(context.history.trimmed_events) == int(trimmed.events) and absi(int(context.serialized_bytes) - bytes) <= 8 and not bool(context.over_ceiling), "the trim is reported inside the context (%d reported, %d measured)" % [int(context.serialized_bytes), bytes])
	var tiny := {"terminal": {"event": {"hp_after": 0.0}}, "history": dense.snapshot(1.0), "state": {}}
	History.fit_to_bytes(tiny, 100)
	_check(tiny.history.events.is_empty() and tiny.history.samples.size() == 1 and int(tiny.history.samples[0].i) == 39 and float(tiny.terminal.event.hp_after) == 0.0 and bool(tiny.over_ceiling), "an impossible ceiling still keeps the latest sample and the terminal event and says it is over")


func _runtime_checks() -> void:
	var recorder := get_node_or_null("/root/BalanceRecorder")
	_check(recorder != null, "runtime balance recorder is installed")
	if recorder == null:
		return
	Global.start_new_attempt()
	Global.attempt_segment = 2
	Global.debug_player_god_mode = false
	Global.permanent_augment_ids = [StringName(), StringName(), StringName()]
	Global.run_luck = 0.0
	Global.set_followers(500)
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
	var dir := "user://balance_incident_test_%s" % Time.get_ticks_usec()
	recorder.report_directory = dir
	recorder.record_headless = true
	recorder.begin_gameplay(player)
	recorder.set_process(false)
	_check(recorder.is_recording() and bool(recorder.get_summary().metadata.features.incidents), "explicit headless capture starts with incidents measured")
	var attacker := Node2D.new()
	attacker.global_position = player.global_position + Vector2(40, 0)
	add_child(attacker)
	var handle := EnemyWorld.create_enemy(SpawnState.new(&"recorder_normal", "res://recorder_normal.tscn", attacker.global_position, 50.0, 10.0, 8.0, 0, 0))
	EnemyWorld.bind_actor(handle, attacker)

	# One second of live gameplay in 0.2 s steps: five cheap samples.
	for i in range(5):
		recorder._process(0.2)
	var ring: Dictionary = recorder._history.stats()
	_check(int(ring.samples) == 5 and int(ring.life_id) == 1, "live gameplay samples state at 5 Hz (%d samples, life %d)" % [int(ring.samples), int(ring.life_id)])
	var live_sample: Dictionary = recorder._history.snapshot(recorder._ledger.gameplay_seconds()).samples[-1]
	_check(float(live_sample.hp) == 100.0 and int(live_sample.nearby.total) == 1 and int(live_sample.nearby.by_spec.get("recorder_normal", 0)) == 1 and live_sample.pressure.has("threat") and live_sample.has("dash_ready") and live_sample.has("since_life_start"), "a sample carries HP, the bounded nearby count by archetype, pressure and protection state")
	# Six seconds paused: the gameplay clock stands still, nothing expires and
	# nothing is sampled.
	var gameplay_before: float = recorder._ledger.gameplay_seconds()
	get_tree().paused = true
	for i in range(30):
		recorder._process(0.2)
	get_tree().paused = false
	var after_pause: Dictionary = recorder._history.snapshot(recorder._ledger.gameplay_seconds())
	_check(recorder._ledger.gameplay_seconds() == gameplay_before and after_pause.samples.size() == 5 and int(after_pause.samples_expired) == 0, "a pause adds no gameplay time, expires nothing and samples nothing")

	# The last life: a hit, a heal, a cost, a refused heal, then the lethal hit
	# between two periodic samples.
	player.take_damage(20.0, attacker)
	player.heal(5.0, &"pickup")
	player.pay_health(3.0, &"fixture")
	player.lock_healing(2.0, &"test")
	player.heal(4.0, &"pickup")
	_check(player.hp == 82.0, "the fixture leaves the player at 82 HP (%.1f)" % player.hp)
	var deaths_before: int = int(recorder.get_summary().incidents.deaths)
	player.take_damage(1000.0, attacker)
	# die() reconstructs immediately here (no reconstruction card in a test).
	_check(not bool(player.is_dead) and player.hp == player.max_hp, "the real player reconstructed immediately after the lethal hit (hp %.1f)" % player.hp)
	var summary: Dictionary = recorder.get_summary()
	_check(int(summary.incidents.deaths) == deaths_before + 1 and int(summary.totals.deaths) == 1 and int(summary.incidents.bytes) > 0, "the death persisted one incident (%d bytes)" % int(summary.incidents.bytes))
	ring = recorder._history.stats()
	_check(int(ring.life_id) == 2 and int(ring.events) == 2 and int(ring.samples) == 0, "the new life starts with a fresh ring holding only the reconstruction (%d events, life %d)" % [int(ring.events), int(ring.life_id)])
	recorder.capture_incident(&"manual")
	_check(int(recorder.get_summary().incidents.captures) == 1, "an explicit capture is counted apart from deaths")

	# Immediate shutdown: everything must already be frozen and queued.
	var capture_path: String = recorder.capture_directory
	recorder.end_capture("suspended")
	recorder.flush_reports()
	var death := {}
	var manual := {}
	var respawn_records := 0
	for line in FileAccess.get_file_as_string(capture_path.path_join("events.jsonl")).strip_edges().split("\n"):
		var record: Variant = JSON.parse_string(line)
		if not (record is Dictionary):
			continue
		match String(record.get("kind", "")):
			"death_context":
				death = record.data
			"incident_context":
				manual = record.data
			"health_change":
				if String(record.data.get("category", "")) == "respawn":
					respawn_records += 1
	_check(not death.is_empty() and String(death.reason) == "death" and int(death.life_id) == 1, "the death context survives immediate reconstruction and capture shutdown")
	if not death.is_empty():
		var terminal: Dictionary = death.get("terminal", {}) if death.get("terminal") is Dictionary else {}
		var hit: Dictionary = terminal.get("event", {})
		var resolution: Dictionary = terminal.get("resolution", {}) if terminal.get("resolution") is Dictionary else {}
		_check(String(hit.get("source", "")) == "recorder_normal" and float(hit.get("hp_before", -1.0)) == 82.0 and float(hit.get("hp_after", -1.0)) == 0.0 and float(hit.get("requested", 0.0)) == 1000.0 and String(hit.get("category", "")) == "hit", "the exact terminal hit is recorded with its source, pre-hit HP and requested amount (source %s, hp %.1f→%.1f)" % [String(hit.get("source", "")), float(hit.get("hp_before", -1.0)), float(hit.get("hp_after", -1.0))])
		_check(String(resolution.get("outcome", "")) == "hit" and float(resolution.get("raw", 0.0)) == 1000.0 and float(resolution.get("adjusted", 0.0)) == 1000.0 and float(resolution.get("applied", 0.0)) == 82.0, "the terminal resolution carries raw, adjusted and applied amounts and the outcome")
		var kinds: Array = []
		for record in death.history.events:
			var label := String(record.kind)
			if label == "health":
				label += ":" + String(record.category)
			kinds.append(label)
		var expected := ["health:hit", "damage", "health:heal", "health:cost", "healing_lock", "heal_refused", "health:hit", "damage", "life"]
		_check(kinds.slice(kinds.size() - expected.size()) == expected, "prior costs, heals, the refused heal and the terminal hit are in chronological order (%s)" % [", ".join(PackedStringArray(kinds))])
		var cost := {}
		for record in death.history.events:
			if String(record.kind) == "health" and String(record.category) == "cost":
				cost = record
		_check(String(cost.get("source", "")) == "ascension:fixture" and float(cost.get("delta", 0.0)) == -3.0 and int(cost.get("life", 0)) == 1, "the earlier cost keeps its source, amount and life id")
		_check(death.history.samples.size() == 5 and bool(death.history.complete) and int(death.history.trimmed_events) == 0 and float(death.history.retained_seconds) > 0.0, "the five samples before death are retained, complete and untrimmed (%d samples)" % death.history.samples.size())
		_check(int(death.build_index) == 1 and death.has("effects") and death.effects.has("ManifestationRunner") and death.health.has("residual") and death.has("segment_phase") and float(death.reconstruction_age) > 0.0, "the context carries the build reference, the pure effect snapshot, the health residual, the phase and the reconstruction age")
		_check(float(death.state.hp) == 0.0 and int(death.state.life) == 1 and death.has("serialized_bytes") and int(death.serialized_bytes) > 0, "the state at death is the dead player's, not a one-second-old sample")
		var has_respawn := false
		for record in death.history.events:
			if String(record.kind) == "health" and String(record.category) == "respawn":
				has_respawn = true
		_check(not has_respawn and respawn_records == 1, "the frozen context ends at the death; the reconstruction is recorded in the new life")
	_check(not manual.is_empty() and String(manual.reason) == "manual" and int(manual.life_id) == 2 and manual.get("terminal") == null and float(manual.state.hp) == float(manual.state.max_hp), "a manual capture records the live life without a terminal event")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(capture_path.path_join("summary.json")))
	_check(saved is Dictionary and int(saved.incidents.deaths) == 1 and int(saved.incidents.captures) == 1 and int(saved.history.event_cap) == 2048 and bool(saved.metadata.features.incidents), "the saved summary reports incidents and the ring limits")
	var report := FileAccess.get_file_as_string(capture_path.path_join("report.md"))
	_check(report.contains("## Incidents") and report.contains("Death contexts: **1**"), "the report explains the incidents")
	EnemyWorld.remove_enemy(handle, &"test")
	attacker.free()
	player.free()
	for name in ["events.jsonl", "summary.json", "report.md", "segments.csv"]:
		DirAccess.remove_absolute(capture_path.path_join(name))
	DirAccess.remove_absolute(capture_path)


func _finish() -> void:
	print("BalanceIncidentHistoryTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)
