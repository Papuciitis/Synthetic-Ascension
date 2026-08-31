extends RefCounted
class_name EnemyTactical

# ------------------------------------------------------------
# “Commit if allies nearby”
# ------------------------------------------------------------
const COMMIT_ALLIES_MIN: int = 6
const COMMIT_RADIUS: float = 240.0
const COMMIT_HP_BUFFER: float = 0.12 # must be this much above retreat ratio to be allowed to commit

# ------------------------------------------------------------
# Runtime
# ------------------------------------------------------------
var _enemy: EnemyActor = null
var _rng := RandomNumberGenerator.new()

var _sep: Node = null
var _ei: Node = null

var _cover_cd: float = 0.0
var _cover_target: Vector2 = Vector2.ZERO
var _has_cover_target: bool = false

# cached dt (so we can use EnemyNavigator without changing EnemyActor.gd signature)
var _dt: float = _default_dt()

# detect "took damage" without extra hooks
var _last_hp: float = -1.0
var _reposition_t: float = 0.0

# Reused query params (allocating one per cover sample was a hot-path cost).
var _point_params := PhysicsPointQueryParameters2D.new()


func setup(enemy: EnemyActor) -> void:
	_enemy = enemy
	_rng.seed = Global._rng.randi()

	_cover_cd = 0.0
	_cover_target = Vector2.ZERO
	_has_cover_target = false

	_dt = _default_dt()
	_last_hp = (-1.0 if _enemy == null else _enemy.hp)
	_reposition_t = 0.0
	_sep = null
	_ei = null


func tick(delta: float) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return

	_dt = delta
	_cover_cd = maxf(_cover_cd - delta, 0.0)
	_reposition_t = maxf(_reposition_t - delta, 0.0)

	# damage reaction: if HP dropped since last tick, force a re-pick soon
	if _last_hp >= 0.0 and _enemy.hp < _last_hp - 0.001:
		_reposition_t = maxf(_reposition_t, 0.45)
		_cover_cd = 0.0

	_last_hp = _enemy.hp


func brain(to_player: Vector2, dist: float) -> Vector2:
	if _enemy == null or not is_instance_valid(_enemy):
		return Vector2.ZERO
	if _enemy.spec == null:
		return to_player * _enemy._spd()

	var spd: float = _enemy._spd()

	# If no cover exists in world => behave like ranged strafe
	var cover_mask: int = _enemy.spec.tactical_cover_mask
	if cover_mask == 0:
		return _fallback_strafe_and_shoot(to_player, dist, spd)

	# --- intent ---
	var hp_ratio: float = _enemy.hp / maxf(_enemy.max_hp, 0.001)
	var want_retreat: bool = hp_ratio <= _enemy.spec.retreat_hp_ratio

	# cover refresh / repick (also after taking damage)
	if _cover_cd <= 0.0 or not _has_cover_target or _reposition_t > 0.0:
		_cover_cd = maxf(_enemy.spec.cover_refresh, 0.1)
		_has_cover_target = _pick_cover_point(want_retreat)
		_reposition_t = 0.0

	# “commit if allies nearby” (but never when low HP)
	var allies: int = _ally_count(COMMIT_RADIUS, 12)
	var can_commit: bool = (not want_retreat) and (hp_ratio >= _enemy.spec.retreat_hp_ratio + COMMIT_HP_BUFFER)
	var want_commit: bool = can_commit and (allies >= COMMIT_ALLIES_MIN)

	# Shared throttled cache on EnemyActor (los_check_interval); a fresh raycast
	# per brain call bypassed the throttle this cache exists for.
	var has_los: bool = _enemy.has_los_cached()

	# --- behavior selection ---
	if want_retreat:
		if _has_cover_target:
			return _navigate_to_point(_cover_target, cover_mask, spd)
		return (-to_player) * spd

	if want_commit:
		return _commit_pressure(to_player, dist, spd)

	# normal tactical: if we have LOS, move into cover to break it
	if has_los and _has_cover_target:
		return _navigate_to_point(_cover_target, cover_mask, spd)

	# already in/near cover -> peek pressure
	return _cover_peek_and_pressure(to_player, dist, spd)


# ------------------------------------------------------------
# Ally counting (fast path via EnemySeparationSystem buckets)
# IMPORTANT: your EnemySeparationSystem node should be in group "enemy_sep"
# ------------------------------------------------------------
func _ally_count(radius: float, max_count: int) -> int:
	if _enemy == null or not is_instance_valid(_enemy):
		return 0

	# Prefer EnemySeparationSystem (which in turn should delegate to EnemyIndex).
	if _sep == null or not is_instance_valid(_sep):
		_sep = _enemy.get_tree().get_first_node_in_group(&"enemy_sep")
	if _sep != null and is_instance_valid(_sep) and _sep.has_method("count_allies"):
		return int(_sep.call("count_allies", _enemy, radius, max_count))

	# Next best: EnemyIndex autoload (fast spatial hash).
	if _ei == null or not is_instance_valid(_ei):
		_ei = _enemy.get_node_or_null("/root/EnemyIndex")
	if _ei != null and is_instance_valid(_ei) and _ei.has_method("count_allies"):
		return int(_ei.call("count_allies", _enemy, radius, max_count))

	# Last resort fallback (slow)
	var count: int = 0
	var r2: float = radius * radius
	for n in _enemy.get_tree().get_nodes_in_group(&"enemies"):
		var other := n as EnemyActor
		if other == null or other == _enemy or other.dead:
			continue
		if _enemy.global_position.distance_squared_to(other.global_position) <= r2:
			count += 1
			if count >= max_count:
				break
	return count


# ------------------------------------------------------------
# Behaviors
# ------------------------------------------------------------
func _fallback_strafe_and_shoot(to_player: Vector2, dist: float, spd: float) -> Vector2:
	var desired: Vector2 = Vector2.ZERO

	var min_d: float = _enemy.spec.preferred_range - _enemy.spec.range_tolerance
	var max_d: float = _enemy.spec.preferred_range + _enemy.spec.range_tolerance

	# keep the distance band
	if dist < min_d:
		desired += -to_player * spd
	elif dist > max_d:
		desired += to_player * spd * 0.55

	# strafe (slightly more than normal shooter)
	var strafe: Vector2 = Vector2(-to_player.y, to_player.x)
	desired += strafe * (spd * (_enemy.spec.strafe_strength + 0.35))

	if _enemy.has_los_cached():
		_enemy._shooter.shoot_if_ready(to_player)

	return desired


func _cover_peek_and_pressure(to_player: Vector2, dist: float, spd: float) -> Vector2:
	var desired: Vector2 = Vector2.ZERO

	# keep roughly preferred band even while in cover
	var min_d: float = _enemy.spec.preferred_range - _enemy.spec.range_tolerance
	var max_d: float = _enemy.spec.preferred_range + _enemy.spec.range_tolerance

	if dist < min_d:
		desired += -to_player * spd * 0.9
	elif dist > max_d:
		desired += to_player * spd * 0.45

	# "peek": small lateral drift that changes over time (less robotic)
	var strafe: Vector2 = Vector2(-to_player.y, to_player.x)
	var wobble: float = _rng.randf_range(0.35, 0.65)
	desired += strafe * (spd * (_enemy.spec.strafe_strength * wobble))

	# shoot if LOS opens (e.g. during peek drift)
	if _enemy.has_los_cached():
		_enemy._shooter.shoot_if_ready(to_player)

	return desired


func _commit_pressure(to_player: Vector2, dist: float, spd: float) -> Vector2:
	# Aggressive ranged: keep band but don't run into cover to break LOS.
	var desired: Vector2 = Vector2.ZERO

	var min_d: float = _enemy.spec.preferred_range - _enemy.spec.range_tolerance
	var max_d: float = _enemy.spec.preferred_range + _enemy.spec.range_tolerance

	# keep the band, but be more willing to approach
	if dist < min_d:
		desired += -to_player * spd * 0.75
	elif dist > max_d:
		desired += to_player * spd * 0.85

	# slightly tighter strafe so it feels “locked in”
	var strafe: Vector2 = Vector2(-to_player.y, to_player.x)
	desired += strafe * (spd * (_enemy.spec.strafe_strength * 0.75))

	# commit means it tries to capitalize on LOS
	if _enemy.has_los_cached():
		_enemy._shooter.shoot_if_ready(to_player)

	return desired


func _navigate_to_point(p: Vector2, cover_mask: int, spd: float) -> Vector2:
	# Use EnemyNavigator to avoid getting stuck when "cover target" is behind walls/doorframes.
	# Mask is cover_mask; EnemyNavigator ORs it with collision_mask internally (in your earlier version).
	if _enemy._nav != null:
		return _enemy._nav.apply(_dt, p, spd, cover_mask)

	# fallback if nav isn't available for some reason
	var v: Vector2 = p - _enemy.global_position
	return (v.normalized() * spd if v.length_squared() > 4.0 else Vector2.ZERO)


# ------------------------------------------------------------
# Cover selection
# ------------------------------------------------------------
func _pick_cover_point(want_far: bool) -> bool:
	if _enemy.player == null or not is_instance_valid(_enemy.player):
		return false

	# already in cover
	if not _enemy.has_los_cached():
		_cover_target = _enemy.global_position
		return true

	var samples: int = maxi(6, _enemy.spec.cover_sample_points)
	var best_score: float = -INF
	var best: Vector2 = Vector2.ZERO
	var found: bool = false

	var player_pos: Vector2 = _enemy.player.global_position

	for i in range(samples):
		var ang: float = (TAU * float(i) / float(samples)) + _rng.randf_range(-0.18, 0.18)
		var rr: float = _enemy.spec.cover_seek_radius * _rng.randf_range(0.65, 1.0)
		var cand: Vector2 = _enemy.global_position + Vector2.RIGHT.rotated(ang) * rr

		# Don't pick points inside movement blockers (use collision_mask, not tactical cover mask).
		if _movement_blocked(cand):
			continue

		# cand is cover only if cand->player ray is BLOCKED
		if _enemy.ray_clear(cand, player_pos):
			continue

		var d: float = cand.distance_to(player_pos)

		# Range scoring
		var ideal: float = _enemy.spec.preferred_range
		if want_far:
			ideal += 220.0

		var range_score: float = -absf(d - ideal)

		# Prefer farther points when retreating
		var far_bonus: float = (d * 0.10 if want_far else 0.0)

		# Slight movement cost penalty
		var move_cost: float = -_enemy.global_position.distance_to(cand) * 0.15

		var score: float = range_score + far_bonus + move_cost
		if score > best_score:
			best_score = score
			best = cand
			found = true

	if found:
		_cover_target = best
		return true

	return false


func _movement_blocked(p: Vector2) -> bool:
	var w: World2D = _enemy.get_world_2d()
	if w == null:
		return false

	var mask: int = int(_enemy.collision_mask)
	if mask == 0:
		return false

	var space: PhysicsDirectSpaceState2D = w.direct_space_state
	_point_params.position = p
	_point_params.collision_mask = mask
	_point_params.collide_with_areas = true
	_point_params.collide_with_bodies = true

	# exclude self + hitbox + player + hurtbox (reuse senses exclude list)
	if _enemy._senses != null:
		_point_params.exclude = _enemy._senses.get_exclude_rids()

	var hits: Array = space.intersect_point(_point_params, 1)
	return not hits.is_empty()


## The pre-first-tick fallback follows the project's tick rate instead of
## assuming 60 Hz (Godot hygiene audit 2026-08-28 §7, top-10 #10).
static func _default_dt() -> float:
	return 1.0 / maxf(1.0, float(Engine.physics_ticks_per_second))
