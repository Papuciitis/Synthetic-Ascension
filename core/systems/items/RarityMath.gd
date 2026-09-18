extends RefCounted
class_name RarityMath

const MIN_EXPONENT: float = -1022.0
const MAX_EXPONENT: float = 1022.0

# Gap half-life: how many ranks of rarity gap halve a duplicate's merge
# value (design spec K1). Balance revision 2 (2026-09-19, section 5.1):
# 3.0, so a six-rank gap keeps a quarter of a peer instead of a sixteenth.
# The same constant converts overflow across a rank boundary.
const GAP_HALF_LIFE: float = 3.0

# Market price of a rank, in Followers, before quality, stats and set
# premium (section 5.2): the same helper prices both endpoints of a
# fractional rank, so the meter is worth exactly the lerp between them.
const PRICE_BASE: float = 26.0
const PRICE_LINEAR: float = 14.0
const PRICE_SQUARE: float = 1.0

# Rate-family stats (move speed, haste) must not scale through the raw
# potency curve unchecked at extreme rarity (spec §1.6 guardrail): their
# rarity-derived contribution plateaus around R13.
const RATE_STAT_POTENCY_CAP: float = 2.25


static func potency(rarity: float) -> float:
	var r := maxf(0.0, rarity)
	return 1.0 + 0.45 * sqrt(r) + 0.05 * r


static func rank_price(rank: int) -> float:
	var r := float(maxi(0, rank))
	return PRICE_BASE + PRICE_LINEAR * r + PRICE_SQUARE * r * r


static func fractional_rank_price(rank: int, meter: float) -> float:
	var r := maxi(0, rank)
	return lerpf(rank_price(r), rank_price(r + 1), clampf(meter, 0.0, 1.0))


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
