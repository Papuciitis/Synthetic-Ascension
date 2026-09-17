extends Node

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const WorldScript = preload("res://core/systems/enemy_world/EnemyWorld.gd")

class DummyEnemy:
	extends Node2D
	var hp := 40.0
	var max_hp := 50.0
	var speed := 120.0
	var velocity := Vector2(3.0, 4.0)
	var dead := false
	var is_elite := false
	var spec: Resource = null

	func _get_active_ai() -> int:
		return 3

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


func _state(id: StringName, position: Vector2) -> EnemySpawnState:
	return SpawnState.new(id, "res://%s.tscn" % String(id), position, 50.0, 120.0, 20.0, 0)


func _run() -> void:
	var world := WorldScript.new()
	add_child(world)
	var first: int = world.create_enemy(_state(&"first", Vector2.ZERO))
	var second: int = world.create_enemy(_state(&"second", Vector2(100.0, 0.0)))
	var actor_one := DummyEnemy.new()
	var actor_two := DummyEnemy.new()
	add_child(actor_one)
	add_child(actor_two)

	_check(world.bind_actor(first, actor_one), "valid handle binds an actor")
	_check(world.get_representation(first) == Types.Representation.MATERIALIZED, "binding marks the record materialized")
	_check(world.actor_for_handle(first) == actor_one, "handle resolves its bound actor")
	_check(world.handle_for_actor(actor_one) == first, "actor resolves its bound handle")
	_check(not world.bind_actor(first, actor_two), "occupied handle rejects another actor")
	_check(not world.bind_actor(second, actor_one), "bound actor rejects another handle")
	_check(not world.unbind_actor(first, actor_two), "wrong actor cannot unbind a handle")
	_check(world.actor_for_handle(first) == actor_one, "failed unbind preserves the binding")
	_check(world.unbind_actor(first, actor_one), "matching actor unbinds successfully")
	_check(world.actor_for_handle(first) == null, "unbound handle has no actor")
	_check(world.handle_for_actor(actor_one) == Types.INVALID_HANDLE, "unbound actor has no handle")
	_check(world.get_representation(first) == Types.Representation.DATA_ONLY, "unbinding restores data-only representation")

	_check(world.bind_actor(first, actor_one), "actor can bind again after clean unbind")
	actor_one.free()
	_check(world.prune_invalid_bindings() == 1, "pruning removes an externally freed actor")
	_check(world.actor_for_handle(first) == null, "freed actor lookup returns null")
	_check(world.get_representation(first) == Types.Representation.DATA_ONLY, "freed actor dematerializes its record")

	_check(world.bind_actor(second, actor_two), "second actor binds before record removal")
	_check(world.remove_enemy(second, &"bound_remove"), "bound record can be removed")
	_check(world.handle_for_actor(actor_two) == Types.INVALID_HANDLE, "record removal clears reverse actor binding")
	_check(world.actor_for_handle(second) == null, "stale handle cannot resolve an actor")

	var legacy := DummyEnemy.new()
	legacy.name = "EnemyLegacyFixture"
	legacy.global_position = Vector2(12.0, 34.0)
	legacy.is_elite = true
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = 17.0
	collision.shape = circle
	legacy.add_child(collision)
	add_child(legacy)
	var before_adopt := world.active_count()
	var legacy_handle: int = world.adopt_legacy_actor(legacy)
	_check(legacy_handle != Types.INVALID_HANDLE, "legacy actor adoption creates a handle")
	_check(world.active_count() == before_adopt + 1, "legacy adoption creates one record")
	_check(world.actor_for_handle(legacy_handle) == legacy, "legacy actor is weakly bound")
	_check(world.get_position(legacy_handle) == Vector2(12.0, 34.0), "legacy adoption copies position")
	_check(world.get_velocity(legacy_handle) == Vector2(3.0, 4.0), "legacy adoption copies velocity")
	_check(world.get_health(legacy_handle) == 40.0, "legacy adoption copies current health")
	_check(world.get_max_health(legacy_handle) == 50.0, "legacy adoption copies maximum health")
	_check(world.get_speed(legacy_handle) == 120.0, "legacy adoption copies speed")
	_check(world.get_collision_radius(legacy_handle) == 17.0, "legacy adoption reads circle collision radius")
	_check(world.get_ai_kind(legacy_handle) == 3, "legacy adoption copies active AI kind")
	_check(Types.has_flag(world.get_flags(legacy_handle), Types.Flags.ELITE), "legacy adoption copies elite state")

	legacy.global_position = Vector2(44.0, 55.0)
	legacy.velocity = Vector2(-8.0, 2.0)
	legacy.hp = 12.0
	legacy.is_elite = false
	legacy.dead = true
	_check(world.sync_legacy_actor(legacy), "legacy actor synchronizes after mutation")
	_check(world.get_position(legacy_handle) == Vector2(44.0, 55.0), "legacy sync updates position")
	_check(world.get_velocity(legacy_handle) == Vector2(-8.0, 2.0), "legacy sync updates velocity")
	_check(world.get_health(legacy_handle) == 12.0, "legacy sync updates health")
	_check(not Types.has_flag(world.get_flags(legacy_handle), Types.Flags.ELITE), "legacy sync clears removed elite state")
	_check(world.get_representation(legacy_handle) == Types.Representation.DYING, "dead legacy actor marks its record dying")

	_check(world.release_legacy_actor(legacy, &"test_release"), "legacy release removes the adopted record")
	_check(not world.is_valid_handle(legacy_handle), "legacy release invalidates its handle")
	_check(not world.release_legacy_actor(legacy, &"test_release"), "legacy release is idempotent")

	actor_two.queue_free()
	legacy.queue_free()
	world.clear_world()
	world.queue_free()
	print("EnemyWorldBindingTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
