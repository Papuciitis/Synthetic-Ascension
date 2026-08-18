extends Node

class ScheduledProbe:
	extends Node2D
	var dead := false
	var assigned_tier := 0
	var scheduled_deltas: Array[float] = []

	func set_scheduler_tier(tier: int) -> void:
		assigned_tier = tier

	func simulation_tier() -> int:
		return assigned_tier

	func run_scheduled_simulation(delta: float) -> void:
		scheduled_deltas.append(delta)

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var live_scheduler := get_node_or_null("/root/EnemySimulationScheduler")
	if live_scheduler != null:
		live_scheduler.set_physics_process(false)
	var scheduler_script := load("res://autoload/EnemySimulationScheduler.gd") as Script
	_check(scheduler_script != null, "enemy simulation scheduler script exists")
	if scheduler_script == null:
		_finish()
		return
	var scheduler := scheduler_script.new() as Node
	add_child(scheduler)
	_test_500_actor_budget(scheduler)
	_test_protected_actors_do_not_consume_ambient_budget(scheduler)
	_test_previous_full_actor_wins_equal_priority_tie(scheduler)
	await _test_enemy_tier_transitions()
	await _test_ambient_elites_and_smart_enemies_remain_budgeted(scheduler)
	_test_rotating_reduced_tick_groups(scheduler_script)
	_test_pooled_actor_stale_group_is_ignored(scheduler_script)
	scheduler.queue_free()
	if live_scheduler != null:
		live_scheduler.set_physics_process(true)
	_finish()


func _test_500_actor_budget(scheduler: Node) -> void:
	scheduler.set("full_budget", 32)
	scheduler.set("mid_budget", 48)
	var enemies: Array = []
	for index in range(500):
		var enemy := Node2D.new()
		enemy.position = Vector2(float(index + 1), 0.0)
		add_child(enemy)
		enemies.append(enemy)
	var assignment := scheduler.call("compute_assignment", enemies, Vector2.ZERO) as Dictionary
	_check(assignment.size() == 500, "500-actor assignment loses no enemies")
	_check(_tier_count(assignment, 0) == 32, "full tier obeys hard ambient budget")
	_check(_tier_count(assignment, 1) == 48, "mid tier obeys hard ambient budget")
	_check(_tier_count(assignment, 2) == 420, "remaining actors become far proxies")
	_free_nodes(enemies)


func _test_protected_actors_do_not_consume_ambient_budget(scheduler: Node) -> void:
	scheduler.set("full_budget", 2)
	scheduler.set("mid_budget", 1)
	var enemies: Array = []
	for index in range(6):
		var enemy := Node2D.new()
		enemy.position = Vector2(float(index + 1) * 10.0, 0.0)
		add_child(enemy)
		enemies.append(enemy)
	(enemies[4] as Node).set_meta(&"objective_required", true)
	(enemies[5] as Node).add_to_group(&"boss_like")
	var assignment := scheduler.call("compute_assignment", enemies, Vector2.ZERO) as Dictionary
	var ordinary_full := 0
	for index in range(4):
		if int(assignment.get((enemies[index] as Node).get_instance_id(), -1)) == 0:
			ordinary_full += 1
	_check(ordinary_full == 2, "protected actors do not consume ordinary full budget")
	_check(int(assignment.get((enemies[4] as Node).get_instance_id(), -1)) == 0, "objective actor remains full")
	_check(int(assignment.get((enemies[5] as Node).get_instance_id(), -1)) == 0, "boss actor remains full")
	_check(assignment.size() == 6, "protected assignment keeps every actor")
	_free_nodes(enemies)


func _test_previous_full_actor_wins_equal_priority_tie(scheduler: Node) -> void:
	scheduler.set("full_budget", 1)
	scheduler.set("mid_budget", 0)
	var incumbent := Node2D.new()
	var challenger := Node2D.new()
	incumbent.position = Vector2(10.0, 0.0)
	challenger.position = Vector2(20.0, 0.0)
	add_child(incumbent)
	add_child(challenger)
	var first := scheduler.call("compute_assignment", [incumbent, challenger], Vector2.ZERO) as Dictionary
	_check(int(first.get(incumbent.get_instance_id(), -1)) == 0, "closest actor initially receives full simulation")
	challenger.position = incumbent.position
	var second := scheduler.call("compute_assignment", [incumbent, challenger], Vector2.ZERO) as Dictionary
	_check(int(second.get(incumbent.get_instance_id(), -1)) == 0, "previous full actor wins an equal-priority tie")
	incumbent.queue_free()
	challenger.queue_free()


func _test_enemy_tier_transitions() -> void:
	var enemy_scene := load("res://core/actors/enemy/enemy.tscn") as PackedScene
	var enemy := enemy_scene.instantiate() as EnemyActor
	add_child(enemy)
	await get_tree().process_frame
	_check(enemy.has_method("set_scheduler_tier"), "enemy exposes atomic scheduler tier transitions")
	_check(enemy.has_method("run_scheduled_simulation"), "enemy exposes manager-driven simulation")
	_check(enemy.has_method("is_body_physics_enabled"), "enemy exposes observable body physics state")
	_check(enemy.has_method("hitbox_roles"), "enemy exposes independent hitbox roles")
	if not enemy.has_method("set_scheduler_tier"):
		enemy.queue_free()
		return
	enemy.call("set_scheduler_tier", 2)
	await get_tree().physics_frame
	_check(not enemy.is_physics_processing(), "far actor has no individual physics callback")
	_check(not bool(enemy.call("is_body_physics_enabled")), "far actor leaves body physics")
	_check(enemy.call("hitbox_roles") == {"monitoring": false, "monitorable": false}, "far hitbox leaves broadphase")
	enemy.call("set_scheduler_tier", 1)
	await get_tree().physics_frame
	var mid_roles := enemy.call("hitbox_roles") as Dictionary
	_check(not enemy.is_physics_processing(), "mid actor is manager scheduled")
	_check(bool(enemy.call("is_body_physics_enabled")), "mid actor retains reduced world collision")
	_check(bool(mid_roles.get("monitorable", false)), "mid actor remains hittable")
	_check(not bool(mid_roles.get("monitoring", true)), "ordinary mid actor does not actively monitor")
	enemy.call("set_scheduler_tier", 0)
	await get_tree().physics_frame
	_check(enemy.is_physics_processing(), "full actor restores individual physics callback")
	_check(not bool((enemy.call("hitbox_roles") as Dictionary).get("monitoring", true)), "ordinary full actor avoids active monitoring")
	_check(enemy.has_method("is_simulation_protected"), "enemy exposes scheduler protection policy")
	enemy.set_meta(&"objective_required", true)
	if enemy.has_method("is_simulation_protected"):
		_check(bool(enemy.call("is_simulation_protected", 5000.0)), "objective actor is protected from reduced simulation")
	enemy.queue_free()

	var leech := enemy_scene.instantiate() as EnemyActor
	var leech_spec := EnemySpec.new()
	leech_spec.ai = EnemySpec.AI.LEECH
	leech.spec = leech_spec
	add_child(leech)
	await get_tree().process_frame
	if leech.has_method("set_scheduler_tier"):
		leech.call("set_scheduler_tier", 1)
		await get_tree().physics_frame
		_check(bool((leech.call("hitbox_roles") as Dictionary).get("monitoring", false)), "leech keeps active contact monitoring in mid tier")
	leech.queue_free()


func _test_rotating_reduced_tick_groups(scheduler_script: Script) -> void:
	var index := get_node("/root/EnemyIndex")
	var scheduler := scheduler_script.new() as Node
	scheduler.set("full_budget", 0)
	scheduler.set("mid_budget", 1)
	scheduler.set("assignment_interval", 0.20)
	scheduler.set("mid_group_count", 2)
	scheduler.set("far_group_count", 6)
	add_child(scheduler)
	var mid_probe := ScheduledProbe.new()
	var far_probe := ScheduledProbe.new()
	mid_probe.position = Vector2(10.0, 0.0)
	far_probe.position = Vector2(100.0, 0.0)
	add_child(mid_probe)
	add_child(far_probe)
	index.call("register", mid_probe)
	index.call("register", far_probe)
	for _frame in range(12):
		scheduler.call("_physics_process", 1.0 / 60.0)
	_check(mid_probe.assigned_tier == 1, "closest budgeted probe is assigned mid tier")
	_check(far_probe.assigned_tier == 2, "remaining probe is assigned far tier")
	_check(mid_probe.scheduled_deltas.size() == 6, "mid group runs six times across twelve physics frames")
	_check(far_probe.scheduled_deltas.size() == 2, "far group runs twice across twelve physics frames")
	if not mid_probe.scheduled_deltas.is_empty():
		_check(is_equal_approx(mid_probe.scheduled_deltas[0], 2.0 / 60.0), "mid step receives accumulated fixed delta")
	if not far_probe.scheduled_deltas.is_empty():
		_check(is_equal_approx(far_probe.scheduled_deltas[0], 6.0 / 60.0), "far step receives accumulated fixed delta")
	index.call("unregister", mid_probe)
	index.call("unregister", far_probe)
	mid_probe.queue_free()
	far_probe.queue_free()
	scheduler.queue_free()


func _test_ambient_elites_and_smart_enemies_remain_budgeted(scheduler: Node) -> void:
	scheduler.set("full_budget", 3)
	scheduler.set("mid_budget", 4)
	var enemy_scene := load("res://core/actors/enemy/enemy.tscn") as PackedScene
	var enemies: Array = []
	for index in range(6):
		var elite := enemy_scene.instantiate() as EnemyActor
		elite.position = Vector2(float(index + 1) * 10.0, 0.0)
		add_child(elite)
		elite.is_elite = true
		enemies.append(elite)
	for index in range(6):
		var ranged := enemy_scene.instantiate() as EnemyActor
		var ranged_spec := EnemySpec.new()
		ranged_spec.ai = EnemySpec.AI.RANGED
		ranged.spec = ranged_spec
		ranged.position = Vector2(float(index + 7) * 10.0, 0.0)
		add_child(ranged)
		enemies.append(ranged)
	await get_tree().process_frame
	var assignment := scheduler.call("compute_assignment", enemies, Vector2.ZERO) as Dictionary
	var counters := scheduler.call("get_debug_counters") as Dictionary
	_check(int(counters.get("protected", -1)) == 0, "ambient elites and smart archetypes do not bypass the hard budget")
	_check(_tier_count(assignment, 0) == 3, "mixed ambient horde still obeys full budget")
	_check(_tier_count(assignment, 1) == 4, "mixed ambient horde still obeys mid budget")
	_check(_tier_count(assignment, 2) == 5, "mixed ambient overflow becomes far simulation")
	_free_nodes(enemies)


func _test_pooled_actor_stale_group_is_ignored(scheduler_script: Script) -> void:
	var index := get_node("/root/EnemyIndex")
	var scheduler := scheduler_script.new() as Node
	scheduler.set("full_budget", 0)
	scheduler.set("mid_budget", 1)
	scheduler.set("mid_group_count", 1)
	add_child(scheduler)
	var probe := ScheduledProbe.new()
	add_child(probe)
	index.call("register", probe)
	scheduler.call("_physics_process", 1.0 / 60.0)
	var calls_before_pooling := probe.scheduled_deltas.size()
	probe.set_meta("__in_pool", true)
	probe.process_mode = Node.PROCESS_MODE_DISABLED
	scheduler.call("_physics_process", 1.0 / 60.0)
	_check(probe.scheduled_deltas.size() == calls_before_pooling, "stale reduced group never simulates an inactive pooled actor")
	index.call("unregister", probe)
	probe.queue_free()
	scheduler.queue_free()


func _tier_count(assignment: Dictionary, tier: int) -> int:
	var count := 0
	for value in assignment.values():
		if int(value) == tier:
			count += 1
	return count


func _free_nodes(nodes: Array) -> void:
	for node_variant in nodes:
		var node := node_variant as Node
		if node != null:
			node.queue_free()


func _finish() -> void:
	print("EnemySimulationSchedulerTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
