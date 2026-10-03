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

# The cut: `hit_d` x D (the native hit, AugmentScaling) x potency, swung by
# d6_count d6 normalised to their mean - the dice keep their tabletop swing
# without the old 3d6 + 10 x Power, which added +2 at 20% Power.
@export var hit_d: float = 2.4
@export var d6_count: int = 3
# Kept for scene compatibility; no longer read.
@export var power_scale: float = 10.0
@export var flat_bonus: float = 0.0

# Bleed
@export var bleed_min_stacks: int = 1
@export var bleed_max_stacks: int = 3
@export var bleed_duration: float = 3.0
@export var bleed_tick: float = 0.5
@export var bleed_tick_mult_of_hit: float = 0.06

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

	var pressed := not Global.active_augment_input_blocked(int(get_meta("hud_slot_index", -1))) and Input.is_action_just_pressed(active_action)
	if pressed:
		_try_cast(true)
	elif transcended and _cd <= 0.0 and not Global.active_augment_input_blocked():
		# Thousand Cuts casts itself the moment it is ready; the key still
		# works. A cast nobody pressed is not "an activation" for Open
		# Circuit's cross-lock. An empty scan waits before scanning again.
		_auto_retry = maxf(0.0, _auto_retry - dt)
		if _auto_retry <= 0.0 and not _try_cast(false):
			_auto_retry = AUTO_RETRY_SEC

	_report_cd(false)

## Returns whether it cut.
func _try_cast(manual: bool = true) -> bool:
	if _cd > 0.0:
		return false

	var targets := _pick_targets(player.global_position, range_px, target_count(), {})
	if targets.is_empty():
		return false

	_cd_max = Global.doctrine_active_cooldown(base_cd)
	_cd = _cd_max
	if manual:
		Global.notify_active_augment_used(int(get_meta("hud_slot_index", -1)))

	var struck: Dictionary = {}
	var killed := _cut_all(targets, struck)
	# Thousand Cuts: a kill re-casts at once from where it fell.
	var chains := 0
	while transcended and killed > 0 and chains < CUTS_CHAINS:
		chains += 1
		var again := _pick_targets(player.global_position, range_px, target_count(), struck)
		if again.is_empty():
			break
		killed = _cut_all(again, struck)

	# The d4 refund rewards a pressed cast. Thousand Cuts' own casts skip it:
	# with a cast on every ready frame, a 50% reset compounded into twice the
	# cast rate on top of the chains (AugmentPowerProbe: 113 D/s at Lv.10).
	if refund_on_3plus and manual:
		var r: int = randi_range(1, 4)
		if r >= 3:
			_cd = 0.0
	return true


## The nearest `count` enemies within `reach`, skipping `struck`.
func _pick_targets(center: Vector2, reach: float, count: int, struck: Dictionary) -> Array[int]:
	var nearby: Array[int] = []
	EnemyCombat.gather_in_radius(center, reach, nearby)
	var open: Array[int] = []
	for handle in nearby:
		if not struck.has(handle):
			open.append(handle)
	open.sort_custom(func(a: int, b: int) -> bool:
		return center.distance_squared_to(EnemyCombat.position_for_handle(a)) < center.distance_squared_to(EnemyCombat.position_for_handle(b)))
	if open.size() > count:
		open.resize(count)
	return open


## Cuts each target once; returns how many died.
func _cut_all(targets: Array[int], struck: Dictionary) -> int:
	var killed := 0
	for handle in targets:
		struck[handle] = true
		if _cut(handle):
			killed += 1
	return killed


func _cut(handle: int, part: String = "augment:spirit_slash:slash") -> bool:
	var target_position := EnemyCombat.position_for_handle(handle)
	# The bleed reads the roll before the Facet's cut multiplier, so
	# Hemorrhage's thinner cut does not thin its own bleed.
	var rolled: float = _roll_hit_damage()
	var hit_dmg: float = rolled * _facet_cut_mul(handle)
	var is_crit: bool = (randf() < crit_chance)

	EnemyCombat.apply_damage(handle, hit_dmg, 1, player, BalanceAttribution.provenance("augment:spirit_slash", part, "augment"))
	var died := not EnemyWorld.is_valid_handle(handle) or EnemyWorld.is_dying(handle) or EnemyWorld.get_health(handle) <= 0.0

	if not died:
		var stacks: int = randi_range(bleed_min_stacks, bleed_max_stacks)
		_apply_bleed(handle, stacks, rolled)
		if is_crit:
			EnemyCombat.apply_stun(handle, crit_stun)
			var direction: Vector2 = (target_position - player.global_position).normalized()
			if direction == Vector2.ZERO:
				direction = Vector2.RIGHT
			EnemyCombat.apply_knockback(handle, direction * crit_knock)

	_spawn_vfx(target_position, is_crit)
	return died


## The Facet's multiplier on one cut: Hemorrhage's always, Executioner's
## only against an enemy already under its health threshold.
func _facet_cut_mul(handle: int) -> float:
	var mul := AugmentFacets.value(AUGMENT_ID, _facet, "damage_mul", 1.0)
	var threshold := AugmentFacets.value(AUGMENT_ID, _facet, "threshold", 0.0)
	if threshold <= 0.0:
		return mul
	var max_health := EnemyWorld.get_max_health(handle)
	return mul if max_health > 0.0 and EnemyWorld.get_health(handle) < threshold * max_health else 1.0


## Phantom Step (the Blink Hex + Spirit Slash Duo): the Hex calls this where
## a blink lands. It cuts the `count` enemies nearest `at` within the Duo's
## range with an ordinary cut each, and touches neither the cooldown nor
## Open Circuit's cross-lock: the free slash is the Duo's whole point.
## Returns how many it cut.
func phantom_cut(at: Vector2, count: int) -> int:
	if player == null or not is_instance_valid(player) or count <= 0:
		return 0
	var targets := _pick_targets(at, AugmentDuos.value(AugmentDuos.PHANTOM_STEP, "range", 220.0), count, {})
	for handle in targets:
		_cut(handle, "augment:spirit_slash:phantom_step")
	return targets.size()


## One target, or Thousand Cuts' 3 + 1 per 4 levels.
func target_count() -> int:
	return (CUTS_TARGETS + int(floor(float(_aug_level) / 4.0))) if transcended else 1


func _roll_hit_damage() -> float:
	return AugmentScaling.damage(player, hit_d, _aug_level) * AugmentScaling.dice_factor(d6_count, 6)


## Thousand Cuts (the Transcended slash).
const CUTS_TARGETS := 3
const CUTS_CHAINS := 3
const AUTO_RETRY_SEC := 0.1
var transcended: bool = false
var _auto_retry: float = 0.0


func set_transcended(value: bool) -> void:
	transcended = value
	_retitle_for_transcendence()


## The chosen Facet (Hemorrhage or Executioner, AugmentFacets), or &"".
## Hemorrhage's bleed is applied from the captured bases in
## _apply_level_scaling_ss, so it never compounds; the cut multiplier is
## read per cut because Executioner depends on the target.
const AUGMENT_ID := &"augment_spirit_slash"
var _facet: StringName = &""


func set_facet(facet: StringName) -> void:
	_facet = facet
	_apply_level_scaling_ss()


## The HUD plate takes the Transcended name; the authored title comes back
## if the flag ever clears (a new attempt rebuilds the node anyway).
var _authored_title: String = ""


func _retitle_for_transcendence() -> void:
	if _authored_title == "":
		_authored_title = hud_title_text
	var turned := AugmentScaling.transcended_name(StringName(str(get_meta("augment_id", ""))))
	hud_title_text = turned if transcended and turned != "" else _authored_title

func _apply_bleed(handle: int, stacks: int, hit_dmg: float) -> void:
	if stacks <= 0:
		return

	var dmg_per_tick_per_stack: float = maxf(0.1, hit_dmg * bleed_tick_mult_of_hit)
	EnemyStatus.apply_bleed(
		handle,
		stacks,
		bleed_duration,
		bleed_tick,
		dmg_per_tick_per_stack,
		player,
	)

func _find_nearest_enemy(center: Vector2, radius: float) -> int:
	return EnemyCombat.nearest_enemy(center, radius)

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


var _aug_level: int = 1
var _bases_captured_ss: bool = false

var _base_range_px_ss: float
var _base_cd_ss: float
var _base_d6_count_ss: int
var _base_power_scale_ss: float
var _base_flat_bonus_ss: float
var _base_crit_chance_ss: float
var _base_bleed_max_ss: int
var _base_bleed_duration_ss: float
var _base_bleed_tick_mult_ss: float

func _enter_tree() -> void:
	_capture_level_bases_ss()

func set_level(level: int) -> void:
	_aug_level = AugmentScaling.clamp_level(level)
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
	_base_bleed_duration_ss = bleed_duration
	_base_bleed_tick_mult_ss = bleed_tick_mult_of_hit

## Damage grows through AugmentScaling.potency; reach, cadence, dice, crit
## and bleed stacks grow with the capped count steps; Hemorrhage deepens
## and lengthens the bleed.
func _apply_level_scaling_ss() -> void:
	_capture_level_bases_ss()
	var t: int = AugmentScaling.count_steps(_aug_level)
	range_px = _base_range_px_ss * (1.0 + 0.05 * float(t))
	base_cd = maxf(1.4, _base_cd_ss * pow(0.94, float(t)))
	d6_count = maxi(1, _base_d6_count_ss + int(floor(float(t) / 2.0)))
	power_scale = _base_power_scale_ss
	flat_bonus = _base_flat_bonus_ss
	crit_chance = clampf(_base_crit_chance_ss + 0.02 * float(t), 0.0, 0.25)
	bleed_max_stacks = maxi(bleed_min_stacks, _base_bleed_max_ss + int(floor(float(t) / 2.0)))
	bleed_duration = _base_bleed_duration_ss * AugmentFacets.value(AUGMENT_ID, _facet, "bleed_duration_mul", 1.0)
	bleed_tick_mult_of_hit = _base_bleed_tick_mult_ss * AugmentFacets.value(AUGMENT_ID, _facet, "bleed_mul", 1.0)

	# Keep internal cooldown max in sync (important if level changes while running).
	_cd_max = base_cd
	_cd = minf(_cd, _cd_max)
