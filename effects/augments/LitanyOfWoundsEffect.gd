extends Node
class_name LitanyOfWoundsEffect

## Litany of Wounds (NEG archetype A5): below 60% HP the wardrobe's total
## active curse severity converts to Haste on a ramp that is complete at
## 20% HP. No on-hit window and no timer: the health bar is the resource,
## read live from the player and the burden snapshot the stat pass left.
## Delivered through AugmentRunner.get_haste_multiplier, so it multiplies
## the shot cadence the way set and item effects do.

var player: Node = null
var level: int = 1


func setup(p: Node) -> void:
	player = p


func set_level(value: int) -> void:
	level = maxi(1, value)


func hp_ratio() -> float:
	if player == null:
		return 1.0
	var max_hp: float = float(player.get("max_hp"))
	if max_hp <= 0.0:
		return 1.0
	return clampf(float(player.get("hp")) / max_hp, 0.0, 1.0)


func total_active_severity() -> float:
	if player == null:
		return 0.0
	var burden: BurdenSnapshot = player.get("last_burden") as BurdenSnapshot
	return burden.total_active if burden != null else 0.0


func haste_bonus() -> float:
	return BurdenResolver.litany_haste(level, total_active_severity(), hp_ratio())


func get_haste_multiplier() -> float:
	return 1.0 + haste_bonus()
