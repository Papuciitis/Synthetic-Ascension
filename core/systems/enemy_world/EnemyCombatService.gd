class_name EnemyCombatService
extends Node

const DeathContextScript = preload("res://core/systems/enemy_world/EnemyDeathContext.gd")

var _world: EnemyWorldService = null
var _query_candidates: Array[int] = []
var _last_segment_t: float = -1.0
# Standalone tests run their own status service instance; production resolves
# the /root/EnemyStatus autoload when this is null.
var status_service_override: Node = null


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
	if (
		actor != null
		and not actor.has_method("_apply_enemy_world_health")
		and actor.has_method("take_damage")
	):
		return _apply_legacy_damage(handle, actor, raw_damage, source)
	var adjusted_damage := _adjust_damage(handle, actor, raw_damage, hit_count)
	var applied_damage := minf(adjusted_damage, current_health)
	if applied_damage <= 0.0:
		return 0.0

	var remaining_health := maxf(0.0, current_health - applied_damage)
	if not _world.set_health(handle, remaining_health):
		return 0.0
	_mirror_health(actor, remaining_health, _world.get_max_health(handle))
	if BattleText != null:
		var ledger_payload := payload as HitLedger
		var was_critical: bool = ledger_payload != null and ledger_payload.critical_hits > 0
		BattleText.damage(_world.get_position(handle), applied_damage, was_critical, handle)
	if source != null and is_instance_valid(source) and RunEvents != null:
		RunEvents.damage_dealt.emit(source, applied_damage)

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
		_death_metadata(handle, actor),
	)
	if RunEvents != null and RunEvents.has_signal("enemy_defeated"):
		RunEvents.enemy_defeated.emit(context)
	if actor != null and actor.has_method("_apply_enemy_world_death"):
		actor.call("_apply_enemy_world_death", context)
	else:
		_finalize_proxy_death(handle)
	return applied_damage


func _finalize_proxy_death(handle: int) -> void:
	# A data-only record has no actor to run the Node death pipeline; grant its
	# follower reward from the committed cold state and release the record
	# exactly once. Item/health drops for far proxies are intentionally skipped
	# in this slice — the defeat snapshot above already fed telemetry and
	# progression.
	var cold := _world.get_cold_state(handle)
	var reward_min := int(cold.get("follower_reward_min", 1))
	var reward_max := maxi(reward_min, int(cold.get("follower_reward_max", reward_min)))
	var reward := Global._rng.randi_range(reward_min, reward_max)
	if (_world.get_flags(handle) & EnemyWorldTypes.Flags.ELITE) != 0:
		reward += int(cold.get("elite_follower_bonus", 0))
	if reward > 0 and Global != null:
		Global.transaction_followers(
			reward,
			&"combat_influence",
			{"enemy_id": String(_world.get_spec_id(handle))},
			true,
			true,
		)
	var status := status_service_override
	if status == null or not is_instance_valid(status):
		status = get_node_or_null("/root/EnemyStatus")
	if status != null and status.has_method("clear_handle"):
		status.call("clear_handle", handle)
	var index := get_node_or_null("/root/EnemyIndex")
	if index != null and index.has_method("is_detached") and bool(index.call("is_detached", handle)):
		index.call("release_detached", handle, &"proxy_death")
	else:
		_world.remove_enemy(handle, &"proxy_death")


func apply_damage_to_actor(
	actor: Node2D,
	raw_damage: float,
	hit_count: int = 1,
	source: Node = null,
	payload: Variant = null,
) -> float:
	var handle := handle_for_actor(actor)
	return apply_damage(handle, raw_damage, hit_count, source, payload)


func apply_hit_ledger(handle: int, ledger: HitLedger) -> float:
	if ledger == null:
		return 0.0
	var applied_damage := apply_damage(
		handle,
		ledger.total_raw_damage,
		maxi(1, ledger.hit_count),
		ledger.source,
		ledger,
	)
	if applied_damage <= 0.0 or not _is_live_handle(handle):
		return applied_damage
	var combined_knockback := ledger.clamped_knockback()
	if combined_knockback != Vector2.ZERO:
		apply_knockback(handle, combined_knockback)
	if (
		ledger.burn_stacks > 0
		and ledger.burn_duration > 0.0
		and ledger.burn_damage_per_tick_per_stack > 0.0
	):
		var status := get_node_or_null("/root/EnemyStatus")
		if status != null:
			status.call(
				"apply_burn",
				handle,
				ledger.burn_stacks,
				ledger.burn_duration,
				ledger.burn_tick,
				ledger.burn_damage_per_tick_per_stack,
				ledger.source,
			)
	return applied_damage


func heal(handle: int, amount: float) -> bool:
	if _world == null or not is_instance_valid(_world) or not _world.heal(handle, amount):
		return false
	_mirror_health(
		_world.actor_for_handle(handle),
		_world.get_health(handle),
		_world.get_max_health(handle),
	)
	return true


func configure_health(handle: int, maximum_health: float, fill_to_max: bool = false) -> bool:
	if (
		_world == null
		or not is_instance_valid(_world)
		or not _world.set_max_health(handle, maximum_health, fill_to_max)
	):
		return false
	_mirror_health(
		_world.actor_for_handle(handle),
		_world.get_health(handle),
		_world.get_max_health(handle),
	)
	return true


func handle_for_actor(actor: Node) -> int:
	if _world == null or not is_instance_valid(_world) or actor == null or not is_instance_valid(actor):
		return EnemyWorldTypes.INVALID_HANDLE
	return _world.handle_for_actor(actor)


func position_for_handle(handle: int) -> Vector2:
	return _world.get_position(handle) if _is_live_handle(handle) else Vector2.ZERO


func actor_for_handle(handle: int) -> Node2D:
	return _world.actor_for_handle(handle) if _is_live_handle(handle) else null


func gather_in_radius(
	origin: Vector2,
	radius: float,
	out: Array[int],
	excluded_handle: int = EnemyWorldTypes.INVALID_HANDLE,
) -> void:
	out.clear()
	if _world == null or not is_instance_valid(_world):
		return
	_world.gather_in_radius(origin, radius, out, excluded_handle)
	for index in range(out.size() - 1, -1, -1):
		if _world.is_dying(out[index]):
			out.remove_at(index)


func nearest_enemy(
	origin: Vector2,
	max_distance: float,
	excluded_handle: int = EnemyWorldTypes.INVALID_HANDLE,
) -> int:
	gather_in_radius(origin, max_distance, _query_candidates, excluded_handle)
	var best_handle := EnemyWorldTypes.INVALID_HANDLE
	var best_distance_squared := maxf(max_distance, 0.0) * maxf(max_distance, 0.0)
	for handle in _query_candidates:
		var distance_squared := origin.distance_squared_to(_world.get_position(handle))
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_handle = handle
	return best_handle


func first_enemy_on_segment(
	from: Vector2,
	to: Vector2,
	projectile_radius: float = 0.0,
	excluded_handle: int = EnemyWorldTypes.INVALID_HANDLE,
) -> int:
	_last_segment_t = -1.0
	if _world == null or not is_instance_valid(_world):
		return EnemyWorldTypes.INVALID_HANDLE
	var midpoint := (from + to) * 0.5
	var broad_radius := from.distance_to(to) * 0.5 + maxf(projectile_radius, 0.0) + _world.largest_collision_radius()
	gather_in_radius(midpoint, broad_radius, _query_candidates, excluded_handle)
	var best_handle := EnemyWorldTypes.INVALID_HANDLE
	var best_t := 2.0
	for handle in _query_candidates:
		var hit_t := _segment_circle_t(
			from,
			to,
			_world.get_position(handle),
			maxf(projectile_radius, 0.0) + _world.get_collision_radius(handle),
		)
		if hit_t >= 0.0 and hit_t < best_t:
			best_t = hit_t
			best_handle = handle
	if best_handle != EnemyWorldTypes.INVALID_HANDLE:
		_last_segment_t = best_t
	return best_handle


func last_segment_hit_t() -> float:
	return _last_segment_t


func gather_in_sector(
	origin: Vector2,
	forward: Vector2,
	outer_radius: float,
	inner_radius: float,
	half_angle_radians: float,
	out: Array[int],
) -> void:
	gather_in_radius(origin, outer_radius, _query_candidates)
	out.clear()
	var direction := forward.normalized()
	if direction == Vector2.ZERO:
		return
	var safe_inner_squared := maxf(inner_radius, 0.0) * maxf(inner_radius, 0.0)
	var cosine_limit := cos(clampf(half_angle_radians, 0.0, PI))
	for handle in _query_candidates:
		var offset := _world.get_position(handle) - origin
		var distance_squared := offset.length_squared()
		if distance_squared < safe_inner_squared or distance_squared <= 0.000001:
			continue
		if direction.dot(offset.normalized()) >= cosine_limit:
			out.append(handle)


func apply_knockback(handle: int, force: Vector2) -> bool:
	if force == Vector2.ZERO or not _is_live_handle(handle):
		return false
	var actor := _world.actor_for_handle(handle)
	var adjusted_force := force
	var cold_state := _world.get_cold_state(handle)
	if cold_state.has("knockback_multiplier"):
		adjusted_force *= maxf(0.0, float(cold_state["knockback_multiplier"]))
	if actor != null and actor.is_in_group(&"boss_like"):
		adjusted_force *= maxf(0.0, float(actor.get_meta("boss_kb_mul", 0.25)))
	if adjusted_force == Vector2.ZERO or not _world.add_knockback_velocity(handle, adjusted_force):
		return false
	if actor != null:
		if actor.has_method("_apply_enemy_world_knockback"):
			actor.call("_apply_enemy_world_knockback", adjusted_force)
		elif actor.has_method("apply_knockback"):
			actor.call("apply_knockback", adjusted_force)
	return true


func apply_stun(handle: int, seconds: float) -> bool:
	if seconds <= 0.0 or not _is_live_handle(handle):
		return false
	if not _world.extend_stun_time(handle, seconds):
		return false
	var actor := _world.actor_for_handle(handle)
	if actor != null:
		if actor.has_method("_apply_enemy_world_stun"):
			actor.call("_apply_enemy_world_stun", _world.get_stun_time(handle))
		elif actor.has_method("apply_stun"):
			actor.call("apply_stun", seconds)
	return true


func _is_live_handle(handle: int) -> bool:
	return (
		_world != null
		and is_instance_valid(_world)
		and _world.is_valid_handle(handle)
		and not _world.is_dying(handle)
	)


func _apply_legacy_damage(handle: int, actor: Node2D, raw_damage: float, source: Node) -> float:
	var before_health := _world.get_health(handle)
	if "hp" in actor:
		before_health = maxf(0.0, float(actor.get("hp")))
	actor.call("take_damage", raw_damage, source)
	if not is_instance_valid(actor):
		return minf(raw_damage, before_health)
	var remaining_health := maxf(0.0, before_health - raw_damage)
	if "hp" in actor:
		remaining_health = maxf(0.0, float(actor.get("hp")))
	_world.set_health(handle, remaining_health)
	if remaining_health <= 0.0 or ("dead" in actor and bool(actor.get("dead"))):
		_world.try_begin_death(handle)
	return clampf(before_health - remaining_health, 0.0, before_health)


func _segment_circle_t(from: Vector2, to: Vector2, center: Vector2, radius: float) -> float:
	var segment := to - from
	var length_squared := segment.length_squared()
	if length_squared <= 0.000001:
		return 0.0 if from.distance_squared_to(center) <= radius * radius else -1.0
	var offset := from - center
	if offset.length_squared() <= radius * radius:
		return 0.0
	var b := 2.0 * offset.dot(segment)
	var c := offset.length_squared() - radius * radius
	var discriminant := b * b - 4.0 * length_squared * c
	if discriminant < 0.0:
		return -1.0
	var root := sqrt(discriminant)
	var first := (-b - root) / (2.0 * length_squared)
	if first >= 0.0 and first <= 1.0:
		return first
	var second := (-b + root) / (2.0 * length_squared)
	return second if second >= 0.0 and second <= 1.0 else -1.0


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


func _death_metadata(handle: int, actor: Node2D) -> Dictionary:
	var cold_state := _world.get_cold_state(handle)
	var snapshot := {
		"opening_scripted": bool(cold_state.get("opening_scripted", false)),
		"special_spawn_kind": cold_state.get("special_spawn_kind", &""),
	}
	if actor != null:
		for key in [&"opening_scripted", &"special_spawn_kind"]:
			if actor.has_meta(key):
				snapshot[String(key)] = actor.get_meta(key)
	return snapshot
