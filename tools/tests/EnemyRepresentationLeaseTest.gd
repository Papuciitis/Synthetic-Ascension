extends Node

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const ManagerScript = preload("res://core/systems/enemy_world/EnemyRepresentationManager.gd")

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


func _indexed_matches(index: Node, actor: Node) -> int:
	var matches := 0
	for candidate in index.call("get_all") as Array:
		if candidate == actor:
			matches += 1
	return matches


func _run() -> void:
	var scene := load("res://core/actors/enemy/enemy.tscn") as PackedScene
	var pool := get_node_or_null("/root/PoolManager")
	var index := get_node_or_null("/root/EnemyIndex")
	var world := get_node_or_null("/root/EnemyWorld") as EnemyWorldService
	_check(scene != null and pool != null and index != null and world != null, "real lease dependencies load")
	if scene == null or pool == null or index == null or world == null:
		_finish()
		return
	pool.call("set_limit_for_scene", scene, 4)
	var before_logical := world.active_count()
	var before_ambient := int(index.call("ambient_alive_count"))
	var before_scene := int(index.call("alive_count_for_scene", scene))

	var actor := pool.call("obtain", scene, self) as EnemyActor
	_check(actor != null, "ordinary EnemyActor materializes through the existing pool")
	if actor == null:
		_finish()
		return
	actor.drop_chance = 0.0
	actor.health_drop_chance = 0.0
	var handle := world.handle_for_actor(actor)
	_check(handle != Types.INVALID_HANDLE, "materialized fixture has a stable logical handle")
	_check(world.active_count() == before_logical + 1, "ordinary spawn creates exactly one logical record")
	var logical_ambient := int(index.call("ambient_alive_count"))
	var logical_scene := int(index.call("alive_count_for_scene", scene))
	_check(logical_ambient == before_ambient + 1 and logical_scene == before_scene + 1, "logical population counters increment once")

	actor.global_position = Vector2(320.0, 180.0)
	actor.velocity = Vector2(11.0, -3.0)
	actor.scale = Vector2(1.25, 0.8)
	actor.take_damage(3.0)
	actor.apply_stun(1.25)
	actor.apply_knockback(Vector2(45.0, -12.0))
	var cold := world.get_cold_state(handle)
	cold["lease_test_payload"] = {"wave": 7, "label": &"preserved"}
	world.replace_cold_state(handle, cold)

	var manager := ManagerScript.new()
	manager.setup(world, pool, index, self)
	add_child(manager)
	_check(manager.dematerialize(handle), "manager dematerializes an eligible ordinary actor")
	await get_tree().process_frame
	_check(world.is_valid_handle(handle), "dematerialization preserves the logical record")
	_check(world.get_representation(handle) == Types.Representation.DATA_ONLY, "dematerialization switches only representation state")
	_check(world.actor_for_handle(handle) == null, "data-only record has no bound actor")
	_check(world.get_position(handle).is_equal_approx(Vector2(320.0, 180.0)), "lease commit preserves position")
	_check(world.get_velocity(handle).is_equal_approx(Vector2(11.0, -3.0)), "lease commit preserves velocity")
	_check(is_equal_approx(world.get_health(handle), actor.hp), "lease commit preserves authoritative health")
	_check(is_equal_approx(world.get_stun_time(handle), 1.25), "lease commit preserves stun state")
	_check(world.get_knockback_velocity(handle).is_equal_approx(Vector2(45.0, -12.0)), "lease commit preserves knockback state")
	_check(int(index.call("ambient_alive_count")) == logical_ambient and int(index.call("alive_count_for_scene", scene)) == logical_scene, "dematerialization does not alter logical population counters")
	_check(_indexed_matches(index, actor) == 0, "dematerialized actor leaves materialized spatial indexes")
	_check(actor.process_mode == Node.PROCESS_MODE_DISABLED and not actor.visible, "pooled representation is fully quiescent")

	world.set_position(handle, Vector2(480.0, 240.0))
	world.set_velocity(handle, Vector2(-20.0, 8.0))
	world.set_health(handle, 4.0)
	world.set_stun_time(handle, 0.6)
	world.set_knockback_velocity(handle, Vector2(-9.0, 2.0))
	var rematerialized := manager.materialize(handle) as EnemyActor
	await get_tree().process_frame
	_check(rematerialized == actor, "promotion reuses the same pooled representation when available")
	_check(world.actor_for_handle(handle) == rematerialized, "promotion binds the existing logical handle")
	_check(world.active_count() == before_logical + 1, "promotion does not create a second logical record")
	_check(rematerialized.global_position.is_equal_approx(Vector2(480.0, 240.0)), "hydration restores the latest data-only position")
	_check(rematerialized.velocity.is_equal_approx(Vector2(-20.0, 8.0)), "hydration restores authoritative velocity")
	_check(is_equal_approx(rematerialized.hp, 4.0), "hydration restores authoritative health")
	_check(is_equal_approx(rematerialized.stun_time, 0.6), "hydration restores authoritative stun")
	_check(rematerialized.knockback_vel.is_equal_approx(Vector2(-9.0, 2.0)), "hydration restores authoritative knockback")
	_check(rematerialized.scale.is_equal_approx(Vector2(1.25, 0.8)), "hydration restores cold actor scale state")
	_check((world.get_cold_state(handle).get("lease_test_payload", {}) as Dictionary).get("wave", 0) == 7, "lease round trip preserves unrelated cold state")
	_check(_indexed_matches(index, rematerialized) == 1, "rematerialized actor is indexed exactly once")
	_check(int(index.call("ambient_alive_count")) == logical_ambient and int(index.call("alive_count_for_scene", scene)) == logical_scene, "promotion leaves logical counters unchanged")

	_check(manager.dematerialize(handle), "representation can dematerialize repeatedly")
	var old_instance_id := actor.get_instance_id()
	actor.queue_free()
	await get_tree().process_frame
	var replacement := manager.materialize(handle) as EnemyActor
	await get_tree().process_frame
	_check(replacement != null and replacement.get_instance_id() != old_instance_id, "forced pooled-node deletion falls back to a fresh representation")
	_check(world.actor_for_handle(handle) == replacement, "fresh replacement binds the same generation handle")
	_check(world.active_count() == before_logical + 1, "forced representation loss does not duplicate logical records")
	_check(_indexed_matches(index, replacement) == 1, "fresh replacement attaches to indexes exactly once")

	_check(manager.dematerialize(handle), "replacement can return to data-only state")
	_check(index.call("release_detached", handle, &"lease_test_cleanup"), "detached logical record has an explicit exact-once release path")
	_check(not world.is_valid_handle(handle), "detached release invalidates the logical handle")
	_check(not index.call("release_detached", handle, &"lease_test_cleanup"), "detached release is idempotent")
	_check(world.active_count() == before_logical, "cleanup restores the initial logical population")
	_check(int(index.call("ambient_alive_count")) == before_ambient and int(index.call("alive_count_for_scene", scene)) == before_scene, "cleanup restores initial population counters")
	_check(manager.materialize(handle) == null, "stale generation handles cannot acquire a representation")

	manager.queue_free()
	await get_tree().process_frame
	_finish()


func _finish() -> void:
	print("EnemyRepresentationLeaseTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
