extends RefCounted
class_name EnemyShooter

# "smart but not sniper" tuning
const PEEK_TIME: float = 0.28
const PEEK_PROBE_DIST: float = 54.0
const PEEK_MOVE_MUL: float = 0.75

const POST_SHOT_DODGE_TIME: float = 0.22
const POST_SHOT_DODGE_MUL: float = 0.70
const APPROACH_WHEN_SHOOT_READY: float = 0.12 # slightly more willing to step in when ready

# SAFE LANE (re-lane / clearance bias)
const SAFE_LANE_MUL: float = 0.55
const SAFE_LANE_STEP_MIN: float = 32.0
const SAFE_LANE_SIDE_CHECK: float = 18.0
const SAFE_LANE_FORWARD_CHECK: float = 14.0

const INF_COST: int = 1_000_000_000

var _enemy: EnemyActor = null
var _cd: float = 0.0

# LOS throttle
var _los_cache: bool = false
var _los_timer: float = 0.0

# peek + recover
var _peek_t: float = 0.0
var _peek_dir: Vector2 = Vector2.ZERO
var _post_shot_t: float = 0.0
var _post_side: int = 1

# weave
var _phase: float = 0.0
var _phase_rate: float = 3.2

var _rng := RandomNumberGenerator.new()


func setup(enemy: EnemyActor) -> void:
	_enemy = enemy
	_cd = 0.0

	_rng.randomize()
	_los_cache = false
	_los_timer = _rng.randf_range(0.0, maxf(0.01, _enemy.los_check_interval if _enemy != null else 0.15))

	_peek_t = 0.0
	_peek_dir = Vector2.ZERO
	_post_shot_t = 0.0
	_post_side = (_rng.randi_range(0, 1) * 2 - 1)

	_phase = _rng.randf_range(0.0, TAU)
	_phase_rate = _rng.randf_range(2.6, 4.2)


func tick(delta: float) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return

	_cd = maxf(_cd - delta, 0.0)

	_los_timer = maxf(_los_timer - delta, 0.0)
	_peek_t = maxf(_peek_t - delta, 0.0)
	_post_shot_t = maxf(_post_shot_t - delta, 0.0)

	_phase += delta * _phase_rate


# Use this from EnemyActor.gd for RANGED AI. Shooter owns: move + shoot.
func brain(
	to_player: Vector2,
	dist: float,
	move_speed: float,
	preferred_range: float,
	range_tolerance: float,
	strafe_strength: float
) -> Vector2:
	if _enemy == null or not is_instance_valid(_enemy):
		return Vector2.ZERO
	if _enemy.spec == null or _enemy.spec.projectile_scene == null:
		return _kite_only(to_player, dist, move_speed, preferred_range, range_tolerance, strafe_strength)

	var cover_mask: int = _enemy.cover_mask()
	var has_los: bool = _los_cached(cover_mask)

	# If cover_mask == 0 => treat LOS as always true (no cover system).
	# This prevents "won't shoot because no cover" behavior.
	if cover_mask == 0:
		has_los = true

	# If we're ready and LOS is blocked (in a world where it CAN be blocked), peek to regain LOS.
	var want_peek: bool = (_cd <= 0.0 and cover_mask != 0 and not has_los)

	if want_peek and _peek_t <= 0.0:
		_pick_peek_dir(to_player, PEEK_PROBE_DIST)
		_peek_t = PEEK_TIME

	# Base movement: keep range + weave
	var desired: Vector2 = _kite_only(to_player, dist, move_speed, preferred_range, range_tolerance, strafe_strength)

	# Peek bias
	if _peek_t > 0.0 and cover_mask != 0:
		if _peek_dir == Vector2.ZERO:
			_peek_dir = Vector2(-to_player.y, to_player.x) * float(_post_side)
		desired += _peek_dir.normalized() * (move_speed * PEEK_MOVE_MUL)

	# Post-shot quick dodge so it doesn't feel turret-y
	if _post_shot_t > 0.0:
		var strafe: Vector2 = Vector2(-to_player.y, to_player.x) * float(_post_side)
		desired += strafe.normalized() * (move_speed * POST_SHOT_DODGE_MUL)

	# ✅ SAFE LANE: after shot (and while peeking), bias toward more open corridor space
	# This reduces doorframe edge-hugging and makes "reposition after firing" feel intentional.
	if _post_shot_t > 0.0 or (_peek_t > 0.0 and cover_mask != 0):
		var lane: Vector2 = _pick_safe_lane_dir(to_player, preferred_range, range_tolerance)
		if lane != Vector2.ZERO:
			desired += lane * (move_speed * SAFE_LANE_MUL)

	# Shooting:
	if _cd <= 0.0:
		if has_los:
			_spawn_projectile(to_player)
			_cd = maxf(_enemy.spec.shoot_every, 0.05)
			_post_shot_t = POST_SHOT_DODGE_TIME
			_post_side *= -1
			_peek_t = 0.0

	return desired


# ------------------------------------------------------------
# Movement helpers
# ------------------------------------------------------------

func _kite_only(
	to_player: Vector2,
	dist: float,
	move_speed: float,
	preferred_range: float,
	range_tolerance: float,
	strafe_strength: float
) -> Vector2:
	var desired: Vector2 = Vector2.ZERO

	var min_d: float = preferred_range - range_tolerance
	var max_d: float = preferred_range + range_tolerance

	if dist < min_d:
		desired += -to_player * move_speed
	elif dist > max_d:
		var mul: float = (1.0 + APPROACH_WHEN_SHOOT_READY) if _cd <= 0.0 else 1.0
		desired += to_player * move_speed * mul

	# Weave/strafe (less robotic)
	var strafe: Vector2 = Vector2(-to_player.y, to_player.x)
	var w: float = (0.55 + 0.25 * sin(_phase))
	desired += strafe * (move_speed * strafe_strength * w)

	return desired


func _pick_peek_dir(to_player: Vector2, probe_dist: float) -> void:
	if _enemy == null or _enemy.player == null or not is_instance_valid(_enemy.player):
		_peek_dir = Vector2.ZERO
		return

	var strafe: Vector2 = Vector2(-to_player.y, to_player.x)
	if strafe.length_squared() < 0.0001:
		_peek_dir = Vector2.RIGHT
		return

	var left_p: Vector2 = _enemy.global_position + strafe.normalized() * probe_dist
	var right_p: Vector2 = _enemy.global_position - strafe.normalized() * probe_dist

	var left_blocked: bool = _movement_blocked(left_p)
	var right_blocked: bool = _movement_blocked(right_p)

	var player_pos: Vector2 = _enemy.player.global_position

	# Prefer the side that (1) isn't blocked for movement, and (2) tends to gain LOS
	var left_los: bool = (not left_blocked) and _enemy.ray_clear(left_p, player_pos)
	var right_los: bool = (not right_blocked) and _enemy.ray_clear(right_p, player_pos)

	if left_los and not right_los:
		_peek_dir = strafe
		_post_side = 1
		return
	if right_los and not left_los:
		_peek_dir = -strafe
		_post_side = -1
		return

	# If both/neither, keep stable alternating side rule
	_peek_dir = (strafe if _post_side > 0 else -strafe)


# ------------------------------------------------------------
# SAFE LANE (clearance bias + flow hint)
# ------------------------------------------------------------

func _candidate_dirs() -> Array:
	# Avoid const normalized() issues by building at runtime (only 8 dirs, cheap).
	return [
		Vector2(1, 0),
		Vector2(-1, 0),
		Vector2(0, 1),
		Vector2(0, -1),
		Vector2(1, 1).normalized(),
		Vector2(1, -1).normalized(),
		Vector2(-1, 1).normalized(),
		Vector2(-1, -1).normalized()
	]


func _pick_safe_lane_dir(to_player: Vector2, preferred_range: float, range_tol: float) -> Vector2:
	if _enemy == null or _enemy.player == null or not is_instance_valid(_enemy.player):
		return Vector2.ZERO

	var pos: Vector2 = _enemy.global_position
	var player_pos: Vector2 = _enemy.player.global_position

	var ff: FlowFieldNav = _enemy._get_flow()
	var step: float = SAFE_LANE_STEP_MIN
	if ff != null and is_instance_valid(ff):
		step = maxf(step, float(ff.cell_size_px) * 0.75)

	# flow hint: helps re-lane along corridor direction (doorframes love to snag lateral-only movement)
	var flow_hint: Vector2 = Vector2.ZERO
	if ff != null and is_instance_valid(ff):
		if ff.has_method("sample_dir_smooth"):
			flow_hint = ff.sample_dir_smooth(pos)
		else:
			flow_hint = ff.sample_dir(pos)

	var best_score: float = -INF
	var best_dir: Vector2 = Vector2.ZERO

	for d in _candidate_dirs():
		var dir: Vector2 = d
		if dir.length_squared() < 0.0001:
			continue

		var p: Vector2 = pos + dir * step
		if _movement_blocked(p):
			continue

		# Optional: reject points outside flow field radius (prevents biasing into “unknown”)
		if ff != null and is_instance_valid(ff) and ff.has_method("sample_cost"):
			var c: int = ff.sample_cost(p)
			if c >= INF_COST:
				continue

		# clearance sampling: prefer spots with free space to the sides + forward
		var open_bonus: float = _open_bonus(p, dir)

		# keep range band influence (don’t re-lane straight into the player)
		var new_dist: float = p.distance_to(player_pos)
		var band_center: float = preferred_range
		var band_err: float = 0.0
		if new_dist < (band_center - range_tol):
			band_err = (band_center - range_tol) - new_dist
		elif new_dist > (band_center + range_tol):
			band_err = new_dist - (band_center + range_tol)

		# avoid “safe lane” picking pure toward-player unless it’s clearly best
		var toward: float = maxf(0.0, dir.dot(to_player))

		# follow flow corridor a bit if present
		var flow_align: float = (dir.dot(flow_hint) if flow_hint != Vector2.ZERO else 0.0)

		# Score weights (tuned to be subtle, not a new AI)
		var score: float = 0.0
		score += open_bonus * 1.25
		score += flow_align * 0.35
		score -= band_err * 0.006
		score -= toward * 0.25

		if score > best_score:
			best_score = score
			best_dir = dir

	return best_dir


func _open_bonus(p: Vector2, dir: Vector2) -> float:
	var bonus: float = 0.0
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	# side clearance (corridor center bias)
	if not _movement_blocked(p + perp * SAFE_LANE_SIDE_CHECK):
		bonus += 1.0
	if not _movement_blocked(p - perp * SAFE_LANE_SIDE_CHECK):
		bonus += 1.0

	# forward clearance (doorframe exit bias)
	if not _movement_blocked(p + dir * SAFE_LANE_FORWARD_CHECK):
		bonus += 0.6

	return bonus


func _movement_blocked(p: Vector2) -> bool:
	# Uses collision_mask (movement blockers), NOT tactical cover mask.
	if _enemy == null or not is_instance_valid(_enemy):
		return false

	var w: World2D = _enemy.get_world_2d()
	if w == null:
		return false

	var mask: int = int(_enemy.collision_mask)
	if mask == 0:
		return false

	var space: PhysicsDirectSpaceState2D = w.direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = p
	params.collision_mask = mask
	params.collide_with_areas = true
	params.collide_with_bodies = true

	# exclude self + hitbox + player (+ hurtbox) via senses list if available
	if _enemy._senses != null and _enemy._senses.has_method("get_exclude_rids"):
		params.exclude = _enemy._senses.get_exclude_rids()

	var hits: Array = space.intersect_point(params, 1)
	return not hits.is_empty()


# ------------------------------------------------------------
# LOS throttle
# ------------------------------------------------------------

func _los_cached(mask: int) -> bool:
	if mask == 0:
		_los_cache = true
		return true

	if _los_timer > 0.0:
		return _los_cache

	_los_timer = maxf(0.01, _enemy.los_check_interval)
	_los_cache = _enemy.has_los_to_player()
	return _los_cache


# ------------------------------------------------------------
# Shooting
# ------------------------------------------------------------
func _threat_damage_mul() -> float:
	if _enemy == null or not is_instance_valid(_enemy):
		return 1.0

	var td: Node = _enemy.get_node_or_null("/root/ThreatDirector")
	if td == null:
		return 1.0

	# ThreatDirector exposes enemy_damage_mul (float)
	return float(td.get("enemy_damage_mul"))


func _spawn_projectile(to_player: Vector2) -> void:
	var to_n: Vector2 = (to_player.normalized() if to_player.length_squared() > 0.001 else Vector2.RIGHT)
	var origin := _enemy.global_position + (to_n * 14.0)
	var manager := _enemy.get_node_or_null("/root/ProjectileManager") as ProjectileSimulationManager
	if manager != null and _enemy.spec.projectile_scene.resource_path == "res://core/combat/projectile/EnemyProjectile.tscn":
		manager.spawn_enemy(origin, to_n, _enemy.spec.projectile_speed, _enemy.spec.projectile_damage * _threat_damage_mul(), _enemy.spec.projectile_lifetime, _enemy, _enemy.spec.id)
		_spawn_muzzle_flash(to_n)
		return

	var proj: Node = _enemy.spec.projectile_scene.instantiate()
	if proj == null:
		return

	# Spawn slightly in front so it doesn't overlap enemy body
	var n2: Node2D = proj as Node2D
	if n2 != null:
		n2.global_position = origin

	# Pass shooter so projectile ignores it
	if proj.has_method("setup"):
		proj.call("setup",
			to_player,
			_enemy.spec.projectile_speed,
			_enemy.spec.projectile_damage * _threat_damage_mul(),
			_enemy.spec.projectile_lifetime,
			_enemy
		)

	# Style (Spitter vs Herald vs default)
	if _enemy.spec != null and proj.has_method("set_style"):
		proj.call("set_style", _enemy.spec.id)

	_spawn_muzzle_flash(to_n)

	_enemy.get_tree().current_scene.call_deferred("add_child", proj)

func _spawn_muzzle_flash(to_n: Vector2) -> void:
	# Muzzle flash remains visual-only and does not create a collision object.
	if _enemy.spec != null:
		var mf: VFX_EnemyMuzzleFlash = VFX_EnemyMuzzleFlash.new()
		_enemy.get_tree().current_scene.add_child(mf)
		mf.setup(_enemy.global_position, to_n, _enemy.spec.id)

func shoot_if_ready(to_player: Vector2) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	if _enemy.spec == null:
		return
	if _enemy.spec.projectile_scene == null:
		return
	if _cd > 0.0:
		return

	_spawn_projectile(to_player)

	_cd = maxf(_enemy.spec.shoot_every, 0.05)

	# keep the same "feel" extras as the brain-shot:
	_post_shot_t = POST_SHOT_DODGE_TIME
	_post_side *= -1
	_peek_t = 0.0
