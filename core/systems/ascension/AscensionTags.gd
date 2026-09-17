extends RefCounted
class_name AscensionTags
## Attack provenance for the advancement tree, carried on HitLedger.tags.
##
## Every hit the tree cares about arrives at EnemyCombatService with a payload;
## the payload's tags say which Core the attack belongs to, whether it is a
## native input or something the tree generated, which tree node is its root,
## how many generations deep it is, its Proc Power, and free-form flags such
## as "execute". Engines read the parsed form; nothing else in the game does.
##
##   core:melee   family:native|tree|status   root:EXQ   path:slash|impact|bullet|...
##   gen:1        pp:0.5                      flag:execute

const FAMILY_NATIVE := "native"
const FAMILY_TREE := "tree"
const META_KEY := "asc_tags"


static func make(core: String, family: String, root: String, path: String, generation: int = 0, proc_power: float = 1.0, flags: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var tags := PackedStringArray()
	tags.append("core:" + core)
	tags.append("family:" + family)
	tags.append("root:" + root)
	tags.append("path:" + path)
	tags.append("gen:%d" % generation)
	tags.append("pp:%.3f" % proc_power)
	for flag in flags:
		tags.append("flag:" + flag)
	return tags


static func native(core: String, path: String) -> PackedStringArray:
	return make(core, FAMILY_NATIVE, "native", path, 0, 1.0)


static func parse(tags: PackedStringArray) -> Dictionary:
	var out := {"core": "", "family": "", "root": "", "path": "", "gen": 0, "pp": 1.0, "flags": PackedStringArray()}
	for tag in tags:
		var split := tag.find(":")
		if split <= 0:
			continue
		var key := tag.substr(0, split)
		var value := tag.substr(split + 1)
		match key:
			"core", "family", "root", "path":
				out[key] = value
			"gen":
				out["gen"] = int(value)
			"pp":
				out["pp"] = float(value)
			"flag":
				(out["flags"] as PackedStringArray).append(value)
	return out


static func with_flag(tags: PackedStringArray, flag: String) -> PackedStringArray:
	var out := tags.duplicate()
	if not out.has("flag:" + flag):
		out.append("flag:" + flag)
	return out


static func has_flag(tags: PackedStringArray, flag: String) -> bool:
	return tags.has("flag:" + flag)


static func value_of(tags: PackedStringArray, key: String) -> String:
	var prefix := key + ":"
	for tag in tags:
		if tag.begins_with(prefix):
			return tag.substr(prefix.length())
	return ""
