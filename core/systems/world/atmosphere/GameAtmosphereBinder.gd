extends Node
## Reads the already selected family; never selects/rerolls a theme. Kept out
## of Game.gd so weather cannot acquire combat, run-state or save ownership.

var _atmosphere: WorldAtmosphere
var _last_key := ""


func _process(_delta: float) -> void:
	var chunks := get_parent().get_node_or_null("ChunkManager") as Node2D
	if chunks == null:
		return
	var atmosphere := chunks.get_node_or_null("WorldAtmosphere") as WorldAtmosphere
	if atmosphere == null:
		return
	if _atmosphere != atmosphere:
		_atmosphere = atmosphere
		_last_key = ""
	var context: StringName = &"institution" if Global.attempt_segment == 1 else &"procedural"
	var family := StringName(chunks.get("district_family"))
	if context == &"procedural" and family == &"":
		return # SegmentProcBuilder has not applied its actual theme yet.
	var reduced := bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))
	var key := "%s/%s/%s" % [context, family, reduced]
	if key != _last_key:
		_last_key = key
		_atmosphere.apply_theme(family, context, reduced)
