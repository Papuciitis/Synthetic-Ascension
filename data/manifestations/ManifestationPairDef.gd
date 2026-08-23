extends RefCounted
class_name ManifestationPairDef

## One authored payoff for a pair of nouns.
##
## Pairs are NEVER rolled. They come online when the loadout already carries two
## rules of each of two nouns, which is why they live in their own catalog
## rather than inside ManifestationCatalog - keeping them out of `roll_for()`,
## `pool_for_slot()` and `all_ids()` makes "a pair is not a drop" a type-level
## fact instead of a guard everyone has to remember.
##
## The set of pairs is a function of the NOUN SET alone, not of which rules
## carry which tags. That is why the noun count is frozen at five: a sixth noun
## is not one more payoff to write, it is five more.

var id: StringName = &""
var display_name: String = ""

## One-line rule, written as trigger -> behaviour like every Manifestation.
var rule: String = ""

## Exactly two nouns, stored sorted so a pair has one canonical form.
var nouns: Array[StringName] = []

## Node script instantiated by ManifestationRunner while the pair is live.
var logic: GDScript = null


func _init(
	p_id: StringName,
	p_display_name: String,
	p_rule: String,
	p_nouns: Array[StringName],
	p_logic: GDScript
) -> void:
	id = p_id
	display_name = p_display_name
	rule = p_rule
	nouns = p_nouns.duplicate()
	nouns.sort()
	logic = p_logic


## Canonical lookup key. The authored `id` is what persists - a key derived from
## the nouns would orphan every saved discovery flag the day a noun is renamed.
func pair_key() -> StringName:
	return StringName("%s+%s" % [String(nouns[0]), String(nouns[1])]) if nouns.size() == 2 else &""


func involves(noun: StringName) -> bool:
	return nouns.has(noun)
