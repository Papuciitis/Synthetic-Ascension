extends RefCounted
class_name AccessibilityPresentation


static func typewriter_characters_per_second(preset: StringName) -> float:
	match preset:
		&"instant": return INF
		&"slow": return 30.0
		&"fast": return 100.0
	return 58.0


static func motion_duration(normal_duration: float, reduced: bool) -> float:
	return minf(normal_duration, 0.01) if reduced else normal_duration


static func flash_alpha(full_alpha: float, level: StringName) -> float:
	match level:
		&"off": return 0.0
		&"reduced": return full_alpha * 0.4
	return full_alpha


static func current_typewriter_characters_per_second() -> float:
	if SettingsManager == null:
		return 58.0
	return typewriter_characters_per_second(StringName(SettingsManager.get_value(&"accessibility", &"typewriter_speed", &"normal")))


static func current_motion_duration(normal_duration: float) -> float:
	var reduced := false if SettingsManager == null else bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))
	return motion_duration(normal_duration, reduced)


static func current_flash_alpha(full_alpha: float) -> float:
	var level := &"full" if SettingsManager == null else StringName(SettingsManager.get_value(&"accessibility", &"combat_flash", &"full"))
	return flash_alpha(full_alpha, level)
