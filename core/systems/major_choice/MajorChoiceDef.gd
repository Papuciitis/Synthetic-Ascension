extends Resource
class_name MajorChoiceDef

@export var id: StringName = &""
@export var title: String = "Major Choice"
@export_multiline var description: String = ""

@export var icon: Texture2D = null

# Offer-bucketing / classification (used for Segment 5 'big choice' moments).
# Suggested categories: &"augment", &"style", &"utility"
@export var category: StringName = &""

# Availability constraints
@export var min_segment: int = 1
@export var max_segment: int = 999
@export var requires_style_id: StringName = &"" # e.g. &"melee", &"ranged", &"magic"
@export var requires_any_permanent_augment: bool = false
@export var requires_augment_ids: Array[StringName] = []
@export var unique_per_attempt: bool = true

# Applied in order
@export var effects: Array[MajorChoiceEffect] = []

func is_available(g: Node) -> bool:
	if id == StringName():
		return false
	if g == null:
		return false

	var seg: int = int(g.call("get_major_choice_context_segment")) if g.has_method("get_major_choice_context_segment") else (int(g.get("attempt_segment")) if g.has_method("get") else 1)
	if seg < min_segment or seg > max_segment:
		return false

	var style_id: StringName = StringName(str(g.get("selected_style_id"))) if g.has_method("get") else &""
	if requires_style_id != StringName() and style_id != requires_style_id:
		return false

	if requires_any_permanent_augment:
		var arr: Array = g.get("permanent_augment_ids")
		var any := false
		for a in arr:
			if a != StringName():
				any = true
				break
		if not any:
			return false

	if not requires_augment_ids.is_empty():
		var arr2: Array = g.get("permanent_augment_ids")
		var have: Dictionary = {}
		for a2 in arr2:
			have[a2] = true
		for req in requires_augment_ids:
			if not have.has(req):
				return false

	# Effects may have extra gating
	for e in effects:
		if e != null and e.has_method("can_apply") and not e.can_apply(g):
			return false

	return true

func preview_lines(g: Node) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for e in effects:
		if e == null:
			continue
		var lines: PackedStringArray = e.get_preview_lines(g)
		for l in lines:
			out.append(l)
	return out
