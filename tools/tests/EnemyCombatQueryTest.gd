extends Node

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const WorldScript = preload("res://core/systems/enemy_world/EnemyWorld.gd")
const CombatScript = preload("res://core/systems/enemy_world/EnemyCombatService.gd")

class KnockbackActor:
	extends Node2D
	var received := Vector2.ZERO

	func _apply_enemy_world_knockback(force: Vector2) -> void:
		received += force

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


func _spawn(world: EnemyWorldService, id: StringName, position: Vector2, radius: float = 3.0) -> int:
	return world.create_enemy(SpawnState.new(id, "res://%s.tscn" % String(id), position, 20.0, 100.0, radius, 0))


func _run() -> void:
	var world := WorldScript.new()
	add_child(world)
	var combat := CombatScript.new()
	combat.setup(world)
	add_child(combat)
	var near := _spawn(world, &"near", Vector2(10.0, 0.0), 2.0)
	var dying := _spawn(world, &"dying", Vector2(20.0, 0.0), 8.0)
	var far := _spawn(world, &"far", Vector2(30.0, 0.0), 5.0)
	var side := _spawn(world, &"side", Vector2(10.0, 20.0), 2.0)
	world.set_health(dying, 0.0)
	world.try_begin_death(dying)

	var gathered: Array[int] = []
	combat.gather_in_radius(Vector2.ZERO, 35.0, gathered)
	_check(gathered.has(near) and gathered.has(far) and gathered.has(side), "radius query returns every live handle in range")
	_check(not gathered.has(dying), "radius query filters dying handles")
	combat.gather_in_radius(Vector2.ZERO, 35.0, gathered, near)
	_check(not gathered.has(near) and gathered.has(far), "radius query honors stable-handle exclusion")
	_check(combat.nearest_enemy(Vector2.ZERO, 100.0) == near, "nearest query returns closest live handle")
	_check(combat.nearest_enemy(Vector2.ZERO, 100.0, near) == side, "nearest query skips excluded and dying handles")

	_check(combat.first_enemy_on_segment(Vector2.ZERO, Vector2(40.0, 0.0), 1.0) == near, "segment query finds first exact collision")
	_check(is_equal_approx(combat.last_segment_hit_t(), 0.175), "segment query exposes exact first-hit fraction")
	_check(combat.first_enemy_on_segment(Vector2.ZERO, Vector2(40.0, 0.0), 1.0, near) == far, "segment exclusion advances to next live collision")
	_check(is_equal_approx(combat.last_segment_hit_t(), 0.60), "excluded segment query preserves exact second-hit fraction")

	combat.gather_in_sector(Vector2.ZERO, Vector2.RIGHT, 40.0, 5.0, deg_to_rad(45.0), gathered)
	_check(gathered.has(near) and gathered.has(far), "sector query includes live handles inside wedge")
	_check(not gathered.has(side) and not gathered.has(dying), "sector query rejects off-angle and dying handles")

	_check(combat.apply_knockback(near, Vector2(4.0, 3.0)), "data-only knockback command succeeds")
	_check(world.get_knockback_velocity(near) == Vector2(4.0, 3.0), "data-only knockback persists in world storage")
	var actor := KnockbackActor.new()
	add_child(actor)
	_check(world.bind_actor(far, actor), "knockback fixture binds materialized actor")
	_check(combat.apply_knockback(far, Vector2(-2.0, 6.0)), "materialized knockback command succeeds")
	_check(world.get_knockback_velocity(far) == Vector2(-2.0, 6.0), "materialized knockback remains authoritative")
	_check(actor.received == Vector2(-2.0, 6.0), "materialized actor mirrors authoritative knockback")

	var stale := _spawn(world, &"stale", Vector2(5.0, 0.0))
	world.remove_enemy(stale, &"query_test")
	var replacement := _spawn(world, &"replacement", Vector2(5.0, 0.0))
	_check(not combat.apply_knockback(stale, Vector2.ONE * 99.0), "stale handle knockback is rejected")
	_check(world.get_knockback_velocity(replacement) == Vector2.ZERO, "stale knockback cannot reach reused slot")

	world.clear_world()
	actor.queue_free()
	combat.queue_free()
	world.queue_free()
	await get_tree().process_frame
	print("EnemyCombatQueryTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
