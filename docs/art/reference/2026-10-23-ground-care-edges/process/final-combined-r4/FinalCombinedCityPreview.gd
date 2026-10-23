extends "/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/stage4-cost-r3/FinalCombinedCityPreview.gd"
## Capture-only cap ownership. Frozen R3 exterior/dimension/still gates inherit.
var _final_cap_settings_events: int = 0


func _prepare_runtime() -> void:
	# SettingsManager emits synchronously after RuntimeApplier.apply_all;
	# parent's later reduced/flash changes can otherwise replace the cap.
	if not SettingsManager.settings_changed.is_connected(_final_capture_settings_applied):
		SettingsManager.settings_changed.connect(_final_capture_settings_applied)
	super._prepare_runtime()


func _final_capture_settings_applied(_section: StringName, _key: StringName, _value: Variant) -> void:
	Engine.max_fps = 20
	_final_cap_settings_events += 1


func _still(name: String) -> void:
	var cap_before: int = Engine.max_fps
	var physics_before: int = Engine.physics_ticks_per_second
	if cap_before != 20 or physics_before != 60:
		_fail("Final capture requires observed 20 FPS cap and unchanged 60 Hz physics before still: " + name)
	await super._still(name)
	if not _final_stills.is_empty():
		var still: Dictionary = _final_stills.back()
		still["render_fps_cap_before_still"] = cap_before
		still["physics_ticks_per_second_before_still"] = physics_before


func _district_evidence() -> Dictionary:
	var result: Dictionary = super._district_evidence()
	result["capture_scene"] = "/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/final-combined-r4/FinalCombinedCityPreview.tscn"
	var combined: Dictionary = result.get("final_combined", {})
	combined["capture_cap_policy"] = {"target_fps":20, "post_apply_settings_events":_final_cap_settings_events, "mechanism":"SettingsManager synchronous post-apply signal; no per-frame cap writes, settings overrides or physics/actor freeze"}
	return result
