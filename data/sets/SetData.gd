extends Resource
class_name SetData

@export var id: StringName
@export var display_name: String = ""
@export_multiline var identity_sentence: String = ""
@export_multiline var playstyle: String = ""
@export_multiline var best_with: String = ""
@export var emblem_shape: StringName = &"ring"
@export var accent_color: Color = Color(1.0, 0.55, 0.20)
@export_multiline var shape_language: String = ""
@export var active_ability_name: String = ""
@export_multiline var active_ability_requirements: String = ""
@export var glossary: Dictionary = {}
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

func sorted_tiers() -> Array[SetTier]:
	var out: Array[SetTier] = tiers.duplicate()
	out.sort_custom(func(a: SetTier, b: SetTier) -> bool:
		return a.required_count < b.required_count
	)
	return out

func next_tier(count: int) -> SetTier:
	for tier: SetTier in sorted_tiers():
		if tier != null and tier.required_count > count:
			return tier
	return null

func max_pieces() -> int:
	var maximum: int = 0
	for tier: SetTier in tiers:
		if tier != null:
			maximum = maxi(maximum, tier.required_count)
	return maximum
