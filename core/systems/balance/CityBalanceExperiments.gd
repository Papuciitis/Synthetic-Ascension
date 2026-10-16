extends RefCounted

## Launch-only city comparisons. Absent arguments preserve the live game;
## metadata records false values too, so baseline captures are explicit.
const NO_OVERTIME_DROP_BONUS := "--city-no-overtime-drop-bonus"
const NO_OVERTIME_RARITY_BONUS := "--city-no-overtime-rarity-bonus"
const GOSPEL_STRONGEST_REWARDS := "--city-gospel-strongest-rewards"
const NO_CITY_DEVELOPMENT := "--city-no-permanent-development"

static var _arguments: PackedStringArray = OS.get_cmdline_user_args()

static func enabled(argument: String) -> bool:
	return _arguments.has(argument)

static func metadata() -> Dictionary:
	return {
		"no_overtime_drop_bonus": enabled(NO_OVERTIME_DROP_BONUS),
		"no_overtime_rarity_bonus": enabled(NO_OVERTIME_RARITY_BONUS),
		"gospel_strongest_rewards": enabled(GOSPEL_STRONGEST_REWARDS),
		"no_permanent_development": enabled(NO_CITY_DEVELOPMENT),
	}
