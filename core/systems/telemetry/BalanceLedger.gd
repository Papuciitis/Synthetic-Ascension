extends RefCounted

## Exact totals, bounded pending history. This class never reads the scene tree
## or writes files; all clocks and outcomes come from the runtime adapter.
const ADJUSTMENTS := ["system_sync", "trade_undo", "ascension_refund"]
## Developer funding (route loaders, overlay grants) is real wallet movement
## but not play income; it gets its own bucket so earned income stays honest.
const DEBUG_REASONS := ["dev_grant", "developer_grant"]
## Player damage outcomes that removed health: an ordinary hit, and a lethal
## hit a rule intercepted (the player is left at 1 HP, so the HP actually
## removed is real). Avoided outcomes only count.
const DAMAGING_OUTCOMES := ["hit", "intercepted"]
const AVOIDED_OUTCOMES := ["evaded", "invulnerable", "god_mode", "missed"]
const METRICS := [
	"seconds_gameplay", "seconds_paused", "seconds_hub", "seconds_loading",
	"enemy_hp_removed", "enemy_damage_after_defenses", "enemy_overkill",
	"player_credited_damage", "player_damage_before_defenses",
	"player_damage_after_defenses", "player_hp_lost", "player_overkill",
	"healing", "heal_overflow", "heal_blocked", "hp_paid",
	"attacks", "resolved_hits", "critical_hits", "kills", "deaths", "respawns", "rescues",
	"evaded_hits", "invulnerable_hits", "god_mode_hits", "missed_hits", "intercepted_hits",
]

## Health reconciliation: one life at a time, closed on reconstruction.
const HEALTH_SOURCE_CAP := 512
const HEALTH_LIVES_KEPT := 32
## Frequent categories are aggregated per window; the rest are discrete records.
const DISCRETE_HEALTH_CATEGORIES := ["cost", "adjustment", "rescue", "respawn"]
const SCHEMA_VERSION := 2
## Damage attribution: aggregate keys per table, overflow to "other"; cast
## ids are remembered in a bounded window only.
const ATTRIBUTION_KEY_CAP := 512
const RECENT_CASTS_KEPT := 256
## Exit and pressure diagnostics: a death this soon after reconstruction is
## counted as a reconstruction death; spawn and contributor keys are capped.
const RECONSTRUCTION_DEATH_WINDOW := 10.0
const SPAWN_KEY_CAP := 128
const OVERTIME_CONTRIBUTOR_CAP := 64

var max_pending_records := 8192
var _health: Dictionary = {}
var _health_totals: Dictionary = {}
var _lives: Array[Dictionary] = []
var _lives_completed := 0
var _recent_casts: Array[String] = []
var _recent_cast_set: Dictionary = {}
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
var _channel_entered_at := -1.0
var _last_respawn_at := -1.0
var _reentry_pending := false

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
	_health = {}
	_health_totals = _empty_health_totals()
	_lives.clear()
	_lives_completed = 0
	_recent_casts.clear()
	_recent_cast_set.clear()
	_open_segment(segment, balance)
	event("capture_started", _metadata)

func _empty_stats(balance: int) -> Dictionary:
	var stats := {
		"followers_open": balance, "followers_close": balance,
		"followers_earned": 0, "followers_spent": 0, "followers_adjustments": 0, "followers_debug": 0,
		"followers_by_reason": {}, "enemies": {}, "player_damage_by_source": {},
		"healing_by_source": {},
		"attribution": {"by_origin": {}, "by_emitter": {}, "overflow": {"by_origin": 0, "by_emitter": 0}, "mixed_raw_breakdown": {}},
		"exit": _empty_exit(),
	}
	for metric in METRICS:
		stats[metric] = 0.0
	return stats

## Per segment (the rite is per segment); the totals row keeps the counters.
static func _empty_exit() -> Dictionary:
	return {"status": "not_unlocked", "unlocked_at": null, "first_channel_at": null, "unlock_to_first_channel": null,
		"completed_at": null, "attempts": 0, "rejections": 0, "lapses": 0, "channel_seconds": 0.0,
		"progress_lost": {"lapse": 0.0, "death": 0.0, "other": 0.0}, "seals": 0, "waves": 0, "wave_enemies": 0,
		"last_chance": 0, "safeguards_granted": 0, "safeguards_used": 0, "safeguards_drained": 0,
		"deaths_while_channeling": 0, "deaths_after_reconstruction": 0, "reconstruction_spent": 0, "reentry_seconds": [],
		"reinforcements": {"beats_started": 0, "beats_ended": 0, "beats_aborted": 0, "members": 0, "specialist_responses": 0, "escalations": 0},
		"spawns": {}, "spawn_overflow": 0,
		"overtime": {"injections": {}, "injection_count": 0, "injected_seconds": 0.0, "injection_overflow": 0,
			"max_overtime": 0.0, "final_overtime": 0.0, "final_unseal_seconds": 0.0, "director_injected_seconds": 0.0}}

func _open_segment(segment: int, balance: int) -> void:
	_current = _empty_stats(balance)
	_current["segment"] = segment
	_current["status"] = "in_progress"
	_segments.append(_current)

func change_segment(segment: int, previous_status: String) -> void:
	flush_window()
	for handle in _enemies.keys():
		enemy_removed(handle, "segment_boundary")
	_current["status"] = previous_status
	event("segment_ended", {"status": previous_status})
	_enemies.clear()
	_open_segment(segment, int(_totals.followers_close))
	event("segment_started", {})

func finish(outcome: String) -> void:
	flush_window()
	_outcome = outcome
	_current["status"] = outcome
	if not _health.is_empty():
		_health["closed_reason"] = outcome
	event("capture_ended", {"outcome": outcome})


# ---------------------------------------------------------------- health reconciliation

func _empty_health_totals() -> Dictionary:
	return {"changes": 0, "checks": 0, "unexplained_checks": 0, "unexplained_hp_delta": 0.0, "max_abs_residual": 0.0, "by_category": {}}


func _empty_life(life_id: int, hp: float, max_hp: float, reason: String) -> Dictionary:
	return {"life_id": life_id, "reason": reason, "started_gameplay": float(_totals.get("seconds_gameplay", 0.0)),
		"hp_start": hp, "max_hp": max_hp, "expected_hp": hp, "changes": 0, "by_category": {}, "by_source": {},
		"by_source_overflow": 0, "checks": 0, "residual": 0.0, "max_abs_residual": 0.0,
		"unexplained_hp_delta": 0.0, "unexplained_checks": 0}


## Starts a life baseline at the observed HP (capture start, reconstruction).
## Initialization is a baseline, never healing.
func begin_life(hp: float, max_hp: float, reason: String) -> void:
	var next_id := int(_health.get("life_id", _lives_completed)) + 1
	_close_life(reason)
	_health = _empty_life(next_id, hp, max_hp, reason)
	event("life_started", {"life_id": next_id, "hp": hp, "max_hp": max_hp, "reason": reason})


func end_life(reason: String) -> void:
	if _health.is_empty():
		return
	_health["ended_reason"] = reason
	_health["ended_gameplay"] = float(_totals.get("seconds_gameplay", 0.0))


func current_life_id() -> int:
	return int(_health.get("life_id", 0))


## The live life's reconciliation state, for incident context.
func life_info() -> Dictionary:
	if _health.is_empty():
		return {"life_id": 0, "started_gameplay": 0.0, "expected_hp": 0.0, "residual": 0.0, "unexplained_checks": 0, "changes": 0}
	return {"life_id": int(_health["life_id"]), "started_gameplay": float(_health["started_gameplay"]),
		"expected_hp": float(_health["expected_hp"]), "residual": float(_health["residual"]),
		"unexplained_checks": int(_health["unexplained_checks"]), "changes": int(_health["changes"])}


## The gameplay clock: advances only while live gameplay runs, never during a
## pause, the hub or a load. Incident history ages by it.
func gameplay_seconds() -> float:
	return float(_totals.get("seconds_gameplay", 0.0))


func _close_life(reason: String) -> void:
	if _health.is_empty():
		return
	var done := _health.duplicate(true)
	done["closed_reason"] = reason
	done["ended_gameplay"] = float(_totals.get("seconds_gameplay", 0.0))
	done["hp_end"] = float(_health.get("expected_hp", 0.0))
	_lives_completed += 1
	if _lives.size() >= HEALTH_LIVES_KEPT:
		_lives.pop_front()
	_lives.append(done)
	_health = {}


## The canonical health-change record: hp_after - hp_before is authoritative.
## Updates reconciliation only; the hit/heal metrics keep coming from the
## resolved-damage/heal signals. Intentional costs are the one source of the
## hp_paid metric, so a cost is counted once.
func record_health_change(change: Dictionary) -> void:
	var category := String(change.get("category", "unknown"))
	var hp_before := float(change.get("hp_before", 0.0))
	var hp_after := float(change.get("hp_after", 0.0))
	var max_after := float(change.get("max_hp_after", 0.0))
	var delta := hp_after - hp_before
	if category == "respawn":
		begin_life(hp_after, max_after, "respawn")
		change["life_id"] = current_life_id()
		event("health_change", change)
		return
	if _health.is_empty():
		begin_life(hp_before, float(change.get("max_hp_before", max_after)), "first_change")
	change["life_id"] = current_life_id()
	_health["expected_hp"] = float(_health["expected_hp"]) + delta
	_health["max_hp"] = max_after
	_health["changes"] = int(_health["changes"]) + 1
	_health_totals["changes"] = int(_health_totals["changes"]) + 1
	for table in [_health["by_category"], _health_totals["by_category"]]:
		var cats: Dictionary = table
		if not cats.has(category):
			cats[category] = {"count": 0, "delta": 0.0}
		cats[category]["count"] = int(cats[category]["count"]) + 1
		cats[category]["delta"] = float(cats[category]["delta"]) + delta
	var source := String(change.get("source_id", "unknown"))
	var sources: Dictionary = _health["by_source"]
	if sources.has(source) or sources.size() < HEALTH_SOURCE_CAP:
		sources[source] = float(sources.get(source, 0.0)) + delta
	else:
		_health["by_source_overflow"] = int(_health["by_source_overflow"]) + 1
		sources["other"] = float(sources.get("other", 0.0)) + delta
	if category == "cost":
		add_metric("hp_paid", maxf(0.0, -delta))
	if category in DISCRETE_HEALTH_CATEGORIES:
		event("health_change", change)
	else:
		# Hits and heals arrive per frame under regen and per contact tick:
		# aggregated per window by category and source, exact in total.
		if not _window.has("health_changes"):
			_window["health_changes"] = {}
		var rows: Dictionary = _window["health_changes"]
		var key := category + ":" + source
		if not rows.has(key):
			rows[key] = {"count": 0, "delta": 0.0}
		rows[key]["count"] = int(rows[key]["count"]) + 1
		rows[key]["delta"] = float(rows[key]["delta"]) + delta


## A sampled HP against the reconciled expectation. A gap is reported as
## unexplained (and the expectation resynced so the next gap is measured on
## its own); nothing is ever invented to balance it.
func observe_hp(hp: float, max_hp: float) -> void:
	if _health.is_empty():
		begin_life(hp, max_hp, "observed")
		return
	var tolerance := maxf(0.001, 0.00001 * maxf(max_hp, float(_health.get("max_hp", 0.0))))
	var expected := float(_health["expected_hp"])
	var residual := hp - expected
	_health["checks"] = int(_health["checks"]) + 1
	_health_totals["checks"] = int(_health_totals["checks"]) + 1
	_health["residual"] = residual
	_health["max_abs_residual"] = maxf(float(_health["max_abs_residual"]), absf(residual))
	_health_totals["max_abs_residual"] = maxf(float(_health_totals["max_abs_residual"]), absf(residual))
	if absf(residual) > tolerance:
		_health["unexplained_checks"] = int(_health["unexplained_checks"]) + 1
		_health["unexplained_hp_delta"] = float(_health["unexplained_hp_delta"]) + residual
		_health_totals["unexplained_checks"] = int(_health_totals["unexplained_checks"]) + 1
		_health_totals["unexplained_hp_delta"] = float(_health_totals["unexplained_hp_delta"]) + residual
		_health["expected_hp"] = hp
		event("health_unexplained", {"life_id": current_life_id(), "expected": expected, "observed": hp, "residual": residual})


func health_summary() -> Dictionary:
	return {"current_life": _health.duplicate(true), "totals": _health_totals.duplicate(true),
		"lives": _lives.duplicate(true), "lives_completed": _lives_completed}

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
	var gained := maxi(0, change)
	var spent := maxi(0, -change)
	if reason == "reconstruction":
		for row in _exit_rows():
			row["reconstruction_spent"] = int(row["reconstruction_spent"]) + spent
	if reason == "trade":
		var buy_value := int(context.get("buy_value", 0))
		var sell_value := int(context.get("sell_value", 0))
		if buy_value >= 0 and sell_value >= 0 and sell_value - buy_value == change:
			gained = sell_value
			spent = buy_value
	for stats in [_totals, _current]:
		stats.followers_close = after
		if reason in ADJUSTMENTS:
			stats.followers_adjustments += change
		elif reason in DEBUG_REASONS:
			stats.followers_debug += change
		else:
			stats.followers_earned += gained
			stats.followers_spent += spent
		var reasons: Dictionary = stats.followers_by_reason
		if not reasons.has(reason):
			reasons[reason] = {"count": 0, "gained": 0, "spent": 0, "net": 0}
		var entry: Dictionary = reasons[reason]
		entry.count += 1
		entry.gained += gained
		entry.spent += spent
		entry.net += change
	event("transaction", {"before": before, "change": change, "after": after, "reason": reason, "context": context})

func enemy_seen(handle: int, spec_id: String, elite: bool, max_hp: float, observed_at_entry: bool = false) -> void:
	var key := spec_id + (" [elite]" if elite else "")
	var enemy: Dictionary = _enemies.get(handle, {})
	if not enemy.is_empty():
		if bool(enemy.defeated) or (enemy.key == key and is_equal_approx(enemy.hp, max_hp)):
			return
		for stats in [_totals, _current]:
			_profile_contribution(stats, enemy, -1)
		enemy.key = key
		enemy.hp = max_hp
	else:
		enemy = {"key": key, "hp": max_hp, "at_entry": observed_at_entry, "first_hit": -1.0, "defeated": false, "damage": 0.0}
	_enemies[handle] = enemy
	for stats in [_totals, _current]:
		_profile_contribution(stats, enemy, 1)

func _profile_contribution(stats: Dictionary, enemy: Dictionary, direction: int) -> void:
	var rows: Dictionary = stats.enemies
	if not rows.has(enemy.key):
		rows[enemy.key] = {"seen": 0, "present_at_entry": 0, "hp_sum": 0.0, "hp_min": INF, "hp_max": 0.0,
			"damage": 0.0, "engaged": 0, "kills": 0, "removed_alive": 0, "ttk_count": 0, "ttk_seconds": 0.0, "ttk_max": 0.0,
			"_live_hp": {}, "_retired_min": INF, "_retired_max": 0.0}
	var row: Dictionary = rows[enemy.key]
	row.seen += direction
	row.present_at_entry += int(enemy.at_entry) * direction
	row.hp_sum += float(enemy.hp) * direction
	row.damage += float(enemy.damage) * direction
	row.engaged += int(float(enemy.first_hit) >= 0.0) * direction
	_change_live_hp(row, float(enemy.hp), direction)
	if row.seen == 0:
		rows.erase(enemy.key)

func _change_live_hp(row: Dictionary, hp: float, direction: int) -> void:
	var key := str(hp)
	var histogram: Dictionary = row._live_hp
	var count := int(histogram.get(key, 0)) + direction
	if count <= 0:
		histogram.erase(key)
	else:
		histogram[key] = count
	if direction > 0:
		row.hp_min = minf(row.hp_min, hp)
		row.hp_max = maxf(row.hp_max, hp)
		return
	row.hp_min = row._retired_min
	row.hp_max = row._retired_max
	for value in histogram:
		row.hp_min = minf(row.hp_min, float(value))
		row.hp_max = maxf(row.hp_max, float(value))

func enemy_damage(handle: int, applied: float, after_defenses: float, hit_count: int, crit_count: int, credited_to_player: bool, provenance: Dictionary = {}, lethal: bool = false) -> void:
	if applied <= 0.0:
		return
	add_metric("enemy_hp_removed", applied)
	add_metric("enemy_damage_after_defenses", after_defenses)
	add_metric("enemy_overkill", maxf(0.0, after_defenses - applied))
	add_metric("resolved_hits", hit_count)
	add_metric("critical_hits", crit_count)
	if credited_to_player:
		add_metric("player_credited_damage", applied)
	if not provenance.is_empty():
		_attribute(provenance, applied, maxf(0.0, after_defenses - applied), hit_count)
	if not _enemies.has(handle):
		return
	var enemy: Dictionary = _enemies[handle]
	if not provenance.is_empty():
		enemy["last_provenance"] = provenance
		if lethal:
			enemy["lethal_provenance"] = provenance
	enemy.damage += applied
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
	# The hit that emptied the bar is credited once; a mixed lethal batch
	# stays mixed, a defeat with no damage record is unknown.
	var lethal_provenance: Dictionary = enemy.get("lethal_provenance", enemy.get("last_provenance", {}))
	_credit_kill(lethal_provenance)
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
	for stats in [_totals, _current]:
		var row: Dictionary = stats.enemies[enemy.key]
		row._retired_min = minf(row._retired_min, float(enemy.hp))
		row._retired_max = maxf(row._retired_max, float(enemy.hp))
		_change_live_hp(row, float(enemy.hp), -1)
	_enemies.erase(handle)

# ---------------------------------------------------------------- damage attribution

func _attribution_row(table: Dictionary, name: String, overflow: Dictionary, key: String) -> Dictionary:
	var use := key
	if not table.has(use) and table.size() >= ATTRIBUTION_KEY_CAP:
		use = "other"
		overflow[name] = int(overflow.get(name, 0)) + 1
	if not table.has(use):
		table[use] = {"hp_removed": 0.0, "overkill": 0.0, "hits": 0, "kills": 0, "casts": 0}
	return table[use]


## Origin and immediate-source tables are alternate groupings of the same HP.
func _attribute(provenance: Dictionary, applied: float, overkill: float, hits: int) -> void:
	var origin := String(provenance.get("origin_id", "unknown"))
	var emitter := String(provenance.get("emitter_id", "unknown"))
	for stats in [_totals, _current]:
		var tables: Dictionary = stats.attribution
		for pair in [["by_origin", origin], ["by_emitter", emitter]]:
			var row := _attribution_row(tables[pair[0]], pair[0], tables.overflow, pair[1])
			row.hp_removed = float(row.hp_removed) + applied
			row.overkill = float(row.overkill) + overkill
			row.hits = int(row.hits) + hits
		if origin == "mixed":
			var breakdown: Dictionary = tables.mixed_raw_breakdown
			var raw: Dictionary = provenance.get("raw_breakdown", {})
			for key in raw:
				if breakdown.has(key) or breakdown.size() < ATTRIBUTION_KEY_CAP:
					breakdown[key] = float(breakdown.get(key, 0.0)) + float(raw[key])
	_note_cast(origin, String(provenance.get("cast_id", "")))


## A cast id seen for the first time counts one activation for its origin;
## pellets and ticks of the same cast do not.
func _note_cast(origin: String, cast_id: String) -> void:
	if cast_id.is_empty():
		return
	var key := origin + "|" + cast_id
	if _recent_cast_set.has(key):
		return
	_recent_cast_set[key] = true
	_recent_casts.append(key)
	if _recent_casts.size() > RECENT_CASTS_KEPT:
		_recent_cast_set.erase(_recent_casts.pop_front())
	for stats in [_totals, _current]:
		var tables: Dictionary = stats.attribution
		var row := _attribution_row(tables.by_origin, "by_origin", tables.overflow, origin)
		row.casts = int(row.casts) + 1


func _credit_kill(provenance: Dictionary) -> void:
	var origin := String(provenance.get("origin_id", "unknown"))
	var emitter := String(provenance.get("emitter_id", "unknown"))
	for stats in [_totals, _current]:
		var tables: Dictionary = stats.attribution
		for pair in [["by_origin", origin], ["by_emitter", emitter]]:
			var row := _attribution_row(tables[pair[0]], pair[0], tables.overflow, pair[1])
			row.kills = int(row.kills) + 1


## How much of the removed HP the origin table explains.
static func attribution_coverage(stats: Dictionary) -> Dictionary:
	var total := float(stats.get("enemy_hp_removed", 0.0))
	var by_origin: Dictionary = (stats.get("attribution", {}) as Dictionary).get("by_origin", {})
	var unknown := float((by_origin.get("unknown", {}) as Dictionary).get("hp_removed", 0.0))
	var mixed := float((by_origin.get("mixed", {}) as Dictionary).get("hp_removed", 0.0))
	var attributed := maxf(0.0, total - unknown - mixed)
	return {"hp_removed": total, "attributed": attributed, "unknown": unknown, "mixed": mixed,
		"attributed_share": (attributed / total) if total > 0.0 else null}


# ---------------------------------------------------------------- exit and pressure

func _exit_rows() -> Array:
	return [_totals.exit, _current.exit]


func _exit_add(key: String, amount: float = 1.0) -> void:
	for row in _exit_rows():
		row[key] = row[key] + amount


## One ExitRite event (RunEvents.exit_rite_event) with its hold/progress.
## An attempt is an actual channel entry; proximity is not one.
func exit_event(kind: String, data: Dictionary) -> void:
	var now := gameplay_seconds()
	var seg: Dictionary = _current.exit
	match kind:
		"unlocked":
			if seg.unlocked_at == null:
				seg["unlocked_at"] = now
			seg["status"] = "unlocked"
		"channel_entered":
			_exit_add("attempts")
			if seg.first_channel_at == null:
				seg["first_channel_at"] = now
				if seg.unlocked_at != null:
					seg["unlock_to_first_channel"] = now - float(seg.unlocked_at)
			seg["status"] = "channeling"
			_channel_entered_at = now
			if _reentry_pending and _last_respawn_at >= 0.0:
				(seg.reentry_seconds as Array).append(now - _last_respawn_at)
				_reentry_pending = false
		"channel_left":
			if String(seg.status) != "completed":
				seg["status"] = "unfinished"
			_close_channel(now)
		"rejected":
			_exit_add("rejections")
		"lapse_drain_started":
			_exit_add("lapses")
		"lapse_drain_ended":
			_lose_progress("lapse", float(data.get("lost", 0.0)))
		"progress_lost":
			var reason := String(data.get("reason", "other"))
			_lose_progress(reason if reason in ["lapse", "death"] else "other", float(data.get("lost", 0.0)))
		"seal":
			_exit_add("seals")
		"wave":
			_exit_add("waves")
			_exit_add("wave_enemies", float(data.get("count", 0)))
		"last_chance":
			_exit_add("last_chance")
		"safeguard_granted":
			_exit_add("safeguards_granted", float(data.get("granted", 0)))
		"safeguard_used":
			_exit_add("safeguards_used")
		"safeguards_drained":
			_exit_add("safeguards_drained", float(data.get("count", 0)))
		"completed":
			seg["status"] = "completed"
			seg["completed_at"] = now
			_close_channel(now)
	var record := data.duplicate()
	record["kind"] = kind
	event("exit", record)


func _close_channel(now: float) -> void:
	if _channel_entered_at >= 0.0:
		_exit_add("channel_seconds", now - _channel_entered_at)
		_channel_entered_at = -1.0


func _lose_progress(reason: String, lost: float) -> void:
	for row in _exit_rows():
		var table: Dictionary = row.progress_lost
		table[reason] = float(table.get(reason, 0.0)) + lost


## A death while the rite was being channelled, and one inside the window
## after a reconstruction (the life's start reason says whether it was one).
func note_death(channeling: bool) -> void:
	if channeling:
		_exit_add("deaths_while_channeling")
	if String(_health.get("reason", "")) == "respawn" and gameplay_seconds() - float(_health.get("started_gameplay", 0.0)) <= RECONSTRUCTION_DEATH_WINDOW:
		_exit_add("deaths_after_reconstruction")


func note_respawn() -> void:
	_last_respawn_at = gameplay_seconds()
	_reentry_pending = true


## One resolved spawn request; repeated results aggregate by source:outcome
## per segment and per metrics window.
func spawn_resolved(source: String, outcome: String, count: int) -> void:
	var key := source + ":" + outcome
	for row in _exit_rows():
		var table: Dictionary = row.spawns
		if table.has(key) or table.size() < SPAWN_KEY_CAP:
			if not table.has(key):
				table[key] = {"requests": 0, "enemies": 0}
			table[key]["requests"] = int(table[key]["requests"]) + 1
			table[key]["enemies"] = int(table[key]["enemies"]) + count
		else:
			row["spawn_overflow"] = int(row["spawn_overflow"]) + 1
	if not _window.has("spawns"):
		_window["spawns"] = {}
	var window: Dictionary = _window.spawns
	if not window.has(key):
		window[key] = {"requests": 0, "enemies": 0}
	window[key]["requests"] = int(window[key]["requests"]) + 1
	window[key]["enemies"] = int(window[key]["enemies"]) + count


func encounter_event(kind: String, data: Dictionary) -> void:
	var members := int(data.get("members", 0))
	for row in _exit_rows():
		var table: Dictionary = row.reinforcements
		match kind:
			"beat_started":
				table["beats_started"] = int(table["beats_started"]) + 1
				table["members"] = int(table["members"]) + members
			"beat_ended":
				table["beats_ended"] = int(table["beats_ended"]) + 1
			"beat_aborted":
				table["beats_aborted"] = int(table["beats_aborted"]) + 1
			"specialist_response":
				table["specialist_responses"] = int(table["specialist_responses"]) + 1
			"escalation":
				table["escalations"] = int(table["escalations"]) + 1
	var record := data.duplicate()
	record["kind"] = kind
	event("encounter", record)


## Extra unseal seconds accepted by the director from one contributor. The
## clock and overtime after it come from the director; nothing is added twice.
func overtime_injection(contributor: String, seconds: float, unseal_seconds: float, overtime: float) -> void:
	var name := contributor if not contributor.is_empty() else "unknown"
	for row in _exit_rows():
		var table: Dictionary = row.overtime
		var injections: Dictionary = table.injections
		if injections.has(name) or injections.size() < OVERTIME_CONTRIBUTOR_CAP:
			injections[name] = float(injections.get(name, 0.0)) + seconds
		else:
			table["injection_overflow"] = int(table["injection_overflow"]) + 1
		table["injection_count"] = int(table["injection_count"]) + 1
		table["injected_seconds"] = float(table["injected_seconds"]) + seconds
		table["final_unseal_seconds"] = unseal_seconds
		table["final_overtime"] = overtime
		table["max_overtime"] = maxf(float(table["max_overtime"]), overtime)
	event("overtime_injection", {"contributor": name, "seconds": seconds, "unseal_seconds": unseal_seconds, "overtime": overtime})


## The director's pure snapshot at a sample: final values and its own
## injection accounting, kept beside the ledger's sum for cross-checking.
func observe_pressure(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	var overtime := float(snapshot.get("overtime", 0.0))
	for row in _exit_rows():
		var table: Dictionary = row.overtime
		table["final_overtime"] = overtime
		table["max_overtime"] = maxf(float(table["max_overtime"]), overtime)
		table["final_unseal_seconds"] = float(snapshot.get("unseal_seconds", table["final_unseal_seconds"]))
		table["director_injected_seconds"] = float(snapshot.get("injected_seconds", table["director_injected_seconds"]))


func player_damage(raw: float, after_defenses: float, applied: float, source: String, outcome: String) -> void:
	if outcome not in DAMAGING_OUTCOMES:
		if outcome in AVOIDED_OUTCOMES:
			add_metric(outcome + "_hits")
		return
	if outcome == "intercepted":
		add_metric("intercepted_hits")
	add_metric("player_damage_before_defenses", raw)
	add_metric("player_damage_after_defenses", after_defenses)
	add_metric("player_hp_lost", applied)
	add_metric("player_overkill", maxf(0.0, after_defenses - applied))
	for stats in [_totals, _current]:
		var sources: Dictionary = stats.player_damage_by_source
		sources[source] = float(sources.get(source, 0.0)) + applied
	if not _window.has("player_damage_by_source"):
		_window["player_damage_by_source"] = {}
	var window_sources: Dictionary = _window.player_damage_by_source
	window_sources[source] = float(window_sources.get(source, 0.0)) + applied

func player_heal(requested: float, modified: float, applied: float, source: String, blocked: bool) -> void:
	add_metric("healing", applied)
	add_metric("heal_overflow", maxf(0.0, modified - applied) if not blocked else 0.0)
	add_metric("heal_blocked", requested if blocked else 0.0)
	for stats in [_totals, _current]:
		var sources: Dictionary = stats.healing_by_source
		sources[source] = float(sources.get(source, 0.0)) + applied

## `owned`: the caller hands over an immutable dictionary it will not touch
## again (an incident snapshot), so it is stored without another deep copy.
## `critical`: a bounded, rare record (a death context) that the pending cap
## may not drop; the cap protects against per-frame floods, not these.
func event(kind: String, data: Dictionary, owned: bool = false, critical: bool = false) -> void:
	_sequence += 1
	if _records.size() >= max_pending_records and not critical:
		_dropped += 1
		return
	_records.append({"seq": _sequence, "elapsed_seconds": _elapsed, "gameplay_seconds": _totals.get("seconds_gameplay", 0.0),
		"segment": _current.get("segment", 0), "kind": kind, "data": data if owned else data.duplicate(true)})

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
	var result := {"schema_version": SCHEMA_VERSION, "metadata": _metadata.duplicate(true), "outcome": _outcome,
		"elapsed_seconds": _elapsed, "totals": _totals.duplicate(true), "segments": _segments.duplicate(true),
		"dropped_records": _dropped, "wallet_discontinuities": _discontinuities, "last_sequence": _sequence,
		"health": health_summary(), "attribution_coverage": attribution_coverage(_totals)}
	var stats_rows: Array = [result.totals]
	stats_rows.append_array(result.segments)
	for stats in stats_rows:
		for enemy_row in stats.enemies.values():
			for key in ["_live_hp", "_retired_min", "_retired_max"]:
				enemy_row.erase(key)
	return result
