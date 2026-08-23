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

## Asymptotic per-level rate shared by capped NEG augments: approaches the
## ceiling, never reaches it, and has no dead levels.
static func asymptotic_rate(ceiling: float, level: int) -> float:
	var lvl := float(maxi(1, level))
	return ceiling * lvl / (lvl + 1.0)


static func resolve(inventory: Inventory, augment_ids: Array) -> BurdenSnapshot:
	var snapshot := BurdenSnapshot.new()
	if inventory == null:
		return snapshot

	var inverting: bool = augment_ids.has(&"augment_inversion_lens")

	# Pass one: read polarity and raw severity.
	var worst_slot := -1
	var worst_severity := 0.0
	for slot in range(Inventory.SLOT_COUNT):
		var item: ItemInstance = inventory.get_at(slot)
		if item == null or item.data == null:
			continue
		if item.polarity == ItemInstance.Polarity.NEG:
			snapshot.neg_count += 1
			var severity := absf(item.active_pct())
			snapshot.entries[slot] = {
				"item": item,
				"severity": severity,
				"active": severity,
				"suppressed": false,
			}
			if severity > worst_severity:
				worst_severity = severity
				worst_slot = slot
		else:
			snapshot.pos_count += 1

	# Pass two: suppression. Exactly one item, always the most severe - the Lens
	# is a single conversion chamber, and letting the player pick would turn a
	# build commitment into per-item micromanagement.
	if inverting and worst_slot >= 0:
		var entry: Dictionary = snapshot.entries[worst_slot]
		entry["active"] = 0.0
		entry["suppressed"] = true
		snapshot.suppressed_slot = worst_slot
		snapshot.suppressed_severity = worst_severity

	# Pass three: totals over ACTIVE burden.
	for slot in snapshot.entries:
		var entry: Dictionary = snapshot.entries[slot]
		var active := float(entry["active"])
		if active <= 0.0:
			continue
		snapshot.active_count += 1
		snapshot.total_active += active
		snapshot.severities.append(active)
		if active >= BurdenSnapshot.QUALIFYING_BURDEN:
			snapshot.qualifying_count += 1

	snapshot.severities.sort()
	snapshot.severities.reverse()
	return snapshot


## What a suppressed item contributes to its own slot stat instead of its curse.
## Positive, and expressed in the same units the slot's multiplier uses, so the
## stat pass can substitute it for the roll without knowing about the Lens.
static func inverted_return(severity: float) -> float:
	return maxf(0.0, severity) * INVERSION_RETURN
