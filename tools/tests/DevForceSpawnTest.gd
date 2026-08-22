extends Node

# Real-game contract test for the dev overlay's force-spawn buttons: requests
# larger than one batch queue and drain across frames (entering ~100 bodies
# into the broadphase in one step measured as a 240-300ms physics spike),
# unlimited mode builds a horde, and a saturated cap reports itself instead
# of silently spawning nothing.

class Driver:
	extends Node

	var _phase := 0
	var _elapsed := 0.0
	var _passes := 0
	var _failures := 0
	var _spawner: Node = null
	var _filter: Node = null
	var _alive_after_horde := 0
	var _wall := 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		Global.start_new_attempt()
		Global.attempt_segment = 2
		Global.debug_dev_segment = false
		Global.debug_dev_mode = true
		Global.debug_player_god_mode = true
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
		if _phase < 1:
			return
		_wall += delta
		# The run-start augment selection pauses the tree until the player
		# picks; headless nobody picks, so dismiss it like a player would.
		# Queue drains and organic spawning only run in gameplay, so the
		# phases measure unpaused time.
		if get_tree().paused:
			if _wall >= 2.0:
				_dismiss_blocking_ui()
			return
		_elapsed += delta
		if _phase == 1 and _elapsed >= 6.0:
			_phase = 2
			_spawner = get_tree().get_first_node_in_group(&"enemy_spawner")
			_filter = get_node_or_null("/root/DebugEnemySpawnFilter")
			_check(_spawner != null and _spawner.has_method("debug_force_spawn"), "spawner exposes debug_force_spawn")
			_check(_filter != null, "spawn filter autoload exists")
			if _spawner == null or _filter == null:
				_finish()
				return
			_filter.set("cap_mode", 0) # PRODUCTION
			var result := _spawner.call("debug_force_spawn", 10) as Dictionary
			_check(
				int(result.get("spawned", -1)) == 10 and int(result.get("queued", -1)) == 0,
				"a one-batch request spawns immediately (got %s now, %s queued)" % [
					result.get("spawned"), result.get("queued"),
				]
			)
			_check(int(result.get("cap", 0)) > 0, "production mode reports a positive effective cap")
			_filter.set("cap_mode", 2) # UNLIMITED
			var horde := _spawner.call("debug_force_spawn", 100) as Dictionary
			_check(
				int(horde.get("spawned", 0)) > 0
				and int(horde.get("spawned", 0)) + int(horde.get("queued", 0)) == 100,
				"a large request splits into now + queued (got %s + %s)" % [
					horde.get("spawned"), horde.get("queued"),
				]
			)
		elif _phase == 2 and _elapsed >= 8.5:
			_phase = 3
			var alive := int(_spawner.call("_alive_total"))
			_check(int(_spawner.get("_force_spawn_queue")) == 0, "the forced spawn queue drains")
			_check(alive >= 90, "queued forced spawns materialize (alive %d)" % alive)
			_alive_after_horde = alive
			_filter.set("cap_mode", 1) # CUSTOM
			_filter.set("custom_total_cap", 1)
			var capped := _spawner.call("debug_force_spawn", 10) as Dictionary
			_check(
				int(capped.get("spawned", -1)) == 0 and int(capped.get("queued", -1)) == 0,
				"a saturated cap spawns nothing and queues nothing"
			)
			_check(
				int(capped.get("cap", 0)) > 0
				and int(capped.get("alive", 0)) + int(capped.get("pending", 0)) >= int(capped.get("cap", 0)),
				"cap saturation is visible in the result"
			)
			_filter.set("custom_total_cap", _alive_after_horde + 40)
			var raised := _spawner.call("debug_force_spawn", 100) as Dictionary
			_check(
				int(raised.get("spawned", 0)) > 0,
				"a raised custom cap opens headroom immediately (got %s)" % raised.get("spawned")
			)
		elif _phase == 3 and _elapsed >= 11.0:
			_phase = 4
			var alive := int(_spawner.call("_alive_total"))
			_check(int(_spawner.get("_force_spawn_queue")) == 0, "a capped queue clears instead of retrying forever")
			_check(
				alive >= _alive_after_horde + 20,
				"the raised custom cap actually grew the population (%d -> %d)" % [_alive_after_horde, alive]
			)
			_filter.set("cap_mode", 0)
			_filter.set("custom_total_cap", 180)
			Global.debug_player_god_mode = false
			Global.goto_main_menu()
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
		print("DevForceSpawnTest: %d passed, %d failed" % [_passes, _failures])
		get_tree().quit(1 if _failures > 0 else 0)


func _ready() -> void:
	var driver := Driver.new()
	get_tree().root.add_child.call_deferred(driver)
