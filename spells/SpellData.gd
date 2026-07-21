extends Resource
class_name SpellData

@export var id: String = "spell_unknown"
@export var display_name: String = "Unknown Spell"
@export var cooldown: float = 1.0

# Scene to instantiate for the spell logic (Node)
@export var spell_scene: PackedScene
@export var auto_cast: bool = true
