extends Node

## What a physics tick is made of in a real segment-2 fight, at held enemy
## populations (the captures' "enemy_step" hitches read the scheduler's
## physics_step_ms, which spans the whole rest of the physics tick, not only
## enemy AI). Marker nodes stamp the first and last physics callback and the
## first idle callback; EnemyActor's debug timers add the enemies' own steps.
## Per stage it prints medians / p95 / p99 of:
##   step      the scheduler's physics_step_ms (what the recorder tags)
##   calls     every script physics callback (first -> last marker)
##   full      enemies' full-tier _physics_process (AI + move_and_slide)
##   sched     mid/far enemy steps the scheduler runs
##   other     calls - full - sched (player, projectiles, directors, ...)
##   server    last callback -> next idle: the physics server's step
## plus materialized enemies, full-tier steps per tick and physics monitors.
##
## Run: <godot> --headless --path . res://tools/tests/PhysicsStepAttributionProbe.tscn
## Env: PROBE_TARGETS=10,30,60,100 (live population), PROBE_HOLD_SEC=10,
## PROBE_BALANCE=1 (BalanceRecorder on, as in play), PROBE_FRAME_DELAY_MS=25
## (sleep each frame, standing in for a slow render/present: Godot then runs
## several physics ticks per frame to catch up). Each stage also tags the
## flight recorder's samples with PerformanceHitchTagger twice: with this
## frame's physics fields ("new") and without them, as older captures were
## tagged from the 0.5 s slow snapshot ("legacy").

class Driver:
	extends Node

	const SPINUP_SEC := 4.0

	var _targets: Array[int] = [10, 30, 60, 100]
	var _hold_sec := 10.0
	var _phase := 0
	var _elapsed := 0.0
	var _wall := 0.0
	var _stage := -1
	var _stage_started := 0.0
	var _topup_left := 0.0
	var _spawner: Node = null
	var _sampling := false
	var _rows: Dictionary = {}
	var _tick_first := 0
	var _tick_last := 0
	var _pending_server_from := 0
	var _report: PackedStringArray = []
	var _frame_delay_ms := 0


	class Marker:
		extends Node
		var probe: Node
		var kind := 0
		func _physics_process(_delta: float) -> void:
			probe.call("_on_physics_marker", kind)
		func _process(_delta: float) -> void:
			if kind == 2:
				probe.call("_on_idle_marker")
			elif kind == 3:
				probe.call("_on_frame_end_marker")


	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		var env_targets := OS.get_environment("PROBE_TARGETS").strip_edges()
		if env_targets != "":
			_targets.clear()
			for part in env_targets.split(","):
				if part.strip_edges().is_valid_int():
					_targets.append(int(part.strip_edges()))
		if OS.get_environment("PROBE_HOLD_SEC").is_valid_float():
			_hold_sec = float(OS.get_environment("PROBE_HOLD_SEC"))
		for kind in [0, 1, 2, 3]:
			var marker := Marker.new()
			marker.probe = self
			marker.kind = kind
			marker.process_mode = Node.PROCESS_MODE_ALWAYS
			marker.process_physics_priority = -1_000_000_000 if kind == 0 else 1_000_000_000
			# 3 runs after every other _process: where rendering would start.
			marker.process_priority = 1_000_000_000 if kind == 3 else -1_000_000_000
			marker.set_process(kind >= 2)
			marker.set_physics_process(kind < 2)
			get_tree().root.call_deferred("add_child", marker)
		var recorder := get_node_or_null("/root/PerformanceFlightRecorder")
		if recorder != null:
			recorder.set("write_reports", false)
			recorder.set("automatic_capture", false)
			recorder.call("set_enabled", true)
		if OS.get_environment("PROBE_FRAME_DELAY_MS").is_valid_int():
			_frame_delay_ms = int(OS.get_environment("PROBE_FRAME_DELAY_MS"))
		# In play the BalanceRecorder is on by default; headless it stays off
		# unless asked (PROBE_BALANCE=1), which is what play looks like.
		var balance := get_node_or_null("/root/BalanceRecorder")
		if balance != null and OS.get_environment("PROBE_BALANCE") == "1":
			balance.set("record_headless", true)
			balance.call("set_enabled", false)
			balance.call("set_enabled", true)
			print("PhysicsStepAttributionProbe: BalanceRecorder on")
		Global.start_new_attempt()
		Global.attempt_segment = 2
		Global.debug_dev_segment = false
		Global.debug_dev_mode = true
		# No story card may stop an unattended run (StoryDirector.cards_allowed).
		StoryDirector.cards_override = 0
		Global.debug_player_god_mode = true
		Global.debug_projectile_stress_test = false
		EnemyActor.debug_physics_timing = true
		_phase = 1
		Global.goto_game()


	func _on_physics_marker(kind: int) -> void:
		var now := Time.get_ticks_usec()
		if kind == 0:
			if _pending_server_from > 0:
				_add("server", float(now - _pending_server_from) / 1000.0)
				_pending_server_from = 0
			_tick_first = now
			EnemyActor.debug_full_step_usec = 0
			EnemyActor.debug_full_step_calls = 0
			EnemyActor.debug_scheduled_step_usec = 0
			EnemyActor.debug_scheduled_step_calls = 0
			return
		_tick_last = now
		if not _sampling or _tick_first <= 0:
			return
		var calls := float(_tick_last - _tick_first) / 1000.0
		var full := float(EnemyActor.debug_full_step_usec) / 1000.0
		var sched := float(EnemyActor.debug_scheduled_step_usec) / 1000.0
		_add("calls", calls)
		_add("full", full)
		_add("sched", sched)
		_add("other", maxf(0.0, calls - full - sched))
		_add("full_steps", float(EnemyActor.debug_full_step_calls))
		_add("sched_steps", float(EnemyActor.debug_scheduled_step_calls))
		_add("active_objects", float(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)))
		_add("collision_pairs", float(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)))
		_pending_server_from = _tick_last


	func _on_frame_end_marker() -> void:
		if _frame_delay_ms > 0 and _phase == 2:
			OS.delay_msec(_frame_delay_ms)


	func _on_idle_marker() -> void:
		if _pending_server_from > 0:
			_add("server", float(Time.get_ticks_usec() - _pending_server_from) / 1000.0)
			_pending_server_from = 0
		if not _sampling:
			return
		var scheduler := get_node_or_null("/root/EnemySimulationScheduler")
		if scheduler != null:
			_add("step", float(scheduler.call("last_step_sample_ms")))
		_add("materialized", float(get_tree().get_nodes_in_group(&"enemies").size()))


	func _add(key: String, value: float) -> void:
		if not _rows.has(key):
			_rows[key] = []
		(_rows[key] as Array).append(value)


	func _pct(values: Array, p: float) -> float:
		if values.is_empty():
			return 0.0
		var ordered := values.duplicate()
		ordered.sort()
		return float(ordered[clampi(int(float(ordered.size() - 1) * p), 0, ordered.size() - 1)])


	func _process(delta: float) -> void:
		if _phase < 1:
			return
		_wall += delta
		if get_tree().paused:
			if _wall >= 2.0:
				var scene := get_tree().current_scene
				var ui := scene.get_node_or_null("UI") if scene != null else null
				if ui != null:
					for child in ui.get_children():
						if child.has_method("open_choose_3"):
							child.queue_free()
				get_tree().paused = false
			return
		_elapsed += delta
		if _phase == 1 and _elapsed >= 3.0:
			_phase = 2
			_spawner = get_tree().get_first_node_in_group(&"enemy_spawner")
			var filter := get_node_or_null("/root/DebugEnemySpawnFilter")
			if _spawner == null or filter == null:
				push_error("PhysicsStepAttributionProbe: missing spawner or filter")
				get_tree().quit(1)
				return
			filter.set("cap_mode", 1)
			_begin_stage(0)
			return
		if _phase != 2:
			return
		_topup_left -= delta
		if _topup_left <= 0.0:
			_topup_left = 0.5
			var deficit: int = _targets[_stage] - int(_spawner.call("_alive_total")) - int(_spawner.get("_force_spawn_queue"))
			if deficit > 0:
				_spawner.call("debug_force_spawn", deficit)
		var in_stage := _elapsed - _stage_started
		if not _sampling and in_stage >= SPINUP_SEC:
			_sampling = true
		if in_stage >= SPINUP_SEC + _hold_sec:
			_end_stage()
			if _stage + 1 < _targets.size():
				_begin_stage(_stage + 1)
			else:
				for line in _report:
					print(line)
				get_tree().quit(0)


	func _begin_stage(index: int) -> void:
		_stage = index
		_stage_started = _elapsed
		_sampling = false
		_rows.clear()
		var filter := get_node_or_null("/root/DebugEnemySpawnFilter")
		if filter != null:
			filter.set("custom_total_cap", _targets[index])


	func _end_stage() -> void:
		_sampling = false
		var line := "PhysicsStepAttribution target=%d materialized~%.0f full_steps/tick~%.0f sched_steps/tick~%.0f | " % [
			_targets[_stage], _pct(_rows.get("materialized", []), 0.5),
			_pct(_rows.get("full_steps", []), 0.5), _pct(_rows.get("sched_steps", []), 0.5)]
		for key in ["step", "calls", "full", "sched", "other", "server"]:
			var values: Array = _rows.get(key, [])
			line += "%s %.2f/%.2f/%.2f  " % [key, _pct(values, 0.5), _pct(values, 0.95), _pct(values, 0.99)]
		line += "| pairs~%.0f active~%.0f" % [_pct(_rows.get("collision_pairs", []), 0.5), _pct(_rows.get("active_objects", []), 0.5)]
		_report.append(line)
		print(line)
		var tags := _tag_report()
		_report.append(tags)
		print(tags)


	## Tag the recorder's samples from this stage's hold, new and legacy way.
	func _tag_report() -> String:
		var recorder := get_node_or_null("/root/PerformanceFlightRecorder")
		if recorder == null:
			return "   tags: no recorder"
		var history: Array = recorder.get("_history")
		var hold_from := Time.get_ticks_usec() - int(_hold_sec * 1_000_000.0)
		var fresh: Array = []
		var legacy: Array = []
		var ticks := {}
		for row in history:
			var sample := row as Dictionary
			if int(sample.get("t_usec", 0)) < hold_from:
				continue
			fresh.append(sample)
			var old := sample.duplicate()
			for key in ["physics_step_ms", "physics_ticks", "physics_frame_ms"]:
				old.erase(key)
			legacy.append(old)
			var n := int(sample.get("physics_ticks", -1))
			ticks[n] = int(ticks.get(n, 0)) + 1
		return "   ticks/frame %s | new tags %s | legacy tags %s" % [str(ticks), _tag_counts(fresh), _tag_counts(legacy)]


	func _tag_counts(samples: Array) -> String:
		var result := PerformanceHitchTagger.distribution(samples)
		var parts: PackedStringArray = []
		for entry in result.get("tags", []):
			parts.append("%s %d" % [entry["tag"], int(entry["count"])])
		return "hitches %d [%s]" % [int(result.get("hitches", 0)), ", ".join(parts)]



func _ready() -> void:
	# Ambient population only, as in EnemyHordeBenchmark: authored beats add
	# protected specials at 45 s and would skew the stages.
	if Global != null and "debug_encounter_beats" in Global:
		Global.set("debug_encounter_beats", false)
	# The game scene replaces this one; the driver lives on the root.
	var driver := Driver.new()
	driver.name = "PhysicsStepAttributionDriver"
	get_tree().root.call_deferred("add_child", driver)
