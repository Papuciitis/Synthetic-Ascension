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


func _init() -> void:
	_grid = SpatialGrid.new(cell_size)


func _ready() -> void:
	if _active.is_empty() and not is_equal_approx(_grid.cell_size, cell_size):
		_grid = SpatialGrid.new(cell_size)


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
	_health[slot] = clampf(state.health, 0.0, state.max_health)
	_max_health[slot] = maxf(state.max_health, 0.0)
	_speeds[slot] = maxf(state.speed, 0.0)
	_collision_radii[slot] = maxf(state.collision_radius, 0.0)
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
	_grid.remove(slot)
	_remove_active_slot(slot)
	_active[slot] = 0
	_positions[slot] = Vector2.ZERO
	_previous_positions[slot] = Vector2.ZERO
	_velocities[slot] = Vector2.ZERO
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


func get_velocity(handle: int) -> Vector2:
	var slot := _slot_if_valid(handle)
	return _velocities[slot] if slot >= 0 else Vector2.ZERO


func set_velocity(handle: int, value: Vector2) -> bool:
	var slot := _slot_if_valid(handle)
	if slot < 0:
		return false
	_velocities[slot] = value
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
	_health[slot] = clampf(value, 0.0, float(_max_health[slot]))
	return true


func get_speed(handle: int) -> float:
	var slot := _slot_if_valid(handle)
	return float(_speeds[slot]) if slot >= 0 else 0.0


func get_collision_radius(handle: int) -> float:
	var slot := _slot_if_valid(handle)
	return float(_collision_radii[slot]) if slot >= 0 else 0.0


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
