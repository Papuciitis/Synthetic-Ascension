extends Node
class_name MagicMissileEffect

@export var missile_scene: PackedScene
@export var base_cooldown: float = 0.75
@export var burst_count: int = 2
@export var burst_interval: float = 0.08
@export var seek_radius: float = 750.0
@export var damage_mult: float = 0.35
@export var scales_with_haste: bool = true
@export var scales_with_power: bool = true
@export var debug_prints: bool = false

var _player: Node2D = null
var _cd: float = 0.0
var _tick: int = 0

# Burst state (no create_timer spam)
var _burst_left: int = 0
var _burst_t: float = 0.0
var _target_handle: int = EnemyWorldTypes.INVALID_HANDLE

func setup(p: Node) -> void:
	_player = p as Node2D

func _ready() -> void:
	set_process(true)
	process_mode = Node.PROCESS_MODE_INHERIT
	if debug_prints:
		print("[MagicMissile] ready missile_scene=", missile_scene)

func _process(dt: float) -> void:
	_tick += 1

	if _player == null or not is_instance_valid(_player):
		if debug_prints and _tick % 60 == 0:
			print("[MagicMissile] no player set (setup not called?)")
		return

	if missile_scene == null:
		if debug_prints and _tick % 60 == 0:
			print("[MagicMissile] missile_scene is null (assign it in MagicMissileEffect.tscn)")
		return

	# If we are in a burst, fire the remaining shots at interval.
	if _burst_left > 0:
		_burst_t -= dt
		if _burst_t <= 0.0:
			if EnemyWorld.is_valid_handle(_target_handle) and not EnemyWorld.is_dying(_target_handle):
				_spawn_one(_target_handle)
			_burst_left -= 1
			_burst_t = burst_interval
		return

	_cd = maxf(_cd - dt, 0.0)
	if _cd > 0.0:
		return

	var handle := _find_nearest_enemy(_player.global_position, seek_radius)
	if handle == EnemyWorldTypes.INVALID_HANDLE:
		if debug_prints and _tick % 60 == 0:
			print("[MagicMissile] no enemies in radius=", seek_radius)
		return

	# cooldown scaling
	var cd: float = base_cooldown
	var st: Stats = _player.get("stats") as Stats
	if scales_with_haste and st != null:
		var haste_mul: float = 1.0 + maxf(st.haste, -0.9)
		cd = cd / maxf(haste_mul, 0.05)
	_cd = maxf(cd, 0.001)

	if debug_prints:
		print("[MagicMissile] fire handle=", handle)

	# Start burst: first shot is immediate, remaining use interval timer.
	_target_handle = handle
	_burst_left = maxi(1, burst_count)
	_burst_t = 0.0

func _spawn_one(handle: int) -> void:
	if not EnemyWorld.is_valid_handle(handle) or EnemyWorld.is_dying(handle) or missile_scene == null:
		return
	var target_position := EnemyCombat.position_for_handle(handle)

	var dmg: float = _compute_damage()

	# Spawn missile (pool if available)
	var pm := get_node_or_null("/root/PoolManager")
	var m: Node = null
	if pm != null and is_instance_valid(pm) and pm.has_method("obtain"):
		m = pm.call("obtain", missile_scene, get_tree().current_scene) as Node
	else:
		m = missile_scene.instantiate()

	var m2 := m as Node2D
	if m2 == null:
		if m != null and m.get_parent() == null:
			m.queue_free()
		return

	if m2.get_parent() == null:
		get_tree().current_scene.add_child(m2)

	m2.global_position = _player.global_position

	var start_dir: Vector2 = (target_position - _player.global_position).normalized()
	if start_dir == Vector2.ZERO:
		start_dir = Vector2.RIGHT
	start_dir = start_dir.rotated(randf_range(-0.35, 0.35))

	if m2.has_method("setup_handle"):
		m2.call("setup_handle", handle, dmg, start_dir, _player)
	elif m2.has_method("setup"):
		var actor := EnemyCombat.actor_for_handle(handle)
		if actor != null:
			m2.call("setup", actor, dmg, start_dir)

func _compute_damage() -> float:
	var base_dmg: float = 12.0
	var v: Variant = _player.get("base_weapon_damage")
	if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
		base_dmg = float(v)

	var mul: float = damage_mult
	var st: Stats = _player.get("stats") as Stats
	if scales_with_power and st != null:
		mul *= (1.0 + st.power)

	return base_dmg * mul

func _find_nearest_enemy(center: Vector2, radius: float) -> int:
	return EnemyCombat.nearest_enemy(center, radius)


const _AUG_MAX_LEVEL: int = 5
var _aug_level: int = 1
var _bases_captured_mm: bool = false

var _base_cooldown_mm: float
var _base_burst_count_mm: int
var _base_burst_interval_mm: float
var _base_seek_radius_mm: float
var _base_damage_mult_mm: float

func _enter_tree() -> void:
	_capture_level_bases_mm()

func set_level(level: int) -> void:
	_aug_level = clampi(level, 1, _AUG_MAX_LEVEL)
	_capture_level_bases_mm()
	_apply_level_scaling_mm()

func _capture_level_bases_mm() -> void:
	if _bases_captured_mm:
		return
	_bases_captured_mm = true

	_base_cooldown_mm = base_cooldown
	_base_burst_count_mm = burst_count
	_base_burst_interval_mm = burst_interval
	_base_seek_radius_mm = seek_radius
	_base_damage_mult_mm = damage_mult

func _apply_level_scaling_mm() -> void:
	var t: int = _aug_level - 1
	if t <= 0:
		base_cooldown = _base_cooldown_mm
		burst_count = _base_burst_count_mm
		burst_interval = _base_burst_interval_mm
		seek_radius = _base_seek_radius_mm
		damage_mult = _base_damage_mult_mm
		return

	base_cooldown = maxf(0.35, _base_cooldown_mm * pow(0.93, float(t)))
	burst_count = maxi(1, _base_burst_count_mm + int(floor(float(t) / 2.0)))
	burst_interval = maxf(0.04, _base_burst_interval_mm * pow(0.96, float(t)))

	seek_radius = _base_seek_radius_mm * (1.0 + 0.05 * float(t))
	damage_mult = _base_damage_mult_mm * (1.0 + 0.12 * float(t))
