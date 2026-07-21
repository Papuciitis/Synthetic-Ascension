extends Resource
class_name WeaponData

@export var id: String
@export var display_name: String

@export var projectile_scene: PackedScene
@export var projectile_speed: float = 650.0
@export var base_damage: float = 10.0
@export var base_cooldown: float = 0.25
