extends Node

# Staged horde benchmark: forces the live population to fixed targets and
# holds each stage, printing frame percentiles and simulation counters.
# Headless runs measure CPU truth (process/physics); desktop runs add real
# frame times and draw calls. The 500-goal gate: stage 550 p95 <= 33ms.

class Driver:
	extends Node

	const STAGES: Array[int] = [120, 250, 400, 550]
	const STAGE_HOLD_SEC := 20.0
	const STAGE_SPINUP_SEC := 4.0

	var _phase := 0
	var _elapsed := 0.0
	var _wall := 0.0
	var _stage_index := -1
	var _stage_started := 0.0
	var _sampling := false
	var _frames: Array[float] = []
	var _process_ms: Array[float] = []
	var _physics_ms: Array[float] = []
	var _draws: Array[float] = []
	var _spawner: Node = null
	var _filter: Node = null
	var _topup_left := 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		Global.start_new_attempt()
		Global.attempt_segment = 2
		Global.debug_dev_segment = false
		Global.debug_dev_mode = true
		Global.debug_player_god_mode = true
		Global.debug_projectile_stress_test = false
		_phase = 1
		Global.goto_game()

	func _pct(values: Array[float], p: float) -> float:
		if values.is_empty():
			return 0.0
		var ordered := values.duplicate()
		ordered.sort()
		return ordered[clampi(int(float(ordered.size() - 1) * p / 100.0), 0, ordered.size() - 1)]

	func _mean(values: Array[float]) -> float:
		if values.is_empty():
			return 0.0
		var total := 0.0
		for value in values:
			total += value
		return total / float(values.size())

	func _dismiss_blocking_ui() -> void:
		var scene := get_tree().current_scene
		var ui := scene.get_node_or_null("UI") if scene != null else null
		if ui != null:
			for child in ui.get_children():
				if child.has_method("open_choose_3"):
					child.queue_free()
		get_tree().paused = false

	func _begin_stage(index: int) -> void:
		_stage_index = index
		_stage_started = _elapsed
		_sampling = false
		_frames.clear()
		_process_ms.clear()
		_physics_ms.clear()
		_draws.clear()
		print("HordeBenchmark: stage %d -> target %d" % [index, STAGES[index]])

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
			if _spawner == null or _filter == null:
				push_error("HordeBenchmark: missing spawner or filter")
				get_tree().quit(1)
				return
			_filter.set("cap_mode", 2) # UNLIMITED
			_begin_stage(0)
			return
		if _phase != 2:
			return

		# Keep the population topped up to the stage target.
		_topup_left -= delta
		if _topup_left <= 0.0:
			_topup_left = 0.5
			var alive := int(_spawner.call("_alive_total"))
			var deficit: int = STAGES[_stage_index] - alive
			if deficit > 0:
				_spawner.call("debug_force_spawn", deficit)

		var stage_elapsed := _elapsed - _stage_started
		if not _sampling and stage_elapsed >= STAGE_SPINUP_SEC:
			_sampling = true
		if _sampling and stage_elapsed < STAGE_SPINUP_SEC + STAGE_HOLD_SEC:
			_frames.append(delta * 1000.0)
			_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			_physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			_draws.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		elif _sampling:
			_report_stage()
			if _stage_index + 1 < STAGES.size():
				_begin_stage(_stage_index + 1)
			else:
				print("HordeBenchmark: completed")
				Global.debug_player_god_mode = false
				_filter.set("cap_mode", 0)
				Global.goto_main_menu()
				get_tree().quit(0)

	func _report_stage() -> void:
		var alive := int(_spawner.call("_alive_total"))
		var scheduler := get_node_or_null("/root/EnemySimulationScheduler")
		var counters := (
			scheduler.call("get_debug_counters") as Dictionary
			if scheduler != null and scheduler.has_method("get_debug_counters")
			else {}
		)
		var world := get_node_or_null("/root/EnemyWorld")
		var world_counters := (
			world.call("get_debug_counters") as Dictionary
			if world != null and world.has_method("get_debug_counters")
			else {}
		)
		print(
			"HordeBenchmark: target=%d alive=%d frames=%d | frame avg %.2f p95 %.2f p99 %.2f | process p95 %.2f | physics p95 %.2f | draws p95 %.0f | full=%s mid=%s far=%s phys_on=%s | materialized=%s data_only=%s"
			% [
				STAGES[_stage_index],
				alive,
				_frames.size(),
				_mean(_frames),
				_pct(_frames, 95.0),
				_pct(_frames, 99.0),
				_pct(_process_ms, 95.0),
				_pct(_physics_ms, 95.0),
				_pct(_draws, 95.0),
				counters.get("full", "?"),
				counters.get("mid", "?"),
				counters.get("far", "?"),
				counters.get("physics_enabled", "?"),
				world_counters.get("materialized", "?"),
				world_counters.get("data_only", "?"),
			]
		)


func _ready() -> void:
	var driver := Driver.new()
	get_tree().root.add_child.call_deferred(driver)
