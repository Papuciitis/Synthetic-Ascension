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
# Elite modifiers (roadmap §9): ids in pick order, a bit mask for the physics
# step, the VAMPIRIC drain clock and the tell drawn on the body.
var _elite_modifier_ids: Array[StringName] = []
var _elite_mod_bits: int = 0
var _vampiric_left: float = 0.0
var _elite_mark: Node2D = null
# The body colour the modifier tint replaced; the clear gives it back.
var _elite_body_modulate: Color = Color.WHITE
# Where the modifier label pops, relative to the body.
const ELITE_LABEL_OFFSET := Vector2(0.0, -34.0)
# BattleText entry emphasis of the modifier label.
const ELITE_LABEL_SCALE := 1.15
# A promotion this many px past the visible rect still pops and teaches.
const ELITE_IN_VIEW_MARGIN := 48.0
## An introduction owed to the player: the promotion happened out of view, so
## the label and teach line fire on first sight instead of being dropped.
var _elite_intro_pending: bool = false
var _elite_intro_tint: Color = Color.WHITE

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
# Last requested deferred collision-role values (see _set_body_shape_disabled).
var _body_shape_disabled_request := -1
var _hitbox_monitoring_request := -1
var _hitbox_monitorable_request := -1
var _batched_renderer_id: int = 0
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

# A representation lease is taken on every pooled obtain, so a starved or broken
# EnemyWorld would push one error per spawn. Report at most one line per this
# window and carry the count of the failures it suppressed into the next one.
const LEASE_ERROR_WINDOW_MS := 5000
static var _lease_error_next_ms: int = 0
static var _lease_error_suppressed: int = 0

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
## Sheet-driven stride/idle frames; null for archetypes still on placeholders.
var animator: EnemyAnimator = null

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
			_report_lease_failure("hydrate", lease_handle)
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
	if not pool_warming:
		_register_batched_visual()

	if not pool_warming:
		_emit_archetype_encountered()


func _emit_archetype_encountered() -> void:
	# Deferred callers can land after a same-frame recycle; never announce a
	# node that is back in the pool or already gone.
	if not is_inside_tree() or bool(get_meta("__in_pool", false)):
		return
	if RunEvents != null and RunEvents.has_signal("enemy_archetype_encountered"):
		RunEvents.enemy_archetype_encountered.emit(self)


func _exit_tree() -> void:
	# Before unregister: it zeroes the world handle the combat registries key on.
	_clear_elite_modifiers()
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
	# Only a live VAMPIRIC pays for its clock; every other enemy pays one int test.
	if (_elite_mod_bits & EliteModifiers.BIT_VAMPIRIC) != 0:
		_tick_vampiric(delta)
	# An owed introduction costs one bool per tick; the view test runs only
	# while it is owed, and never again once paid.
	if _elite_intro_pending and _in_player_view():
		_announce_elite_modifiers(elite_modifier_ids(), _elite_intro_tint)

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
	if animator != null:
		animator.tick(velocity)


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
	if _sim_scheduler == null or not is_instance_valid(_sim_scheduler):
		_sim_scheduler = get_node_or_null("/root/EnemySimulationScheduler")
	if (
		_sim_scheduler != null
		and _sim_scheduler.has_method("should_release_noncontact_smart")
		and bool(_sim_scheduler.call("should_release_noncontact_smart", ai, player_distance))
	):
		return true
	# Once released, hold far physics until meaningfully closer so the boundary
	# cannot flap materialization every assignment refresh.
	var release := (
		lod_smart_reacquire_distance if _lod_tier == 2
		else lod_smart_release_distance
	)
	# The scheduler owns the exact hysteretic boundaries for each pressure tier.
	# Local exports remain as a safe fallback for isolated scenes and old saves.
	if (
		_sim_scheduler != null
		and _sim_scheduler.has_method("smart_physics_boundary")
	):
		release = float(_sim_scheduler.call("smart_physics_boundary", _lod_tier == 2))
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
	if kind == &"summon" or kind == &"beat":
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


func _register_batched_visual() -> void:
	# Batched enemy visuals: the sprite hides and the shared proxy renderer
	# draws every enemy through per-texture MultiMesh batches, collapsing
	# hundreds of per-node sprite draws. Falls back to normal sprites when
	# the proxy root is absent or the debug flag is off. Registration is per
	# node instance; the renderer skips pooled/hidden/dead actors and prunes
	# freed ones.
	if Global == null or not Global.debug_enemy_visual_batching:
		_unregister_batched_visual()
		return
	var proxy_root := get_tree().get_first_node_in_group(&"enemy_proxy_root")
	var renderer: Node = proxy_root.get("renderer") if proxy_root != null else null
	if renderer == null or not renderer.has_method("register_actor"):
		_unregister_batched_visual()
		return
	# Registration must be per RENDERER instance, not per node lifetime:
	# pooled nodes outlive the per-scene renderer, so a node recycled
	# across a segment transition carried _visual_batched=true, a hidden
	# sprite, and no entry in the NEW renderer — permanently invisible
	# (and materialization pulls from the same stale pool, so the
	# invisible ones appeared preferentially near the player).
	var renderer_id := renderer.get_instance_id()
	if _visual_batched and _batched_renderer_id == renderer_id:
		# Already registered with THIS renderer (same-scene pool reuse). The
		# entry survives recycle, so its interpolation snapshot still holds
		# the previous occupant's death transform - without this reset the
		# next publish draws one frame at the last kill's position.
		if renderer.has_method("reset_actor_snapshot"):
			renderer.call("reset_actor_snapshot", self)
		return
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	renderer.call("register_actor", self, sprite)
	sprite.visible = false
	_visual_batched = true
	_batched_renderer_id = renderer_id


func _unregister_batched_visual() -> void:
	# Exact inverse of registration: leave the registry (publish() walks every
	# entry each frame, so it must track live enemies only) and draw the own
	# sprite again, so an unbatched node is never invisible - whichever scene
	# or renderer it is reused in.
	if not _visual_batched:
		return
	var renderer := instance_from_id(_batched_renderer_id) as Node
	if renderer != null and renderer.has_method("unregister_actor"):
		renderer.call("unregister_actor", self)
	_visual_batched = false
	_batched_renderer_id = 0
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.visible = true


func _apply_simulation_collision_roles() -> void:
	_set_body_shape_disabled(_lod_tier == 2)
	var participates_in_queries := _lod_tier < 2
	_set_hitbox_roles(
		participates_in_queries and _get_active_ai() == EnemySpec.AI.LEECH,
		participates_in_queries
	)


# Collision roles are written deferred (physics flush). Comparing against the
# LIVE property while an earlier deferred write is still pending drops the
# newer request: a same-frame recycle->obtain left the reused enemy with the
# recycle's "disabled = true" landing last, collisionless until the next
# assignment refresh changed its tier (never, while paused). So each helper
# also remembers the last REQUESTED value and writes whenever either the
# request or the live value differs (-1 = nothing requested yet).
func _set_body_shape_disabled(disabled: bool) -> void:
	if _body_shape == null or not is_instance_valid(_body_shape):
		_body_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _body_shape == null:
		return
	var want := 1 if disabled else 0
	if _body_shape_disabled_request != want or _body_shape.disabled != disabled:
		_body_shape_disabled_request = want
		_body_shape.set_deferred("disabled", disabled)


func _set_hitbox_roles(active_monitoring: bool, can_be_monitored: bool) -> void:
	if _hitbox == null or not is_instance_valid(_hitbox):
		_hitbox = get_node_or_null("Hitbox") as Area2D
	if _hitbox == null:
		return
	var want_monitoring := 1 if active_monitoring else 0
	if _hitbox_monitoring_request != want_monitoring or _hitbox.monitoring != active_monitoring:
		_hitbox_monitoring_request = want_monitoring
		_hitbox.set_deferred("monitoring", active_monitoring)
	var want_monitorable := 1 if can_be_monitored else 0
	if _hitbox_monitorable_request != want_monitorable or _hitbox.monitorable != can_be_monitored:
		_hitbox_monitorable_request = want_monitorable
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
	# Before unregister: it zeroes the world handle the combat registries key on.
	_clear_elite_modifiers()
	if _enemy_index == null or not is_instance_valid(_enemy_index):
		_enemy_index = get_node_or_null("/root/EnemyIndex")
	if _enemy_index != null and _enemy_index.has_method("unregister"):
		_enemy_index.call("unregister", self)
	_sniper.cleanup()
	player = null
	set_process(false)
	set_physics_process(false)
	visible = false
	_set_body_shape_disabled(true)
	_set_hitbox_roles(false, false)
	_unregister_batched_visual()
	# A parked node is not a live enemy. Everything that ITERATES the group
	# wants the living (separation, herald buffs, tactical neighbours, the
	# spawner's census, Level1Builder's opening-restore sweep, which used to
	# queue_free the whole warm pool); everything that TESTS the group asks
	# "is this thing I just hit an enemy?", and a parked node is never hit.
	# _reset_for_pool_obtain re-adds on the way back out.
	remove_from_group(&"enemies")


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
		_report_lease_failure("reuse", handle)


# Returns how many failures the caller's line stands for; 0 means suppressed.
static func _claim_lease_error(now_ms: int) -> int:
	if now_ms < _lease_error_next_ms:
		_lease_error_suppressed += 1
		return 0
	var stands_for := _lease_error_suppressed + 1
	_lease_error_suppressed = 0
	_lease_error_next_ms = now_ms + LEASE_ERROR_WINDOW_MS
	return stands_for


func _report_lease_failure(phase: String, handle: int) -> void:
	var stands_for := _claim_lease_error(Time.get_ticks_msec())
	if stands_for <= 0:
		return
	push_error(
		"[EnemyActor] %s: representation lease unavailable handle=%d spec=%s pool_warming=%s failures=%d"
		% [
			phase,
			handle,
			(String(spec.id) if spec != null else "<no spec>"),
			bool(get_meta("__in_pool", false)),
			stands_for,
		]
	)


func _reset_for_pool_obtain(register_new_logical_enemy: bool = true) -> void:
	_clear_elite_modifiers()
	for child in get_children():
		if child is BurnDot or child is BleedDot or child is VFX_EliteModifierMark:
			child.free()
	for key in [
		&"culled",
		&"cull_reason",
		&"_threat_scaled",
		&"split_generation",
		&"split_item_entitled",
		&"elite_split_child",
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
	# Re-register with the CURRENT scene's batch renderer (idempotent per
	# renderer). Also rebuilds the interpolation snapshot, so a reused node
	# doesn't smear from its old death site for 200ms.
	_register_batched_visual()
	# Pooled nodes never re-run _ready, so the first-encounter dossier used
	# to fire only when a pool ran dry - minutes late, usually while the
	# player watched a DIFFERENT new archetype. Deferred so the spawner has
	# finished positioning and elite-rolling before the card reads the node.
	call_deferred("_emit_archetype_encountered")


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
	# Roadmap §9: from ascension on, an elite also IS something readable.
	_promote_elite(EliteModifiers.pick_for_phase(_segment_phase(), spec))


## Roadmap §9 / plan §2.4: a beat (the Hunter: fast + vampiric) or any other
## caller names the modifiers it wants. Promotes a plain enemy; on a live elite
## it replaces the current set. Unknown and archetype-denied ids are dropped.
func apply_elite_modifiers(ids: Array[StringName]) -> void:
	if spec == null or dead:
		return
	if not is_elite:
		_promote_elite(ids)
		return
	# The clear restores the plain elite look, so an empty set reads as one.
	_clear_elite_modifiers()
	_apply_elite_modifiers(ids)


func elite_modifier_ids() -> Array[StringName]:
	return _elite_modifier_ids.duplicate()


func has_elite_modifier(id: StringName) -> bool:
	return (_elite_mod_bits & EliteModifiers.bit_for(id)) != 0


func _segment_phase() -> StringName:
	var director := get_node_or_null("/root/ThreatDirector")
	if director == null:
		return &"recon"
	var phase: Variant = director.get("segment_phase")
	if phase is StringName or phase is String:
		return StringName(phase)
	return &"recon"


func _promote_elite(requested: Array[StringName]) -> void:
	var modifiers := EliteModifiers.filter_for_spec(requested, spec)
	is_elite = true
	if PerformanceFlightRecorder != null and bool(PerformanceFlightRecorder.get("enabled")):
		var modifier_names: PackedStringArray = []
		for id in modifiers:
			modifier_names.append(String(id))
		PerformanceFlightRecorder.record_counter_event(&"enemy", &"elite_promoted", 1, {
			"enemy_id": scene_file_path.get_file().get_basename(),
			"modifiers": ",".join(modifier_names),
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
	# The proxy renderer caches a per-handle visual profile from the FIRST
	# demotion; without invalidation an enemy promoted to elite kept its
	# old tint/scale whenever it rendered as a data-only proxy.
	if _enemy_world_handle != 0:
		var elite_proxy_root := get_tree().get_first_node_in_group(&"enemy_proxy_root")
		var elite_renderer: Node = elite_proxy_root.get("renderer") if elite_proxy_root != null else null
		if elite_renderer != null and elite_renderer.has_method("invalidate_visual_profile"):
			elite_renderer.call("invalidate_visual_profile", _enemy_world_handle)
	_apply_elite_modifiers(modifiers)


func _apply_elite_modifiers(requested: Array[StringName]) -> void:
	var ids := EliteModifiers.filter_for_spec(requested, spec)
	_elite_modifier_ids = ids
	_elite_mod_bits = 0
	for id in ids:
		_elite_mod_bits |= EliteModifiers.bit_for(id)
	if ids.is_empty():
		return
	var handle := _resolve_enemy_world_handle()
	if (_elite_mod_bits & EliteModifiers.BIT_FAST) != 0:
		# On top of the archetype's elite multipliers; the HP cut keeps it a
		# glass cannon the player can still answer.
		configure_health(max_hp * EliteModifiers.FAST_HP_MULT, true)
		speed *= EliteModifiers.FAST_SPEED_MULT
		_base_speed = speed
	if (_elite_mod_bits & EliteModifiers.BIT_ARMOURED) != 0 and handle != 0:
		EnemyCombat.set_elite_armour(handle, EliteModifiers.ARMOUR_FLAT_FRACTION)
	if (_elite_mod_bits & EliteModifiers.BIT_SHIELDED) != 0 and handle != 0:
		EnemyCombat.set_elite_shield(handle, EliteModifiers.SHIELD_RADIUS)
	if (_elite_mod_bits & EliteModifiers.BIT_VAMPIRIC) != 0:
		_vampiric_left = EliteModifiers.VAMPIRIC_DRAIN_EVERY
	# The tell: the first modifier's tint on the body, every modifier's mark.
	# The colour found here is the one the clear restores.
	var tint := EliteModifiers.tint(ids[0])
	var spr := get_node_or_null("Sprite2D") as CanvasItem
	if spr != null:
		_elite_body_modulate = spr.modulate
		spr.modulate = tint
	_attach_elite_mark(ids, tint)
	_announce_elite_modifiers(ids, tint)


func _clear_elite_modifiers() -> void:
	if _elite_mod_bits == 0 and _elite_modifier_ids.is_empty():
		return
	if (_elite_mod_bits & (EliteModifiers.BIT_ARMOURED | EliteModifiers.BIT_SHIELDED)) != 0 and _enemy_world_handle != 0:
		EnemyCombat.clear_elite_modifiers(_enemy_world_handle)
	# FAST is the one modifier that lives in the actor's stats rather than a
	# registry or a clock; without giving them back a replacement inherits
	# them and a second FAST squares them. The exact inverse of the apply, and
	# not a heal: raising the cap back leaves HP where FAST left it, only a
	# promotion fills. A teardown clears too; there the pool reset overwrites
	# both from the scene base right after, and configure_health skips a corpse.
	if (_elite_mod_bits & EliteModifiers.BIT_FAST) != 0:
		speed /= EliteModifiers.FAST_SPEED_MULT
		_base_speed = speed
		configure_health(max_hp / EliteModifiers.FAST_HP_MULT)
	_elite_mod_bits = 0
	_elite_modifier_ids = []
	_vampiric_left = 0.0
	_elite_intro_pending = false
	# The VAMPIRIC pulse writes the sprite's modulate every redraw, and a
	# queued free still steps this frame: the mark is released before the body
	# gets back the colour the apply found.
	_drop_elite_mark()
	var spr := get_node_or_null("Sprite2D") as CanvasItem
	if spr != null:
		spr.modulate = _elite_body_modulate


func _attach_elite_mark(ids: Array[StringName], tint: Color) -> void:
	_drop_elite_mark()
	var mark := VFX_EliteModifierMark.new()
	mark.setup(self, ids, tint)
	add_child(mark)
	_elite_mark = mark


func _drop_elite_mark() -> void:
	if _elite_mark != null and is_instance_valid(_elite_mark):
		if _elite_mark.has_method("release"):
			_elite_mark.call("release")
		_elite_mark.queue_free()
	_elite_mark = null


func _announce_elite_modifiers(ids: Array[StringName], tint: Color) -> void:
	# Legibility is part of the mechanism: the label pops on the body when the
	# promotion happens in view, and each modifier teaches itself once per run
	# the first time one is promoted where the player can see it.
	if not _in_player_view():
		# Defer, do not drop. An elite promoted off-screen still arrives, and
		# the Run Sheet's field notes only know a modifier once it has been
		# taught - a missed popup used to mean no note either.
		_elite_intro_pending = true
		_elite_intro_tint = tint
		return
	_elite_intro_pending = false
	var labels: PackedStringArray = []
	for id in ids:
		labels.append(EliteModifiers.label(id))
	if BattleText != null:
		BattleText.popup(global_position + ELITE_LABEL_OFFSET, " · ".join(labels), tint, ELITE_LABEL_SCALE)
	if RunEvents == null or not RunEvents.has_signal("tutorial_tip"):
		return
	for id in ids:
		if EliteModifiers.consume_teach(id):
			RunEvents.tutorial_tip.emit(EliteModifiers.teach_line(id), EliteModifiers.TEACH_SECONDS)


func _in_player_view(margin: float = ELITE_IN_VIEW_MARGIN) -> bool:
	if not is_inside_tree():
		return false
	var viewport := get_viewport()
	if viewport == null:
		return false
	var rect := viewport.get_visible_rect().grow(margin)
	return rect.has_point(viewport.get_canvas_transform() * global_position)


func _tick_vampiric(delta: float) -> void:
	_vampiric_left -= delta
	if _vampiric_left > 0.0:
		return
	_vampiric_left = EliteModifiers.VAMPIRIC_DRAIN_EVERY
	# Nothing to heal: skip the gather entirely.
	if hp >= max_hp:
		return
	if _enemy_index == null or not is_instance_valid(_enemy_index):
		_enemy_index = get_node_or_null("/root/EnemyIndex")
	if _enemy_index == null or not _enemy_index.has_method("gather_in_radius"):
		return
	var gathered: Array = []
	_enemy_index.call("gather_in_radius", global_position, EliteModifiers.VAMPIRIC_DRAIN_RADIUS, gathered)
	var healed := 0.0
	var fed := 0
	for n in gathered:
		var ally := n as EnemyActor
		if ally == null or ally == self or ally.dead or ally.is_elite:
			continue
		var taken := EnemyCombat.drain_health(
			EnemyCombat.handle_for_actor(ally),
			ally.max_hp * EliteModifiers.VAMPIRIC_DRAIN_FRACTION,
			EliteModifiers.VAMPIRIC_DRAIN_FLOOR_HP,
		)
		if taken <= 0.0:
			continue
		healed += taken
		fed += 1
		if fed >= EliteModifiers.VAMPIRIC_DRAIN_TARGETS:
			break
	if healed > 0.0:
		heal(healed)
		if _elite_mark != null and is_instance_valid(_elite_mark) and _elite_mark.has_method("note_feed"):
			_elite_mark.call("note_feed")
		if PerformanceFlightRecorder != null and bool(PerformanceFlightRecorder.get("enabled")):
			PerformanceFlightRecorder.record_counter_event(&"enemy", &"elite_vampiric_fed", 1, {
				"enemy_id": scene_file_path.get_file().get_basename(),
			})


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
	# Promotion obtains from the same pool as spawning: without this, a
	# proxy visible at distance went INVISIBLE the moment it materialized
	# near the player on a cross-scene recycled node.
	_register_batched_visual()
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
			# A sheet-animated enemy shows one atlas region; its data-only
			# proxy keeps the standing frame rather than the whole sheet.
			var frame_size := texture_size
			if animator != null and animator.is_active():
				var region := animator.idle_region()
				frame_size = region.size
				state["proxy_region"] = EnemyAnimator.normalized_region(region, texture_size)
			elif sprite.region_enabled:
				frame_size = sprite.region_rect.size
				state["proxy_region"] = EnemyAnimator.normalized_region(sprite.region_rect, texture_size)
			state["proxy_size"] = Vector2(
				maxf(absf(frame_size.x * sprite.scale.x * scale.x), 4.0),
				maxf(absf(frame_size.y * sprite.scale.y * scale.y), 4.0),
			)
	return state


func _quiesce_representation_lease() -> void:
	_representation_lease_active = false
	for child in get_children():
		if child is BurnDot or child is BleedDot:
			child.free()
	_sniper.cleanup()
	_clear_elite_modifiers()
	# Invalidates any SceneTreeTimer-based leech loop from the old lease.
	_leech.setup(self)
	player = null
	velocity = Vector2.ZERO
	knockback_vel = Vector2.ZERO
	stun_time = 0.0
	set_process(false)
	set_physics_process(false)
	visible = false
	_set_body_shape_disabled(true)
	_set_hitbox_roles(false, false)
	_unregister_batched_visual()
	# Same as the recycle path: a lease-quiesced actor is a data-only proxy
	# with no body, and must not read as a live enemy. Rematerialization
	# re-adds (this path does NOT go through _reset_for_pool_obtain).
	remove_from_group(&"enemies")


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
