extends Node

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const WorldScript = preload("res://core/systems/enemy_world/EnemyWorld.gd")
const PolicyScript = preload("res://core/systems/enemy_world/EnemyRepresentationPolicy.gd")

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


func _spawn(world: Node, id: StringName, position: Vector2, ai_kind: int = 0, flags: int = 0, materialized: bool = false) -> int:
	var handle := int(world.call("create_enemy", SpawnState.new(
		id,
		"res://%s.tscn" % String(id),
		position,
		20.0,
		75.0,
		8.0,
		ai_kind,
		flags,
	)))
	if materialized:
		world.call("set_representation", handle, Types.Representation.MATERIALIZED)
	return handle


func _evaluate(policy: RefCounted, world: Node, promotions: Array[int], demotions: Array[int]) -> Dictionary:
	return policy.call("evaluate", world, Vector2.ZERO, promotions, demotions) as Dictionary


func _run() -> void:
	var policy := PolicyScript.new()
	policy.set("materialized_budget", 500)
	_check(int(policy.call("effective_budget")) == 96, "materialized budget clamps to the hard 96 ceiling")

	var world := WorldScript.new()
	add_child(world)
	policy.set("materialized_budget", 3)
	policy.set("max_promotions_per_step", 1)
	var critical := _spawn(world, &"critical", Vector2(2000.0, 0.0), 0, Types.Flags.CRITICAL | Types.Flags.NEVER_RETIRE)
	var elite := _spawn(world, &"elite", Vector2(80.0, 0.0), 0, Types.Flags.ELITE)
	var smart := _spawn(world, &"smart", Vector2(60.0, 0.0), 2)
	var ordinary := _spawn(world, &"ordinary", Vector2(20.0, 0.0))
	var promotions: Array[int] = []
	var demotions: Array[int] = []
	_evaluate(policy, world, promotions, demotions)
	_check(promotions.has(critical), "critical record promotes regardless of distance")
	_check(promotions.has(elite) and promotions.has(smart), "elite and smart records remain fully materialized in the chase slice")
	_check(not promotions.has(ordinary), "required actors consume the hard budget before ambient promotion")
	_check(promotions.size() == 3, "required promotions bypass ordinary churn but respect the hard budget")
	world.queue_free()
	await get_tree().process_frame

	world = WorldScript.new()
	add_child(world)
	policy = PolicyScript.new()
	policy.set("materialized_budget", 8)
	policy.set("activation_distance", 480.0)
	policy.set("deactivation_distance", 640.0)
	var hysteresis_actor := _spawn(world, &"hysteresis_actor", Vector2(550.0, 0.0), 0, 0, true)
	var hysteresis_proxy := _spawn(world, &"hysteresis_proxy", Vector2(550.0, 0.0))
	var far_actor := _spawn(world, &"far_actor", Vector2(700.0, 0.0), 0, 0, true)
	promotions.clear()
	demotions.clear()
	_evaluate(policy, world, promotions, demotions)
	_check(not demotions.has(hysteresis_actor), "materialized actor stays active inside deactivation hysteresis")
	_check(not promotions.has(hysteresis_proxy), "data-only record stays proxy outside activation hysteresis")
	_check(demotions.has(far_actor), "ordinary actor beyond deactivation distance becomes a demotion candidate")
	world.queue_free()
	await get_tree().process_frame

	world = WorldScript.new()
	add_child(world)
	policy = PolicyScript.new()
	policy.set("materialized_budget", 2)
	policy.set("max_demotions_per_step", 1)
	var near_actor := _spawn(world, &"near_actor", Vector2(100.0, 0.0), 0, 0, true)
	var middle_actor := _spawn(world, &"middle_actor", Vector2(200.0, 0.0), 0, 0, true)
	var far_budget_actor := _spawn(world, &"far_budget_actor", Vector2(300.0, 0.0), 0, 0, true)
	promotions.clear()
	demotions.clear()
	_evaluate(policy, world, promotions, demotions)
	_check(demotions == [far_budget_actor], "over-budget policy demotes the farthest eligible actor first")
	_check(not demotions.has(near_actor) and not demotions.has(middle_actor), "bounded demotion preserves nearer actors")
	world.queue_free()
	await get_tree().process_frame

	world = WorldScript.new()
	add_child(world)
	policy = PolicyScript.new()
	policy.set("materialized_budget", 8)
	policy.set("max_promotions_per_step", 2)
	var nearest_proxy := _spawn(world, &"nearest_proxy", Vector2(30.0, 0.0))
	var second_proxy := _spawn(world, &"second_proxy", Vector2(60.0, 0.0))
	_spawn(world, &"third_proxy", Vector2(90.0, 0.0))
	promotions.clear()
	demotions.clear()
	var counters := _evaluate(policy, world, promotions, demotions)
	_check(promotions == [nearest_proxy, second_proxy], "ordinary promotions are nearest-first and bounded per step")
	_check(int(counters.get("projected_materialized", -1)) == 2, "policy reports projected budget occupancy")

	world.queue_free()
	await get_tree().process_frame
	print("EnemyRepresentationPolicyTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
