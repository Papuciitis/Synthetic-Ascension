extends RefCounted
class_name Vouchers

## Vouchers (docs/design/2026-10-03-duos-facets-and-the-reliquary.md §4):
## Follower-priced upgrades that last the run, two offered each Hub visit,
## each bought once. Global reads them where they act (has_voucher).

const FOURTH_SEAL := &"fourth_seal"
const RECAST_INDULGENCE := &"recast_indulgence"
const GILDED_INK := &"gilded_ink"
const CATALYST_PRIMER := &"catalyst_primer"
const CONCORDANCE := &"concordance"
const WHETSTONE := &"whetstone"
const BURDEN_WRIT := &"burden_writ"
const TITHE_SERMON := &"tithe_sermon"

const POOL := {
	FOURTH_SEAL: {"name": "Fourth Seal Draft", "text": "Every Binding deals one more card."},
	RECAST_INDULGENCE: {"name": "Recast Indulgence", "text": "Recasts cost half."},
	GILDED_INK: {"name": "Gilded Ink", "text": "Gilded and rarer Binding cards are 40% more likely."},
	CATALYST_PRIMER: {"name": "Catalyst Primer", "text": "Augments Transcend one level sooner (never below Lv.3)."},
	CONCORDANCE: {"name": "Concordance", "text": "Duo cards appear once both augments reach Lv.2."},
	WHETSTONE: {"name": "Whetstone", "text": "Facet cards appear from Lv.2."},
	BURDEN_WRIT: {"name": "Burden Writ", "text": "A Burdened Binding raises no Threat."},
	TITHE_SERMON: {"name": "Tithe Sermon", "text": "Abstaining from a Binding pays half again."},
}

const OFFER_SIZE := 2
const GILDED_INK_MUL := 1.4
const RECAST_MUL := 0.5
const TITHE_MUL := 1.5


static func ids() -> Array:
	var out: Array = POOL.keys()
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


static func display_name(id: StringName) -> String:
	var row: Dictionary = POOL.get(id, {})
	return String(row.get("name", ""))


static func text(id: StringName) -> String:
	var row: Dictionary = POOL.get(id, {})
	return String(row.get("text", ""))


## On the run's stage scale (follower economy audit 2026-10-04, P4): 300 at
## the first Hub as before, then +100 a segment (Hub 2 400, Hub 5 700, Hub 10
## 1,200). It was +50 a segment, a flat price against income that grows ~7x.
static func price(segment: int) -> int:
	return 200 + 100 * maxi(1, segment)


## OFFER_SIZE vouchers not yet bought, a seeded shuffle of the rest.
static func deal(rng: RandomNumberGenerator, bought: Array) -> Array:
	var open: Array = []
	for id in ids():
		if not bought.has(String(id)) and not bought.has(id):
			open.append(String(id))
	for i in range(open.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = open[i]
		open[i] = open[j]
		open[j] = tmp
	return open.slice(0, mini(OFFER_SIZE, open.size()))
