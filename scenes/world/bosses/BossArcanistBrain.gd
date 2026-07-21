extends Node

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

var _e: Enemy

var _fan_cd: float = 1.2
var _mines_cd: float = 2.0
var _beam_cd: float = 4.5
var _pylons_cd: float = 5.0
var _blink_cd: float = 0.8

var _phase: int = 0
var _tier_is_boss: bool = false
var _tier_checked: bool = false

func _ready() -> void:
	_e = get_parent() as Enemy
	if _e == null:
		set_process(false)
		return
	_e.set_meta("boss_archetype", "mage")
	set_process(true)

func _process(delta: float) -> void:
	if _e == null or not is_instance_valid(_e) or _e.dead:
		return
	if _e.player == null or not is_instance_valid(_e.player):
		return

	if _e.has_meta("boss_returning") and bool(_e.get_meta("boss_returning")):
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

func _fan_shot() -> void:
	if projectile_scene == null:
		return
	var dir := (_e.player.global_position - _e.global_position).normalized()

	# Telegraph cone
	if cone_vfx_scene != null:
		var v := cone_vfx_scene.instantiate()
		get_tree().current_scene.add_child(v)
		if v.has_method("setup"):
			v.call("setup", _e.global_position, dir, 280.0, deg_to_rad(fan_spread_deg * 0.5), fan_telegraph,
				Color(1, 1, 1, 0.35), Color(0.78, 0.22, 1.0, 0.22))

	_call_fan(dir)

@warning_ignore("redundant_await")
func _call_fan(dir: Vector2) -> void:
	await get_tree().create_timer(maxf(0.05, fan_telegraph)).timeout
	if _e == null or not is_instance_valid(_e) or _e.dead:
		return
	var n := maxi(3, fan_projectiles)
	var half := deg_to_rad(fan_spread_deg * 0.5)
	var base := dir.angle()

	for i in range(n):
		var t := 0.0 if n == 1 else float(i) / float(n - 1)
		var a := base + lerpf(-half, half, t)
		var d := Vector2(cos(a), sin(a))

		var proj := projectile_scene.instantiate() as EnemyProjectile
		get_tree().current_scene.add_child(proj)
		proj.global_position = _e.global_position
		proj.setup(d, fan_projectile_speed, fan_projectile_damage * (1.0 + 0.25 * float(_phase)), 2.6, _e)

func _drop_mines() -> void:
	if mine_scene == null:
		return
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
		get_tree().current_scene.add_child(mine)
		mine.setup(pos, _e, mine_fuse, mine_radius, mine_damage * (1.0 + 0.20 * float(_phase)))

func _beam_sweep() -> void:
	if beam_scene == null:
		return
	var dir := (_e.player.global_position - _e.global_position).normalized()
	var base := dir.angle()

	# Sweep across a wide arc
	var a0 := base - deg_to_rad(55.0)
	var a1 := base + deg_to_rad(55.0)

	var beam := beam_scene.instantiate() as BossBeamSweep
	get_tree().current_scene.add_child(beam)
	beam.setup(_e.global_position, a0, a1, _e)
	beam.damage *= (1.0 + 0.25 * float(_phase))

func _spawn_pylons() -> void:
	if pylon_scene == null:
		return
	var center := _e.player.global_position
	for i in range(maxi(1, pylons_count)):
		var ang := TAU * float(i) / float(maxi(1, pylons_count))
		var pos := center + Vector2(cos(ang), sin(ang)) * 240.0
		var pyl := pylon_scene.instantiate() as BossPylon
		get_tree().current_scene.add_child(pyl)
		pyl.global_position = pos

func _blink() -> void:
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
	get_tree().current_scene.add_child(v)
	(v as Node2D).global_position = pos
