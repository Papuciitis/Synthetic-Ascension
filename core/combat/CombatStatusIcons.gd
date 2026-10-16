extends RefCounted

## Authored, already-coloured combat badges. Callers supply semantic IDs;
## neither combat text nor tutorial guidance infers a status from its words.
const DIRECTORY := "res://assets/textures/ui/combat_status/"
const IDS: Array[StringName] = [
	&"armoured", &"vampiric", &"shielded", &"splitting", &"fast",
	&"burn", &"bleed", &"stun", &"slow", &"warded", &"haste", &"fading",
	&"execution_mark", &"wound", &"cracked", &"prime", &"weak_point",
	&"fracture", &"link", &"blood_rite", &"healing_sealed", &"jam", &"debt",
	&"anchored", &"marked", &"scarred",
]

const _LABELS := {
	&"burn": "BURNING", &"bleed": "BLEEDING", &"stun": "STUNNED",
	&"slow": "SLOWED", &"warded": "WARDED", &"haste": "HASTE",
	&"fading": "FADING", &"execution_mark": "MARKED", &"wound": "WOUNDED",
	&"cracked": "ARMOUR CRACKED", &"prime": "PRIMED", &"weak_point": "EXPOSED",
	&"fracture": "FRACTURED", &"link": "LINKED", &"blood_rite": "BLOOD RITE",
	&"healing_sealed": "HEALING SEALED", &"jam": "JAMMED", &"debt": "DEBT",
	&"anchored": "ANCHORED", &"marked": "MARKED", &"scarred": "SCAR",
}

const _COLOURS := {
	&"burn": Color(1.0, 0.48, 0.18), &"bleed": Color(0.96, 0.24, 0.30),
	&"stun": Color(1.0, 0.86, 0.30), &"slow": Color(0.50, 0.78, 1.0),
	&"warded": Color(0.30, 0.90, 0.96), &"haste": Color(0.44, 0.94, 0.62),
	&"fading": Color(0.60, 0.63, 0.78), &"execution_mark": Color(1.0, 0.34, 0.36),
	&"wound": Color(0.90, 0.34, 0.30), &"cracked": Color(1.0, 0.70, 0.38),
	&"prime": Color(0.98, 0.80, 0.34), &"weak_point": Color(1.0, 0.98, 0.90),
	&"fracture": Color(1.0, 0.60, 0.25), &"link": Color(0.75, 0.50, 1.0),
	&"blood_rite": Color(0.82, 0.20, 0.40), &"healing_sealed": Color(0.78, 0.36, 0.90),
	&"jam": Color(1.0, 0.30, 0.20), &"debt": Color(0.80, 0.60, 1.0),
	&"anchored": Color(0.62, 0.84, 1.0), &"marked": Color(0.86, 0.52, 1.0),
	&"scarred": Color(0.86, 0.34, 0.30),
}

static var _textures: Dictionary = {}


static func known(id: StringName) -> bool:
	return EliteModifiers.is_known(id) or _LABELS.has(id)


static func label(id: StringName) -> String:
	return EliteModifiers.label(id) if EliteModifiers.is_known(id) else String(_LABELS.get(id, ""))


static func colour(id: StringName) -> Color:
	return EliteModifiers.tint(id) if EliteModifiers.is_known(id) else _COLOURS.get(id, Color.WHITE) as Color


static func texture(id: StringName) -> Texture2D:
	if not known(id):
		return null
	if _textures.has(id):
		return _textures[id] as Texture2D
	var path := DIRECTORY + String(id) + ".png"
	if not ResourceLoader.exists(path):
		return null
	var art := load(path) as Texture2D
	if art != null:
		_textures[id] = art
	return art
