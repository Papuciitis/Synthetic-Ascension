extends Node

# Playable presets (data/ascension/presets_v4.json): every preset purchases
# in order through the real rules, equips what it names, loads its engines,
# and survives a scripted crowd fight. Then the whole-system checks: despawn
# mid-effect, handle reuse, reentrant kills, pause/resume, refunds,
# save/load, scene transitions and the Revelations toggle. Frame numbers
# printed here are HEADLESS (no rendering) and are labelled as such.
#
# Run: <godot> --headless --path . res://tools/tests/AscensionPresetTest.tscn

const PLAYER_SCENE = preload("res://core/actors/player/player.tscn")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const PRESETS := "res://data/ascension/presets_v4.json"
const FIGHT_FRAMES := 240
const CROWD := 60

var _passes := 0
var _failures := 0
var _player: Node2D
var _runner: AscensionRunner
var _spawned: Array[int] = []
var _origin: Vector2
var _fighting := false
var _frame_ms: Array[float] = []
var _wall_ms: Array[float] = []
var _last_wall_usec := 0
var _rng := RandomNumberGenerator.new()
var _report: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 20260916
	call_deferred(&"_run")


func _process(delta: float) -> void:
	if not _fighting:
		return
	var now := Time.get_ticks_usec()
	_frame_ms.append(delta * 1000.0)
	if _last_wall_usec > 0:
		_wall_ms.append(float(now - _last_wall_usec) / 1000.0)
	_last_wall_usec = now


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _pct(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values := values.duplicate()
	sorted_values.sort()
	return sorted_values[clampi(int(ceil(fraction * sorted_values.size())) - 1, 0, sorted_values.size() - 1)]


func _spawn(hp: float, at: Vector2, flags: int = 0) -> int:
	var handle := EnemyWorld.create_enemy(SpawnState.new(&"asc_preset", "res://asc_preset.tscn", at, hp, 10.0, 8.0, 0, flags))
	_spawned.append(handle)
	return handle


func _clear_enemies() -> void:
	for handle in _spawned:
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"test")
	_spawned.clear()
	ProjectileManager.clear_for_run_end()
	_runner.flush_attacks()


func _alive() -> Array[int]:
	var out: Array[int] = []
	for handle in _spawned:
		if _runner.enemy_alive(handle):
			out.append(handle)
	return out


func _load_presets() -> Array:
	var file := FileAccess.open(PRESETS, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return (parsed as Dictionary).get("presets", []) if parsed is Dictionary else []


## Replays a preset through the real purchase rules on a fresh ledger.
func _replay(db: AscensionTreeDB, preset: Dictionary) -> Dictionary:
	var native := String(preset.get("native_core", "melee"))
	var ledger := AscensionLedger.new(db, AscensionLedger.fresh_state(native))
	ledger.note_segment_completed(9)
	var spent := 0
	var failed := ""
	var nodes: Array = preset.get("nodes", [])
	for index in range(nodes.size()):
		var id := String(nodes[index])
		if id.begins_with("core."):
			continue
		var chosen := ""
		if db.kind(id) == "gate" and index + 1 < nodes.size() and String(nodes[index + 1]).begins_with("core."):
			chosen = String(nodes[index + 1]).trim_prefix("core.")
		if db.kind(id) == "evolution":
			ledger.grant_evolution_claim()
		var verdict := ledger.can_buy(id, 100000000, chosen)
		if not verdict["ok"]:
			failed = "%s: %s" % [id, verdict["reason"]]
			break
		spent += ledger.record_purchase(id, int(verdict["cost"]), chosen)
	return {"spent": spent, "failed": failed, "ledger": ledger}


func _equip(ledger: AscensionLedger, preset: Dictionary) -> String:
	var equip: Dictionary = preset.get("equip", {})
	for slot in ["q", "v", "v2", "reaction"]:
		var id := String(equip.get(slot, ""))
		if not id.is_empty() and not ledger.equip(slot, id):
			return "%s -> %s" % [slot, id]
	for slot in ["keystones", "axioms"]:
		for id in equip.get(slot, []):
			if not ledger.equip(slot, String(id)):
				return "%s -> %s" % [slot, String(id)]
	return ""


## Installs a preset on the live runner (real purchases, real prices).
func _install(preset: Dictionary) -> Dictionary:
	_clear_enemies()
	var native := String(preset.get("native_core", "melee"))
	Global.selected_style_id = native
	Global.attempt_ascension = AscensionLedger.fresh_state(native)
	var ledger := Global.ascension_ledger()
	ledger.note_segment_completed(9)
	var db := ledger.db
	var nodes: Array = preset.get("nodes", [])
	for index in range(nodes.size()):
		var id := String(nodes[index])
		if id.begins_with("core."):
			continue
		var chosen := ""
		if db.kind(id) == "gate" and index + 1 < nodes.size() and String(nodes[index + 1]).begins_with("core."):
			chosen = String(nodes[index + 1]).trim_prefix("core.")
		if db.kind(id) == "evolution":
			ledger.grant_evolution_claim()
		var verdict := ledger.can_buy(id, 100000000, chosen)
		if not verdict["ok"]:
			return {"failed": "%s: %s" % [id, verdict["reason"]]}
		ledger.record_purchase(id, int(verdict["cost"]), chosen)
	var equip_failed := _equip(ledger, preset)
	_runner.q_cooldown_left = 0.0
	_runner._saved_recovery.clear()
	_runner._v_gap_left = 0.0
	_runner.v_charge = 0.0
	_runner.v2_charge = 0.0
	_runner._q_holding = false
	_player.global_position = _origin
	_player.hp = _player.max_hp
	_player.set("invulnerable_time", 0.0)
	_runner.aim_override = _origin + Vector2(200, 0)
	_runner.refresh()
	_runner.q_cooldown_left = 0.0
	return {"failed": equip_failed, "ledger": ledger}


func _native_tags(core: String) -> PackedStringArray:
	var path: String = {"melee": "slash", "ranged": "bullet", "magic": "impact"}[core]
	var tags := AscensionTags.native(core, path)
	tags = AscensionTags.with_flag(tags, "core_strike")
	if core == "melee":
		tags = AscensionTags.with_flag(tags, "execute_enabled")
	return tags


## A scripted crowd fight: strikes, casts, dashes, kills, respawns.
func _fight(label: String, frames: int = FIGHT_FRAMES, crowd: int = CROWD) -> Dictionary:
	var core := String(_runner.native_core)
	var kills := 0
	var strikes := 0
	var casts := 0
	var generated_before := int(_runner.telemetry.get("generated", 0))
	for i in range(crowd):
		_spawn(40.0 + 20.0 * float(i % 4), _origin + Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(60.0, 320.0), EnemyWorldTypes.Flags.ELITE if i % 15 == 14 else 0)
	_frame_ms.clear()
	_wall_ms.clear()
	_last_wall_usec = 0
	_fighting = true
	for frame in range(frames):
		await get_tree().process_frame
		var alive := _alive()
		if frame % 4 == 0 and not alive.is_empty():
			var target := alive[_rng.randi_range(0, alive.size() - 1)]
			var target_pos := _runner.enemy_position(target)
			_runner.aim_override = target_pos
			RunEvents.weapon_fired.emit(_player, StringName(core), _origin, target_pos, 1.0, 1.0)
			strikes += 1
			if core == "ranged":
				_player.call("_spawn_ranged_bullet", _origin, (target_pos - _origin).normalized(), _runner.native_damage())
			else:
				var tags := _native_tags(core)
				tags.append("cast:native:%d" % strikes)
				var hit_before := _runner.enemy_alive(target)
				_runner.damage_enemy(target, _runner.native_damage() * (1.0 + 0.5 * float(frame % 3)), tags)
				if hit_before and not _runner.enemy_alive(target):
					kills += 1
		if frame % 45 == 20:
			_runner.q_cooldown_left = 0.0
			var verdict := _runner.activate_q()
			if bool(verdict.get("ok", false)):
				casts += 1
		if frame == 60 or frame == 180:
			_runner.v_charge = AscensionRunner.V_CHARGE_MAX
			_runner._v_gap_left = 0.0
			var verdict_v := _runner.activate_v()
			if bool(verdict_v.get("ok", false)):
				casts += 1
		if frame % 90 == 40 and not _player.is_dashing():
			_runner.dash_toward(Vector2.from_angle(_rng.randf_range(0.0, TAU)), 160.0)
		if frame % 30 == 15:
			# Refill the crowd so chains always have bodies.
			var deficit := crowd - alive.size()
			for i in range(mini(deficit, 12)):
				_spawn(40.0 + 20.0 * float(i % 4), _origin + Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(80.0, 320.0))
	_fighting = false
	# Let queued attacks and projectiles settle.
	for _i in range(90):
		await get_tree().process_frame
		if _runner.pending_attacks().is_empty() and ProjectileManager.active_count() == 0:
			break
	_runner.flush_attacks()
	var dead := 0
	for handle in _spawned:
		if not EnemyWorld.is_valid_handle(handle) or not _runner.enemy_alive(handle):
			dead += 1
	var row := {
		"preset": label, "frames": frames, "strikes": strikes, "casts": casts, "dead": dead, "spawned": _spawned.size(),
		"generated": int(_runner.telemetry.get("generated", 0)) - generated_before,
		"p50_ms": _pct(_frame_ms, 0.5), "p95_ms": _pct(_frame_ms, 0.95), "p99_ms": _pct(_frame_ms, 0.99), "max_ms": _pct(_frame_ms, 1.0),
		"wall_p95_ms": _pct(_wall_ms, 0.95), "wall_max_ms": _pct(_wall_ms, 1.0),
	}
	_report.append(row)
	print("HEADLESS %-36s frames %d strikes %d casts %d dead %d/%d generated %d | frame p50 %.2f p95 %.2f p99 %.2f max %.2f ms | wall p95 %.2f max %.2f ms" % [label, frames, strikes, casts, dead, _spawned.size(), row["generated"], row["p50_ms"], row["p95_ms"], row["p99_ms"], row["max_ms"], row["wall_p95_ms"], row["wall_max_ms"]])
	return row


func _run() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	await get_tree().process_frame
	await get_tree().process_frame
	_runner = _player.get_node("AscensionRunner") as AscensionRunner
	_origin = _player.global_position
	Global.run_luck = 0.0
	Global.debug_ascension_revelations_enabled = true
	var db := AscensionTreeDB.shared()
	var presets := _load_presets()
	_check(presets.size() >= 31, "presets_v4.json lists the presets (%d)" % presets.size())

	# ---------------- every preset purchases through the real rules and equips
	var seen_disciplines: Dictionary = {}
	for preset_variant in presets:
		var preset := preset_variant as Dictionary
		var name := String(preset["name"])
		var result := _replay(db, preset)
		_check(result["failed"] == "", "preset '%s' purchases in order at real prices (%s; %d Followers)" % [name, result["failed"], int(result["spent"])])
		var equip_failed := _equip(result["ledger"], preset)
		_check(equip_failed == "", "preset '%s' equips its loadout (%s)" % [name, equip_failed])
		if not String(preset.get("discipline", "")).is_empty():
			seen_disciplines[String(preset["discipline"])] = true
		var authored := int(preset.get("authored_cost", -1))
		if authored > 0:
			_check(int(result["spent"]) == authored, "preset '%s' costs the authored %d (%d)" % [name, authored, int(result["spent"])])
	_check(seen_disciplines.size() == 9, "all nine disciplines have presets (%d)" % seen_disciplines.size())

	# ---------------- every preset fights a crowd on the live runner
	for preset_variant in presets:
		var preset := preset_variant as Dictionary
		var name := String(preset["name"])
		var installed := _install(preset)
		if installed["failed"] != "":
			_check(false, "preset '%s' installs on the runner (%s)" % [name, installed["failed"]])
			continue
		var expected_engines := 0
		var codes: Dictionary = {}
		for id in _runner.active_ids:
			var code := db.discipline_of(String(id))
			if code.is_empty() and db.kind(String(id)) == "fusion":
				for pair_code in db.fusion_disciplines(String(id)):
					codes[pair_code] = true
			elif code.is_empty() and db.kind(String(id)) == "union":
				codes["UN"] = true
			elif not code.is_empty():
				codes[code] = true
		expected_engines = codes.size()
		_check(_runner.engines.size() == expected_engines, "preset '%s' builds %d engine(s)" % [name, expected_engines])
		var row := await _fight(name)
		_check(int(row["dead"]) > 0 and int(row["strikes"]) > 0, "preset '%s' fights: %d strikes, %d casts, %d of %d bodies dead" % [name, int(row["strikes"]), int(row["casts"]), int(row["dead"]), int(row["spawned"])])
		_check(_runner.pending_attacks().is_empty(), "preset '%s' drains its attack queue" % name)
		_runner._sweep_statuses()
		var live := _alive().size()
		_check(_runner.statuses.size() <= live, "preset '%s' keeps statuses only for live enemies (%d for %d live)" % [name, _runner.statuses.size(), live])

	# ---------------- whole-system checks on a rich preset
	var rich: Dictionary = {}
	for preset_variant in presets:
		if String((preset_variant as Dictionary)["name"]) == "Execution pure":
			rich = preset_variant
	var installed_rich := _install(rich)
	_check(installed_rich["failed"] == "", "the rich preset installs")
	# despawn mid-effect: cast into a crowd, then remove every enemy at once
	for i in range(30):
		_spawn(30.0, _origin + Vector2.from_angle(float(i) * 0.21) * 90.0)
	_runner.aim_override = _origin + Vector2(90, 0)
	_runner.activate_q()
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	_runner.activate_v()
	_runner.damage_enemy(_spawned[0], 500.0, _native_tags("melee"))
	for handle in _spawned.duplicate():
		if EnemyWorld.is_valid_handle(handle):
			EnemyWorld.remove_enemy(handle, &"despawn")
	for _i in range(30):
		await get_tree().process_frame
	_runner.flush_attacks()
	_check(_runner.pending_attacks().is_empty(), "despawning every enemy mid-cast drains the queue without errors")
	_clear_enemies()
	# handle reuse: spawn, mark, kill, repeat; statuses never accumulate
	for i in range(300):
		var handle := _spawn(20.0, _origin + Vector2(60, 0))
		_runner.damage_enemy(handle, 5.0, _native_tags("melee"))
		_runner.damage_enemy(handle, 500.0, _native_tags("melee"))
		if i % 50 == 49:
			_runner.flush_attacks()
	_runner.flush_attacks()
	_runner._sweep_statuses()
	_check(_runner.statuses.size() <= _alive().size() + 1, "300 spawn/mark/kill cycles leave no status behind (%d)" % _runner.statuses.size())
	_clear_enemies()
	# pause / resume
	for i in range(10):
		_spawn(30.0, _origin + Vector2.from_angle(float(i) * 0.6) * 100.0)
	_runner.damage_enemy(_spawned[0], 500.0, _native_tags("melee"))
	get_tree().paused = true
	for _i in range(5):
		await get_tree().process_frame
	var paused_pending := _runner.pending_attacks().size()
	_check(not _runner._input_allowed(), "while paused the runner takes no input")
	get_tree().paused = false
	for _i in range(20):
		await get_tree().process_frame
	_runner.flush_attacks()
	_check(_runner.pending_attacks().is_empty() and paused_pending >= 0, "resuming finishes what the pause held (%d queued while paused)" % paused_pending)
	_runner.q_cooldown_left = 0.0
	_check(bool(_runner.activate_q().get("ok", false)), "Q works again after resume")
	_clear_enemies()
	# refund with live engine state (the Gavel from the previous section is
	# still winding up: the refund lands while its engine has live state)
	var ledger_live := Global.ascension_ledger()
	Global.set_followers(0)
	Global.ascension_refund_context_hub = true
	var back := Global.ascension_refund("EXQ3")
	Global.ascension_refund_context_hub = false
	_check(back > 0 and not ledger_live.owns("EXQ3") and _runner.engines.size() >= 1, "refunding a mutation mid-run returns Followers (%d) and rebuilds the engines" % back)
	for _i in range(90):
		await get_tree().process_frame
	_runner.flush_attacks()
	_spawn(30.0, _origin + Vector2(60, 0))
	_runner.q_cooldown_left = 0.0
	var after_refund := _runner.activate_q()
	_check(bool(after_refund.get("ok", false)), "the Q still casts after the refund (%s)" % String(after_refund.get("message", "")))
	_clear_enemies()
	# save / load round trip
	var save := SaveData.new()
	var was_active := Global.attempt_active
	Global.attempt_active = true
	Global.write_save(save)
	var owned_before: Dictionary = (Global.attempt_ascension["owned"] as Dictionary).duplicate()
	var equipped_before: String = Global.ascension_ledger().equipped("q")
	Global.attempt_ascension = AscensionLedger.fresh_state("melee")
	_runner.refresh()
	_check(_runner.engines.is_empty(), "a fresh attempt has no engines")
	Global.apply_save(save)
	Global.attempt_active = was_active
	_runner.refresh()
	var owned_after: Dictionary = Global.attempt_ascension["owned"]
	_check(owned_after.size() == owned_before.size() and Global.ascension_ledger().equipped("q") == equipped_before and _runner.engines.size() >= 1, "save/load restores the owned set (%d) and equipment, and the engines rebuild" % owned_after.size())
	# scene transition: the player leaves and re-enters the tree
	var parent := _player.get_parent()
	parent.remove_child(_player)
	_check(_runner.engines.is_empty(), "leaving the tree unwires the runner")
	parent.add_child(_player)
	await get_tree().process_frame
	_check(_runner.engines.size() >= 1, "re-entering rebuilds the engines")
	var re := _spawn(30.0, _origin + Vector2(60, 0))
	_runner.damage_enemy(re, 500.0, _native_tags("melee"))
	_check(not _runner.enemy_alive(re) and int(_runner.telemetry.get("kills", 0)) >= 1, "hits resolve through the re-wired runner")
	_clear_enemies()
	# Revelations off / on
	Global.debug_ascension_revelations_enabled = false
	_runner.v_charge = AscensionRunner.V_CHARGE_MAX
	_runner._v_gap_left = 0.0
	_check(_runner.activate_v().get("message", "") == "REVELATIONS OFF", "Revelations off refuses V")
	Global.debug_ascension_revelations_enabled = true
	_check(bool(_runner.activate_v().get("ok", false)), "Revelations on casts V")

	_clear_enemies()
	Global.attempt_ascension = {}
	_player.queue_free()
	print("AscensionPresetTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
