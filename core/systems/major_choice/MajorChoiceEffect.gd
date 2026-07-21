extends Resource
class_name MajorChoiceEffect
## Base class for an effect applied when a Major Choice is committed.
## Keep effects small and composable; author choices as .tres in res://data/major_choices/

func can_apply(_g: Node) -> bool:
	return true

func apply(_g: Node) -> void:
	pass

func get_preview_lines(_g: Node) -> PackedStringArray:
	return PackedStringArray()
