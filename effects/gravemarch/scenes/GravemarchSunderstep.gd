extends SetEffectBase
class_name GravemarchSunderstep

@export var base_cd: float = 1.45
@export var min_cd: float = 0.40

@export var radius: float = 170.0
@export var dmg_mult: float = 0.95
@export var knockback: float = 520.0
@export var stun_time: float = 0.11

@export var vfx_shockwave_scene: PackedScene

var _cd := 0.0

func _init() -> void:
	effect_id = &"gravemarch_4_sunderstep"

func _ready() -> void:
	RunEvents.weapon_fired.connect(_on_weapon_fired)

func _exit_tree() -> void:
	if RunEvents.weapon_fired.is_connected(_on_weapon_fired):
		RunEvents.weapon_fired.disconnect(_on_weapon_fired)

func _process(dt: float) -> void:
	_cd = maxf(_cd - dt, 0.0)

func _on_weapon_fired(p: Node, _style: StringName, _origin: Vector2, _target: Vector2, power_mul: float, haste_mul: float) -> void:
	if p != player:
		return
	if _cd > 0.0:
		return

	_cd = maxf(min_cd, base_cd / maxf(haste_mul, 0.05))

	var p2 := player as Node2D
	if p2 == null:
		return

	var center := p2.global_position
	var r := radius * (0.92 + 0.18 * set_strength)
	_spawn_wave(center, r)

	var base := _get_player_base_damage()
	var dmg := base * dmg_mult * power_mul * set_strength
	var handles: Array[int] = []
	EnemyCombat.gather_in_radius(center, r, handles)
	for handle in handles:
		var hit_position := EnemyCombat.position_for_handle(handle)
		EnemyCombat.apply_damage(handle, dmg, 1, player)
		var direction := hit_position - center
		if direction.length_squared() > 0.001:
			EnemyCombat.apply_knockback(
				handle,
				direction.normalized() * knockback * (0.85 + 0.25 * set_strength),
			)
		EnemyCombat.apply_stun(handle, stun_time * (0.85 + 0.20 * set_strength))

func _get_player_base_damage() -> float:
	if player != null:
		var v = player.get("base_weapon_damage")
		if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
			return float(v)
	return 12.0

func _spawn_wave(pos: Vector2, r: float) -> void:
	if vfx_shockwave_scene == null:
		return
	var vfx := vfx_shockwave_scene.instantiate()
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
