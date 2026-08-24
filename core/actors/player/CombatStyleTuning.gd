extends RefCounted
class_name CombatStyleTuning

## Per-style attack numbers, in exactly one place.
##
## These used to be written twice - once in player.gd's _fire_weapon() and again
## in ManifestationEffect.repeat_player_attack() - so retuning a style left every
## echo rule quietly paying the old number. player.gd has no class_name, so a
## shared static is the only way both sides can name the same constant.

## Melee trades reach for damage and an arc that hits everything in front of it.
const MELEE_DAMAGE_MULT: float = 1.25

## Magic is the slowest and heaviest: fewest casts, biggest number, blast radius.
const MAGIC_DAMAGE_MULT: float = 1.55

## Ranged is the baseline every other number is expressed against.
const RANGED_DAMAGE_MULT: float = 1.0


static func damage_multiplier(style_id: StringName) -> float:
	match style_id:
		&"melee":
			return MELEE_DAMAGE_MULT
		&"magic":
			return MAGIC_DAMAGE_MULT
		_:
			return RANGED_DAMAGE_MULT
