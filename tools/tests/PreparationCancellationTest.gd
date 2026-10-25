extends SceneTree
## External regression for superseding the real scene router while its new
## script preparation is yielding, BEFORE any Game threaded request exists.
## Run twice in separate cold engines, with isolated launcher XDG directories:
##   --script <absolute path> -- --preparation-case=menu
##   --script <absolute path> -- --preparation-case=terminal
## Can also run against a pack by adding --main-pack <EXE>.
## No world is instantiated and no preparation helper is called directly.
## The late-cancellation fence is the latest destination's real loading-card
## lifecycle followed by two process_frame signals: every preparation yield
## resumes on that signal and must observe the changed transition ID.

const MENU_PATH := "res://ui/screens/MainMenu.tscn"
const GAME_PATH := "res://scenes/game.tscn"
const PEEP_PATH := "res://ui/screens/PeePContinuation.tscn"
const WAIT_MS := 180000

var _case := "menu"
var _passes := 0
var _failures := 0
var _global: Node
var _save_manager: Node
var _watching := false
var _game_entries := 0
var _game_statuses: Array[int] = []


func _initialize() -> void:
	Engine.max_fps = 20
	_run.call_deferred()


func _check(ok: bool, message: String) -> bool:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)
	return ok


func _wait_until(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + WAIT_MS
	while not bool(condition.call()):
		if Time.get_ticks_msec() >= deadline:
			return false
		await process_frame
	return true


func _scene_ready(path: String) -> bool:
	return current_scene != null and current_scene.scene_file_path == path \
		and current_scene.is_node_ready() and not bool(_global.call("is_scene_transition_active")) \
		and (not current_scene.has_method("is_transition_ready") or bool(current_scene.call("is_transition_ready")))


func _observe() -> void:
	if not _watching:
		return
	var status := ResourceLoader.load_threaded_get_status(GAME_PATH)
	if status != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE and not _game_statuses.has(status):
		_game_statuses.append(status)


func _on_root_child_entered(node: Node) -> void:
	if _watching and node.scene_file_path == GAME_PATH:
		_game_entries += 1


func _run() -> void:
	Engine.max_fps = 20
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--preparation-case="):
			_case = arg.trim_prefix("--preparation-case=")
	if not _check(_case in ["menu", "terminal"], "case is menu or terminal (use separate cold invocations)"):
		_finish()
		return
	_global = root.get_node_or_null("Global")
	_save_manager = root.get_node_or_null("SaveManager")
	if not _check(_global != null and _save_manager != null, "real project autoloads initialize"):
		_finish()
		return
	_save_manager.set("save_dir", "user://preparation_cancel_%s_%d/" % [_case, Time.get_ticks_usec()])
	_save_manager.set("current_save", null)
	_save_manager.set("current_slot", -1)
	_global.set("debug_disable_autosave", true)
	for name: String in ["PerformanceFlightRecorder", "BalanceRecorder"]:
		var recorder := root.get_node_or_null(NodePath(name))
		if recorder != null:
			recorder.set("report_directory", String(_save_manager.get("save_dir")) + name + "/")
	print("PREPARATION_CANCELLATION case=", _case, " scratch=", ProjectSettings.globalize_path(String(_save_manager.get("save_dir"))))
	var save: Resource = _save_manager.call("create_slot", 1, "Preparation cancellation")
	if not _check(save != null, "scratch profile is created before normal routing"):
		_finish()
		return
	_save_manager.call("set_current", 1, save)
	_global.call("start_new_attempt")
	_global.call("set_followers", 0)
	_global.call("goto_main_menu")
	if not _check(await _wait_until(func() -> bool: return _scene_ready(MENU_PATH)), "the actual Main Menu is ready"):
		_finish()
		return
	var scrim: Node = _global.call("loading_scrim")
	if not _check(await _wait_until(func() -> bool: return not bool(scrim.call("is_showing"))), "initial menu loading card finishes normally"):
		_finish()
		return
	_check(not paused and not root.gui_disable_input, "real Menu begins with usable pause and input state")
	_check(not ResourceLoader.has_cached(GAME_PATH), "the complete Game PackedScene starts cold")
	_check(ResourceLoader.load_threaded_get_status(GAME_PATH) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, "no Game threaded request predates the case")
	_check(not bool(_global.get("debug_dev_mode")) and not bool(_global.get("debug_dev_segment")), "case uses the normal Game route")
	if _failures > 0:
		_finish()
		return
	var outgoing := current_scene
	var runs_before := int(save.get("total_runs"))
	process_frame.connect(_observe)
	root.child_entered_tree.connect(_on_root_child_entered)
	_watching = true
	_global.call("goto_game")
	var preparation_seen := await _wait_until(func() -> bool:
		return bool(_global.call("is_scene_transition_active")) and paused and current_scene == outgoing \
			and ResourceLoader.load_threaded_get_status(GAME_PATH) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
	)
	if not _check(preparation_seen, "real Game transition yields while paused before requesting the cold PackedScene"):
		_finish()
		return
	_check(bool(scrim.call("is_showing")), "loading card remains visible during real preparation")
	var abandoned_id := int(_global.get("_scene_transition_id"))
	var target := MENU_PATH
	if _case == "terminal":
		# This records a real terminal outcome. The OLD preparation must notice
		# it and perform its built-in reroute; the test never requests PeeP.
		target = PEEP_PATH
		_global.call("begin_peep_continuation")
		_check(bool(_global.call("has_pending_peep")), "terminal outcome becomes pending during preparation")
	else:
		_global.call("goto_main_menu")
	if not _check(await _wait_until(func() -> bool:
		return _scene_ready(target) and current_scene != outgoing
	), "latest %s destination replaces the preparing Game route" % _case):
		_finish()
		return
	_check(int(_global.get("_scene_transition_id")) > abandoned_id, "the newer destination owns the transition generation")
	if not _check(await _wait_until(func() -> bool: return not bool(scrim.call("is_showing"))), "latest destination completes its real loading-card lifecycle"):
		_finish()
		return
	var latest := current_scene
	# A preparation suspended on process_frame must resume and reject its old
	# generation by these signals. These are lifecycle fences, not timed sleeps.
	await process_frame
	await process_frame
	_observe()
	_check(current_scene == latest and _scene_ready(target), "late old preparation preserves the latest scene")
	_check(not paused and not root.gui_disable_input, "late old preparation preserves usable pause and input state")
	_check(_game_entries == 0, "no abandoned Game instance ever enters the root")
	_check(_game_statuses.is_empty() and ResourceLoader.load_threaded_get_status(GAME_PATH) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, "no abandoned Game threaded request is observed (statuses=%s)" % [_game_statuses])
	_check(not ResourceLoader.has_cached(GAME_PATH), "cancellation never warms the complete Game PackedScene")
	_check(int(save.get("total_runs")) == runs_before, "cancellation starts no extra attempt")
	if _case == "terminal":
		_check(bool(_global.call("has_pending_peep")) and not (save.get("meta_pending_peep") as Dictionary).is_empty(), "terminal continuation remains unresolved in memory and the scratch profile")
	else:
		_check(not bool(_global.call("has_pending_peep")), "menu supersession invents no terminal outcome")
	_finish()


func _finish() -> void:
	_watching = false
	# Keep scratch routing active through deferred autoload teardown.
	paused = false
	print("PreparationCancellationTest[%s]: %d passed, %d failed" % [_case, _passes, _failures])
	quit(1 if _failures > 0 else 0)
