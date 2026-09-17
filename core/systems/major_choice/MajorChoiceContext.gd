extends RefCounted
class_name MajorChoiceContext

var stage_id: StringName = &""
var source_segment: int = 0
var style_id: StringName = &""
var augment_ids: Array[StringName] = []
var augment_levels: Dictionary = {}
var set_piece_counts: Dictionary = {}
var prior_family_ids: Array[StringName] = []
var tags: Dictionary = {}


static func from_global(g: Node, next_stage: StringName) -> RefCounted:
	var own_script := load("res://core/systems/major_choice/MajorChoiceContext.gd") as Script
	var context: RefCounted = own_script.new()
	context.stage_id = next_stage
	if g == null:
		return context
	context.source_segment = int(g.call("get_major_choice_context_segment")) if g.has_method("get_major_choice_context_segment") else int(g.get("attempt_segment"))
	context.style_id = StringName(str(g.get("selected_style_id")))
	context.tags[StringName("style:%s" % String(context.style_id))] = true
	var equipped: Array = g.get("permanent_augment_ids")
	for value in equipped:
		var augment_id := StringName(str(value))
		if augment_id == StringName():
			continue
		context.augment_ids.append(augment_id)
		var augment_data: AugmentData = g.get("augment_db").get(augment_id, null) as AugmentData
		if _augment_has_active_input(augment_data):
			context.tags[&"active_augment"] = true
		if g.has_method("get_augment_level"):
			context.augment_levels[augment_id] = int(g.call("get_augment_level", augment_id))
	var inventory := g.get("run_inventory") as Inventory
	if inventory != null:
		context.set_piece_counts = inventory.get_set_counts().duplicate(true)
		for set_variant in context.set_piece_counts.keys():
			if int(context.set_piece_counts[set_variant]) > 0:
				context.tags[StringName("set:%s" % str(set_variant))] = true
	var stage_ids: Dictionary = g.get("attempt_doctrine_stage_ids") if g.get("attempt_doctrine_stage_ids") != null else {}
	for selected_variant in stage_ids.values():
		var selected_id := StringName(str(selected_variant))
		if g.get("major_choice_db") == null:
			continue
		var definition: MajorChoiceDef = g.get("major_choice_db").get_def(selected_id)
		if definition != null and definition.family_id != StringName():
			context.prior_family_ids.append(definition.family_id)
			context.tags[StringName("family:%s" % String(definition.family_id))] = true
	return context


static func _augment_has_active_input(data: AugmentData) -> bool:
	if data == null:
		return false
	for scene in data.effect_scenes:
		if scene == null:
			continue
		var effect := scene.instantiate()
		for property_info in effect.get_property_list():
			if StringName(property_info.get("name", "")) == &"active_action":
				effect.free()
				return true
		effect.free()
	return false
