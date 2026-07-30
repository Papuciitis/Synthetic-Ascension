extends SceneTree

var _passes := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var script := load("res://autoload/DebugEnemySpawnFilter.gd") as Script
	_check(script != null, "spawn filter model exists")
	if script == null:
		_finish()
		return

	var filter: Node = script.new() as Node
	root.add_child(filter)
	_check(filter.has_method("is_enemy_enabled"), "filter exposes archetype checks")
	_check(filter.has_method("effective_total_cap"), "filter exposes total cap resolution")
	_check(filter.has_method("effective_type_cap"), "filter exposes per-type cap resolution")
	_check(filter.has_method("is_node_enabled"), "filter exposes direct-spawn node checks")

	_check(int(filter.call("effective_total_cap", 220)) == 220, "production total cap is preserved")
	_check(int(filter.call("effective_type_cap", &"enemy_grunt", 80)) == 80, "production type cap is preserved")

	filter.set("cap_mode", 1)
	filter.set("custom_total_cap", 180)
	filter.call("set_custom_type_cap", &"enemy_grunt", 0)
	_check(int(filter.call("effective_total_cap", 220)) == 180, "custom total cap is applied")
	_check(int(filter.call("effective_type_cap", &"enemy_grunt", 80)) == 0, "zero custom type cap means unlimited")

	filter.set("cap_mode", 2)
	_check(int(filter.call("effective_total_cap", 220)) == 0, "unlimited mode removes total cap")
	_check(int(filter.call("effective_type_cap", &"enemy_grunt", 80)) == 0, "unlimited mode removes type cap")

	filter.call("register_enemy_id", &"enemy_grunt")
	filter.call("register_enemy_id", &"enemy_sniper")
	filter.call("isolate_enemy", &"enemy_sniper")
	_check(not bool(filter.call("is_enemy_enabled", &"enemy_grunt", false)), "isolation disables other archetypes")
	_check(bool(filter.call("is_enemy_enabled", &"enemy_sniper", false)), "isolation keeps selected archetype enabled")
	_check(int(filter.get("cap_mode")) == 1, "isolation switches to Custom cap mode")
	_check(int(filter.call("effective_type_cap", &"enemy_sniper", 2)) == 0, "isolated archetype bypasses production cap")

	filter.call("set_enemy_enabled", &"enemy_sniper", false)
	_check(not bool(filter.call("is_enemy_enabled", &"enemy_sniper", false)), "disabled ordinary archetype is rejected")
	_check(bool(filter.call("is_enemy_enabled", &"enemy_sniper", true)), "protected actor survives ordinary filtering")
	filter.set("filter_protected_actors", true)
	_check(not bool(filter.call("is_enemy_enabled", &"enemy_sniper", true)), "protected actor obeys explicit protected filtering")
	filter.set("filter_protected_actors", false)
	filter.call("set_enemy_enabled", &"enemy_grunt", true)
	_check(filter.get("spawning_enabled") != null, "filter exposes a master spawning state")
	filter.set("spawning_enabled", false)
	_check(not bool(filter.call("is_enemy_enabled", &"enemy_grunt", false)), "master spawning blocks ordinary direct spawns")
	_check(bool(filter.call("is_enemy_enabled", &"enemy_grunt", true)), "master spawning preserves protected actors by default")
	filter.set("spawning_enabled", true)

	var direct_enemy := Node.new()
	direct_enemy.set_meta("enemy_id", &"enemy_sniper")
	_check(not bool(filter.call("is_node_enabled", direct_enemy)), "direct enemy-created spawn uses the same disabled ID")
	direct_enemy.free()

	var enemy_index := root.get_node_or_null("EnemyIndex")
	if enemy_index != null:
		filter.call("set_enemy_enabled", &"enemy_grunt", true)
		var live_enemy := Node2D.new()
		live_enemy.set_meta("enemy_id", &"enemy_grunt")
		live_enemy.add_to_group(&"enemies")
		root.add_child(live_enemy)
		enemy_index.call("register", live_enemy)
		filter.call("set_enemy_enabled", &"enemy_grunt", false)
		await process_frame
		_check(not is_instance_valid(live_enemy), "disabling an archetype retires its existing live enemies")

	filter.queue_free()
	var spawner_script := load("res://core/systems/spawner/spawner.gd") as Script
	_check(spawner_script != null, "canonical spawner script loads")
	if spawner_script != null:
		var spawner := spawner_script.new() as Node
		spawner.set("spawn_table", load("res://data/enemies/spawn/SpawnTable_Default.tres"))
		root.add_child(spawner)
		await process_frame
		_check(spawner.has_method("_pick_enabled_entry"), "ambient selection filters disabled archetypes before weighted choice")
		_check(spawner.has_method("_remaining_total_capacity"), "spawner supports unlimited debug capacity")
		var global_filter := root.get_node_or_null("DebugEnemySpawnFilter")
		if global_filter != null:
			global_filter.set("cap_mode", 0)
			_check(int(spawner.call("_current_alive_cap")) == 180, "production table total cap remains 180")
			global_filter.set("cap_mode", 1)
			global_filter.set("custom_total_cap", 333)
			_check(int(spawner.call("_current_alive_cap")) == 333, "custom total cap reaches canonical spawner")
			global_filter.set("cap_mode", 2)
			_check(int(spawner.call("_current_alive_cap")) == 0, "unlimited mode reaches canonical spawner")
			global_filter.set("cap_mode", 0)
		spawner.queue_free()
	_finish()


func _finish() -> void:
	print("SpawnFilterTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
