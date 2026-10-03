extends RefCounted
class_name AugmentBinding

## The Binding: the augment pick that follows every segment
## (docs/design/2026-10-03-bindings-and-theses.md §3).
##
## Pure and seeded: Global builds the context, this decides the cards, and
## the same context and seed always deal the same offer. A card is a plain
## Dictionary so the offer can sit in the save as-is:
##   {"kind": "new" | "rank" | "swap" | "transcend", "id": String, "grade": int}
## A transcend card has grade -1 (it adds one level and the transformation).

const KIND_NEW := "new"
const KIND_RANK := "rank"
const KIND_SWAP := "swap"
const KIND_TRANSCEND := "transcend"

## The three NEG archetypes a fresh profile's first offer always shows one
## of (segment 1 pass S2), so the first curse the run finds has a reader.
const NEG_ARCHETYPE_IDS: Array[StringName] = [&"augment_corruption_engine", &"augment_doctrine_of_burden", &"augment_inversion_lens"]


## Context keys:
##   equipped: Array (3 slots, StringName() = empty)
##   locked: Array[bool] (slots the Hub locked; never swapped out)
##   pool: Array of every augment id (sorted, for a stable deal)
##   transcend_ready: Array of equipped ids ready to Transcend, best first
##   segment: completed segment the grades are rolled for
##   luck, grade_mul, grade_floor: grade roll inputs (AugmentScaling)
##   card_count: cards to deal (3, or 4 with the Circuit Thesis)
##   neg_guarantee: the fresh-profile intro pick
static func build_offer(context: Dictionary, rng: RandomNumberGenerator) -> Array:
	var count := maxi(1, int(context.get("card_count", 3)))
	var equipped: Array = context.get("equipped", [])
	var locked: Array = context.get("locked", [])
	var pool: Array = context.get("pool", [])
	var ready: Array = context.get("transcend_ready", [])
	var segment := int(context.get("segment", 1))
	var luck := float(context.get("luck", 0.0))
	var grade_mul := float(context.get("grade_mul", 1.0))
	var grade_floor := int(context.get("grade_floor", 0))

	var equipped_ids: Array[StringName] = []
	var empty_slots := 0
	var swappable := false
	for i in range(equipped.size()):
		var id := StringName(str(equipped[i])) if equipped[i] != null else StringName()
		if id == StringName():
			empty_slots += 1
			continue
		equipped_ids.append(id)
		if i >= locked.size() or not bool(locked[i]):
			swappable = true

	var fresh: Array[StringName] = []
	for value in pool:
		var id := StringName(str(value))
		if id != StringName() and not equipped_ids.has(id):
			fresh.append(id)
	_shuffle(fresh, rng)
	var ranks: Array[StringName] = equipped_ids.duplicate()
	_shuffle(ranks, rng)

	var cards: Array = []
	if not ready.is_empty():
		var first := StringName(str(ready[0]))
		cards.append({"kind": KIND_TRANSCEND, "id": String(first), "grade": -1})
		ranks.erase(first)

	if empty_slots > 0:
		for id in fresh:
			if cards.size() >= count:
				break
			cards.append({"kind": KIND_NEW, "id": String(id), "grade": 0})
		for id in ranks:
			if cards.size() >= count:
				break
			cards.append({"kind": KIND_RANK, "id": String(id), "grade": 0})
	else:
		# Full slots: rank-ups of what you carry, and one way to change it.
		var room := count - (1 if swappable and not fresh.is_empty() else 0)
		for id in ranks:
			if cards.size() >= room:
				break
			cards.append({"kind": KIND_RANK, "id": String(id), "grade": 0})
		if swappable:
			for id in fresh:
				if cards.size() >= count:
					break
				cards.append({"kind": KIND_SWAP, "id": String(id), "grade": 0})

	if bool(context.get("neg_guarantee", false)):
		cards = _ensure_neg_archetype(cards, fresh)

	for card in cards:
		if String(card["kind"]) != KIND_TRANSCEND:
			card["grade"] = AugmentScaling.roll_grade(rng, segment, luck, grade_mul, grade_floor)
	return cards


## The level an augment ends at when `card` resolves, from its `current`
## stored run level. A new or swapped-in augment enters at its stored level
## plus the grade's levels minus one (a Gilded new augment is Lv.2); a rank
## adds the grade's levels; a Transcendence adds one.
static func resulting_level(card: Dictionary, current: int) -> int:
	var cur := maxi(1, current)
	match String(card.get("kind", "")):
		KIND_TRANSCEND:
			return AugmentScaling.clamp_level(cur + 1)
		KIND_RANK:
			return AugmentScaling.clamp_level(cur + AugmentScaling.grade_levels(int(card.get("grade", 0))))
		_:
			return AugmentScaling.clamp_level(cur + AugmentScaling.grade_levels(int(card.get("grade", 0))) - 1)


static func needs_slot_choice(card: Dictionary) -> bool:
	return String(card.get("kind", "")) == KIND_SWAP


static func _ensure_neg_archetype(cards: Array, fresh: Array[StringName]) -> Array:
	for card in cards:
		if NEG_ARCHETYPE_IDS.has(StringName(str(card["id"]))):
			return cards
	for id in fresh:
		if NEG_ARCHETYPE_IDS.has(id):
			var entry := {"kind": KIND_NEW, "id": String(id), "grade": 0}
			if cards.size() >= 3:
				cards[cards.size() - 1] = entry
			else:
				cards.append(entry)
			return cards
	return cards


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
