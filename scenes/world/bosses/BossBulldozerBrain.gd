extends Node

const AttackScope = preload("res://scenes/world/bosses/BossAttackScope.gd")
const GroundWarning = preload("res://scenes/world/bosses/BossGroundWarning.gd")
const SpriteTrail = preload("res://scenes/world/bosses/BossSpriteTrail.gd")
const ImpactSprites = preload("res://scenes/world/bosses/BossImpactSprites.gd")
const WindupSprites = preload("res://scenes/world/bosses/BossWindupSprites.gd")
const ArrivalSprites = preload("res://scenes/world/bosses/BossArrivalSprites.gd")
const SectorWarning = preload("res://scenes/world/bosses/BossSectorWarning.gd")
const SectorStrike = preload("res://scenes/world/bosses/BossSectorStrike.gd")
const BossPhases = preload("res://scenes/world/bosses/BossPhases.gd")
const Oracle = preload("res://scenes/world/bosses/BossEscapeOracle.gd")
const TeachingPlacement = preload("res://scenes/world/bosses/BossTeachingPlacement.gd")
const TEACHING_RUSH_TELL := 0.85
const TEACHING_RECOVERY := 0.9
const TEACHING_SHOCK_INTERVAL := 0.32
const TEACHING_CALL_TELL := 1.0
const RUNNER_LIFETIME := 15.0
const RUNNER_RADIUS := 17.0

## Main boss (S10, boss overhaul proposal steps 4-6). The S5 vocabulary keeps
## its measured tells and footprints; the main fight changes the problem by
## phase instead of shortening them. Phase 1: rush, planted slam and Fault
## Line on shorter neutral gaps. Phase 2 (65%): Sweeping Cleave and one warned
## Runner call. Phase 3 (30%): the Breach Sequence and a Fault Line follow-up.
## Every commitment must keep a walk out at baseline speed (BossEscapeOracle).
const MAIN_RUSH_EVERY := 3.0
const MAIN_SLAM_EVERY := 3.2
const MAIN_SHOCK_EVERY := 4.6
const MAIN_CLEAVE_EVERY := 3.8
const MAIN_BREACH_EVERY := 6.0
## Cooldown resets per phase: neutral gaps shorten, tells never do.
const MAIN_PHASE_TEMPO: Array[float] = [1.0, 0.9, 0.8]
const PHASE_SHIFT_SECONDS := 0.8
## A failed selection pass (nothing could keep a walk out) waits this long.
const SELECTION_RETRY := 0.2
const CLEAVE_TELL := 1.1
const CLEAVE_RADIUS := 125.0
const CLEAVE_HALF_ANGLE := 1.3089969 # 75 degrees either side of the facing
const CLEAVE_RANGE := 160.0
const CLEAVE_DAMAGE := 16.0
const CLEAVE_LIFE := 0.18
const CLEAVE_RECOVERY := 1.0
const BREACH_RUSH_TELL := 0.95
const BREACH_BEAT := 0.5
const BREACH_IMPACT_RADIUS := 100.0
const BREACH_RECOVERY := 1.2
## The rush must arrive this close to its previewed endpoint to plant there.
const BREACH_ARRIVAL_TOLERANCE := 6.0
const FOLLOWUP_GAP := 0.6
const FOLLOWUP_TURN := 0.6108652 # 35 degrees

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
@export var blocker_scene: PackedScene = preload("res://scenes/world/enemies/EnemyRunner.tscn")

@export_group("VFX")
@export var vfx_ring_scene: PackedScene = preload("res://assets/vfx/world/sets/conduit/VFX_ShockRing.tscn")
@export var vfx_wave_scene: PackedScene = preload("res://assets/vfx/world/sets/conduit/VFX_Shockwave.tscn")
@export var damage_circle_scene: PackedScene = preload("res://core/combat/hazards/DamageCircle.tscn")

var _e: EnemyActor
var _slam_cd: float = 1.5
var _shock_cd: float = 2.0

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
var _rush_cd := 0.6
var _rush_previous := Vector2.ZERO
var _rush_hit := false
var _recovery_generation := -1
var _call_consumed := false
var _arrival_positions: Array[Vector2] = []
var _arrival_cues: Array[Node2D] = []
var _runner_lives: Array[Dictionary] = []
var _recovery_seconds := TEACHING_RECOVERY
## Main boss state: phases only advance, so return healing never re-opens a
## phase's once-only arrival.
var _boss_phase := 0
var _call_pending := false
var _cleave_cd := 1.0
var _breach_cd := 1.0
var _selection_hold := 0.0
var _last_attack: StringName = &""
var _pattern_counter := 0
var _rush_tell := TEACHING_RUSH_TELL
var _breach_target := Vector2.ZERO
var _breach_warning: Node2D
var _followup_dir := Vector2.ZERO

func _ready() -> void:
	_e = get_parent() as EnemyActor
	if _e == null:
		set_process(false)
		return
	_e.set_meta("boss_archetype", "tank")
	# Both tiers choose their rushes here; the legacy charge brain never does.
	_e.set_meta(&"boss_controller_owns_charge", true)
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
	# Both tiers run on the physics clock (_physics_process).
	set_process(false)


func _sync_tier() -> void:
	var main := is_instance_valid(_e) and _e.is_in_group(&"boss")
	if main == _main_tier:
		return
	_main_tier = main
	# The arena names the tier right after spawning: start the main fight from
	# its own opening clocks.
	if main:
		_rush_cd = 1.2
		_slam_cd = 1.0
		_shock_cd = 1.8
	_e.set_meta(&"boss_contact_suppressed", false)


## The attack state also owns contact: through every committed state and
## recovery the boss adds no ordinary contact tick on top of its attacks.
func _set_teaching_state(state: StringName) -> void:
	if is_instance_valid(_e):
		_e.set_meta(&"boss_teaching_state", state)
		_e.set_meta(&"boss_contact_suppressed", state != &"idle")


func _tempo() -> float:
	return MAIN_PHASE_TEMPO[clampi(_boss_phase, 0, MAIN_PHASE_TEMPO.size() - 1)]


func _tick_main_selection(delta: float) -> void:
	_slam_cd = maxf(0.0, _slam_cd - delta)
	_shock_cd = maxf(0.0, _shock_cd - delta)
	_rush_cd = maxf(0.0, _rush_cd - delta)
	_cleave_cd = maxf(0.0, _cleave_cd - delta)
	_breach_cd = maxf(0.0, _breach_cd - delta)
	# A threshold crossed during an attack waits for it to settle (we are
	# idle here). Several crossed at once make one transition, not a queue.
	var phase := BossPhases.phase_for(clampf(_e.hp / maxf(_e.max_hp, 0.001), 0.0, 1.0))
	if phase > _boss_phase:
		_begin_phase_shift(phase)
		return
	if _call_pending:
		_call_pending = false
		_begin_teaching_call()
		return
	_selection_hold = maxf(0.0, _selection_hold - delta)
	if _selection_hold > 0.0:
		return
	var distance := _e.global_position.distance_to(_e.player.global_position)
	var options: Array[StringName] = []
	if _slam_cd <= 0.0 and distance <= 220.0:
		options.append(&"slam")
	if _boss_phase >= 1 and _cleave_cd <= 0.0 and distance <= CLEAVE_RANGE:
		options.append(&"cleave")
	if _boss_phase >= 2 and _breach_cd <= 0.0 and distance <= _e.spec.charge_trigger_range:
		options.append(&"breach")
	if _rush_cd <= 0.0 and distance <= _e.spec.charge_trigger_range:
		options.append(&"rush")
	if _shock_cd <= 0.0 and distance <= 520.0:
		options.append(&"shock")
	if options.is_empty():
		return
	for kind in _ordered_options(options):
		if _try_main_attack(kind):
			_last_attack = kind
			return
	# Nothing could keep a walk out from where the player stands right now.
	_selection_hold = SELECTION_RETRY


## A seeded weighted order: signature moves are likelier, and the last
## attack weighs a quarter while another is available (rarer, not barred).
func _ordered_options(options: Array[StringName]) -> Array[StringName]:
	var weights := {&"slam": 3.0, &"cleave": 3.0, &"breach": 3.5, &"rush": 2.0, &"shock": 2.0}
	var rng := _pattern_rng()
	var keyed: Array = []
	for kind in options:
		var weight: float = weights.get(kind, 1.0)
		if kind == _last_attack and options.size() > 1:
			weight *= 0.25
		keyed.append([pow(maxf(rng.randf(), 0.0001), 1.0 / weight), kind])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var ordered: Array[StringName] = []
	for entry: Array in keyed:
		ordered.append(entry[1])
	return ordered


func _pattern_rng() -> RandomNumberGenerator:
	var home: Vector2 = _e.get_meta(&"boss_home_pos", _e.global_position)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Global.attempt_world_seed) ^ int(Global.attempt_segment) * 10007 ^ floori(home.x) * 73856093 ^ floori(home.y) * 19349663 ^ _pattern_counter * 83492791
	_pattern_counter += 1
	return rng


## Commits `kind` only when its whole plan keeps a walk out from where the
## player stands (BossEscapeOracle), with the boss's body as an obstacle.
func _try_main_attack(kind: StringName) -> bool:
	var origin := _e.global_position
	var direction := (_e.player.global_position - origin).normalized()
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var followup := Vector2.ZERO
	if kind == &"shock" and _boss_phase >= 2:
		followup = direction.rotated(FOLLOWUP_TURN if _pattern_rng().randf() < 0.5 else -FOLLOWUP_TURN)
		if not _escapable(_plan_for(kind, origin, direction, followup)):
			followup = Vector2.ZERO
	if _cast != &"" or not _escapable(_plan_for(kind, origin, direction, followup)):
		return false
	match kind:
		&"slam":
			_do_slam()
		&"cleave":
			_do_cleave()
		&"breach":
			_do_breach()
		&"rush":
			_begin_teaching_rush()
		&"shock":
			_followup_dir = followup
			_do_shockwave()
	if _cast == &"":
		return false
	# Only an accepted commitment spends its clock (the rush sets its own).
	match kind:
		&"slam":
			_slam_cd = MAIN_SLAM_EVERY * _tempo()
		&"cleave":
			_cleave_cd = MAIN_CLEAVE_EVERY * _tempo()
		&"breach":
			_breach_cd = MAIN_BREACH_EVERY * _tempo()
		&"shock":
			_shock_cd = MAIN_SHOCK_EVERY * _tempo()
	return true


func _escapable(plan: Array) -> bool:
	var player := _e.player
	var shape: Dictionary = Oracle.player_shape(player)
	var blockers := [{"center": _e.global_position, "radius": _body_radius()}]
	var clearance := Oracle.walking_clearance(shape)
	var path_clear := func(from: Vector2, to: Vector2) -> bool:
		return TeachingPlacement.corridor_clear(_e, from, to, clearance)
	return Oracle.has_escape(player.global_position, plan, shape, blockers, path_clear, Oracle.walking_speed(player))


## The hazards an attack would release, timed from its commitment. The same
## numbers drive the casts below, so the check and the attack agree.
func _plan_for(kind: StringName, origin: Vector2, direction: Vector2, followup: Vector2 = Vector2.ZERO) -> Array:
	var plan: Array = []
	var travel := _e.spec.charge_speed * _e.spec.charge_duration
	match kind:
		&"slam":
			plan.append({"kind": &"circle", "center": origin, "radius": slam_radius, "from": slam_windup, "to": slam_windup + 0.18})
		&"cleave":
			plan.append({"kind": &"sector", "center": origin, "facing": direction.angle(), "radius": CLEAVE_RADIUS, "half_angle": CLEAVE_HALF_ANGLE, "from": CLEAVE_TELL, "to": CLEAVE_TELL + CLEAVE_LIFE})
		&"rush", &"breach":
			var tell := BREACH_RUSH_TELL if kind == &"breach" else TEACHING_RUSH_TELL
			var arrive := tell + _e.spec.charge_duration
			plan.append({"kind": &"sweep", "a": origin, "b": origin + direction * travel, "radius": _body_radius(), "from": tell, "to": arrive, "body": true})
			if kind == &"breach":
				plan.append({"kind": &"circle", "center": origin + direction * travel, "radius": BREACH_IMPACT_RADIUS, "from": arrive + BREACH_BEAT, "to": arrive + BREACH_BEAT + 0.18})
		&"shock":
			var count := maxi(1, shockwave_waves)
			for index in range(count * (2 if not followup.is_zero_approx() else 1)):
				var line := direction if index < count else followup
				var step := index % count
				var at := _fault_node_time(index, count)
				plan.append({"kind": &"circle", "center": origin + line * shockwave_spacing * float(step + 1), "radius": shockwave_radius, "from": at, "to": at + 0.16})
	return plan


func _body_radius() -> float:
	var body := _e.get_node_or_null("CollisionShape2D") as CollisionShape2D
	return (body.shape as CircleShape2D).radius if body != null and body.shape is CircleShape2D else 40.0


## The phase beat: the boss braces in place (damageable, no new attack) while
## the bar's mark and a sound mark the change. The new phase holds even if
## the beat is interrupted.
func _begin_phase_shift(phase: int) -> void:
	if not _begin_cast(&"phase_shift"):
		return
	var entering_two := _boss_phase < 1 and phase >= 1
	_boss_phase = phase
	if entering_two:
		_call_pending = true
	_show_windup(&"phase", PHASE_SHIFT_SECONDS)
	SfxManager.play_2d(&"boss_intro", _cast_origin, -6.0)
	if RunEvents != null and RunEvents.has_signal(&"boss_phase_changed"):
		RunEvents.boss_phase_changed.emit(_e, phase)


func main_phase() -> int:
	return _boss_phase


func _do_cleave() -> void:
	if not _begin_cast(&"cleave"):
		return
	_cast_dir = (_e.player.global_position - _cast_origin).normalized()
	if _cast_dir.is_zero_approx():
		_cast_dir = Vector2.RIGHT
	SfxManager.play_2d(&"boss_warning", _cast_origin)
	var warning := SectorWarning.new()
	warning.setup(_cast_origin, _cast_dir.angle(), CLEAVE_RADIUS, CLEAVE_HALF_ANGLE)
	AttackScope.bind(warning, _e)
	get_tree().current_scene.add_child(warning)
	_warnings.append(warning)
	_show_windup(&"cleave", CLEAVE_TELL)


func _do_breach() -> void:
	if not _begin_teaching_rush(BREACH_RUSH_TELL, &"breach_tell"):
		return
	# The follow-up is announced with the rush: its full footprint waits at the
	# lane's end from the first frame of the tell.
	_breach_target = _cast_origin + _cast_dir * _e.spec.charge_speed * _e.spec.charge_duration
	var warning: Node2D = GroundWarning.new()
	warning.call("set_attack_style", &"slam")
	warning.call("setup", _breach_target, BREACH_IMPACT_RADIUS, 0.0)
	AttackScope.bind(warning, _e)
	get_tree().current_scene.add_child(warning)
	_breach_warning = warning


func _breach_total() -> float:
	return BREACH_RUSH_TELL + _e.spec.charge_duration + BREACH_BEAT


## Progress of the announced impact across tell, rush and beat.
func _update_breach_warning(elapsed: float = -1.0) -> void:
	if not is_instance_valid(_breach_warning):
		return
	var time := elapsed
	if time < 0.0:
		time = BREACH_RUSH_TELL + (_e.spec.charge_duration - maxf(_e._charge._time_left, 0.0))
	_breach_warning.call("set_progress", time / _breach_total())


func _end_breach_rush() -> void:
	_e._charge.cancel()
	_stop_trail()
	# A wall or a shove stopped the rush short: the advertised impact cannot
	# happen where it was shown, so it is withdrawn, never moved.
	if _e.global_position.distance_to(_breach_target) > BREACH_ARRIVAL_TOLERANCE:
		if is_instance_valid(_breach_warning):
			_breach_warning.queue_free()
		_breach_warning = null
		_enter_recovery(0.0, BREACH_RECOVERY)
		return
	_cast = &"breach_beat"
	_cast_elapsed = 0.0
	_e.set_meta(&"boss_cast_locked", true)
	_set_teaching_state(&"breach_beat")


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


func _begin_teaching_rush(tell: float = TEACHING_RUSH_TELL, state: StringName = &"rush_tell") -> bool:
	_sync_tier()
	if not _begin_cast(state):
		return false
	_rush_tell = tell
	_rush_cd = MAIN_RUSH_EVERY * _tempo() if _main_tier else 3.6
	_rush_hit = false
	_cast_dir = (_e.player.global_position - _cast_origin).normalized()
	if _cast_dir.is_zero_approx():
		_cast_dir = Vector2.RIGHT
	SfxManager.play_2d(&"boss_warning", _cast_origin)
	_windup = WindupSprites.new()
	var body := _e.get_node("CollisionShape2D") as CollisionShape2D
	var radius := (body.shape as CircleShape2D).radius
	# The hit is the whole body's sweep, so the lane reaches the leading edge:
	# the centre's travel plus one body radius, at the body's full width.
	_windup.setup(_cast_dir, tell, &"charge", _e.spec.charge_speed * _e.spec.charge_duration + radius, radius * 2.0)
	_windup.externally_driven = true
	AttackScope.bind(_windup, _e)
	_e.add_child(_windup)
	return true


func _physics_process(delta: float) -> void:
	_sync_tier()
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
	if _cast == &"rush" or _cast == &"breach_rush":
		_resolve_rush_contact(_rush_previous, _e.global_position)
		_rush_previous = _e.global_position
		_track_charge(0.0)
		if _cast == &"breach_rush":
			_update_breach_warning()
		if _e._charge._time_left <= 0.0:
			if _cast == &"breach_rush":
				_end_breach_rush()
			else:
				_enter_recovery()
	elif _cast != &"":
		_tick_cast(delta)
	elif _main_tier:
		_tick_main_selection(delta)
	else:
		_tick_teaching_selection(delta)


func _resolve_rush_contact(from: Vector2, to: Vector2) -> void:
	if _rush_hit or not is_instance_valid(_e.player):
		return
	# The drawn lane starts at the body's centre and runs forward along the
	# committed direction: a player behind that line (touching the boss's
	# back) is outside it, and a body charging away never strikes them.
	if (_e.player.global_position - from).dot(_cast_dir) < 0.0:
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

		# The stop is cosmetic: a small skid ripple, never the slam's art at a
		# damage-sized radius, and its thud sits under real impacts.
		var body := _e.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var reach := (body.shape as CircleShape2D).radius * 1.5 if body != null and body.shape is CircleShape2D else 60.0
		_spawn_wave(_e.global_position, reach, &"skid")
		return

func _do_slam() -> void:
	if not _begin_cast(&"slam"):
		return
	SfxManager.play_2d(&"boss_warning", _cast_origin)
	_add_warning(_cast_origin, slam_radius, maxf(0.05, slam_windup), &"slam")
	_show_windup(&"slam", slam_windup)

func _do_shockwave() -> void:
	if not _begin_cast(&"shock"):
		_followup_dir = Vector2.ZERO
		return
	SfxManager.play_2d(&"boss_warning", _cast_origin)
	_cast_dir = (_e.player.global_position - _cast_origin).normalized()
	if _cast_dir == Vector2.ZERO:
		_cast_dir = Vector2.RIGHT
	_shock_index = 0
	_show_windup(&"shock", shockwave_windup)
	# Every node, the follow-up line's too, is previewed before the first.
	for index in range(_fault_node_count()):
		_add_warning(_fault_node_position(index), shockwave_radius, _fault_node_time(index), &"shock")

func _begin_cast(kind: StringName) -> bool:
	_sync_tier()
	if _scope == null or not _scope.is_active() or _is_busy():
		return false
	_cast = kind
	_cast_elapsed = 0.0
	_cast_origin = _e.global_position
	_e.set_meta(&"boss_cast_locked", true)
	_set_teaching_state(kind)
	return true

func _shock_time(index: int) -> float:
	return maxf(0.05, shockwave_windup) + TEACHING_SHOCK_INTERVAL * float(index)


## The Fault Line's nodes in release order: its own line, then (main boss,
## phase 3) a follow-up line turned from it, starting FOLLOWUP_GAP later.
func _fault_node_count() -> int:
	return maxi(1, shockwave_waves) * (1 if _followup_dir.is_zero_approx() else 2)


func _fault_node_time(index: int, count: int = -1) -> float:
	var line := maxi(1, shockwave_waves) if count < 0 else count
	if index < line:
		return _shock_time(index)
	return _shock_time(line - 1) + FOLLOWUP_GAP + TEACHING_SHOCK_INTERVAL * float(index - line)


func _fault_node_position(index: int) -> Vector2:
	var line := maxi(1, shockwave_waves)
	var direction := _cast_dir if index < line else _followup_dir
	return _cast_origin + direction * shockwave_spacing * float(index % line + 1)

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
		if _cast_elapsed >= _recovery_seconds:
			_cancel_cast()
		return
	if _scope == null or not _scope.is_active():
		_cancel_cast()
		return
	_cast_elapsed += delta
	_update_teaching_anticipation()
	if _cast == &"rush_tell" or _cast == &"breach_tell":
		# Knockback can earn an interruption, never a relocated or teleported
		# rush whose real start disagrees with its committed lane.
		if _e.global_position.distance_to(_cast_origin) > 2.0:
			_cancel_cast()
		elif _cast_elapsed >= _rush_tell:
			if is_instance_valid(_windup):
				_windup.cancel_attack()
			_windup = null
			_cast = &"breach_rush" if _cast == &"breach_tell" else &"rush"
			_cast_elapsed = 0.0
			_rush_previous = _e.global_position
			_e.set_meta(&"boss_cast_locked", false)
			_set_teaching_state(_cast)
			_e._charge.begin_committed(_cast_dir, _e.spec.charge_duration, _e.spec.charge_speed)
			_track_charge(0.0)
	elif _cast == &"phase_shift":
		if _cast_elapsed >= PHASE_SHIFT_SECONDS:
			_cancel_cast()
	elif _cast == &"cleave":
		if _cast_elapsed >= CLEAVE_TELL:
			var strike := SectorStrike.new()
			strike.setup(_cast_origin, _cast_dir.angle(), CLEAVE_RADIUS, CLEAVE_HALF_ANGLE, CLEAVE_DAMAGE, CLEAVE_LIFE, _e)
			AttackScope.bind(strike, _e)
			get_tree().current_scene.add_child(strike)
			SfxManager.play_2d_limited(&"boss_slam_impact", _cast_origin + _cast_dir * CLEAVE_RADIUS * 0.5, 120)
			_enter_recovery(maxf(0.0, _cast_elapsed - CLEAVE_TELL), CLEAVE_RECOVERY)
	elif _cast == &"breach_beat":
		_update_breach_warning(BREACH_RUSH_TELL + _e.spec.charge_duration + _cast_elapsed)
		if _cast_elapsed >= BREACH_BEAT:
			if is_instance_valid(_breach_warning):
				_breach_warning.queue_free()
			_breach_warning = null
			_spawn_wave(_breach_target, BREACH_IMPACT_RADIUS, &"slam")
			_spawn_damage_circle(_breach_target, BREACH_IMPACT_RADIUS, slam_damage, 0.18, &"slam")
			_enter_recovery(maxf(0.0, _cast_elapsed - BREACH_BEAT), BREACH_RECOVERY)
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
		_enter_recovery(maxf(0.0, _cast_elapsed - maxf(0.05, slam_windup)))
	elif _cast == &"shock":
		var nodes := _fault_node_count()
		while _shock_index < nodes and _cast_elapsed >= _fault_node_time(_shock_index):
			var pos := _fault_node_position(_shock_index)
			_spawn_wave(pos, shockwave_radius, &"shock")
			_spawn_damage_circle(pos, shockwave_radius, shockwave_damage, 0.16, &"shock")
			if _shock_index < _warnings.size() and is_instance_valid(_warnings[_shock_index]):
				_warnings[_shock_index].queue_free()
			_shock_index += 1
		if _shock_index >= nodes:
			_enter_recovery(maxf(0.0, _cast_elapsed - _fault_node_time(_shock_index - 1)))


func _update_teaching_anticipation() -> void:
	var tell := _rush_tell
	if _cast == &"slam":
		tell = maxf(0.05, slam_windup)
	elif _cast == &"shock":
		tell = maxf(0.05, shockwave_windup)
	elif _cast == &"summon":
		tell = TEACHING_CALL_TELL
	elif _cast == &"cleave":
		tell = CLEAVE_TELL
	elif _cast == &"phase_shift":
		tell = PHASE_SHIFT_SECONDS
	if is_instance_valid(_windup):
		_windup.call("set_progress", _cast_elapsed / tell)
	for index in range(_warnings.size()):
		var warning := _warnings[index]
		if is_instance_valid(warning) and not warning.is_queued_for_deletion():
			var release_at := _fault_node_time(index) if _cast == &"shock" else tell
			warning.call("set_progress", _cast_elapsed / release_at)
	if _cast == &"breach_tell":
		_update_breach_warning(_cast_elapsed)


func _clear_cast_art() -> void:
	for warning in _warnings:
		if is_instance_valid(warning):
			warning.queue_free()
	_warnings.clear()
	if is_instance_valid(_breach_warning):
		_breach_warning.queue_free()
	_breach_warning = null
	_followup_dir = Vector2.ZERO
	for cue in _arrival_cues:
		if is_instance_valid(cue):
			cue.call("cancel_attack")
	_arrival_cues.clear()
	_arrival_positions.clear()
	if is_instance_valid(_windup):
		_windup.cancel_attack()
	_windup = null


func _enter_recovery(overshoot: float = 0.0, seconds: float = TEACHING_RECOVERY) -> void:
	_clear_cast_art()
	_cast = &"recovery"
	_cast_elapsed = overshoot
	_recovery_seconds = seconds
	_recovery_generation = _scope.generation
	_e._charge.cancel()
	_e.set_meta(&"boss_cast_locked", true)
	_set_teaching_state(&"recovery")
	_stop_trail()

func _add_warning(pos: Vector2, radius: float, duration: float, kind: StringName = &"generic") -> void:
	var warning: Node2D = GroundWarning.new()
	warning.call("set_attack_style", kind)
	# The controller drives every warning's progress on the gameplay clock.
	warning.call("setup", pos, radius, 0.0)
	AttackScope.bind(warning, _e)
	get_tree().current_scene.add_child(warning)
	_warnings.append(warning)

func _show_windup(kind: StringName, duration: float) -> void:
	if is_instance_valid(_windup):
		_windup.queue_free()
	_windup = WindupSprites.new()
	_windup.setup(_e.player.global_position - _e.global_position, duration, kind)
	_windup.externally_driven = true
	AttackScope.bind(_windup, _e)
	_e.add_child(_windup)

func _interrupt_cast() -> void:
	if _cast == &"recovery" and _scope != null and _scope.owner_available() and _scope.generation == _recovery_generation:
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

## Both tiers call Runners only as one warned, finite arrival: S5 once below
## half health, the main boss once on entering phase 2.
func _summon_blockers() -> void:
	_sync_tier()
	_begin_teaching_call()


func _begin_teaching_call() -> void:
	if _call_consumed or blocker_scene == null or (not _main_tier and _e.hp > _e.max_hp * 0.5):
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
	SfxManager.play_2d_limited(&"boss_slam_impact", pos, 120, -6.0 if kind == &"skid" else 0.0)

func _spawn_damage_circle(pos: Vector2, radius: float, dmg: float, life: float, kind: StringName = &"generic") -> void:
	if damage_circle_scene == null:
		return
	var d := damage_circle_scene.instantiate() as DamageCircle
	d.attack_style = kind
	d.setup(pos, radius, dmg, life, _e)
	AttackScope.bind(d, _e)
	get_tree().current_scene.add_child(d)
