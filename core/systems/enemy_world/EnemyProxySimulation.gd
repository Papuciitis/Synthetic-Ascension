class_name EnemyProxySimulation
extends Node

const Types = preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")

const CHASE_AI_KIND := 0
const EXCLUDED_FLAGS := (
	Types.Flags.ELITE
	| Types.Flags.CRITICAL
	| Types.Flags.OBJECTIVE
	| Types.Flags.TUTORIAL
	| Types.Flags.NEVER_RETIRE
	| Types.Flags.SPECIAL
)

var normal_update_hz := 10.0
var pressure_update_hz := 6.0
var emergency_update_hz := 3.0
var normal_slice_count := 6
var pressure_slice_count := 8
var emergency_slice_count := 12
var update_hz := 10.0
var slice_count := 6
var max_slices_per_advance := 24

var _world: EnemyWorldService = null
var _clock := 0.0
var _slice_accumulator := 0.0
var _slice_cursor := 0
var _handles: Array[int] = []
var _direction_provider: Callable
var _total_updates := 0
var _total_slices := 0
var _last_updates := 0
var _last_elapsed_usec := 0


func setup(world: EnemyWorldService) -> void:
	_world = world
	_clock = 0.0
	_slice_accumulator = 0.0
	_slice_cursor = 0
	_total_updates = 0
	_total_slices = 0
	_last_updates = 0
	_last_elapsed_usec = 0


func set_direction_provider(provider: Callable) -> void:
	_direction_provider = provider


func set_pressure_level(level: int) -> void:
	var previous_hz := update_hz
	if level >= 2:
		update_hz = emergency_update_hz
		slice_count = emergency_slice_count
	elif level >= 1:
		update_hz = pressure_update_hz
		slice_count = pressure_slice_count
	else:
		update_hz = normal_update_hz
		slice_count = normal_slice_count
	if (
		not is_equal_approx(previous_hz, update_hz)
		and previous_hz > 0.0
		and _world != null
		and is_instance_valid(_world)
	):
		_world.rebase_proxy_interpolation(_clock, 1.0 / previous_hz)


func advance(delta: float, target_position: Vector2) -> int:
	_last_updates = 0
	_last_elapsed_usec = 0
	if _world == null or not is_instance_valid(_world) or delta <= 0.0 or update_hz <= 0.0:
		return 0
	var started := Time.get_ticks_usec()
	_clock += delta
	_slice_accumulator += delta
	var safe_slice_count := maxi(1, slice_count)
	var fixed_delta := 1.0 / update_hz
	var slice_interval := fixed_delta / float(safe_slice_count)
	var due_slices := mini(
		maxi(0, int(floor((_slice_accumulator + 0.000001) / slice_interval))),
		maxi(1, max_slices_per_advance),
	)
	if due_slices <= 0:
		_last_elapsed_usec = Time.get_ticks_usec() - started
		return 0
	_slice_accumulator = maxf(0.0, _slice_accumulator - float(due_slices) * slice_interval)
	# Avoid a resume hitch after a long pause; excess old time is intentionally
	# discarded instead of simulating an unbounded catch-up train.
	_slice_accumulator = minf(_slice_accumulator, fixed_delta)
	_world.active_handles(_handles)
	for _slice_index in range(due_slices):
		_last_updates += _simulate_slice(
			_handles,
			_slice_cursor,
			safe_slice_count,
			fixed_delta,
			target_position,
		)
		_slice_cursor = (_slice_cursor + 1) % safe_slice_count
		_total_slices += 1
	_total_updates += _last_updates
	_last_elapsed_usec = Time.get_ticks_usec() - started
	return _last_updates


func interpolated_position(handle: int, alpha: float = -1.0) -> Vector2:
	if _world == null or not _world.is_valid_handle(handle):
		return Vector2.ZERO
	var blend := alpha
	if blend < 0.0:
		var fixed_delta := 1.0 / maxf(update_hz, 0.001)
		blend = (_clock - _world.get_proxy_update_time(handle)) / fixed_delta
	blend = clampf(blend, 0.0, 1.0)
	return _world.get_previous_position(handle).lerp(_world.get_position(handle), blend)


func clock() -> float:
	return _clock


func update_interval() -> float:
	return 1.0 / maxf(update_hz, 0.001)


func interpolation_phase() -> float:
	# Global fraction of the current fixed step, for renderer interpolation.
	# Per-handle phases differ by at most one slice (~a frame), which is not
	# visually distinguishable.
	if update_hz <= 0.0:
		return 1.0
	var fixed_delta := 1.0 / update_hz
	return clampf(fmod(_clock, fixed_delta) / fixed_delta, 0.0, 1.0)


func get_debug_counters() -> Dictionary:
	return {
		"clock": _clock,
		"slice": _slice_cursor,
		"total_slices": _total_slices,
		"last_updates": _last_updates,
		"total_updates": _total_updates,
		"last_usec": _last_elapsed_usec,
	}


func _simulate_slice(
	handles: Array[int],
	cursor: int,
	safe_slice_count: int,
	fixed_delta: float,
	target_position: Vector2,
) -> int:
	var updates := 0
	for index in range(cursor, handles.size(), safe_slice_count):
		var handle := handles[index]
		if not _is_proxy_chase(handle):
			continue
		_simulate_chase(handle, fixed_delta, target_position)
		updates += 1
	return updates


func _is_proxy_chase(handle: int) -> bool:
	return (
		_world.is_valid_handle(handle)
		and not _world.is_dying(handle)
		and _world.get_representation(handle) == Types.Representation.DATA_ONLY
		and _world.get_ai_kind(handle) == CHASE_AI_KIND
		and (_world.get_flags(handle) & EXCLUDED_FLAGS) == 0
	)


func _simulate_chase(handle: int, delta: float, target_position: Vector2) -> void:
	var position := _world.get_position(handle)
	# Where the renderer is drawing this proxy right now. Normally a step lands
	# exactly one interval after the last one (blend 1, origin = position); after
	# a rate change or slice re-mapping it can land mid-blend, and the new
	# blend must start from the drawn point or the proxy snaps forward.
	var step_blend := clampf((_clock - _world.get_proxy_update_time(handle)) * update_hz, 0.0, 1.0)
	var drawn_origin := position
	if step_blend < 0.999:
		drawn_origin = _world.get_previous_position(handle).lerp(position, step_blend)
	var knockback := _world.get_knockback_velocity(handle)
	knockback = knockback.move_toward(
		Vector2.ZERO,
		_world.get_knockback_decay(handle) * delta,
	)
	_world.set_knockback_velocity(handle, knockback)

	var velocity := knockback
	var stun_left := _world.get_stun_time(handle)
	if stun_left > 0.0:
		_world.set_stun_time(handle, maxf(0.0, stun_left - delta))
	else:
		var direction := _direction_for(handle, position, target_position)
		velocity += direction * _world.get_speed(handle)
		if direction != Vector2.ZERO:
			_world.set_facing(handle, direction)

	var next_position := position + velocity * delta
	if not next_position.is_finite():
		velocity = Vector2.ZERO
		next_position = position
	_world.set_velocity(handle, velocity)
	_world.set_position(handle, next_position)
	if step_blend < 0.999:
		_world.set_previous_position(handle, drawn_origin)
	_world.set_proxy_update_time(handle, _clock)


func _direction_for(handle: int, position: Vector2, target_position: Vector2) -> Vector2:
	if _direction_provider.is_valid():
		var result: Variant = _direction_provider.call(handle, position, target_position)
		if result is Vector2:
			return (result as Vector2).normalized()
	var offset := target_position - position
	return offset.normalized() if offset != Vector2.ZERO else Vector2.ZERO
