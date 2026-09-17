extends RefCounted
class_name RarityMath

const MIN_EXPONENT: float = -1022.0
const MAX_EXPONENT: float = 1022.0

# Gap half-life: how many ranks of rarity gap halve a duplicate's merge
# value (design spec K1; first playtest value).
const GAP_HALF_LIFE: float = 1.5

# Rate-family stats (move speed, haste) must not scale through the raw
# potency curve unchecked at extreme rarity (spec §1.6 guardrail): their
# rarity-derived contribution plateaus around R13.
const RATE_STAT_POTENCY_CAP: float = 2.25


static func potency(rarity: float) -> float:
	var r := maxf(0.0, rarity)
	return 1.0 + 0.45 * sqrt(r) + 0.05 * r


static func overflow_factor() -> float:
	# Leftover meter converts across a rank boundary at the SAME per-rank
	# ratio as the gap law — if these two numbers differ, the value of
	# identical material depends on when it happened to cross a threshold.
	return pow(2.0, -1.0 / GAP_HALF_LIFE)


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
		float(incoming_rarity - destination_rarity) / GAP_HALF_LIFE,
		MIN_EXPONENT,
		MAX_EXPONENT
	)
	return maxf(0.0, quality_factor) * pow(2.0, exponent)
