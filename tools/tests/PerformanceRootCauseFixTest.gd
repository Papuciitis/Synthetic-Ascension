extends Node

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	_test_flow_coalescing()
	_test_scheduler_tier_contract()
	_test_projectile_query_contract()
	_test_chunk_queue_contract()
	print("PerformanceRootCauseFixTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_flow_coalescing() -> void:
	var flow := FlowFieldNav.new()
	add_child(flow)
	flow.set("_has_requested", true)
	flow.set("_building", true)
	flow.set("_last_nav_revision", 7)
	flow.call("_request_rebuild", Vector2i(10, 10), 7, &"player_moved", true)
	_check(bool(flow.get("_building")), "player movement keeps active flow build alive")
	_check(bool(flow.get("_pending")), "latest flow destination remains queued")
	flow.queue_free()


func _test_scheduler_tier_contract() -> void:
	# The old population-LOD layer had no production callers; production tiers are
	# owned by EnemySimulationScheduler and bounded by max_scheduler_tier. These
	# assertions target the live path so they fail if production regresses.
	var enemy_scene := load("res://core/actors/enemy/enemy.tscn") as PackedScene
	var enemy := enemy_scene.instantiate() as EnemyActor
	_check(not enemy.has_method("compute_population_lod_tier"), "dead population LOD layer is removed")
	_check(not enemy.has_method("should_run_reduced_step"), "dead reduced-step scheduler is removed")
	_check(enemy.has_method("max_scheduler_tier"), "enemy exposes maximum demotion tier")
	_check(enemy.has_method("run_scheduled_simulation"), "enemy exposes manager-driven simulation")
	if enemy.has_method("max_scheduler_tier"):
		_check(int(enemy.call("max_scheduler_tier")) == 2, "plain ambient enemy may become a far proxy")
		enemy.is_elite = true
		_check(int(enemy.call("max_scheduler_tier")) == 1, "elite never loses world collision")
		enemy.is_elite = false
		var sniper_spec := EnemySpec.new()
		sniper_spec.ai = EnemySpec.AI.SNIPER
		enemy.spec = sniper_spec
		_check(int(enemy.call("max_scheduler_tier")) == 1, "sniper never loses world collision")
	enemy.free()


func _test_projectile_query_contract() -> void:
	var manager_script := load("res://core/combat/projectile/ProjectileSimulationManager.gd") as Script
	var manager: Node = manager_script.new()
	_check(manager.has_method("_query_first_enemy_hit"), "projectile manager exposes allocation-free enemy query")
	_check(manager.has_method("debug_last_enemy_hit"), "projectile query exposes reusable hit result for verification")
	add_child(manager)
	var index := get_node("/root/EnemyIndex")
	var near_enemy := Node2D.new()
	var far_enemy := Node2D.new()
	near_enemy.position = Vector2(30, 0)
	far_enemy.position = Vector2(70, 0)
	add_child(near_enemy)
	add_child(far_enemy)
	index.call("register", near_enemy)
	index.call("register", far_enemy)
	manager.set("_enemy_index", index)
	_check(bool(manager.call("_query_first_enemy_hit", Vector2.ZERO, Vector2(100, 0), 0.0, 0)), "projectile query finds an enemy")
	_check((manager.call("debug_last_enemy_hit") as Dictionary).get("target") == near_enemy, "projectile query selects nearest exact hit")
	_check(bool(manager.call("_query_first_enemy_hit", Vector2.ZERO, Vector2(100, 0), 0.0, near_enemy.get_instance_id())), "projectile exclusion still permits later hit")
	_check((manager.call("debug_last_enemy_hit") as Dictionary).get("target") == far_enemy, "projectile exclusion preserves piercing order")
	index.call("unregister", near_enemy)
	index.call("unregister", far_enemy)
	near_enemy.queue_free()
	far_enemy.queue_free()
	manager.queue_free()


func _test_chunk_queue_contract() -> void:
	var manager := ChunkManager.new()
	_check(manager.has_method("queue_missing_chunks"), "chunk manager exposes bounded generation queue")
	_check(manager.has_method("process_chunk_generation_queue"), "chunk manager exposes per-frame generation budget")
	_check(manager.has_method("debug_chunk_queue"), "chunk manager exposes queue ordering diagnostics")
	manager.ground_enabled = false
	manager.generation_enabled = false
	manager.load_radius = 1
	add_child(manager)
	manager.set("_current_center", Vector2i(5, 5))
	manager.call("queue_missing_chunks", Vector2i(5, 5))
	var queued := manager.call("debug_chunk_queue") as Array
	_check(not queued.is_empty() and queued[0] == Vector2i(5, 5), "chunk queue orders center first")
	var before := queued.size()
	var generated := int(manager.call("process_chunk_generation_queue", 1))
	_check(generated == 1 and (manager.call("debug_chunk_queue") as Array).size() == before - 1, "chunk queue obeys one-chunk budget")
	manager.queue_free()
