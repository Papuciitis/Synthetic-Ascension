extends Node

const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

class MirrorActor:
	extends Node2D
	var health := 20.0
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


func _spawn_record(id: StringName, position: Vector2, health: float = 20.0) -> int:
	return EnemyWorld.create_enemy(SpawnState.new(id, "res://%s.tscn" % String(id), position, health, 0.0, 5.0, 0))


func _profile(damage: float = 10.0, pierce: int = 0) -> HitProfileAdapter:
	var profile := HitProfileAdapter.new()
	profile.speed = 100.0
	profile.max_range = 200.0
	profile.damage = damage
	profile.collision_radius = 1.0
	profile.pierce = pierce
	return profile


func _run() -> void:
	var manager_script := load("res://core/combat/projectile/ProjectileSimulationManager.gd") as Script
	var manager := manager_script.new() as Node2D
	add_child(manager)
	manager.set_physics_process(false)
	manager.call("_sync_scene_refs")
	var source := Node.new()
	add_child(source)

	var data_only := _spawn_record(&"data_only", Vector2(50.0, 0.0))
	_check(manager.call("spawn_player", Vector2.ZERO, Vector2.RIGHT, _profile(), source), "managed projectile spawns for data-only target")
	manager.call("_simulate_one", 0, 0.60)
	manager.call("_flush_hit_ledgers")
	_check(EnemyWorld.get_health(data_only) == 10.0, "managed projectile damages data-only record")
	_check(int(manager.call("active_count")) == 0, "non-piercing projectile retires after data-only hit")

	EnemyWorld.remove_enemy(data_only, &"test_reset")
	var materialized := _spawn_record(&"materialized", Vector2(30.0, 0.0))
	var actor := MirrorActor.new()
	actor.position = Vector2(30.0, 0.0)
	add_child(actor)
	EnemyWorld.bind_actor(materialized, actor)
	var second := _spawn_record(&"second", Vector2(70.0, 0.0))
	_check(manager.call("spawn_player", Vector2.ZERO, Vector2.RIGHT, _profile(10.0, 1), source), "piercing projectile spawns for mixed representations")
	manager.call("_simulate_one", 0, 0.35)
	manager.call("_flush_hit_ledgers")
	_check(EnemyWorld.get_health(materialized) == 10.0 and actor.health == 10.0, "first piercing hit updates materialized record and mirror")
	_check(int(manager.call("active_count")) == 1, "piercing projectile survives first handle hit")
	manager.call("_simulate_one", 0, 0.40)
	manager.call("_flush_hit_ledgers")
	_check(EnemyWorld.get_health(second) == 10.0, "piercing projectile next damages data-only handle")
	_check(int(manager.call("active_count")) == 0, "piercing projectile retires after its final hit")

	EnemyWorld.remove_enemy(materialized, &"test_reset")
	EnemyWorld.remove_enemy(second, &"test_reset")
	var stale_target := _spawn_record(&"stale_target", Vector2(30.0, 0.0))
	manager.call("spawn_player", Vector2.ZERO, Vector2.RIGHT, _profile(), source)
	manager.call("_simulate_one", 0, 0.35)
	_check((manager.get("_pending_ledgers") as Dictionary).has(stale_target), "pending ledger is keyed by stable handle")
	EnemyWorld.remove_enemy(stale_target, &"before_flush")
	var replacement := _spawn_record(&"replacement", Vector2(30.0, 0.0))
	manager.call("_flush_hit_ledgers")
	_check(EnemyWorld.get_health(replacement) == 20.0, "stale queued hit cannot damage slot replacement")

	manager.call("_clear_all")
	EnemyWorld.remove_enemy(replacement, &"test_cleanup")
	actor.queue_free()
	manager.queue_free()
	await get_tree().process_frame
	print("ProjectileHandleCombatTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)

