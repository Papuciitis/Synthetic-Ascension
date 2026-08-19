extends Node

# Full-game soak: launches a real segment-2 run, requires live enemies to
# spawn and close on the player, then verifies scene transitions leave zero
# enemy population behind (Nodes, index entries, and logical world records).
# Guards the pool-warm ghost regression, where warmed pool nodes registered as
# live enemies, filled every spawn cap, and survived scene changes.

class SoakDriver:
	extends Node

	var _phase := 0
	var _elapsed := 0.0
	var _passes := 0
	var _failures := 0
	var _first_run_peak_alive := 0
	var _second_run_peak_alive := 0
	var _first_run_best_distance := INF
	var _seeded_first_run := false
	var _seeded_second_run := false

	func _seed_spawns_if_quiet(population: Dictionary, already_seeded: bool) -> bool:
		# Pre-unseal pacing can legitimately produce zero organic spawns in the
		# first seconds; seed through the real spawner path so the lifecycle
		# assertions stay deterministic without faking construction.
		if already_seeded or int(population["alive"]) > 0:
			return already_seeded
		var scene_root := get_tree().current_scene
		var spawner := scene_root.get_node_or_null("Spawner") if scene_root != null else null
		if spawner != null and spawner.has_method("spawn_burst"):
			spawner.call("spawn_burst", 6)
			return true
		return already_seeded

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		Global.start_new_attempt()
		Global.attempt_segment = 2
		Global.debug_dev_segment = false
		Global.debug_dev_mode = true
		Global.debug_projectile_stress_test = false
		_phase = 1
		Global.goto_game()

	func _check(condition: bool, message: String) -> void:
		if condition:
			_passes += 1
			print("PASS: ", message)
		else:
			_failures += 1
			push_error("FAIL: " + message)

	func _population() -> Dictionary:
		var index := get_node_or_null("/root/EnemyIndex")
		var world := get_node_or_null("/root/EnemyWorld")
		var alive := int(index.call("alive_count")) if index != null else -1
		var logical := int(world.call("active_count")) if world != null else -1
		var pooled_ghosts := 0
		if index != null:
			for entry in (index.call("get_all") as Array):
				if entry != null and is_instance_valid(entry) and bool((entry as Node).get_meta("__in_pool", false)):
					pooled_ghosts += 1
		return {"alive": alive, "logical": logical, "pooled_ghosts": pooled_ghosts}

	func _process(delta: float) -> void:
		if _phase < 1:
			return
		_elapsed += delta
		var population := _population()
		if _phase == 1:
			if _elapsed >= 6.0:
				_seeded_first_run = _seed_spawns_if_quiet(population, _seeded_first_run)
			_first_run_peak_alive = maxi(_first_run_peak_alive, int(population["alive"]))
			var player := get_tree().get_first_node_in_group(&"player") as Node2D
			var combat := get_node_or_null("/root/EnemyCombat")
			var world := get_node_or_null("/root/EnemyWorld")
			if player != null and combat != null and world != null:
				var nearest := int(combat.call("nearest_enemy", player.global_position, 100000.0, 0))
				if nearest != 0:
					var nearest_position := world.call("get_position", nearest) as Vector2
					_first_run_best_distance = minf(
						_first_run_best_distance,
						player.global_position.distance_to(nearest_position)
					)
		elif _phase == 3:
			if _elapsed >= 31.0:
				_seeded_second_run = _seed_spawns_if_quiet(population, _seeded_second_run)
			_second_run_peak_alive = maxi(_second_run_peak_alive, int(population["alive"]))

		if _phase == 1 and _elapsed >= 20.0:
			_check(_first_run_peak_alive > 0, "a real run spawns live enemies")
			_check(int(population["pooled_ghosts"]) == 0, "no pooled ghost is ever registered as alive")
			_check(_first_run_best_distance < 3000.0, "spawned enemies approach the player")
			_phase = 2
			Global.goto_main_menu()
		elif _phase == 2 and _elapsed >= 25.0:
			_check(int(population["alive"]) == 0, "leaving the run clears every indexed enemy")
			_check(int(population["logical"]) == 0, "leaving the run clears every logical world record")
			_phase = 3
			Global.start_new_attempt()
			Global.attempt_segment = 2
			Global.goto_game()
		elif _phase == 3 and _elapsed >= 45.0:
			_check(_second_run_peak_alive > 0, "a second run spawns fresh enemies after teardown")
			_phase = 4
			Global.goto_main_menu()
		elif _phase == 4 and _elapsed >= 49.0:
			var final_population := _population()
			_check(int(final_population["alive"]) == 0 and int(final_population["logical"]) == 0, "final teardown leaves no enemy population")
			_phase = 5
			print("EnemyRunTransitionSoakTest: %d passed, %d failed" % [_passes, _failures])
			get_tree().quit(1 if _failures > 0 else 0)


func _ready() -> void:
	var driver := SoakDriver.new()
	get_tree().root.add_child.call_deferred(driver)
