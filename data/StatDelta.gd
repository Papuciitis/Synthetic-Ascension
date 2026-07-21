extends Resource
class_name StatDelta

@export var max_hp: float = 0.0
@export var armor: float = 0.0
@export var move_speed: float = 0.0
@export var power: float = 0.0
@export var haste: float = 0.0
@export var luck: float = 0.0

func apply_to(s: Stats) -> void:
	s.max_hp += max_hp
	s.armor += armor
	s.move_speed += move_speed
	s.power += power
	s.haste += haste
	s.luck += luck

func copy() -> StatDelta:
	return duplicate(true) as StatDelta

func stack_key() -> String:
	# Keep ordering fixed.
	return "%s|%s|%s|%s|%s|%s" % [
		_sn(max_hp), _sn(armor), _sn(move_speed), _sn(power), _sn(haste), _sn(luck)
	]

func equals(other: StatDelta) -> bool:
	if other == null:
		return false
	return stack_key() == other.stack_key()

func _sn(v: float) -> String:
	# Normalize floats for stable comparisons.
	# If you later roll lots of decimals, you can increase precision.
	return String.num(v, 3)
