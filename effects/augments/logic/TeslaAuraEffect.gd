extends Node
class_name TeslaAuraEffect

@export var radius: float = 180.0
@export var tick_interval: float = 0.55
@export var max_targets: int = 4
## Each zap's payload in D, the native hit (AugmentScaling): the tree's unit,
## so the aura grows with the build instead of staying at 12 x 0.45.
@export var damage_mult: float = 0.5

## Storm Crown (the Transcended aura): wider, and each zap chains.
const CROWN_RADIUS_MUL := 1.3
const CROWN_HOPS := 2
const CROWN_HOP_FALLOFF := 0.7
const CROWN_HOP_RANGE := 170.0
const CROWN_STUN := 0.12
const CROWN_HEAVY_MUL := 2.0
var transcended: bool = false

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

## Slipstream Coil (the Sprint Servos + Tesla Aura Duo) reads whether the
## player moved since the last frame: a position compare, no query.
var _last_player_pos: Vector2 = Vector2.ZERO
var _moving: bool = false

func setup(p: Node) -> void:
	player = p as Node2D
	if player != null:
		_last_player_pos = player.global_position

func _ready() -> void:
	set_process(true)

func _process(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	var at := player.global_position
	_moving = at != _last_player_pos
	_last_player_pos = at

	_t += dt
	# Haste speeds the aura now, as it does every other automatic augment.
	if _t < current_tick_interval():
		return
	_t = 0.0

	var dmg: float = _compute_damage()
	var origin: Vector2 = _origin_pos()
	var reach: float = current_radius()

	# optional pulse ring at tick moment
	_spawn_pulse(origin)

	# gather + sort by distance so it feels intentional
	var candidates: Array[int] = []
	EnemyCombat.gather_in_radius(origin, reach, candidates)

	_sort_origin = origin
	candidates.sort_custom(Callable(self, "_sort_by_dist"))

	var hit: int = 0
	var struck: Dictionary = {}
	for handle in candidates:
		var hit_position := EnemyCombat.position_for_handle(handle)
		_zap(handle, dmg)
		struck[handle] = true
		_spawn_arc(origin, hit_position)
		if transcended:
			_chain_from(handle, hit_position, dmg, struck)

		hit += 1
		if hit >= max_targets:
			break


func _zap(handle: int, dmg: float) -> void:
	var amount := dmg
	if transcended:
		if AugmentScaling.is_heavy(handle):
			amount *= CROWN_HEAVY_MUL
		EnemyCombat.apply_stun(handle, CROWN_STUN)
	if zap_stun > 0.0:
		EnemyCombat.apply_stun(handle, zap_stun)
	EnemyCombat.apply_damage(handle, amount, 1, player, BalanceAttribution.provenance("augment:tesla_aura", "augment:tesla_aura:zap", "augment"))


## Storm Crown: from a struck enemy the arc leaps to the nearest one not yet
## struck this pulse, CROWN_HOPS times, losing CROWN_HOP_FALLOFF each leap.
func _chain_from(handle: int, at: Vector2, dmg: float, struck: Dictionary) -> void:
	var from_handle := handle
	var from_at := at
	var amount := dmg
	for hop in range(CROWN_HOPS):
		amount *= CROWN_HOP_FALLOFF
		var nearby: Array[int] = []
		EnemyCombat.gather_in_radius(from_at, CROWN_HOP_RANGE, nearby, from_handle)
		var next := EnemyWorldTypes.INVALID_HANDLE
		var best := INF
		for candidate in nearby:
			if struck.has(candidate):
				continue
			var d2 := from_at.distance_squared_to(EnemyCombat.position_for_handle(candidate))
			if d2 < best:
				best = d2
				next = candidate
		if next == EnemyWorldTypes.INVALID_HANDLE:
			return
		var next_at := EnemyCombat.position_for_handle(next)
		_zap(next, amount)
		struck[next] = true
		_spawn_arc(from_at, next_at)
		from_handle = next
		from_at = next_at


func current_radius() -> float:
	return radius * (CROWN_RADIUS_MUL if transcended else 1.0)


func current_tick_interval() -> float:
	var interval := tick_interval / AugmentScaling.haste_multiplier(player)
	if _moving and Global.augment_duo_active(AugmentDuos.SLIPSTREAM_COIL):
		interval *= AugmentDuos.value(AugmentDuos.SLIPSTREAM_COIL, "tick_mul", 1.0)
	return maxf(0.15, interval)

func _sort_by_dist(a: Variant, b: Variant) -> bool:
	var a_position := EnemyCombat.position_for_handle(int(a))
	var b_position := EnemyCombat.position_for_handle(int(b))
	return a_position.distance_squared_to(_sort_origin) < b_position.distance_squared_to(_sort_origin)

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
	return AugmentScaling.damage(player, damage_mult, _aug_level)


func set_transcended(value: bool) -> void:
	transcended = value


## The chosen Facet (Overcharge or Static Field, AugmentFacets), or &"".
## Applied from the captured bases in _apply_level_scaling_ta, so it never
## compounds; it stacks with Storm Crown, which multiplies at use time.
const AUGMENT_ID := &"augment_tesla_aura"
var _facet: StringName = &""
## Static Field's stun on every zap, 0 without it.
var zap_stun: float = 0.0


func set_facet(facet: StringName) -> void:
	_facet = facet
	_apply_level_scaling_ta()


var _aug_level: int = 1
var _bases_captured_ta: bool = false

var _base_radius_ta: float
var _base_tick_interval_ta: float
var _base_max_targets_ta: int
var _base_damage_mult_ta: float

func _enter_tree() -> void:
	_capture_level_bases_ta()

func set_level(level: int) -> void:
	_aug_level = AugmentScaling.clamp_level(level)
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

## Damage grows through AugmentScaling.potency (read at each zap); the
## radius, tick and target count grow with the capped count steps. A Facet
## trades on top: Overcharge fewer, harder zaps; Static Field a wider,
## stunning, softer ring.
func _apply_level_scaling_ta() -> void:
	_capture_level_bases_ta()
	var t: int = AugmentScaling.count_steps(_aug_level)
	damage_mult = _base_damage_mult_ta * AugmentFacets.value(AUGMENT_ID, _facet, "damage_mul", 1.0)
	radius = _base_radius_ta * (1.0 + 0.07 * float(t)) * AugmentFacets.value(AUGMENT_ID, _facet, "radius_mul", 1.0)
	tick_interval = maxf(0.25, _base_tick_interval_ta * pow(0.95, float(t)))
	var targets: int = _base_max_targets_ta + int(floor(float(t) / 2.0))
	max_targets = maxi(1, targets + int(AugmentFacets.value(AUGMENT_ID, _facet, "target_delta", 0.0)))
	zap_stun = AugmentFacets.value(AUGMENT_ID, _facet, "stun", 0.0)
