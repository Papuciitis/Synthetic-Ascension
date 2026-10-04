extends RefCounted
class_name AugmentRites

## The Reliquary's rites and the Burdened Binding
## (docs/design/2026-10-03-duos-facets-and-the-reliquary.md §3-4). Pure
## arithmetic and seeded rolls; Global applies them.

# ---------------------------------------------------------------- Corruption

const EXALTED := &"exalted"
const SCARRED := &"scarred"
const SUNDERED := &"sundered"
const OUTCOMES: Array[StringName] = [EXALTED, SCARRED, SUNDERED]
const OUTCOME_NAMES := {EXALTED: "EXALTED", SCARRED: "SCARRED", SUNDERED: "SUNDERED"}
const OUTCOME_TEXT := {
	EXALTED: "+3 levels.",
	SCARRED: "+2 levels; while it is equipped, Max HP x0.9.",
	SUNDERED: "-2 levels (never below 1).",
}
## While a Scarred augment is equipped, Max HP is multiplied by this.
const SCAR_MAX_HP_MUL := 0.9
## How far Luck moves the odds, in weight points, from Sundered to Exalted.
const LUCK_SHIFT := 10.0


static func corruption_weights(luck: float) -> PackedFloat32Array:
	var shift := clampf(LuckResolver.effective(luck) * LUCK_SHIFT, -LUCK_SHIFT, LUCK_SHIFT)
	return PackedFloat32Array([45.0 + shift, 35.0, 20.0 - shift])


static func roll_corruption(rng: RandomNumberGenerator, luck: float) -> StringName:
	var weights := corruption_weights(luck)
	var total := 0.0
	for w in weights:
		total += w
	var pick := rng.randf() * total
	for i in range(OUTCOMES.size()):
		pick -= weights[i]
		if pick <= 0.0:
			return OUTCOMES[i]
	return OUTCOMES[OUTCOMES.size() - 1]


static func corrupted_level(outcome: StringName, level: int) -> int:
	match outcome:
		EXALTED:
			return AugmentScaling.clamp_level(level + 3)
		SCARRED:
			return AugmentScaling.clamp_level(level + 2)
		SUNDERED:
			return AugmentScaling.clamp_level(level - 2)
	return AugmentScaling.clamp_level(level)


# ---------------------------------------------------------------- Transfusion

const TRANSFUSION_MIN_DONOR := 2
## The price of a level through the second Binding (40); deeper, a level
## costs TRANSFUSION_COST_PER_SEGMENT x the Binding's segment.
const TRANSFUSION_COST_PER_LEVEL := 40
const TRANSFUSION_COST_PER_SEGMENT := 20


## Levels a donor at `donor_level` pours into the recipient.
static func transfusion_gain(donor_level: int) -> int:
	if donor_level < TRANSFUSION_MIN_DONOR:
		return 0
	return floori(float(donor_level) / 2.0)


## Followers one level costs at a Binding segment: 40 through segment 2, then
## 20 x segment (60 at Hub 3, 200 at Hub 10) - the follower economy audit's
## P4, so a flat 40 does not become free while income grows ~7x.
static func transfusion_cost_per_level(segment: int = 2) -> int:
	return TRANSFUSION_COST_PER_SEGMENT * maxi(2, segment)


static func transfusion_cost(gain: int, segment: int = 2) -> int:
	return maxi(0, gain) * transfusion_cost_per_level(segment)


# ---------------------------------------------------------------- the Burden

## Threat debt a Burdened Binding adds to the segment it opens.
const BURDEN_THREAT := 20.0


## The cursed relic ids a Burden can bind into the bag, sorted for a
## stable seeded pick.
static func burden_relic_ids(item_db: Dictionary) -> Array:
	var out: Array = []
	for id in item_db.keys():
		if String(id).begins_with("curse_"):
			out.append(String(id))
	out.sort()
	return out


## The grades a Burden leaves: every graded card one higher, Apocryphal
## stays; Transcend, Duo and Facet cards (grade -1) are untouched.
static func burdened_offer(offer: Array) -> Array:
	var out: Array = []
	for card in offer:
		var copy: Dictionary = (card as Dictionary).duplicate()
		var grade := int(copy.get("grade", -1))
		if grade >= 0:
			copy["grade"] = mini(grade + 1, AugmentScaling.GRADE_COUNT - 1)
		out.append(copy)
	return out


# ---------------------------------------------------------------- Consecrate

## Consecrate (follower economy audit 2026-10-04, P6): the Followers twin of
## the Burden. One graded card rises one grade for 150 x the Binding's
## segment x (k + 1), k = Consecrations already paid this Binding, so late
## Followers have a rising-price outlet on the run's spike (450 / 900 / 1,350
## at Hub 3; 1,500 / 3,000 / 4,500 at Hub 10).
const CONSECRATE_PER_SEGMENT := 150
## Marks a card Consecrate raised, so the Binding knows a Recast would throw
## a paid grade away (review 2026-10-04). Rides the saved offer as-is.
const CONSECRATED_KEY := "consecrated"


static func consecrate_cost(segment: int, done: int) -> int:
	return CONSECRATE_PER_SEGMENT * maxi(1, segment) * (maxi(0, done) + 1)


static func can_consecrate_card(card: Dictionary) -> bool:
	var grade := int(card.get("grade", -1))
	return grade >= 0 and grade < AugmentScaling.GRADE_COUNT - 1


## Whether one more grade on `card` changes what it resolves to for an
## augment whose stored run level is `current`. A grade only adds levels and
## AugmentBinding.resulting_level clamps them at Lv.20, so a card that
## already reaches the cap gains nothing (review 2026-10-04: such a card was
## Consecrated, charged and announced as raised).
static func consecrate_adds_level(card: Dictionary, current: int) -> bool:
	if not can_consecrate_card(card):
		return false
	var raised := card.duplicate()
	raised["grade"] = int(card["grade"]) + 1
	return AugmentBinding.resulting_level(raised, current) > AugmentBinding.resulting_level(card, current)


## The offer with card `index` one grade higher and marked Consecrated;
## every other card as dealt.
static func consecrated_offer(offer: Array, index: int) -> Array:
	var out: Array = []
	for i in range(offer.size()):
		var copy: Dictionary = (offer[i] as Dictionary).duplicate()
		if i == index and can_consecrate_card(copy):
			copy["grade"] = int(copy["grade"]) + 1
			copy[CONSECRATED_KEY] = true
		out.append(copy)
	return out
