extends Node

const AttackScope = preload("res://scenes/world/bosses/BossAttackScope.gd")
const GroundWarning = preload("res://scenes/world/bosses/BossGroundWarning.gd")
const SpriteTrail = preload("res://scenes/world/bosses/BossSpriteTrail.gd")
const ImpactSprites = preload("res://scenes/world/bosses/BossImpactSprites.gd")
const WindupSprites = preload("res://scenes/world/bosses/BossWindupSprites.gd")
const ArrivalSprites = preload("res://scenes/world/bosses/BossArrivalSprites.gd")
const TEACHING_RUSH_TELL := 0.85
const TEACHING_RECOVERY := 0.9
const TEACHING_SHOCK_INTERVAL := 0.32
const TEACHING_CALL_TELL := 1.0
const RUNNER_LIFETIME := 15.0
const RUNNER_RADIUS := 17.0

@export_group("Slam")
@export var slam_every: float = 3.6
@export var slam_windup: float = 0.65
@export var slam_radius: float = 135.0
@export var slam_damage: float = 18.0

@export_group("Shockwave")
@export var shockwave_every: float = 5.2
@export var shockwave_waves: int = 3
@export var shockwave_spacing: float = 140.0
@export var shockwave_radius: float = 85.0
@export var shockwave_damage: float = 10.0
@export var shockwave_windup: float = 0.55

@export_group("Blockers")
@export var summon_every: float = 9.0
@export var summon_count: int = 3
@export var blocker_scene: PackedScene = preload("res://scenes/world/enemies/EnemyRunner.tscn")

@export_group("VFX")
@export var vfx_ring_scene: PackedScene = preload("res://assets/vfx/world/sets/conduit/VFX_ShockRing.tscn")
@export var vfx_wave_scene: PackedScene = preload("res://assets/vfx/world/sets/conduit/VFX_Shockwave.tscn")
@export var damage_circle_scene: PackedScene = preload("res://core/combat/hazards/DamageCircle.tscn")

var _e: EnemyActor
var _slam_cd: float = 1.5
var _shock_cd: float = 2.0
var _summon_cd: float = 5.0

var _phase: int = 0
var _was_charging: bool = false
var _trail: Node2D = null
var _trail_step_accum: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _scope: Node
var _cast: StringName = &""
var _cast_elapsed := 0.0
var _cast_origin := Vector2.ZERO
var _cast_dir := Vector2.RIGHT
var _shock_index := 0
var _warnings: Array[Node] = []
var _windup: Node2D
var _main_tier := false
var _legacy_slam_tell := 0.65
var _legacy_shock_tell := 0.55
var _rush_cd := 0.6
var _rush_previous := Vector2.ZERO
var _rush_hit := false
var _recovery_generation := -1
var _call_consumed := false
var _arrival_positions: Array[Vector2] = []
var _arrival_cues: Array[Node2D] = []
var _runner_lives: Array[Dictionary] = []

func _ready() -> void:
	_e = get_parent() as EnemyActor
	if _e == null:
		set_process(false)
		return
	_e.set_meta("boss_archetype", "tank")
	_e.set_meta(&"boss_controller_owns_charge", true)
	_legacy_slam_tell = slam_windup
	_legacy_shock_tell = shockwave_windup
	slam_windup = 1.3
	shockwave_windup = 1.35
	_set_teaching_state(&"idle")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Observe the actor's completed physics move, including its last dash step.
	process_physics_priority = 10
	_scope = AttackScope.new()
	add_child(_scope)
	_scope.setup(_e)
	_scope.cast_interrupted.connect(_interrupt_cast)
	_last_pos = _e.global_position
	set_process(true)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_sync_tier()
	if not _main_tier:
		return
	if _scope == null or not _scope.is_active():
		_cancel_cast()
		_stop_trail()
		return
	if _e.player == null or not is_instance_valid(_e.player):
		return

	if _cast != &"":
		_tick_cast(delta)
		return

	# Phase logic (simple)
	var hp_ratio := 1.0
	if _e.max_hp > 0.0:
		hp_ratio = clampf(_e.hp / _e.max_hp, 0.0, 1.0)

	_phase = 0
	if hp_ratio <= 0.50:
		_phase = 1
	if hp_ratio <= 0.20:
		_phase = 2

	var cd_mul := 1.0
	if _phase == 1:
		cd_mul = 0.78
	elif _phase == 2:
		cd_mul = 0.62

	_slam_cd = maxf(_slam_cd - delta, 0.0)
	_shock_cd = maxf(_shock_cd - delta, 0.0)
	_summon_cd = maxf(_summon_cd - delta, 0.0)

	# The rush trail and endpoint are cosmetic at both tiers.
	_track_charge(delta)

	# Abilities
	var dist := _e.global_position.distance_to(_e.player.global_position)

	if _slam_cd <= 0.0 and dist <= 220.0 and not _is_busy():
		_slam_cd = slam_every * cd_mul
		_do_slam()
		return

	if _shock_cd <= 0.0 and dist <= 520.0 and not _is_busy():
		_shock_cd = shockwave_every * cd_mul
		_do_shockwave()
		return

	if _summon_cd <= 0.0 and _phase >= 1 and not _is_busy():
		_summon_cd = summon_every * lerpf(1.0, 0.75, float(_phase) / 2.0)
		_summon_blockers()


func _sync_tier() -> void:
	var main := is_instance_valid(_e) and _e.is_in_group(&"boss")
	if main == _main_tier:
		return
	_main_tier = main
	slam_windup = _legacy_slam_tell if main else 1.3
	shockwave_windup = _legacy_shock_tell if main else 1.35
	_e.set_meta(&"boss_controller_owns_charge", not main)
	_e.set_meta(&"boss_contact_suppressed", false)


func _set_teaching_state(state: StringName) -> void:
	if is_instance_valid(_e):
		_e.set_meta(&"boss_teaching_state", state)
		_e.set_meta(&"boss_contact_suppressed", not _main_tier and state != &"idle")


func _tick_teaching_selection(delta: float) -> void:
	_slam_cd = maxf(0.0, _slam_cd - delta)
	_shock_cd = maxf(0.0, _shock_cd - delta)
	_rush_cd = maxf(0.0, _rush_cd - delta)
	var dist := _e.global_position.distance_to(_e.player.global_position)
	if _e.hp <= _e.max_hp * 0.5 and not _call_consumed:
		_summon_blockers()
	elif _slam_cd <= 0.0 and dist <= 220.0:
		_slam_cd = slam_every
		_do_slam()
	elif _rush_cd <= 0.0 and dist <= _e.spec.charge_trigger_range:
		_begin_teaching_rush()
	elif _shock_cd <= 0.0 and dist <= 520.0:
		_shock_cd = shockwave_every
		_do_shockwave()


func _begin_teaching_rush() -> bool:
	_sync_tier()
	if _main_tier or not _begin_cast(&"rush_tell"):
		return false
	_rush_cd = 3.6
	_rush_hit = false
	_cast_dir = (_e.player.global_position - _cast_origin).normalized()
	if _cast_dir.is_zero_approx():
		_cast_dir = Vector2.RIGHT
	SfxManager.play_2d(&"boss_warning", _cast_origin)
	_windup = WindupSprites.new()
	var body := _e.get_node("CollisionShape2D") as CollisionShape2D
	var diameter := (body.shape as CircleShape2D).radius * 2.0
	_windup.setup(_cast_dir, TEACHING_RUSH_TELL, &"charge", _e.spec.charge_speed * _e.spec.charge_duration, diameter)
	_windup.externally_driven = true
	AttackScope.bind(_windup, _e)
	_e.add_child(_windup)
	return true


func _physics_process(delta: float) -> void:
	_sync_tier()
	if not _main_tier:
		_tick_teaching(delta)


func _tick_teaching(delta: float) -> void:
	if get_tree().paused:
		return
	_tick_runner_lives(delta)
	if _scope == null or not _scope.is_active():
		if _cast == &"recovery" and _scope != null and _scope.owner_available():
			_tick_cast(delta)
			return
		_cancel_cast()
		return
	if not is_instance_valid(_e.player):
		_cancel_cast()
		return
	if _cast == &"rush":
		_resolve_rush_contact(_rush_previous, _e.global_position)
		_rush_previous = _e.global_position
		_track_charge(0.0)
		if _e._charge._time_left <= 0.0:
			_enter_recovery()
	elif _cast != &"":
		_tick_cast(delta)
	else:
		_tick_teaching_selection(delta)


func _resolve_rush_contact(from: Vector2, to: Vector2) -> void:
	if _rush_hit or not is_instance_valid(_e.player):
		return
	var collider := _e.get_node("CollisionShape2D") as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collider.shape
	query.collision_mask = 4 # The physical player body, not decorative art or Hitbox.
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = _e.safe_margin + 0.1
	query.exclude = [_e.get_rid()]
	var space := _e.get_world_2d().direct_space_state
	query.transform = Transform2D(0.0, from)
	var hit := not space.intersect_shape(query, 8).is_empty()
	query.motion = to - from
	if not hit and not query.motion.is_zero_approx():
		var travel := space.cast_motion(query)
		hit = travel.size() == 2 and travel[0] < 1.0
	query.motion = Vector2.ZERO
	query.transform = Transform2D(0.0, to)
	if not hit:
		hit = not space.intersect_shape(query, 8).is_empty()
	if hit:
		_rush_hit = true
		var raw_damage := 10.0
		if _e.player.has_method("_threat_enemy_damage_mul"):
			raw_damage *= float(_e.player.call("_threat_enemy_damage_mul"))
		_e.player.call("take_damage", raw_damage, _e)

func _is_busy() -> bool:
	if _cast != &"":
		return true
	# Don't start new casts while EnemyCharge is overriding movement.
	if _e != null and _e._charge != null:
		return (_e._charge._windup_left > 0.0 or _e._charge._time_left > 0.0)
	return false

func _track_charge(_delta: float) -> void:
	if _e == null or _e._charge == null:
		return

	var charging_now := (_e._charge._time_left > 0.0)

	if charging_now and not _was_charging:
		# start trail
		_was_charging = true
		_trail_step_accum = 0.0
		_last_pos = _e.global_position

		_trail = SpriteTrail.new()
		if _trail != null:
			AttackScope.bind(_trail, _e)
			get_tree().current_scene.add_child(_trail)
			_trail.follow = _e
			_trail.width = 7.5
			_trail.alpha = 0.40
		return

	if not charging_now and _was_charging:
		_was_charging = false
		# stop trail + impact pop
		if _trail != null and is_instance_valid(_trail):
			_trail.stop_and_fade()
		_trail = null

		# impact wave at end of charge
		_spawn_wave(_e.global_position, slam_radius * 0.85)
		return

func _do_slam() -> void:
	if not _begin_cast(&"slam"):
		return
	SfxManager.play_2d(&"boss_warning", _cast_origin)
	_add_warning(_cast_origin, slam_radius, maxf(0.05, slam_windup), &"slam")
	_show_windup(&"slam", slam_windup)

func _do_shockwave() -> void:
	if not _begin_cast(&"shock"):
		return
	SfxManager.play_2d(&"boss_warning", _cast_origin)
	_cast_dir = (_e.player.global_position - _cast_origin).normalized()
	if _cast_dir == Vector2.ZERO:
		_cast_dir = Vector2.RIGHT
	_shock_index = 0
	_show_windup(&"shock", shockwave_windup)
	for i in range(maxi(1, shockwave_waves)):
		_add_warning(_cast_origin + _cast_dir * shockwave_spacing * float(i + 1), shockwave_radius, _shock_time(i), &"shock")

func _begin_cast(kind: StringName) -> bool:
	_sync_tier()
	if _scope == null or not _scope.is_active() or _is_busy():
		return false
	_cast = kind
	_cast_elapsed = 0.0
	_cast_origin = _e.global_position
	_e.set_meta(&"boss_cast_locked", true)
	if not _main_tier:
		_set_teaching_state(kind)
	return true

func _shock_time(index: int) -> float:
	if not _main_tier:
		return maxf(0.05, shockwave_windup) + TEACHING_SHOCK_INTERVAL * float(index)
	return maxf(0.05, shockwave_windup) + 0.06 * float(index * (index + 1))

func _tick_cast(delta: float) -> void:
	if get_tree().paused:
		return
	# An interruption can stop an attack, but cannot erase its already-earned
	# melee opening. Death or leaving the court still cancels recovery.
	if _cast == &"recovery":
		if _scope == null or not _scope.owner_available() or _scope.generation != _recovery_generation:
			_cancel_cast()
			return
		_cast_elapsed += delta
		if _cast_elapsed >= TEACHING_RECOVERY:
			_cancel_cast()
		return
	if _scope == null or not _scope.is_active():
		_cancel_cast()
		return
	_cast_elapsed += delta
	if not _main_tier:
		_update_teaching_anticipation()
	if _cast == &"rush_tell":
		# Knockback can earn an interruption, never a relocated or teleported
		# rush whose real start disagrees with its committed lane.
		if _e.global_position.distance_to(_cast_origin) > 2.0:
			_cancel_cast()
		elif _cast_elapsed >= TEACHING_RUSH_TELL:
			if is_instance_valid(_windup):
				_windup.cancel_attack()
			_windup = null
			_cast = &"rush"
			_cast_elapsed = 0.0
			_rush_previous = _e.global_position
			_e.set_meta(&"boss_cast_locked", false)
			_set_teaching_state(&"rush")
			_e._charge.begin_committed(_cast_dir, _e.spec.charge_duration, _e.spec.charge_speed)
			_track_charge(0.0)
	elif _cast == &"summon":
		for cue in _arrival_cues:
			if is_instance_valid(cue):
				cue.call("set_progress", _cast_elapsed / TEACHING_CALL_TELL)
		if _cast_elapsed >= TEACHING_CALL_TELL:
			_release_teaching_runners()
			_enter_recovery(maxf(0.0, _cast_elapsed - TEACHING_CALL_TELL))
	elif _cast == &"slam" and _cast_elapsed >= maxf(0.05, slam_windup):
		_spawn_wave(_cast_origin, slam_radius, &"slam")
		_spawn_damage_circle(_cast_origin, slam_radius, slam_damage, 0.18, &"slam")
		if _main_tier:
			_cancel_cast()
		else:
			_enter_recovery(maxf(0.0, _cast_elapsed - maxf(0.05, slam_windup)))
	elif _cast == &"shock":
		while _shock_index < maxi(1, shockwave_waves) and _cast_elapsed >= _shock_time(_shock_index):
			var pos := _cast_origin + _cast_dir * shockwave_spacing * float(_shock_index + 1)
			_spawn_wave(pos, shockwave_radius, &"shock")
			_spawn_damage_circle(pos, shockwave_radius, shockwave_damage, 0.16, &"shock")
			if _shock_index < _warnings.size() and is_instance_valid(_warnings[_shock_index]):
				_warnings[_shock_index].queue_free()
			_shock_index += 1
		if _shock_index >= maxi(1, shockwave_waves):
			if _main_tier:
				_cancel_cast()
			else:
				_enter_recovery(maxf(0.0, _cast_elapsed - _shock_time(_shock_index - 1)))


func _update_teaching_anticipation() -> void:
	var tell := TEACHING_RUSH_TELL
	if _cast == &"slam":
		tell = maxf(0.05, slam_windup)
	elif _cast == &"shock":
		tell = maxf(0.05, shockwave_windup)
	elif _cast == &"summon":
		tell = TEACHING_CALL_TELL
	if is_instance_valid(_windup):
		_windup.call("set_progress", _cast_elapsed / tell)
	for index in range(_warnings.size()):
		var warning := _warnings[index]
		if is_instance_valid(warning) and not warning.is_queued_for_deletion():
			var release_at := _shock_time(index) if _cast == &"shock" else tell
			warning.call("set_progress", _cast_elapsed / release_at)


func _clear_cast_art() -> void:
	for warning in _warnings:
		if is_instance_valid(warning):
			warning.queue_free()
	_warnings.clear()
	for cue in _arrival_cues:
		if is_instance_valid(cue):
			cue.call("cancel_attack")
	_arrival_cues.clear()
	_arrival_positions.clear()
	if is_instance_valid(_windup):
		_windup.cancel_attack()
	_windup = null


func _enter_recovery(overshoot: float = 0.0) -> void:
	_clear_cast_art()
	_cast = &"recovery"
	_cast_elapsed = overshoot
	_recovery_generation = _scope.generation
	_e._charge.cancel()
	_e.set_meta(&"boss_cast_locked", true)
	_set_teaching_state(&"recovery")
	_stop_trail()

func _add_warning(pos: Vector2, radius: float, duration: float, kind: StringName = &"generic") -> void:
	var warning: Node2D = GroundWarning.new()
	warning.call("set_attack_style", kind)
	warning.call("setup", pos, radius, duration if _main_tier else 0.0)
	AttackScope.bind(warning, _e)
	get_tree().current_scene.add_child(warning)
	_warnings.append(warning)

func _show_windup(kind: StringName, duration: float) -> void:
	if is_instance_valid(_windup):
		_windup.queue_free()
	_windup = WindupSprites.new()
	_windup.setup(_e.player.global_position - _e.global_position, duration, kind)
	_windup.externally_driven = not _main_tier
	AttackScope.bind(_windup, _e)
	_e.add_child(_windup)

func _interrupt_cast() -> void:
	if not _main_tier and _cast == &"recovery" and _scope != null and _scope.owner_available() and _scope.generation == _recovery_generation:
		return
	_cancel_cast()

func _cancel_cast() -> void:
	_cast = &""
	_cast_elapsed = 0.0
	_recovery_generation = -1
	_clear_cast_art()
	if is_instance_valid(_e):
		_e.set_meta(&"boss_cast_locked", false)
		_set_teaching_state(&"idle")
		if _e._charge != null:
			_e._charge.cancel()
		for child in _e.get_children():
			if child is VFX_ChargeWindup or child.get_script() == WindupSprites:
				if child.has_method("cancel_attack"):
					child.call("cancel_attack")
				else:
					child.queue_free()
	_stop_trail()

func _stop_trail() -> void:
	if is_instance_valid(_trail):
		_trail.queue_free()
	_trail = null
	_was_charging = false

func _summon_blockers() -> void:
	_sync_tier()
	if not _main_tier:
		_begin_teaching_call()
		return
	if blocker_scene == null:
		return
	var requested: int = maxi(1, summon_count)
	var enemy_index: Node = _e.get_node_or_null("/root/EnemyIndex")
	var granted: int = requested
	if enemy_index != null and enemy_index.has_method("try_reserve_special"):
		granted = int(enemy_index.call("try_reserve_special", &"boss_add", requested))
	var base: Vector2 = _e.global_position
	for i in range(granted):
		var ang: float = TAU * float(i) / float(maxi(1, granted))
		var pos := base + Vector2(cos(ang), sin(ang)) * 120.0
		var blocker: Node = blocker_scene.instantiate()
		if blocker == null or not (blocker is EnemyActor):
			if blocker != null:
				blocker.free()
			_release_boss_add_reservation(enemy_index)
			continue
		(blocker as Node2D).global_position = pos
		AttackScope.bind(blocker, _e)
		var current_scene: Node = get_tree().current_scene
		if current_scene == null:
			blocker.free()
			_release_boss_add_reservation(enemy_index)
			continue
		(blocker as Node2D).position = current_scene.to_local(pos) if current_scene is Node2D else pos
		if enemy_index != null and enemy_index.has_method("commit_special"):
			enemy_index.call("commit_special", blocker, &"boss_add")
		current_scene.add_child(blocker)


func _begin_teaching_call() -> void:
	if _call_consumed or blocker_scene == null or _e.hp > _e.max_hp * 0.5:
		return
	if not _begin_cast(&"summon"):
		return
	# A committed call is the one opportunity for this boss's lifetime. An
	# interrupt, failed placement or leash reset cannot replenish its rewards.
	_call_consumed = true
	for index in range(3):
		var pos := _cast_origin + Vector2.RIGHT.rotated(TAU * float(index) / 3.0) * 120.0
		if not _runner_position_clear(pos):
			continue
		_arrival_positions.append(pos)
		var cue := ArrivalSprites.new() as Node2D
		cue.call("setup", pos, 36.0, TEACHING_CALL_TELL, &"summon")
		AttackScope.bind(cue, _e)
		get_tree().current_scene.add_child(cue)
		# The same controller clock owns progress and release; helper expiry
		# cannot run one physics priority ahead and erase the final warning.
		cue.set_process(false)
		cue.set_physics_process(false)
		_arrival_cues.append(cue)
	_show_windup(&"summon", TEACHING_CALL_TELL)


func _runner_position_clear(pos: Vector2) -> bool:
	var circle := CircleShape2D.new()
	circle.radius = RUNNER_RADIUS
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, pos)
	query.collision_mask = _e.collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = 2.0
	query.exclude = [_e.get_rid()]
	if not _e.get_world_2d().direct_space_state.intersect_shape(query, 16).is_empty():
		return false
	var chunks := get_tree().get_first_node_in_group(&"chunk_manager") as ChunkManager
	return chunks == null or chunks.projectile_hit_t(pos, pos, RUNNER_RADIUS + 2.0) < 0.0


func _release_teaching_runners() -> void:
	var live := 0
	for entry: Dictionary in _runner_lives:
		var actor = (entry["ref"] as WeakRef).get_ref()
		if is_instance_valid(actor) and not actor.dead and not actor.is_queued_for_deletion():
			live += 1
	var requested := mini(_arrival_positions.size(), maxi(0, 6 - live))
	var enemy_index := _e.get_node_or_null("/root/EnemyIndex")
	var granted := requested
	if enemy_index != null:
		granted = int(enemy_index.call("try_reserve_special", &"boss_add", requested))
	for index in range(granted):
		var pos := _arrival_positions[index]
		if not _runner_position_clear(pos):
			_release_boss_add_reservation(enemy_index)
			continue
		var runner := blocker_scene.instantiate() as EnemyActor
		if runner == null:
			_release_boss_add_reservation(enemy_index)
			continue
		var world := get_tree().current_scene
		if world == null:
			runner.free()
			_release_boss_add_reservation(enemy_index)
			continue
		runner.position = world.to_local(pos) if world is Node2D else pos
		AttackScope.bind(runner, _e)
		if enemy_index != null:
			enemy_index.call("commit_special", runner, &"boss_add")
		world.add_child(runner)
		_runner_lives.append({"ref": weakref(runner), "remaining": RUNNER_LIFETIME})


func _tick_runner_lives(delta: float) -> void:
	for index in range(_runner_lives.size() - 1, -1, -1):
		var entry := _runner_lives[index]
		var actor = (entry["ref"] as WeakRef).get_ref()
		if not is_instance_valid(actor) or actor.dead or actor.is_queued_for_deletion():
			_runner_lives.remove_at(index)
			continue
		entry["remaining"] = float(entry["remaining"]) - delta
		if float(entry["remaining"]) <= 0.0:
			actor.despawn(&"boss_cleanup")
			_runner_lives.remove_at(index)


func _release_boss_add_reservation(enemy_index: Node) -> void:
	if enemy_index != null and enemy_index.has_method("release_special"):
		enemy_index.call("release_special", &"boss_add", 1)

func _spawn_wave(pos: Vector2, radius: float, kind: StringName = &"slam") -> void:
	var v := ImpactSprites.new()
	v.top_level = true
	v.setup(pos, radius, kind, 0.65 if kind == &"slam" else 0.42)
	AttackScope.bind(v, _e)
	get_tree().current_scene.add_child(v)
	SfxManager.play_2d_limited(&"boss_slam_impact", pos, 120)

func _spawn_damage_circle(pos: Vector2, radius: float, dmg: float, life: float, kind: StringName = &"generic") -> void:
	if damage_circle_scene == null:
		return
	var d := damage_circle_scene.instantiate() as DamageCircle
	d.attack_style = kind
	d.setup(pos, radius, dmg, life, _e)
	AttackScope.bind(d, _e)
	get_tree().current_scene.add_child(d)
