extends Node

var _passes := 0
var _failures := 0
var _kill_events := 0
var _defeat_events := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _on_enemy_killed(_source: Node, _enemy: Node, _position: Vector2) -> void:
	_kill_events += 1


func _on_enemy_defeated(_context: RefCounted) -> void:
	_defeat_events += 1


func _run() -> void:
	var scene := load("res://core/actors/enemy/enemy.tscn") as PackedScene
	var pool := get_node_or_null("/root/PoolManager")
	var world := get_node_or_null("/root/EnemyWorld")
	_check(scene != null and pool != null and world != null, "real enemy lifecycle dependencies load")
	if scene == null or pool == null or world == null:
		_finish()
		return
	pool.call("set_limit_for_scene", scene, 2)
	var callback := Callable(self, "_on_enemy_killed")
	var defeat_callback := Callable(self, "_on_enemy_defeated")
	if not RunEvents.enemy_killed.is_connected(callback):
		RunEvents.enemy_killed.connect(callback)
	if RunEvents.has_signal("enemy_defeated") and not RunEvents.is_connected("enemy_defeated", defeat_callback):
		RunEvents.connect("enemy_defeated", defeat_callback)

	var enemy := pool.call("obtain", scene, self) as EnemyActor
	_check(enemy != null, "real pooled EnemyActor spawns")
	if enemy == null:
		_finish()
		return
	enemy.drop_chance = 0.0
	enemy.health_drop_chance = 0.0
	var first_handle := int(world.call("handle_for_actor", enemy))
	_check(first_handle != 0, "spawned actor owns a stable world handle")
	var initial_health := enemy.hp
	_check(is_equal_approx(float(world.call("get_health", first_handle)), enemy.hp), "actor health starts equal to world health")

	enemy.take_damage(2.0, null)
	_check(is_equal_approx(enemy.hp, initial_health - 2.0), "direct damage updates actor mirror")
	_check(is_equal_approx(float(world.call("get_health", first_handle)), enemy.hp), "direct damage updates authoritative world health")

	var ledger := HitLedger.new()
	ledger.add_resolved_hit(3.0, null, Vector2.ZERO, false, 0, 0.0, 0.5, 0.0)
	enemy.apply_hit_ledger(ledger)
	_check(is_equal_approx(enemy.hp, initial_health - 5.0) and is_equal_approx(float(world.call("get_health", first_handle)), enemy.hp), "batched hit keeps actor and world synchronized")

	_check(enemy.heal(2.0), "actor exposes authoritative healing")
	_check(is_equal_approx(enemy.hp, initial_health - 3.0) and is_equal_approx(float(world.call("get_health", first_handle)), enemy.hp), "healing updates actor and world together")
	_check(enemy.configure_health(20.0, true), "actor exposes authoritative maximum-health configuration")
	_check(enemy.max_hp == 20.0 and enemy.hp == 20.0, "health configuration updates actor mirror")
	_check(world.call("get_max_health", first_handle) == 20.0 and world.call("get_health", first_handle) == 20.0, "health configuration updates world values")

	enemy.take_damage(999.0, null)
	_check(_kill_events == 1, "lethal damage emits one compatibility kill event")
	_check(_defeat_events == 1, "lethal damage emits one generic defeat event")
	_check(not world.call("is_valid_handle", first_handle), "despawn invalidates the dead actor handle")
	enemy.take_damage(999.0, null)
	_check(_kill_events == 1 and _defeat_events == 1, "late damage on pooled actor cannot repeat either death event")

	var reused := pool.call("obtain", scene, self) as EnemyActor
	_check(reused == enemy, "dead materialized actor is reused from pool")
	var second_handle := int(world.call("handle_for_actor", reused))
	_check(second_handle != 0 and second_handle != first_handle, "pool obtain assigns a fresh-generation handle")
	_check(reused.hp == reused.max_hp and not reused.dead, "reused actor mirror resets alive at full health")
	_check(is_equal_approx(float(world.call("get_health", second_handle)), reused.hp), "reused actor and new world record agree")

	reused.call("despawn", &"test_cleanup")
	await get_tree().process_frame
	if RunEvents.enemy_killed.is_connected(callback):
		RunEvents.enemy_killed.disconnect(callback)
	if RunEvents.has_signal("enemy_defeated") and RunEvents.is_connected("enemy_defeated", defeat_callback):
		RunEvents.disconnect("enemy_defeated", defeat_callback)
	_finish()


func _finish() -> void:
	print("EnemyCombatLifecycleTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)
