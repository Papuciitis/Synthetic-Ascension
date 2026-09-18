extends Node2D
class_name RegenerationRingEffect

## Balance revision 2 (section 3.4): every tick heals
## mean = (base_heal + max_hp_share * max HP) * A(r) * max(0.10, 1 + roll)
## times a uniform roll in [roll_min, roll_max] (mean 1), hard-limited to
## tick_cap_share of max HP, never on a dead player. A(r) is the item's
## effect profile (0.9 at R0, 1.0 at R1, 1.9 at R30, then a slow tail).
@export var tick_interval: float = 1.0
@export var base_heal: float = 1.5
@export var max_hp_share: float = 0.015
@export var roll_min: float = 0.4
@export var roll_max: float = 1.6
@export var tick_cap_share: float = 0.05
## Tests inject a deterministic roll multiplier here (-1 = random).
var roll_override: float = -1.0

# Scales with rarity: heal *= (1 + rarity * rarity_scale)

# VFX
@export var vfx_plus_scene: PackedScene
@export var ring_radius: float = 20.0
@export var ring_width: float = 3.0
@export var ring_alpha: float = 0.12

var player: Node = null
var item: ItemInstance = null
var slot_index: int = -1

## Shared 30 Hz wall-clock bucket, the same idiom as
## ManifestationEffect.pulse_redraw: every idle painter in the run lands on the
## same frames instead of drifting out of phase with the others.
const PULSE_REDRAW_MS: int = 33

var _t: float = 0.0
var _acc: float = 0.0
var _last_pulse_bucket: int = -1

func get_effects_short(inst: ItemInstance) -> PackedStringArray:
	var out := PackedStringArray()
	var max_hp := _player_max_hp()
	var mean := mean_heal(inst, max_hp)
	var next := mean_heal_at(inst, max_hp, float(maxi(0, inst.rarity) + 1)) if inst != null else mean
	out.append("Heals every %.1fs: about %.1f HP (%.1f-%.1f; next rank %.1f), never more than %.0f%% of max HP." % [tick_interval, mean, mean * roll_min, mean * roll_max, next, tick_cap_share * 100.0])
	out.append("Plays green regen pulses (+).")
	return out


## The mean tick before the random roll and the cap, at the item's rank.
func mean_heal(inst: ItemInstance, max_hp: float) -> float:
	return mean_heal_at(inst, max_hp, ItemScaling.effective_rank(inst) if inst != null else 0.0)


func mean_heal_at(inst: ItemInstance, max_hp: float, rank: float) -> float:
	return (base_heal + max_hp_share * maxf(0.0, max_hp)) * ItemScaling.accessory_factor("ring_regeneration", rank) * _effect_multiplier(inst)


## One tick: the mean times the roll, hard-limited to a share of max HP.
func tick_amount(inst: ItemInstance, max_hp: float, roll: float) -> float:
	return minf(mean_heal(inst, max_hp) * roll, tick_cap_share * maxf(0.0, max_hp))


func _player_max_hp() -> float:
	if player == null or not is_instance_valid(player):
		return 0.0
	var value: Variant = player.get("max_hp")
	return float(value) if value is float or value is int else 0.0


func setup_with_item(p: Node, inst: ItemInstance, slot: int) -> void:
	player = p
	item = inst
	slot_index = slot

func set_item_instance(inst: ItemInstance) -> void:
	item = inst

func _ready() -> void:
	z_as_relative = false
	z_index = 4075

	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	if vfx_plus_scene == null:
		# default fallback
		vfx_plus_scene = load("res://assets/vfx/world/items/VFX_FloatingPlus.tscn")

	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_t += dt
	_pulse_redraw()

	if player == null or not is_instance_valid(player):
		return
	if not player.has_method("heal"):
		return

	_acc += dt
	if _acc < tick_interval:
		return
	_acc = 0.0

	var dead: Variant = player.get("is_dead")
	if dead is bool and dead:
		return
	var roll := roll_override if roll_override >= 0.0 else randf_range(roll_min, roll_max)
	var amt := tick_amount(item, _player_max_hp(), roll)
	if amt <= 0.0:
		return

	# The source name only labels telemetry (healing_by_source); the heal
	# itself follows the generic path exactly as before.
	player.call("heal", amt, &"item:ring_regeneration")
	_spawn_plus()



## The ring is an ambient breathe with no state behind it, so it is redrawn on
## the shared 30 Hz bucket rather than every frame. What it paints is unchanged:
## _t still advances every frame and the phase is read at draw time.
func _pulse_redraw() -> void:
	var bucket := floori(float(Time.get_ticks_msec()) / float(PULSE_REDRAW_MS))
	if bucket == _last_pulse_bucket:
		return
	_last_pulse_bucket = bucket
	queue_redraw()


func _effect_multiplier(inst: ItemInstance) -> float:
	return maxf(0.10, 1.0 + (inst.active_pct() if inst != null else 0.0))

func _spawn_plus() -> void:
	if vfx_plus_scene == null:
		return
	var n := vfx_plus_scene.instantiate()
	var p2 := n as Node2D
	if p2 == null:
		n.queue_free()
		return

	# Attach to current scene so it doesn't inherit player scaling, but position at player.
	get_tree().current_scene.add_child(p2)
	var base_pos := global_position
	p2.global_position = base_pos + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 8.0))
	p2.scale = Vector2.ONE * randf_range(0.9, 1.15)

func _draw() -> void:
	# subtle green ring
	var pulse := 0.85 + 0.15 * sin(_t * TAU * 2.0)
	var a := ring_alpha * pulse
	draw_circle(Vector2.ZERO, ring_radius, Color(0.35, 1.0, 0.55, a))
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, Color(0.55, 1.0, 0.65, a * 1.25), ring_width, true)
