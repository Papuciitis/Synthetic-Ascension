extends Node
class_name TeslaAuraEffect

@export var radius: float = 180.0
@export var tick_interval: float = 0.55
@export var max_targets: int = 4
@export var damage_mult: float = 0.45

# VFX (assign in inspector)
@export var vfx_arc_scene: PackedScene          # VFX_TeslaArc2D.tscn
@export var vfx_pulse_scene: PackedScene        # VFX_TeslaPulseRing.tscn (optional)

# VFX tuning
@export var arc_duration: float = 0.10
@export var arc_jaggedness: float = 11.0
@export var arc_segments: int = 10

@export var arc_color_core: Color = Color(0.95, 0.98, 1.0, 1.0)
@export var arc_color_glow: Color = Color(0.25, 0.65, 1.0, 0.60)

var player: Node2D = null
var _t: float = 0.0
var _sort_origin: Vector2 = Vector2.ZERO

func setup(p: Node) -> void:
	player = p as Node2D

func _ready() -> void:
	set_process(true)

func _process(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	_t += dt
	if _t < tick_interval:
		return
	_t = 0.0

	var dmg: float = _compute_damage()
	var r2: float = radius * radius
	var origin: Vector2 = _origin_pos()

	# optional pulse ring at tick moment
	_spawn_pulse(origin)

	# gather + sort by distance so it feels intentional
	var candidates: Array[Node2D] = []
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Node2D
		if e == null or not is_instance_valid(e):
			continue
		if origin.distance_squared_to(e.global_position) > r2:
			continue
		candidates.append(e)

	_sort_origin = origin
	candidates.sort_custom(Callable(self, "_sort_by_dist"))

	var hit: int = 0
	for e in candidates:
		if e == null or not is_instance_valid(e):
			continue

		# damage (IMPORTANT: pass player as source so your systems can attribute it)
		if e.has_method("take_damage"):
			e.call("take_damage", dmg, player)

		# arcs
		_spawn_arc(origin, e.global_position)

		hit += 1
		if hit >= max_targets:
			break

func _sort_by_dist(a: Variant, b: Variant) -> bool:
	var aa := a as Node2D
	var bb := b as Node2D
	if aa == null or bb == null:
		return false
	return aa.global_position.distance_squared_to(_sort_origin) < bb.global_position.distance_squared_to(_sort_origin)

func _origin_pos() -> Vector2:
	# prefer Hurtbox center if present (usually matches player visuals better)
	var hb := player.get_node_or_null("Hurtbox") as Node2D
	if hb != null:
		return hb.global_position
	return player.global_position

func _spawn_arc(a: Vector2, b: Vector2) -> void:
	if vfx_arc_scene == null:
		return

	var n := vfx_arc_scene.instantiate()
	var v := n as Node2D
	if v == null:
		return

	get_tree().current_scene.add_child(v)

	# configure if it is our arc script
	if v.has_method("setup_positions"):
		v.call("setup_positions", a, b, arc_duration)

	# best-effort param tweaks (safe even if those exports don’t exist)
	if v.has_method("set"):
		v.set("jaggedness", arc_jaggedness)
		v.set("segments", arc_segments)
		v.set("color_core", arc_color_core)
		v.set("color_glow", arc_color_glow)

func _spawn_pulse(pos: Vector2) -> void:
	if vfx_pulse_scene == null:
		return
	var n := vfx_pulse_scene.instantiate()
	var v := n as Node2D
	if v == null:
		return
	get_tree().current_scene.add_child(v)

	if v.has_method("setup"):
		v.call("setup", pos, radius)

func _compute_damage() -> float:
	var base_dmg: float = 12.0

	var bwd: Variant = player.get("base_weapon_damage")
	if typeof(bwd) == TYPE_FLOAT or typeof(bwd) == TYPE_INT:
		base_dmg = float(bwd)

	var power: float = 0.0
	var st_var: Variant = player.get("stats")
	if st_var is Object:
		var pvar: Variant = (st_var as Object).get("power")
		if typeof(pvar) == TYPE_FLOAT or typeof(pvar) == TYPE_INT:
			power = float(pvar)

	return base_dmg * damage_mult * (1.0 + power)


const _AUG_MAX_LEVEL: int = 5
var _aug_level: int = 1
var _bases_captured_ta: bool = false

var _base_radius_ta: float
var _base_tick_interval_ta: float
var _base_max_targets_ta: int
var _base_damage_mult_ta: float

func _enter_tree() -> void:
	_capture_level_bases_ta()

func set_level(level: int) -> void:
	_aug_level = clampi(level, 1, _AUG_MAX_LEVEL)
	_capture_level_bases_ta()
	_apply_level_scaling_ta()

func _capture_level_bases_ta() -> void:
	if _bases_captured_ta:
		return
	_bases_captured_ta = true

	_base_radius_ta = radius
	_base_tick_interval_ta = tick_interval
	_base_max_targets_ta = max_targets
	_base_damage_mult_ta = damage_mult

func _apply_level_scaling_ta() -> void:
	var t: int = _aug_level - 1
	if t <= 0:
		radius = _base_radius_ta
		tick_interval = _base_tick_interval_ta
		max_targets = _base_max_targets_ta
		damage_mult = _base_damage_mult_ta
		return

	radius = _base_radius_ta * (1.0 + 0.07 * float(t))
	tick_interval = maxf(0.25, _base_tick_interval_ta * pow(0.95, float(t)))
	max_targets = maxi(1, _base_max_targets_ta + int(floor(float(t) / 2.0)))
	damage_mult = _base_damage_mult_ta * (1.0 + 0.10 * float(t))
