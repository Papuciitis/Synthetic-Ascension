extends RefCounted

## Runs only on the report worker. Inputs are immutable, JSON-safe snapshots;
## never access live nodes, resources, or the scene tree here.
static func write_batch(batch: Dictionary, directory: String) -> Dictionary:
	var summary: Dictionary = (batch.get("summary", {}) as Dictionary).duplicate(true)
	var err := DirAccess.make_dir_recursive_absolute(directory)
	if err != OK and err != ERR_ALREADY_EXISTS:
		return _failure("Create capture directory", err)
	var records: Array = batch.get("records", [])
	if not records.is_empty():
		var path := directory.path_join("events.jsonl")
		var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
		if file == null:
			return _failed_batch(directory, summary, "Open event history", FileAccess.get_open_error())
		file.seek_end()
		for record in records:
			file.store_line(JSON.stringify(json_safe(record)))
		file.flush()
		err = file.get_error()
		file.close()
		if err != OK:
			return _failed_batch(directory, summary, "Write event history", err)
	if not summary.is_empty():
		summary["artifacts_complete"] = true
		# JSON is the final commit marker for this group of readable artifacts.
		var files := {"report.md": markdown(summary), "segments.csv": segment_csv(summary),
			"summary.json": JSON.stringify(json_safe(summary), "\t")}
		for name in files:
			err = _replace_file(directory.path_join(name), files[name])
			if err != OK:
				return _failed_batch(directory, summary, "Write " + name, err)
	return {"ok": true, "error": "", "directory": directory}

static func _failed_batch(directory: String, summary: Dictionary, operation: String, err: Error) -> Dictionary:
	var result := _failure(operation, err)
	if not summary.is_empty():
		summary["writer_failures"] = int(summary.get("writer_failures", 0)) + 1
		summary["last_error"] = result.error
		summary["artifacts_complete"] = false
		# If JSON remains writable, persist the failure of this very batch. If
		# even that fails, the caller still exposes the error in status/output.
		_replace_file(directory.path_join("summary.json"), JSON.stringify(json_safe(summary), "\t"))
	return result

static func _replace_file(path: String, content: String) -> Error:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(content)
	file.flush()
	var err := file.get_error()
	file.close()
	if err != OK:
		return err
	err = DirAccess.rename_absolute(temp, path)
	if err != OK:
		DirAccess.remove_absolute(temp)
	return err

static func _failure(operation: String, err: Error) -> Dictionary:
	return {"ok": false, "error": "%s: %s" % [operation, error_string(err)]}

static func json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var result := {}
			for key in value:
				result[str(key)] = json_safe(value[key])
			return result
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var result: Array = []
			for item in value:
				result.append(json_safe(item))
			return result
		TYPE_INT:
			# Godot's JSON parser and many viewers use IEEE-754 doubles. Preserve
			# exact money and seeds beyond their integer range as decimal strings.
			return str(value) if value > 9007199254740991 or value < -9007199254740991 else value
		TYPE_FLOAT:
			return value if is_finite(value) else null
		TYPE_STRING_NAME:
			return str(value)
		TYPE_VECTOR2:
			return [value.x, value.y]
		TYPE_OBJECT:
			return null
		_:
			return value

static func markdown(summary: Dictionary) -> String:
	var t: Dictionary = summary.get("totals", {})
	var meta: Dictionary = summary.get("metadata", {})
	var build: Dictionary = meta.get("build", {})
	var seconds := float(t.get("seconds_gameplay", 0.0))
	var text := "# Balance capture\n\n"
	text += "Capture: `%s`  \nOutcome: **%s**  \nBuild: `%s` / `%s`  \nWorld seed: `%s`\n\n" % [meta.get("capture_id", "unknown"), summary.get("outcome", "recording"), build.get("game_version", "unknown"), build.get("git_commit", "unknown"), build.get("world_seed", "unknown")]
	text += "This is one observed session. Resuming a save starts a separate capture with the same run key; earlier gameplay is not inferred.\n\n"
	text += "## Recording health\n\nDropped history records: **%d**. Wallet discontinuities: **%d**. Writer failures: **%d**.\n\n" % [summary.get("dropped_records", 0), summary.get("wallet_discontinuities", 0), summary.get("writer_failures", 0)]
	text += "## Economy\n\n| Opening | Earned | Spent | Adjustments | Debug grants | Closing |\n|---:|---:|---:|---:|---:|---:|\n"
	text += "| %s | %s | %s | %s | %s | %s |\n\n" % [t.get("followers_open", 0), t.get("followers_earned", 0), t.get("followers_spent", 0), t.get("followers_adjustments", 0), t.get("followers_debug", 0), t.get("followers_close", 0)]
	text += "Opening + earned - spent + adjustments + debug grants = closing. Refunds, trade undo and system synchronization are adjustments; developer funding (route loaders, overlay grants) is a debug grant, never earned income. Sales count as earnings under their own reason. Amounts are actual wallet changes.\n\n"
	text += "| Reason | Gained | Spent | Net | Count |\n|---|---:|---:|---:|---:|\n"
	for reason in t.get("followers_by_reason", {}):
		var row: Dictionary = t.followers_by_reason[reason]
		text += "| %s | %s | %s | %s | %s |\n" % [_cell(reason), row.gained, row.spent, row.net, row.count]
	text += "\n## Combat\n\n| Measurement | Value |\n|---|---:|\n"
	for pair in [["Gameplay seconds", "seconds_gameplay"], ["Paused seconds", "seconds_paused"], ["Hub seconds", "seconds_hub"], ["Loading/other seconds", "seconds_loading"],
		["Enemy HP removed", "enemy_hp_removed"], ["Enemy overkill", "enemy_overkill"], ["Damage directly credited to player", "player_credited_damage"],
		["Player HP lost to hits", "player_hp_lost"], ["Player overkill", "player_overkill"], ["HP intentionally paid", "hp_paid"],
		["Healing applied", "healing"], ["Healing overflow", "heal_overflow"], ["Healing sealed", "heal_blocked"],
		["Weapon attacks", "attacks"], ["Resolved hits/ticks", "resolved_hits"], ["Critical hits", "critical_hits"], ["Kills", "kills"], ["Deaths", "deaths"], ["Reconstructions", "respawns"], ["Rescues", "rescues"],
		["Hits evaded", "evaded_hits"], ["Hits during invulnerability", "invulnerable_hits"], ["Hits missed by a rule", "missed_hits"], ["Lethal hits intercepted (left at 1 HP)", "intercepted_hits"], ["Hits under god mode", "god_mode_hits"]]:
		text += "| %s | %.2f |\n" % [pair[0], float(t.get(pair[1], 0.0))]
	if seconds > 0.0:
		text += "\nEnemy HP removed / gameplay second: **%.2f**. Kills / gameplay minute: **%.2f**.\n" % [float(t.get("enemy_hp_removed", 0.0)) / seconds, float(t.get("kills", 0.0)) * 60.0 / seconds]
	text += "\nGameplay time includes travel while the player is alive; it excludes pauses, hub time, loading and death screens. These rates are not combat-only or training-dummy DPS.\n\n"
	var health: Dictionary = summary.get("health", {})
	if not health.is_empty():
		var ht: Dictionary = health.get("totals", {})
		var live_life: Dictionary = health.get("current_life", {})
		text += "## Health reconciliation\n\nEvery HP change is recorded at its owner (hits, heals, costs, takebacks, adjustments, rescues, reconstruction) and each life's expected HP is compared with the sampled HP once per second. Lives observed: **%d** (completed %d). Recorded changes: **%d**. Checks: **%d**, unexplained: **%d** (net unexplained HP %.2f, largest residual %.3f). An unexplained check means some HP change reached no record; it is reported, never balanced away.\n\n" % [int(health.get("lives_completed", 0)) + (0 if live_life.is_empty() else 1), int(health.get("lives_completed", 0)), int(ht.get("changes", 0)), int(ht.get("checks", 0)), int(ht.get("unexplained_checks", 0)), float(ht.get("unexplained_hp_delta", 0.0)), float(ht.get("max_abs_residual", 0.0))]
		text += "| Category | Changes | Net HP |\n|---|---:|---:|\n"
		for category in ht.get("by_category", {}):
			var row: Dictionary = ht.by_category[category]
			text += "| %s | %s | %.2f |\n" % [_cell(category), row.get("count", 0), float(row.get("delta", 0.0))]
		text += "\nSources per life, including Death Rattle payments, Scar Tissue and Slow Heart takebacks and stat-refresh clamps, are in summary.json under health.\n\n"
	text += "## Enemy scaling\n\n| Archetype | Seen | Mean HP | Max HP | Kills | TTK samples | Mean TTK (s) | Removed alive |\n|---|---:|---:|---:|---:|---:|---:|---:|\n"
	for key in t.get("enemies", {}):
		var row: Dictionary = t.enemies[key]
		var ttk := "—" if row.ttk_count == 0 else "%.3f" % (row.ttk_seconds / row.ttk_count)
		text += "| %s | %d | %.2f | %.2f | %d | %d | %s | %d |\n" % [_cell(key), row.seen, row.hp_sum / maxf(1.0, row.seen), row.hp_max, row.kills, row.ttk_count, ttk, row.removed_alive]
	text += "\nTTK runs from first observed damaging hit to death using gameplay seconds. Only defeated, engaged enemies contribute; surviving enemies are not assigned zero. HP reflects registration/entry and later elite or boss configuration.\n\n"
	var features: Dictionary = meta.get("features", {})
	if not features.is_empty():
		var measured: Array = []
		var missing: Array = []
		for feature in features:
			(measured if bool(features[feature]) else missing).append(String(feature))
		text += "## Recorder coverage\n\nRecorder revision %s, balance revision %s. Measured: %s. Not measured by this revision (absent means unavailable, never zero): %s.\n\n" % [str(meta.get("recorder_revision", "unknown")), str(meta.get("balance_revision", "unknown")), ", ".join(measured) if not measured.is_empty() else "none", ", ".join(missing) if not missing.is_empty() else "none"]
	text += "## Coverage\n\nPlayer damage is grouped by immediate source in summary.json; self-inflicted rule damage uses the source `self_damage`. An intercepted lethal hit counts its actual HP removed under player HP lost and its excess under overkill. Contact pressure is a combined swarm source. Enemy HP loss comes from the authoritative EnemyWorld damage event; legacy actors that bypass it are outside this damage total. Critical counts require a HitLedger. Generic heals retain a generic source. Detailed ability ancestry, avoided-hit raw damage, loot decisions and automated balance judgments are outside this core recorder.\n\nSee events.jsonl for wallet operations, build snapshots, pressure samples and lifecycle events; segments.csv for progression comparisons.\n"
	return text

static func segment_csv(summary: Dictionary) -> String:
	var fields := ["segment", "status", "seconds_gameplay", "seconds_paused", "seconds_hub", "seconds_loading", "followers_open", "followers_earned", "followers_spent", "followers_adjustments", "followers_debug", "followers_close", "enemy_hp_removed", "player_hp_lost", "healing", "hp_paid", "kills", "deaths"]
	var output := ",".join(fields) + "\n"
	for segment in summary.get("segments", []):
		var values: PackedStringArray = []
		for field in fields:
			values.append(str(segment.get(field, 0)))
		output += ",".join(values) + "\n"
	return output

static func _cell(value: Variant) -> String:
	return str(value).replace("|", "\\|").replace("\n", " ").replace("\r", " ")
