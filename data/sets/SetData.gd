extends Resource
class_name SetData

@export var id: StringName
@export var display_name: String = ""
@export var tiers: Array[SetTier] = []

func active_tiers(count: int) -> Array[SetTier]:
	var out: Array[SetTier] = []
	for t in tiers:
		if t != null and count >= t.required_count:
			out.append(t)
	out.sort_custom(func(a: SetTier, b: SetTier) -> bool:
		return a.required_count < b.required_count
	)
	return out
