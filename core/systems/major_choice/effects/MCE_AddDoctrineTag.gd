extends MajorChoiceEffect
class_name MCE_AddDoctrineTag

@export var rule_key: StringName = &""
@export var value: Variant = true
@export var preview_text: String = ""


func can_apply(g: Node) -> bool:
	return g != null and rule_key != StringName() and g.has_method("set_doctrine_rule")


func apply(g: Node) -> void:
	if can_apply(g):
		g.call("set_doctrine_rule", rule_key, value)


func get_preview_lines(_g: Node) -> PackedStringArray:
	return PackedStringArray(["• " + preview_text]) if not preview_text.is_empty() else PackedStringArray()
