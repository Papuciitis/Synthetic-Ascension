extends RefCounted
class_name EnemyHordeNav

const INF_COST: int = 1_000_000_000

const INV_SQRT2: float = 0.7071067811865476

const CAND_DIRS: Array[Vector2] = [
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(INV_SQRT2,  INV_SQRT2),
	Vector2(INV_SQRT2, -INV_SQRT2),
	Vector2(-INV_SQRT2,  INV_SQRT2),
	Vector2(-INV_SQRT2, -INV_SQRT2),
]

const SEP_RADIUS_SWARM: float = 42.0
const SEP_STRENGTH_SWARM: float = 0.55

var _sep_sys: Node = null
var _smoothed_move: Vector2 = Vector2.ZERO

var _e: EnemyActor = null

# LOS throttle (smart AIs only)
var _los_cache: bool = false
var _los_timer: float = 0.0
var _rng := RandomNumberGenerator.new()

# Flow inertia
var _flow_move: Vector2 = Vector2.ZERO

# Hot-path caches (avoid sampling every frame for every enemy)
var _flow_cached_dir: Vector2 = Vector2.ZERO
var _flow_next_msec: int = 0

var _sep_cached: Vector2 = Vector2.ZERO
var _sep_next_msec: int = 0

# Wall slide assist
var _wall_slide_dir: Vector2 = Vector2.ZERO
var _wall_slide_t: float = 0.0
var _wall_hand: int = 1
var _wall_best_cost: int = INF_COST
var _wall_since_best: float = 0.0
var _pre_pos: Vector2 = Vector2.ZERO

# Fallback stuck nudge (rare)
var _stuck_last_pos: Vector2 = Vector2.ZERO
var _stuck_t: float = 0.0
var _nudge_t: float = 0.0
var _nudge_side: int = 1


func setup(enemy: EnemyActor) -> void:
	_e = enemy
	# Seed from the shared RNG: randomize() pulls OS entropy and runs on every
	# spawn and pool reuse, which is measurable during spawn storms.
	_rng.seed = Global._rng.randi()

	_smoothed_move = Vector2.ZERO
	_sep_sys = null
	_flow_cached_dir = Vector2.ZERO
	_flow_next_msec = 0
	_sep_cached = Vector2.ZERO
	_sep_next_msec = 0

	if _e != null and is_instance_valid(_e):
		_stuck_last_pos = _e.global_position
		_pre_pos = _e.global_position

		# desync LOS checks across enemies
		_los_timer = _rng.randf_range(0.0, maxf(0.01, _e.los_check_interval))

func pre_steer(ai: int, move: Vector2, to_player: Vector2, delta: float, lod_tier: int = 0) -> Vector2:
	if _e == null or not is_instance_valid(_e):
		return move

	_pre_pos = _e.global_position

	# Macro nav (flow field)
	if _e.dumb_pathing_enabled:
		move = _apply_flow_nav(ai, move, to_player, delta)

	# Local separation is the most expensive horde-neighbour query. Keep it for
	# near/mid swarms, but distant ambient enemies can follow the shared flow field.
	if lod_tier < 2 and _e.flow_for_swarm_ai and _is_swarm_ai(ai):
		var sep: Vector2 = _sample_sep(SEP_RADIUS_SWARM, 8 if lod_tier == 0 else 5)
		if sep != Vector2.ZERO and move.length_squared() > 0.0001:
			var mag: float = move.length()
			var d: Vector2 = move / mag
			var blended: Vector2 = (d * (1.0 - SEP_STRENGTH_SWARM) + sep * SEP_STRENGTH_SWARM).normalized()
			move = blended * mag

	# Micro nav (corner assist)
	move = _apply_wall_slide_pre(move, delta)

	# Rare fallback
	move = _apply_stuck_nudge(move, delta)

	# Velocity smoothing (removes jitter + “bee turning”)
	move = _smooth(move, ai, delta)

	return move

func post_move(desired_move: Vector2, to_player: Vector2, delta: float, _lod_tier: int = 0) -> void:
	if _e == null or not is_instance_valid(_e):
		return
	_post_move_wall_slide(desired_move, to_player, delta)


# -------------------------------------------------------------------
# Flow nav
# -------------------------------------------------------------------

func _is_swarm_ai(ai: int) -> bool:
	return ai == EnemySpec.AI.CHASE \
		or ai == EnemySpec.AI.SPLITTER \
		or ai == EnemySpec.AI.LEECH \
		or ai == EnemySpec.AI.HERALD \
		or ai == EnemySpec.AI.BOMBER


func _los_cached(delta: float) -> bool:
	# Prefer shared cache on EnemyActor (so multiple modules don't raycast independently)
	if _e != null and is_instance_valid(_e) and _e.has_method("has_los_cached"):
		return bool(_e.call("has_los_cached"))

	_los_timer -= delta
	if _los_timer > 0.0:
		return _los_cache

	_los_timer = maxf(0.01, _e.los_check_interval)
	_los_cache = _e.has_los_to_player()
	return _los_cache


func _flow_dir(world_pos: Vector2) -> Vector2:
	# Cache flow sampling (lots of enemies read the same field each frame)
	var now: int = Time.get_ticks_msec()
	if now < _flow_next_msec:
		return _flow_cached_dir
	_flow_next_msec = now + 60

	var ff: FlowFieldNav = _e._get_flow()
	if ff == null or not is_instance_valid(ff):
		_flow_cached_dir = Vector2.ZERO
		return Vector2.ZERO

	var dir: Vector2
	if _e.flow_smoothing and ff.has_method("sample_dir_smooth"):
		dir = ff.sample_dir_smooth(world_pos)
	else:
		dir = ff.sample_dir(world_pos)

	if dir != Vector2.ZERO:
		_flow_cached_dir = dir
		return dir

	# downhill fallback (no direct-to-player snap here)
	if not ff.has_method("sample_cost"):
		_flow_cached_dir = Vector2.ZERO
		return Vector2.ZERO

	var cs: float = float(ff.cell_size_px)
	var step: float = cs * 0.75

	var best_cost: int = INF_COST
	var best_dir: Vector2 = Vector2.ZERO

	for d in CAND_DIRS:
		var c: int = ff.sample_cost(world_pos + d * step)
		if c < best_cost:
			best_cost = c
			best_dir = d

	_flow_cached_dir = best_dir
	return best_dir

func _apply_flow_nav(ai: int, chase: Vector2, to_player: Vector2, delta: float) -> Vector2:
	# If sniper is deliberately relocating, do NOT let flow drag it.
	# (Flow is great for swarm pressure, but it breaks the “sniper brain” feel.)
	if ai == EnemySpec.AI.SNIPER and _e != null and is_instance_valid(_e):
		if _e._sniper != null and is_instance_valid(_e._sniper) and _e._sniper.has_method("is_relocating"):
			if bool(_e._sniper.call("is_relocating")):
				return chase

	var ff_dir: Vector2 = _flow_dir(_e.global_position)
	if ff_dir == Vector2.ZERO:
		# If flow has no idea, keep inertia for swarmers instead of snapping to player.
		if _flow_move != Vector2.ZERO and _e.flow_for_swarm_ai and _is_swarm_ai(ai):
			return _flow_move * _e._spd()
		return chase

	# Only blend toward player if flow already roughly points toward player.
	# This prevents "door is behind you but you keep hugging the wall facing player".
	var blend: float = _e.flow_blend_to_player
	if blend > 0.0 and to_player != Vector2.ZERO:
		if ff_dir.dot(to_player) > 0.20:
			ff_dir = (ff_dir * (1.0 - blend) + to_player * blend).normalized()
		# else: no blend

	# FLOW INERTIA (door frames / corners)
	if _flow_move == Vector2.ZERO:
		_flow_move = ff_dir
	else:
		var dotv: float = _flow_move.dot(ff_dir)
		var t: float = clampf(delta * (2.0 if dotv < -0.15 else 10.0), 0.0, 1.0)
		_flow_move = _flow_move.lerp(ff_dir, t)
		_flow_move = (_flow_move.normalized() if _flow_move.length_squared() > 0.0001 else ff_dir)

	# Swarm AIs: follow flow strongly
	if _e.flow_for_swarm_ai and _is_swarm_ai(ai):
		return _flow_move * _e._spd()

	# Smart AIs: if LOS exists, keep their intent (they can "see" you)
	var needs_los: bool = (ai == EnemySpec.AI.RANGED or ai == EnemySpec.AI.TACTICAL or ai == EnemySpec.AI.SNIPER)
	if needs_los and _los_cached(delta):
		return chase

	# Otherwise, steer intent toward flow
	var mag: float = chase.length()
	if mag < 0.01:
		mag = _e._spd()

	var chase_dir: Vector2 = (chase / mag) if mag > 0.001 else _flow_move
	var blended: Vector2 = (chase_dir * 0.35 + _flow_move * 0.65).normalized()
	return blended * mag

# -------------------------------------------------------------------
# Wall slide (corner assist)
# -------------------------------------------------------------------

func _apply_wall_slide_pre(move: Vector2, delta: float) -> Vector2:
	if not _e.wall_slide_enabled:
		_wall_slide_t = 0.0
		_wall_slide_dir = Vector2.ZERO
		return move

	if _wall_slide_t <= 0.0 or _wall_slide_dir == Vector2.ZERO or move.length_squared() < 1.0:
		return move

	_wall_slide_t = maxf(_wall_slide_t - delta, 0.0)

	var dir: Vector2 = move.normalized()
	var blended: Vector2 = (dir * (1.0 - _e.wall_slide_strength) + _wall_slide_dir * _e.wall_slide_strength).normalized()
	return blended * move.length()


func _post_move_wall_slide(desired_move: Vector2, to_player: Vector2, delta: float) -> void:
	if not _e.wall_slide_enabled:
		return
	if desired_move.length_squared() < 1.0:
		return

	var ff: FlowFieldNav = _e._get_flow()

	# While sliding: measure progress by flow cost, not euclidean distance.
	if _wall_slide_t > 0.0 and ff != null and is_instance_valid(ff) and ff.has_method("sample_cost"):
		var c: int = ff.sample_cost(_e.global_position)
		if c < _wall_best_cost - 1:
			_wall_best_cost = c
			_wall_since_best = 0.0
		else:
			_wall_since_best += delta

		# Not improving? flip hand and force re-pick next collision.
		if _wall_since_best > 0.90:
			_wall_since_best = 0.0
			_wall_hand *= -1
			_wall_slide_t = 0.0
			_wall_slide_dir = Vector2.ZERO

	var disp: Vector2 = _e.global_position - _pre_pos
	var desired_dir: Vector2 = desired_move.normalized()
	var forward: float = disp.dot(desired_dir)

	if forward >= _e.wall_slide_trigger_forward_px:
		return

	var sc: int = _e.get_slide_collision_count()
	if sc <= 0:
		return

	# Find normal that blocks desired direction the most
	var best_dot: float = 1.0
	var best_n: Vector2 = Vector2.ZERO

	for i in range(sc):
		var col := _e.get_slide_collision(i)
		var n: Vector2 = col.get_normal()
		var d: float = desired_dir.dot(n)
		if d < best_dot:
			best_dot = d
			best_n = n

	if best_n == Vector2.ZERO:
		return

	var t1: Vector2 = Vector2(-best_n.y, best_n.x).normalized()
	var t2: Vector2 = -t1

	# Choose tangent by probing FLOW COST on each side.
	var chosen: Vector2 = Vector2.ZERO

	if ff != null and is_instance_valid(ff) and ff.has_method("sample_cost"):
		var probe: float = 28.0
		var c1: int = ff.sample_cost(_e.global_position + t1 * probe)
		var c2: int = ff.sample_cost(_e.global_position + t2 * probe)

		if c1 < c2 - 1:
			chosen = t1
		elif c2 < c1 - 1:
			chosen = t2
		else:
			# ambiguous: keep stable hand rule
			chosen = (t1 if _wall_hand > 0 else t2)

	else:
		# fallback: dot with guidance
		var guide: Vector2 = _flow_dir(_e.global_position)
		if guide == Vector2.ZERO:
			guide = to_player
		if guide == Vector2.ZERO:
			guide = desired_dir

		var d1: float = t1.dot(guide)
		var d2: float = t2.dot(guide)

		if absf(d1 - d2) < 0.10:
			chosen = (t1 if _wall_hand > 0 else t2)
		else:
			chosen = (t1 if d1 > d2 else t2)

	if chosen == Vector2.ZERO:
		return

	# Start / refresh wall slide
	if _wall_slide_t <= 0.0:
		_wall_since_best = 0.0
		_wall_best_cost = (ff.sample_cost(_e.global_position) if ff != null and is_instance_valid(ff) and ff.has_method("sample_cost") else INF_COST)

	_wall_hand = (1 if chosen == t1 else -1)
	_wall_slide_dir = chosen
	_wall_slide_t = _e.wall_slide_time


# -------------------------------------------------------------------
# Rare fallback unstick
# -------------------------------------------------------------------

func _apply_stuck_nudge(move: Vector2, delta: float) -> Vector2:
	if not _e.stuck_nudge_enabled:
		_stuck_last_pos = _e.global_position
		_stuck_t = 0.0
		_nudge_t = 0.0
		return move

	if move.length_squared() < 1.0:
		_stuck_last_pos = _e.global_position
		_stuck_t = maxf(_stuck_t - delta * 2.0, 0.0)
		_nudge_t = maxf(_nudge_t - delta, 0.0)
		return move

	var moved: float = _e.global_position.distance_to(_stuck_last_pos)
	_stuck_last_pos = _e.global_position

	var min_move: float = _e.stuck_min_move_px_per_sec * delta
	if moved < min_move:
		_stuck_t += delta
	else:
		_stuck_t = maxf(_stuck_t - delta * 2.0, 0.0)

	if _nudge_t > 0.0:
		_nudge_t = maxf(_nudge_t - delta, 0.0)
	elif _stuck_t >= _e.stuck_time_to_nudge:
		_stuck_t = 0.0
		_nudge_t = _e.stuck_nudge_time
		_nudge_side *= -1

	if _nudge_t > 0.0:
		var dir: Vector2 = move.normalized()
		var perp: Vector2 = Vector2(-dir.y, dir.x) * float(_nudge_side)
		var blended: Vector2 = (dir * (1.0 - _e.stuck_nudge_strength) + perp * _e.stuck_nudge_strength).normalized()
		return blended * move.length()

	return move


func _sample_sep(radius: float, max_neighbors: int) -> Vector2:
	var now: int = Time.get_ticks_msec()
	if now < _sep_next_msec:
		return _sep_cached
	_sep_next_msec = now + 60
	if _sep_sys == null or not is_instance_valid(_sep_sys):
		_sep_sys = _e.get_tree().get_first_node_in_group(&"enemy_sep")
	if _sep_sys == null or not is_instance_valid(_sep_sys):
		return Vector2.ZERO
	if not _sep_sys.has_method("sample_sep"):
		return Vector2.ZERO
	_sep_cached = _sep_sys.call("sample_sep", _e, radius, max_neighbors) as Vector2
	return _sep_cached

func _smooth(move: Vector2, ai: int, delta: float) -> Vector2:
	# Turn/accel feel per role (simple + cheap)
	var base: float = maxf(60.0, _e._spd())
	var accel: float = base * 10.0

	# shooters/snipers feel better if they don't “snap”
	if ai == EnemySpec.AI.RANGED or ai == EnemySpec.AI.SNIPER or ai == EnemySpec.AI.TACTICAL:
		accel = base * 7.0

	_smoothed_move = _smoothed_move.move_toward(move, accel * delta)
	return _smoothed_move
