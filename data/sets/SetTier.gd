extends Resource
class_name SetTier

@export var required_count: int = 2
@export var display_name: String = ""
@export_multiline var mechanical_description: String = ""
@export_multiline var plain_description: String = ""
@export var glossary_terms: PackedStringArray = PackedStringArray()
@export var mods: StatDelta = null

# effects that become active at this tier (separate nodes/scenes)
@export var effect_scenes: Array[PackedScene] = []

func apply_to(s: Stats) -> void:
	if mods != null:
		mods.apply_to(s)


## Balance revision 2: the flat bonuses scaled by the set's channels.
func apply_scaled(s: Stats, scaling: Dictionary) -> void:
	if mods != null:
		SetScaling.scaled_tier_mods(mods, scaling).apply_to(s)
