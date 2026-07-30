extends RefCounted
class_name RarityMath

const MIN_EXPONENT: float = -1022.0
const MAX_EXPONENT: float = 1022.0


static func potency(rarity: float) -> float:
	var r := maxf(0.0, rarity)
	return 1.0 + 0.45 * sqrt(r) + 0.05 * r


static func merge_quality(data: ItemData, roll_pct: float) -> float:
	if data == null:
		return 1.0
	var authored_extreme := maxf(absf(data.pct_min), absf(data.pct_max))
	if authored_extreme <= 0.000001:
		return 1.0
	var normalized := clampf(absf(roll_pct) / authored_extreme, 0.0, 1.0)
	return 0.75 + 0.50 * normalized


static func merge_mass(
	incoming_rarity: int,
	destination_rarity: int,
	quality_factor: float
) -> float:
	var exponent := clampf(
		float(incoming_rarity - destination_rarity),
		MIN_EXPONENT,
		MAX_EXPONENT
	)
	return maxf(0.0, quality_factor) * pow(2.0, exponent)
