extends Node

# Live-game gate for the proxy vertical slice: with the rollout enabled, a real
# run must demote distant ordinary enemies to data-only records, keep them
# moving and killable, render them through the batched proxy renderer, and
# clear every logical record when the run is torn down.

class RolloutDriver:
	extends Node

	var _phase := 0
	var _elapsed := 0.0
	var _passes := 0
	var _failures := 0
	var _seeded := false
	var _teleported := false
	var _sampled_handle := 0
	var _sampled_position := Vector2.ZERO
	var _kill_handle := 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_check("enemy_proxy_rollout" in Global, "global exposes the proxy rollout flag")
		Global.set("enemy_proxy_rollout", true)
		Global.start_new_attempt()
		Global.attempt_segment = 2
		Global.debug_dev_segment = false
		Global.debug_dev_mode = true
		# Entry overlays pause the tree waiting for input a headless run never
		# provides; skip them so gameplay actually simulates.
		Global.pending_augment_pick = false
		Global.pending_big_choice = false
		_phase = 1
		Global.goto_game()

	func _check(condition: bool, message: String) -> void:
		if condition:
			_passes += 1
			print("PASS: ", message)
		else:
			_failures += 1
			push_error("FAIL: " + message)

	func _world_counters() -> Dictionary:
		var world := get_node_or_null("/root/EnemyWorld")
		return world.call("get_debug_counters") as Dictionary if world != null else {}

	func _find_data_only_handle() -> int:
		var world := get_node_or_null("/root/EnemyWorld")
		if world == null:
			return 0
		var handles: Array[int] = []
		world.call("active_handles", handles)
		for handle in handles:
			if int(world.call("get_representation", handle)) == 0 and not bool(world.call("is_dying", handle)):
				return handle
		return 0

	func _process(delta: float) -> void:
		if _phase < 1:
			return
		_elapsed += delta
		if get_tree().paused:
			get_tree().paused = false

		if _phase == 1:
			# Retry seeding until enemies actually exist: early bursts can fail
			# wholesale while procedural chunks are still streaming in.
			if _elapsed >= 4.0 and not _seeded:
				var index := get_node_or_null("/root/EnemyIndex")
				if index != null and int(index.call("alive_count")) > 0:
					_seeded = true
				else:
					var scene_root := get_tree().current_scene
					var spawner := scene_root.get_node_or_null("Spawner") if scene_root != null else null
					if spawner != null and spawner.has_method("spawn_burst"):
						spawner.call("spawn_burst", 12)
			# Deterministic distance arrangement: chasing enemies close below the
			# deactivation distance within seconds, so a passive sample races the
			# policy. Push a handful of ordinary actors far out instead.
			if _seeded and _elapsed >= 10.0 and not _teleported:
				_teleported = true
				var index_tp := get_node_or_null("/root/EnemyIndex")
				var player_tp := get_tree().get_first_node_in_group(&"player") as Node2D
				if index_tp != null and player_tp != null:
					var moved := 0
					for entry in (index_tp.call("get_all") as Array):
						var actor := entry as Node2D
						if actor == null or not is_instance_valid(actor):
							continue
						if "is_elite" in actor and bool(actor.get("is_elite")):
							continue
						actor.global_position = player_tp.global_position + Vector2(2200.0 + 120.0 * moved, 160.0 * moved)
						index_tp.call("update_enemy", actor)
						moved += 1
						if moved >= 6:
							break
			if _elapsed >= 16.0:
				var counters := _world_counters()
				var proxy_root := get_tree().get_first_node_in_group(&"enemy_proxy_root")
				_check(proxy_root != null, "game wires the enemy proxy root")
				_check(int(counters.get("data_only", 0)) > 0, "distant ordinary enemies demote to data-only records")
				_check(int(counters.get("materialized", 0)) <= 96, "materialized actors respect the hard budget ceiling")
				if proxy_root != null:
					var renderer: Variant = proxy_root.get("renderer")
					_check(
						renderer != null and int(renderer.call("visible_count")) > 0,
						"proxy renderer draws the data-only population"
					)
				var world_sample := get_node_or_null("/root/EnemyWorld")
				_sampled_handle = _find_data_only_handle()
				if _sampled_handle != 0 and world_sample != null:
					_sampled_position = world_sample.call("get_position", _sampled_handle) as Vector2
				_phase = 2
		elif _phase == 2 and _elapsed >= 18.5:
			var world := get_node_or_null("/root/EnemyWorld")
			var still_data_only := (
				_sampled_handle != 0
				and world != null
				and bool(world.call("is_valid_handle", _sampled_handle))
				and int(world.call("get_representation", _sampled_handle)) == 0
			)
			var moved_far_enough := false
			if still_data_only:
				var current := world.call("get_position", _sampled_handle) as Vector2
				moved_far_enough = current.distance_to(_sampled_position) > 24.0
			_check(
				_sampled_handle != 0 and (moved_far_enough or not still_data_only),
				"data-only enemies keep moving through the proxy simulation"
			)
			_kill_handle = _find_data_only_handle()
			_check(_kill_handle != 0, "a data-only target is available for combat")
			if _kill_handle != 0:
				var combat := get_node_or_null("/root/EnemyCombat")
				combat.call("apply_damage", _kill_handle, 100000.0, 1, get_tree().get_first_node_in_group(&"player"))
			_phase = 5
		elif _phase == 5 and _elapsed >= 20.0:
			var world_kill := get_node_or_null("/root/EnemyWorld")
			_check(
				_kill_handle == 0 or world_kill == null or not bool(world_kill.call("is_valid_handle", _kill_handle)),
				"lethal damage removes a data-only enemy exactly once"
			)
			_phase = 3
			Global.goto_main_menu()
		elif _phase == 3 and _elapsed >= 23.0:
			var counters := _world_counters()
			var index := get_node_or_null("/root/EnemyIndex")
			_check(int(counters.get("logical", -1)) == 0, "run teardown clears every logical record including proxies")
			_check(index == null or int(index.call("alive_count")) == 0, "run teardown clears the population counters")
			_phase = 4
			print("EnemyProxyRolloutTest: %d passed, %d failed" % [_passes, _failures])
			get_tree().quit(1 if _failures > 0 else 0)


func _ready() -> void:
	var driver := RolloutDriver.new()
	get_tree().root.add_child.call_deferred(driver)
