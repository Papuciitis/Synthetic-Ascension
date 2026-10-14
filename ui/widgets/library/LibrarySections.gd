extends RefCounted
## Public section metadata for already-sanitized library entries. Native slot,
## noun and recipe clues may be shown before discovery; hidden identities may not.
## Reads resource catalogs only: no live effects, inventory changes or save writes.

const NEUTRAL := Color(0.67, 0.61, 0.51)
const CURSE := Color(0.56, 0.40, 0.58)
const SLOT_LABELS := ["Health", "Armor", "Movement", "Power", "Haste", "Luck", "Offhands", "Rings", "Bag items"]
const SLOT_COLORS := [
	Color(0.76, 0.43, 0.39), Color(0.55, 0.63, 0.70),
	Color(0.47, 0.66, 0.56), Color(0.78, 0.52, 0.34),
	Color(0.72, 0.64, 0.41), Color(0.55, 0.68, 0.68),
	Color(0.56, 0.52, 0.72), Color(0.73, 0.55, 0.63),
	Color(0.64, 0.58, 0.48),
]
const RECIPE_KINDS := ["transcend", "duo", "facet", "thesis", "canon"]
const RECIPE_COLORS := [
	Color(0.71, 0.55, 0.37), Color(0.56, 0.48, 0.68),
	Color(0.44, 0.64, 0.65), Color(0.49, 0.63, 0.48),
	Color(0.72, 0.46, 0.45),
]
const GUIDE_TOPICS := {
	"equipment_identity": ["Equipment", Color(0.72, 0.56, 0.45)],
	"nouns_and_pairs": ["Pairs", Color(0.63, 0.53, 0.72)],
	"merges_and_imprints": ["Imprints", Color(0.49, 0.67, 0.59)],
	"augment_growth": ["Augments", Color(0.51, 0.62, 0.73)],
	"doctrine_families": ["Doctrines", Color(0.73, 0.62, 0.41)],
}


static func describe(entry: Dictionary) -> Dictionary:
	match String(entry.get("category", "")):
		"Items":
			return _item(entry)
		"Manifestations", "Pairs":
			return _nouns(entry)
		"Recipes":
			return _recipe(entry)
		"Buildcraft":
			var topic := String(entry.get("id", ""))
			if GUIDE_TOPICS.has(topic):
				var data: Array = GUIDE_TOPICS[topic]
				return _section("guide:" + topic, data[0], maxi(0, int(entry.get("folio", 1)) - 1), data[1])
		"Sets":
			var section := _neutral(entry)
			if bool(entry.get("discovered", false)):
				var data := Global.set_db.get(StringName(entry.get("id", "")), null) as SetData
				if data != null:
					section["color"] = data.accent_color
			return section
	return _neutral(entry)


static func _item(entry: Dictionary) -> Dictionary:
	var id := String(entry.get("id", ""))
	var data := Global.item_db.get(id, null) as ItemData
	if data == null:
		return _neutral(entry)
	var slot := int(data.equip_slot)
	var index := slot if slot >= 0 and slot < 8 else 8
	var section := _section("slot:%d" % slot if index < 8 else "slot:bag", SLOT_LABELS[index], index, SLOT_COLORS[index])
	if not bool(entry.get("discovered", false)):
		return section
	var marks: Array = section["marks"]
	if id.begins_with("curse_"):
		marks.append(_mark("curse", "Curse", CURSE))
	if not data.set_id.is_empty() and Global.library_has("set:" + data.set_id):
		var set_data := Global.set_db.get(StringName(data.set_id), null) as SetData
		if set_data != null:
			marks.append(_mark("set", set_data.display_name, set_data.accent_color))
	return section


static func _nouns(entry: Dictionary) -> Dictionary:
	var tags: Array[StringName] = []
	var id := StringName(entry.get("id", ""))
	if String(entry.get("category", "")) == "Manifestations":
		tags = ManifestationCatalog.tags_of(id)
	else:
		var pair := ManifestationPairCatalog.get_def(id)
		if pair != null:
			tags = pair.nouns
	if tags.is_empty() or not ManifestationNouns.known(tags[0]):
		return _neutral(entry)
	# The catalog's first tag is the existing primary identity, including on
	# rules whose second noun occurs earlier in the canonical display order.
	var primary := tags[0]
	var section := _section("noun:" + String(primary), ManifestationNouns.label(primary).capitalize(), ManifestationNouns.ORDER.find(primary), ManifestationNouns.colour(primary))
	var marks: Array = section["marks"]
	for noun: StringName in tags.slice(1):
		if noun == primary or not ManifestationNouns.known(noun):
			continue
		marks.append(_mark("noun", ManifestationNouns.label(noun).capitalize(), ManifestationNouns.colour(noun)))
		if marks.size() == 2:
			break
	return section


static func _recipe(entry: Dictionary) -> Dictionary:
	var kind := String(entry.get("key", "")).get_slice(":", 0)
	if not RECIPE_KINDS.has(kind):
		kind = String(entry.get("id", "")).get_slice(":", 0)
	var order := RECIPE_KINDS.find(kind)
	if order < 0:
		return _neutral(entry)
	return _section("recipe:" + kind, String(Grimoire.SECTIONS[order]).capitalize(), order, RECIPE_COLORS[order])


static func _neutral(entry: Dictionary) -> Dictionary:
	var known := bool(entry.get("discovered", false))
	var category := String(entry.get("category", ""))
	var subject := "accounts"
	match category:
		"Sets": subject = "sets"
		"Items": subject = "equipment"
		"Augments": subject = "augments"
		"Enemies": subject = "opponents"
		"Chronicles": subject = "accounts"
	return _section("recorded" if known else "sealed", ("Recorded " if known else "Sealed ") + subject, 0 if known else 1, NEUTRAL)


static func _section(id: String, label: String, order: int, color: Color) -> Dictionary:
	return {"id": id, "label": label, "order": order, "color": color, "marks": [] as Array[Dictionary]}


static func _mark(kind: String, label: String, color: Color) -> Dictionary:
	return {"kind": kind, "label": label, "color": color}
