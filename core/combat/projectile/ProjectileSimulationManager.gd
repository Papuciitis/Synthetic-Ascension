extends Node2D
class_name ProjectileSimulationManager

## Dense-array simulation for ordinary, straight ballistic projectiles.
## Exotic homing/reflection/mine/beam attacks remain node-owned by design.

enum Team { PLAYER, ENEMY }
enum Visual { PLAYER_BLUE, PLAYER_FIRE, ENEMY_BLUE, ENEMY_GREEN, ENEMY_VIOLET }

const IMPACT_SCENE := preload("res://assets/vfx/world/sets/conduit/VFX_SpokesBurst.tscn")
const DEFAULT_CAPACITY: int = 4096
const PLAYER_RADIUS: float = 25.0

var capacity: int = DEFAULT_CAPACITY
var _positions := PackedVector2Array()
var _previous := PackedVector2Array()
var _velocities := PackedVector2Array()
var _life_left := PackedFloat32Array()
var _range_left := PackedFloat32Array()
var _radii := PackedFloat32Array()
var _damage := PackedFloat32Array()
var _knockback := PackedFloat32Array()
var _burn_duration := PackedFloat32Array()
var _burn_tick := PackedFloat32Array()
var _burn_mult := PackedFloat32Array()
var _body_length := PackedFloat32Array()
var _body_width := PackedFloat32Array()
var _teams := PackedInt32Array()
var _visuals := PackedInt32Array()
var _pierce := PackedInt32Array()
var _burn_stacks := PackedInt32Array()
var _crit := PackedByteArray()
var _last_hit_handles := PackedInt64Array()
var _colors := PackedColorArray()
var _sources: Array = []
var _active_count: int = 0

var _chunk_manager: ChunkManager = null
var _player: Node2D = null
var _pending_ledgers: Dictionary = {}
var _renderer: MultiMeshInstance2D = null
var _multimesh: MultiMesh = null
var _render_buffer := PackedFloat32Array()
var _last_scene_id: int = 0
var _query_hit_handle: int = 0
var _query_hit_t: float = -1.0

var _hits_this_frame: int = 0
var _batches_this_frame: int = 0
var _dropped_total: int = 0
var _last_physics_ms: float = 0.0
var _stress_started: bool = false
var _last_stress_enabled: bool = false
var _debug_label: Label = null

func _ready() -> void:
	z_index = 200
	add_to_group(&"projectile_simulation_manager")
	_build_renderer()
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	var started_us := Time.get_ticks_usec()
	var stress_enabled: bool = Global != null and Global.debug_projectile_stress_test
	if stress_enabled != _last_stress_enabled:
		_last_stress_enabled = stress_enabled
		if PerformanceFlightRecorder != null:
			PerformanceFlightRecorder.record_event(&"projectile", &"stress_toggled", {"enabled": stress_enabled})
	_sync_scene_refs()
	_hits_this_frame = 0
	_batches_this_frame = 0
	_pending_ledgers.clear()
	if Global != null and Global.debug_projectile_stress_test:
		_run_stress_step()
	for i in range(_active_count - 1, -1, -1):
		_simulate_one(i, delta)
	_flush_hit_ledgers()
	_update_renderer()
	_last_physics_ms = float(Time.get_ticks_usec() - started_us) / 1000.0
	_update_debug_overlay()

func spawn_player(origin: Vector2, direction: Vector2, profile: HitProfileAdapter, source: Node) -> bool:
	if profile == null:
		return false
	var visual := Visual.PLAYER_FIRE if profile.has_meta("burn_duration") else Visual.PLAYER_BLUE
	var burn_time := float(profile.get_meta("burn_duration", 0.0))
	var burn_interval := float(profile.get_meta("burn_tick", 0.5))
	var burn_stack_count := int(profile.get_meta("burn_stacks", 0))
	var burn_tick_mult := float(profile.get_meta("burn_tick_mult", 0.0))
	return _spawn(origin, direction.normalized() * profile.speed, maxf(0.05, profile.max_range / maxf(profile.speed, 1.0) + 0.1), profile.max_range, profile.collision_radius, profile.damage, Team.PLAYER, visual, source, profile.knockback, profile.pierce, profile.critical, burn_stack_count, burn_time, burn_interval, burn_tick_mult, profile.body_len, profile.body_width, profile.body_core)

func spawn_enemy(origin: Vector2, direction: Vector2, speed: float, damage: float, lifetime: float, source: Node, enemy_id: StringName = &"") -> bool:
	var visual := Visual.ENEMY_BLUE
	var color := Color(0.95, 0.98, 1.0, 1.0)
	if enemy_id == &"enemy_spitter":
		visual = Visual.ENEMY_GREEN
		color = Color(0.75, 1.0, 0.25, 1.0)
	elif enemy_id == &"enemy_herald":
		visual = Visual.ENEMY_VIOLET
		color = Color(1.0, 0.70, 0.35, 1.0)
	return _spawn(origin, direction.normalized() * speed, lifetime, speed * lifetime, 5.0, damage, Team.ENEMY, visual, source, 0.0, 0, false, 0, 0.0, 0.5, 0.0, 18.0, 4.0, color)

func _spawn(origin: Vector2, velocity: Vector2, lifetime: float, max_range: float, radius: float, damage: float, team: int, visual: int, source: Node, knockback: float, pierce: int, critical: bool, burn_stacks: int, burn_duration: float, burn_tick: float, burn_mult: float, body_len: float, body_width: float, color: Color) -> bool:
	if _active_count >= capacity:
		_dropped_total += 1
		if PerformanceFlightRecorder != null:
			PerformanceFlightRecorder.record_counter_event(&"projectile", &"capacity_dropped", 1, {"capacity": capacity})
		return false
	var index := _active_count
	if _positions.size() > index:
		# Reuse a retained slot: arrays keep their high-water capacity so churn
		# never reallocates them.
		_positions[index] = origin
		_previous[index] = origin
		_velocities[index] = velocity
		_life_left[index] = maxf(0.01, lifetime)
		_range_left[index] = maxf(0.0, max_range)
		_radii[index] = maxf(1.0, radius)
		_damage[index] = maxf(0.0, damage)
		_knockback[index] = maxf(0.0, knockback)
		_burn_duration[index] = maxf(0.0, burn_duration)
		_burn_tick[index] = maxf(0.05, burn_tick)
		_burn_mult[index] = maxf(0.0, burn_mult)
		_body_length[index] = maxf(2.0, body_len)
		_body_width[index] = maxf(1.0, body_width)
		_teams[index] = team
		_visuals[index] = visual
		_pierce[index] = maxi(0, pierce)
		_burn_stacks[index] = maxi(0, burn_stacks)
		_crit[index] = 1 if critical else 0
		_last_hit_handles[index] = 0
		_colors[index] = color
		_sources[index] = source
	else:
		_positions.append(origin)
		_previous.append(origin)
		_velocities.append(velocity)
		_life_left.append(maxf(0.01, lifetime))
		_range_left.append(maxf(0.0, max_range))
		_radii.append(maxf(1.0, radius))
		_damage.append(maxf(0.0, damage))
		_knockback.append(maxf(0.0, knockback))
		_burn_duration.append(maxf(0.0, burn_duration))
		_burn_tick.append(maxf(0.05, burn_tick))
		_burn_mult.append(maxf(0.0, burn_mult))
		_body_length.append(maxf(2.0, body_len))
		_body_width.append(maxf(1.0, body_width))
		_teams.append(team)
		_visuals.append(visual)
		_pierce.append(maxi(0, pierce))
		_burn_stacks.append(maxi(0, burn_stacks))
		_crit.append(1 if critical else 0)
		_last_hit_handles.append(0)
		_colors.append(color)
		_sources.append(source)
	_active_count += 1
	return true

func _simulate_one(index: int, delta: float) -> void:
	if index >= _active_count:
		return
	var old_pos := _positions[index]
	var movement := _velocities[index] * delta
	var new_pos := old_pos + movement
	_previous[index] = old_pos
	_life_left[index] -= delta
	_range_left[index] -= movement.length()
	var world_t := _world_hit_t(old_pos, new_pos, _radii[index])
	var target: Node2D = null
	var target_handle: int = 0
	var target_t := -1.0
	if _teams[index] == Team.PLAYER:
		if _query_first_enemy_hit(old_pos, new_pos, _radii[index], _last_hit_handles[index]):
			target_handle = _query_hit_handle
			target_t = _query_hit_t
	else:
		target = _player
		if target != null and is_instance_valid(target):
			target_t = _segment_circle_t(old_pos, new_pos, target.global_position, PLAYER_RADIUS + _radii[index])

	if world_t >= 0.0 and (target_t < 0.0 or world_t <= target_t):
		_remove(index)
		return
	if target_handle != 0 and target_t >= 0.0:
		var hit_pos := old_pos.lerp(new_pos, target_t)
		_queue_handle_hit(index, target_handle, hit_pos)
		if _pierce[index] <= 0:
			_remove(index)
			return
		_pierce[index] -= 1
		_last_hit_handles[index] = target_handle
	elif target != null and target_t >= 0.0:
		var hit_pos := old_pos.lerp(new_pos, target_t)
		_queue_node_hit(index, target, hit_pos)
		if _pierce[index] <= 0:
			_remove(index)
			return
		_pierce[index] -= 1
	_positions[index] = new_pos
	if _life_left[index] <= 0.0 or _range_left[index] <= 0.0:
		_remove(index)

func _query_first_enemy_hit(from: Vector2, to: Vector2, radius: float, excluded_handle: int) -> bool:
	_query_hit_handle = 0
	_query_hit_t = -1.0
	if EnemyCombat == null:
		return false
	_query_hit_handle = EnemyCombat.first_enemy_on_segment(from, to, radius, excluded_handle)
	if _query_hit_handle == 0:
		return false
	_query_hit_t = EnemyCombat.last_segment_hit_t()
	return true


func debug_last_enemy_hit() -> Dictionary:
	return {
		"handle": _query_hit_handle,
		"target": EnemyCombat.actor_for_handle(_query_hit_handle) if _query_hit_handle != 0 else null,
		"t": _query_hit_t,
	}

func _segment_circle_t(from: Vector2, to: Vector2, center: Vector2, radius: float) -> float:
	var segment := to - from
	var len2 := segment.length_squared()
	if len2 <= 0.000001:
		return 0.0 if from.distance_squared_to(center) <= radius * radius else -1.0
	var t := clampf((center - from).dot(segment) / len2, 0.0, 1.0)
	return t if from.lerp(to, t).distance_squared_to(center) <= radius * radius else -1.0

func _world_hit_t(from: Vector2, to: Vector2, radius: float) -> float:
	if _chunk_manager == null or not is_instance_valid(_chunk_manager):
		return -1.0
	return _chunk_manager.projectile_hit_t(from, to, radius)

func _queue_handle_hit(index: int, target_handle: int, hit_position: Vector2) -> void:
	if target_handle == 0 or not EnemyWorld.is_valid_handle(target_handle):
		return
	_hits_this_frame += 1
	var ledger: HitLedger = _pending_ledgers.get(target_handle, null) as HitLedger
	if ledger == null:
		ledger = HitLedger.new()
		ledger.target_handle = target_handle
		_pending_ledgers[target_handle] = ledger
	_add_projectile_to_ledger(index, ledger)
	if _teams[index] == Team.PLAYER:
		_spawn_impact(hit_position)


func _queue_node_hit(index: int, target: Node, hit_position: Vector2) -> void:
	if target == null or not is_instance_valid(target):
		return
	_hits_this_frame += 1
	var target_id := target.get_instance_id()
	var ledger: HitLedger = _pending_ledgers.get(target_id, null) as HitLedger
	if ledger == null:
		ledger = HitLedger.new()
		ledger.target = target
		_pending_ledgers[target_id] = ledger
	_add_projectile_to_ledger(index, ledger)
	if _teams[index] == Team.PLAYER:
		_spawn_impact(hit_position)


func _add_projectile_to_ledger(index: int, ledger: HitLedger) -> void:
	# A queued projectile may outlive its firing node. Check the raw Variant before
	# casting it; casting a stale Object reference raises "Trying to cast a freed object".
	var source: Node = null
	var source_value: Variant = _sources[index]
	if is_instance_valid(source_value):
		source = source_value as Node
	var direction := _velocities[index].normalized()
	ledger.add_resolved_hit(_damage[index], source, direction * _knockback[index], _crit[index] != 0, _burn_stacks[index], _burn_duration[index], _burn_tick[index], _damage[index] * _burn_mult[index])

func _flush_hit_ledgers() -> void:
	_batches_this_frame = _pending_ledgers.size()
	for value in _pending_ledgers.values():
		var ledger := value as HitLedger
		if ledger == null:
			continue
		if ledger.target_handle != 0:
			EnemyCombat.apply_hit_ledger(ledger.target_handle, ledger)
		elif ledger.target != null and is_instance_valid(ledger.target) and ledger.target.has_method("apply_hit_ledger"):
			ledger.target.call("apply_hit_ledger", ledger)
		elif ledger.target != null and is_instance_valid(ledger.target) and ledger.target.has_method("take_damage"):
			ledger.target.call("take_damage", ledger.total_raw_damage, ledger.source)

func _spawn_impact(world_position: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var impact := IMPACT_SCENE.instantiate()
	scene.add_child(impact)
	if impact.has_method("setup"):
		impact.call("setup", world_position)

func _remove(index: int) -> void:
	var last := _active_count - 1
	if index < 0 or index > last:
		return
	if index != last:
		_positions[index] = _positions[last]
		_previous[index] = _previous[last]
		_velocities[index] = _velocities[last]
		_life_left[index] = _life_left[last]
		_range_left[index] = _range_left[last]
		_radii[index] = _radii[last]
		_damage[index] = _damage[last]
		_knockback[index] = _knockback[last]
		_burn_duration[index] = _burn_duration[last]
		_burn_tick[index] = _burn_tick[last]
		_burn_mult[index] = _burn_mult[last]
		_body_length[index] = _body_length[last]
		_body_width[index] = _body_width[last]
		_teams[index] = _teams[last]
		_visuals[index] = _visuals[last]
		_pierce[index] = _pierce[last]
		_burn_stacks[index] = _burn_stacks[last]
		_crit[index] = _crit[last]
		_last_hit_handles[index] = _last_hit_handles[last]
		_colors[index] = _colors[last]
		_sources[index] = _sources[last]
	# Keep the high-water capacity: shrinking 21 packed arrays per despawn was
	# a realloc + copy storm at bullet-heaven churn rates. Only the released
	# source reference is cleared so it cannot pin a freed node's Variant.
	_sources[last] = null
	_active_count -= 1

func _clear_all() -> void:
	while _active_count > 0:
		_remove(_active_count - 1)
	_update_renderer()

func clear_for_run_end() -> void:
	# Public lifecycle hook used before pausing or replacing the active run scene.
	_pending_ledgers.clear()
	_clear_all()

func _sync_scene_refs() -> void:
	var scene := get_tree().current_scene
	var scene_id := scene.get_instance_id() if scene != null else 0
	if scene_id != _last_scene_id:
		_clear_all()
		_last_scene_id = scene_id
		_stress_started = false
		_chunk_manager = get_tree().get_first_node_in_group(&"chunk_manager") as ChunkManager
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
		return
	if _chunk_manager == null or not is_instance_valid(_chunk_manager):
		_chunk_manager = get_tree().get_first_node_in_group(&"chunk_manager") as ChunkManager
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node2D

func _build_renderer() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(18.0, 4.0)
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.mesh = quad
	_multimesh.instance_count = capacity
	_multimesh.visible_instance_count = 0
	_renderer = MultiMeshInstance2D.new()
	_renderer.name = "BatchedBulletRenderer"
	_renderer.multimesh = _multimesh
	_renderer.z_index = 200
	var bullet_material := CanvasItemMaterial.new()
	bullet_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_renderer.material = bullet_material
	add_child(_renderer)

func _update_renderer() -> void:
	if _multimesh == null:
		return
	# One buffer upload instead of two RenderingServer calls per projectile per
	# frame (~600 calls at typical bullet counts). Layout per instance:
	# 8 floats of 2D transform rows, then 4 floats of color.
	var expected_size := capacity * 12
	if _render_buffer.size() != expected_size:
		_render_buffer.resize(expected_size)
	for i in range(_active_count):
		var base := i * 12
		var direction := _velocities[i]
		var length := direction.length()
		var cos_a := 1.0
		var sin_a := 0.0
		if length > 0.000001:
			cos_a = direction.x / length
			sin_a = direction.y / length
		var scale_x := _body_length[i] / 18.0
		var scale_y := _body_width[i] / 4.0
		var projectile_position := _positions[i]
		var color := _colors[i]
		_render_buffer[base + 0] = cos_a * scale_x
		_render_buffer[base + 1] = -sin_a * scale_y
		_render_buffer[base + 2] = 0.0
		_render_buffer[base + 3] = projectile_position.x
		_render_buffer[base + 4] = sin_a * scale_x
		_render_buffer[base + 5] = cos_a * scale_y
		_render_buffer[base + 6] = 0.0
		_render_buffer[base + 7] = projectile_position.y
		_render_buffer[base + 8] = color.r
		_render_buffer[base + 9] = color.g
		_render_buffer[base + 10] = color.b
		_render_buffer[base + 11] = color.a
	RenderingServer.multimesh_set_buffer(_multimesh.get_rid(), _render_buffer)
	_multimesh.emit_changed()
	_multimesh.visible_instance_count = _active_count

func get_debug_counters() -> Dictionary:
	return {"active": _active_count, "visuals": _active_count, "hits": _hits_this_frame, "batches": _batches_this_frame, "capacity": capacity, "dropped": _dropped_total, "physics_ms": _last_physics_ms}

func active_count() -> int:
	return _active_count

func _run_stress_step() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if not _stress_started:
		_stress_started = true
		for i in range(100):
			var dir := Vector2.RIGHT.rotated(TAU * float(i) / 100.0)
			_spawn(_player.global_position, dir * 760.0, 2.0, 1500.0, 4.0, 1.0, Team.PLAYER, i % 5, _player, 0.0, 0, false, 0, 0.0, 0.5, 0.0, 16.0, 3.0, _stress_color(i % 5))
	if _active_count < 550:
		for i in range(8):
			var dir := Vector2.RIGHT.rotated(Global._rng.randf() * TAU)
			var visual: int = Global._rng.randi_range(0, 4)
			_spawn(_player.global_position, dir * Global._rng.randf_range(500.0, 900.0), 2.5, 1800.0, 4.0, 1.0, Team.PLAYER, visual, _player, 0.0, 0, false, 0, 0.0, 0.5, 0.0, 16.0, 3.0, _stress_color(visual))

func _stress_color(visual: int) -> Color:
	match visual:
		Visual.PLAYER_FIRE: return Color(1.0, 0.45, 0.1, 1.0)
		Visual.ENEMY_GREEN: return Color(0.5, 1.0, 0.2, 1.0)
		Visual.ENEMY_VIOLET: return Color(0.85, 0.3, 1.0, 1.0)
		Visual.ENEMY_BLUE: return Color(0.3, 0.7, 1.0, 1.0)
		_: return Color(0.9, 0.98, 1.0, 1.0)

func _update_debug_overlay() -> void:
	var enabled: bool = Global != null and Global.debug_projectile_stress_test
	if enabled and _debug_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 250
		add_child(layer)
		_debug_label = Label.new()
		_debug_label.position = Vector2(24, 180)
		_debug_label.add_theme_font_size_override("font_size", 16)
		layer.add_child(_debug_label)
	if _debug_label != null:
		_debug_label.visible = enabled
		if enabled:
			_debug_label.text = "PROJECTILES  active:%d  visuals:%d  hits:%d  batches:%d\ncapacity:%d  dropped:%d  physics step:%.2f ms" % [_active_count, _active_count, _hits_this_frame, _batches_this_frame, capacity, _dropped_total, _last_physics_ms]
