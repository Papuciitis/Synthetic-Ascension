class_name EnemyCombatService
extends Node

const DeathContextScript = preload("res://core/systems/enemy_world/EnemyDeathContext.gd")

var _world: EnemyWorldService = null


func setup(world: EnemyWorldService) -> void:
	_world = world


func _ready() -> void:
	if _world == null:
		_world = get_node_or_null("/root/EnemyWorld") as EnemyWorldService


func apply_damage(
	handle: int,
	raw_damage: float,
	hit_count: int = 1,
	source: Node = null,
	payload: Variant = null,
) -> float:
	if _world == null or not is_instance_valid(_world):
		return 0.0
	if raw_damage <= 0.0 or not _world.is_valid_handle(handle) or _world.is_dying(handle):
		return 0.0

	var current_health := _world.get_health(handle)
	if current_health <= 0.0:
		return 0.0
	var actor := _world.actor_for_handle(handle)
	var adjusted_damage := _adjust_damage(handle, actor, raw_damage, hit_count)
	var applied_damage := minf(adjusted_damage, current_health)
	if applied_damage <= 0.0:
		return 0.0

	var remaining_health := maxf(0.0, current_health - applied_damage)
	if not _world.set_health(handle, remaining_health):
		return 0.0
	_mirror_health(actor, remaining_health, _world.get_max_health(handle))

	if remaining_health > 0.0:
		_apply_survivor_feedback(actor, applied_damage, source, payload)
		return applied_damage

	if not _world.try_begin_death(handle):
		return applied_damage
	var context := DeathContextScript.new(
		handle,
		_world.get_spec_id(handle),
		_world.get_position(handle),
		_world.get_flags(handle),
		source,
	)
	if actor != null and actor.has_method("_apply_enemy_world_death"):
		actor.call("_apply_enemy_world_death", context)
	return applied_damage


func _adjust_damage(handle: int, actor: Node2D, raw_damage: float, hit_count: int) -> float:
	var cold_state := _world.get_cold_state(handle)
	var damage_multiplier := maxf(0.0, float(cold_state.get("damage_taken_mul", 1.0)))
	var hit_cap_ratio := maxf(0.0, float(cold_state.get("hit_cap_ratio", 0.0)))
	if actor != null:
		if actor.has_meta("damage_taken_mul"):
			damage_multiplier = maxf(0.0, float(actor.get_meta("damage_taken_mul")))
		if actor.has_meta("hit_cap_ratio"):
			hit_cap_ratio = maxf(0.0, float(actor.get_meta("hit_cap_ratio")))
	var adjusted := maxf(0.0, raw_damage) * damage_multiplier
	if hit_cap_ratio > 0.0:
		var hit_cap := _world.get_max_health(handle) * hit_cap_ratio * float(maxi(1, hit_count))
		adjusted = minf(adjusted, hit_cap)
	return adjusted


func _mirror_health(actor: Node2D, current_health: float, maximum_health: float) -> void:
	if actor != null and actor.has_method("_apply_enemy_world_health"):
		actor.call("_apply_enemy_world_health", current_health, maximum_health)


func _apply_survivor_feedback(
	actor: Node2D,
	applied_damage: float,
	source: Node,
	payload: Variant,
) -> void:
	if actor != null and actor.has_method("_apply_enemy_world_damage_feedback"):
		actor.call("_apply_enemy_world_damage_feedback", applied_damage, source, payload)
