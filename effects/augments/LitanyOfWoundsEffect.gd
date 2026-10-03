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


## Requiem: the Transcended Litany starts sooner, doubles its cap and pays
## the same number as Power.
func is_requiem() -> bool:
	return Global != null and Global.is_augment_transcended(&"augment_litany_of_wounds")


func haste_bonus() -> float:
	return BurdenResolver.litany_haste(level, total_active_severity(), hp_ratio(), is_requiem())


func get_haste_multiplier() -> float:
	return 1.0 + haste_bonus()


func get_power_multiplier() -> float:
	return 1.0 + haste_bonus() if is_requiem() else 1.0
