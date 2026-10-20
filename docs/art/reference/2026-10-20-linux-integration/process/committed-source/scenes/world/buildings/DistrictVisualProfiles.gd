extends RefCounted
## Pure presentation selection. Physical templates and the selected theme keep
## their existing owners; callers receive independent per-building data.

static func resolve(family: StringName) -> Dictionary:
	var profile: StringName = &"checkpoint_guard_loggia" if family == &"checkpoint_lanes" else &"common_base"
	return {
		"family_id": family,
		"profile_id": profile,
		"roof_form_set_id": profile,
		"facade_form_set_id": profile,
	}
