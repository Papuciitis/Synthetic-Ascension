extends RefCounted
class_name LuckResolver

const SOFTCAP: float = 0.50


static func effective(luck: float) -> float:
	if is_zero_approx(luck):
		return 0.0
	return luck / (absf(luck) + SOFTCAP)


static func positive_probability(luck: float, base_probability: float = 0.50) -> float:
	return clampf(base_probability + effective(luck) * 0.12, 0.20, 0.80)


static func drop_multiplier(luck: float) -> float:
	return clampf(1.0 + effective(luck) * 0.35, 0.75, 1.35)


static func roll_quality_shift(luck: float) -> float:
	return clampf(effective(luck) * 0.15, -0.15, 0.15)


static func rarity_promotion_bonus(luck: float) -> float:
	return clampf(effective(luck) * 0.18, -0.18, 0.18)


static func vendor_stock_bonus(luck: float) -> float:
	return clampf(effective(luck) * 0.20, -0.20, 0.20)


static func buy_multiplier(luck: float) -> float:
	return 1.0 - clampf(maxf(0.0, effective(luck)) * 0.12, 0.0, 0.12)


static func sell_multiplier(luck: float) -> float:
	return 1.0 + clampf(maxf(0.0, effective(luck)) * 0.08, 0.0, 0.08)


static func extra_follower_chance(luck: float) -> float:
	return clampf(maxf(0.0, effective(luck)) * 0.20, 0.0, 0.20)


static func lucky_crit_chance(luck: float) -> float:
	return clampf(maxf(0.0, effective(luck)) * 0.08, 0.0, 0.08)


static func lucky_evasion_chance(luck: float) -> float:
	return clampf(maxf(0.0, effective(luck)) * 0.06, 0.0, 0.06)


static func secondary_event_bonus(luck: float) -> float:
	return clampf(effective(luck) * 0.12, -0.12, 0.12)


static func augment_quality_bonus(luck: float) -> float:
	return clampf(effective(luck) * 0.12, -0.12, 0.12)
