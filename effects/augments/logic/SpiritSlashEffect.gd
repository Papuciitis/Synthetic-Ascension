extends Node
class_name SpiritSlashEffect

signal active_cd_changed(time_left: float, max_cd: float)

@export var hud_priority: int = 10
@export var hud_key_text: String = "F"
@export var hud_title_text: String = "Spirit Slash"
@export var hud_icon: Texture2D

@export var active_action: StringName = &"augment_active"

@export var range_px: float = 180.0
@export var base_cd: float = 2.5

# 3d6 + power scaling
@export var d6_count: int = 3
@export var power_scale: float = 10.0
@export var flat_bonus: float = 0.0

# Bleed
@export var bleed_min_stacks: int = 1
@export var bleed_max_stacks: int = 3
@export var bleed_duration: float = 3.0
@export var bleed_tick: float = 0.5
@export var bleed_tick_mult_of_hit: float = 0.04

# Crit -> stun + knockback
@export var crit_chance: float = 0.12
@export var crit_stun: float = 0.35
@export var crit_knock: float = 520.0

# Refund 1d4 >= 3
@export var refund_on_3plus: bool = true

# VFX scene (assign VFX_SpiritSlash.tscn)
@export var vfx_scene: PackedScene

var player: Node2D = null
var _cd: float = 0.0
var _cd_max: float = 2.5
var _last_report: float = -999.0

func setup(p: Node) -> void:
	player = p as Node2D

func _ready() -> void:
	set_process(true)
	_cd_max = base_cd
	_report_cd(true)

func _process(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	if _cd > 0.0:
		_cd = maxf(_cd - dt, 0.0)

	if Input.is_action_just_pressed(active_action):
		_try_cast()

	_report_cd(false)

func _try_cast() -> void:
	if _cd > 0.0:
		return

	var t: Node2D = _find_nearest_enemy(player.global_position, range_px)
	if t == null:
		return

	_cd_max = base_cd
	_cd = _cd_max

	var hit_dmg: float = _roll_hit_damage()
	var is_crit: bool = (randf() < crit_chance)

	if t.has_method("take_damage"):
		t.call("take_damage", hit_dmg, player)

	var stacks: int = randi_range(bleed_min_stacks, bleed_max_stacks)
	_apply_bleed(t, stacks, hit_dmg)

	if is_crit:
		if t.has_method("apply_stun"):
			t.call("apply_stun", crit_stun)
		if t.has_method("apply_knockback"):
			var dir: Vector2 = (t.global_position - player.global_position).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			t.call("apply_knockback", dir * crit_knock)

	_spawn_vfx(t.global_position, is_crit)

	if refund_on_3plus:
		var r: int = randi_range(1, 4)
		if r >= 3:
			_cd = 0.0

func _roll_hit_damage() -> float:
	var total: int = 0
	for i in range(maxi(1, d6_count)):
		total += randi_range(1, 6)

	var power: float = 0.0
	var st: Stats = player.get("stats") as Stats
	if st != null:
		power = st.power

	return float(total) + flat_bonus + (power * power_scale)

func _apply_bleed(t: Node, stacks: int, hit_dmg: float) -> void:
	if stacks <= 0:
		return

	var dmg_per_tick_per_stack: float = maxf(0.1, hit_dmg * bleed_tick_mult_of_hit)
	var handle := EnemyCombat.handle_for_actor(t)
	if handle != 0:
		EnemyStatus.apply_bleed(
			handle,
			stacks,
			bleed_duration,
			bleed_tick,
			dmg_per_tick_per_stack,
			player,
		)
		return

	var dot: BleedDot = null
	var existing: Node = t.get_node_or_null("BleedDot")
	if existing != null:
		dot = existing as BleedDot

	if dot == null:
		dot = BleedDot.new()
		dot.name = "BleedDot"
		t.add_child(dot)

	dot.setup(t, player, stacks, bleed_duration, bleed_tick, dmg_per_tick_per_stack)

func _find_nearest_enemy(center: Vector2, radius: float) -> Node2D:
	var best: Node2D = null
	var best_d2: float = radius * radius

	for n in get_tree().get_nodes_in_group("enemies"):
		var e: Node2D = n as Node2D
		if e == null or not is_instance_valid(e):
			continue
		var d2: float = center.distance_squared_to(e.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = e

	return best

func _spawn_vfx(pos: Vector2, is_crit: bool) -> void:
	if vfx_scene == null:
		return

	var v: Node2D = vfx_scene.instantiate() as Node2D
	if v == null:
		return

	get_tree().current_scene.add_child(v)

	if v.has_method("setup"):
		v.call("setup", player.global_position, pos, is_crit)
	else:
		v.global_position = pos

func _report_cd(force: bool) -> void:
	if not force and absf(_cd - _last_report) < 0.05:
		return
	_last_report = _cd
	active_cd_changed.emit(_cd, _cd_max)


const _AUG_MAX_LEVEL: int = 5
var _aug_level: int = 1
var _bases_captured_ss: bool = false

var _base_range_px_ss: float
var _base_cd_ss: float
var _base_d6_count_ss: int
var _base_power_scale_ss: float
var _base_flat_bonus_ss: float
var _base_crit_chance_ss: float
var _base_bleed_max_ss: int

func _enter_tree() -> void:
	_capture_level_bases_ss()

func set_level(level: int) -> void:
	_aug_level = clampi(level, 1, _AUG_MAX_LEVEL)
	_capture_level_bases_ss()
	_apply_level_scaling_ss()

func _capture_level_bases_ss() -> void:
	if _bases_captured_ss:
		return
	_bases_captured_ss = true

	_base_range_px_ss = range_px
	_base_cd_ss = base_cd
	_base_d6_count_ss = d6_count
	_base_power_scale_ss = power_scale
	_base_flat_bonus_ss = flat_bonus
	_base_crit_chance_ss = crit_chance
	_base_bleed_max_ss = bleed_max_stacks

func _apply_level_scaling_ss() -> void:
	var t: int = _aug_level - 1
	if t <= 0:
		range_px = _base_range_px_ss
		base_cd = _base_cd_ss
		d6_count = _base_d6_count_ss
		power_scale = _base_power_scale_ss
		flat_bonus = _base_flat_bonus_ss
		crit_chance = _base_crit_chance_ss
		bleed_max_stacks = _base_bleed_max_ss
	else:
		range_px = _base_range_px_ss * (1.0 + 0.05 * float(t))
		base_cd = maxf(1.4, _base_cd_ss * pow(0.94, float(t)))

		d6_count = maxi(1, _base_d6_count_ss + int(floor(float(t) / 2.0)))
		power_scale = _base_power_scale_ss * (1.0 + 0.12 * float(t))
		flat_bonus = _base_flat_bonus_ss + 0.5 * float(t)

		crit_chance = clampf(_base_crit_chance_ss + 0.02 * float(t), 0.0, 0.25)
		bleed_max_stacks = maxi(bleed_min_stacks, _base_bleed_max_ss + int(floor(float(t) / 2.0)))

	# Keep internal cooldown max in sync (important if level changes while running).
	_cd_max = base_cd
	_cd = minf(_cd, _cd_max)
