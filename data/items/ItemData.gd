extends Resource
class_name ItemData

@export var id: String
@export var display_name: String
@export var rarity: int = 0
@export var icon: Texture2D

@export_multiline var description: String = ""

@export var mods: StatDelta   # <-- changed
@export var max_stack: int = 10  # used by stacking progress/upgrades
@export var rarity_base: StatDelta # base bonus per rarity step (flat)
@export var pct_min: float = -0.9999
@export var pct_max: float = 0.9999
@export var runtime_enabled: bool = true
@export_range(0.0, 1.0, 0.01) var duplicate_feed_value: float = 0.0
@export var scripted_value_weight: float = 0.0

## Relative likelihood of being chosen when something rolls a random item.
## 1.0 is ordinary. Authored set-pieces - the deep curses especially - sit well
## below it, because a catastrophe the player meets every other fight stops
## being a catastrophe and becomes wallpaper.
@export var drop_weight: float = 1.0

# Which equipped slot it belongs to. If NONE, it goes to bag only.
enum EquipSlot { NONE = -1, HP = 0, ARMOR = 1, MOVE = 2, POWER = 3, HASTE = 4, LUCK = 5, OFFHAND = 6, RING = 7 }
@export var equip_slot: EquipSlot = EquipSlot.NONE
@export var set_id: String

# Optional passive/effect scenes to run while equipped (used by ItemEffectRunner).
@export var effect_scenes: Array[PackedScene] = []
@export var positive_effect_scenes: Array[PackedScene] = []
@export var negative_effect_scenes: Array[PackedScene] = []


func get_effect_scenes(inst: ItemInstance) -> Array[PackedScene]:
	if inst != null:
		if int(inst.polarity) == int(ItemInstance.Polarity.NEG) and not negative_effect_scenes.is_empty():
			return negative_effect_scenes
		if int(inst.polarity) == int(ItemInstance.Polarity.POS) and not positive_effect_scenes.is_empty():
			return positive_effect_scenes
	return effect_scenes


func get_effects_short(inst: ItemInstance) -> PackedStringArray:
	# Auto-generates short tooltip lines from effect scenes.
	# Effect scenes can implement:
	#   func get_effects_short(inst: ItemInstance) -> PackedStringArray
	var out: PackedStringArray = PackedStringArray()
	var scenes: Array[PackedScene] = get_effect_scenes(inst)
	if scenes.is_empty():
		return out

	var seen: Dictionary[String, bool] = {}

	for ps: PackedScene in scenes:
		if ps == null:
			continue

		var node: Node = ps.instantiate()
		if node == null:
			continue

		if node.has_method("get_effects_short"):
			var r: Variant = node.call("get_effects_short", inst)

			if r is PackedStringArray:
				var psa := r as PackedStringArray
				for s: String in psa:
					var ss: String = s.strip_edges()
					if ss != "" and not seen.has(ss):
						seen[ss] = true
						out.append(ss)

			elif r is Array:
				var arr := r as Array
				for v: Variant in arr:
					var ss2: String = String(v).strip_edges()
					if ss2 != "" and not seen.has(ss2):
						seen[ss2] = true
						out.append(ss2)

		node.free() # not in tree, so immediate free is fine

	return out
