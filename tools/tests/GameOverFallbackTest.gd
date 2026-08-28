extends Node

# Regression: game.gd end_run() paused the tree first and, when the game-over
# UI could not be instantiated, returned with the tree still paused and no way
# out (logging audit 2026-08-28, finding 44). It must recover: the tree is
# unpaused and the player is taken back to the main menu.
#
# Needs a real run: end_run() lives on the game scene. The Dev Segment world
# keeps the boot light (game.gd strips chunking, spawner and Level1 for it).

class Driver:
	extends Node

	var _phase := 0
	var _wall := 0.0
	var _passes := 0
	var _failures := 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		Global.debug_dev_segment = true
		Global.debug_dev_mode = true
		Global.start_new_attempt()
		Global.attempt_segment = 2
		Global.pending_augment_pick = false
		_phase = 1
		Global.goto_game()

	func _check(condition: bool, message: String) -> void:
		if condition:
			_passes += 1
			print("PASS: ", message)
		else:
			_failures += 1
			push_error("FAIL: " + message)

	func _process(delta: float) -> void:
		_wall += delta
		if _wall > 40.0:
			_check(false, "timed out in phase %d" % _phase)
			_finish()
			return
		match _phase:
			1:
				var scene := get_tree().current_scene
				if scene != null and scene.scene_file_path == Global.PATH_GAME and scene.is_node_ready():
					_phase = 2
					_wall = 0.0
			2:
				if _wall < 0.5:
					return
				if get_tree().paused:
					_dismiss_blocking_ui()
					return
				var game := get_tree().current_scene
				_check(game != null and game.has_method("end_run"), "game scene is live and exposes end_run")
				if game == null:
					_finish()
					return
				game.set("game_over_ui_scene", null)
				game.call("end_run")
				_phase = 3
				_wall = 0.0
			3:
				if _wall < 1.0:
					return
				var scene := get_tree().current_scene
				var where := scene.scene_file_path if scene != null else "<none>"
				_check(not get_tree().paused, "tree is not left paused when the game-over UI is unavailable")
				_check(where == Global.PATH_MAIN_MENU, "run end without a game-over UI falls back to the main menu (now at %s)" % where)
				_finish()

	func _dismiss_blocking_ui() -> void:
		var scene := get_tree().current_scene
		var ui := scene.get_node_or_null("UI") if scene != null else null
		if ui != null:
			for child in ui.get_children():
				if child.has_method("open_choose_3"):
					child.queue_free()
		get_tree().paused = false

	func _finish() -> void:
		_phase = 99
		print("GameOverFallbackTest: %d passed, %d failed" % [_passes, _failures])
		get_tree().quit(1 if _failures > 0 else 0)


func _ready() -> void:
	var driver := Driver.new()
	get_tree().root.add_child.call_deferred(driver)
