extends Node2D
class_name OakheartShieldEffect

# Gameplay: damage reduction is applied BEFORE armor in Player._take_damage.
@export var base_damage_reduction: float = 0.08  # 8%
@export var extra_reduction_from_positive_pct: float = 0.10 # up to +10% at very high rolls

# VFX tuning
@export var radius_padding: float = 8.0
@export var segments: int = 72
@export var wave_amp: float = 2.6
@export var wave_freq: float = 3.0
@export var roll_speed: float = 1.6
@export var pulse_speed: float = 1.8

@export var core_width: float = 2.4
@export var glow_width: float = 12.0
@export var fill_alpha: float = 0.10

@export var color_core: Color = Color(0.88, 0.98, 1.0, 0.95)
@export var color_glow: Color = Color(0.30, 0.85, 1.0, 0.55)
@export var color_fill: Color = Color(0.25, 0.55, 1.0, 0.22)

var player: Node2D = null
var item: ItemInstance = null
var slot_index: int = -1

## Shared 30 Hz wall-clock bucket, the same idiom as
## ManifestationEffect.pulse_redraw: every idle painter in the run lands on the
## same frames instead of drifting out of phase with the others.
const PULSE_REDRAW_MS: int = 33

var _t: float = 0.0
var _r: float = 36.0
var _hurtbox: Area2D = null
var _last_pulse_bucket: int = -1
## The ring's point buffer, kept for the node's lifetime and rewritten in place,
## as VFX_HexMarkAura and VFX_StaminaCoreAura do.
var _pts: PackedVector2Array = PackedVector2Array()

func get_effects_short(inst: ItemInstance) -> PackedStringArray:
	var out := PackedStringArray()
	var pct := 0.0
	if inst != null:
		pct = clampf(inst.active_pct(), -0.25, 0.5)
	var extra := maxf(pct, 0.0) * extra_reduction_from_positive_pct
	var short_mult: float = (inst.rarity_effect_multiplier() if inst != null else 1.0)
	var dr := clampf((base_damage_reduction + extra) * short_mult, 0.0, 0.50)
	out.append("Reduces incoming damage by ~%.0f%% (before armor; rarity scales, cap 50%%)." % (dr * 100.0))
	out.append("Shows a protective shield aura.")
	return out

func setup_with_item(p: Node, inst: ItemInstance, slot: int) -> void:
	player = p as Node2D
	item = inst
	slot_index = slot

func set_item_instance(inst: ItemInstance) -> void:
	item = inst

func _ready() -> void:
	z_as_relative = false
	z_index = 4085

	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# Defer hurtbox lookup until everything is ready.
	call_deferred("_resolve_hurtbox")
	set_process(true)
	queue_redraw()

func _resolve_hurtbox() -> void:
	if player == null or not is_instance_valid(player):
		return
	_hurtbox = player.get_node_or_null("Hurtbox") as Area2D
	if _hurtbox != null:
		_r = _get_hurtbox_radius(_hurtbox) + radius_padding

func _process(dt: float) -> void:
	_t += dt
	# The hurtbox radius is resolved once; re-scanning its children every frame
	# allocated a child Array per frame for a constant result.
	_pulse_redraw()

## The ring is an ambient breathe with no state behind it, so it is redrawn on
## the shared 30 Hz bucket rather than every frame. What it paints is unchanged:
## _t still advances every frame and the phase is read at draw time.
func _pulse_redraw() -> void:
	var bucket := floori(float(Time.get_ticks_msec()) / float(PULSE_REDRAW_MS))
	if bucket == _last_pulse_bucket:
		return
	_last_pulse_bucket = bucket
	queue_redraw()

func get_damage_taken_multiplier() -> float:
	var pct := 0.0
	if item != null:
		pct = clampf(item.active_pct(), -0.25, 0.5)

	# Only positive rolls increase DR (negative just keeps base DR).
	# Rarity grows the reduction along the shared potency curve, with a
	# hard ceiling so damage reduction can never approach immunity.
	var extra := maxf(pct, 0.0) * extra_reduction_from_positive_pct
	var rarity_mult := (item.rarity_effect_multiplier() if item != null else 1.0)
	var dr := clampf((base_damage_reduction + extra) * rarity_mult, 0.0, 0.50)
	return 1.0 - dr

func _get_hurtbox_radius(hb: Area2D) -> float:
	var csn: CollisionShape2D = null
	for c in hb.get_children():
		csn = c as CollisionShape2D
		if csn != null:
			break
	if csn == null or csn.shape == null:
		return 36.0

	var sh := csn.shape
	if sh is CircleShape2D:
		return (sh as CircleShape2D).radius
	if sh is RectangleShape2D:
		var sz := (sh as RectangleShape2D).size
		return maxf(sz.x, sz.y) * 0.5
	if sh is CapsuleShape2D:
		var cap := sh as CapsuleShape2D
		return maxf(cap.radius, cap.height * 0.5 + cap.radius)
	if sh is ConvexPolygonShape2D:
		var pts := (sh as ConvexPolygonShape2D).points
		var m := 0.0
		for p in pts:
			m = maxf(m, p.length())
		return maxf(m, 24.0)

	return 36.0

func _draw() -> void:
	# subtle pulsing radius
	var pulse := 0.92 + 0.08 * sin(_t * TAU * pulse_speed)
	var r := _r * pulse

	# fill
	if fill_alpha > 0.0:
		draw_circle(Vector2.ZERO, r * 0.98, Color(color_fill.r, color_fill.g, color_fill.b, color_fill.a * fill_alpha))

	# wavy ring points, written into the node's own buffer instead of a fresh
	# PackedVector2Array per repaint - the reuse VFX_HexMarkAura does. The lines
	# below are unchanged: draw_polyline would join the segments differently, and
	# this is a redraw-frequency fix, not a look change.
	var seg: int = maxi(24, int(segments))
	if _pts.size() != seg + 1:
		_pts.resize(seg + 1)

	for i in range(seg + 1):
		var a := (float(i) / float(seg)) * TAU
		var wob := wave_amp * sin(a * wave_freq + _t * TAU * roll_speed)
		var rr := r + wob
		_pts[i] = Vector2(cos(a), sin(a)) * rr

	# glow (wide)
	for i in range(seg):
		draw_line(_pts[i], _pts[i + 1], Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a), glow_width, true)

	# core (thin)
	for i in range(seg):
		draw_line(_pts[i], _pts[i + 1], Color(color_core.r, color_core.g, color_core.b, color_core.a), core_width, true)
