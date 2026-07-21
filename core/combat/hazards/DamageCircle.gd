extends Area2D
class_name DamageCircle

@export var radius: float = 64.0
@export var damage: float = 10.0
@export var lifetime: float = 0.20
@export var hit_once: bool = true

var source: Node = null
var _hit: bool = false

@onready var shape: CollisionShape2D = $CollisionShape2D

func setup(world_pos: Vector2, radius_px: float, dmg: float, life: float, src: Node = null) -> void:
	global_position = world_pos
	radius = radius_px
	damage = dmg
	lifetime = life
	source = src

func _ready() -> void:
	# Default Area2D layer/mask are fine (they match player hurtbox defaults)
	if shape != null and shape.shape is CircleShape2D:
		(shape.shape as CircleShape2D).radius = radius

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	# If player is already overlapping at spawn, apply once immediately.
	_check_overlap_now()

	if lifetime > 0.0:
		var t := get_tree().create_timer(lifetime)
		t.timeout.connect(queue_free)

func _check_overlap_now() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node
	if p == null:
		return
	var hb := p.get_node_or_null("Hurtbox") as Area2D
	if hb == null:
		return
	# Simple distance check (cheap).
	if (hb.global_position.distance_to(global_position) <= radius + 32.0):
		_apply_damage(p)

func _on_area_entered(a: Area2D) -> void:
	if a == null or not a.is_in_group("player_hurtbox"):
		return
	var p := a.get_parent()
	if p != null:
		_apply_damage(p)

func _apply_damage(p: Node) -> void:
	if hit_once and _hit:
		return
	_hit = true
	if p.has_method("take_damage"):
		p.call("take_damage", damage, source)
	if hit_once:
		queue_free()
