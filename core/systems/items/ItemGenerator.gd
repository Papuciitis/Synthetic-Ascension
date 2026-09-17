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
		# A worn loot-table curse pushes the polarity coin toward NEG. Applied
		# here rather than folded into Luck, because Luck bends dozens of
		# systems and this must only bend one.
		var positive_chance := LuckResolver.positive_probability(luck)
		if Global != null:
			positive_chance = clampf(positive_chance - Global.curse_drop_bias, 0.05, 0.95)
		choose_positive = rng.randf() <= positive_chance
	# Bell first, shift after: averaging AFTER adding the shift halved the
	# advertised Luck effect. Quality 1.0 is always the BEST outcome for the
	# player: the strongest POS roll, or the mildest NEG roll — the old
	# negative branch lerped toward min_pct, so high Luck made NEG rolls
	# MORE severe.
	var quality := clampf(
		(rng.randf() + rng.randf()) * 0.5 + LuckResolver.roll_quality_shift(luck),
		0.0,
		1.0
	)
	if choose_positive:
		return lerpf(maxf(0.0, min_pct), max_pct, quality)
	return lerpf(min_pct, minf(0.0, max_pct), quality)


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
