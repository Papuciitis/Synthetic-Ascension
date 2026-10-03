extends RefCounted
class_name AugmentFacets

## Facets (docs/design/2026-10-03-duos-facets-and-the-reliquary.md §2): two
## branches per combat augment; a FACET card asks which. The effect scripts
## take the chosen id through set_facet() and read its numbers from
## `values` here, so the card, the Grimoire and the effect agree.

const LEVEL_REQUIRED := 3

const FACETS := {
	&"augment_magic_missile": [
		{"id": &"salvo", "name": "Salvo", "rule": "+2 missiles a volley; each deals 25% less.", "values": {"extra_missiles": 2, "damage_mul": 0.75}},
		{"id": &"lance", "name": "Lance", "rule": "Half the missiles (at least 1), each x2.2 damage; seek radius x1.5.", "values": {"missile_mul": 0.5, "damage_mul": 2.2, "seek_mul": 1.5}},
	],
	&"augment_tesla_aura": [
		{"id": &"overcharge", "name": "Overcharge", "rule": "2 fewer targets (at least 1); zaps x1.7.", "values": {"target_delta": -2, "damage_mul": 1.7}},
		# The stun stays under the aura's 0.15 s pulse floor: at 0.15 s a fast,
		# Slipstream-driven aura held its nearest eight stunned for good.
		{"id": &"static_field", "name": "Static Field", "rule": "Radius x1.3; zaps stun 0.1 s and deal x0.85.", "values": {"radius_mul": 1.3, "stun": 0.1, "damage_mul": 0.85}},
	],
	&"augment_spirit_slash": [
		{"id": &"hemorrhage", "name": "Hemorrhage", "rule": "Bleed ticks twice as hard for twice as long; the cut x0.8.", "values": {"bleed_mul": 2.0, "bleed_duration_mul": 2.0, "damage_mul": 0.8}},
		{"id": &"executioner", "name": "Executioner", "rule": "x2 damage against enemies under 30% health.", "values": {"threshold": 0.3, "damage_mul": 2.0}},
	],
	&"augment_blink_hex": [
		{"id": &"long_step", "name": "Long Step", "rule": "Blink range x1.6; cooldown x0.75.", "values": {"range_mul": 1.6, "cooldown_mul": 0.75}},
		{"id": &"deep_mark", "name": "Deep Mark", "rule": "+1 marked attack; mark damage x1.5.", "values": {"extra_marks": 1, "damage_mul": 1.5}},
	],
	&"augment_summon_spiderlings": [
		{"id": &"swarm", "name": "Swarm", "rule": "+2 spiderlings a cast; bites x0.7.", "values": {"extra_spawn": 2, "bite_mul": 0.7}},
		{"id": &"venom_sacs", "name": "Venom Sacs", "rule": "Detonations x1.8; blast radius x1.4.", "values": {"blast_mul": 1.8, "radius_mul": 1.4}},
	],
	&"augment_reflect_shield": [
		{"id": &"riposte", "name": "Riposte", "rule": "Reflected rounds deal x1.5.", "values": {"reflect_mul": 1.5}},
		{"id": &"long_guard", "name": "Long Guard", "rule": "Parry window x1.6; cooldown x1.3.", "values": {"window_mul": 1.6, "cooldown_mul": 1.3}},
	],
	&"augment_stamina_core": [
		{"id": &"second_wind", "name": "Second Wind", "rule": "Activating heals 15% of max HP.", "values": {"heal_fraction": 0.15}},
		{"id": &"iron_lung", "name": "Iron Lung", "rule": "Cooldown x0.65; duration x0.75.", "values": {"cooldown_mul": 0.65, "duration_mul": 0.75}},
	],
}


static func has_facets(aug_id: StringName) -> bool:
	return FACETS.has(aug_id)


static func options(aug_id: StringName) -> Array:
	return FACETS.get(aug_id, [])


static func option(aug_id: StringName, facet_id: StringName) -> Dictionary:
	for row in options(aug_id):
		if StringName(row["id"]) == facet_id:
			return row
	return {}


static func is_option(aug_id: StringName, facet_id: StringName) -> bool:
	return not option(aug_id, facet_id).is_empty()


static func display_name(aug_id: StringName, facet_id: StringName) -> String:
	return String(option(aug_id, facet_id).get("name", ""))


static func rule(aug_id: StringName, facet_id: StringName) -> String:
	return String(option(aug_id, facet_id).get("rule", ""))


## One number of a chosen Facet; `fallback` when the augment has no such
## Facet or the Facet does not set it (so an effect can always multiply).
static func value(aug_id: StringName, facet_id: StringName, key: String, fallback: float) -> float:
	var row := option(aug_id, facet_id)
	if row.is_empty():
		return fallback
	var values: Dictionary = row.get("values", {})
	return float(values.get(key, fallback))
