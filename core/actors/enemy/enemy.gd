extends CharacterBody2D
class_name EnemyActor

@export var spec: EnemySpec

# fallback if spec is null (and also used by EnemyDrops module)
@export var item_pickup_scene: PackedScene
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 0.25
@export var drop_pool_prefixes: PackedStringArray = ["conduit_","lattice_","gravemarch_","acc_","ring_"]
@export var drop_fallback_to_all: bool = false
@export var drop_amount_min: int = 1
@export var drop_amount_max: int = 1
@export var drop_instance_roll: bool = true
@export var drop_rarity_min: int = 0
@export var drop_rarity_max: int = 0
@export var drop_force_polarity: int = 0
@export var pickup_delay: float = 0.25
@export var drop_spawn_radius: float = 18.0

@export_group("Health Pickup Drops")
@export_range(0.0, 1.0, 0.005) var health_drop_chance: float = 0.03
@export_range(0.01, 1.0, 0.01) var health_drop_restore_fraction: float = 0.20
@export_range(1.0, 120.0, 1.0) var health_drop_lifetime: float = 20.0

@export var speed: float = 150.0
@export var max_hp: float = 50.0
@export var knockback_decay: float = 2200.0

@export var debug_hits: bool = false
@export var debug_drops: bool = false

# ------------------------------------------------------------
# Horde nav / performance (used by EnemyHordeNav)
# ------------------------------------------------------------
@export_group("Flow Field Horde Nav")
@export var dumb_pathing_enabled: bool = true # kept name for compatibility
@export var flow_for_swarm_ai: bool = true
@export var flow_smoothing: bool = true
@export_range(0.0, 1.0, 0.01) var flow_blend_to_player: float = 0.20

@export_group("LOS Throttle (smart AIs only)")
@export var los_check_interval: float = 0.15

@export_group("Simulation LOD (ambient swarm only)")
@export var simulation_lod_enabled: bool = true
@export var lod_near_distance: float = 1100.0
@export var lod_mid_distance: float = 2400.0
@export var lod_mid_steer_interval: float = 0.08
@export var lod_far_steer_interval: float = 0.20
@export var lod_population_start: int = 32
@export var lod_population_full_pressure: int = 96
@export var lod_pressured_near_distance: float = 380.0
@export var lod_pressured_mid_distance: float = 1200.0
@export var lod_mid_reduced_population: int = 48
@export_range(0.025, 0.05, 0.001) var lod_mid_physics_interval: float = 0.033
@export_range(0.067, 0.10, 0.001) var lod_far_physics_interval: float = 0.083
@export var lod_disable_far_hitbox: bool = true
@export_range(2, 8, 1) var physics_max_slides: int = 4
@export var sniper_retirement_safety_margin: float = 450.0

# ------------------------------------------------------------
# Corner / wall assist
# ------------------------------------------------------------
@export_group("Wall Slide Assist")
@export var wall_slide_enabled: bool = true
@export var wall_slide_time: float = 0.35
@export_range(0.0, 1.0, 0.01) var wall_slide_strength: float = 0.90
@export var wall_slide_trigger_forward_px: float = 2.0

@export_group("Fallback Unstick (rare)")
@export var stuck_nudge_enabled: bool = true
@export var stuck_min_move_px_per_sec: float = 18.0
@export var stuck_time_to_nudge: float = 0.25
@export var stuck_nudge_time: float = 0.18
@export_range(0.0, 1.0, 0.01) var stuck_nudge_strength: float = 0.55

# ------------------------------------------------------------
# Search / Target Memory (kept for future)
# ------------------------------------------------------------
@export_group("Search / Target Memory")
@export var memory_time: float = 12.0
@export var follow_visible_enemy: bool = true
@export var follow_visible_enemy_max_dist: float = 1200.0
@export var wander_radius: float = 260.0
@export var wander_repick_time: float = 1.0

@export_group("Local Comms")
@export var comm_enabled: bool = true
@export var comm_radius: float = 520.0
@export var comm_broadcast_interval: float = 0.25
@export var comm_require_clear_to_sender: bool = false
@export var hearing_enabled: bool = true
@export var hearing_range: float = 1200.0

# Runtime
var hp: float = 0.0
var player: Node2D = null
var dead: bool = false
var stun_time: float = 0.0
var knockback_vel: Vector2 = Vector2.ZERO


# LOS cache (shared across modules; prevents duplicate raycasts)
var _los_cache: bool = false
var _los_timer: float = 0.0

# Elite
var is_elite: bool = false

# Shared movement helpers
var _orbit_angle: float = 0.0
var _base_speed: float = 0.0

# Temporary speed buff (Herald)
var _speed_mul: float = 1.0
var _speed_mul_time: float = 0.0

# Local slow while inside a wardstone stability field
var _stability_mul: float = 1.0

# Shared references / LOD state
var _flow: FlowFieldNav = null
var _enemy_index: Node = null
var _hitbox: Area2D = null
var _lod_tier: int = 0 # 0 near/full, 1 mid, 2 far
var _lod_steer_left: float = 0.0
var _lod_steer_accum: float = 0.0
var _lod_force_refresh: bool = true
var _cached_chase: Vector2 = Vector2.ZERO
var _cached_nav_target: Vector2 = Vector2.ZERO
var _far_step_left: float = 0.0
var _far_delta_accum: float = 0.0
var _far_last_delta: float = 0.0
var _simulation_motion_scale: float = 1.0
var _ambient_population: int = 0
var _population_refresh_left: float = 0.0

# Modules
var _drops: EnemyDrops = EnemyDrops.new()
var _senses: EnemySenses = EnemySenses.new()
var _nav: EnemyNavigator = EnemyNavigator.new()

var _leech: EnemyLeech = EnemyLeech.new()
var _herald: EnemyHerald = EnemyHerald.new()
var _tactical: EnemyTactical = EnemyTactical.new()
var _charge: EnemyCharge = EnemyCharge.new()
var _shooter: EnemyShooter = EnemyShooter.new()
var _summoner: EnemySummoner = EnemySummoner.new()
var _bomber: EnemyBomber = EnemyBomber.new()
var _splitter: EnemySplitter = EnemySplitter.new()
var _sniper: EnemySniper = EnemySniper.new()

var _life: EnemyLifecycle = EnemyLifecycle.new()
var _init: EnemyInit = EnemyInit.new()

# New: all horde macro+micro steering lives here
var _horde_nav: EnemyHordeNav = EnemyHordeNav.new()


func _ready() -> void:
	_init.setup(self, _drops, _senses, _leech, _herald, _tactical, _charge, _shooter, _life)
	_init.boot()

	_summoner.setup(self)
	_bomber.setup(self)
	_splitter.setup(self)
	_sniper.setup(self)

	_life.setup(self, _drops, _bomber, _splitter)
	_nav.setup(self, _senses)

	add_to_group(&"enemies")

	# Nav helper module
	_horde_nav.setup(self)

	# Desync LOS checks so large hordes don't raycast on the same frame.
	_los_timer = Global._rng.randf_range(0.0, maxf(0.01, los_check_interval))

	# Cache the hot-path references once. Reacquisition only happens if an autoload
	# or scene-owned hitbox is unexpectedly replaced.
	_enemy_index = get_node_or_null("/root/EnemyIndex")
	_hitbox = get_node_or_null("Hitbox") as Area2D
	if _enemy_index != null and is_instance_valid(_enemy_index) and _enemy_index.has_method("register"):
		_enemy_index.call("register", self)

	# The horde helper already handles corners; four solver slides are enough for
	# ordinary enemies and materially cheaper than the previous hard-coded eight.
	safe_margin = 0.04
	max_slides = clampi(physics_max_slides, 2, 8) if _is_lod_eligible(_get_active_ai()) else 8
	_lod_steer_left = Global._rng.randf_range(0.0, maxf(0.01, lod_far_steer_interval))
	_far_step_left = Global._rng.randf_range(0.0, maxf(0.067, lod_far_physics_interval))
	_population_refresh_left = Global._rng.randf_range(0.0, 0.5)

	if RunEvents != null and RunEvents.has_signal("enemy_archetype_encountered"):
		RunEvents.enemy_archetype_encountered.emit(self)


func _exit_tree() -> void:
	if _enemy_index == null or not is_instance_valid(_enemy_index):
		_enemy_index = get_node_or_null("/root/EnemyIndex")
	if _enemy_index != null and is_instance_valid(_enemy_index) and _enemy_index.has_method("unregister"):
		_enemy_index.call("unregister", self)

	# important: sniper telegraph nodes live in current_scene, so free them on despawn
	if _sniper != null:
		_sniper.cleanup()


func _physics_process(delta: float) -> void:
	_simulation_motion_scale = 1.0
	_population_refresh_left -= delta
	if _population_refresh_left <= 0.0:
		_population_refresh_left += 0.5
		if _enemy_index != null and is_instance_valid(_enemy_index) and _enemy_index.has_method("ambient_alive_count"):
			_ambient_population = int(_enemy_index.call("ambient_alive_count"))
	# Acquire player if needed
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	var ai: int = _get_active_ai()
	if player != null and is_instance_valid(player):
		var preliminary_distance := global_position.distance_to(player.global_position)
		_update_lod_tier(ai, preliminary_distance)
		if (
			_should_reduce_physics(ai)
			and _is_lod_eligible(ai)
			and stun_time <= 0.0
			and knockback_vel == Vector2.ZERO
		):
			if not should_run_reduced_step(delta):
				return
			delta = consume_simulation_delta()
			_simulation_motion_scale = delta / maxf(get_physics_process_delta_time(), 0.000001)
		else:
			should_run_far_step(delta)
	_update_los_cache(delta, ai)
	_tick_active_modules(delta, ai)

	# Knockback decay
	if knockback_vel != Vector2.ZERO:
		knockback_vel = knockback_vel.move_toward(Vector2.ZERO, knockback_decay * delta)

	# Speed buff timer (Herald)
	if _speed_mul_time > 0.0:
		_speed_mul_time = maxf(_speed_mul_time - delta, 0.0)
		if _speed_mul_time <= 0.0:
			_speed_mul = 1.0

	# Stun handling
	if stun_time > 0.0:
		stun_time = maxf(stun_time - delta, 0.0)
		velocity = knockback_vel
		_move_and_slide_scaled()
		_lod_force_refresh = true
		_update_enemy_index(true)
		return

	if player == null:
		velocity = knockback_vel
		_move_and_slide_scaled()
		_update_enemy_index(true)
		return

	# Charge override (windup/dash) is only relevant to the charge brain.
	if ai == EnemySpec.AI.CHARGE and _charge.step_override(delta):
		velocity = _charge.override_velocity() + knockback_vel
		_move_and_slide_scaled()
		_update_enemy_index(true)
		return

	# Basic vectors (player)
	var dvec: Vector2 = player.global_position - global_position
	var dist: float = dvec.length()
	var to_player: Vector2 = (dvec / dist) if dist > 0.001 else Vector2.ZERO
	_lod_steer_accum += delta
	_lod_steer_left -= delta
	var refresh_steering: bool = _lod_tier == 0 or _lod_force_refresh or _lod_steer_left <= 0.0

	var chase: Vector2 = _cached_chase
	var to_nav_target: Vector2 = _cached_nav_target if _cached_nav_target != Vector2.ZERO else to_player

	if refresh_steering:
		var steer_delta: float = maxf(delta, _lod_steer_accum)
		_lod_steer_accum = 0.0
		_lod_force_refresh = false
		_lod_steer_left = _lod_interval_for_tier()

		# Boss leash / return-to-home (full-rate actors only).
		var boss_returning: bool = false
		to_nav_target = to_player
		if is_in_group(&"boss_like") and has_meta("boss_home_pos"):
			var home: Vector2 = get_meta("boss_home_pos") as Vector2
			var leash: float = float(get_meta("boss_leash_radius")) if has_meta("boss_leash_radius") else 900.0
			var disengage: float = float(get_meta("boss_disengage_radius")) if has_meta("boss_disengage_radius") else leash * 1.25
			var dist_home: float = global_position.distance_to(home)
			var player_from_home: float = player.global_position.distance_to(home)
			boss_returning = dist_home > leash or player_from_home > disengage
			set_meta("boss_returning", boss_returning)
			if boss_returning:
				var heal_pct: float = float(get_meta("boss_heal_pct_per_sec")) if has_meta("boss_heal_pct_per_sec") else 0.0
				if heal_pct > 0.0 and max_hp > 0.0 and not dead:
					hp = minf(max_hp, hp + max_hp * heal_pct * steer_delta)
				var home_vec: Vector2 = home - global_position
				var home_dist: float = home_vec.length()
				to_nav_target = (home_vec / home_dist) if home_dist > 0.001 else Vector2.ZERO

		# Sniper always runs for side effects (telegraph/fire), matching the old behavior.
		var base_is_sniper: bool = spec != null and spec.ai == EnemySpec.AI.SNIPER
		var sniper_move: Vector2 = Vector2.ZERO
		var sniper_mul: float = 1.0
		if base_is_sniper:
			sniper_move = _sniper.brain(to_player, dist, _spd())
			sniper_mul = _sniper.windup_mul()

		if boss_returning:
			chase = to_nav_target * _spd()
		else:
			match ai:
				EnemySpec.AI.CHASE:
					chase = to_player * _spd()
				EnemySpec.AI.ORBIT:
					chase = _orbit_move(steer_delta)
				EnemySpec.AI.RANGED:
					chase = _ranged_brain(to_player, dist)
				EnemySpec.AI.CHARGE:
					chase = _charge.brain(to_player, dist)
				EnemySpec.AI.BOMBER:
					chase = _bomber.brain(to_player, dist, _spd())
				EnemySpec.AI.SUMMONER:
					chase = _summoner.brain(to_player, dist, _spd())
				EnemySpec.AI.SPLITTER:
					chase = to_player * _spd()
				EnemySpec.AI.TACTICAL:
					chase = _tactical.brain(to_player, dist) * sniper_mul
				EnemySpec.AI.LEECH:
					chase = to_player * _spd()
				EnemySpec.AI.HERALD:
					chase = _herald.brain(to_player, dist)
				EnemySpec.AI.SNIPER:
					chase = sniper_move
				_:
					chase = to_player * _spd()

		chase = _horde_nav.pre_steer(ai, chase, to_nav_target, steer_delta, _lod_tier)
		_cached_chase = chase
		_cached_nav_target = to_nav_target

	velocity = chase + knockback_vel
	_move_and_slide_scaled()

	# Collision reaction remains immediate even when far steering is staggered.
	var collided: bool = get_slide_collision_count() > 0
	if refresh_steering or collided:
		_horde_nav.post_move(chase, to_nav_target, delta, _lod_tier)
	if collided and _lod_tier > 0:
		_lod_force_refresh = true

	# Spatial buckets remain exact for the projectile manager. The cached autoload
	# reference removes the old per-enemy scene-tree lookup from this hot path.
	_update_enemy_index(true)


func _tick_active_modules(delta: float, ai: int) -> void:
	# Previously every enemy ticked all six modules every physics frame. Only the
	# active archetype (plus the shared shooter used by Tactical/Herald) needs work.
	if ai == EnemySpec.AI.RANGED or ai == EnemySpec.AI.TACTICAL or ai == EnemySpec.AI.HERALD:
		_shooter.tick(delta)
	if ai == EnemySpec.AI.CHARGE:
		_charge.tick(delta)
	if ai == EnemySpec.AI.SUMMONER:
		_summoner.tick(delta)
	if ai == EnemySpec.AI.SNIPER or (spec != null and spec.ai == EnemySpec.AI.SNIPER):
		_sniper.tick(delta)
	if ai == EnemySpec.AI.HERALD:
		_herald.tick(delta)
	if ai == EnemySpec.AI.TACTICAL:
		_tactical.tick(delta)


func _update_lod_tier(ai: int, distance_to_player: float) -> void:
	var next_tier := compute_population_lod_tier(ai, distance_to_player, _ambient_population)
	if next_tier == _lod_tier:
		return
	_lod_tier = next_tier
	_lod_force_refresh = true
	_lod_steer_left = 0.0
	_set_hitbox_active(not (lod_disable_far_hitbox and _lod_tier == 2))


func compute_population_lod_tier(ai: int, distance_to_player: float, ambient_population: int) -> int:
	if not _is_lod_eligible(ai):
		return 0
	var pressure := sqrt(clampf(
		float(ambient_population - lod_population_start)
		/ float(maxi(1, lod_population_full_pressure - lod_population_start)),
		0.0,
		1.0
	))
	var near_limit := lerpf(lod_near_distance, minf(lod_near_distance, lod_pressured_near_distance), pressure)
	var mid_limit := lerpf(
		maxf(lod_mid_distance, lod_near_distance),
		maxf(near_limit, lod_pressured_mid_distance),
		pressure
	)
	if distance_to_player > mid_limit:
		return 2
	if distance_to_player > near_limit:
		return 1
	return 0


func _is_lod_eligible(ai: int) -> bool:
	if not simulation_lod_enabled or is_elite:
		return false
	if is_in_group(&"boss_like") or is_in_group(&"boss") or is_in_group(&"miniboss"):
		return false
	if has_meta("never_cull") and bool(get_meta("never_cull")):
		return false
	var special_kind := get_meta("special_spawn_kind", &"") as StringName
	if special_kind != &"" and special_kind != &"split":
		return false
	return ai == EnemySpec.AI.CHASE or ai == EnemySpec.AI.SPLITTER or ai == EnemySpec.AI.LEECH


func simulation_tier() -> int:
	return _lod_tier


func should_run_far_step(delta: float) -> bool:
	return should_run_reduced_step(delta)


func should_run_reduced_step(delta: float) -> bool:
	if not _should_reduce_physics(_get_active_ai()):
		_far_step_left = 0.0
		_far_delta_accum = 0.0
		_far_last_delta = maxf(0.0, delta)
		return true
	_far_delta_accum += maxf(0.0, delta)
	_far_step_left -= maxf(0.0, delta)
	if _far_step_left > 0.0:
		return false
	var interval := (
		clampf(lod_far_physics_interval, 0.067, 0.10)
		if _lod_tier == 2
		else clampf(lod_mid_physics_interval, 0.025, 0.05)
	)
	_far_step_left += interval
	if _far_step_left <= 0.0:
		_far_step_left = interval
	_far_last_delta = _far_delta_accum
	_far_delta_accum = 0.0
	return true


func _should_reduce_physics(ai: int) -> bool:
	if not _is_lod_eligible(ai):
		return false
	if _lod_tier == 2:
		return true
	return _lod_tier == 1 and _ambient_population >= lod_mid_reduced_population


func consume_simulation_delta() -> float:
	return maxf(_far_last_delta, 0.000001)


func _move_and_slide_scaled() -> void:
	var motion_scale := maxf(_simulation_motion_scale, 1.0)
	velocity *= motion_scale
	move_and_slide()
	velocity /= motion_scale


func is_retirement_protected(player_distance: float) -> bool:
	if is_in_group(&"boss_like") or is_in_group(&"boss") or is_in_group(&"miniboss"):
		return true
	if bool(get_meta("objective_required", false)) or bool(get_meta("tutorial_actor", false)):
		return true
	if bool(get_meta("never_cull", false)):
		return true
	var kind := get_meta("special_spawn_kind", &"") as StringName
	if kind == &"summon":
		return true
	if kind == &"interior" and bool(get_meta("interior_active", true)):
		return true
	if kind == &"boss_add" and bool(get_meta("encounter_active", true)):
		return true
	if _get_active_ai() == EnemySpec.AI.SNIPER:
		if _sniper != null and _sniper.is_combat_committed():
			return true
		var engagement := (
			maxf(spec.sniper_range, spec.sniper_beam_length)
			if spec != null
			else 1200.0
		)
		return player_distance <= engagement + maxf(0.0, sniper_retirement_safety_margin)
	return false


func _lod_interval_for_tier() -> float:
	match _lod_tier:
		1:
			return maxf(0.02, lod_mid_steer_interval)
		2:
			return maxf(0.05, lod_far_steer_interval)
		_:
			return 0.0


func _set_hitbox_active(value: bool) -> void:
	if _hitbox == null or not is_instance_valid(_hitbox):
		_hitbox = get_node_or_null("Hitbox") as Area2D
	if _hitbox == null:
		return
	if _hitbox.monitoring != value:
		_hitbox.set_deferred("monitoring", value)
	if _hitbox.monitorable != value:
		_hitbox.set_deferred("monitorable", value)


func _update_enemy_index(force: bool) -> void:
	if not force:
		return
	if _enemy_index == null or not is_instance_valid(_enemy_index):
		_enemy_index = get_node_or_null("/root/EnemyIndex")
	if _enemy_index != null and is_instance_valid(_enemy_index) and _enemy_index.has_method("update_enemy"):
		_enemy_index.call("update_enemy", self)


func _notify_enemy_index_dead() -> void:
	if _enemy_index == null or not is_instance_valid(_enemy_index):
		_enemy_index = get_node_or_null("/root/EnemyIndex")
	if _enemy_index != null and is_instance_valid(_enemy_index) and _enemy_index.has_method("mark_dead"):
		_enemy_index.call("mark_dead", self)


func _get_active_ai() -> int:
	if spec == null:
		return EnemySpec.AI.CHASE
	if is_elite and spec.elite_ai_override >= 0:
		return spec.elite_ai_override
	return spec.ai


func _spd() -> float:
	return _base_speed * _speed_mul * _stability_mul


func _orbit_move(delta: float) -> Vector2:
	if spec == null:
		return Vector2.ZERO

	_orbit_angle += spec.orbit_turn_speed * delta
	var target: Vector2 = player.global_position + Vector2.RIGHT.rotated(_orbit_angle) * spec.orbit_radius
	var v: Vector2 = (target - global_position)
	if v.length_squared() < 0.001:
		return Vector2.ZERO
	return v.normalized() * _spd()


func _ranged_brain(to_player: Vector2, dist: float) -> Vector2:
	if spec == null:
		return to_player * _spd()

	return _shooter.brain(
		to_player,
		dist,
		_spd(),
		spec.preferred_range,
		spec.range_tolerance,
		spec.strafe_strength
	)

# -----------------------
# Elite
# -----------------------
func make_elite() -> void:
	if spec == null or is_elite:
		return

	is_elite = true
	if PerformanceFlightRecorder != null:
		PerformanceFlightRecorder.record_counter_event(&"enemy", &"elite_promoted", 1, {
			"enemy_id": scene_file_path.get_file().get_basename(),
		})
	_lod_tier = 0
	_lod_force_refresh = true
	_set_hitbox_active(true)
	max_slides = 8
	max_hp *= spec.elite_hp_mult
	hp = max_hp

	speed *= spec.elite_speed_mult
	_base_speed = speed
	if spec.ai == EnemySpec.AI.SPLITTER:
		scale *= Vector2.ONE * maxf(1.0, spec.split_elite_scale_mult)

	var spr: CanvasItem = get_node_or_null("Sprite2D") as CanvasItem
	if spr != null:
		spr.modulate = spec.elite_tint


# -----------------------
# Effects / CC
# -----------------------
func apply_knockback(force: Vector2) -> void:
	# Boss-like enemies resist knockback to avoid being juggled.
	if is_in_group(&"boss_like"):
		var mul := 0.25
		if has_meta("boss_kb_mul"):
			mul = float(get_meta("boss_kb_mul"))
		force *= mul
	knockback_vel += force

func apply_stun(seconds: float) -> void:
	stun_time = maxf(stun_time, seconds)

func apply_speed_buff(mult: float, duration: float) -> void:
	if mult <= 1.0 or duration <= 0.0:
		return
	_speed_mul = maxf(_speed_mul, mult)
	_speed_mul_time = maxf(_speed_mul_time, duration)

func set_stability_mul(mult: float) -> void:
	_stability_mul = clampf(mult, 0.1, 1.0)

func clear_stability_mul() -> void:
	_stability_mul = 1.0


# -----------------------
# Hitbox -> Leech
# -----------------------
func _on_hitbox_area_entered(a: Area2D) -> void:
	_leech.on_hitbox_area_entered(a)

func _on_hitbox_area_exited(a: Area2D) -> void:
	_leech.on_hitbox_area_exited(a)


# -----------------------
# Damage -> Lifecycle
# -----------------------
func take_damage(amount: float, source: Node = null) -> void:
	_life.take_damage(amount, source)

func apply_hit_ledger(ledger: HitLedger) -> void:
	_life.apply_hit_ledger(ledger)


# -----------------------
# Flow Field access + Senses helpers (used by modules + nav helper)
# -----------------------
func _get_flow() -> FlowFieldNav:
	if _flow == null or not is_instance_valid(_flow):
		_flow = get_tree().get_first_node_in_group("flow_field_nav") as FlowFieldNav
	return _flow

func has_los_to_player() -> bool:
	return _senses.has_los_to_player()

func cover_mask() -> int:
	return _senses.cover_mask()

func ray_clear(a: Vector2, b: Vector2) -> bool:
	return _senses.ray_clear(a, b)

func point_blocked(p: Vector2) -> bool:
	return _senses.point_blocked(p)


func _update_los_cache(delta: float, ai: int) -> void:
	var needs_los := (
		ai == EnemySpec.AI.RANGED
		or ai == EnemySpec.AI.TACTICAL
		or ai == EnemySpec.AI.SNIPER
		or ai == EnemySpec.AI.HERALD
	)

	if not needs_los:
		_los_cache = false
		_los_timer = 0.0
		return

	_los_timer -= delta
	if _los_timer > 0.0:
		return

	_los_timer = maxf(0.01, los_check_interval)
	_los_cache = has_los_to_player()

func has_los_cached() -> bool:
	return _los_cache
