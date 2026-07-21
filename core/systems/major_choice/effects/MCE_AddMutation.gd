extends MajorChoiceEffect
class_name MCE_AddMutation

@export var mutation_id: StringName = &""
@export var value: Variant = true

func can_apply(g: Node) -> bool:
	return g != null and mutation_id != StringName()

func apply(g: Node) -> void:
	if g == null or mutation_id == StringName():
		return
	if g.has_method("add_mutation"):
		g.add_mutation(mutation_id, value)
	else:
		# Fallback: write to dictionary if present
		var d: Dictionary = g.get("attempt_mutations")
		d[String(mutation_id)] = value
		g.set("attempt_mutations", d)

func get_preview_lines(_g: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if mutation_id == StringName():
		return out
	var id := String(mutation_id)

	var pretty := ""
	match id:
		"mut_melee_dual_slash":
			pretty = "Melee mutation: Dual Slash"
		"mut_ranged_shotgun":
			pretty = "Ranged mutation: Scatter Doctrine"
		"mut_magic_trisigil":
			pretty = "Magic mutation: Tri-Sigil"
		_:
			pretty = "Mutation: %s" % id

	out.append("• " + pretty)
	return out
