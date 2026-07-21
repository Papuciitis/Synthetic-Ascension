extends Node2D
class_name BossMine

@export var fuse: float = 1.10
@export var radius: float = 90.0
@export var damage: float = 14.0

@export var telegraph_scene: PackedScene = preload("res://assets/vfx/world/sets/conduit/VFX_ShockRing.tscn")
@export var impact_scene: PackedScene = preload("res://assets/vfx/world/sets/conduit/VFX_Shockwave.tscn")
@export var damage_circle_scene: PackedScene = preload("res://core/combat/hazards/DamageCircle.tscn")

var source: Node = null

func setup(world_pos: Vector2, src: Node, fuse_sec: float, radius_px: float, dmg: float) -> void:
	global_position = world_pos
	source = src
	fuse = fuse_sec
	radius = radius_px
	damage = dmg

func _ready() -> void:
	# Telegraph
	if telegraph_scene != null:
		var t := telegraph_scene.instantiate()
		add_child(t)
		if t.has_method("setup"):
			t.call("setup", global_position, radius)

	# Explode after fuse
	var timer := get_tree().create_timer(maxf(0.05, fuse))
	timer.timeout.connect(_explode)

func _explode() -> void:
	if not is_inside_tree():
		return

	# Impact VFX
	if impact_scene != null:
		var v := impact_scene.instantiate()
		get_tree().current_scene.add_child(v)
		if v.has_method("setup"):
			v.call("setup", global_position, radius)

	# Damage (instant / short)
	if damage_circle_scene != null:
		var d := damage_circle_scene.instantiate() as DamageCircle
		get_tree().current_scene.add_child(d)
		var src: Node = source
		if src != null and (not is_instance_valid(src)):
			src = null
		d.setup(global_position, radius, damage, 0.15, src)

	queue_free()
