extends Node

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
var _trail: VFX_TrailFollow2D = null
var _trail_step_accum: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	_e = get_parent() as EnemyActor
	if _e == null:
		set_process(false)
		return
	_e.set_meta("boss_archetype", "tank")
	_last_pos = _e.global_position
	set_process(true)

func _process(delta: float) -> void:
	if _e == null or not is_instance_valid(_e) or _e.dead:
		return
	if _e.player == null or not is_instance_valid(_e.player):
		return

	if _e.has_meta("boss_returning") and bool(_e.get_meta("boss_returning")):
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

	# Track charge state to add a trail + small hazard crumbs.
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

	if _summon_cd <= 0.0 and _phase >= 1:
		_summon_cd = summon_every * lerpf(1.0, 0.75, float(_phase) / 2.0)
		_summon_blockers()

func _is_busy() -> bool:
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

		_trail = VFX_TrailFollow2D.new()
		if _trail != null:
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
		_spawn_damage_circle(_e.global_position, slam_radius * 0.55, slam_damage * 0.65, 0.12)
		return

	# While charging: lay small “crumb” hazards to sell the rush.
	if charging_now:
		var step := _e.global_position.distance_to(_last_pos)
		_last_pos = _e.global_position
		_trail_step_accum += step
		if _trail_step_accum >= 42.0:
			_trail_step_accum = 0.0
			_spawn_damage_circle(_e.global_position, 26.0, 5.0, 0.18)

func _do_slam() -> void:
	# Telegraph ring
	if vfx_ring_scene != null:
		var r := vfx_ring_scene.instantiate()
		get_tree().current_scene.add_child(r)
		if r.has_method("setup"):
			r.call("setup", _e.global_position, slam_radius)

	# Delayed hit
	_async_slam()

func _async_slam() -> void:
	# fire-and-forget coroutine
	_call_slam()

@warning_ignore("redundant_await")
func _call_slam() -> void:
	await get_tree().create_timer(maxf(0.05, slam_windup)).timeout
	if _e == null or not is_instance_valid(_e) or _e.dead:
		return
	_spawn_wave(_e.global_position, slam_radius)
	_spawn_damage_circle(_e.global_position, slam_radius, slam_damage, 0.18)

func _do_shockwave() -> void:
	var dir := (_e.player.global_position - _e.global_position).normalized()
	_call_shock(dir)

@warning_ignore("redundant_await")
func _call_shock(dir: Vector2) -> void:
	for i in range(maxi(1, shockwave_waves)):
		await get_tree().create_timer(0.12 * float(i)).timeout
		if _e == null or not is_instance_valid(_e) or _e.dead:
			return
		var p := _e.global_position + dir * shockwave_spacing * float(i + 1)
		_spawn_wave(p, shockwave_radius)
		_spawn_damage_circle(p, shockwave_radius, shockwave_damage, 0.16)

func _summon_blockers() -> void:
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
		var current_scene: Node = get_tree().current_scene
		if current_scene == null:
			blocker.free()
			_release_boss_add_reservation(enemy_index)
			continue
		if enemy_index != null and enemy_index.has_method("commit_special"):
			enemy_index.call("commit_special", blocker, &"boss_add")
		current_scene.add_child(blocker)


func _release_boss_add_reservation(enemy_index: Node) -> void:
	if enemy_index != null and enemy_index.has_method("release_special"):
		enemy_index.call("release_special", &"boss_add", 1)

func _spawn_wave(pos: Vector2, radius: float) -> void:
	if vfx_wave_scene == null:
		return
	var v := vfx_wave_scene.instantiate()
	get_tree().current_scene.add_child(v)
	if v.has_method("setup"):
		v.call("setup", pos, radius)

func _spawn_damage_circle(pos: Vector2, radius: float, dmg: float, life: float) -> void:
	if damage_circle_scene == null:
		return
	var d := damage_circle_scene.instantiate() as DamageCircle
	get_tree().current_scene.add_child(d)
	d.setup(pos, radius, dmg, life, _e)
