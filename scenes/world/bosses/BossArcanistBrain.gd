extends Node

const AttackScope = preload("res://scenes/world/bosses/BossAttackScope.gd")
const WindupSprites = preload("res://scenes/world/bosses/BossWindupSprites.gd")
const TeachingPlacement = preload("res://scenes/world/bosses/BossTeachingPlacement.gd")
const ArrivalSprites = preload("res://scenes/world/bosses/BossArrivalSprites.gd")
const GroundWarning = preload("res://scenes/world/bosses/BossGroundWarning.gd")
const FAN_RAY = preload("res://scenes/world/bosses/art/vfx/arcane_beam_body.tres")
const BossPhases = preload("res://scenes/world/bosses/BossPhases.gd")
const Oracle = preload("res://scenes/world/bosses/BossEscapeOracle.gd")
## The S5 fan's warned reach: five bolts at 320 px/s for 1.625 s.
const TEACHING_FAN_RANGE := 520.0
const FAN_BOLT_RADIUS := 5.0 # EnemyProjectile's collision circle

## Main boss (S10, boss overhaul proposal steps 5-6). Phase 1 keeps the S5
## vocabulary (focused fan, announced blink, mine constellation) on shorter
## neutral gaps. Phase 2 (65%) adds the Split Fan, the rebuilt Arc Sweep and
## one Pylon Pair; phase 3 (30%) the Convergence Sequence, a four-node mine
## arc and a fresh Pylon Pair. Pylons hold fire through major patterns, and
## every pattern must keep a walk out at baseline speed (BossEscapeOracle).
const MAIN_FAN_EVERY := 2.6
const MAIN_MINES_EVERY := 4.6
const MAIN_BLINK_EVERY := 5.5
const MAIN_SPLIT_EVERY := 4.2
const MAIN_SWEEP_EVERY := 6.5
const MAIN_CONVERGENCE_EVERY := 8.5
const MAIN_PHASE_TEMPO: Array[float] = [1.0, 0.9, 0.8]
const PHASE_SHIFT_SECONDS := 0.8
const SELECTION_RETRY := 0.2
## Clear space after each pattern has fully resolved (scaled by tempo): the
## Pylon Pair fires here rather than over a pattern, and the player resets.
const MAIN_NEUTRAL_SECONDS := 0.8
const SPLIT_TELL := 1.1
const SPLIT_SPEED := 300.0
const SPLIT_LIFE := 1.75
const SPLIT_BOLTS := 13 # every 8 degrees, 48 either side of the aim...
const SPLIT_STEP := 0.13962634
const SPLIT_GAP_HALF := 0.19198622 # ...less those within 11 degrees of a
const SPLIT_GAP_OFFSET := 0.41887902 # line 24 degrees off the aim: the gap
const SWEEP_TELL := 1.1
const SWEEP_TIME := 1.6
const SWEEP_HALF_ARC := 0.61086524 # 70 degrees in all
const SWEEP_LENGTH := 520.0
const SWEEP_WIDTH := 34.0
const SWEEP_RECOVERY := 1.0
const CONVERGENCE_BEAM_DELAY := 1.0
const CONVERGENCE_RECOVERY := 1.2
const PYLON_RING := 240.0
const MAIN_PYLON_LIFE := 14.0
const MAJOR_STATES: Array[StringName] = [&"fan", &"mines", &"split", &"sweep", &"convergence_fan", &"convergence_beam"]

@export_group("Fan Shot")
@export var fan_every: float = 2.8
@export var fan_telegraph: float = 0.22
@export var fan_projectiles: int = 9
@export var fan_spread_deg: float = 46.0
@export var fan_projectile_speed: float = 420.0
@export var fan_projectile_damage: float = 7.0

@export_group("Mines")
@export var mines_every: float = 4.8
@export var mines_count: int = 3
@export var mine_fuse: float = 1.05
@export var mine_radius: float = 95.0
@export var mine_damage: float = 15.0
@export var mine_scene: PackedScene = preload("res://scenes/world/bosses/BossMine.tscn")

@export_group("Beam Sweep (Boss tier)")
@export var beam_every: float = 7.2
@export var beam_scene: PackedScene = preload("res://scenes/world/bosses/BossBeamSweep.tscn")

@export_group("Pylons (Boss tier)")
@export var pylons_every: float = 9.0
@export var pylons_count: int = 2
@export var pylon_scene: PackedScene = preload("res://scenes/world/bosses/BossPylon.tscn")

@export_group("Mobility")
@export var blink_every: float = 4.0
@export var blink_min_dist: float = 160.0
@export var blink_target_radius: float = 320.0
@export var blink_attempts: int = 10
@export var blink_vfx_scene: PackedScene = preload("res://assets/vfx/world/augments/VFX_HexBlinkBurst.tscn")

@export_group("Telegraphs / Projectiles")
@export var cone_vfx_scene: PackedScene = preload("res://assets/vfx/world/enemies/VFX_EnemyShootCone.tscn")
@export var projectile_scene: PackedScene = preload("res://core/combat/projectile/EnemyProjectile.tscn")

var _e: EnemyActor

var _fan_cd: float = 1.2
var _mines_cd: float = 2.0
var _beam_cd: float = 4.5
var _pylons_cd: float = 5.0
var _blink_cd: float = 0.8

var _phase: int = 0
var _tier_is_boss: bool = false
var _tier_checked: bool = false
var _scope: Node
var _cast_left := 0.0
var _cast_kind: StringName = &""
var _fan_origin := Vector2.ZERO
var _fan_dir := Vector2.RIGHT
var _fan_phase := 0
var _fan_warning: Node
var _channel: Node
var _pylons: Array[WeakRef] = []
var _windup: Node2D
var _teaching_initialized := false
var _teaching_state: StringName = &"idle"
var _teaching_left := 0.0
var _teaching_duration := 0.0
var _recovery_generation := -1
var _teaching_counter := 0
var _teaching_markers: Array[Node2D] = []
var _teaching_pressure: Array[WeakRef] = []
var _teaching_destination := Vector2.ZERO
var _teaching_mine_center := Vector2.ZERO
var _teaching_mine_points := PackedVector2Array()
var _teaching_escape := Vector2.RIGHT
var _neutral_left := 1.0
var _neutral_distance := 0.0
var _neutral_last := Vector2.ZERO
## Main boss state: phases only advance, so their once-only Pylon Pairs can
## never be farmed by return healing.
var _boss_phase := 0
var _pylons_pending := false
var _split_cd := 1.5
var _sweep_cd := 2.5
var _convergence_cd := 2.0
var _selection_hold := 0.0
var _last_pattern: StringName = &""
var _split_dir := Vector2.RIGHT
var _split_side := 1.0
var _sweep_from := 0.0

func _ready() -> void:
	_e = get_parent() as EnemyActor
	if _e == null:
		set_process(false)
		return
	_e.set_meta("boss_archetype", "mage")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_scope = AttackScope.new()
	add_child(_scope)
	_scope.setup(_e)
	_scope.cast_interrupted.connect(_cancel_cast)
	set_process(true)

## The legacy timer kit only drives an Arcanist outside both arenas (test
## and developer spawns); both arena tiers run the committed controller.
func _process(delta: float) -> void:
	if _is_teaching() or _is_main():
		return
	if get_tree().paused:
		return
	if _scope == null or not _scope.is_active():
		_cancel_cast()
		return
	if _e.player == null or not is_instance_valid(_e.player):
		return

	if _cast_kind != &"":
		_cast_left -= delta
		if _cast_left <= 0.0:
			if _cast_kind == &"fan":
				_release_fan()
			_cancel_cast()
		return

	# Tier check (groups are applied by the Arena right after spawn)
	if not _tier_checked:
		_tier_is_boss = _e.is_in_group("boss")
		_tier_checked = true

	# Phase logic
	var hp_ratio := 1.0
	if _e.max_hp > 0.0:
		hp_ratio = clampf(_e.hp / _e.max_hp, 0.0, 1.0)

	_phase = 0
	if hp_ratio <= 0.50:
		_phase = 1
	if hp_ratio <= 0.25:
		_phase = 2

	var cd_mul := 1.0
	if _phase == 1:
		cd_mul = 0.78
	elif _phase == 2:
		cd_mul = 0.62

	_fan_cd = maxf(_fan_cd - delta, 0.0)
	_mines_cd = maxf(_mines_cd - delta, 0.0)
	_beam_cd = maxf(_beam_cd - delta, 0.0)
	_pylons_cd = maxf(_pylons_cd - delta, 0.0)
	_blink_cd = maxf(_blink_cd - delta, 0.0)

	var dist := _e.global_position.distance_to(_e.player.global_position)

	# Blink if player is too close (keeps “mage” identity).
	if dist <= blink_min_dist and _blink_cd <= 0.0:
		_blink_cd = blink_every * cd_mul
		_blink()
		return

	# Mines
	if _mines_cd <= 0.0:
		_mines_cd = mines_every * cd_mul
		_drop_mines()
		return

	# Fan shot
	if _fan_cd <= 0.0 and dist <= 720.0:
		_fan_cd = fan_every * cd_mul
		_fan_shot()
		return

	# Boss-only: beam + pylons as arena pressure
	if _tier_is_boss:
		if _beam_cd <= 0.0:
			_beam_cd = beam_every * cd_mul
			_beam_sweep()
			return
		if _pylons_cd <= 0.0 and _phase >= 1:
			_pylons_cd = pylons_every * cd_mul
			_spawn_pylons()

func _physics_process(delta: float) -> void:
	if _is_teaching() or _is_main():
		_tick_teaching(delta)

func _tick_teaching(delta: float) -> void:
	# Walking, commitments and recovery spend the same gameplay time even
	# when capped physics catch-up slows the world during a long frame.
	if get_tree().paused:
		return
	if _scope == null or not _scope.is_active():
		_cancel_cast()
		return
	if _e.player == null or not is_instance_valid(_e.player):
		return
	_ensure_teaching()
	_process_teaching(maxf(0.0, delta))

func _fan_shot() -> void:
	if _is_teaching() or _is_main():
		_ensure_teaching()
		_start_teaching_fan()
		return
	if projectile_scene == null or not _begin_cast(&"fan", maxf(0.05, fan_telegraph)):
		return
	_fan_origin = _e.global_position
	_fan_dir = (_e.player.global_position - _fan_origin).normalized()
	_fan_phase = _phase
	SfxManager.play_2d(&"boss_cast_warning", _fan_origin)
	_show_windup(&"fan", maxf(0.05, fan_telegraph), _fan_dir)

	# Telegraph cone
	if cone_vfx_scene != null:
		var v := cone_vfx_scene.instantiate()
		if v is VFX_EnemyShootCone:
			v.hold_until_release = true
		if v is Node2D:
			v.top_level = true
		if v.has_method("setup"):
			v.call("setup", _fan_origin, _fan_dir, 280.0, deg_to_rad(fan_spread_deg * 0.5), fan_telegraph,
				Color(1, 1, 1, 0.35), Color(0.78, 0.22, 1.0, 0.22))
		AttackScope.bind(v, _e)
		get_tree().current_scene.add_child(v)
		_fan_warning = v

func _release_fan() -> void:
	var teaching := _is_teaching()
	# Both arena tiers fire the compact, fully warned five-bolt fan.
	var compact := teaching or _is_main()
	var n := 5 if compact else maxi(3, fan_projectiles)
	var half := deg_to_rad(23.0 if compact else fan_spread_deg * 0.5)
	var base := _fan_dir.angle()

	for i in range(n):
		var t := 0.0 if n == 1 else float(i) / float(n - 1)
		var a := base + lerpf(-half, half, t)
		var d := Vector2(cos(a), sin(a))

		var proj := projectile_scene.instantiate() as EnemyProjectile
		var world := get_tree().current_scene
		proj.position = world.to_local(_fan_origin) if world is Node2D else _fan_origin
		proj.setup(d, 320.0 if compact else fan_projectile_speed, fan_projectile_damage * (1.0 if teaching else (1.0 + 0.25 * float(_fan_phase))), 1.625 if compact else 2.6, _e)
		AttackScope.bind(proj, _e)
		_register_teaching_pressure(proj)
		get_tree().current_scene.add_child(proj)

func _begin_cast(kind: StringName, duration: float) -> bool:
	if _scope == null or not _scope.is_active() or _cast_kind != &"":
		return false
	_cast_kind = kind
	_cast_left = duration
	_e.set_meta(&"boss_cast_locked", true)
	return true

func _cancel_cast() -> void:
	# Stun pauses an already-open recovery; it must not remove its remaining
	# melee opportunity. Full cancellation changes generation and still clears
	# the lock, including cancellation while the actor happens to be stunned.
	var preserve_recovery: bool = _teaching_initialized and _teaching_state == &"recovery" and is_instance_valid(_e) and _e.stun_time > 0.0 and _scope != null and _scope.owner_available() and int(_scope.generation) == _recovery_generation
	if _teaching_initialized:
		_clear_teaching_markers()
		if not preserve_recovery:
			_teaching_state = &"idle"
			_teaching_left = 0.0
			_e.set_meta(&"boss_teaching_state", &"idle")
	_cast_kind = &""
	_cast_left = 0.0
	if is_instance_valid(_fan_warning):
		_fan_warning.queue_free()
	_fan_warning = null
	if is_instance_valid(_channel):
		_channel.queue_free()
	_channel = null
	if is_instance_valid(_windup):
		_windup.cancel_attack()
	_windup = null
	if is_instance_valid(_e):
		_e.set_meta(&"boss_cast_locked", preserve_recovery)

func _drop_mines() -> void:
	if _is_teaching() or _is_main():
		_ensure_teaching()
		_start_teaching_mines(4 if _is_main() and _boss_phase >= 2 else 3)
		return
	if mine_scene == null:
		return
	_show_windup(&"mine", 0.35, _e.player.global_position - _e.global_position)
	var p := _e.player.global_position
	var count := mines_count + (_phase)  # more mines in later phases
	count = clampi(count, 2, 6)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_msec()) ^ int(_e.get_instance_id())

	for i in range(count):
		var ang := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(90.0, 210.0)
		var pos := p + Vector2(cos(ang), sin(ang)) * r

		var mine := mine_scene.instantiate() as BossMine
		mine.setup(pos, _e, mine_fuse, mine_radius, mine_damage * (1.0 + 0.20 * float(_phase)))
		AttackScope.bind(mine, _e)
		get_tree().current_scene.add_child(mine)

func _beam_sweep() -> void:
	# The arena tiers never use this legacy beam: S5 has none, and the main
	# boss's announced sweep is _start_sweep.
	if _is_teaching() or _is_main():
		return
	if beam_scene == null or _cast_kind != &"":
		return
	var dir := (_e.player.global_position - _e.global_position).normalized()
	var base := dir.angle()

	# Sweep across a wide arc
	var a0 := base - deg_to_rad(55.0)
	var a1 := base + deg_to_rad(55.0)

	var beam := beam_scene.instantiate() as BossBeamSweep
	beam.setup(_e.global_position, a0, a1, _e)
	beam.damage *= (1.0 + 0.25 * float(_phase))
	if not _begin_cast(&"beam", beam.telegraph_time + beam.sweep_time):
		beam.free()
		return
	AttackScope.bind(beam, _e)
	get_tree().current_scene.add_child(beam)
	_channel = beam
	_show_windup(&"beam", beam.telegraph_time, dir)

func _show_windup(kind: StringName, duration: float, direction: Vector2) -> void:
	if is_instance_valid(_windup):
		_windup.cancel_attack()
	_windup = WindupSprites.new()
	_windup.setup(direction, duration, kind)
	AttackScope.bind(_windup, _e)
	_e.add_child(_windup)

func _spawn_pylons() -> void:
	# The main boss raises its pairs per phase (_spawn_main_pylons).
	if _is_teaching() or _is_main():
		return
	if pylon_scene == null:
		return
	_pylons = _pylons.filter(func(ref: WeakRef) -> bool: return is_instance_valid(ref.get_ref()) and not ref.get_ref().is_queued_for_deletion())
	var center := _e.player.global_position
	var count := mini(maxi(1, pylons_count), 2 - _pylons.size())
	for i in range(maxi(0, count)):
		var ang := TAU * float(i) / float(maxi(1, pylons_count))
		var pos := center + Vector2(cos(ang), sin(ang)) * 240.0
		var pyl := pylon_scene.instantiate() as BossPylon
		pyl.call("setup", pos, _e, 12.0)
		AttackScope.bind(pyl, _e)
		get_tree().current_scene.add_child(pyl)
		_pylons.append(weakref(pyl))

func _blink() -> void:
	if _is_teaching() or _is_main():
		_ensure_teaching()
		_start_teaching_blink()
		return
	var old := _e.global_position
	_spawn_blink_vfx(old)

	var player_pos := _e.player.global_position
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_msec()) ^ int(_e.get_instance_id())

	var best := old
	for i in range(maxi(1, blink_attempts)):
		var ang := rng.randf_range(0.0, TAU)
		var pos := player_pos + Vector2(cos(ang), sin(ang)) * blink_target_radius
		if _is_point_clear(pos):
			best = pos
			break

	_e.global_position = best
	_spawn_blink_vfx(best)

func _is_point_clear(p: Vector2) -> bool:
	# Basic collision point check using the boss' collision mask.
	var w := _e.get_world_2d()
	if w == null:
		return true
	var space := w.direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = p
	params.collision_mask = int(_e.collision_mask)
	params.collide_with_bodies = true
	params.collide_with_areas = true
	var hits := space.intersect_point(params, 1)
	return hits.is_empty()

func _spawn_blink_vfx(pos: Vector2) -> void:
	if blink_vfx_scene == null:
		return
	var v := blink_vfx_scene.instantiate()
	if v is Node2D:
		v.top_level = true
	(v as Node2D).global_position = pos
	AttackScope.bind(v, _e)
	get_tree().current_scene.add_child(v)


func _is_teaching() -> bool:
	return is_instance_valid(_e) and _e.is_in_group(&"miniboss") and not _e.is_in_group(&"boss")

func _is_main() -> bool:
	return is_instance_valid(_e) and _e.is_in_group(&"boss")

func main_phase() -> int:
	return _boss_phase

func _ensure_teaching() -> void:
	if _teaching_initialized:
		return
	_teaching_initialized = true
	_phase = 0
	_neutral_last = _e.global_position
	_set_teaching_state(&"idle", 0.0)

func _set_teaching_state(kind: StringName, seconds: float) -> void:
	_teaching_state = kind
	_teaching_left = maxf(seconds, 0.0)
	_teaching_duration = _teaching_left
	if kind == &"recovery":
		_recovery_generation = int(_scope.generation)
	_e.set_meta(&"boss_teaching_state", kind)
	_e.set_meta(&"boss_cast_locked", kind != &"idle")

func _register_teaching_pressure(node: Node) -> void:
	if _is_teaching() or _is_main():
		_teaching_pressure.append(weakref(node))

func _current_mines(owned_only: bool = false) -> Array:
	var result: Array = []
	for mine in get_tree().get_nodes_in_group(BossMine.GROUP):
		if mine is BossMine and not mine.is_queued_for_deletion() and (not owned_only or mine.source == _e):
			result.append(mine)
	return result

func _has_teaching_pressure() -> bool:
	# Runs every idle physics tick: prune in place rather than reallocating.
	for index in range(_teaching_pressure.size() - 1, -1, -1):
		var node = _teaching_pressure[index].get_ref()
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			_teaching_pressure.remove_at(index)
	return not _teaching_pressure.is_empty() or not _current_mines(true).is_empty()

func _can_start_teaching() -> bool:
	return not get_tree().paused and _scope != null and _scope.is_active() and _teaching_state == &"idle" and not _has_teaching_pressure()

func _clear_teaching_markers() -> void:
	for marker in _teaching_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_teaching_markers.clear()
	if is_instance_valid(_fan_warning):
		_fan_warning.queue_free()
	_fan_warning = null
	if is_instance_valid(_windup):
		_windup.cancel_attack()
	_windup = null

func _teaching_recovery(seconds: float) -> void:
	_clear_teaching_markers()
	_set_teaching_state(&"recovery", seconds)

func _process_teaching(delta: float) -> void:
	_fan_cd = maxf(0.0, _fan_cd - delta)
	_mines_cd = maxf(0.0, _mines_cd - delta)
	_blink_cd = maxf(0.0, _blink_cd - delta)
	_split_cd = maxf(0.0, _split_cd - delta)
	_sweep_cd = maxf(0.0, _sweep_cd - delta)
	_convergence_cd = maxf(0.0, _convergence_cd - delta)
	if _is_main():
		# Pylons hold fire through a major pattern and while it is in the air,
		# recovery included.
		_e.set_meta(&"boss_major_pattern", _teaching_state in MAJOR_STATES or _has_teaching_pressure())
	if _teaching_state != &"idle":
		_teaching_left = maxf(0.0, _teaching_left - delta)
		for marker in _teaching_markers:
			if is_instance_valid(marker):
				marker.set_progress(1.0 - _teaching_left / maxf(0.05, _teaching_duration))
		if _teaching_left > 0.0:
			return
		match _teaching_state:
			&"fan":
				_release_fan()
				_teaching_recovery(0.9)
			&"mines":
				_release_teaching_mines()
				_teaching_recovery(0.9)
			&"blink":
				if TeachingPlacement.blink_valid(_e, _e.player, _teaching_destination, _current_mines()):
					_e.global_position = _teaching_destination
					_e.call("_update_enemy_index", true)
				_teaching_recovery(1.2 if not _is_main() else 0.9)
			&"split":
				_release_split()
				_teaching_recovery(0.9)
			&"sweep":
				_teaching_recovery(SWEEP_RECOVERY)
			&"convergence_fan":
				# The split resolves; the announced sweep keeps its own clock.
				_release_split()
				_clear_teaching_markers()
				_set_teaching_state(&"convergence_beam", CONVERGENCE_BEAM_DELAY + SWEEP_TIME)
				_show_windup(&"beam", CONVERGENCE_BEAM_DELAY, Vector2.from_angle(_sweep_from))
			&"convergence_beam":
				_teaching_recovery(CONVERGENCE_RECOVERY)
			&"phase_shift", &"recovery":
				_set_teaching_state(&"idle", 0.0)
				_neutral_left = 1.0
				_neutral_distance = 0.0
				_neutral_last = _e.global_position
				if _is_main():
					_selection_hold = MAIN_NEUTRAL_SECONDS * _tempo()
		return

	# Existing ranged steering gets one bounded reposition, then the mage
	# stands its ground until the next commitment. Player damage is unaffected.
	# The budget bounds evasion near the player only: beyond the fan's reach
	# no pattern can start, so standing still would stall the fight while a
	# ranged build shoots freely. There steering may always close the distance.
	var distance := _e.global_position.distance_to(_e.player.global_position)
	_neutral_left = maxf(0.0, _neutral_left - delta)
	_neutral_distance += _e.global_position.distance_to(_neutral_last)
	_neutral_last = _e.global_position
	var budget_spent := _neutral_left <= 0.0 or _neutral_distance >= 80.0
	_e.set_meta(&"boss_cast_locked", budget_spent and distance <= TEACHING_FAN_RANGE)
	if _is_main():
		_process_main_selection(delta, distance)
		return
	if _has_teaching_pressure():
		return
	if _blink_cd <= 0.0 and distance <= blink_min_dist:
		if not _start_teaching_blink():
			_blink_cd = 1.0
		return
	if _mines_cd <= 0.0:
		if not _start_teaching_mines():
			_mines_cd = 1.0
		return
	if _fan_cd <= 0.0 and distance <= TEACHING_FAN_RANGE:
		_start_teaching_fan()

func _tempo() -> float:
	return MAIN_PHASE_TEMPO[clampi(_boss_phase, 0, MAIN_PHASE_TEMPO.size() - 1)]


func _process_main_selection(delta: float, distance: float) -> void:
	# A threshold crossed during a pattern waits for neutral (we are idle);
	# several crossed at once make one transition.
	var phase := BossPhases.phase_for(clampf(_e.hp / maxf(_e.max_hp, 0.001), 0.0, 1.0))
	if phase > _boss_phase:
		_begin_phase_shift(phase)
		return
	if _pylons_pending:
		_pylons_pending = false
		_spawn_main_pylons()
	# The neutral beat starts once the last pattern has left the field.
	if _has_teaching_pressure():
		return
	_selection_hold = maxf(0.0, _selection_hold - delta)
	if _selection_hold > 0.0:
		return
	var options: Array[StringName] = []
	if _mines_cd <= 0.0:
		options.append(&"mines")
	if _fan_cd <= 0.0 and distance <= TEACHING_FAN_RANGE:
		options.append(&"fan")
	if _boss_phase >= 1 and _split_cd <= 0.0 and distance <= SPLIT_SPEED * SPLIT_LIFE:
		options.append(&"split")
	if _boss_phase >= 1 and _sweep_cd <= 0.0 and distance <= SWEEP_LENGTH:
		options.append(&"sweep")
	if _boss_phase >= 2 and _convergence_cd <= 0.0 and distance <= SWEEP_LENGTH:
		options.append(&"convergence")
	var ordered := _ordered_patterns(options)
	# Too close: the announced blink comes first, as in S5.
	if _blink_cd <= 0.0 and distance <= blink_min_dist:
		ordered.push_front(&"blink")
	if ordered.is_empty():
		return
	for kind in ordered:
		if _try_main_pattern(kind):
			_last_pattern = kind
			return
	_selection_hold = SELECTION_RETRY


## A seeded weighted order: signature patterns are likelier, and the last
## one is not repeated while another is available.
func _ordered_patterns(options: Array[StringName]) -> Array[StringName]:
	var weights := {&"mines": 2.0, &"fan": 2.0, &"split": 3.0, &"sweep": 3.0, &"convergence": 3.5}
	var rng := _pattern_rng()
	_teaching_counter += 1
	var keyed: Array = []
	for kind in options:
		var weight: float = weights.get(kind, 1.0)
		if kind == _last_pattern and options.size() > 1:
			weight *= 0.25
		keyed.append([pow(maxf(rng.randf(), 0.0001), 1.0 / weight), kind])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var ordered: Array[StringName] = []
	for entry: Array in keyed:
		ordered.append(entry[1])
	return ordered


func _try_main_pattern(kind: StringName) -> bool:
	if _teaching_state != &"idle":
		return false
	if (kind in [&"split", &"convergence"] and projectile_scene == null) or (kind in [&"sweep", &"convergence"] and beam_scene == null):
		return false
	var origin := _e.global_position
	var aim := (_e.player.global_position - origin).normalized()
	if aim.is_zero_approx():
		aim = Vector2.RIGHT
	var rng := _pattern_rng()
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	match kind:
		&"blink":
			if not _start_teaching_blink():
				_blink_cd = 1.0
				return false
			_blink_cd = MAIN_BLINK_EVERY * _tempo()
			return true
		&"mines":
			if not _start_teaching_mines(4 if _boss_phase >= 2 else 3):
				_mines_cd = 1.0
				return false
			_mines_cd = MAIN_MINES_EVERY * _tempo()
			return true
		&"fan":
			if not _escapable(_fan_plan(origin, aim, _focused_angles(), 0.95, 320.0, 1.625)) or not _start_teaching_fan():
				return false
			_fan_cd = MAIN_FAN_EVERY * _tempo()
			_fan_phase = _boss_phase
			return true
		&"split":
			for try_side in [side, -side]:
				if _escapable(_fan_plan(origin, aim, _split_angles(try_side), SPLIT_TELL, SPLIT_SPEED, SPLIT_LIFE)):
					_start_split(aim, try_side, &"split", SPLIT_TELL)
					_split_cd = MAIN_SPLIT_EVERY * _tempo()
					return true
			return false
		&"sweep":
			for turn in [side, -side]:
				var from_angle: float = aim.angle() - turn * SWEEP_HALF_ARC
				var to_angle: float = aim.angle() + turn * SWEEP_HALF_ARC
				if _escapable([_sweep_hazard(origin, from_angle, to_angle, SWEEP_TELL)]):
					_start_sweep(from_angle, to_angle, SWEEP_TELL, &"sweep", SWEEP_TELL + SWEEP_TIME)
					_sweep_cd = MAIN_SWEEP_EVERY * _tempo()
					return true
			return false
		&"convergence":
			var beam_tell := SPLIT_TELL + CONVERGENCE_BEAM_DELAY
			for try_side in [side, -side]:
				for turn in [try_side, -try_side]:
					var from_angle: float = aim.angle() - turn * SWEEP_HALF_ARC
					var to_angle: float = aim.angle() + turn * SWEEP_HALF_ARC
					var plan := _fan_plan(origin, aim, _split_angles(try_side), SPLIT_TELL, SPLIT_SPEED, SPLIT_LIFE)
					plan.append(_sweep_hazard(origin, from_angle, to_angle, beam_tell))
					if _escapable(plan):
						_start_split(aim, try_side, &"convergence_fan", SPLIT_TELL)
						_start_sweep(from_angle, to_angle, beam_tell, &"convergence_fan", SPLIT_TELL)
						_convergence_cd = MAIN_CONVERGENCE_EVERY * _tempo()
						return true
			return false
	return false


func _focused_angles() -> Array[float]:
	var angles: Array[float] = []
	for index in range(5):
		angles.append(deg_to_rad(-23.0 + 11.5 * float(index)))
	return angles


## Thirteen lanes every 8 degrees, symmetric about the aim, less the three
## nearest a line 24 degrees to `side`: a 32-degree gap between bolt lanes.
func _split_angles(side: float) -> Array[float]:
	var angles: Array[float] = []
	for index in range(SPLIT_BOLTS):
		var angle := SPLIT_STEP * (float(index) - float(SPLIT_BOLTS - 1) * 0.5)
		if absf(angle - side * SPLIT_GAP_OFFSET) > SPLIT_GAP_HALF:
			angles.append(angle)
	return angles


func _fan_plan(origin: Vector2, aim: Vector2, angles: Array[float], tell: float, speed: float, life: float) -> Array:
	var plan: Array = []
	for angle in angles:
		plan.append({"kind": &"bolt", "origin": origin, "velocity": aim.rotated(angle) * speed, "radius": FAN_BOLT_RADIUS, "from": tell, "to": tell + life})
	return plan


func _sweep_hazard(origin: Vector2, from_angle: float, to_angle: float, tell: float) -> Dictionary:
	return {"kind": &"beam", "origin": origin, "angle_from": from_angle, "angle_to": to_angle, "length": SWEEP_LENGTH, "width": SWEEP_WIDTH, "from": tell, "to": tell + SWEEP_TIME}


func _escapable(plan: Array) -> bool:
	var player := _e.player
	var shape: Dictionary = Oracle.player_shape(player)
	var blockers := [{"center": _e.global_position, "radius": TeachingPlacement.body_radius(_e)}]
	var path_clear := func(from: Vector2, to: Vector2) -> bool:
		return TeachingPlacement.corridor_clear(_e, from, to, float(shape["body_radius"]))
	return Oracle.has_escape(player.global_position, plan, shape, blockers, path_clear)


func _begin_phase_shift(phase: int) -> void:
	_boss_phase = phase
	# One Pylon Pair per threshold reached; a skipped threshold owes only one.
	# The previous phase's pair expires with its phase.
	_expire_main_pylons()
	_pylons_pending = true
	_clear_teaching_markers()
	_set_teaching_state(&"phase_shift", PHASE_SHIFT_SECONDS)
	_show_windup(&"phase_cast", PHASE_SHIFT_SECONDS, _e.player.global_position - _e.global_position)
	SfxManager.play_2d(&"boss_intro", _e.global_position, -6.0)
	if RunEvents != null and RunEvents.has_signal(&"boss_phase_changed"):
		RunEvents.boss_phase_changed.emit(_e, phase)


func _expire_main_pylons() -> void:
	for ref in _pylons:
		var old = ref.get_ref()
		if is_instance_valid(old) and old.has_method("cancel_attack"):
			old.call("cancel_attack")
	_pylons.clear()


## The pair stands on opposite sides of the player, both in clear,
## leash-bound ground; at most two live, never replaced within a phase.
func _spawn_main_pylons() -> void:
	_expire_main_pylons()
	if pylon_scene == null:
		return
	var center := _e.player.global_position
	var first := _pattern_rng().randi_range(0, 7)
	_teaching_counter += 1
	for index in range(8):
		var direction := Vector2.RIGHT.rotated(float((first + index) % 8) * PI * 0.25)
		var points := [center + direction * PYLON_RING, center - direction * PYLON_RING]
		if not (TeachingPlacement.disc_clear(_e, points[0], 24.0) and TeachingPlacement.disc_clear(_e, points[1], 24.0)):
			continue
		for point in points:
			var pylon := pylon_scene.instantiate() as BossPylon
			pylon.call("setup", point, _e, MAIN_PYLON_LIFE)
			AttackScope.bind(pylon, _e)
			get_tree().current_scene.add_child(pylon)
			_pylons.append(weakref(pylon))
		return


func _start_split(aim: Vector2, side: float, state: StringName, tell: float) -> void:
	_fan_origin = _e.global_position
	_split_dir = aim
	_split_side = side
	_fan_phase = _boss_phase
	_teaching_counter += 1
	_set_teaching_state(state, tell)
	SfxManager.play_2d(&"boss_cast_warning", _fan_origin)
	_show_windup(&"fan", tell, aim)
	var marker := Node2D.new()
	marker.name = "SplitFanRayWarnings"
	marker.top_level = true
	marker.position = _fan_origin
	AttackScope.bind(marker, _e)
	get_tree().current_scene.add_child(marker)
	var reach := SPLIT_SPEED * SPLIT_LIFE
	var lanes := _split_angles(side)
	for index in range(lanes.size()):
		var angle := aim.angle() + lanes[index]
		var sprite := Sprite2D.new()
		sprite.name = "BoltLane%d" % index
		sprite.texture = FAN_RAY
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.position = Vector2.RIGHT.rotated(angle) * reach * 0.5
		sprite.rotation = angle
		sprite.scale = Vector2(reach / FAN_RAY.get_width(), 10.0 / FAN_RAY.get_height())
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.55)
		sprite.z_as_relative = false
		sprite.z_index = 1
		marker.add_child(sprite)
	_fan_warning = marker


func _release_split() -> void:
	if projectile_scene == null:
		return
	var world := get_tree().current_scene
	for angle in _split_angles(_split_side):
		var proj := projectile_scene.instantiate() as EnemyProjectile
		proj.position = world.to_local(_fan_origin) if world is Node2D else _fan_origin
		proj.setup(_split_dir.rotated(angle), SPLIT_SPEED, fan_projectile_damage * (1.0 + 0.25 * float(_fan_phase)), SPLIT_LIFE, _e)
		AttackScope.bind(proj, _e)
		_register_teaching_pressure(proj)
		world.add_child(proj)


## The rebuilt Arc Sweep: start and end lanes announced through the whole
## telegraph, a rooted channel on the physics clock, then recovery.
func _start_sweep(from_angle: float, to_angle: float, telegraph: float, state: StringName, state_seconds: float) -> void:
	if beam_scene == null:
		return
	var beam := beam_scene.instantiate() as BossBeamSweep
	beam.telegraph_time = telegraph
	beam.sweep_time = SWEEP_TIME
	beam.length = SWEEP_LENGTH
	beam.width = SWEEP_WIDTH
	beam.damage = 16.0 * (1.0 + 0.25 * float(_boss_phase))
	beam.physics_clock = true
	beam.preview_end_lane = true
	beam.setup(_e.global_position, from_angle, to_angle, _e)
	AttackScope.bind(beam, _e)
	get_tree().current_scene.add_child(beam)
	_channel = beam
	_sweep_from = from_angle
	if _teaching_state != state:
		_set_teaching_state(state, state_seconds)
	if state == &"sweep":
		_teaching_counter += 1
		SfxManager.play_2d(&"boss_cast_warning", _e.global_position)
		_show_windup(&"beam", telegraph, Vector2.from_angle(from_angle))


func _start_teaching_fan() -> bool:
	if projectile_scene == null or not _can_start_teaching():
		return false
	_fan_origin = _e.global_position
	_fan_dir = (_e.player.global_position - _fan_origin).normalized()
	if _fan_dir.is_zero_approx():
		_fan_dir = Vector2.RIGHT
	_fan_phase = 0
	_fan_cd = fan_every
	_teaching_counter += 1
	_set_teaching_state(&"fan", 0.95)
	SfxManager.play_2d(&"boss_cast_warning", _fan_origin)
	_show_windup(&"fan", 0.95, _fan_dir)
	var marker := Node2D.new()
	marker.name = "FocusedFanRayWarnings"
	marker.top_level = true
	marker.position = _fan_origin
	AttackScope.bind(marker, _e)
	get_tree().current_scene.add_child(marker)
	for i in range(5):
		var angle := _fan_dir.angle() + deg_to_rad(-23.0 + 11.5 * float(i))
		var sprite := Sprite2D.new()
		sprite.name = "BoltLane%d" % i
		sprite.texture = FAN_RAY
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.position = Vector2.RIGHT.rotated(angle) * 260.0
		sprite.rotation = angle
		sprite.scale = Vector2(520.0 / FAN_RAY.get_width(), 10.0 / FAN_RAY.get_height())
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.55)
		sprite.z_as_relative = false
		sprite.z_index = 1
		marker.add_child(sprite)
	_fan_warning = marker
	return true

func _pattern_rng() -> RandomNumberGenerator:
	var home: Vector2 = _e.get_meta(&"boss_home_pos", _e.global_position)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Global.attempt_world_seed) ^ int(Global.attempt_segment) * 10007 ^ floori(home.x) * 73856093 ^ floori(home.y) * 19349663 ^ _teaching_counter * 83492791
	return rng

func _start_teaching_blink() -> bool:
	if not _can_start_teaching():
		return false
	var player_pos := _e.player.global_position
	var away := (_e.global_position - player_pos).normalized()
	if away.is_zero_approx():
		away = Vector2.LEFT
	var first := _pattern_rng().randi_range(0, 7)
	var found := false
	for i in range(8):
		var candidate := player_pos + away.rotated(float((first + i) % 8) * PI * 0.25) * 195.0
		if TeachingPlacement.blink_valid(_e, _e.player, candidate, _current_mines()):
			_teaching_destination = candidate
			found = true
			break
	if not found:
		return false
	_teaching_counter += 1
	_blink_cd = 6.5
	_set_teaching_state(&"blink", 0.8)
	_show_windup(&"blink", 0.8, _teaching_destination - _e.global_position)
	SfxManager.play_2d(&"boss_cast_warning", _e.global_position)
	for point in [_e.global_position, _teaching_destination]:
		var marker := ArrivalSprites.new()
		marker.setup(point, TeachingPlacement.body_radius(_e) + 8.0, 0.8, &"blink")
		AttackScope.bind(marker, _e)
		get_tree().current_scene.add_child(marker)
		# The committed cast owns this cue's clock, including its final frame.
		marker.set_process(false)
		marker.set_physics_process(false)
		_teaching_markers.append(marker)
	return true

func _start_teaching_mines(count: int = 3) -> bool:
	if mine_scene == null or not _can_start_teaching() or _current_mines(true).size() + count > 5:
		return false
	var center := _e.player.global_position
	var away := (center - _e.global_position).normalized()
	if away.is_zero_approx():
		away = Vector2.RIGHT
	var first := _pattern_rng().randi_range(0, 3)
	var found := false
	for i in range(4):
		var escape := away.rotated(float((first + i) % 4) * PI * 0.5)
		var points := PackedVector2Array()
		# Three nodes, or the main boss's four-node arc; the escape corridor
		# along `escape` stays open either way.
		for degrees in ([60.0, 180.0, -60.0] if count <= 3 else [50.0, 130.0, -130.0, -50.0]):
			points.append(center + escape.rotated(deg_to_rad(degrees)) * 210.0)
		if TeachingPlacement.mine_pattern_valid(_e, _e.player, center, points, escape, mine_radius, _current_mines()):
			_teaching_mine_points = points
			_teaching_escape = escape
			found = true
			break
	if not found:
		return false
	_teaching_mine_center = center
	_teaching_counter += 1
	_mines_cd = mines_every
	_set_teaching_state(&"mines", 0.6)
	_show_windup(&"mine", 0.6, center - _e.global_position)
	SfxManager.play_2d(&"boss_cast_warning", _e.global_position)
	for point in _teaching_mine_points:
		var marker := GroundWarning.new()
		marker.set_attack_style(&"mine")
		marker.setup(point, mine_radius, 0.6)
		AttackScope.bind(marker, _e)
		get_tree().current_scene.add_child(marker)
		marker.set_process(false)
		marker.set_physics_process(false)
		_teaching_markers.append(marker)
	return true

func _release_teaching_mines() -> void:
	if not TeachingPlacement.mine_pattern_valid(_e, _e.player, _teaching_mine_center, _teaching_mine_points, _teaching_escape, mine_radius, _current_mines()):
		return
	for point in _teaching_mine_points:
		var mine := mine_scene.instantiate() as BossMine
		mine.setup(point, _e, 1.4, mine_radius, mine_damage * (1.0 + 0.2 * float(_boss_phase)))
		AttackScope.bind(mine, _e)
		_register_teaching_pressure(mine)
		get_tree().current_scene.add_child(mine)
