extends RefCounted
class_name EnemyNavigator

# Point-to-point navigator (cheap):
# - SEEK: go straight if we have a clear ray corridor
# - WALL: follow obstacle boundary (bug algorithm) until we can leave cleanly
#
# Designed to work with your current EnemyActor + EnemySenses without requiring
# any extra exported vars. If you later add tuning vars on EnemyActor (wall_follow_*),
# this navigator will automatically pick them up via enemy.get(...).

enum Mode { SEEK, WALL }

var _enemy: EnemyActor = null
var _senses: EnemySenses = null

var _mode: int = Mode.SEEK

# wall-follow state
var _side: int = 1 # 1=left, -1=right
var _wall_normal: Vector2 = Vector2.ZERO
var _best_dist: float = INF
var _since_best: float = 0.0

# stuck detection
var _last_pos: Vector2 = Vector2.ZERO
var _stuck_time: float = 0.0

# helps avoid stale state when target changes drastically
var _last_target: Vector2 = Vector2.INF

# smoothing
var _smoothed_vel: Vector2 = Vector2.ZERO


func setup(enemy: EnemyActor, senses: EnemySenses) -> void:
	_enemy = enemy
	_senses = senses
	_reset_all()


func reset() -> void:
	_reset_all()


func apply(delta: float, target_pos: Vector2, speed: float, mask: int) -> Vector2:
	if _enemy == null or not is_instance_valid(_enemy):
		return Vector2.ZERO

	var pos: Vector2 = _enemy.global_position
	var to_target: Vector2 = target_pos - pos
	var dist: float = to_target.length()
	if dist < 1.0:
		_reset_all()
		return Vector2.ZERO

	var desired_dir: Vector2 = to_target / dist

	# If target jumps a lot (e.g. retarget), don't keep wall-follow state.
	if _last_target != Vector2.INF and _last_target.distance_to(target_pos) > 96.0:
		_reset_wall_only()
	_last_target = target_pos

	var nav_mask: int = _get_nav_mask(mask)
	if nav_mask == 0:
		return _smooth(desired_dir * speed, delta)

	var ex: Array[RID] = _build_excludes()

	_update_stuck(delta)

	# ---------- SEEK MODE ----------
	if _mode == Mode.SEEK:
		if _can_go_straight(pos, desired_dir, target_pos, nav_mask, ex):
			return _smooth(desired_dir * speed, delta)

		_enter_wall_follow(pos, desired_dir, dist, target_pos, nav_mask, ex)

	# ---------- WALL MODE ----------
	if dist < _best_dist - 3.0:
		_best_dist = dist
		_since_best = 0.0
	else:
		_since_best += delta

	var leave_slack: float = _f("wall_follow_leave_slack", 4.0)
	if _ray_clear(pos, target_pos, nav_mask, ex) and dist <= _best_dist + leave_slack:
		_mode = Mode.SEEK
		_wall_normal = Vector2.ZERO
		_since_best = 0.0
		_best_dist = dist
		if _can_go_straight(pos, desired_dir, target_pos, nav_mask, ex):
			return _smooth(desired_dir * speed, delta)

	var no_improve_flip: float = _f("wall_follow_no_improve_flip_time", 2.2)
	if _since_best > no_improve_flip:
		_since_best = 0.0
		_side *= -1
		_wall_normal = Vector2.ZERO

	return _smooth(_wall_follow_step(pos, desired_dir, speed, nav_mask, ex), delta)


func _get_nav_mask(mask: int) -> int:
	# Prefer the caller-provided obstacle mask (usually "world/cover" layers only).
	if mask != 0:
		return mask

	# Optional per-enemy override if you add it later.
	var v = _enemy.get(&"nav_obstacle_mask")
	if v != null and typeof(v) == TYPE_INT:
		return int(v)

	# Fallback: if you already have a cover/obstacle mask on enemy.
	v = _enemy.get(&"tactical_cover_mask")
	if v != null and typeof(v) == TYPE_INT:
		return int(v)

	# Last resort (can include player/enemies; use only if you must)
	return int(_enemy.collision_mask)


func _build_excludes() -> Array[RID]:
	var ex: Array[RID] = []

	# Exclude self if it's a CollisionObject2D
	if _enemy is CollisionObject2D:
		ex.append((_enemy as CollisionObject2D).get_rid())

	if _senses != null:
		var s_ex = _senses.get_exclude_rids()
		if s_ex != null:
			ex.append_array(s_ex)

		# If your EnemySenses can expose the current target RID, exclude it
		# so "ray to target_pos" doesn't treat the target as an obstacle.
		if _senses.has_method("get_target_rid"):
			var target_rid = _senses.call("get_target_rid")
			if typeof(target_rid) == TYPE_RID:
				ex.append(target_rid)

	return ex
	
# -------------------------------------------------------------------
# internals
# -------------------------------------------------------------------

func _reset_all() -> void:
	_mode = Mode.SEEK
	_side = 1
	_wall_normal = Vector2.ZERO
	_best_dist = INF
	_since_best = 0.0
	_stuck_time = 0.0
	_last_target = Vector2.INF
	_smoothed_vel = Vector2.ZERO
	_last_pos = (_enemy.global_position if _enemy != null and is_instance_valid(_enemy) else Vector2.ZERO)


func _reset_wall_only() -> void:
	_mode = Mode.SEEK
	_side = 1
	_wall_normal = Vector2.ZERO
	_best_dist = INF
	_since_best = 0.0
	_stuck_time = 0.0


func _update_stuck(delta: float) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return

	var moved: float = _enemy.global_position.distance_to(_last_pos)
	_last_pos = _enemy.global_position

	# Defaults are tuned for "I snagged a corner" cases.
	var min_move_px_per_sec: float = _f("wall_follow_min_move_px_per_sec", 14.0)
	var stuck_flip_time: float = _f("wall_follow_stuck_flip_time", 0.45)

	var min_move: float = min_move_px_per_sec * delta
	if moved < min_move:
		_stuck_time += delta
	else:
		_stuck_time = maxf(_stuck_time - delta * 1.3, 0.0)

	if _stuck_time > stuck_flip_time:
		_stuck_time = 0.0
		_side *= -1
		_wall_normal = Vector2.ZERO


func _can_go_straight(pos: Vector2, desired_dir: Vector2, target_pos: Vector2, mask: int, ex: Array[RID]) -> bool:
	# 1) immediate front check so we don't "think we're clear" while wedged on a corner
	var hand_probe: float = _f("wall_follow_hand_probe_dist", 44.0)
	var front_hit := _ray_hit(pos, pos + desired_dir * maxf(hand_probe, 32.0), mask, ex)
	if not front_hit.is_empty():
		return false

	# 2) ray to target must be clear
	return _ray_clear(pos, target_pos, mask, ex)


func _enter_wall_follow(pos: Vector2, desired_dir: Vector2, dist: float, target_pos: Vector2, mask: int, ex: Array[RID]) -> void:
	_mode = Mode.WALL
	_best_dist = dist
	_since_best = 0.0

	# Acquire initial wall normal from the obstruction towards target.
	var hit := _ray_hit(pos, target_pos, mask, ex)
	if not hit.is_empty():
		var n: Vector2 = hit.get("normal", Vector2.ZERO) as Vector2
		if n != Vector2.ZERO:
			_wall_normal = n.normalized()

	# Fallback if ray didn't hit (rare), use "push away" vector.
	if _wall_normal == Vector2.ZERO:
		_wall_normal = (-desired_dir).normalized()

	# Choose a side that initially helps move toward the target more.
	var left: Vector2 = _wall_normal.rotated(PI * 0.5).normalized()
	var right: Vector2 = _wall_normal.rotated(-PI * 0.5).normalized()
	_side = (1 if left.dot(desired_dir) >= right.dot(desired_dir) else -1)


func _wall_follow_step(pos: Vector2, desired_dir: Vector2, speed: float, mask: int, ex: Array[RID]) -> Vector2:
	var probe_dist: float = _f("wall_follow_probe_dist", 96.0)
	var hand_probe: float = _f("wall_follow_hand_probe_dist", 44.0)
	var gap_exit_bias: float = _f("wall_follow_gap_exit_bias", 0.25)
	var keep_off_bias: float = _f("wall_follow_keep_off_bias", 0.35)

	# Reacquire normal if lost
	if _wall_normal == Vector2.ZERO:
		var hit := _ray_hit(pos, pos + desired_dir * maxf(probe_dist, 64.0), mask, ex)
		if not hit.is_empty():
			var n: Vector2 = hit.get("normal", Vector2.ZERO) as Vector2
			if n != Vector2.ZERO:
				_wall_normal = n.normalized()
		if _wall_normal == Vector2.ZERO:
			_wall_normal = (-desired_dir).normalized()

	# Tangent direction along wall
	var tangent: Vector2 = _wall_normal.rotated(float(_side) * PI * 0.5).normalized()
	if tangent == Vector2.ZERO:
		return desired_dir * speed

	# "hand" probe into wall to maintain contact
	var into_wall: Vector2 = (-_wall_normal).normalized()
	var hand_hit := _ray_hit(pos, pos + into_wall * hand_probe, mask, ex)

	if not hand_hit.is_empty():
		var n2: Vector2 = hand_hit.get("normal", _wall_normal) as Vector2
		if n2 != Vector2.ZERO:
			_wall_normal = n2.normalized()
			tangent = _wall_normal.rotated(float(_side) * PI * 0.5).normalized()
	else:
		# If hand loses contact, it might be a doorway.
		# Step slightly "out" from the wall to slip through openings.
		var out_bias: Vector2 = into_wall * gap_exit_bias
		var vgap: Vector2 = (tangent + out_bias).normalized()
		if vgap != Vector2.ZERO:
			return vgap * speed

	# Forward probe to turn corners properly
	var fwd_hit := _ray_hit(pos, pos + tangent * maxf(probe_dist, 64.0), mask, ex)
	if not fwd_hit.is_empty():
		var n3: Vector2 = fwd_hit.get("normal", _wall_normal) as Vector2
		if n3 != Vector2.ZERO:
			_wall_normal = n3.normalized()
			tangent = _wall_normal.rotated(float(_side) * PI * 0.5).normalized()

	# Keep-off bias prevents grinding into wall
	var keep_off: Vector2 = _wall_normal * keep_off_bias
	var v: Vector2 = (tangent + keep_off).normalized()
	if v == Vector2.ZERO:
		v = tangent

	return v * speed


func _smooth(v: Vector2, delta: float) -> Vector2:
	# If you want snappier behavior, raise accel_mult.
	var accel_mult: float = _f("nav_smooth_accel_mult", 10.0) # "speed per second"
	var accel: float = maxf(120.0, v.length()) * accel_mult
	_smoothed_vel = _smoothed_vel.move_toward(v, accel * delta)
	return _smoothed_vel


func _ray_clear(a: Vector2, b: Vector2, mask: int, ex: Array[RID]) -> bool:
	var w: World2D = _enemy.get_world_2d()
	if w == null:
		return true

	var space: PhysicsDirectSpaceState2D = w.direct_space_state
	var params := PhysicsRayQueryParameters2D.new()
	params.from = a
	params.to = b
	params.collision_mask = mask
	params.exclude = ex
	params.collide_with_bodies = true
	params.collide_with_areas = true
	params.hit_from_inside = true

	return space.intersect_ray(params).is_empty()


func _ray_hit(a: Vector2, b: Vector2, mask: int, ex: Array[RID]) -> Dictionary:
	var w: World2D = _enemy.get_world_2d()
	if w == null:
		return {}

	var space: PhysicsDirectSpaceState2D = w.direct_space_state
	var params := PhysicsRayQueryParameters2D.new()
	params.from = a
	params.to = b
	params.collision_mask = mask
	params.exclude = ex
	params.collide_with_bodies = true
	params.collide_with_areas = true
	params.hit_from_inside = true

	return space.intersect_ray(params)


func _f(prop: StringName, default_value: float) -> float:
	# Safe “read if exists on EnemyActor” helper.
	if _enemy == null:
		return default_value
	var v = _enemy.get(prop)
	if v == null:
		return default_value
	var t: int = typeof(v)
	if t == TYPE_INT or t == TYPE_FLOAT:
		return float(v)
	return default_value
