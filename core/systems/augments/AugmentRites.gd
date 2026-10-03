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
const TRANSFUSION_COST_PER_LEVEL := 40


## Levels a donor at `donor_level` pours into the recipient.
static func transfusion_gain(donor_level: int) -> int:
	if donor_level < TRANSFUSION_MIN_DONOR:
		return 0
	return floori(float(donor_level) / 2.0)


static func transfusion_cost(gain: int) -> int:
	return maxi(0, gain) * TRANSFUSION_COST_PER_LEVEL


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
