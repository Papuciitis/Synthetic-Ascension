extends Node

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const WorldScript = preload("res://core/systems/enemy_world/EnemyWorld.gd")
const CombatScript = preload("res://core/systems/enemy_world/EnemyCombatService.gd")

class DummyEnemy:
	extends Node2D
	var health_updates := 0
	var feedback_calls := 0
	var death_calls := 0
	var mirrored_health := -1.0
	var last_damage := -1.0
	var last_context: RefCounted = null

	func _apply_enemy_world_health(current_health: float, _maximum_health: float) -> void:
		health_updates += 1
		mirrored_health = current_health

	func _apply_enemy_world_damage_feedback(applied_damage: float, _source: Node, _payload: Variant) -> void:
		feedback_calls += 1
		last_damage = applied_damage

	func _apply_enemy_world_death(context: RefCounted) -> void:
		death_calls += 1
		last_context = context

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


func _spawn(world: Node, id: StringName, health: float = 100.0, cold: Dictionary = {}) -> int:
	return int(world.call("create_enemy", SpawnState.new(
		id,
		"res://%s.tscn" % String(id),
		Vector2(12.0, 34.0),
		health,
		100.0,
		20.0,
		0,
		Types.Flags.ELITE if id == &"elite" else Types.Flags.NONE,
		cold,
	)))


func _run() -> void:
	var world := WorldScript.new()
	add_child(world)
	var combat := CombatScript.new()
	combat.setup(world)
	add_child(combat)

	var ordinary := _spawn(world, &"ordinary")
	var actor := DummyEnemy.new()
	add_child(actor)
	_check(world.bind_actor(ordinary, actor), "materialized target binds before combat")
	_check(is_equal_approx(combat.apply_damage(ordinary, 30.0), 30.0), "ordinary damage reports the applied amount")
	_check(is_equal_approx(world.get_health(ordinary), 70.0), "ordinary damage mutates world health")
	_check(actor.health_updates == 1 and actor.mirrored_health == 70.0, "damage mirrors authoritative health to actor")
	_check(actor.feedback_calls == 1 and actor.last_damage == 30.0, "surviving actor receives hit feedback")

	actor.set_meta("damage_taken_mul", 0.5)
	actor.set_meta("hit_cap_ratio", 0.10)
	_check(is_equal_approx(combat.apply_damage(ordinary, 80.0, 2), 20.0), "bound actor compatibility modifiers cap batched hits")
	_check(is_equal_approx(world.get_health(ordinary), 50.0), "modified damage remains authoritative")

	_check(is_equal_approx(combat.apply_damage(ordinary, 999.0), 10.0), "single-hit cap applies before lethal transition")
	_check(not world.is_dying(ordinary), "capped nonlethal hit keeps target alive")
	actor.remove_meta("hit_cap_ratio")
	_check(is_equal_approx(combat.apply_damage(ordinary, 999.0), 40.0), "lethal damage reports only remaining health")
	_check(world.get_health(ordinary) == 0.0 and world.is_dying(ordinary), "lethal damage atomically marks world record dying")
	_check(actor.death_calls == 1 and actor.feedback_calls == 3, "lethal hit resolves death once without survivor feedback")
	_check(actor.last_context != null, "lethal hit provides a death context")
	if actor.last_context != null:
		_check(int(actor.last_context.get("handle")) == ordinary, "death context preserves stable handle")
		_check(actor.last_context.get("spec_id") == &"ordinary", "death context preserves spec id")
		_check(actor.last_context.get("position") == Vector2(12.0, 34.0), "death context preserves position")
	_check(combat.apply_damage(ordinary, 10.0) == 0.0, "damage after death is ignored")
	_check(actor.death_calls == 1, "repeated lethal damage cannot repeat actor death callback")

	var data_only := _spawn(world, &"elite", 100.0, {"damage_taken_mul": 0.25, "hit_cap_ratio": 0.20})
	_check(is_equal_approx(combat.apply_damage(data_only, 500.0, 2), 40.0), "data-only record resolves cold-state modifiers without actor")
	_check(is_equal_approx(world.get_health(data_only), 60.0), "data-only damage persists in world storage")
	_check(is_equal_approx(combat.apply_damage(data_only, 500.0, 4), 60.0), "data-only lethal damage clamps to remaining health")
	_check(world.is_dying(data_only), "data-only enemy can die without materialization")

	var stale := _spawn(world, &"stale")
	_check(world.remove_enemy(stale, &"test"), "stale combat fixture is removed")
	var replacement := _spawn(world, &"replacement")
	_check(combat.apply_damage(stale, 100.0) == 0.0, "stale handle damage is rejected")
	_check(world.get_health(replacement) == 100.0, "stale damage cannot affect reused slot")
	_check(combat.apply_damage(Types.INVALID_HANDLE, 10.0) == 0.0, "invalid handle damage is rejected")
	_check(combat.apply_damage(replacement, 0.0) == 0.0, "zero damage is ignored")
	_check(combat.apply_damage(replacement, -10.0) == 0.0, "negative damage is ignored")

	print("EnemyCombatServiceTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)

