extends MajorChoiceEffect
class_name MCE_TranscendEquippedAugments

## The Engine Prays: every equipped augment that can Transcend does, now,
## whatever its level and catalyst.


func can_apply(g: Node) -> bool:
	return g != null and g.has_method("transcend_equipped_augments")


func apply(g: Node) -> void:
	if can_apply(g):
		g.call("transcend_equipped_augments")
