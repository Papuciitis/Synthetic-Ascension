extends RefCounted
class_name HitProfileAdapter

## Reusable compatibility target for item effects that historically mutated a
## RangedBullet node. Player owns one adapter and the manager copies its values
## synchronously, so this does not allocate a Node/Resource per projectile.

var speed: float = 700.0
var max_range: float = 520.0
var damage: float = 10.0
var collision_radius: float = 6.0
var knockback: float = 0.0
var pierce: int = 0
var critical: bool = false
var body_len: float = 18.0
var body_width: float = 4.0
var body_core: Color = Color(0.92, 0.98, 1.0, 0.95)
var body_glow: Color = Color(0.25, 0.65, 1.0, 0.35)

func reset(base_damage: float) -> void:
	for key in get_meta_list():
		remove_meta(key)
	speed = 700.0
	max_range = 520.0
	damage = base_damage
	collision_radius = 6.0
	knockback = 0.0
	pierce = 0
	critical = false
	body_len = 18.0
	body_width = 4.0
	body_core = Color(0.92, 0.98, 1.0, 0.95)
	body_glow = Color(0.25, 0.65, 1.0, 0.35)

func queue_redraw() -> void:
	pass

