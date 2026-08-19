extends Node

const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")

class MirrorActor:
	extends Node2D
	var health := 20.0

	func _apply_enemy_world_health(current_health: float, _maximum_health: float) -> void:
		health = current_health

	func _apply_enemy_world_damage_feedback(_damage: float, _source: Node, _payload: Variant) -> void:
		pass

	func _apply_enemy_world_death(_context: RefCounted) -> void:
		pass

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


func _spawn(id: StringName, position: Vector2) -> int:
	return EnemyWorld.create_enemy(SpawnState.new(id, "res://%s.tscn" % String(id), position, 20.0, 0.0, 4.0, 0))


func _run() -> void:
	var source := Node.new()
	add_child(source)
	var data_impact := _spawn(&"data_impact", Vector2(30.0, 0.0))
	var materialized_impact := _spawn(&"materialized_impact", Vector2(40.0, 0.0))
	var impact_actor := MirrorActor.new()
	impact_actor.position = Vector2(40.0, 0.0)
	add_child(impact_actor)
	EnemyWorld.bind_actor(materialized_impact, impact_actor)
	var impact_scene := load("res://scenes/world/combat/MagicImpact.tscn") as PackedScene
	var impact := impact_scene.instantiate() as MagicImpact
	impact.radius = 60.0
	impact.damage = 5.0
	impact.lifetime = 1.0
	impact.source = source
	add_child(impact)
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(EnemyWorld.get_health(data_impact) == 15.0, "magic radius damages data-only handle")
	_check(EnemyWorld.get_health(materialized_impact) == 15.0 and impact_actor.health == 15.0, "magic radius keeps materialized record and mirror equal")
	EnemyWorld.remove_enemy(data_impact, &"area_reset")
	EnemyWorld.remove_enemy(materialized_impact, &"area_reset")
	impact.queue_free()
	impact_actor.queue_free()

	var data_melee := _spawn(&"data_melee", Vector2(50.0, 0.0))
	var materialized_melee := _spawn(&"materialized_melee", Vector2(50.0, 10.0))
	var outside_melee := _spawn(&"outside_melee", Vector2(0.0, 50.0))
	var melee_actor := MirrorActor.new()
	melee_actor.position = Vector2(50.0, 10.0)
	add_child(melee_actor)
	EnemyWorld.bind_actor(materialized_melee, melee_actor)
	var slash_scene := load("res://scenes/world/combat/MeleeSlash.tscn") as PackedScene
	var slash := slash_scene.instantiate() as MeleeSlash
	slash.damage = 6.0
	slash.lifetime = 1.0
	slash.arc_radius = 62.0
	slash.arc_degrees = 90.0
	slash.thickness = 18.0
	slash.source = source
	add_child(slash)
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(EnemyWorld.get_health(data_melee) == 14.0, "melee wedge damages data-only handle")
	_check(EnemyWorld.get_health(materialized_melee) == 14.0 and melee_actor.health == 14.0, "melee wedge damages materialized handle once")
	_check(EnemyWorld.get_health(outside_melee) == 20.0, "melee wedge rejects off-angle handle")
	slash.call("_scan_world_targets")
	_check(EnemyWorld.get_health(materialized_melee) == 14.0, "world and physics paths share one-hit deduplication")

	for handle in [data_melee, materialized_melee, outside_melee]:
		EnemyWorld.remove_enemy(handle, &"area_cleanup")
	slash.queue_free()
	melee_actor.queue_free()
	source.queue_free()
	await get_tree().process_frame
	print("EnemyAreaCombatTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)

