extends SceneTree
## Measures the real cold Game route. No fixture delay keeps the spinner alive.

var _passes := 0
var _failures := 0
var _warm_repeat := false

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	var passes_before := _passes
	var failures_before := _failures
	print("TRANSITION_CASE ", "warm_same_process" if _warm_repeat else "cold")
	var global := root.get_node("Global")
	root.get_node("BalanceRecorder").set("report_directory", "user://frontend_transition_captures")
	var diagnostic_paths: Array = []
	var diagnostic_file := OS.get_environment("FRONTEND_DIAG_DEPENDENCIES")
	if not diagnostic_file.is_empty():
		diagnostic_paths = JSON.parse_string(FileAccess.get_file_as_string(diagnostic_file)) as Array
	global.set("debug_disable_autosave", true)
	root.get_node("SettingsManager").call("set_value", &"accessibility", &"reduced_motion", false, false)
	global.call("start_new_attempt")
	var segment := 2 if OS.get_environment("FRONTEND_TEST_SEGMENT").is_empty() else clampi(int(OS.get_environment("FRONTEND_TEST_SEGMENT")), 1, 10)
	global.set("attempt_segment", segment)
	global.set("attempt_world_seed", 732113)
	global.set("attempt_opening_completed", true)
	global.set("attempt_opening_phase", 10)
	global.set("pending_augment_pick", false)
	global.set("pending_big_choice", false)
	var menu := (load("res://ui/screens/MainMenu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	var started := Time.get_ticks_usec()
	global.call("goto_game")
	var scrim := global.call("loading_scrim") as CanvasLayer
	var spinner := scrim.find_child("Spinner", true, false) as Control
	var previous_rotation := spinner.rotation
	var samples := 0
	var moving_samples := 0
	var previous_usec := Time.get_ticks_usec()
	var max_gap_ms := 0.0
	var capture_dir := OS.get_environment("FRONTEND_CAPTURE_DIR")
	var next_diagnostic := Time.get_ticks_msec() + 5000
	while current_scene == menu and Time.get_ticks_usec() - started < 120000000:
		await process_frame
		var now := Time.get_ticks_usec()
		var load_gap_ms := float(now - previous_usec) / 1000.0
		max_gap_ms = maxf(max_gap_ms, load_gap_ms)
		if OS.get_environment("FRONTEND_TRACE_READY") == "1" and load_gap_ms > 150.0:
			print("LOAD_FRAME index=%d gap_ms=%.3f" % [samples, load_gap_ms])
		if not diagnostic_paths.is_empty() and Time.get_ticks_msec() >= next_diagnostic:
			next_diagnostic = Time.get_ticks_msec() + 5000
			var progress: Array = []
			var status := ResourceLoader.load_threaded_get_status("res://scenes/game.tscn", progress)
			var uncached: Array[String] = []
			for path: String in diagnostic_paths:
				if not ResourceLoader.has_cached(path):
					uncached.append(path)
			print("LOAD_PROGRESS elapsed_ms=%d status=%d progress=%s uncached=%s" % [(Time.get_ticks_usec() - started) / 1000, status, progress, uncached])
		previous_usec = now
		if current_scene != menu:
			break
		samples += 1
		if not is_equal_approx(spinner.rotation, previous_rotation):
			moving_samples += 1
		previous_rotation = spinner.rotation
		if not capture_dir.is_empty() and samples in [12, 30] and DisplayServer.get_name() != "headless":
			root.get_texture().get_image().save_png(capture_dir.path_join("loading-frame-%d.png" % samples))
	print("TRANSITION_STATE resource_status=%d active=%s paused=%s current=%s" % [ResourceLoader.load_threaded_get_status("res://scenes/game.tscn"), global.get("_scene_transition_active"), paused, current_scene.scene_file_path if current_scene != null else "<switching>"])
	print("TRANSITION_METRICS loading_frames=%d spinner_advances=%d route_ms=%.3f max_gap_ms=%.3f" % [samples, moving_samples, float(Time.get_ticks_usec() - started) / 1000.0, max_gap_ms])
	_check(moving_samples >= 8, "the spinner advances across real cold Game loading work")
	var ready_deadline := Time.get_ticks_msec() + 30000
	var setup_frames := 0
	var setup_spinner_advances := 0
	var setup_kept_frozen := true
	while Time.get_ticks_msec() < ready_deadline:
		if current_scene != null and (not current_scene.has_method("is_transition_ready") or bool(current_scene.call("is_transition_ready"))):
			break
		if current_scene != null:
			setup_kept_frozen = setup_kept_frozen and paused and root.gui_disable_input
		await process_frame
		var now := Time.get_ticks_usec()
		var frame_gap_ms := float(now - previous_usec) / 1000.0
		max_gap_ms = maxf(max_gap_ms, frame_gap_ms)
		previous_usec = now
		setup_frames += 1
		if OS.get_environment("FRONTEND_TRACE_READY") == "1" and current_scene != null:
			var builder := get_first_node_in_group(&"segment_proc_builder")
			var staged_hud := current_scene.get_node_or_null("UI/HUD")
			print("SETUP_FRAME index=%d gap_ms=%.3f game_stage=%s builder_stage=%s hud_stage=%s" % [setup_frames, frame_gap_ms, current_scene.get("_entry_stage"), builder.get("_initialization_stage") if builder != null else "<none>", staged_hud.get("_initialization_stage") if staged_hud != null else "<none>"])
		if not is_equal_approx(spinner.rotation, previous_rotation):
			setup_spinner_advances += 1
		previous_rotation = spinner.rotation
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/game.tscn", "the responsive route reaches the actual Game scene")
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/game.tscn" and (not current_scene.has_method("is_transition_ready") or bool(current_scene.call("is_transition_ready"))), "the real destination completes its initial world setup")
	_check(setup_frames >= 4 and setup_spinner_advances >= 3 and setup_kept_frozen, "the destination builds across animated frames with gameplay and input frozen")
	_check(not paused and not root.gui_disable_input, "ready gameplay releases only the temporary loading pause and input lock")
	var final_hud := current_scene.get_node_or_null("UI/HUD") if current_scene != null else null
	_check(final_hud != null and final_hud.get("bag_ctl") != null and final_hud.get("tip_ctl") != null and final_hud.get("gate_overlay_ctl") != null and final_hud.get("tutorial_tip_ctl") != null, "staged HUD retains its management, tooltip, gate, and tutorial bindings")
	print("TRANSITION_SETUP_METRICS setup_frames=%d spinner_advances=%d total_ms=%.3f max_gap_ms=%.3f" % [setup_frames, setup_spinner_advances, float(Time.get_ticks_usec() - started) / 1000.0, max_gap_ms])
	_check(max_gap_ms < 300.0, "resource loading and initial world setup keep animation frame gaps below 300 ms")
	print("TRANSITION_CASE_RESULT case=%s passed=%d failed=%d" % ["warm_same_process" if _warm_repeat else "cold", _passes - passes_before, _failures - failures_before])
	print("LoadingTransitionResponsivenessTest: %d passed, %d failed" % [_passes, _failures])
	if OS.get_environment("FRONTEND_REPEAT_TRANSITION") == "1" and not _warm_repeat:
		_warm_repeat = true
		if current_scene != null:
			current_scene.free()
			current_scene = null
		paused = false
		await process_frame
		await _run()
		return
	quit(1 if _failures > 0 else 0)
