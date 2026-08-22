extends Node

# Real-game contract test for the dev overlay's force-spawn buttons: under
# production caps with headroom the requested count spawns exactly; unlimited
# mode builds a horde; a saturated cap reports itself instead of silently
# spawning nothing.

class Driver:
	extends Node

	var _phase := 0
	var _elapsed := 0.0
	var _passes := 0
	var _failures := 0

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
		if _phase != 1:
			return
		_elapsed += delta
		if _elapsed < 6.0:
			return
		_phase = 2
		var spawner := get_tree().get_first_node_in_group(&"enemy_spawner")
		var filter := get_node_or_null("/root/DebugEnemySpawnFilter")
		_check(spawner != null and spawner.has_method("debug_force_spawn"), "spawner exposes debug_force_spawn")
		_check(filter != null, "spawn filter autoload exists")
		if spawner == null or filter == null:
			_finish()
			return

		filter.set("cap_mode", 0) # PRODUCTION
		var result := spawner.call("debug_force_spawn", 10) as Dictionary
		_check(
			int(result.get("spawned", -1)) == 10,
			"production headroom force-spawns the full request (got %s of 10, alive %s, cap %s)" % [
				result.get("spawned"), result.get("alive"), result.get("cap"),
			]
		)
		_check(int(result.get("cap", 0)) > 0, "production mode reports a positive effective cap")

		filter.set("cap_mode", 2) # UNLIMITED
		var horde := spawner.call("debug_force_spawn", 100) as Dictionary
		_check(
			int(horde.get("spawned", 0)) >= 60,
			"unlimited force-spawn builds a horde (got %s of 100, alive %s)" % [
				horde.get("spawned"), horde.get("alive"),
			]
		)

		filter.set("cap_mode", 1) # CUSTOM
		filter.set("custom_total_cap", 1)
		var capped := spawner.call("debug_force_spawn", 10) as Dictionary
		_check(int(capped.get("spawned", -1)) == 0, "a saturated cap force-spawns nothing")
		_check(
			int(capped.get("cap", 0)) > 0
			and int(capped.get("alive", 0)) + int(capped.get("pending", 0)) >= int(capped.get("cap", 0)),
			"cap saturation is visible in the result (alive %s + pending %s >= cap %s)" % [
				capped.get("alive"), capped.get("pending"), capped.get("cap"),
			]
		)

		filter.set("cap_mode", 0)
		filter.set("custom_total_cap", 180)
		Global.debug_player_god_mode = false
		Global.goto_main_menu()
		_finish()

	func _finish() -> void:
		print("DevForceSpawnTest: %d passed, %d failed" % [_passes, _failures])
		get_tree().quit(1 if _failures > 0 else 0)


func _ready() -> void:
	var driver := Driver.new()
	get_tree().root.add_child.call_deferred(driver)
