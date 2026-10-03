extends MajorChoiceEffect
class_name MCE_AddStyleMutation

## Second Hand: the native attack mutation for the run's style - Twin Cut
## (melee), Scatter (ranged), Tri-Sigil (magic). player.gd reads them.

const BY_STYLE := {
	&"melee": &"mut_melee_dual_slash",
	&"ranged": &"mut_ranged_shotgun",
	&"magic": &"mut_magic_trisigil",
}


func can_apply(g: Node) -> bool:
	return g != null and g.has_method("add_mutation")


func apply(g: Node) -> void:
	if not can_apply(g):
		return
	var style := StringName(str(g.get("selected_style_id")))
	g.call("add_mutation", BY_STYLE.get(style, &"mut_ranged_shotgun"), true)
