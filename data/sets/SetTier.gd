extends Resource
class_name SetTier

@export var required_count: int = 2
@export var mods: StatDelta = null

# effects that become active at this tier (separate nodes/scenes)
@export var effect_scenes: Array[PackedScene] = []

func apply_to(s: Stats) -> void:
	if mods != null:
		mods.apply_to(s)
