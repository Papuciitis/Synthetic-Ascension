extends SetEffectBase
class_name LatticeAfterstrike

@export var base_cd: float = 1.15
@export var min_cd: float = 0.25
@export var delay: float = 0.34

@export var radius: float = 155.0
@export var dmg_mult: float = 0.75
@export var knockback: float = 320.0

@export var vfx_pulse_ring_scene: PackedScene

var _cd := 0.0
var _pending: Array[Dictionary] = [] # [{ t: float, pos: Vector2, power: float, style: StringName }]

func _init() -> void:
	effect_id = &"lattice_4_afterstrike"

func _ready() -> void:
	RunEvents.weapon_fired.connect(_on_weapon_fired)

func _exit_tree() -> void:
	if RunEvents.weapon_fired.is_connected(_on_weapon_fired):
		RunEvents.weapon_fired.disconnect(_on_weapon_fired)

func _process(dt: float) -> void:
	_cd = maxf(_cd - dt, 0.0)

	for i in range(_pending.size() - 1, -1, -1):
		_pending[i].t -= dt
		if _pending[i].t <= 0.0:
			_detonate(_pending[i].pos, float(_pending[i].power))
			_pending.remove_at(i)

func _on_weapon_fired(p: Node, style_id: StringName, _origin: Vector2, target: Vector2, power_mul: float, haste_mul: float) -> void:
	if p != player:
		return
	if _cd > 0.0:
		return

	_cd = maxf(min_cd, base_cd / maxf(haste_mul, 0.05))

	# Slightly different feel per style: melee detonates closer to player (less whiff).
	var pos := target
	if style_id == &"melee":
		var p2 := player as Node2D
		if p2 != null:
			pos = p2.global_position.lerp(target, 0.55)

	_pending.append({ "t": delay, "pos": pos, "power": power_mul })

func _detonate(pos: Vector2, power_mul: float) -> void:
	_spawn_pulse(pos, radius * (0.90 + 0.15 * set_strength))

	var base := _get_player_base_damage()
	var dmg := base * dmg_mult * power_mul * set_strength
	var r := radius * (0.90 + 0.15 * set_strength)
	var targets: Array[int] = []
	EnemyCombat.gather_in_radius(pos, r, targets)
	for handle in targets:
		var hit_position := EnemyCombat.position_for_handle(handle)
		EnemyCombat.apply_damage(handle, dmg, 1, player)
		var direction := hit_position - pos
		if direction.length_squared() > 0.001:
			EnemyCombat.apply_knockback(
				handle,
				direction.normalized() * knockback * (0.85 + 0.25 * set_strength),
			)

func _get_player_base_damage() -> float:
	if player != null:
		var v = player.get("base_weapon_damage")
		if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
			return float(v)
	return 12.0

func _spawn_pulse(pos: Vector2, r: float) -> void:
	if vfx_pulse_ring_scene == null:
		return
	var vfx := vfx_pulse_ring_scene.instantiate()
	var n2 := vfx as Node2D
	if n2 == null:
		if vfx != null:
			vfx.queue_free()
		return
	get_tree().current_scene.add_child(n2)
	if n2.has_method("setup"):
		n2.call("setup", pos, r)
	else:
		n2.global_position = pos
	if n2.has_method("play"):
		n2.call("play")
