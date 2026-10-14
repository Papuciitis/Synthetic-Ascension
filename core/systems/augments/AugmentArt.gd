extends RefCounted
class_name AugmentArt

## Illustration selection is explicit. Offers and reference pages can show a
## form the run has never owned; only their callers read the current run.
## Authored AugmentData.icon remains the base illustration and last fallback.
const CARD_DIR := "res://assets/ui/augments/cards/"
const SLUGS := {
	&"augment_magic_missile": "magic_missile",
	&"augment_tesla_aura": "tesla_aura",
	&"augment_spirit_slash": "spirit_slash",
	&"augment_blink_hex": "blink_hex",
	&"augment_summon_spiderlings": "summon_spiderlings",
	&"augment_reflect_shield": "reflect_shield",
	&"augment_stamina_core": "stamina_core",
	&"augment_lucky_charm": "lucky_charm",
	&"augment_sprint_servos": "sprint_servos",
	&"augment_corruption_engine": "corruption_engine",
	&"augment_doctrine_of_burden": "doctrine_of_burden",
	&"augment_inversion_lens": "inversion_lens",
	&"augment_equilibrium_sigil": "equilibrium_sigil",
	&"augment_litany_of_wounds": "litany_of_wounds",
	&"augment_cult_of_personality": "cult_of_personality",
	&"augment_gamblers_rite": "gamblers_rite",
}


## Transcendence supersedes a chosen Facet; a missing transformed image can
## still fall back to the Facet, then to the authored base icon.
static func candidate_paths(id: StringName, facet: StringName = &"", transcended: bool = false) -> Array[String]:
	var paths: Array[String] = []
	var slug := String(SLUGS.get(id, ""))
	if slug.is_empty():
		return paths
	if transcended and AugmentScaling.can_transcend(id):
		paths.append(CARD_DIR + "transcend/" + slug + ".png")
	if AugmentFacets.is_option(id, facet):
		paths.append(CARD_DIR + "facets/" + slug + "_" + String(facet) + ".png")
	return paths


static func offer_paths(id: StringName, entry: Dictionary, facet: StringName = &"", transcended: bool = false) -> Array[String]:
	match String(entry.get("kind", "")):
		AugmentBinding.KIND_DUO:
			return grimoire_paths("duo:" + str(entry.get("id", "")))
		AugmentBinding.KIND_TRANSCEND:
			return candidate_paths(id, facet, true)
	return candidate_paths(id, facet, transcended)


## Keys already identify a recipe's explicit form, independent of the run.
static func grimoire_paths(key: String) -> Array[String]:
	var parts := key.split(":")
	if parts.size() == 2:
		if parts[0] == "transcend":
			return candidate_paths(StringName(parts[1]), &"", true)
		if parts[0] == "duo" and AugmentDuos.is_duo(StringName(parts[1])):
			return [CARD_DIR + "duos/" + parts[1].trim_prefix("duo_") + ".png"]
	if parts.size() == 3 and parts[0] == "facet":
		return candidate_paths(StringName(parts[1]), StringName(parts[2]), false)
	return []


static func resolve_texture(paths: Array, fallback: Texture2D = null) -> Texture2D:
	for candidate in paths:
		var path := str(candidate)
		if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
			continue
		var texture := load(path) as Texture2D
		if texture != null:
			return texture
	# Do not cache misses: an illustration can become available after import.
	return fallback


static func texture_for(data: AugmentData, facet: StringName = &"", transcended: bool = false) -> Texture2D:
	if data == null:
		return null
	return resolve_texture(candidate_paths(data.id, facet, transcended), data.icon)


static func grimoire_texture(key: String, augment_db: Dictionary) -> Texture2D:
	var paths := grimoire_paths(key)
	if paths.is_empty():
		return null
	var parts := key.split(":")
	var data: AugmentData = null
	if parts[0] == "duo":
		var members := AugmentDuos.members(StringName(parts[1]))
		if not members.is_empty():
			data = augment_db.get(members[0], null) as AugmentData
	else:
		data = augment_db.get(StringName(parts[1]), null) as AugmentData
	return resolve_texture(paths, data.icon if data != null else null)
