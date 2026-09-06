extends Node2D
class_name RegenerationRingEffect

@export var tick_interval: float = 1.0
@export var heal_min: float = 1.0
@export var heal_max: float = 4.0

# Scales with rarity: heal *= (1 + rarity * rarity_scale)
@export var rarity_scale: float = 0.20

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
	var heal_scale := (inst.rarity_effect_multiplier() if inst != null else 1.0) * _effect_multiplier(inst)
	out.append("Heals every %.1fs: %.1f–%.1f HP (rarity scales)." % [tick_interval, heal_min * heal_scale, heal_max * heal_scale])
	out.append("Plays green regen pulses (+).")
	return out

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

	var amt := lerpf(heal_min, heal_max, randf())
	var rarity_mult := (item.rarity_effect_multiplier() if item != null else 1.0)
	amt *= rarity_mult * _effect_multiplier(item)
	# Ceiling scales with rarity too — the old flat 12.0 silently capped
	# the ring's growth around R5.
	amt = clampf(amt, 0.5, 12.0 * rarity_mult)

	player.call("heal", amt)
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
