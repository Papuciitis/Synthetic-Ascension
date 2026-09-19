extends Node

# Real-world streaming reproduction (performance war room M1, step 1).
# Runs the REAL segment-2 game like EnemyHordeBenchmark, holds a horde
# through the debug spawn filter so chunks carry enemies, then teleports
# the player along the district plan's main route (or one chunk east
# with ROAM_ROUTE=east) every two seconds and samples the game's
# ChunkManager every frame: per-chunk build phases, the site decoration's
# sub-steps, and the frame time while roaming. Prints the phase
# percentiles, every activation above 16.7 ms with its split, and the
# roaming frame p95 / p99. Read-only.
#
# Run: <godot> --headless --path . --quit-after 200000 res://tools/tests/RoamStreamProbe.tscn
# Env: ROAM_STOPS (16; capped by the route's length in route mode),
# ROAM_HORDE (120), ROAM_DWELL_SEC (2.0), ROAM_SEED (attempt world seed; a
# fresh one when unset), ROAM_ROUTE (main | east)

class Driver:
	extends Node
	var _phase := 0
	var _elapsed := 0.0
	var _wall := 0.0
	var _stops := 16
	var _horde := 120
	var _dwell := 2.0
	var _stop_index := -1
	var _stop_started := 0.0
	var _spawner: Node = null
	var _filter: Node = null
	var _manager: Node = null
	var _player: Node2D = null
	var _topup_left := 0.0
	var _frames: Array[float] = []
	var _samples: Dictionary = {}
	var _site_steps: Dictionary = {}
	var _content_steps: Dictionary = {}
	var _chunk_px := 1024.0
	var _route: Array = []
	var _route_mode := "main"

	func _env_int(key: String, fallback: int) -> int:
		var value := OS.get_environment(key).strip_edges()
		return int(value) if value.is_valid_int() else fallback

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_stops = _env_int("ROAM_STOPS", 16)
		_horde = _env_int("ROAM_HORDE", 120)
		var route_env := OS.get_environment("ROAM_ROUTE").strip_edges()
		if route_env == "east":
			_route_mode = "east"
		var dwell := OS.get_environment("ROAM_DWELL_SEC").strip_edges()
		if dwell.is_valid_float():
			_dwell = float(dwell)
		Global.start_new_attempt()
		var seed_env := OS.get_environment("ROAM_SEED").strip_edges()
		if seed_env.is_valid_int():
			Global.attempt_world_seed = int(seed_env)
		Global.attempt_segment = 2
		Global.debug_dev_segment = false
		Global.debug_dev_mode = true
		Global.debug_player_god_mode = true
		Global.debug_projectile_stress_test = false
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

	func _collect() -> void:
		if _manager == null:
			return
		var stats: Dictionary = _manager.call("get_chunk_stream_debug_stats") as Dictionary
		for sample in stats.get("build_phase_samples", []):
			if sample is Dictionary:
				var key := String((sample as Dictionary).get("coord", "?"))
				var existing: Dictionary = _samples.get(key, {})
				if existing.is_empty() or bool(existing.get("staged_pending", false)):
					var copy: Dictionary = (sample as Dictionary).duplicate()
					copy["stop"] = int(existing.get("stop", _stop_index))
					_samples[key] = copy
		var site: Dictionary = stats.get("site_last_step_usec", {}) as Dictionary
		if site.has("coord"):
			_site_steps[String(site["coord"])] = site.duplicate()
		var content: Dictionary = stats.get("content_last_steps", {}) as Dictionary
		if content.has("coord") and not _content_steps.has(String(content["coord"])):
			_content_steps[String(content["coord"])] = content.duplicate(true)

	func _pct(values: Array, p: float) -> float:
		if values.is_empty():
			return 0.0
		var sorted := values.duplicate()
		sorted.sort()
		return float(sorted[clampi(int(ceil(p * sorted.size())) - 1, 0, sorted.size() - 1)])

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
			_spawner = get_tree().get_first_node_in_group(&"enemy_spawner")
			_filter = get_node_or_null("/root/DebugEnemySpawnFilter")
			_manager = get_tree().get_first_node_in_group(&"chunk_manager")
			_player = get_tree().get_first_node_in_group(&"player") as Node2D
			if _spawner == null or _filter == null or _manager == null or _player == null:
				push_error("RoamStreamProbe: missing spawner, filter, chunk manager or player")
				get_tree().quit(1)
				return
			_chunk_px = float(_manager.get("chunk_size_px"))
			if _route_mode == "main":
				var builder := get_tree().get_first_node_in_group(&"segment_proc_builder")
				var plan: Dictionary = (builder.get("_plan") as Dictionary) if builder != null else {}
				_route = (plan.get("main_route", []) as Array).duplicate()
				if _route.is_empty():
					push_error("RoamStreamProbe: no main route in the segment plan")
					get_tree().quit(1)
					return
				_stops = mini(_stops, _route.size())
			_filter.set("cap_mode", 1)
			_filter.set("custom_total_cap", _horde)
			_phase = 2
			_stop_index = -1
			_stop_started = _elapsed
			print("RoamStreamProbe: segment 2 seed %d, horde %d, %d stops (%s route, chunk %d px) every %.1f s" % [Global.attempt_world_seed, _horde, _stops, ("main" if _route_mode == "main" else "east"), int(_chunk_px), _dwell])
			return
		if _phase != 2:
			return
		_topup_left -= delta
		if _topup_left <= 0.0:
			_topup_left = 0.5
			var alive := int(_spawner.call("_alive_total"))
			var queued := int(_spawner.get("_force_spawn_queue"))
			var deficit: int = _horde - alive - queued
			if deficit > 0:
				_spawner.call("debug_force_spawn", deficit)
		if _stop_index >= 0:
			_frames.append(delta * 1000.0)
		_collect()
		if _elapsed - _stop_started >= _dwell:
			_stop_index += 1
			_stop_started = _elapsed
			if _stop_index >= _stops:
				_report()
				return
			if _route_mode == "main":
				var c: Vector2i = _route[_stop_index]
				_player.global_position = (Vector2(c) + Vector2(0.5, 0.5)) * _chunk_px
			else:
				_player.global_position += Vector2(_chunk_px, 0.0)

	func _report() -> void:
		_phase = 3
		var rows: Array = _samples.values()
		var streamed: Array = []
		for r in rows:
			if int(r.get("stop", -1)) >= 0:
				streamed.append(r)
		print("RoamStreamProbe: %d activations while roaming (%d before the first stop), horde alive %d, materialized %s" % [streamed.size(), rows.size() - streamed.size(), int(_spawner.call("_alive_total")), str(EnemyWorld.active_count()) if EnemyWorld != null else "?"])
		print("| phase | p50 ms | p95 ms | max ms |")
		print("|---|---:|---:|---:|")
		for phase in ["setup_ms", "ground_ms", "content_ms", "floor_ms", "blocker_ms", "total_ms"]:
			var values: Array = []
			for r in streamed:
				values.append(float(r.get(phase, 0.0)))
			print("| %s | %.2f | %.2f | %.2f |" % [phase.trim_suffix("_ms"), _pct(values, 0.5), _pct(values, 0.95), _pct(values, 1.0)])
		var over := 0
		var steps: Array = []
		var over_step := 0
		var staged_count := 0
		for r in streamed:
			if float(r.get("total_ms", 0.0)) > 16.7:
				over += 1
			# The largest single-frame piece of this activation: with staged
			# blockers the content side, the physics step and the render step
			# land on different frames.
			var content_side := float(r.get("total_ms", 0.0)) - float(r.get("blocker_ms", 0.0))
			var worst_piece := float(r.get("total_ms", 0.0))
			if bool(_manager.get("staged_blocker_activation")):
				staged_count += 1
				worst_piece = maxf(content_side, maxf(float(r.get("blocker_physics_ms", 0.0)), float(r.get("blocker_render_ms", 0.0))))
			steps.append(worst_piece)
			if worst_piece > 16.7:
				over_step += 1
		print("activations over 16.7 ms while roaming: %d of %d; site chunks decorated: %d" % [over, streamed.size(), _site_steps.size()])
		print("worst single-frame step per activation (%s): p50 %.2f p95 %.2f max %.2f; over 16.7 ms: %d, over 12 ms: %d" % ["staged" if staged_count > 0 else "synchronous", _pct(steps, 0.5), _pct(steps, 0.95), _pct(steps, 1.0), over_step, steps.filter(func(v: float) -> bool: return v > 12.0).size()])
		streamed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("total_ms", 0.0)) > float(b.get("total_ms", 0.0)))
		print("worst activations (total: setup / ground / content / floor / blocker):")
		for i in range(mini(6, streamed.size())):
			var r: Dictionary = streamed[i]
			var key := String(r.get("coord", "?"))
			print("  %s stop %d %.2f ms: %.2f / %.2f / %.2f / %.2f / %.2f (blocker = physics %.2f + render %.2f)" % [key, int(r.get("stop", -1)), float(r.get("total_ms", 0.0)), float(r.get("setup_ms", 0.0)), float(r.get("ground_ms", 0.0)), float(r.get("content_ms", 0.0)), float(r.get("floor_ms", 0.0)), float(r.get("blocker_ms", 0.0)), float(r.get("blocker_physics_ms", 0.0)), float(r.get("blocker_render_ms", 0.0))])
			if _content_steps.has(key):
				var cs: Dictionary = _content_steps[key]
				var line := "      content [%s role=%s conn=%d]:" % [String(cs.get("archetype", "?")), String(cs.get("role", "")), int(cs.get("conn", 0))]
				for k in ["site_probe", "site", "body", "deco"]:
					if cs.has(k):
						line += " %s %.2f" % [k, float(cs[k]) / 1000.0]
				if cs.has("district"):
					var ds: Dictionary = cs["district"]
					line += " | district:"
					for k in ["fill", "roads", "parcels", "donjon", "wall_lines", "walls", "reward"]:
						if ds.has(k):
							line += " %s %.2f" % [k, float(ds[k]) / 1000.0]
				print(line)
			if _site_steps.has(key):
				var st: Dictionary = _site_steps[key]
				print("      site sub-steps ms: plan %.2f / floor %.2f / walls %.2f / cover %.2f / door %.2f / volumes %.2f" % [float(st.get("plan", 0)) / 1000.0, float(st.get("floor", 0)) / 1000.0, float(st.get("walls", 0)) / 1000.0, float(st.get("cover", 0)) / 1000.0, float(st.get("door", 0)) / 1000.0, float(st.get("volumes", 0)) / 1000.0])
		print("roaming frame ms: p50 %.2f p95 %.2f p99 %.2f max %.2f over %d frames" % [_pct(_frames, 0.5), _pct(_frames, 0.95), _pct(_frames, 0.99), _pct(_frames, 1.0), _frames.size()])
		print("RoamStreamProbe: completed")
		Global.debug_player_god_mode = false
		_filter.set("cap_mode", 0)
		get_tree().quit(0)


func _ready() -> void:
	var driver := Driver.new()
	driver.name = "RoamStreamDriver"
	get_tree().root.call_deferred("add_child", driver)
