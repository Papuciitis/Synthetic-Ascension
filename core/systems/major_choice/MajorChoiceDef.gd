extends Resource
class_name MajorChoiceDef

@export var id: StringName = &""
@export var title: String = "Major Choice"
@export_multiline var description: String = ""

@export var icon: Texture2D = null

@export var enabled: bool = true
@export var stage: StringName = &"method"
@export var offer_role: StringName = &"amplify"
@export var family_id: StringName = &""
@export_multiline var gift_text: String = ""
@export_multiline var price_text: String = ""
@export_multiline var consequence_text: String = ""
@export var build_tags: Array[StringName] = []
@export var base_offer_score: float = 1.0

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
	if not enabled:
		return false
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


func is_doctrine_complete() -> bool:
	return (
		enabled
		and stage in [&"method", &"doctrine", &"apotheosis"]
		and offer_role in [&"amplify", &"transfigure", &"covenant"]
		and family_id != StringName()
		and not gift_text.strip_edges().is_empty()
		and not price_text.strip_edges().is_empty()
		and not consequence_text.strip_edges().is_empty()
	)


func score_for(context: RefCounted) -> float:
	var score := base_offer_score
	if context == null:
		return score
	var context_tags: Dictionary = context.get("tags")
	for tag in build_tags:
		if context_tags.has(tag):
			score += 10.0
	if context_tags.has(StringName("family:%s" % String(family_id))):
		score += 25.0
	return score

func preview_lines(g: Node) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for e in effects:
		if e == null:
			continue
		var lines: PackedStringArray = e.get_preview_lines(g)
		for l in lines:
			out.append(l)
	return out
