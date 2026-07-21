extends Resource
class_name StyleData

@export var id: String
@export var display_name: String

@export var hp_add: float = 0.0
@export var armor_add: float = 0.0
@export var speed_add: float = 0.0

@export var power_add: float = 0.0
@export var haste_add: float = 0.0
@export var luck_add: float = 0.0

func apply_to(s: Stats) -> void:
	s.max_hp += hp_add
	s.armor += armor_add
	s.move_speed += speed_add
	s.power += power_add
	s.haste += haste_add
	s.luck += luck_add
