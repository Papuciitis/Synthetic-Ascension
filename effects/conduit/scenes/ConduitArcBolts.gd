extends SetEffectBase
class_name ConduitArcBolts

@export var base_cd: float = 1.25
@export var min_cd: float = 0.25
@export var radius: float = 260.0
@export var chain_radius: float = 180.0
@export var dmg1_mult: float = 0.55
@export var dmg2_mult: float = 0.35
@export var debug_proc_logging: bool = false

@export var vfx_arc_line_scene: PackedScene

var _cd := 0.0

func _init() -> void:
	effect_id = &"conduit_4_arc_bolts"

func _ready() -> void:
	RunEvents.weapon_fired.connect(_on_weapon_fired)

func _exit_tree() -> void:
	if RunEvents.weapon_fired.is_connected(_on_weapon_fired):
		RunEvents.weapon_fired.disconnect(_on_weapon_fired)

func _process(dt: float) -> void:
	_cd = maxf(_cd - dt, 0.0)

func _on_weapon_fired(p: Node, _style_id: StringName, origin: Vector2, _target: Vector2, power_mul: float, haste_mul: float) -> void:
	if p != player:
		return
	if _cd > 0.0:
		return

	_cd = maxf(min_cd, base_cd / maxf(haste_mul, 0.05))
	if debug_proc_logging:
		print("[Conduit] ArcBolts proc")

	var r := radius * (0.90 + 0.15 * set_strength)
	var cr := chain_radius * (0.90 + 0.15 * set_strength)

	var first_handle := _nearest_enemy(origin, r)
	if first_handle == EnemyWorldTypes.INVALID_HANDLE:
		return
	var first_position := EnemyCombat.position_for_handle(first_handle)

	_spawn_arc_vfx(origin, first_position)

	var base_dmg := _get_player_base_damage()
	_deal_damage(first_handle, base_dmg * dmg1_mult * power_mul * set_strength)

	var second_handle := _nearest_enemy(first_position, cr, first_handle)
	if second_handle != EnemyWorldTypes.INVALID_HANDLE:
		_spawn_arc_vfx(first_position, EnemyCombat.position_for_handle(second_handle))
		_deal_damage(second_handle, base_dmg * dmg2_mult * power_mul * set_strength)

func _spawn_arc_vfx(a: Vector2, b: Vector2) -> void:
	if vfx_arc_line_scene == null:
		return
	var vfx := vfx_arc_line_scene.instantiate()
	if vfx == null:
		return
	get_tree().current_scene.add_child(vfx)
	if vfx.has_method("setup"):
		vfx.call("setup", a, b)

func _get_player_base_damage() -> float:
	if player != null:
		var v = player.get("base_weapon_damage")
		if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
			return float(v)
	return 12.0

func _nearest_enemy(
	from: Vector2,
	r: float,
	excluded_handle: int = EnemyWorldTypes.INVALID_HANDLE,
) -> int:
	return EnemyCombat.nearest_enemy(from, r, excluded_handle)

func _deal_damage(handle: int, amount: float) -> void:
	# The player is the SOURCE, as every other set effect passes it: without
	# it apply_damage emits damage_dealt with a null source, so nothing that
	# keys on "the player dealt this" fires - lifesteal, and any Manifestation
	# rule listening for a hit.
	EnemyCombat.apply_damage(handle, amount, 1, player)
