extends Resource
class_name Stats

@export var max_hp: float = 100.0
@export var armor: float = 0.0
@export var move_speed: float = 200.0

@export var power: float = 0.0   # +% damage, eg 0.20 = +20%
@export var haste: float = 0.0   # +% speed/cdr, eg 0.30 = +30%
@export var luck: float = 0.0    # used later (crit, rerolls, drops)

func copy() -> Stats:
	return duplicate(true) as Stats
