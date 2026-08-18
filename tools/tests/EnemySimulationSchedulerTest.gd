extends Node

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
	scheduler.queue_free()
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
