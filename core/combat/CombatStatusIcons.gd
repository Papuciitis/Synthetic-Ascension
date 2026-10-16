extends RefCounted

## Authored, already-coloured combat badges. Callers supply semantic IDs;
## neither combat text nor tutorial guidance infers a status from its words.
const DIRECTORY := "res://assets/textures/ui/combat_status/"
const IDS: Array[StringName] = [&"armoured", &"vampiric", &"shielded", &"splitting", &"fast"]

static var _textures: Dictionary = {}


static func texture(id: StringName) -> Texture2D:
	if not IDS.has(id):
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
