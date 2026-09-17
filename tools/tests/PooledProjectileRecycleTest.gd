extends Node

# Regression: a pooled Area2D projectile used to recycle itself synchronously
# from inside its own area_entered emission (PoolManager.recycle -> monitoring
# writes and remove_child while the physics server is flushing queries). That
# raised engine errors every hit, left the reused projectile with a stale
# overlap map, and a projectile touching two hitboxes in one flush damaged
# twice. Pins: one flush -> one hit; the projectile still returns to the pool;
# the reused projectile hits again.

const PROJECTILE_SCENE := preload("res://core/combat/projectile/projectile.tscn")

class FakeEnemy:
	extends Node2D
	var hits := 0

	func take_damage(_amount: float, _source: Node) -> void:
		hits += 1

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


func _make_enemy(at: Vector2) -> FakeEnemy:
	var enemy := FakeEnemy.new()
	enemy.add_to_group(&"enemies")
	enemy.position = at
	var hitbox := Area2D.new()
	hitbox.add_to_group(&"enemy_hitbox")
	hitbox.collision_layer = 2 # projectile.tscn collision_mask = 2
	hitbox.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	hitbox.add_child(shape)
	enemy.add_child(hitbox)
	add_child(enemy)
	return enemy


func _settle() -> void:
	for _i in 4:
		await get_tree().physics_frame
	await get_tree().process_frame


func _run() -> void:
	var pm := get_node_or_null("/root/PoolManager")
	_check(pm != null, "PoolManager autoload is present")
	if pm == null:
		_finish()
		return

	var a := _make_enemy(Vector2(100.0, 0.0))
	var b := _make_enemy(Vector2(104.0, 0.0))
	await get_tree().physics_frame

	var projectile := pm.call("obtain", PROJECTILE_SCENE, self) as Area2D
	_check(projectile != null, "projectile.tscn is obtainable from the pool")
	if projectile == null:
		_finish()
		return
	projectile.global_position = Vector2(102.0, 0.0)
	projectile.set("velocity", Vector2.ZERO)
	await _settle()

	_check(a.hits + b.hits == 1, "two hitboxes in one physics flush produce exactly one hit (got %d)" % (a.hits + b.hits))
	_check(is_instance_valid(projectile) and bool(projectile.get_meta("__in_pool", false)), "projectile is back in the pool after the flush")
	_check(is_instance_valid(projectile) and projectile.get_parent() == pm, "pooled projectile is parked under PoolManager")

	var again := pm.call("obtain", PROJECTILE_SCENE, self) as Area2D
	_check(again == projectile, "pool hands the recycled projectile back out")
	a.hits = 0
	b.hits = 0
	if again != null:
		again.global_position = Vector2(102.0, 0.0)
		again.set("velocity", Vector2.ZERO)
	await _settle()
	_check(a.hits + b.hits == 1, "reused projectile registers its overlap again and hits exactly once (got %d)" % (a.hits + b.hits))
	_check(is_instance_valid(again) and bool(again.get_meta("__in_pool", false)), "reused projectile returns to the pool again")
	_finish()


func _finish() -> void:
	print("PooledProjectileRecycleTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
