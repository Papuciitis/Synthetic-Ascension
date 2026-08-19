extends Node

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const WorldScript = preload("res://core/systems/enemy_world/EnemyWorld.gd")
const CombatScript = preload("res://core/systems/enemy_world/EnemyCombatService.gd")
const StatusScript = preload("res://core/systems/enemy_world/EnemyStatusService.gd")

class MirrorActor:
	extends Node2D
	var health := 50.0
	var deaths := 0

	func _apply_enemy_world_health(current_health: float, _maximum_health: float) -> void:
		health = current_health

	func _apply_enemy_world_damage_feedback(_damage: float, _source: Node, _payload: Variant) -> void:
		pass

	func _apply_enemy_world_death(_context: RefCounted) -> void:
		deaths += 1

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


func _spawn(world: EnemyWorldService, id: StringName, health: float = 50.0) -> int:
	return world.create_enemy(SpawnState.new(id, "res://%s.tscn" % String(id), Vector2.ZERO, health, 0.0, 4.0, 0))


func _run() -> void:
	var world := WorldScript.new()
	add_child(world)
	var combat := CombatScript.new()
	combat.setup(world)
	add_child(combat)
	var status := StatusScript.new()
	status.setup(world, combat)
	add_child(status)
	status.set_physics_process(false)

	var data_only := _spawn(world, &"data_only")
	_check(status.apply_burn(data_only, 2, 5.0, 0.5, 1.0), "burn schedule accepts data-only handle")
	status.advance(0.1)
	_check(world.get_health(data_only) == 48.0, "new burn ticks responsively on data-only target")
	_check(status.apply_bleed(data_only, 1, 5.0, 0.5, 1.0), "bleed schedule coexists on same handle")
	status.advance(0.5)
	_check(world.get_health(data_only) == 45.0, "central step ticks simultaneous burn and bleed")
	_check(status.apply_burn(data_only, 1, 8.0, 0.5, 3.0), "burn refresh succeeds")
	status.advance(0.5)
	_check(world.get_health(data_only) == 38.0, "burn refresh keeps maximum stacks and updates tick damage")
	_check(status.active_status_count() == 2, "one handle owns one schedule per status kind")

	var materialized := _spawn(world, &"materialized")
	var actor := MirrorActor.new()
	add_child(actor)
	world.bind_actor(materialized, actor)
	status.apply_burn(materialized, 2, 5.0, 0.5, 2.0)
	status.advance(0.1)
	_check(world.get_health(materialized) == 46.0 and actor.health == 46.0, "materialized and data-only status damage use identical authority")

	var lethal := _spawn(world, &"lethal", 3.0)
	status.apply_bleed(lethal, 1, 5.0, 0.5, 5.0)
	status.advance(0.1)
	_check(world.is_dying(lethal), "lethal central status tick uses exact-once world death")
	_check(not status.has_status(lethal, &"bleed"), "lethal tick removes remaining status schedule")

	var stale := _spawn(world, &"stale")
	status.apply_burn(stale, 3, 5.0, 0.5, 4.0)
	world.remove_enemy(stale, &"status_test")
	var replacement := _spawn(world, &"replacement")
	status.advance(1.0)
	_check(world.get_health(replacement) == 50.0, "stale status cannot damage reused slot generation")
	_check(not status.has_status(stale, &"burn"), "stale schedule is pruned safely")

	var expiring := _spawn(world, &"expiring")
	status.apply_burn(expiring, 1, 0.2, 0.5, 10.0)
	status.advance(0.2)
	_check(world.get_health(expiring) == 50.0 and not status.has_status(expiring, &"burn"), "status expiring at the boundary does not tick late")
	_check(not status.apply_burn(Types.INVALID_HANDLE, 1, 1.0, 0.5, 1.0), "invalid handle cannot receive status")

	world.clear_world()
	status.clear_all()
	actor.queue_free()
	status.queue_free()
	combat.queue_free()
	world.queue_free()
	await get_tree().process_frame
	print("EnemyStatusServiceTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)

