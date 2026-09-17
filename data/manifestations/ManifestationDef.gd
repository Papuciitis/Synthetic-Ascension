extends RefCounted
class_name ManifestationDef

## One curated Manifestation: a single trigger -> behaviour rule that an item
## instance can carry for its whole life. Manifestations are handcrafted; the
## RNG only picks WHICH one an item gets, never assembles one from parts.

var id: StringName = &""
var display_name: String = ""

## One-line rule shown on the item. Write it as trigger -> behaviour, in the
## player's language, not the implementation's.
var rule: String = ""

## The shared nouns this rule speaks about, 1-2 of them, and the reason the
## layer produces engines at all. A tag is valid ONLY if it names a resource in
## ManifestationState.NOUNS - the runner claims each one while the rule is
## equipped, so "declared" and "claimed" cannot drift apart.
##
## Every rule carries at least one. A rule that shares no noun with anything can
## never combine, and enough of those measurably starve the whole layer: each
## untagged rule lowers the chance that any two equipped rules interact.
var tags: Array[StringName] = []

## Equip slots this may roll on (Inventory.SLOT_* / ItemData.EquipSlot).
var slots: Array[int] = []

## Relative pick weight inside an eligible pool.
var weight: float = 1.0

## Node script instantiated by ManifestationRunner while the item is equipped.
var logic: GDScript = null


func _init(
	p_id: StringName,
	p_display_name: String,
	p_rule: String,
	p_tags: Array[StringName],
	p_slots: Array[int],
	p_logic: GDScript,
	p_weight: float = 1.0
) -> void:
	id = p_id
	display_name = p_display_name
	rule = p_rule
	tags = p_tags
	slots = p_slots
	logic = p_logic
	weight = maxf(0.01, p_weight)


func allows_slot(slot: int) -> bool:
	return slots.has(slot)


## The noun this rule is displayed as belonging to when only one can be shown.
func primary_tag() -> StringName:
	return tags[0] if not tags.is_empty() else &""


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
