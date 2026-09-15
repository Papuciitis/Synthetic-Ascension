extends RefCounted

## Exact totals, bounded pending history. This class never reads the scene tree
## or writes files; all clocks and outcomes come from the runtime adapter.
const ADJUSTMENTS := ["system_sync", "trade_undo", "ascension_refund"]
const METRICS := [
	"seconds_gameplay", "seconds_paused", "seconds_hub", "seconds_loading",
	"enemy_hp_removed", "enemy_damage_after_defenses", "enemy_overkill",
	"player_credited_damage", "player_damage_before_defenses",
	"player_damage_after_defenses", "player_hp_lost", "player_overkill",
	"healing", "heal_overflow", "heal_blocked", "hp_paid",
	"attacks", "resolved_hits", "critical_hits", "kills", "deaths", "respawns", "rescues",
	"evaded_hits", "invulnerable_hits", "god_mode_hits",
]

var max_pending_records := 8192
var _metadata: Dictionary = {}
var _totals: Dictionary = {}
var _segments: Array[Dictionary] = []
var _current: Dictionary = {}
var _enemies: Dictionary = {}
var _records: Array[Dictionary] = []
var _window: Dictionary = {}
var _sequence := 0
var _elapsed := 0.0
var _dropped := 0
var _discontinuities := 0
var _outcome := "recording"

func start(metadata: Dictionary, balance: int, segment: int) -> void:
	_metadata = metadata.duplicate(true)
	_totals = _empty_stats(balance)
	_segments.clear()
	_enemies.clear()
	_records.clear()
	_window.clear()
	_sequence = 0
	_elapsed = 0.0
	_dropped = 0
	_discontinuities = 0
	_outcome = "recording"
	_open_segment(segment, balance)
	event("capture_started", _metadata)

func _empty_stats(balance: int) -> Dictionary:
	var stats := {
		"followers_open": balance, "followers_close": balance,
		"followers_earned": 0, "followers_spent": 0, "followers_adjustments": 0,
		"followers_by_reason": {}, "enemies": {}, "player_damage_by_source": {},
		"healing_by_source": {},
	}
	for metric in METRICS:
		stats[metric] = 0.0
	return stats

func _open_segment(segment: int, balance: int) -> void:
	_current = _empty_stats(balance)
	_current["segment"] = segment
	_current["status"] = "in_progress"
	_segments.append(_current)

func change_segment(segment: int, previous_status: String) -> void:
	flush_window()
	_current["status"] = previous_status
	event("segment_ended", {"status": previous_status})
	_enemies.clear()
	_open_segment(segment, int(_totals.followers_close))
	event("segment_started", {})

func finish(outcome: String) -> void:
	flush_window()
	_outcome = outcome
	_current["status"] = outcome
	event("capture_ended", {"outcome": outcome})

func advance(seconds: float, mode: String) -> void:
	if seconds <= 0.0 or not is_finite(seconds):
		return
	_elapsed += seconds
	var key := "seconds_" + mode
	if key in METRICS:
		add_metric(key, seconds)

func add_metric(key: String, amount: float = 1.0) -> void:
	_totals[key] = float(_totals.get(key, 0.0)) + amount
	_current[key] = float(_current.get(key, 0.0)) + amount
	_window[key] = float(_window.get(key, 0.0)) + amount

func transaction(before: int, change: int, after: int, reason: String, context: Dictionary) -> void:
	if before != int(_totals.followers_close) or before + change != after:
		_discontinuities += 1
	for stats in [_totals, _current]:
		stats.followers_close = after
		if reason in ADJUSTMENTS:
			stats.followers_adjustments += change
		elif change > 0:
			stats.followers_earned += change
		else:
			stats.followers_spent -= change
		var reasons: Dictionary = stats.followers_by_reason
		if not reasons.has(reason):
			reasons[reason] = {"count": 0, "gained": 0, "spent": 0, "net": 0}
		var entry: Dictionary = reasons[reason]
		entry.count += 1
		entry.gained += maxi(0, change)
		entry.spent += maxi(0, -change)
		entry.net += change
	event("transaction", {"before": before, "change": change, "after": after, "reason": reason, "context": context})

func enemy_seen(handle: int, spec_id: String, elite: bool, max_hp: float, observed_at_entry: bool = false) -> void:
	if _enemies.has(handle):
		return
	var key := spec_id + (" [elite]" if elite else "")
	_enemies[handle] = {"key": key, "first_hit": -1.0, "defeated": false}
	for stats in [_totals, _current]:
		var rows: Dictionary = stats.enemies
		if not rows.has(key):
			rows[key] = {"seen": 0, "present_at_entry": 0, "hp_sum": 0.0, "hp_min": max_hp, "hp_max": max_hp,
				"damage": 0.0, "engaged": 0, "kills": 0, "removed_alive": 0, "ttk_count": 0, "ttk_seconds": 0.0, "ttk_max": 0.0}
		var row: Dictionary = rows[key]
		row.seen += 1
		row.present_at_entry += int(observed_at_entry)
		row.hp_sum += max_hp
		row.hp_min = minf(row.hp_min, max_hp)
		row.hp_max = maxf(row.hp_max, max_hp)

func enemy_damage(handle: int, applied: float, after_defenses: float, hit_count: int, crit_count: int, credited_to_player: bool) -> void:
	if applied <= 0.0:
		return
	add_metric("enemy_hp_removed", applied)
	add_metric("enemy_damage_after_defenses", after_defenses)
	add_metric("enemy_overkill", maxf(0.0, after_defenses - applied))
	add_metric("resolved_hits", hit_count)
	add_metric("critical_hits", crit_count)
	if credited_to_player:
		add_metric("player_credited_damage", applied)
	if not _enemies.has(handle):
		return
	var enemy: Dictionary = _enemies[handle]
	var first: bool = float(enemy.first_hit) < 0.0
	if first:
		enemy.first_hit = float(_totals.seconds_gameplay)
	for stats in [_totals, _current]:
		var row: Dictionary = stats.enemies[enemy.key]
		row.damage += applied
		row.engaged += int(first)

func enemy_defeated(handle: int) -> void:
	if not _enemies.has(handle) or bool(_enemies[handle].defeated):
		return
	var enemy: Dictionary = _enemies[handle]
	enemy.defeated = true
	add_metric("kills")
	for stats in [_totals, _current]:
		var row: Dictionary = stats.enemies[enemy.key]
		row.kills += 1
		if float(enemy.first_hit) >= 0.0:
			var duration := maxf(0.0, float(_totals.seconds_gameplay) - float(enemy.first_hit))
			row.ttk_count += 1
			row.ttk_seconds += duration
			row.ttk_max = maxf(row.ttk_max, duration)

func enemy_removed(handle: int, _reason: String) -> void:
	if not _enemies.has(handle):
		return
	var enemy: Dictionary = _enemies[handle]
	if not bool(enemy.defeated):
		for stats in [_totals, _current]:
			stats.enemies[enemy.key].removed_alive += 1
	_enemies.erase(handle)

func player_damage(raw: float, after_defenses: float, applied: float, source: String, outcome: String) -> void:
	if outcome != "hit":
		if outcome in ["evaded", "invulnerable", "god_mode"]:
			add_metric(outcome + "_hits")
		return
	add_metric("player_damage_before_defenses", raw)
	add_metric("player_damage_after_defenses", after_defenses)
	add_metric("player_hp_lost", applied)
	add_metric("player_overkill", maxf(0.0, after_defenses - applied))
	for stats in [_totals, _current]:
		var sources: Dictionary = stats.player_damage_by_source
		sources[source] = float(sources.get(source, 0.0)) + applied
	event("player_damage", {"raw": raw, "after_defenses": after_defenses, "hp_lost": applied, "source": source})

func player_heal(requested: float, modified: float, applied: float, source: String, blocked: bool) -> void:
	add_metric("healing", applied)
	add_metric("heal_overflow", maxf(0.0, modified - applied) if not blocked else 0.0)
	add_metric("heal_blocked", requested if blocked else 0.0)
	for stats in [_totals, _current]:
		var sources: Dictionary = stats.healing_by_source
		sources[source] = float(sources.get(source, 0.0)) + applied

func event(kind: String, data: Dictionary) -> void:
	_sequence += 1
	if _records.size() >= max_pending_records:
		_dropped += 1
		return
	_records.append({"seq": _sequence, "elapsed_seconds": _elapsed, "gameplay_seconds": _totals.get("seconds_gameplay", 0.0),
		"segment": _current.get("segment", 0), "kind": kind, "data": data.duplicate(true)})

func flush_window() -> void:
	if not _window.is_empty():
		event("metrics", _window)
		_window = {}

func take_records() -> Array[Dictionary]:
	var records := _records
	_records = []
	return records

func pending_count() -> int:
	return _records.size()

func summary() -> Dictionary:
	return {"schema_version": 1, "metadata": _metadata.duplicate(true), "outcome": _outcome,
		"elapsed_seconds": _elapsed, "totals": _totals.duplicate(true), "segments": _segments.duplicate(true),
		"dropped_records": _dropped, "wallet_discontinuities": _discontinuities, "last_sequence": _sequence}
