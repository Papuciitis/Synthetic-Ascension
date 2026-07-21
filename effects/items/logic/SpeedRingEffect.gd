extends Node2D
class_name SpeedRingEffect

@export var min_speed_to_emit: float = 120.0
@export var emit_rate: float = 18.0 # streaks/sec at high speed
@export var max_rate: float = 28.0

@export var vfx_streak_scene: PackedScene

var player: Node = null
var item: ItemInstance = null
var slot_index: int = -1

var _acc: float = 0.0

func get_effects_short(_inst: ItemInstance) -> PackedStringArray:
	var out := PackedStringArray()
	out.append("Increases movement speed.")
	out.append("Leaves speed streaks while moving fast.")
	return out

func setup_with_item(p: Node, inst: ItemInstance, slot: int) -> void:
	player = p
	item = inst
	slot_index = slot

func set_item_instance(inst: ItemInstance) -> void:
	item = inst

func _ready() -> void:
	if vfx_streak_scene == null:
		vfx_streak_scene = load("res://assets/vfx/world/items/VFX_SpeedStreak.tscn")
	set_process(true)

func _process(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	var vel: Vector2 = Vector2.ZERO

	# get() returns Variant → type it explicitly to avoid the warning
	var v: Variant = player.get("velocity")
	if v is Vector2:
		vel = v as Vector2

	var sp: float = vel.length()
	if sp < min_speed_to_emit:
		_acc = 0.0
		return

	var k: float = clampf((sp - min_speed_to_emit) / 220.0, 0.0, 1.0)
	var rate: float = clampf(lerpf(emit_rate * 0.35, emit_rate, k), 1.0, max_rate)
	_acc += dt * rate

	while _acc >= 1.0:
		_acc -= 1.0
		_spawn_streak(vel)
		
func _spawn_streak(vel: Vector2) -> void:
	if vfx_streak_scene == null:
		return
	var n := vfx_streak_scene.instantiate()
	var s := n as Node2D
	if s == null:
		n.queue_free()
		return

	# Direction: streaks travel opposite to movement
	var dir := -vel.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.LEFT

	if n.has_method("set"):
		if n.get("dir") is Vector2:
			n.set("dir", dir.rotated(randf_range(-0.35, 0.35)))

	get_tree().current_scene.add_child(s)

	# spawn slightly behind player with some sideways jitter
	var side := Vector2(-dir.y, dir.x)
	var offset := dir * randf_range(8.0, 18.0) + side * randf_range(-14.0, 14.0)
	s.global_position = global_position + offset
	s.rotation = dir.angle()
