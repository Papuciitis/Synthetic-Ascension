extends RefCounted
class_name ItemGenerator


static func promotion_chance(context: ItemDropContext, current_rarity: int) -> float:
	if context == null:
		return 0.0
	var chance := 0.08
	chance += minf(0.18, float(maxi(0, context.segment_index - 1)) * 0.015)
	chance += clampf(context.threat_level, 0.0, 1.0) * 0.12
	chance += clampf(float(context.source_rank), 0.0, 4.0) * 0.08
	if context.is_elite:
		chance += 0.08
	chance += LuckResolver.rarity_promotion_bonus(context.player_luck)
	var catchup_gap := maxf(0.0, context.equipped_rarity_average - float(current_rarity))
	chance += minf(0.10, catchup_gap * 0.02)
	chance = clampf(chance, 0.0, 0.90)
	if current_rarity >= context.rarity_soft_cap:
		chance *= clampf(context.overcap_chance, 0.0, 1.0)
	return chance


static func roll_rarity(context: ItemDropContext, rng: RandomNumberGenerator) -> int:
	if context == null or rng == null:
		return 0
	var low := mini(context.rarity_min, context.rarity_max)
	var high := maxi(context.rarity_min, context.rarity_max)
	var rarity := maxi(0, rng.randi_range(low, high))
	for _promotion in range(64):
		if rng.randf() > promotion_chance(context, rarity):
			break
		rarity += 1
	return rarity


static func roll_signed_percent(
	data: ItemData,
	luck: float,
	rng: RandomNumberGenerator
) -> float:
	if data == null or rng == null:
		return 0.0
	return roll_signed_range(data.pct_min, data.pct_max, luck, rng)


static func roll_signed_range(
	min_pct: float,
	max_pct: float,
	luck: float,
	rng: RandomNumberGenerator
) -> float:
	if rng == null:
		return 0.0
	var has_positive := max_pct > 0.0
	var has_negative := min_pct < 0.0
	if not has_positive and not has_negative:
		return 0.0
	var choose_positive := has_positive
	if has_positive and has_negative:
		choose_positive = rng.randf() <= LuckResolver.positive_probability(luck)
	var quality := clampf(
		rng.randf() + LuckResolver.roll_quality_shift(luck),
		0.0,
		1.0
	)
	# Retain a bell-like center while Luck shifts quality beneficially.
	quality = (quality + rng.randf()) * 0.5
	if choose_positive:
		return lerpf(maxf(0.0, min_pct), max_pct, quality)
	return lerpf(minf(0.0, max_pct), min_pct, quality)


static func create_instance(
	data: ItemData,
	context: ItemDropContext,
	rng: RandomNumberGenerator
) -> ItemInstance:
	if data == null or context == null or rng == null:
		return null
	var roll := roll_signed_percent(data, context.player_luck, rng)
	var polarity := ItemInstance.Polarity.POS if roll >= 0.0 else ItemInstance.Polarity.NEG
	return ItemInstance.from_roll(data, roll_rarity(context, rng), polarity, roll)
