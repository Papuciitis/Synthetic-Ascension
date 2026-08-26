extends MajorChoiceEffect
class_name MCE_ModDoctrineRule

@export var rule_key: StringName = &""
@export var multiply: float = 1.0
@export var add: float = 0.0
@export var clamp_min: float = -INF
@export var clamp_max: float = INF
@export var preview_text: String = ""


func can_apply(g: Node) -> bool:
	return g != null and rule_key != StringName() and g.has_method("set_doctrine_rule")


func apply(g: Node) -> void:
	if not can_apply(g):
		return
	var fallback := 1.0 if not is_equal_approx(multiply, 1.0) else 0.0
	var current := float(g.call("get_doctrine_rule", rule_key, fallback))
	var value := (current * multiply) + add
	value = clampf(value, clamp_min, clamp_max)
	g.call("set_doctrine_rule", rule_key, value)


func get_preview_lines(_g: Node) -> PackedStringArray:
	return PackedStringArray(["• " + preview_text]) if not preview_text.is_empty() else PackedStringArray()
