extends ManifestationEffect
class_name ManifestationPairEffect

## Base class for an authored pair payoff.
##
## A pair is just a ManifestationEffect the runner instantiates when its
## condition holds, which buys the whole hook contract and the demand-driven
## signal wiring for free. Two things differ:
##
##  * It belongs to no slot. slot_index defaults to -1, which would sort a pair
##    FIRST in the runner's dispatch order and let it drain a shared resource
##    before the rules that produce it had run. Pairs are pinned to sort LAST:
##    the engine reacts to the items, it never pre-empts them.
##  * It has no item, so rarity is the MEAN of the rules that formed it. Min
##    would punish a mixed loadout; max would be farmable with one ranked ring.

var pair_definition: ManifestationPairDef = null
var _contributor_rarity: float = 0.0


func setup_pair(
	p: Node,
	shared: ManifestationState,
	def: ManifestationPairDef,
	mean_rarity: float
) -> void:
	player = p as Node2D
	state = shared
	pair_definition = def
	_contributor_rarity = maxf(0.0, mean_rarity)
	# Dispatched after every slotted rule, never before.
	slot_index = Inventory.SLOT_COUNT
	_on_manifestation_ready()


func set_contributor_rarity(mean_rarity: float) -> void:
	_contributor_rarity = maxf(0.0, mean_rarity)


func effective_rarity() -> float:
	return _contributor_rarity


func manifestation_id() -> StringName:
	return pair_definition.id if pair_definition != null else &""


func tags() -> Array[StringName]:
	return pair_definition.nouns if pair_definition != null else ([] as Array[StringName])


func primary_tag() -> StringName:
	if pair_definition == null or pair_definition.nouns.is_empty():
		return &""
	return pair_definition.nouns[0]


func describe() -> String:
	return pair_definition.rule if pair_definition != null else ""
