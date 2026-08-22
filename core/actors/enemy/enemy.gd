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

@export_group("Simulation LOD")
@export var simulation_lod_enabled: bool = true
# Beyond this distance a hit-reaction no longer buys a full-simulation slot.
@export var lod_mid_distance: float = 2400.0
# Ordinary smart archetypes may release body/hitbox physics beyond this
# distance: player projectiles resolve through EnemyCombat's data-side
# segment tests, so broadphase presence only matters near the player. The
# lower re-acquire bound is hysteresis against materialize churn on the edge.
@export var lod_smart_release_distance: float = 2600.0
@export var lod_smart_reacquire_distance: float = 2300.0
@export var lod_mid_steer_interval: float = 0.08
@export var lod_far_steer_interval: float = 0.20
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
var _sim_scheduler: Node = null
var _visual_batched := false
var _hitbox: Area2D = null
var _body_shape: CollisionShape2D = null
var _lod_tier: int = 0 # 0 near/full, 1 mid, 2 far
var _lod_steer_left: float = 0.0
var _lod_steer_accum: float = 0.0
var _lod_force_refresh: bool = true
var _cached_chase: Vector2 = Vector2.ZERO
var _cached_nav_target: Vector2 = Vector2.ZERO
var _simulation_motion_scale: float = 1.0
var _scheduled_step_delta: float = 0.0
var _pool_fresh_obtain_pending: bool = false
var _scene_base_scale: Vector2 = Vector2.ONE
var _scene_base_speed: float = 0.0
var _scene_base_max_hp: float = 0.0
var _scene_base_knockback_decay: float = 0.0
var _enemy_world_handle: int = 0
var _representation_lease_active: bool = false

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
	_scene_base_scale = scale
	_scene_base_speed = speed
	_scene_base_max_hp = max_hp
	_scene_base_knockback_decay = knockback_decay
	_init.setup(self, _drops, _senses, _leech, _herald, _tactical, _charge, _shooter, _life)
	_init.boot()

	_summoner.setup(self)
	_bomber.setup(self)
	_splitter.setup(self)
	_sniper.setup(self)

	_life.setup(self, _drops, _bomber, _splitter)
	_nav.setup(self, _senses)

	# A node entering the tree already inside the pool is being WARMED, not
	# spawned: it must not join gameplay groups or register as live population.
	# Its first obtain runs the full reset, which performs the registration.
	var pool_warming := bool(get_meta("__in_pool", false))
	if not pool_warming:
		add_to_group(&"enemies")

	# Nav helper module
	_horde_nav.setup(self)

	# Desync LOS checks so large hordes don't raycast on the same frame.
	_los_timer = Global._rng.randf_range(0.0, maxf(0.01, los_check_interval))

	# Cache the hot-path references once. Reacquisition only happens if an autoload
	# or scene-owned hitbox is unexpectedly replaced.
	_enemy_index = get_node_or_null("/root/EnemyIndex")
	_hitbox = get_node_or_null("Hitbox") as Area2D
	_body_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	var obtain_context: Dictionary = get_meta("__pool_obtain_context", {}) as Dictionary
	var lease_handle := int(obtain_context.get("enemy_world_handle", 0))
	if pool_warming:
		pass # warmed inventory: no registration until first obtain
	elif bool(obtain_context.get("enemy_representation_lease", false)) and lease_handle != 0:
		if not hydrate_representation_lease(lease_handle):
			push_error("EnemyActor could not hydrate representation lease")
	elif _enemy_index != null and is_instance_valid(_enemy_index) and _enemy_index.has_method("register"):
		_enemy_index.call("register", self)

	# The horde helper already handles corners; four solver slides are enough for
	# ordinary enemies and materially cheaper than the previous hard-coded eight.
	safe_margin = 0.04
	max_slides = clampi(physics_max_slides, 2, 8) if _is_lod_eligible(_get_active_ai()) else 8
	_lod_steer_left = Global._rng.randf_range(0.0, maxf(0.01, lod_far_steer_interval))
	_apply_simulation_collision_roles()
	# Warmed nodes need the full reset (and its registration) on first obtain.
	_pool_fresh_obtain_pending = has_meta("__pool_key") and not pool_warming
	_register_batched_visual()

	if not pool_warming and RunEvents != null and RunEvents.has_signal("enemy_archetype_encountered"):
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
	if dead or _lod_tier != 0:
		return
	_run_simulation_step(delta)


func run_scheduled_simulation(delta: float) -> void:
	if dead or _lod_tier == 0:
		return
	_run_simulation_step(maxf(delta, 0.000001))


func _run_simulation_step(delta: float) -> void:
	_scheduled_step_delta = delta
	_simulation_motion_scale = delta / maxf(get_physics_process_delta_time(), 0.000001)
	# Acquire player if needed
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	var ai: int = _get_active_ai()
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
					heal(max_hp * heal_pct * steer_delta)
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
	var collided: bool = _lod_tier < 2 and get_slide_collision_count() > 0
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


func _lod_base_eligible() -> bool:
	if not simulation_lod_enabled or is_elite:
		return false
	if is_in_group(&"boss_like") or is_in_group(&"boss") or is_in_group(&"miniboss"):
		return false
	if has_meta("never_cull") and bool(get_meta("never_cull")):
		return false
	var special_kind := get_meta("special_spawn_kind", &"") as StringName
	return special_kind == &"" or special_kind == &"split"


func _is_lod_eligible(ai: int) -> bool:
	if not _lod_base_eligible():
		return false
	return ai == EnemySpec.AI.CHASE or ai == EnemySpec.AI.SPLITTER or ai == EnemySpec.AI.LEECH


func simulation_tier() -> int:
	return _lod_tier


func max_scheduler_tier(player_distance: float = -1.0) -> int:
	# Far tier disables body collision and broadphase presence. Ambient swarm
	# archetypes may always pay that price. Ordinary smart archetypes stay
	# shootable without a body (projectiles hit through EnemyCombat's data-side
	# segment tests), so they may release physics once far enough that contact
	# damage and body collision cannot matter. Elites, snipers, and special
	# actors clamp to mid at any distance.
	var ai: int = _get_active_ai()
	if _is_lod_eligible(ai):
		return 2
	if player_distance >= 0.0 and _can_release_far_physics(ai, player_distance):
		return 2
	return 1


func _can_release_far_physics(ai: int, player_distance: float) -> bool:
	if ai == EnemySpec.AI.SNIPER or not _lod_base_eligible():
		return false
	# Once released, hold far physics until meaningfully closer so the boundary
	# cannot flap materialization every assignment refresh.
	var release := (
		lod_smart_reacquire_distance if _lod_tier == 2
		else lod_smart_release_distance
	)
	# Sustained physics pressure pulls the release boundary inward so a horde
	# sheds physics bodies instead of stacking mid-clamped ones.
	if _sim_scheduler == null or not is_instance_valid(_sim_scheduler):
		_sim_scheduler = get_node_or_null("/root/EnemySimulationScheduler")
	if (
		_sim_scheduler != null
		and _sim_scheduler.has_method("physics_release_distance_scale")
	):
		release *= float(_sim_scheduler.call("physics_release_distance_scale"))
	return player_distance >= maxf(release, 0.0)


func set_scheduler_tier(tier: int) -> void:
	var next_tier := clampi(tier, 0, 2)
	if next_tier == _lod_tier:
		# Unchanged tier: keep the per-enemy steering stagger intact. Callbacks and
		# collision roles are re-asserted cheaply because pool obtain relies on it.
		set_physics_process(_lod_tier == 0)
		_apply_simulation_collision_roles()
		return
	var was_far := _lod_tier == 2
	_lod_tier = next_tier
	set_physics_process(_lod_tier == 0)
	_lod_force_refresh = true
	_lod_steer_left = 0.0
	_apply_simulation_collision_roles()
	if was_far and _lod_tier < 2:
		reset_physics_interpolation()


func run_full_simulation_next_frame() -> void:
	set_scheduler_tier(0)


func is_body_physics_enabled() -> bool:
	if _body_shape == null or not is_instance_valid(_body_shape):
		_body_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	return _body_shape == null or not _body_shape.disabled


func hitbox_roles() -> Dictionary:
	if _hitbox == null or not is_instance_valid(_hitbox):
		_hitbox = get_node_or_null("Hitbox") as Area2D
	if _hitbox == null:
		return {"monitoring": false, "monitorable": false}
	return {"monitoring": _hitbox.monitoring, "monitorable": _hitbox.monitorable}


func is_simulation_protected(player_distance: float) -> bool:
	# Only actors whose encounter/lifecycle contract requires exact simulation may
	# bypass the hard budget. Ambient elites and smart archetypes are prioritized by
	# proximity, but never allowed to make the full-rate population unbounded.
	return is_retirement_protected(player_distance)


func simulation_priority(player_position: Vector2) -> float:
	var distance_squared := global_position.distance_squared_to(player_position)
	var priority := -distance_squared
	# Hit reactions deserve full fidelity, but only near the player; in a bullet
	# heaven most of the horde carries residual knockback, and an unbounded boost
	# lets distant hit enemies churn the full-simulation slots every refresh.
	if (
		(stun_time > 0.0 or knockback_vel != Vector2.ZERO)
		and distance_squared <= lod_mid_distance * lod_mid_distance
	):
		priority += 1000000000.0
	return priority


func _move_and_slide_scaled() -> void:
	if _lod_tier == 2:
		global_position += velocity * maxf(_scheduled_step_delta, 0.0)
		return
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
	_set_hitbox_roles(value and _get_active_ai() == EnemySpec.AI.LEECH, value)


func _register_batched_visual() -> void:
	# Batched enemy visuals: the sprite hides and the shared proxy renderer
	# draws every enemy through per-texture MultiMesh batches, collapsing
	# hundreds of per-node sprite draws. Falls back to normal sprites when
	# the proxy root is absent or the debug flag is off. Registration is per
	# node instance; the renderer skips pooled/hidden/dead actors and prunes
	# freed ones.
	if _visual_batched or Global == null or not Global.debug_enemy_visual_batching:
		return
	var proxy_root := get_tree().get_first_node_in_group(&"enemy_proxy_root")
	var renderer: Node = proxy_root.get("renderer") if proxy_root != null else null
	if renderer == null or not renderer.has_method("register_actor"):
		return
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	renderer.call("register_actor", self, sprite)
	sprite.visible = false
	_visual_batched = true


func _apply_simulation_collision_roles() -> void:
	if _body_shape == null or not is_instance_valid(_body_shape):
		_body_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _body_shape != null and _body_shape.disabled != (_lod_tier == 2):
		_body_shape.set_deferred("disabled", _lod_tier == 2)
	var participates_in_queries := _lod_tier < 2
	_set_hitbox_roles(
		participates_in_queries and _get_active_ai() == EnemySpec.AI.LEECH,
		participates_in_queries
	)


func _set_hitbox_roles(active_monitoring: bool, can_be_monitored: bool) -> void:
	if _hitbox == null or not is_instance_valid(_hitbox):
		_hitbox = get_node_or_null("Hitbox") as Area2D
	if _hitbox == null:
		return
	if _hitbox.monitoring != active_monitoring:
		_hitbox.set_deferred("monitoring", active_monitoring)
	if _hitbox.monitorable != can_be_monitored:
		_hitbox.set_deferred("monitorable", can_be_monitored)


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


func can_pool_as_ambient() -> bool:
	if scene_file_path == "":
		return false
	if get_meta("special_spawn_kind", &"") as StringName != &"":
		return false
	if (
		is_in_group(&"boss_like")
		or is_in_group(&"boss")
		or is_in_group(&"miniboss")
		or bool(get_meta("objective_required", false))
		or bool(get_meta("tutorial_actor", false))
		or bool(get_meta("never_cull", false))
	):
		return false
	if not simulation_lod_enabled:
		return false
	# Eligibility is judged on the base archetype, deliberately ignoring elite
	# status: at high threat most deaths are elites, and excluding them collapses
	# pool reuse exactly when spawn pressure peaks. The obtain reset clears every
	# elite mutation (status, stats, tint, solver slides).
	var base_ai: int = spec.ai if spec != null else EnemySpec.AI.CHASE
	return (
		base_ai == EnemySpec.AI.CHASE
		or base_ai == EnemySpec.AI.SPLITTER
		or base_ai == EnemySpec.AI.LEECH
	)


func despawn(_reason: StringName = &"death") -> void:
	if can_pool_as_ambient() and PoolManager != null:
		PoolManager.recycle(self)
		return
	if _enemy_index == null or not is_instance_valid(_enemy_index):
		_enemy_index = get_node_or_null("/root/EnemyIndex")
	if _enemy_index != null and _enemy_index.has_method("unregister"):
		_enemy_index.call("unregister", self)
	queue_free()


func _on_pool_recycle() -> void:
	if _enemy_index == null or not is_instance_valid(_enemy_index):
		_enemy_index = get_node_or_null("/root/EnemyIndex")
	if _enemy_index != null and _enemy_index.has_method("unregister"):
		_enemy_index.call("unregister", self)
	_sniper.cleanup()
	player = null
	set_process(false)
	set_physics_process(false)
	visible = false
	if _body_shape != null:
		_body_shape.set_deferred("disabled", true)
	_set_hitbox_roles(false, false)


func _on_pool_recycle_context(context: Dictionary) -> void:
	if bool(context.get("enemy_representation_lease", false)):
		_quiesce_representation_lease()
		return
	_on_pool_recycle()


func _on_pool_obtain() -> void:
	if _pool_fresh_obtain_pending:
		_pool_fresh_obtain_pending = false
		return
	_reset_for_pool_obtain()


func _on_pool_obtain_context(context: Dictionary) -> void:
	if _pool_fresh_obtain_pending:
		_pool_fresh_obtain_pending = false
		return
	if not bool(context.get("enemy_representation_lease", false)):
		_reset_for_pool_obtain()
		return
	var handle := int(context.get("enemy_world_handle", 0))
	_reset_for_pool_obtain(false)
	if not hydrate_representation_lease(handle):
		push_error("EnemyActor could not attach reused representation lease")


func _reset_for_pool_obtain(register_new_logical_enemy: bool = true) -> void:
	for child in get_children():
		if child is BurnDot or child is BleedDot:
			child.free()
	for key in [
		&"culled",
		&"cull_reason",
		&"_threat_scaled",
		&"split_generation",
		&"split_item_entitled",
		&"sniper_combat_committed",
	]:
		if has_meta(key):
			remove_meta(key)
	scale = _scene_base_scale
	speed = _scene_base_speed
	max_hp = _scene_base_max_hp
	knockback_decay = _scene_base_knockback_decay
	dead = false
	is_elite = false
	# make_elite doubles the solver slides; restore the ordinary budget.
	max_slides = clampi(physics_max_slides, 2, 8) if _is_lod_eligible(_get_active_ai()) else 8
	velocity = Vector2.ZERO
	knockback_vel = Vector2.ZERO
	stun_time = 0.0
	_speed_mul = 1.0
	_speed_mul_time = 0.0
	_stability_mul = 1.0
	_los_cache = false
	_los_timer = Global._rng.randf_range(0.0, maxf(0.01, los_check_interval))
	_cached_chase = Vector2.ZERO
	_cached_nav_target = Vector2.ZERO
	_lod_steer_accum = 0.0
	_lod_steer_left = 0.0
	_lod_force_refresh = true
	_init.boot()
	_summoner.setup(self)
	_bomber.setup(self)
	_splitter.setup(self)
	_sniper.setup(self)
	_life.setup(self, _drops, _bomber, _splitter)
	_nav.setup(self, _senses)
	_horde_nav.setup(self)
	# Idempotent; warmed nodes skipped the group in _ready and join here on
	# their first obtain.
	add_to_group(&"enemies")
	visible = true
	set_process(true)
	set_scheduler_tier(0)
	_enemy_index = get_node_or_null("/root/EnemyIndex")
	_representation_lease_active = false
	if register_new_logical_enemy and _enemy_index != null and _enemy_index.has_method("register"):
		_enemy_index.call("register", self)


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
	if PerformanceFlightRecorder != null and bool(PerformanceFlightRecorder.get("enabled")):
		PerformanceFlightRecorder.record_counter_event(&"enemy", &"elite_promoted", 1, {
			"enemy_id": scene_file_path.get_file().get_basename(),
		})
	if _enemy_index != null and is_instance_valid(_enemy_index) and _enemy_index.has_method("note_elite"):
		_enemy_index.call("note_elite", self)
	set_scheduler_tier(0)
	max_slides = 8
	configure_health(max_hp * spec.elite_hp_mult, true)

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
	if force == Vector2.ZERO or dead:
		return
	EnemyCombat.apply_knockback(_resolve_enemy_world_handle(), force)


func _apply_enemy_world_knockback(force: Vector2) -> void:
	knockback_vel += force

func apply_stun(seconds: float) -> void:
	if seconds <= 0.0 or dead:
		return
	EnemyCombat.apply_stun(_resolve_enemy_world_handle(), seconds)


func _apply_enemy_world_stun(seconds: float) -> void:
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
	if dead or amount <= 0.0:
		return
	EnemyCombat.apply_damage(_resolve_enemy_world_handle(), amount, 1, source)

func apply_hit_ledger(ledger: HitLedger) -> void:
	if dead or ledger == null:
		return
	EnemyCombat.apply_hit_ledger(_resolve_enemy_world_handle(), ledger)


func heal(amount: float) -> bool:
	if dead or amount <= 0.0:
		return false
	return EnemyCombat.heal(_resolve_enemy_world_handle(), amount)


func configure_health(new_max_health: float, fill_to_max: bool = false) -> bool:
	if dead:
		return false
	var handle := _resolve_enemy_world_handle()
	if handle == 0:
		max_hp = maxf(new_max_health, 0.0)
		hp = max_hp if fill_to_max else minf(hp, max_hp)
		return true
	return EnemyCombat.configure_health(handle, new_max_health, fill_to_max)


func _bind_enemy_world_handle(handle: int) -> void:
	_enemy_world_handle = handle


func commit_representation_lease(handle: int) -> bool:
	if handle == 0 or not EnemyWorld.is_valid_handle(handle):
		return false
	if EnemyWorld.actor_for_handle(handle) != self:
		return false
	EnemyWorld.set_position(handle, global_position)
	EnemyWorld.reset_interpolation(handle)
	EnemyWorld.set_velocity(handle, velocity)
	EnemyWorld.set_knockback_velocity(handle, knockback_vel)
	EnemyWorld.set_knockback_decay(handle, knockback_decay)
	EnemyWorld.set_stun_time(handle, stun_time)
	EnemyWorld.set_speed(handle, _spd())
	var flags := EnemyWorld.get_flags(handle)
	if is_elite:
		flags |= EnemyWorldTypes.Flags.ELITE
	else:
		flags &= ~EnemyWorldTypes.Flags.ELITE
	EnemyWorld.set_flags(handle, flags)
	var cold_state := EnemyWorld.get_cold_state(handle)
	cold_state.merge(_build_enemy_world_cold_state(), true)
	EnemyWorld.replace_cold_state(handle, cold_state)
	return true


func hydrate_representation_lease(handle: int) -> bool:
	if handle == 0 or not EnemyWorld.is_valid_handle(handle):
		return false
	if _enemy_index == null or not is_instance_valid(_enemy_index):
		_enemy_index = get_node_or_null("/root/EnemyIndex")
	if _enemy_index == null or not _enemy_index.has_method("attach_representation"):
		return false
	if not bool(_enemy_index.call("attach_representation", self, handle)):
		return false
	var cold_state := EnemyWorld.get_cold_state(handle)
	global_position = EnemyWorld.get_position(handle)
	velocity = EnemyWorld.get_velocity(handle)
	knockback_vel = EnemyWorld.get_knockback_velocity(handle)
	knockback_decay = EnemyWorld.get_knockback_decay(handle)
	stun_time = EnemyWorld.get_stun_time(handle)
	max_hp = EnemyWorld.get_max_health(handle)
	hp = EnemyWorld.get_health(handle)
	dead = false
	is_elite = (EnemyWorld.get_flags(handle) & EnemyWorldTypes.Flags.ELITE) != 0
	scale = cold_state.get("actor_scale", _scene_base_scale) as Vector2
	speed = float(cold_state.get("actor_speed", speed))
	_base_speed = float(cold_state.get("base_speed", speed))
	_speed_mul = float(cold_state.get("speed_mul", 1.0))
	_speed_mul_time = maxf(float(cold_state.get("speed_mul_time", 0.0)), 0.0)
	_stability_mul = clampf(float(cold_state.get("stability_mul", 1.0)), 0.1, 1.0)
	_orbit_angle = float(cold_state.get("orbit_angle", _orbit_angle))
	_enemy_world_handle = handle
	_representation_lease_active = true
	visible = true
	set_process(true)
	set_scheduler_tier(0)
	_update_enemy_index(true)
	reset_physics_interpolation()
	return true


func _build_enemy_world_cold_state() -> Dictionary:
	var state := {
		"actor_scale": scale,
		"actor_speed": speed,
		"base_speed": _base_speed,
		"speed_mul": _speed_mul,
		"speed_mul_time": _speed_mul_time,
		"stability_mul": _stability_mul,
		"orbit_angle": _orbit_angle,
		"knockback_decay": knockback_decay,
	}
	if spec != null:
		# Lets systems that only see logical records (debug cull, death rewards,
		# telemetry) resolve the archetype without a materialized node.
		state["enemy_id"] = spec.id
		# Lets a data-only death grant the same follower reward the actor would.
		state["follower_reward_min"] = spec.follower_reward_min
		state["follower_reward_max"] = spec.follower_reward_max
		state["elite_follower_bonus"] = spec.elite_follower_bonus
	for key in [
		&"split_generation",
		&"split_item_entitled",
		&"split_root_id",
		&"special_spawn_kind",
	]:
		if has_meta(key):
			state[String(key)] = get_meta(key)
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		state["proxy_visual_key"] = StringName(
			scene_file_path if not scene_file_path.is_empty() else String(name)
		)
		state["proxy_color"] = sprite.modulate
		state["proxy_z_index"] = z_index + sprite.z_index
		if sprite.texture != null:
			if not sprite.texture.resource_path.is_empty():
				state["proxy_texture_path"] = sprite.texture.resource_path
			var texture_size := sprite.texture.get_size()
			state["proxy_size"] = Vector2(
				maxf(absf(texture_size.x * sprite.scale.x * scale.x), 4.0),
				maxf(absf(texture_size.y * sprite.scale.y * scale.y), 4.0),
			)
	return state


func _quiesce_representation_lease() -> void:
	_representation_lease_active = false
	for child in get_children():
		if child is BurnDot or child is BleedDot:
			child.free()
	_sniper.cleanup()
	# Invalidates any SceneTreeTimer-based leech loop from the old lease.
	_leech.setup(self)
	player = null
	velocity = Vector2.ZERO
	knockback_vel = Vector2.ZERO
	stun_time = 0.0
	set_process(false)
	set_physics_process(false)
	visible = false
	if _body_shape == null or not is_instance_valid(_body_shape):
		_body_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _body_shape != null:
		_body_shape.set_deferred("disabled", true)
	_set_hitbox_roles(false, false)


func _resolve_enemy_world_handle() -> int:
	if _enemy_world_handle != 0 and EnemyWorld.is_valid_handle(_enemy_world_handle):
		return _enemy_world_handle
	_enemy_world_handle = EnemyWorld.handle_for_actor(self)
	return _enemy_world_handle


func _apply_enemy_world_health(current_health: float, maximum_health: float) -> void:
	max_hp = maximum_health
	hp = current_health


func _apply_enemy_world_damage_feedback(applied_damage: float, source: Node, payload: Variant) -> void:
	_life.apply_damage_feedback(applied_damage, source, payload)


func _apply_enemy_world_death(context: RefCounted) -> void:
	_life.resolve_death(context)


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
