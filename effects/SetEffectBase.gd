extends Node
class_name SetEffectBase

@export var effect_id: StringName = &""

@export var tooltip_short: String = ""
@export_multiline var tooltip_long: String = ""


# Filled by SetRunner.setup(...)
var player: Node = null

# Filled by SetRunner when the effect comes from a set tier.
# Used so set strength can scale with equipped item rarity.
var source_set_id: StringName = &""
var set_count: int = 0
var set_avg_rarity: float = 0.0
var set_strength: float = 1.0

func setup(p: Node) -> void:
	player = p

# Optional richer setup (SetRunner will prefer this if present).
func setup_set(p: Node, set_id: StringName, count: int, avg_rarity: float, strength: float) -> void:
	setup(p)
	set_set_scaling(set_id, count, avg_rarity, strength)

# Called whenever inventory changes while this effect stays active.
func set_set_scaling(set_id: StringName, count: int, avg_rarity: float, strength: float) -> void:
	source_set_id = set_id
	set_count = count
	set_avg_rarity = avg_rarity
	set_strength = maxf(0.1, strength)

func get_move_speed_multiplier() -> float:
	return 1.0

func get_haste_multiplier() -> float:
	return 1.0

func get_tooltip_short() -> String:
	return tooltip_short

func get_tooltip_long() -> String:
	return tooltip_long
