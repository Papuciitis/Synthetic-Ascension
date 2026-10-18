extends SceneTree
## A terminal result arriving during a real cold load must supersede that load.

var _passed := 0
var _failed := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
		print("PASS: ", message)
	else:
		_failed += 1
		push_error("FAIL: " + message)

func _wait_final_construction_stage() -> bool:
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline:
		var builder := get_first_node_in_group(&"segment_proc_builder")
		if current_scene != null and current_scene.scene_file_path == "res://scenes/game.tscn" and not bool(current_scene.call("is_transition_ready")) and builder != null and builder.get("_initialization_stage") == &"events":
			return true
		await process_frame
	return false

func _run() -> void:
	var global := root.get_node("Global")
	var saves := root.get_node("SaveManager")
	saves.set("save_dir", "user://scene_transition_interruption/")
	var profile: Resource = saves.call("create_slot", 1, "Transition interruption")
	saves.call("set_current", 1, profile)
	global.set("debug_disable_autosave", true)
	global.call("start_new_attempt")
	global.set("attempt_segment", 2)
	global.set("pending_augment_pick", false)
	global.set("pending_big_choice", false)
	global.call("set_followers", 0)
	var runs_before := int(profile.get("total_runs"))
	var menu := (load("res://ui/screens/MainMenu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	var entered_game := [false]
	root.child_entered_tree.connect(func(node: Node) -> void:
		if node.scene_file_path == "res://scenes/game.tscn":
			entered_game[0] = true
	)
	global.call("goto_game")
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and ResourceLoader.load_threaded_get_status("res://scenes/game.tscn") != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await process_frame
	_check(ResourceLoader.load_threaded_get_status("res://scenes/game.tscn") == ResourceLoader.THREAD_LOAD_IN_PROGRESS, "the interruption begins during genuine Game resource loading")
	global.call("begin_peep_continuation")
	while Time.get_ticks_msec() < deadline:
		if current_scene != null and current_scene.scene_file_path == "res://ui/screens/PeePContinuation.tscn":
			break
		await process_frame
	_check(current_scene != null and current_scene.scene_file_path == "res://ui/screens/PeePContinuation.tscn", "terminal continuation supersedes the in-flight normal-world route")
	_check(bool(global.call("has_pending_peep")) and int(profile.get("total_runs")) == runs_before, "the terminal choice remains unresolved without starting another attempt")
	while Time.get_ticks_msec() < deadline and ResourceLoader.load_threaded_get_status("res://scenes/game.tscn") == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await process_frame
	_check(ResourceLoader.load_threaded_get_status("res://scenes/game.tscn") != ResourceLoader.THREAD_LOAD_IN_PROGRESS, "the superseded resource finishes before its late-result assertion")
	for _i in range(4):
		await process_frame
	_check(not entered_game[0] and current_scene != null and current_scene.scene_file_path == "res://ui/screens/PeePContinuation.tscn", "the superseded Game result cannot replace continuation after its resource load completes")
	_check(not paused, "terminal presentation releases the temporary loading pause")
	# Corrupt only an in-memory race definition so the genuine Game route
	# fails its supplemental atlas request, without touching shared assets.
	global.set("meta_pending_peep", {})
	global.call("start_new_attempt")
	global.set("selected_race_id", "human")
	var race_visual := load("res://data/visuals/races/human.tres")
	var original_race: StringName = race_visual.get("race_id")
	race_visual.set("race_id", &"missing_transition_test_race")
	var failed_paths: Array[String] = []
	global.connect("balance_scene_transition_failed", func(path: String) -> void: failed_paths.append(path))
	var outgoing := current_scene
	global.call("goto_game")
	deadline = Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and (failed_paths.is_empty() or bool(global.call("is_scene_transition_active"))):
		await process_frame
	race_visual.set("race_id", original_race)
	_check(failed_paths == ["res://assets/textures/characters/baked/missing_transition_test_race_frames.tres"], "a genuine supplemental race-atlas failure emits exactly one failed-resource signal")
	_check(current_scene == outgoing and not paused and not root.gui_disable_input, "supplemental asset failure restores the outgoing scene and its pause/input state")
	_check(not bool(global.call("is_scene_transition_active")) and not bool(global.call("loading_scrim").call("is_showing")), "supplemental asset failure releases the transition and loading card")
	global.set("attempt_segment", 2)
	global.set("attempt_world_seed", 732113)
	global.set("attempt_opening_completed", true)
	global.set("pending_augment_pick", false)
	global.set("pending_big_choice", false)
	global.call("goto_game")
	deadline = Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and (current_scene == null or current_scene.scene_file_path != "res://scenes/game.tscn"):
		await process_frame
	var partial_game: WeakRef = weakref(current_scene)
	_check(current_scene != null and current_scene.has_method("is_transition_ready") and not bool(current_scene.call("is_transition_ready")) and paused and root.gui_disable_input, "a second route begins while Game genuinely owns an unfinished setup freeze")
	global.call("goto_game")
	while Time.get_ticks_msec() < deadline:
		if current_scene != null and current_scene != partial_game.get_ref() and current_scene.scene_file_path == "res://scenes/game.tscn" and bool(current_scene.call("is_transition_ready")):
			break
		await process_frame
	_check(partial_game.get_ref() == null and current_scene != null and current_scene.scene_file_path == "res://scenes/game.tscn" and bool(current_scene.call("is_transition_ready")), "the latest Game route replaces the partially constructed destination")
	_check(not paused and not root.gui_disable_input, "Game reload does not inherit the superseded destination's temporary pause or input hold")
	global.call("goto_game")
	var completed_game := current_scene
	while Time.get_ticks_msec() < deadline and (current_scene == null or current_scene == completed_game):
		await process_frame
	_check(current_scene != null and not bool(current_scene.call("is_transition_ready")), "terminal interruption also starts during genuine destination construction")
	global.call("set_followers", 0)
	global.call("begin_peep_continuation")
	while Time.get_ticks_msec() < deadline and (current_scene == null or current_scene.scene_file_path != "res://ui/screens/PeePContinuation.tscn"):
		await process_frame
	_check(current_scene != null and current_scene.scene_file_path == "res://ui/screens/PeePContinuation.tscn" and not paused and not root.gui_disable_input, "terminal reroute during destination construction releases the abandoned setup's input and pause")
	global.set("meta_pending_peep", {})
	global.call("start_new_attempt")
	global.set("attempt_segment", 2)
	global.set("attempt_world_seed", 732113)
	global.set("attempt_opening_completed", true)
	global.set("pending_augment_pick", false)
	var recorder := root.get_node("BalanceRecorder")
	recorder.set("record_headless", true)
	recorder.set("report_directory", "user://late_transition_capture_test")
	global.call("goto_game")
	_check(await _wait_final_construction_stage(), "menu interruption starts at the real final construction stage before Game readiness")
	global.call("goto_main_menu")
	deadline = Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and (current_scene == null or current_scene.scene_file_path != "res://ui/screens/MainMenu.tscn"):
		await process_frame
	_check(not bool(recorder.call("is_recording")) and recorder.get("_mode") != "gameplay", "an outgoing Game completing during a menu route cannot reopen a gameplay capture")
	global.call("goto_game")
	_check(await _wait_final_construction_stage(), "failure interruption also begins immediately before old Game readiness")
	race_visual.set("race_id", &"missing_transition_test_race")
	global.call("goto_game")
	var bound_while_pending := false
	while Time.get_ticks_msec() < deadline and (failed_paths.size() < 2 or bool(global.call("is_scene_transition_active"))):
		bound_while_pending = bound_while_pending or recorder.get("_mode") == "gameplay"
		await process_frame
	race_visual.set("race_id", original_race)
	_check(not bound_while_pending, "old Game completion defers its recorder binding while the newer route is still pending")
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/game.tscn" and bool(current_scene.call("is_transition_ready")) and bool(recorder.call("is_recording")) and recorder.get("_mode") == "gameplay" and not paused and not root.gui_disable_input, "failed replacement resumes and binds the now-ready outgoing Game exactly when the route fails")
	global.call("goto_game")
	_check(await _wait_final_construction_stage(), "failure-history control keeps an existing capture across another final-stage reload")
	race_visual.set("race_id", &"missing_transition_test_race")
	global.call("goto_game")
	while Time.get_ticks_msec() < deadline and (failed_paths.size() < 3 or bool(global.call("is_scene_transition_active"))):
		await process_frame
	race_visual.set("race_id", original_race)
	recorder.call("flush_reports")
	var history := FileAccess.get_file_as_string(String(recorder.get("capture_directory")).path_join("events.jsonl"))
	var failure_targets: Array[String] = []
	for line in history.split("\n", false):
		var row: Dictionary = JSON.parse_string(line)
		if row.get("kind") == "scene_transition_failed":
			failure_targets.append(String(row.get("data", {}).get("target", "")))
	_check(failure_targets == ["res://scenes/game.tscn"], "failure history retains the requested Game destination before deferred gameplay binding clears it")
	print("SceneTransitionInterruptionTest: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
