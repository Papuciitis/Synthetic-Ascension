extends RefCounted
class_name Grimoire

## The Grimoire (docs/design/2026-10-03-duos-facets-and-the-reliquary.md §4):
## every Transcendence, Duo, Facet, Thesis and Canon the profile has ever
## reached, and the story's records, kept in the profile
## (Global.grimoire_entries). Keys:
##   transcend:<augment id>   duo:<duo id>   facet:<augment id>:<facet id>
##   thesis:<family>          canon:<family>   record:<id> (StoryLines.RECORDS)

const SECTIONS: PackedStringArray = ["TRANSCENDENCE", "DUO", "FACET", "THESIS", "CANON", "RECORDS"]


static func transcend_key(aug_id: StringName) -> String:
	return "transcend:%s" % String(aug_id)


static func duo_key(duo_id: StringName) -> String:
	return "duo:%s" % String(duo_id)


static func facet_key(aug_id: StringName, facet_id: StringName) -> String:
	return "facet:%s:%s" % [String(aug_id), String(facet_id)]


static func thesis_key(family: StringName) -> String:
	return "thesis:%s" % String(family)


static func canon_key(family: StringName) -> String:
	return "canon:%s" % String(family)


static func _augment_name(aug_id: StringName, augment_db: Dictionary) -> String:
	var data := augment_db.get(aug_id, null) as AugmentData
	return data.display_name if data != null else String(aug_id)


## Every entry the Grimoire can hold, in display order:
## {key, section, name, rule, hint}. The hint is shown while the entry is
## undiscovered; the name and rule only once it is.
static func catalogue(augment_db: Dictionary) -> Array:
	var out: Array = []
	var augments: Array = AugmentScaling.TRANSCENDENCE.keys()
	augments.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for aug_id in augments:
		out.append({
			"key": transcend_key(aug_id), "section": "TRANSCENDENCE",
			"name": AugmentScaling.transcended_name(aug_id), "rule": AugmentScaling.transcend_rule(aug_id),
			"hint": "%s at Lv.%d with %s" % [_augment_name(aug_id, augment_db), AugmentScaling.TRANSCEND_LEVEL, AugmentScaling.catalyst_text(aug_id)],
		})
	for duo_id in AugmentDuos.ids():
		var pair: Array = []
		for member in AugmentDuos.members(duo_id):
			pair.append(_augment_name(member, augment_db))
		out.append({
			"key": duo_key(duo_id), "section": "DUO",
			"name": AugmentDuos.display_name(duo_id), "rule": AugmentDuos.rule(duo_id),
			"hint": " + ".join(PackedStringArray(pair)),
		})
	var faceted: Array = AugmentFacets.FACETS.keys()
	faceted.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for aug_id in faceted:
		for row in AugmentFacets.options(aug_id):
			out.append({
				"key": facet_key(aug_id, StringName(row["id"])), "section": "FACET",
				"name": "%s: %s" % [_augment_name(aug_id, augment_db), String(row["name"])], "rule": String(row["rule"]),
				"hint": "a Facet of %s" % _augment_name(aug_id, augment_db),
			})
	for family in [&"circuit", &"vessel", &"archive"]:
		out.append({
			"key": thesis_key(family), "section": "THESIS",
			"name": "%s THESIS" % String(family).to_upper(), "rule": String(DoctrineFamilies.THESIS.get(family, "")),
			"hint": "two %s Doctrines" % String(family),
		})
	for family in [&"circuit", &"vessel", &"archive"]:
		out.append({
			"key": canon_key(family), "section": "CANON",
			"name": "%s CANON" % String(family).to_upper(), "rule": String(DoctrineFamilies.CANON.get(family, "")),
			"hint": "three %s Doctrines" % String(family),
		})
	# The story's codex, noted by play (StoryDirector.note_record).
	out.append_array(StoryDirector.record_catalogue())
	return out
