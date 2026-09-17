extends Node

# Minigun-build stress benchmark: enables the projectile stress torrent
# (ProjectileSimulationManager._run_stress_step) and holds two stages —
# no enemies (pure projectile sim + render cost) and a 250-enemy horde
# (adds data/node hits and the per-hit impact VFX suspected of tanking
# frames: one VFX_SpokesBurst node instantiated per hit). Prints frame
# percentiles plus live projectile and impact-node counts, and persists
# the stage lines like EnemyHordeBenchmark.

class Driver:
	extends Node

	# Stage plan (every enemy stage holds 250):
	#   0 torrent only          — pure projectile sim + render cost
	#   1 horde only (no stress)— in-run baseline for diffing the later stages
	#   2 massacre              — torrent + mortal horde (death/respawn churn)
	#   3 immortal              — hits land, nothing dies (hit pipeline share)
	#   4 immortal, no impacts  — impact system share
	# Drops and stray per-hit nodes are swept between stages so each stage
	# measures its own condition, not the previous stage's leftovers.
	const STAGES: Array[int] = [0, 250, 250, 250, 250]
	const STRESS: Array[bool] = [true, false, true, true, true]
	const IMMORTAL: Array[bool] = [false, false, false, true, true]
	const NO_IMPACTS: Array[bool] = [false, false, false, false, true]
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
	var _projectiles: Array[float] = []
	var _impacts: Array[float] = []
	var _hits: Array[float] = []
	var _nodes: Array[float] = []
	var _render_cpu: Array[float] = []
	var _render_gpu: Array[float] = []
	var _spawner: Node = null
	var _filter: Node = null
	var _topup_left := 0.0
	var _report_lines: PackedStringArray = []

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

	func _process(delta: float) -> void:
		if _phase < 1:
			return
		_dismiss_tutorial_cards()
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
				push_error("MinigunStressBenchmark: missing spawner or filter")
				get_tree().quit(1)
				return
			_filter.set("cap_mode", 1)
			RenderingServer.viewport_set_measure_render_time(
				get_viewport().get_viewport_rid(), true
			)
			_begin_stage(0)
			return
		if _phase != 2:
			return

		_topup_left -= delta
		if _topup_left <= 0.0:
			_topup_left = 0.5
			var target := STAGES[_stage_index]
			if target > 0:
				var alive := int(_spawner.call("_alive_total"))
				var queued := int(_spawner.get("_force_spawn_queue"))
				var deficit: int = target - alive - queued
				if deficit > 0:
					_spawner.call("debug_force_spawn", deficit)
				if IMMORTAL[_stage_index]:
					_make_population_immortal()

		var stage_elapsed := _elapsed - _stage_started
		if not _sampling and stage_elapsed >= STAGE_SPINUP_SEC:
			_sampling = true
		if _sampling and stage_elapsed < STAGE_SPINUP_SEC + STAGE_HOLD_SEC:
			_frames.append(delta * 1000.0)
			_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			_physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			_draws.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			var manager := get_node_or_null("/root/ProjectileManager")
			_projectiles.append(float(manager.get("_active_count")) if manager != null else 0.0)
			_hits.append(float(manager.get("_hits_this_frame")) if manager != null else 0.0)
			_impacts.append(float(_count_impact_nodes()))
			_nodes.append(float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
			var vp_rid := get_viewport().get_viewport_rid()
			_render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp_rid))
			_render_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp_rid))
		elif _sampling:
			_screenshot_stage()
			_census()
			_report_stage()
			if _stage_index + 1 < STAGES.size():
				_begin_stage(_stage_index + 1)
			else:
				print("MinigunStressBenchmark: completed")
				_write_report()
				Global.debug_projectile_stress_test = false
				Global.debug_player_god_mode = false
				_filter.set("cap_mode", 0)
				Global.goto_main_menu()
				get_tree().quit(0)

	func _begin_stage(index: int) -> void:
		_stage_index = index
		_stage_started = _elapsed
		_sampling = false
		_frames.clear()
		_process_ms.clear()
		_physics_ms.clear()
		_draws.clear()
		_projectiles.clear()
		_impacts.clear()
		_hits.clear()
		_nodes.clear()
		_render_cpu.clear()
		_render_gpu.clear()
		_filter.set("custom_total_cap", STAGES[index])
		if STAGES[index] == 0:
			_filter.call("disable_all")
		else:
			_filter.call("enable_all")
			_filter.set("cap_mode", 1)
			_filter.set("custom_total_cap", STAGES[index])
		var manager := get_node_or_null("/root/ProjectileManager")
		if manager != null:
			manager.set("debug_disable_impacts", NO_IMPACTS[index])
			# Re-arm the opening 100-bullet ring whenever stress toggles on.
			if not STRESS[index]:
				manager.set("_stress_started", false)
		Global.debug_projectile_stress_test = STRESS[index]
		_sweep_stage_leftovers()
		print("MinigunStressBenchmark: stage %d -> %d enemies%s%s%s" % [
			index, STAGES[index],
			" (immortal)" if IMMORTAL[index] else "",
			" (no impacts)" if NO_IMPACTS[index] else "",
			" + stress torrent" if STRESS[index] else " (no stress: baseline)",
		])

	func _sweep_stage_leftovers() -> void:
		# Drops from a massacre stage otherwise linger into the next stage and
		# contaminate its draw/node counts.
		var scene := get_tree().current_scene
		if scene == null:
			return
		var swept := 0
		for child in scene.get_children():
			var script: Script = child.get_script() as Script
			if script == null:
				continue
			var file := script.resource_path.get_file()
			if file == "ItemPickup.gd" or file == "HealthPickup.gd":
				child.queue_free()
				swept += 1
		if swept > 0:
			print("MinigunStress: swept %d leftover pickups" % swept)

	func _make_population_immortal() -> void:
		var world := get_node_or_null("/root/EnemyWorld")
		var combat := get_node_or_null("/root/EnemyCombat")
		if world == null or combat == null:
			return
		var handles: Array[int] = []
		world.call("active_handles", handles)
		for handle in handles:
			combat.call("configure_health", handle, 1.0e9, true)

	func _screenshot_stage() -> void:
		# Optional visual check (impact burst look, torrent density): set
		# MINIGUN_SHOT_DIR to capture one frame at the end of each stage.
		var dir := OS.get_environment("MINIGUN_SHOT_DIR")
		if dir.is_empty():
			return
		DirAccess.make_dir_recursive_absolute(dir)
		var img := get_viewport().get_texture().get_image()
		img.save_png(dir.path_join("stage_%d.png" % _stage_index))

	func _census() -> void:
		# One-shot FULL-TREE tally (script file, else class) so draw-call
		# spikes can be attributed even when the culprits live under
		# CanvasLayers or nested inside enemies. Also counts visible
		# CanvasItems, the population the render thread actually walks.
		var tally: Dictionary = {}
		var canvas_items := 0
		var stack: Array[Node] = [get_tree().root]
		while not stack.is_empty():
			var node: Node = stack.pop_back()
			for child in node.get_children():
				stack.push_back(child)
			var item := node as CanvasItem
			if item != null and item.visible:
				canvas_items += 1
			var script: Script = node.get_script() as Script
			var key := (
				script.resource_path.get_file() if script != null else node.get_class()
			)
			tally[key] = int(tally.get(key, 0)) + 1
		var pairs: Array = []
		for key in tally:
			pairs.append([key, tally[key]])
		pairs.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
		var parts: PackedStringArray = []
		for i in range(mini(15, pairs.size())):
			parts.append("%s=%d" % [pairs[i][0], pairs[i][1]])
		var line := "MinigunStress census stage=%d visible_canvas_items=%d: %s" % [
			_stage_index, canvas_items, " ".join(parts),
		]
		print(line)
		_report_lines.append(line)

	func _count_impact_nodes() -> int:
		# Batched impacts live in one renderer under the projectile manager;
		# also count any legacy per-hit SpokesBurst nodes at the scene root.
		var count := 0
		var manager := get_node_or_null("/root/ProjectileManager")
		if manager != null:
			var batched: Node = manager.get("_impact_renderer")
			if batched != null and is_instance_valid(batched):
				count += int(batched.call("active_count"))
		var scene := get_tree().current_scene
		if scene != null:
			for child in scene.get_children():
				var script: Script = child.get_script() as Script
				if script != null and script.resource_path.ends_with("VFX_SpokesBurst.gd"):
					count += 1
		return count

	func _report_stage() -> void:
		var line := (
			"MinigunStress: enemies=%d%s frames=%d | frame avg %.2f p95 %.2f p99 %.2f | process avg %.2f p95 %.2f | physics avg %.2f p95 %.2f | render cpu avg %.2f gpu avg %.2f gpu p95 %.2f | draws p95 %.0f | projectiles avg %.0f max %.0f | hits/frame avg %.1f | impact_nodes avg %.1f max %.0f | nodes first %.0f last %.0f"
			% [
				STAGES[_stage_index],
				(" (immortal)" if IMMORTAL[_stage_index] else "")
					+ (" (no impacts)" if NO_IMPACTS[_stage_index] else "")
					+ ("" if STRESS[_stage_index] else " (baseline, no stress)"),
				_frames.size(),
				_mean(_frames),
				_pct(_frames, 95.0),
				_pct(_frames, 99.0),
				_mean(_process_ms),
				_pct(_process_ms, 95.0),
				_mean(_physics_ms),
				_pct(_physics_ms, 95.0),
				_mean(_render_cpu),
				_mean(_render_gpu),
				_pct(_render_gpu, 95.0),
				_pct(_draws, 95.0),
				_mean(_projectiles),
				_pct(_projectiles, 100.0),
				_mean(_hits),
				_mean(_impacts),
				_pct(_impacts, 100.0),
				_nodes[0] if not _nodes.is_empty() else 0.0,
				_nodes[_nodes.size() - 1] if not _nodes.is_empty() else 0.0,
			]
		)
		print(line)
		_report_lines.append(line)

	func _write_report() -> void:
		var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
		var directory := "res://performance_results/benchmarks"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		var file := FileAccess.open(directory.path_join("minigun_%s.txt" % stamp), FileAccess.WRITE)
		if file != null:
			for line in _report_lines:
				file.store_line(line)
			file.close()

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

	func _dismiss_tutorial_cards() -> void:
		for node in get_tree().root.find_children("*", "", true, false):
			var script: Script = node.get_script() as Script
			if script != null and script.resource_path.ends_with("TutorialCardOverlay.gd"):
				node.call("_dismiss")

	func _dismiss_blocking_ui() -> void:
		var scene := get_tree().current_scene
		var ui := scene.get_node_or_null("UI") if scene != null else null
		if ui != null:
			for child in ui.get_children():
				if child.has_method("open_choose_3"):
					child.queue_free()
		get_tree().paused = false


func _ready() -> void:
	# Benchmarks measure the ambient population; authored beats would add
	# protected specials at 45 s and skew the stages.
	if Global != null and "debug_encounter_beats" in Global:
		Global.set("debug_encounter_beats", false)
	var driver := Driver.new()
	get_tree().root.add_child.call_deferred(driver)
