extends Node2D
class_name FirestoneEffect

# --- VFX tuning ---
@export var orbit_radius: float = 18.0
@export var orbit_speed: float = 2.0
@export var glow_radius: float = 22.0
@export var glow_alpha: float = 0.10
@export var ember_alpha: float = 0.85

# --- Gameplay tuning ---
# Baseline bonus when equipped (kept small; real tuning later)
@export var base_magic_power: float = 0.04
@export var base_magic_haste: float = 0.02

# Extra bonus that scales with the rolled % (ItemInstance.active_pct)
@export var pct_to_magic_power: float = 0.35  # active_pct * this -> added to Stats.power


# --- Burn (DoT) tuning ---
@export var burn_duration: float = 2.5
@export var burn_tick: float = 0.5
# Damage per tick per stack = hit_damage * burn_tick_mult (scaled by roll)
@export var burn_tick_mult: float = 0.03
@export var burn_mult_roll_scale: float = 0.60
@export var burn_stacks: int = 1

## Shared 30 Hz wall-clock bucket, the same idiom as
## ManifestationEffect.pulse_redraw: every idle painter in the run lands on the
## same frames instead of drifting out of phase with the others.
const PULSE_REDRAW_MS: int = 33

var player: Node2D = null
var item: ItemInstance = null
var slot_index: int = -1
var _t: float = 0.0
var _last_pulse_bucket: int = -1


func get_effects_short(inst: ItemInstance) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	out.append("Your hits apply Burn (DoT) and your attacks look fiery.")
	var pct: float = 0.0
	if inst != null:
		pct = maxf(inst.active_pct(), 0.0)

	var short_mult: float = (inst.rarity_effect_multiplier() if inst != null else 1.0)
	var pow_bonus: float = (base_magic_power + (pct * pct_to_magic_power)) * short_mult
	var hst_bonus: float = base_magic_haste * minf(short_mult, 2.25)
	out.append("Magic: +%.1f%% Power, +%.1f%% Haste (roll and rarity scale)." % [pow_bonus * 100.0, hst_bonus * 100.0])

	var burn_mult_scaled: float = burn_tick_mult * (1.0 + pct * burn_mult_roll_scale) * short_mult
	out.append("Burn: %.1fs for %d stack(s). Each tick deals ~%.1f%% of hit." % [burn_duration, burn_stacks, burn_mult_scaled * 100.0])
	return out

func setup_with_item(p: Node, inst: ItemInstance, slot: int) -> void:
	player = p as Node2D
	item = inst
	slot_index = slot

func set_item_instance(inst: ItemInstance) -> void:
	item = inst

func _ready() -> void:
	z_as_relative = false
	z_index = 4080

	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	_pulse_redraw()

## The ring is an ambient breathe with no state behind it, so it is redrawn on
## the shared 30 Hz bucket rather than every frame. What it paints is unchanged:
## _t still advances every frame and the phase is read at draw time.
func _pulse_redraw() -> void:
	var bucket := int(Time.get_ticks_msec() / PULSE_REDRAW_MS)
	if bucket == _last_pulse_bucket:
		return
	_last_pulse_bucket = bucket
	queue_redraw()


func _pct() -> float:
	if item == null:
		return 0.0
	return clampf(item.active_pct(), -0.25, 0.5)

func _burn_mult_scaled() -> float:
	var pct: float = 0.0
	if item != null:
		pct = maxf(item.active_pct(), 0.0)
	var rarity_mult := (item.rarity_effect_multiplier() if item != null else 1.0)
	return burn_tick_mult * (1.0 + pct * burn_mult_roll_scale) * rarity_mult

func _apply_burn_meta(attack: Object) -> void:
	if attack == null:
		return
	attack.set_meta("burn_duration", burn_duration)
	attack.set_meta("burn_tick", burn_tick)
	attack.set_meta("burn_stacks", burn_stacks)
	attack.set_meta("burn_tick_mult", _burn_mult_scaled())

func apply_to_stats(s: Stats) -> void:
	# Firestone's *numbers* are for magic style.
	if Global == null or str(Global.selected_style_id) != "magic":
		return

	var pct := _pct()
	var rarity_mult := (item.rarity_effect_multiplier() if item != null else 1.0)
	s.power += (base_magic_power + (pct * pct_to_magic_power)) * rarity_mult
	# Haste is a rate stat: capped growth (spec §1.6 guardrail).
	s.haste += base_magic_haste * minf(rarity_mult, 2.25)

# --- Visual "fire attacks" tint hooks ---
func apply_to_ranged_bullet(bullet: Node, _style_id: StringName) -> void:
	# Subtle warm tint for non-magic too (pure VFX).
	if bullet == null:
		return
	_apply_burn_meta(bullet)
	# RangedBullet uses procedural colors; set if those properties exist.
	if bullet.has_method("set"):
		if bullet.get("body_core") is Color:
			bullet.set("body_core", Color(1.0, 0.86, 0.55, 0.95))
		if bullet.get("body_glow") is Color:
			bullet.set("body_glow", Color(1.0, 0.25, 0.10, 0.38))
		if bullet.has_method("queue_redraw"):
			bullet.call("queue_redraw")

func apply_to_hit_profile(profile: HitProfileAdapter, _style_id: StringName) -> void:
	if profile == null:
		return
	_apply_burn_meta(profile)
	profile.body_core = Color(1.0, 0.86, 0.55, 0.95)
	profile.body_glow = Color(1.0, 0.25, 0.10, 0.38)

func apply_to_melee_slash(slash: Node) -> void:
	if slash == null:
		return
	_apply_burn_meta(slash)
	# Warm sparks / edge for the slash
	if slash.get("spark_color") is Color:
		slash.set("spark_color", Color(1.0, 0.55, 0.15, 0.70))
	if slash.get("color_edge") is Color:
		slash.set("color_edge", Color(1.0, 0.55, 0.18, 0.55))
	if slash.has_method("queue_redraw"):
		slash.call("queue_redraw")

func apply_to_magic_impact(impact: Node) -> void:
	if impact == null:
		return
	_apply_burn_meta(impact)
	# Stronger "fiery spell" palette
	if impact.get("color_core") is Color:
		impact.set("color_core", Color(1.0, 0.96, 0.88, 1.0))
	if impact.get("color_glow") is Color:
		impact.set("color_glow", Color(1.0, 0.35, 0.10, 1.0))
	if impact.get("color_fill") is Color:
		impact.set("color_fill", Color(1.0, 0.22, 0.05, 1.0))
	if impact.get("flicker_strength") is float:
		impact.set("flicker_strength", 0.12)
	if impact.has_method("queue_redraw"):
		impact.call("queue_redraw")

func _draw() -> void:
	# Soft player glow
	var pct := _pct()
	var glow_mul := 1.0 + maxf(pct, 0.0) * 0.8
	var a_glow := glow_alpha * glow_mul

	draw_circle(Vector2.ZERO, glow_radius * glow_mul, Color(1.0, 0.40, 0.10, a_glow))
	draw_circle(Vector2.ZERO, (glow_radius * 0.55) * glow_mul, Color(1.0, 0.70, 0.25, a_glow * 0.85))

	# Orbiting ember (small flame blob)
	var ang := _t * TAU * orbit_speed
	var p := Vector2(cos(ang), sin(ang)) * orbit_radius
	var flick := 0.85 + 0.15 * sin(_t * TAU * 6.0)
	var a := ember_alpha * flick

	# ember core + glow
	draw_circle(p, 4.6, Color(1.0, 0.60, 0.20, a))
	draw_circle(p, 9.5, Color(1.0, 0.20, 0.05, a * 0.35))

	# little flame lick (triangle-ish)
	var up := Vector2(0, -1).rotated(ang)
	var side := Vector2(1, 0).rotated(ang)
	var poly := PackedVector2Array([
		p + up * 10.0,
		p - up * 4.0 + side * 5.0,
		p - up * 4.0 - side * 5.0
	])
	draw_colored_polygon(poly, Color(1.0, 0.35, 0.10, a * 0.55))
