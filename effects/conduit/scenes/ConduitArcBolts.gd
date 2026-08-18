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

	var e1 := _nearest_enemy(origin, r, null)
	if e1 == null:
		return

	_spawn_arc_vfx(origin, (e1 as Node2D).global_position)

	var base_dmg := _get_player_base_damage()
	_deal_damage(e1, base_dmg * dmg1_mult * power_mul * set_strength)

	var e2 := _nearest_enemy((e1 as Node2D).global_position, cr, e1 as Node2D)
	if e2 != null:
		_spawn_arc_vfx((e1 as Node2D).global_position, (e2 as Node2D).global_position)
		_deal_damage(e2, base_dmg * dmg2_mult * power_mul * set_strength)

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

func _nearest_enemy(from: Vector2, r: float, exclude: Node2D) -> Node2D:
	# Spatial index instead of a full "enemies" group scan per bolt hop.
	var ei := get_node_or_null("/root/EnemyIndex")
	if ei != null and ei.has_method("nearest_enemy"):
		return ei.call("nearest_enemy", from, r, exclude) as Node2D
	var best: Node2D = null
	var best_d2 := r * r
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Node2D
		if e == null or not is_instance_valid(e):
			continue
		if exclude != null and e == exclude:
			continue
		var d2 := from.distance_squared_to(e.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = e
	return best

func _deal_damage(enemy: Node, amount: float) -> void:
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("take_damage"):
		enemy.call("take_damage", amount)
