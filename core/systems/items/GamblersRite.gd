class_name GamblersRite
extends RefCounted

## Gambler's Rite (NEG archetype A7): the reward is FINDING a curse, never
## wearing one. A legitimately new NEG instance the player consumes from
## the world (equipped, bagged or fed on pickup) rolls for a Follower, and
## the first acquisition of each distinct NEG base item per segment banks
## Resonance up to a per-segment cap. Trades, rewards, moves and undo are
## not acquisitions; the source on the item operation says which is which.
## The player's own drop collected again is a move: its pickup reports
## "player", so dropping and re-picking one curse cannot roll the Rite (and
## grow the Congregation) again and again (review 2026-10-04).

const ACQUISITION_KINDS: Array[StringName] = [&"equipped", &"bagged", &"merged"]
const ACQUISITION_SOURCES: Array[String] = ["pickup"]


static func is_new_neg_acquisition(kind: StringName, inst: ItemInstance, data: Dictionary) -> bool:
	if not ACQUISITION_KINDS.has(kind):
		return false
	if not ACQUISITION_SOURCES.has(String(data.get("source", ""))):
		return false
	if kind == &"merged":
		var incoming: Variant = data.get("incoming", {})
		return incoming is Dictionary and int((incoming as Dictionary).get("polarity", ItemInstance.Polarity.POS)) == ItemInstance.Polarity.NEG
	return inst != null and inst.data != null and int(inst.polarity) == ItemInstance.Polarity.NEG
