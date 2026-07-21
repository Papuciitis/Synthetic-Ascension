extends CharacterBody2D
class_name Enemy

@export var spec: EnemySpec

# fallback if spec is null (and also used by EnemyDrops module)
@export var item_pickup_scene: PackedScene
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 0.25
@export var drop_pool_prefixes: PackedStringArray = ["conduit_","lattice_","gravemarch_","acc_","ring_"]
@export var drop_fallback_to_all: bool = false
@export var drop_amount_min: int = 1
@export var drop_amount_max: int = 1
@export var drop_instance_roll: bool = false
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
@export var debug_drops: bool = true

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

# Flow reference (shared)
var _flow: FlowFieldNav = null

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

	# Register into EnemyIndex spatial hash (autoload; optional)
	var ei := get_node_or_null("/root/EnemyIndex")
	if ei != null and is_instance_valid(ei) and ei.has_method("register"):
		ei.call("register", self)

	# Helps reduce corner snagging in Godot kinematic solver
	safe_margin = 0.04
	max_slides = 8

	if RunEvents != null and RunEvents.has_signal("enemy_archetype_encountered"):
		RunEvents.enemy_archetype_encountered.emit(self)


func _exit_tree() -> void:
	var ei := get_node_or_null("/root/EnemyIndex")
	if ei != null and is_instance_valid(ei) and ei.has_method("unregister"):
		ei.call("unregister", self)

	# important: sniper telegraph nodes live in current_scene, so free them on despawn
	if _sniper != null:
		_sniper.cleanup()


func _physics_process(delta: float) -> void:
	# Acquire player if needed
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D

	# Cache LOS once per interval for smart AIs.
	var _ai_cache: int = _get_active_ai()
	_update_los_cache(delta, _ai_cache)

	# Knockback decay
	if knockback_vel != Vector2.ZERO:
		knockback_vel = knockback_vel.move_toward(Vector2.ZERO, knockback_decay * delta)

	# Module ticks
	_shooter.tick(delta)
	_charge.tick(delta)
	_summoner.tick(delta)
	_sniper.tick(delta)
	_herald.tick(delta)
	_tactical.tick(delta)

	# Speed buff timer (Herald)
	if _speed_mul_time > 0.0:
		_speed_mul_time = maxf(_speed_mul_time - delta, 0.0)
		if _speed_mul_time <= 0.0:
			_speed_mul = 1.0

	# Stun handling
	if stun_time > 0.0:
		stun_time = maxf(stun_time - delta, 0.0)
		velocity = knockback_vel
		move_and_slide()
		return

	if player == null:
		velocity = knockback_vel
		move_and_slide()
		return

	# Charge override (windup/dash) owned by EnemyCharge
	if _charge.step_override(delta):
		velocity = _charge.override_velocity() + knockback_vel
		move_and_slide()
		return

	# Basic vectors (player)
	var dvec: Vector2 = (player.global_position - global_position)
	var dist: float = dvec.length()
	var to_player: Vector2 = (dvec / dist) if dist > 0.001 else Vector2.ZERO

	# Boss leash / return-to-home (only for group 'boss_like').
	# Keeps bosses around their arena, prevents running them across the whole streamed map.
	var to_nav_target: Vector2 = to_player
	var boss_returning: bool = false
	if is_in_group(&"boss_like") and has_meta("boss_home_pos"):
		var home: Vector2 = get_meta("boss_home_pos") as Vector2
		var leash: float = float(get_meta("boss_leash_radius")) if has_meta("boss_leash_radius") else 900.0
		var disengage: float = float(get_meta("boss_disengage_radius")) if has_meta("boss_disengage_radius") else leash * 1.25

		var dist_home := global_position.distance_to(home)
		var player_from_home := player.global_position.distance_to(home)

		boss_returning = (dist_home > leash) or (player_from_home > disengage)
		set_meta("boss_returning", boss_returning)

		if boss_returning:
			# Heal slowly while returning.
			var heal_pct: float = float(get_meta("boss_heal_pct_per_sec")) if has_meta("boss_heal_pct_per_sec") else 0.0
			if heal_pct > 0.0 and max_hp > 0.0 and not dead:
				hp = min(max_hp, hp + max_hp * heal_pct * delta)

			var mv: Vector2 = (home - global_position)
			var md: float = mv.length()
			to_nav_target = (mv / md) if md > 0.001 else Vector2.ZERO

	# Sniper always runs for side effects (telegraph/fire)
	var base_is_sniper: bool = (spec != null and spec.ai == EnemySpec.AI.SNIPER)
	var sniper_move: Vector2 = Vector2.ZERO
	var sniper_mul: float = 1.0
	if base_is_sniper:
		sniper_move = _sniper.brain(to_player, dist, _spd())
		sniper_mul = _sniper.windup_mul()

	# Base AI move (open-field intent)
	var chase: Vector2 = Vector2.ZERO
	var ai: int = _ai_cache

	# If returning to arena, ignore the normal AI brains and just go home.
	if boss_returning:
		chase = to_nav_target * _spd()
	else:
		match ai:
			EnemySpec.AI.CHASE:
				chase = to_player * _spd()
			EnemySpec.AI.ORBIT:
				chase = _orbit_move(delta)
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

	# ✅ macro+micro steering in one place
	chase = _horde_nav.pre_steer(ai, chase, to_nav_target, delta)

	# Move
	velocity = chase + knockback_vel
	move_and_slide()

	# wall-follow decision uses collisions from this frame
	_horde_nav.post_move(chase, to_nav_target, delta)

	# Update EnemyIndex cell (cheap; no-op unless cell changed)
	var ei := get_node_or_null("/root/EnemyIndex")
	if ei != null and is_instance_valid(ei) and ei.has_method("update_enemy"):
		ei.call("update_enemy", self)


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
	max_hp *= spec.elite_hp_mult
	hp = max_hp

	speed *= spec.elite_speed_mult
	_base_speed = speed

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
