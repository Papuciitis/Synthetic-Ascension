extends Node

# Boots the real game at a segment with a V4 preset, keeps a crowd alive,
# strikes and casts on a schedule, and writes a JSON report of the frame
# distribution (process delta and wall spacing), draw calls, node counts and
# the runner's subsystem counters. Runs headless (--headless) or windowed
# (a real display): the report says which.
#
# Run: <godot> [--headless] --path . res://tools/tests/AscensionBuildProbe.tscn
# Env: PROBE_PRESET (route or preset name; default "Execution pure"),
#      PROBE_SEGMENT (default 5), PROBE_SECONDS (default 40), PROBE_POP (default 60),
#      PROBE_KILLS_PER_SEC (default 6), PROBE_CAST (default 1: Q every 3 s, V
#      when charged), PROBE_OUT (json path; default user://build_probe.json),
#      PROBE_SEED (default 20260916)

class Driver:
	extends Node

	var _phase := 0
	var _elapsed := 0.0
	var _wall := 0.0
	var _spawner: Node = null
	var _filter: Node = null
	var _topup_left := 0.0
	var _seconds := 40.0
	var _population := 60
	var _kills_per_sec := 6.0
	var _kill_accum := 0.0
	var _preset := "Execution pure"
	var _cast := true
	var _out := "user://build_probe.json"
	var _seed := 20260916
	var _frame_ms: Array[float] = []
	var _wall_ms: Array[float] = []
	var _draw_calls: Array[float] = []
	var _nodes: Array[float] = []
	var _asc_usec: Array[float] = []
	var _last_wall_usec := 0
	var _q_timer := 0.0
	var _casts := 0
	var _kills := 0
	var _rng := RandomNumberGenerator.new()
	var _events: Array = []

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		var env := func(key: String, fallback: String) -> String:
			var value := OS.get_environment(key).strip_edges()
			return value if not value.is_empty() else fallback
		_preset = env.call("PROBE_PRESET", _preset)
		_seconds = float(env.call("PROBE_SECONDS", str(_seconds)))
		_population = int(env.call("PROBE_POP", str(_population)))
		_kills_per_sec = float(env.call("PROBE_KILLS_PER_SEC", str(_kills_per_sec)))
		_cast = env.call("PROBE_CAST", "1") != "0"
		_out = env.call("PROBE_OUT", _out)
		_seed = int(env.call("PROBE_SEED", str(_seed)))
		_rng.seed = _seed
		Global.start_new_attempt()
		Global.attempt_segment = int(env.call("PROBE_SEGMENT", "5"))
		if Global.attempt_segment > 1:
			Global.attempt_opening_completed = true
			Global.attempt_opening_phase = 10
		Global.debug_dev_segment = false
		Global.debug_dev_mode = true
		Global.debug_player_god_mode = true
		Global.debug_ascension_revelations_enabled = true
		_phase = 1
		Global.goto_game()

	func _dismiss_blocking_ui() -> void:
		var scene := get_tree().current_scene
		var ui := scene.get_node_or_null("UI") if scene != null else null
		if ui != null:
			for child in ui.get_children():
				if child.has_method("open_choose_3"):
					child.queue_free()
		get_tree().paused = false

	func _pct(values: Array[float], fraction: float) -> float:
		if values.is_empty():
			return 0.0
		var sorted_values := values.duplicate()
		sorted_values.sort()
		return sorted_values[clampi(int(ceil(fraction * sorted_values.size())) - 1, 0, sorted_values.size() - 1)]

	func _process(delta: float) -> void:
		if _phase < 1:
			return
		_wall += delta
		if get_tree().paused:
			if _wall >= 2.0:
				_dismiss_blocking_ui()
			return
		_elapsed += delta
		if _phase == 1 and _elapsed >= 3.0:
			_phase = 2
			_spawner = get_tree().get_first_node_in_group(&"enemy_spawner")
			_filter = get_node_or_null("/root/DebugEnemySpawnFilter")
			if _filter != null:
				_filter.set("cap_mode", 1)
				_filter.set("custom_total_cap", _population)
			var tools := get_node_or_null("/root/DevSetCollisionTools")
			if tools != null:
				var loaded: Dictionary = tools.call("apply_ascension_route", _preset, true)
				print("[probe] preset: ", loaded)
				_events.append({"t": _elapsed, "event": "preset", "result": loaded})
			if PerformanceFlightRecorder != null:
				PerformanceFlightRecorder.record_event(&"probe", &"start", {"preset": _preset, "population": _population})
			_elapsed = 0.0
			_last_wall_usec = 0
			return
		if _phase != 2:
			return
		var now := Time.get_ticks_usec()
		_frame_ms.append(delta * 1000.0)
		if _last_wall_usec > 0:
			_wall_ms.append(float(now - _last_wall_usec) / 1000.0)
		_last_wall_usec = now
		_draw_calls.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		_nodes.append(float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		var player := get_tree().get_first_node_in_group(&"player")
		var runner: Node = player.get_node_or_null("AscensionRunner") if player != null else null
		if runner != null:
			var counters: Dictionary = runner.call("get_debug_counters")
			_asc_usec.append(float(int(counters.get("tick_usec", 0)) + int(counters.get("flush_usec", 0)) + int(counters.get("hit_usec", 0))))
		_topup_left -= delta
		if _topup_left <= 0.0 and _spawner != null:
			_topup_left = 0.5
			var alive := int(_spawner.call("_alive_total"))
			var queued := int(_spawner.get("_force_spawn_queue"))
			var deficit: int = _population - alive - queued
			if deficit > 0:
				_spawner.call("debug_force_spawn", deficit)
		_kill_accum += delta * _kills_per_sec
		if _kill_accum >= 1.0 and player != null:
			var handles: Array[int] = []
			EnemyWorld.active_handles(handles)
			var index := 0
			while _kill_accum >= 1.0 and index < handles.size():
				var handle := handles[index]
				index += 1
				if EnemyWorld.is_dying(handle):
					continue
				_kill_accum -= 1.0
				if runner != null:
					var core := String(runner.get("native_core"))
					var tags := AscensionTags.native(core, {"melee": "slash", "ranged": "bullet", "magic": "impact"}[core])
					tags = AscensionTags.with_flag(tags, "core_strike")
					tags = AscensionTags.with_flag(tags, "execute_enabled")
					tags.append("cast:native:%d" % int(_elapsed * 10.0))
					RunEvents.weapon_fired.emit(player, StringName(core), player.global_position, EnemyWorld.get_position(handle), 1.0, 1.0)
					runner.call("damage_enemy", handle, 9999.0, tags)
				else:
					EnemyCombat.apply_damage(handle, 9999.0, 1, player)
				_kills += 1
			if index >= handles.size():
				_kill_accum = 0.0
		if _cast and runner != null:
			_q_timer += delta
			if _q_timer >= 3.0:
				_q_timer = 0.0
				runner.set("q_cooldown_left", 0.0)
				var verdict: Dictionary = runner.call("activate_q")
				if bool(verdict.get("ok", false)):
					_casts += 1
				if float(runner.get("v_charge")) >= 100.0:
					var verdict_v: Dictionary = runner.call("activate_v")
					if bool(verdict_v.get("ok", false)):
						_casts += 1
						_events.append({"t": _elapsed, "event": "revelation"})
		if _elapsed >= _seconds:
			_phase = 3
			_write_report(runner)
			Global.debug_player_god_mode = false
			if _filter != null:
				_filter.set("cap_mode", 0)
			get_tree().quit(0)

	func _write_report(runner: Node) -> void:
		var counters: Dictionary = runner.call("get_debug_counters") if runner != null else {}
		var report := {
			"preset": _preset,
			"segment": Global.attempt_segment,
			"seconds": _elapsed,
			"population": _population,
			"kills_per_sec": _kills_per_sec,
			"kills": _kills,
			"casts": _casts,
			"seed": _seed,
			"headless": DisplayServer.get_name() == "headless",
			"display_server": DisplayServer.get_name(),
			"renderer": RenderingServer.get_current_rendering_method() if DisplayServer.get_name() != "headless" else "none",
			"godot": Engine.get_version_info().get("string", ""),
			"build": BuildInfo.describe(),
			"os": OS.get_name(),
			"cpu": OS.get_processor_name(),
			"gpu": RenderingServer.get_video_adapter_name() if DisplayServer.get_name() != "headless" else "",
			"frames": _frame_ms.size(),
			"frame_ms": {"p50": _pct(_frame_ms, 0.5), "p95": _pct(_frame_ms, 0.95), "p99": _pct(_frame_ms, 0.99), "max": _pct(_frame_ms, 1.0)},
			"wall_ms": {"p50": _pct(_wall_ms, 0.5), "p95": _pct(_wall_ms, 0.95), "p99": _pct(_wall_ms, 0.99), "max": _pct(_wall_ms, 1.0)},
			"draw_calls": {"p50": _pct(_draw_calls, 0.5), "max": _pct(_draw_calls, 1.0)},
			"nodes": {"start": _nodes[0] if not _nodes.is_empty() else 0.0, "end": _nodes[_nodes.size() - 1] if not _nodes.is_empty() else 0.0, "max": _pct(_nodes, 1.0)},
			"ascension_usec": {"p50": _pct(_asc_usec, 0.5), "p95": _pct(_asc_usec, 0.95), "max": _pct(_asc_usec, 1.0)},
			"runner_counters": counters,
			"events": _events,
			"note": "frame_ms is the process delta; wall_ms is real spacing between frames; headless runs have no rendering and are not a play-feel measurement.",
		}
		var file := FileAccess.open(_out, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "  "))
			file.close()
		print("AscensionBuildProbe: %s | %s | frames %d | frame p50 %.2f p95 %.2f p99 %.2f max %.2f ms | wall p95 %.2f max %.2f | draw p50 %.0f | nodes %.0f -> %.0f | kills %d casts %d -> %s" % [_preset, "headless" if bool(report["headless"]) else "windowed", _frame_ms.size(), report["frame_ms"]["p50"], report["frame_ms"]["p95"], report["frame_ms"]["p99"], report["frame_ms"]["max"], report["wall_ms"]["p95"], report["wall_ms"]["max"], report["draw_calls"]["p50"], report["nodes"]["start"], report["nodes"]["end"], _kills, _casts, _out])


func _ready() -> void:
	var driver := Driver.new()
	driver.name = "AscensionBuildProbeDriver"
	get_tree().root.call_deferred("add_child", driver)
