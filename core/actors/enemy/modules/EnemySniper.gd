extends RefCounted
class_name EnemySniper

const Accessibility := preload("res://core/settings/AccessibilityPresentation.gd")

enum State { IDLE, RELOCATE, WINDUP }

var _owner: EnemyActor = null
var _state: int = State.IDLE

var _cd: float = 0.0
var _windup_left: float = 0.0

var _aim_dir: Vector2 = Vector2.RIGHT
var _aim_ang: float = 0.0

var _tele: Line2D = null

# relocation / perch logic
var _dt: float = 1.0 / 60.0
var _spot: Vector2 = Vector2.ZERO
var _has_spot: bool = false
var _spot_repick_cd: float = 0.0
var _no_los_t: float = 0.0

var _rng := RandomNumberGenerator.new()


func setup(owner: EnemyActor) -> void:
	_owner = owner
	_rng.randomize()

	_cd = _rng.randf_range(0.3, 0.9)
	_state = State.IDLE
	_windup_left = 0.0

	_dt = 1.0 / 60.0
	_spot = Vector2.ZERO
	_has_spot = false
	_spot_repick_cd = _rng.randf_range(0.2, 0.6)
	_no_los_t = 0.0

	_free_telegraph()


func tick(delta: float) -> void:
	if _owner == null or not is_instance_valid(_owner):
		_free_telegraph()
		return

	_dt = delta
	_cd = maxf(_cd - delta, 0.0)
	_spot_repick_cd = maxf(_spot_repick_cd - delta, 0.0)

	# advance telegraph time (stored on the Line2D via meta, no extra member vars)
	if _tele != null and is_instance_valid(_tele):
		var tt: float = 0.0
		var tv: Variant = _tele.get_meta("_t", 0.0)
		if typeof(tv) == TYPE_FLOAT or typeof(tv) == TYPE_INT:
			tt = float(tv)
		_tele.set_meta("_t", tt + delta)

	if _state == State.WINDUP:
		_windup_left = maxf(_windup_left - delta, 0.0)

		# Elite tracks slowly during windup (base locks)
		if _owner.is_elite:
			_track_aim(delta)

		_update_telegraph()

		# If player hard breaks LOS during windup, cancel (prevents unfair “through wall” feeling)
		if not _has_los_to_player():
			_no_los_t += delta
			if _no_los_t > 0.20:
				_state = State.RELOCATE
				_free_telegraph()
				_cd = maxf(_read_spec_float(_owner.spec, &"sniper_cooldown", 0.4) * 0.35, 0.12)
				return
		else:
			_no_los_t = 0.0

		if _windup_left <= 0.0:
			_fire()
			_state = State.IDLE
			_free_telegraph()
			var s: EnemySpec = _owner.spec
			_cd = maxf(_read_spec_float(s, &"sniper_cooldown", 0.4), 0.1)


func brain(to_player: Vector2, dist: float, spd: float) -> Vector2:
	if _owner == null or _owner.spec == null:
		return to_player * spd

	var s: EnemySpec = _owner.spec

	# Track LOS break time (used to force relocation)
	if _has_los_to_player():
		_no_los_t = maxf(_no_los_t - _dt * 3.0, 0.0)
	else:
		_no_los_t += _dt

	# If currently winding up, movement is constrained
	if _state == State.WINDUP:
		return _sniper_move(to_player, dist, spd, s.sniper_move_mul_during_windup)

	# Decide if we should relocate
	var min_d: float = s.preferred_range - s.range_tolerance
	var too_close: bool = dist < (min_d * 0.95)
	var los_bad: bool = _no_los_t > 0.75

	# Repick if too close, LOS has been broken too long, or no spot yet
	if (too_close or los_bad or not _has_spot) and _spot_repick_cd <= 0.0:
		_has_spot = _pick_shoot_spot()
		_spot_repick_cd = _rng.randf_range(0.55, 0.95)
		if _has_spot:
			_state = State.RELOCATE

	# If we have a perch spot and we're relocating, navigate there
	if _state == State.RELOCATE and _has_spot:
		var move_to: Vector2 = _navigate_to_point(_spot, spd)
		if move_to == Vector2.ZERO or _owner.global_position.distance_squared_to(_spot) <= (22.0 * 22.0):
			_state = State.IDLE
		return move_to

	# Try to start a shot (prefer doing this while IDLE / not relocating)
	if _state == State.IDLE and _cd <= 0.0:
		if dist <= s.sniper_range and _has_los_to_player():
			_start_windup(to_player)
			return _sniper_move(to_player, dist, spd, s.sniper_move_mul_during_windup)

	# Default movement when not shooting: keep around preferred range
	return _sniper_move(to_player, dist, spd, 1.0)


# Let other systems (EnemyHordeNav) know when we’re doing “deliberate relocation”
func is_relocating() -> bool:
	return _state == State.RELOCATE


func is_combat_committed() -> bool:
	return (
		_state == State.WINDUP
		or _state == State.RELOCATE
		or (_tele != null and is_instance_valid(_tele))
	)


# --------------------
# Internals: windup / aim
# --------------------
func _start_windup(to_player: Vector2) -> void:
	var s: EnemySpec = _owner.spec

	_state = State.WINDUP
	_windup_left = maxf(s.sniper_windup, 0.05)
	_no_los_t = 0.0

	# Base behavior: lock aim now.
	_aim_dir = (to_player.normalized() if to_player.length_squared() > 0.0001 else Vector2.RIGHT)
	_aim_ang = _aim_dir.angle()

	_ensure_telegraph()
	_update_telegraph()


func _track_aim(delta: float) -> void:
	# Elite behavior: track slowly during windup with capped turn speed
	if _owner == null or _owner.player == null:
		return

	var s: EnemySpec = _owner.spec
	var desired: Vector2 = (_owner.player.global_position - _owner.global_position)
	if desired.length_squared() < 0.0001:
		return

	var desired_ang: float = desired.angle()

	var diff: float = wrapf(desired_ang - _aim_ang, -PI, PI)
	var max_step: float = maxf(s.sniper_track_turn_speed, 0.0) * delta
	diff = clampf(diff, -max_step, max_step)

	_aim_ang += diff
	_aim_dir = Vector2.RIGHT.rotated(_aim_ang)


func _sniper_move(to_player: Vector2, dist: float, spd: float, mul: float) -> Vector2:
	var s: EnemySpec = _owner.spec

	var out: Vector2 = Vector2.ZERO
	var min_d: float = s.preferred_range - s.range_tolerance
	var max_d: float = s.preferred_range + s.range_tolerance

	if dist < min_d:
		out = -to_player * spd
	elif dist > max_d:
		out = to_player * spd * 0.45

	# soft strafe (keeps it interesting)
	var strafe: Vector2 = Vector2(-to_player.y, to_player.x)
	out += strafe * (spd * s.strafe_strength * 0.65)

	return out * mul


# --------------------
# Perch selection / navigation
# --------------------
func _navigate_to_point(p: Vector2, spd: float) -> Vector2:
	if _owner == null or not is_instance_valid(_owner):
		return Vector2.ZERO

	# Use navigator if available, else direct steer
	if _owner._nav != null:
		return _owner._nav.apply(_dt, p, spd, _owner.cover_mask())

	var v: Vector2 = p - _owner.global_position
	return (v.normalized() * spd if v.length_squared() > 4.0 else Vector2.ZERO)


func _pick_shoot_spot() -> bool:
	if _owner == null or _owner.spec == null:
		return false
	if _owner.player == null or not is_instance_valid(_owner.player):
		return false

	var s: EnemySpec = _owner.spec
	var player_pos: Vector2 = _owner.player.global_position

	var ideal_r: float = clampf(s.sniper_range * 0.78, s.preferred_range + 60.0, s.sniper_range * 0.92)
	var samples: int = 12

	var best_score: float = -INF
	var best: Vector2 = Vector2.ZERO
	var found: bool = false

	for i in range(samples):
		var ang: float = (TAU * float(i) / float(samples)) + _rng.randf_range(-0.22, 0.22)
		var rr: float = ideal_r * _rng.randf_range(0.88, 1.06)
		var cand: Vector2 = player_pos + Vector2.RIGHT.rotated(ang) * rr

		# Avoid picking points inside movement blockers
		if _movement_blocked(cand):
			continue

		# Must have LOS to player (ignoring enemies)
		if not _los_from_point(cand, player_pos):
			continue

		var d_to_p: float = cand.distance_to(player_pos)
		if d_to_p > s.sniper_range * 0.98:
			continue

		# Score: prefer close to ideal radius, prefer not too close, prefer low travel cost
		var range_score: float = -absf(d_to_p - ideal_r)
		var far_bias: float = d_to_p * 0.03
		var travel_cost: float = -_owner.global_position.distance_to(cand) * 0.18

		var score: float = range_score + far_bias + travel_cost
		if score > best_score:
			best_score = score
			best = cand
			found = true

	if found:
		_spot = best
		return true

	return false


func _movement_blocked(p: Vector2) -> bool:
	var w: World2D = _owner.get_world_2d()
	if w == null:
		return false

	var mask: int = int(_owner.collision_mask)
	if mask == 0:
		return false

	var space: PhysicsDirectSpaceState2D = w.direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = p
	params.collision_mask = mask
	params.collide_with_areas = true
	params.collide_with_bodies = true

	if _owner._senses != null:
		params.exclude = _owner._senses.get_exclude_rids()

	var hits: Array = space.intersect_point(params, 1)
	return not hits.is_empty()


func _los_from_point(from: Vector2, to: Vector2) -> bool:
	var hit: Dictionary = _ray_first_non_enemy(from, to)
	if hit.is_empty():
		return true

	var col: Object = hit.get("collider", null) as Object
	if col is Node:
		var n := col as Node
		return n.is_in_group("player") or n.is_in_group("player_hurtbox")

	return false


# --------------------
# Fire / ray logic (your existing “ignore enemies” approach)
# --------------------
func _fire() -> void:
	var s: EnemySpec = _owner.spec
	if s == null:
		return

	var dmg_base: float = _read_spec_float(s, &"sniper_damage", 0.0)
	if dmg_base <= 0.0:
		return

	var from: Vector2 = _owner.global_position
	var dir: Vector2 = (_aim_dir.normalized() if _aim_dir.length_squared() > 0.0001 else Vector2.RIGHT)

	var length: float = maxf(_read_spec_float(s, &"sniper_beam_length", 1200.0), 100.0)
	var half_w: float = maxf(_read_spec_float(s, &"sniper_beam_width", 0.0), 0.0) * 0.5
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	# compute a nice “visual end” for the flash (center ray)
	var to_vis: Vector2 = from + dir * length
	var hit_vis: Dictionary = _ray_first_non_enemy(from, to_vis)
	if not hit_vis.is_empty():
		to_vis = hit_vis.get("position", to_vis) as Vector2

	# SHOT VFX: bright flash + end pop
	var w_vis: float = maxf(_read_spec_float(s, &"sniper_beam_width", 18.0), 18.0)
	_spawn_beam_flash(from, to_vis, w_vis)
	_spawn_end_pop(to_vis, dir, w_vis)

	# 3 rays to approximate width: center + left + right
	var hit_player: bool = false
	hit_player = hit_player or _ray_hits_player(from + perp * 0.0, dir, length)
	if half_w > 0.5:
		hit_player = hit_player or _ray_hits_player(from + perp * half_w, dir, length)
		hit_player = hit_player or _ray_hits_player(from - perp * half_w, dir, length)

	if hit_player and _owner.player != null and _owner.player.has_method("take_damage"):
		_owner.player.call("take_damage", dmg_base, _owner)


func _ray_hits_player(from: Vector2, dir: Vector2, length: float) -> bool:
	var end: Vector2 = from + dir * length
	var hit: Dictionary = _ray_first_non_enemy(from, end)

	if hit.is_empty():
		return false

	var col: Object = hit.get("collider", null) as Object
	if col == null:
		return false

	if col is Node:
		var n: Node = col as Node
		if n.is_in_group("player") or n.is_in_group("player_hurtbox"):
			return true

	return false


func _has_los_to_player() -> bool:
	# Uses same ray logic: if first non-enemy is player/hurtbox => LOS
	if _owner == null or _owner.player == null:
		return false

	var from: Vector2 = _owner.global_position
	var to: Vector2 = _owner.player.global_position
	var hit: Dictionary = _ray_first_non_enemy(from, to)

	if hit.is_empty():
		return true # nothing blocks it

	var col: Object = hit.get("collider", null) as Object
	if col is Node:
		var n := col as Node
		return n.is_in_group("player") or n.is_in_group("player_hurtbox")

	return false


func _ray_first_non_enemy(from: Vector2, to: Vector2) -> Dictionary:
	# Cast ray; if it hits an enemy/enemy_hitbox, skip it and cast again.
	# Stops on first obstacle/player. Prevents mobs from body-blocking the sniper.
	var w := _owner.get_world_2d()
	if w == null:
		return {}

	var space := w.direct_space_state
	var params := PhysicsRayQueryParameters2D.new()
	params.from = from
	params.to = to
	params.collide_with_areas = true
	params.collide_with_bodies = true
	params.collision_mask = 0xFFFFFFFF

	var ex: Array[RID] = []
	ex.append(_owner.get_rid())

	var hb: Area2D = _owner.get_node_or_null("Hitbox") as Area2D
	if hb != null:
		ex.append(hb.get_rid())

	params.exclude = ex

	var tries: int = 0
	var cur_from: Vector2 = from
	while tries < 8:
		params.from = cur_from
		var hit: Dictionary = space.intersect_ray(params)
		if hit.is_empty():
			return {}

		var col: Object = hit.get("collider", null) as Object
		var rid: RID = hit.get("rid", RID()) as RID

		if col is Node:
			var n: Node = col as Node
			if n.is_in_group("enemies") or n.is_in_group("enemy_hitbox"):
				# skip this enemy collider and continue
				if rid.is_valid():
					ex.append(rid)
					params.exclude = ex
				var pos: Vector2 = hit.get("position", cur_from) as Vector2
				var step_dir: Vector2 = (to - from)
				step_dir = (step_dir.normalized() if step_dir.length_squared() > 0.0001 else Vector2.RIGHT)
				cur_from = pos + step_dir * 0.75
				tries += 1
				continue

		return hit

	return {}


# --------------------
# Telegraph visuals (kept from your version)
# --------------------
func _ensure_telegraph() -> void:
	if _tele != null and is_instance_valid(_tele):
		return

	_tele = Line2D.new()
	_tele.top_level = true
	_tele.antialiased = true
	_tele.z_index = 200

	var s: EnemySpec = _owner.spec
	var w: float = maxf(_read_spec_float(s, &"sniper_beam_width", 14.0), 14.0)
	_tele.width = w
	_tele.default_color = Color(1.0, 0.35, 0.20, 0.25)
	_tele.joint_mode = Line2D.LINE_JOINT_ROUND
	_tele.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_tele.end_cap_mode = Line2D.LINE_CAP_ROUND

	# Glow line (child)
	var glow := Line2D.new()
	glow.name = "Glow"
	glow.top_level = true
	glow.antialiased = true
	glow.z_index = 199
	glow.width = w * 2.6
	glow.default_color = Color(1.0, 0.15, 0.95, 0.18)
	glow.joint_mode = Line2D.LINE_JOINT_ROUND
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND

	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = glow_mat

	# End marker tick (child)
	var mark := Line2D.new()
	mark.name = "EndMark"
	mark.top_level = true
	mark.antialiased = true
	mark.z_index = 201
	mark.width = maxf(2.0, w * 0.12)
	mark.default_color = Color(1.0, 0.75, 0.35, 0.55)
	mark.joint_mode = Line2D.LINE_JOINT_ROUND
	mark.begin_cap_mode = Line2D.LINE_CAP_ROUND
	mark.end_cap_mode = Line2D.LINE_CAP_ROUND

	var mark_mat := CanvasItemMaterial.new()
	mark_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mark.material = mark_mat

	_owner.get_tree().current_scene.add_child(glow)
	_owner.get_tree().current_scene.add_child(_tele)
	_owner.get_tree().current_scene.add_child(mark)

	_tele.set_meta("_glow_id", glow.get_instance_id())
	_tele.set_meta("_mark_id", mark.get_instance_id())
	_tele.set_meta("_t", 0.0)


func _update_telegraph() -> void:
	if _tele == null or not is_instance_valid(_tele):
		return
	if _owner == null or _owner.spec == null:
		return

	var s: EnemySpec = _owner.spec
	var from: Vector2 = _owner.global_position
	var dir: Vector2 = (_aim_dir.normalized() if _aim_dir.length_squared() > 0.0001 else Vector2.RIGHT)

	var length: float = maxf(_read_spec_float(s, &"sniper_beam_length", 1200.0), 100.0)
	var to: Vector2 = from + dir * length

	# stop telegraph at first obstacle (but still ignore enemies)
	var hit: Dictionary = _ray_first_non_enemy(from, to)
	if not hit.is_empty():
		var pos: Vector2 = hit.get("position", to) as Vector2
		to = pos

	# time + windup progress
	var tt: float = 0.0
	var tv: Variant = _tele.get_meta("_t", 0.0)
	if typeof(tv) == TYPE_FLOAT or typeof(tv) == TYPE_INT:
		tt = float(tv)

	var windup_total: float = maxf(_read_spec_float(s, &"sniper_windup", 0.25), 0.05)
	var prog: float = 1.0 - clampf(_windup_left / windup_total, 0.0, 1.0) # 0->1

	var pulse: float = 0.75 + 0.25 * sin(tt * TAU * 2.5)
	var jitter: float = (0.4 + 1.6 * prog) * sin(tt * 18.0)
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	var from2: Vector2 = from + perp * jitter
	var to2: Vector2 = to + perp * jitter

	var base_w: float = maxf(_read_spec_float(s, &"sniper_beam_width", 14.0), 14.0)
	var core_w: float = base_w * (0.82 + 0.28 * prog)
	var glow_w: float = core_w * 2.6

	var a_core: float = lerpf(0.22, 0.78, prog) * pulse
	var a_glow: float = lerpf(0.10, 0.34, prog) * pulse
	var a_mark: float = lerpf(0.35, 0.85, prog) * (0.85 + 0.15 * sin(tt * TAU * 4.0))

	_tele.width = core_w
	_tele.default_color = Color(1.0, 0.35, 0.20, a_core)
	_tele.clear_points()
	_tele.add_point(from2)
	_tele.add_point(to2)

	var glow: Line2D = null
	var mark: Line2D = null

	var gid_v: Variant = _tele.get_meta("_glow_id", 0)
	if typeof(gid_v) == TYPE_INT:
		var gobj := instance_from_id(int(gid_v))
		glow = gobj as Line2D

	var mid_v: Variant = _tele.get_meta("_mark_id", 0)
	if typeof(mid_v) == TYPE_INT:
		var mobj := instance_from_id(int(mid_v))
		mark = mobj as Line2D

	if glow != null and is_instance_valid(glow):
		glow.width = glow_w
		glow.default_color = Color(1.0, 0.15, 0.95, a_glow)
		glow.clear_points()
		glow.add_point(from2)
		glow.add_point(to2)

	if mark != null and is_instance_valid(mark):
		var tick_len: float = maxf(10.0, base_w * 0.55) * (0.85 + 0.25 * prog)
		mark.width = maxf(2.0, base_w * 0.12)
		mark.default_color = Color(1.0, 0.75, 0.35, a_mark)

		var p0: Vector2 = to2 - perp * (tick_len * 0.5)
		var p1: Vector2 = to2 + perp * (tick_len * 0.5)

		mark.clear_points()
		mark.add_point(p0)
		mark.add_point(p1)


func _free_telegraph() -> void:
	if _tele != null and is_instance_valid(_tele):
		var gid_v: Variant = _tele.get_meta("_glow_id", 0)
		if typeof(gid_v) == TYPE_INT:
			var gobj := instance_from_id(int(gid_v))
			var glow := gobj as Line2D
			if glow != null and is_instance_valid(glow):
				glow.queue_free()

		var mid_v: Variant = _tele.get_meta("_mark_id", 0)
		if typeof(mid_v) == TYPE_INT:
			var mobj := instance_from_id(int(mid_v))
			var mark := mobj as Line2D
			if mark != null and is_instance_valid(mark):
				mark.queue_free()

		_tele.queue_free()

	_tele = null


# --------------------
# helpers
# --------------------
func _read_spec_float(spec: Object, prop: StringName, fallback: float) -> float:
	if spec == null:
		return fallback
	var v: Variant = spec.get(prop)
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return fallback


func _spawn_beam_flash(from: Vector2, to: Vector2, width: float) -> void:
	var alpha := Accessibility.current_flash_alpha(0.95)
	if alpha <= 0.0:
		return
	var flash := Line2D.new()
	flash.top_level = true
	flash.antialiased = true
	flash.z_index = 260
	flash.width = width * 1.05
	flash.default_color = Color(1, 1, 1, alpha)
	flash.joint_mode = Line2D.LINE_JOINT_ROUND
	flash.begin_cap_mode = Line2D.LINE_CAP_ROUND
	flash.end_cap_mode = Line2D.LINE_CAP_ROUND

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.material = mat

	flash.add_point(from)
	flash.add_point(to)

	_owner.get_tree().current_scene.add_child(flash)

	var tw := flash.create_tween()
	tw.tween_property(flash, "modulate", Color(1, 1, 1, 0), 0.09)
	tw.tween_callback(Callable(flash, "queue_free"))


func _spawn_end_pop(pos: Vector2, dir: Vector2, width: float) -> void:
	var alpha := Accessibility.current_flash_alpha(0.9)
	if alpha <= 0.0:
		return
	var pop := Line2D.new()
	pop.top_level = true
	pop.antialiased = true
	pop.z_index = 261
	pop.width = maxf(2.0, width * 0.10)
	pop.default_color = Color(1.0, 0.85, 0.45, alpha)
	pop.joint_mode = Line2D.LINE_JOINT_ROUND
	pop.begin_cap_mode = Line2D.LINE_CAP_ROUND
	pop.end_cap_mode = Line2D.LINE_CAP_ROUND

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pop.material = mat

	var d := (dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT)
	var perp := Vector2(-d.y, d.x)
	var r: float = maxf(10.0, width * 0.45)

	pop.add_point(pos - perp * r)
	pop.add_point(pos + perp * r)

	_owner.get_tree().current_scene.add_child(pop)

	var tw := pop.create_tween()
	tw.tween_property(pop, "modulate", Color(1, 1, 1, 0), 0.10)
	tw.tween_callback(Callable(pop, "queue_free"))


func is_winding_up() -> bool:
	return _state == State.WINDUP


func windup_mul() -> float:
	if _owner == null or _owner.spec == null:
		return 1.0
	if _state == State.WINDUP:
		return maxf(_read_spec_float(_owner.spec, &"sniper_move_mul_during_windup", 1.0), 0.0)
	return 1.0


func cleanup() -> void:
	_free_telegraph()
