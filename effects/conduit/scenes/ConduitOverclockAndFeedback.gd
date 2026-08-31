extends SetEffectBase

signal active_cd_changed(time_left: float, max_cd: float)
signal active_failed(message: String)

@export var vfx_shock_ring_scene: PackedScene # legacy (leave EMPTY / null)
@export var vfx_pulse_ring_scene: PackedScene # assign PulseRing.tscn (updated)
@export var vfx_spokes_scene: PackedScene     # assign SpokesBurst.tscn (updated)

# NEW: better shape-language VFX
@export var vfx_cleave_arc_scene: PackedScene # assign VFX_CleaveArc.tscn
@export var vfx_explosive_t_scene: PackedScene # assign VFX_ExplosiveT.tscn

@export var hud_priority: int = 10
@export var hud_key_text: String = "R"
@export var hud_title_text: String = "Circuit Feedback"
@export var hud_icon: Texture2D

# ---- passive: Overclock ----
@export var overclock_duration: float = 2.5
@export var overclock_move_mul: float = 1.18
@export var overclock_haste_mul: float = 1.22

# Ranged identity: split shot
@export var split_angle_deg: float = 10.0
@export var split_damage_mult: float = 0.75
@export var try_add_pierce: bool = true

# Melee: cleave + hits around player (mechanics unchanged)
@export var melee_lash_radius: float = 220.0
@export var melee_lash_targets: int = 4
@export var melee_lash_damage_mult: float = 0.65
@export var melee_lash_knockback: float = 180.0
@export var melee_lash_stun: float = 0.10

# Magic: Explosive T out-and-back (fewer, cleaner pings)
@export var magic_barrage_steps: int = 3
@export var magic_barrage_side_hits: int = 2
@export var magic_barrage_side_offset: float = 70.0
@export var magic_barrage_damage_mult: float = 0.55
@export var magic_return_delay: float = 0.18

# Ranged: minigun burst after split
@export var burst_count: int = 5
@export var burst_interval: float = 0.05
@export var burst_spread_deg: float = 6.0
@export var burst_damage_mult: float = 0.45

var _overclock_time: float = 0.0
var _prime_next_shot: bool = false

var _last_kill_pos: Vector2 = Vector2.ZERO
var _has_last_kill_pos: bool = false

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ranged burst state
var _burst_scn: PackedScene = null
var _burst_origin: Vector2 = Vector2.ZERO
var _burst_dir: Vector2 = Vector2.RIGHT
var _burst_damage: float = 0.0
var _burst_shots_left: int = 0
var _burst_timer: float = 0.0
var _burst_spread_rad: float = 0.0

# ---- active: Circuit Feedback ----
@export var active_base_cd: float = 8.0
@export var active_radius: float = 140.0
@export var active_damage_mult: float = 0.9
@export var active_knockback: float = 520.0
@export var active_stun: float = 0.45

var _active_cd: float = 0.0
var _active_cd_max: float = 0.0
var _last_cd_report: float = -999.0

func _init() -> void:
	effect_id = &"conduit_6_overclock_feedback"

func _ready() -> void:
	_rng.randomize()
	RunEvents.enemy_killed.connect(_on_enemy_killed)
	RunEvents.weapon_fired.connect(_on_weapon_fired)
	_report_active_cd(true)

func _exit_tree() -> void:
	if RunEvents.enemy_killed.is_connected(_on_enemy_killed):
		RunEvents.enemy_killed.disconnect(_on_enemy_killed)
	if RunEvents.weapon_fired.is_connected(_on_weapon_fired):
		RunEvents.weapon_fired.disconnect(_on_weapon_fired)

func _process(dt: float) -> void:
	if _overclock_time > 0.0:
		_overclock_time = max(_overclock_time - dt, 0.0)

	if _active_cd > 0.0:
		_active_cd = max(_active_cd - dt, 0.0)

	# Ranged burst tick
	if _burst_shots_left > 0 and _burst_scn != null:
		_burst_timer -= dt
		while _burst_shots_left > 0 and _burst_timer <= 0.0:
			var a: float = _rng.randf_range(-_burst_spread_rad, _burst_spread_rad)
			_spawn_bullet(_burst_scn, _burst_origin, _burst_dir.rotated(a), _burst_damage)
			_burst_shots_left -= 1
			_burst_timer += max(burst_interval, 0.01)

	# Active (R)
	if player != null and Input.is_action_just_pressed("set_active"):
		_try_circuit_feedback()

	_report_active_cd()

func _on_enemy_killed(p: Node, _enemy: Node, pos: Vector2) -> void:
	if p != player:
		return
	_overclock_time = overclock_duration
	_prime_next_shot = true

	_last_kill_pos = pos
	_has_last_kill_pos = true

func get_move_speed_multiplier() -> float:
	return overclock_move_mul if _overclock_time > 0.0 else 1.0

func get_haste_multiplier() -> float:
	return overclock_haste_mul if _overclock_time > 0.0 else 1.0

func _on_weapon_fired(p: Node, style_id: StringName, origin: Vector2, target: Vector2, power_mul: float, _haste_mul: float) -> void:
	if p != player:
		return
	if not _prime_next_shot:
		return

	_prime_next_shot = false

	var base_dir: Vector2 = (target - origin).normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.RIGHT

	var ang: float = deg_to_rad(split_angle_deg)

	# match multipliers
	var style_mul: float = 1.0
	if style_id == &"melee":
		style_mul = 1.25
	elif style_id == &"magic":
		style_mul = 1.15

	var base_dmg: float = _get_player_base_damage()
	var main_like_dmg: float = base_dmg * style_mul * power_mul * set_strength

	# --- RANGED
	if style_id == &"ranged":
		var scn: PackedScene = player.get("ranged_bullet_scene") as PackedScene
		if scn == null:
			return

		var split_dmg: float = base_dmg * split_damage_mult * power_mul * set_strength
		_spawn_bullet(scn, origin, base_dir.rotated(ang), split_dmg)
		_spawn_bullet(scn, origin, base_dir.rotated(-ang), split_dmg)

		var aim: Vector2 = target
		if _has_last_kill_pos:
			aim = _last_kill_pos
		_start_ranged_burst(origin, aim, base_dmg * power_mul * burst_damage_mult * set_strength)
		return

	# --- MELEE (clean cleave VFX)
	if style_id == &"melee":
		_melee_lashes(origin, target, main_like_dmg)
		return

	# --- MAGIC (Explosive T-ish)
	if style_id == &"magic":
		_magic_barrage(origin, target, main_like_dmg)
		return

# ----------------------------
# ACTIVE
# ----------------------------
func _try_circuit_feedback() -> void:
	if player == null:
		return
	if _active_cd > 0.0:
		active_failed.emit("Cooldown %.1fs" % _active_cd)
		return

	var st: Stats = player.get("stats") as Stats

	var haste_mul: float = 1.0
	if st != null:
		haste_mul = 1.0 + maxf(st.haste, -0.9)

	_active_cd = maxf(1.0, active_base_cd / maxf(haste_mul, 0.05))
	_active_cd_max = _active_cd
	_report_active_cd(true)

	var origin: Vector2 = (player as Node2D).global_position

	# VFX
	var r := active_radius * (0.90 + 0.15 * set_strength)
	_spawn_pulse(origin, r)
	_spawn_spokes(origin)

	var base_dmg: float = _get_player_base_damage()

	var power_mul: float = 1.0
	if st != null:
		power_mul = 1.0 + st.power

	var handles: Array[int] = []
	EnemyCombat.gather_in_radius(origin, r, handles)
	for handle in handles:
		var hit_position := EnemyCombat.position_for_handle(handle)
		EnemyCombat.apply_damage(handle, base_dmg * active_damage_mult * power_mul * set_strength, 1, player)
		var direction := (hit_position - origin).normalized()
		EnemyCombat.apply_knockback(handle, direction * active_knockback * (0.85 + 0.25 * set_strength))
		EnemyCombat.apply_stun(handle, active_stun * (0.85 + 0.25 * set_strength))

func get_active_state() -> Dictionary:
	var is_ready: bool = player != null and _active_cd <= 0.05
	var state_parts: Array[String] = []
	state_parts.append("DISCHARGE PRIMED" if _prime_next_shot else "DISCHARGE EMPTY")
	if _overclock_time > 0.0:
		state_parts.append("OVERCLOCK %.1fs" % _overclock_time)
	return {
		"ready": is_ready,
		"cooldown_left": _active_cd,
		"cooldown_max": _active_cd_max if _active_cd_max > 0.0 else active_base_cd,
		"status_text": "READY" if is_ready else String.num(_active_cd, 1),
		"combat_text": " · ".join(state_parts),
	}

func debug_prime_discharge(enabled: bool = true) -> void:
	_prime_next_shot = enabled

func debug_set_overclock(seconds: float = 2.5) -> void:
	_overclock_time = maxf(0.0, seconds)

func _report_active_cd(force: bool = false) -> void:
	if force or absf(_active_cd - _last_cd_report) > 0.05 or (_active_cd <= 0.0 and _last_cd_report > 0.0):
		_last_cd_report = _active_cd
		active_cd_changed.emit(max(_active_cd, 0.0), max(_active_cd_max, 0.0))

# ----------------------------
# PASSIVE HELPERS
# ----------------------------
func _get_player_base_damage() -> float:
	var v = player.get("base_weapon_damage")
	if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
		return float(v)
	return 12.0

func _start_ranged_burst(origin: Vector2, aim: Vector2, dmg: float) -> void:
	if player == null:
		return

	var scn: PackedScene = player.get("ranged_bullet_scene") as PackedScene
	if scn == null:
		return

	var dir: Vector2 = (aim - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	_burst_scn = scn
	_burst_origin = origin
	_burst_dir = dir
	_burst_damage = dmg
	_burst_shots_left = max(0, burst_count)
	_burst_timer = 0.0
	_burst_spread_rad = deg_to_rad(burst_spread_deg)

func _get_nearest_enemies(center: Vector2, radius: float, max_targets: int) -> Array[int]:
	var out: Array[int] = []
	EnemyCombat.gather_in_radius(center, radius, out)
	out.sort_custom(func(a: int, b: int) -> bool:
		return center.distance_squared_to(EnemyCombat.position_for_handle(a)) < center.distance_squared_to(EnemyCombat.position_for_handle(b))
	)

	if out.size() > max_targets:
		out.resize(max_targets)

	return out

func _spawn_cleave_arc(pos: Vector2, dir: Vector2, r: float) -> void:
	if vfx_cleave_arc_scene == null:
		return
	var n := vfx_cleave_arc_scene.instantiate()
	if n == null:
		return
	get_tree().current_scene.add_child(n)
	if n.has_method("setup"):
		n.call("setup", pos, dir, r)

func _spawn_explosive_t(origin: Vector2, target: Vector2) -> void:
	if vfx_explosive_t_scene == null:
		return

	var n: Node = vfx_explosive_t_scene.instantiate()
	get_tree().current_scene.add_child(n)

	if n.has_method("setup"):
		n.call("setup", origin, target)


func _melee_lashes(origin: Vector2, target: Vector2, dmg: float) -> void:
	var dir := (target - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	# Cleave shape + small pulse (mechanics unchanged)
	_spawn_cleave_arc(origin, dir, melee_lash_radius * 0.55)
	_spawn_pulse(origin, melee_lash_radius * 0.40)

	var targets: Array[int] = _get_nearest_enemies(origin, melee_lash_radius, melee_lash_targets)
	if targets.is_empty():
		return

	for handle in targets:
		var hit_position := EnemyCombat.position_for_handle(handle)
		var hit_dmg: float = dmg * melee_lash_damage_mult

		# Impact burst on enemy (your SpokesBurst now looks good)
		_spawn_spokes(hit_position)
		EnemyCombat.apply_damage(handle, hit_dmg, 1, player)
		EnemyCombat.apply_knockback(handle, (hit_position - origin).normalized() * melee_lash_knockback)
		EnemyCombat.apply_stun(handle, melee_lash_stun)

func _magic_barrage(origin: Vector2, target: Vector2, dmg: float) -> void:
	if player == null:
		return

	_spawn_explosive_t(origin, target)

	var dmg_hit := dmg * magic_barrage_damage_mult
	var dir := (target - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	# outbound pings (clean line)
	var out_hits := clampi(magic_barrage_steps, 2, 5)
	for i in range(1, out_hits + 1):
		var t := float(i) / float(out_hits + 1)
		player.call("_spawn_magic", origin.lerp(target, t), dmg_hit)

	# impact pop
	player.call("_spawn_magic", target, dmg_hit * 1.20)
	_spawn_spokes(target)

	# small side shrapnel near impact (kept but controlled)
	var perp := Vector2(-dir.y, dir.x)
	var side := clampi(magic_barrage_side_hits, 0, 4)
	for j in range(side):
		var side_sign := -1.0 if (j % 2 == 0) else 1.0
		var p2 := target + perp * side_sign * (magic_barrage_side_offset * 0.55) + dir * _rng.randf_range(-18.0, 18.0)
		player.call("_spawn_magic", p2, dmg_hit * 0.75)

	# return pings after delay (Explosives T “comes back”)
	var ret_hits := clampi(out_hits + 1, 3, 6)
	var origin_copy := origin
	var target_copy := target
	var dmg_copy := dmg_hit
	var player_ref := player

	get_tree().create_timer(max(0.01, magic_return_delay)).timeout.connect(func() -> void:
		if player_ref == null or not is_instance_valid(player_ref):
			return
		for i in range(1, ret_hits + 1):
			var t := float(i) / float(ret_hits + 1)
			player_ref.call("_spawn_magic", target_copy.lerp(origin_copy, t), dmg_copy)
	)

# ----------------------------
# BULLET SPAWN (unchanged)
# ----------------------------
func _spawn_pulse(pos: Vector2, radius: float) -> void:
	var scn: PackedScene = vfx_pulse_ring_scene
	if scn == null:
		scn = vfx_shock_ring_scene
	if scn == null:
		return

	var n: Node = scn.instantiate()
	if n == null:
		return

	get_tree().current_scene.add_child(n)

	if n.has_method("setup"):
		n.call("setup", pos, radius)
	elif n is Node2D:
		(n as Node2D).global_position = pos

func _spawn_spokes(pos: Vector2) -> void:
	if vfx_spokes_scene == null:
		return

	var n: Node = vfx_spokes_scene.instantiate()
	if n == null:
		return

	get_tree().current_scene.add_child(n)

	if n.has_method("setup"):
		n.call("setup", pos)
	elif n is Node2D:
		(n as Node2D).global_position = pos

func _spawn_bullet(scn: PackedScene, pos: Vector2, dir: Vector2, dmg: float) -> void:
	var bullet := scn.instantiate()
	if bullet == null:
		return

	if bullet is Node2D:
		(bullet as Node2D).global_position = pos

	var hb: Area2D = player.get_node_or_null("Hurtbox") as Area2D
	if hb != null and bullet is CollisionObject2D:
		(bullet as CollisionObject2D).collision_layer = hb.collision_layer
		(bullet as CollisionObject2D).collision_mask = hb.collision_mask

	bullet.set("damage", dmg)

	var speed_val := 600.0
	var s = bullet.get("speed")
	if typeof(s) in [TYPE_INT, TYPE_FLOAT]:
		speed_val = float(s)
	bullet.set("velocity", dir.normalized() * speed_val)

	if try_add_pierce:
		if bullet.get("pierce") != null:
			bullet.set("pierce", 1)
		elif bullet.get("pierce_count") != null:
			bullet.set("pierce_count", 1)

	bullet.add_to_group("player_projectile")
	get_tree().current_scene.add_child(bullet)


func reset_cooldowns() -> void:
	_active_cd = 0.0
	_active_cd_max = 0.0
	_report_active_cd(true)
