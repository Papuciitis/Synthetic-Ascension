class_name EnemyWorldService
extends Node

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const SpatialGrid = preload("res://core/systems/enemy_world/EnemySpatialGrid.gd")

@export var cell_size: float = 64.0

var _active := PackedByteArray()
var _generations := PackedInt64Array()
var _positions := PackedVector2Array()
var _previous_positions := PackedVector2Array()
var _velocities := PackedVector2Array()
var _facings := PackedVector2Array()
var _knockback_velocities := PackedVector2Array()
var _knockback_decays := PackedFloat32Array()
var _stun_times := PackedFloat32Array()
var _proxy_update_times := PackedFloat32Array()
var _health := PackedFloat32Array()
var _max_health := PackedFloat32Array()
var _speeds := PackedFloat32Array()
var _collision_radii := PackedFloat32Array()
var _ai_kinds := PackedInt32Array()
var _flags := PackedInt64Array()
var _representations := PackedInt32Array()
var _active_slots := PackedInt32Array()
var _active_slot_indices := PackedInt32Array()
var _free_slots := PackedInt32Array()
var _spec_ids: Array[StringName] = []
var _scene_paths := PackedStringArray()
var _cold_states: Array[Dictionary] = []
var _grid: EnemySpatialGrid
var _removed_by_reason: Dictionary = {}
var _actor_refs: Dictionary = {} # handle -> WeakRef
var _actor_handles: Dictionary = {} # actor instance id -> handle
var _bound_instance_ids: Dictionary = {} # handle -> actor instance id
var _legacy_handles: Dictionary = {} # handle -> true
var _largest_collision_radius: float = 0.0
var _largest_collision_radius_dirty: bool = false


func _init() -> void:
	_grid = SpatialGrid.new(cell_size)


func _ready() -> void:
	if _active.is_empty() and not is_equal_approx(_grid.cell_size, cell_size):
		_grid = SpatialGrid.new(cell_size)


func _exit_tree() -> void:
	# Application shutdown: drop every object graph (WeakRefs, cold-state
	# dictionaries, spec names) before script teardown so engine cleanup never
	# walks records owned by a half-destructed autoload. This is a shutdown-order
	# hazard mitigation, not gameplay logic.
	_actor_refs.clear()
	_actor_handles.clear()
	_bound_instance_ids.clear()
	_legacy_handles.clear()
	_cold_states.clear()
	_spec_ids.clear()
	_removed_by_reason.clear()
	if _grid != null:
		_grid.clear()


func create_enemy(state: EnemySpawnState) -> int:
	if state == null:
		return Types.INVALID_HANDLE
	var slot: int
	if _free_slots.is_empty():
		slot = _append_slot_storage()
	else:
		var free_index := _free_slots.size() - 1
		slot = int(_free_slots[free_index])
		_free_slots.resize(free_index)

	_active[slot] = 1
	_positions[slot] = state.position
	_previous_positions[slot] = state.position
	_velocities[slot] = state.velocity
	_facings[slot] = state.velocity.normalized() if state.velocity != Vector2.ZERO else Vector2.RIGHT
	_knockback_velocities[slot] = Vector2.ZERO
	_knockback_decays[slot] = maxf(float(state.cold_state.get("knockback_decay", 2200.0)), 0.0)
	_stun_times[slot] = 0.0
	_proxy_update_times[slot] = 0.0
	_health[slot] = clampf(state.health, 0.0, state.max_health)
	_max_health[slot] = maxf(state.max_health, 0.0)
	_speeds[slot] = maxf(state.speed, 0.0)
	_collision_radii[slot] = maxf(state.collision_radius, 0.0)
	_largest_collision_radius = maxf(_largest_collision_radius, float(_collision_radii[slot]))
	_ai_kinds[slot] = state.ai_kind
	_flags[slot] = state.flags
	_representations[slot] = Types.Representation.DATA_ONLY
	_spec_ids[slot] = state.spec_id
	_scene_paths[slot] = state.scene_path
	_cold_states[slot] = state.cold_state.duplicate(true)
	_active_slot_indices[slot] = _active_slots.size()
	_active_slots.append(slot)
	_grid.insert(slot, state.position)
	return Types.make_handle(slot, int(_generations[slot]))


func remove_enemy(handle: int, reason: StringName = &"removed") -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0:
		return false
	unbind_actor(handle)
	_legacy_handles.erase(handle)
	_grid.remove(slot)
	_remove_active_slot(slot)
	if is_equal_approx(float(_collision_radii[slot]), _largest_collision_radius):
		_largest_collision_radius_dirty = true
	_active[slot] = 0
	_positions[slot] = Vector2.ZERO
	_previous_positions[slot] = Vector2.ZERO
	_velocities[slot] = Vector2.ZERO
	_facings[slot] = Vector2.ZERO
	_knockback_velocities[slot] = Vector2.ZERO
	_knockback_decays[slot] = 0.0
	_stun_times[slot] = 0.0
	_proxy_update_times[slot] = 0.0
	_health[slot] = 0.0
	_max_health[slot] = 0.0
	_speeds[slot] = 0.0
	_collision_radii[slot] = 0.0
	_ai_kinds[slot] = 0
	_flags[slot] = 0
	_representations[slot] = Types.Representation.DATA_ONLY
	_spec_ids[slot] = StringName()
	_scene_paths[slot] = ""
	_cold_states[slot] = {}
	_generations[slot] = _next_generation(int(_generations[slot]))
	_free_slots.append(slot)
	_removed_by_reason[reason] = int(_removed_by_reason.get(reason, 0)) + 1
	return true


func is_valid_handle(handle: int) -> bool:
	return _slot_if_valid(handle) >= 0


func active_count() -> int:
	return _active_slots.size()


func active_handles(out: Array[int]) -> void:
	out.clear()
	for slot_variant in _active_slots:
		var slot := int(slot_variant)
		out.append(Types.make_handle(slot, int(_generations[slot])))


func get_position(handle: int) -> Vector2:
	var slot := _slot_if_valid(handle)
	return _positions[slot] if slot >= 0 else Vector2.ZERO


func get_previous_position(handle: int) -> Vector2:
	var slot := _slot_if_valid(handle)
	return _previous_positions[slot] if slot >= 0 else Vector2.ZERO


func set_position(handle: int, value: Vector2) -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0:
		return false
	_previous_positions[slot] = _positions[slot]
	_positions[slot] = value
	_grid.move(slot, value)
	return true


func reset_interpolation(handle: int) -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0:
		return false
	_previous_positions[slot] = _positions[slot]
	return true


func get_velocity(handle: int) -> Vector2:
	var slot := _slot_if_valid(handle)
	return _velocities[slot] if slot >= 0 else Vector2.ZERO


func set_velocity(handle: int, value: Vector2) -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0:
		return false
	_velocities[slot] = value
	return true


func get_facing(handle: int) -> Vector2:
	var slot := _slot_if_valid(handle)
	return _facings[slot] if slot >= 0 else Vector2.ZERO


func set_facing(handle: int, value: Vector2) -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0 or _representations[slot] == Types.Representation.DYING or value == Vector2.ZERO:
		return false
	_facings[slot] = value.normalized()
	return true


func get_knockback_velocity(handle: int) -> Vector2:
	var slot := _slot_if_valid(handle)
	return _knockback_velocities[slot] if slot >= 0 else Vector2.ZERO


func set_knockback_velocity(handle: int, value: Vector2) -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0 or _representations[slot] == Types.Representation.DYING:
		return false
	_knockback_velocities[slot] = value
	return true


func add_knockback_velocity(handle: int, value: Vector2) -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0 or _representations[slot] == Types.Representation.DYING:
		return false
	_knockback_velocities[slot] += value
	return true


func get_knockback_decay(handle: int) -> float:
	var slot := _slot_if_valid(handle)
	return float(_knockback_decays[slot]) if slot >= 0 else 0.0


func set_knockback_decay(handle: int, value: float) -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0:
		return false
	_knockback_decays[slot] = maxf(value, 0.0)
	return true


func get_stun_time(handle: int) -> float:
	var slot := _slot_if_valid(handle)
	return float(_stun_times[slot]) if slot >= 0 else 0.0


func set_stun_time(handle: int, seconds: float) -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0 or _representations[slot] == Types.Representation.DYING:
		return false
	_stun_times[slot] = maxf(seconds, 0.0)
	return true


func extend_stun_time(handle: int, seconds: float) -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0 or _representations[slot] == Types.Representation.DYING or seconds <= 0.0:
		return false
	_stun_times[slot] = maxf(float(_stun_times[slot]), seconds)
	return true


func get_proxy_update_time(handle: int) -> float:
	var slot := _slot_if_valid(handle)
	return float(_proxy_update_times[slot]) if slot >= 0 else 0.0


func set_proxy_update_time(handle: int, value: float) -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0:
		return false
	_proxy_update_times[slot] = maxf(value, 0.0)
	return true


func get_health(handle: int) -> float:
	var slot := _slot_if_valid(handle)
	return float(_health[slot]) if slot >= 0 else 0.0


func get_max_health(handle: int) -> float:
	var slot := _slot_if_valid(handle)
	return float(_max_health[slot]) if slot >= 0 else 0.0


func set_health(handle: int, value: float) -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0:
		return false
	if _representations[slot] == Types.Representation.DYING and value > 0.0:
		return false
	_health[slot] = clampf(value, 0.0, float(_max_health[slot]))
	return true


func set_max_health(handle: int, value: float, fill_to_max: bool = false) -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0 or _representations[slot] == Types.Representation.DYING:
		return false
	var safe_max := maxf(value, 0.0)
	_max_health[slot] = safe_max
	_health[slot] = safe_max if fill_to_max else minf(float(_health[slot]), safe_max)
	return true


func heal(handle: int, amount: float) -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0 or amount <= 0.0 or _representations[slot] == Types.Representation.DYING:
		return false
	_health[slot] = minf(float(_health[slot]) + amount, float(_max_health[slot]))
	return true


func is_dying(handle: int) -> bool:
	var slot := _slot_if_valid(handle)
	return slot >= 0 and _representations[slot] == Types.Representation.DYING


func try_begin_death(handle: int) -> bool:
	var slot := _slot_if_valid(handle)
	if (
		slot < 0
		or _representations[slot] == Types.Representation.DYING
		or _health[slot] > 0.0
	):
		return false
	_representations[slot] = Types.Representation.DYING
	return true


func get_speed(handle: int) -> float:
	var slot := _slot_if_valid(handle)
	return float(_speeds[slot]) if slot >= 0 else 0.0


func set_speed(handle: int, value: float) -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0 or _representations[slot] == Types.Representation.DYING:
		return false
	_speeds[slot] = maxf(value, 0.0)
	return true


func get_collision_radius(handle: int) -> float:
	var slot := _slot_if_valid(handle)
	return float(_collision_radii[slot]) if slot >= 0 else 0.0


func largest_collision_radius() -> float:
	if not _largest_collision_radius_dirty:
		return _largest_collision_radius
	_largest_collision_radius = 0.0
	for slot_variant in _active_slots:
		var slot := int(slot_variant)
		_largest_collision_radius = maxf(_largest_collision_radius, float(_collision_radii[slot]))
	_largest_collision_radius_dirty = false
	return _largest_collision_radius


func get_spec_id(handle: int) -> StringName:
	var slot := _slot_if_valid(handle)
	return _spec_ids[slot] if slot >= 0 else StringName()


func get_scene_path(handle: int) -> String:
	var slot := _slot_if_valid(handle)
	return _scene_paths[slot] if slot >= 0 else ""


func get_ai_kind(handle: int) -> int:
	var slot := _slot_if_valid(handle)
	return int(_ai_kinds[slot]) if slot >= 0 else 0


func get_flags(handle: int) -> int:
	var slot := _slot_if_valid(handle)
	return int(_flags[slot]) if slot >= 0 else 0


func set_flags(handle: int, value: int) -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0:
		return false
	_flags[slot] = value
	return true


func get_representation(handle: int) -> int:
	var slot := _slot_if_valid(handle)
	return int(_representations[slot]) if slot >= 0 else Types.Representation.DATA_ONLY


func set_representation(handle: int, value: int) -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0:
		return false
	if (
		_representations[slot] == Types.Representation.DYING
		and value != Types.Representation.DYING
	):
		return false
	_representations[slot] = value
	return true


func get_cold_state(handle: int) -> Dictionary:
	var slot := _slot_if_valid(handle)
	return _cold_states[slot].duplicate(true) if slot >= 0 else {}


func replace_cold_state(handle: int, value: Dictionary) -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0:
		return false
	_cold_states[slot] = value.duplicate(true)
	return true


func bind_actor(handle: int, actor: Node2D) -> bool:
	if not is_valid_handle(handle):
		return false
	if actor == null or not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return false
	var current_actor := actor_for_handle(handle)
	if current_actor != null:
		return current_actor == actor
	var actor_id := int(actor.get_instance_id())
	var current_handle := int(_actor_handles.get(actor_id, Types.INVALID_HANDLE))
	if current_handle != Types.INVALID_HANDLE:
		if is_valid_handle(current_handle) and actor_for_handle(current_handle) == actor:
			return current_handle == handle
		_actor_handles.erase(actor_id)
	_actor_refs[handle] = weakref(actor)
	_actor_handles[actor_id] = handle
	_bound_instance_ids[handle] = actor_id
	set_representation(handle, Types.Representation.MATERIALIZED)
	return true


func unbind_actor(handle: int, actor: Node2D = null) -> bool:
	if not _actor_refs.has(handle):
		return false
	var bound_id := int(_bound_instance_ids.get(handle, 0))
	if actor != null:
		if not is_instance_valid(actor) or int(actor.get_instance_id()) != bound_id:
			return false
	_clear_binding_maps(handle)
	if (
		is_valid_handle(handle)
		and get_representation(handle) == Types.Representation.MATERIALIZED
	):
		set_representation(handle, Types.Representation.DATA_ONLY)
	return true


func actor_for_handle(handle: int) -> Node2D:
	if not is_valid_handle(handle):
		_clear_binding_maps(handle)
		return null
	var ref_variant: Variant = _actor_refs.get(handle)
	if ref_variant == null or not (ref_variant is WeakRef):
		_clear_binding_maps(handle)
		return null
	var actor_variant: Variant = (ref_variant as WeakRef).get_ref()
	if (
		actor_variant == null
		or not is_instance_valid(actor_variant)
		or not (actor_variant is Node2D)
	):
		_clear_binding_maps(handle)
		if get_representation(handle) == Types.Representation.MATERIALIZED:
			set_representation(handle, Types.Representation.DATA_ONLY)
		return null
	return actor_variant as Node2D


func handle_for_actor(actor: Node) -> int:
	if actor == null or not is_instance_valid(actor):
		return Types.INVALID_HANDLE
	var actor_id := int(actor.get_instance_id())
	var handle := int(_actor_handles.get(actor_id, Types.INVALID_HANDLE))
	if handle == Types.INVALID_HANDLE:
		return Types.INVALID_HANDLE
	if not is_valid_handle(handle) or actor_for_handle(handle) != actor:
		_actor_handles.erase(actor_id)
		return Types.INVALID_HANDLE
	return handle


func prune_invalid_bindings() -> int:
	var removed := 0
	var handles: Array = _actor_refs.keys().duplicate()
	for handle_variant in handles:
		var handle := int(handle_variant)
		if actor_for_handle(handle) == null:
			removed += 1
	return removed


func adopt_legacy_actor(actor: Node2D) -> int:
	if actor == null or not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return Types.INVALID_HANDLE
	var existing := handle_for_actor(actor)
	if existing != Types.INVALID_HANDLE:
		return existing
	var flags := _flags_from_actor(actor)
	var state := EnemySpawnState.new(
		_spec_id_from_actor(actor),
		actor.scene_file_path,
		actor.global_position,
		float(actor.get("max_hp")) if "max_hp" in actor else 1.0,
		float(actor.get("speed")) if "speed" in actor else 0.0,
		_collision_radius_from_actor(actor),
		_ai_kind_from_actor(actor),
		flags,
		_cold_state_from_actor(actor),
	)
	if "velocity" in actor:
		state.velocity = actor.get("velocity") as Vector2
	var handle := create_enemy(state)
	if handle == Types.INVALID_HANDLE:
		return handle
	if "hp" in actor:
		set_health(handle, float(actor.get("hp")))
	if "knockback_vel" in actor:
		set_knockback_velocity(handle, actor.get("knockback_vel") as Vector2)
	if "knockback_decay" in actor:
		set_knockback_decay(handle, float(actor.get("knockback_decay")))
	if "stun_time" in actor:
		set_stun_time(handle, float(actor.get("stun_time")))
	if not bind_actor(handle, actor):
		remove_enemy(handle, &"legacy_adopt_failed")
		return Types.INVALID_HANDLE
	_legacy_handles[handle] = true
	return handle


func sync_legacy_actor(actor: Node2D) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	var handle := handle_for_actor(actor)
	if handle == Types.INVALID_HANDLE or not _legacy_handles.has(handle):
		return false
	set_position(handle, actor.global_position)
	if "velocity" in actor:
		set_velocity(handle, actor.get("velocity") as Vector2)
	if "knockback_vel" in actor:
		set_knockback_velocity(handle, actor.get("knockback_vel") as Vector2)
	if "knockback_decay" in actor:
		set_knockback_decay(handle, float(actor.get("knockback_decay")))
	if "stun_time" in actor:
		set_stun_time(handle, float(actor.get("stun_time")))
	var flags := get_flags(handle)
	if "is_elite" in actor and bool(actor.get("is_elite")):
		flags |= Types.Flags.ELITE
	else:
		flags &= ~Types.Flags.ELITE
	set_flags(handle, flags)
	# EnemyActor implements this callback and treats the record as authoritative.
	# Generic legacy nodes keep the old one-way import until they are migrated.
	if actor.has_method("_apply_enemy_world_health"):
		actor.call("_apply_enemy_world_health", get_health(handle), get_max_health(handle))
	else:
		if "hp" in actor:
			set_health(handle, float(actor.get("hp")))
		if "dead" in actor and bool(actor.get("dead")):
			set_representation(handle, Types.Representation.DYING)
	if not is_dying(handle):
		set_representation(handle, Types.Representation.MATERIALIZED)
	return true


func release_legacy_actor(actor: Node2D, reason: StringName = &"legacy_unregistered") -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	var handle := handle_for_actor(actor)
	if handle == Types.INVALID_HANDLE or not _legacy_handles.has(handle):
		return false
	_legacy_handles.erase(handle)
	unbind_actor(handle, actor)
	return remove_enemy(handle, reason)


func rebuild_legacy_shadow(valid_enemies: Array) -> void:
	var legacy_handles: Array = _legacy_handles.keys().duplicate()
	for handle_variant in legacy_handles:
		var handle := int(handle_variant)
		if is_valid_handle(handle):
			remove_enemy(handle, &"legacy_rebuild")
	_legacy_handles.clear()
	for enemy_variant in valid_enemies:
		if (
			enemy_variant == null
			or not is_instance_valid(enemy_variant)
			or not (enemy_variant is Node2D)
		):
			continue
		var enemy := enemy_variant as Node2D
		if enemy.is_queued_for_deletion() or not enemy.is_inside_tree():
			continue
		adopt_legacy_actor(enemy)


func gather_in_radius(
	origin: Vector2,
	radius: float,
	out: Array[int],
	excluded_handle: int = Types.INVALID_HANDLE,
) -> void:
	out.clear()
	var safe_radius := maxf(radius, 0.0)
	var radius_squared := safe_radius * safe_radius
	var candidate_slots: Array[int] = []
	_grid.gather_candidate_slots(origin, safe_radius, candidate_slots)
	for slot in candidate_slots:
		if slot < 0 or slot >= _active.size() or _active[slot] == 0:
			continue
		var handle := Types.make_handle(slot, int(_generations[slot]))
		if handle == excluded_handle:
			continue
		if origin.distance_squared_to(_positions[slot]) <= radius_squared:
			out.append(handle)


func nearest_enemy(
	origin: Vector2,
	max_distance: float,
	excluded_handle: int = Types.INVALID_HANDLE,
) -> int:
	var candidates: Array[int] = []
	gather_in_radius(origin, max_distance, candidates, excluded_handle)
	var best_handle := Types.INVALID_HANDLE
	var best_distance_squared := maxf(max_distance, 0.0) * maxf(max_distance, 0.0)
	for handle in candidates:
		var distance_squared := origin.distance_squared_to(get_position(handle))
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_handle = handle
	return best_handle


func clear_world() -> void:
	var handles: Array[int] = []
	active_handles(handles)
	for handle in handles:
		remove_enemy(handle, &"world_cleared")


func get_debug_counters() -> Dictionary:
	return {
		"logical": _active_slots.size(),
		"capacity": _active.size(),
		"free_slots": _free_slots.size(),
		"materialized": _count_representation(Types.Representation.MATERIALIZED),
		"data_only": _count_representation(Types.Representation.DATA_ONLY),
		"dying": _count_representation(Types.Representation.DYING),
		"spatial_cells": _grid.active_cell_count(),
		"max_cell_occupancy": _grid.max_cell_occupancy(),
		"removed_by_reason": _removed_by_reason.duplicate(),
	}


func _append_slot_storage() -> int:
	var slot := _active.size()
	var next_size := slot + 1
	_active.resize(next_size)
	_generations.resize(next_size)
	_positions.resize(next_size)
	_previous_positions.resize(next_size)
	_velocities.resize(next_size)
	_facings.resize(next_size)
	_knockback_velocities.resize(next_size)
	_knockback_decays.resize(next_size)
	_stun_times.resize(next_size)
	_proxy_update_times.resize(next_size)
	_health.resize(next_size)
	_max_health.resize(next_size)
	_speeds.resize(next_size)
	_collision_radii.resize(next_size)
	_ai_kinds.resize(next_size)
	_flags.resize(next_size)
	_representations.resize(next_size)
	_active_slot_indices.resize(next_size)
	_spec_ids.resize(next_size)
	_scene_paths.resize(next_size)
	_cold_states.resize(next_size)
	_generations[slot] = 1
	_active_slot_indices[slot] = -1
	_spec_ids[slot] = StringName()
	_cold_states[slot] = {}
	return slot


func _slot_if_valid(handle: int) -> int:
	var slot := Types.slot_from_handle(handle)
	if slot < 0 or slot >= _active.size():
		return -1
	if _active[slot] == 0:
		return -1
	if int(_generations[slot]) != Types.generation_from_handle(handle):
		return -1
	return slot


func _remove_active_slot(slot: int) -> void:
	var active_index := int(_active_slot_indices[slot])
	var last_index := _active_slots.size() - 1
	if active_index != last_index:
		var moved_slot := int(_active_slots[last_index])
		_active_slots[active_index] = moved_slot
		_active_slot_indices[moved_slot] = active_index
	_active_slots.resize(last_index)
	_active_slot_indices[slot] = -1


func _next_generation(current: int) -> int:
	if current >= 0x7FFFFFFF:
		return 1
	return current + 1


func _count_representation(value: int) -> int:
	var count := 0
	for slot_variant in _active_slots:
		var slot := int(slot_variant)
		if int(_representations[slot]) == value:
			count += 1
	return count


func _clear_binding_maps(handle: int) -> void:
	var actor_id := int(_bound_instance_ids.get(handle, 0))
	_actor_refs.erase(handle)
	_bound_instance_ids.erase(handle)
	if actor_id != 0 and int(_actor_handles.get(actor_id, Types.INVALID_HANDLE)) == handle:
		_actor_handles.erase(actor_id)


func _spec_id_from_actor(actor: Node2D) -> StringName:
	var base_name := actor.scene_file_path.get_file().get_basename()
	if base_name.is_empty():
		base_name = actor.name
	return StringName(base_name.trim_prefix("Enemy").to_snake_case())


func _collision_radius_from_actor(actor: Node2D) -> float:
	var collision := actor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		return maxf((collision.shape as CircleShape2D).radius, 0.0)
	return 24.0


func _ai_kind_from_actor(actor: Node2D) -> int:
	if actor.has_method("_get_active_ai"):
		return int(actor.call("_get_active_ai"))
	if "spec" in actor:
		var spec_variant: Variant = actor.get("spec")
		if spec_variant != null and "ai" in spec_variant:
			return int(spec_variant.get("ai"))
	return 0


func _flags_from_actor(actor: Node) -> int:
	var flags: int = Types.Flags.NONE
	if "is_elite" in actor and bool(actor.get("is_elite")):
		flags |= Types.Flags.ELITE
	var boss_like := (
		actor.is_in_group(&"boss_like")
		or actor.is_in_group(&"boss")
		or actor.is_in_group(&"miniboss")
	)
	var objective_required := bool(actor.get_meta(&"objective_required", false))
	var tutorial_actor := (
		bool(actor.get_meta(&"tutorial_actor", false))
		or bool(actor.get_meta(&"opening_scripted", false))
		or actor.is_in_group(&"opening_scripted_actor")
	)
	if boss_like:
		flags |= Types.Flags.CRITICAL | Types.Flags.NEVER_RETIRE
	if objective_required:
		flags |= Types.Flags.CRITICAL | Types.Flags.OBJECTIVE | Types.Flags.NEVER_RETIRE
	if tutorial_actor:
		flags |= Types.Flags.CRITICAL | Types.Flags.TUTORIAL | Types.Flags.NEVER_RETIRE
	if bool(actor.get_meta(&"never_cull", false)):
		flags |= Types.Flags.NEVER_RETIRE
	if actor.has_meta(&"special_spawn_kind"):
		flags |= Types.Flags.SPECIAL
	return flags


func _cold_state_from_actor(actor: Node2D) -> Dictionary:
	if actor.has_method("_build_enemy_world_cold_state"):
		var value: Variant = actor.call("_build_enemy_world_cold_state")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}
