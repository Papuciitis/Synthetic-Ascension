extends RefCounted
class_name BurdenResolver

## Builds the one BurdenSnapshot every NEG archetype reads.
##
## Kept static and inventory-shaped rather than living on the player, so the
## tooltip, the Run Sheet and the stat recompute all read the SAME arithmetic.
## The previous shape - Corruption Engine inlining its own top-two loop inside
## recompute_run_stats - meant a second archetype had to re-derive severity, and
## nothing could show the player the calculation.

## Fraction of a suppressed curse's severity that comes back as its own stat.
## Well under 1.0 on purpose: an Inversion Lens should make a horrific item
## WORTH carrying, never strictly better than an equivalent POS item, or the
## whole POS/NEG choice collapses.
const INVERSION_RETURN: float = 0.55

## Doctrine of Burden tuning. The Doctrine pays per qualifying curse, so it
## scales with item count and needs a bounded ceiling; the ceilings default to
## six full-rate items (today's maximum wardrobe) so nothing changes until
## playtesting picks real values. Static so the dev console and tests can
## retune without a scene.
static var doctrine_armor_per_item: float = 16.0
static var doctrine_hp_per_item: float = 0.09
static var doctrine_armor_cap: float = 96.0
static var doctrine_hp_cap: float = 0.54

## Asymptotic per-level rate shared by capped NEG augments: approaches the
## ceiling, never reaches it, and has no dead levels.
static func asymptotic_rate(ceiling: float, level: int) -> float:
	var lvl := float(maxi(1, level))
	return ceiling * lvl / (lvl + 1.0)


## How much of its authored negative range a NEG item's roll uses (0..1).
## ItemData.pct_min is the deepest roll the item can produce, so it is the
## denominator; an item with no authored range (the -99.99% default) is judged
## against the full range, which keeps the old absolute reading for it.
static func burden_ratio_for(item: ItemInstance) -> float:
	if item == null or item.data == null or item.polarity != ItemInstance.Polarity.NEG:
		return 0.0
	var severity := absf(item.active_pct())
	var authored := absf(item.data.pct_min)
	return severity / maxf(authored, maxf(severity, 0.0001))


static func resolve(inventory: Inventory, augment_ids: Array) -> BurdenSnapshot:
	var snapshot := BurdenSnapshot.new()
	if inventory == null:
		return snapshot

	var inverting: bool = augment_ids.has(&"augment_inversion_lens")

	# Pass one: the polarity census over EVERY slot, and raw severity for the
	# statistical slots only. Accessories (offhand, ring) are counted as NEG
	# but never enter burden arithmetic: their roll drives scripted behaviour,
	# not a stat the Lens could hand back.
	var worst_slot := -1
	var worst_severity := 0.0
	for slot in range(Inventory.SLOT_COUNT):
		var item: ItemInstance = inventory.get_at(slot)
		if item == null or item.data == null:
			continue
		if item.polarity != ItemInstance.Polarity.NEG:
			snapshot.pos_count += 1
			continue
		snapshot.neg_count += 1
		if slot >= Inventory.STAT_SLOT_COUNT:
			continue
		var severity := absf(item.active_pct())
		snapshot.entries[slot] = {
			"item": item,
			"severity": severity,
			"ratio": burden_ratio_for(item),
			"active": severity,
			"suppressed": false,
			"qualifies": false,
		}
		if severity > worst_severity:
			worst_severity = severity
			worst_slot = slot

	# Pass two: suppression. Exactly one item, always the most severe among the
	# statistical slots - the Lens is a single conversion chamber, and letting
	# the player pick would turn a build commitment into per-item
	# micromanagement. Runtime only: the stored roll is never rewritten.
	if inverting and worst_slot >= 0:
		var entry: Dictionary = snapshot.entries[worst_slot]
		entry["active"] = 0.0
		entry["suppressed"] = true
		snapshot.suppressed_slot = worst_slot
		snapshot.suppressed_severity = worst_severity

	# Pass three: totals over ACTIVE burden. A suppressed curse contributes to
	# nothing here - not Corruption severity, not the Doctrine count.
	for slot in snapshot.entries:
		var entry: Dictionary = snapshot.entries[slot]
		var active := float(entry["active"])
		if active <= 0.0:
			continue
		snapshot.active_count += 1
		snapshot.total_active += active
		snapshot.severities.append(active)
		if float(entry["ratio"]) >= BurdenSnapshot.QUALIFYING_BURDEN_RATIO:
			entry["qualifies"] = true
			snapshot.qualifying_count += 1

	snapshot.severities.sort()
	snapshot.severities.reverse()
	return snapshot


## What a suppressed item contributes to its own slot stat instead of its curse.
## Positive, and expressed in the same units the slot's multiplier uses, so the
## stat pass can substitute it for the roll without knowing about the Lens.
static func inverted_return(severity: float) -> float:
	return maxf(0.0, severity) * INVERSION_RETURN


## Doctrine of Burden payout for a qualifying-curse count at an augment level:
## {"armor": flat armour, "hp": Max HP fraction}. Per-item rates are
## asymptotic in level; totals are capped so the Doctrine cannot scale without
## bound as wardrobes grow.
static func doctrine_bonus(level: int, qualifying_count: int) -> Dictionary:
	var count := float(maxi(0, qualifying_count))
	return {
		"armor": minf(doctrine_armor_cap, asymptotic_rate(doctrine_armor_per_item, level) * count),
		"hp": minf(doctrine_hp_cap, asymptotic_rate(doctrine_hp_per_item, level) * count),
	}


static func doctrine_tuning() -> Dictionary:
	return {
		"armor_per_item": doctrine_armor_per_item,
		"hp_per_item": doctrine_hp_per_item,
		"armor_cap": doctrine_armor_cap,
		"hp_cap": doctrine_hp_cap,
	}


## Partial updates are fine: only the keys given change.
static func set_doctrine_tuning(values: Dictionary) -> void:
	doctrine_armor_per_item = float(values.get("armor_per_item", doctrine_armor_per_item))
	doctrine_hp_per_item = float(values.get("hp_per_item", doctrine_hp_per_item))
	doctrine_armor_cap = float(values.get("armor_cap", doctrine_armor_cap))
	doctrine_hp_cap = float(values.get("hp_cap", doctrine_hp_cap))
