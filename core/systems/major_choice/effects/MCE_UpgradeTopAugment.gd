extends MajorChoiceEffect
class_name MCE_UpgradeTopAugment

## Twin Seal Protocol: the highest-level equipped augment gains `amount`
## levels (the first slot wins a tie).

@export var amount: int = 3


func can_apply(g: Node) -> bool:
	return g != null and top_augment(g) != StringName()


func apply(g: Node) -> void:
	var id := top_augment(g)
	if id == StringName():
		return
	var level := int(g.call("get_augment_level", id))
	g.call("set_augment_level", id, AugmentScaling.clamp_level(level + amount))
	if g.has_signal("permanent_augments_changed"):
		g.permanent_augments_changed.emit(g.get("permanent_augment_ids"))


static func top_augment(g: Node) -> StringName:
	if g == null:
		return StringName()
	var best := StringName()
	var best_level := -1
	for value in g.get("permanent_augment_ids"):
		var id := StringName(str(value))
		if id == StringName():
			continue
		var level := int(g.call("get_augment_level", id))
		if level > best_level:
			best = id
			best_level = level
	return best
