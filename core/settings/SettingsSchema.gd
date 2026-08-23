extends RefCounted
class_name SettingsSchema

const SCHEMA_VERSION := 1
const SECTIONS: Array[StringName] = [&"audio", &"video", &"controls", &"accessibility"]
const FRAME_LIMITS: Array[int] = [0, 60, 90, 120, 144, 165, 240, 360]
const WINDOW_MODES: Array[StringName] = [&"windowed", &"borderless", &"fullscreen"]
const VSYNC_MODES: Array[StringName] = [&"off", &"on", &"adaptive"]
const TYPEWRITER_SPEEDS: Array[StringName] = [&"instant", &"slow", &"normal", &"fast"]
const FLASH_LEVELS: Array[StringName] = [&"off", &"reduced", &"full"]


static func defaults() -> Dictionary:
	return {
		&"audio": {
			&"master_volume": 1.0,
			&"master_muted": false,
			&"music_volume": 0.32,
			&"music_muted": false,
			&"sfx_volume": 1.0,
			&"sfx_muted": false,
			&"ui_volume": 1.0,
			&"ui_muted": false,
		},
		&"video": {
			&"window_mode": &"borderless",
			&"resolution": Vector2i(1920, 1080),
			&"vsync": &"on",
			&"frame_limit": 0,
		},
		&"controls": {
			&"controller_deadzone": 0.2,
			&"bindings": {},
		},
		&"accessibility": {
			&"ui_scale": 1.0,
			&"typewriter_speed": &"normal",
			&"reduced_motion": false,
			&"combat_flash": &"full",
			&"damage_numbers": true,
		},
	}


static func normalize(raw: Dictionary) -> Dictionary:
	var result := defaults()
	for section: StringName in SECTIONS:
		var source: Dictionary = raw.get(section, raw.get(String(section), {})) as Dictionary
		for key_variant in result[section].keys():
			var key := StringName(key_variant)
			if source.has(key):
				result[section][key] = source[key]
			elif source.has(String(key)):
				result[section][key] = source[String(key)]

	for key in [&"master_volume", &"music_volume", &"sfx_volume", &"ui_volume"]:
		result[&"audio"][key] = clampf(float(result[&"audio"][key]), 0.0, 1.0)
	for key in [&"master_muted", &"music_muted", &"sfx_muted", &"ui_muted"]:
		result[&"audio"][key] = bool(result[&"audio"][key])

	var window_mode := StringName(result[&"video"][&"window_mode"])
	result[&"video"][&"window_mode"] = window_mode if window_mode in WINDOW_MODES else &"borderless"
	var resolution_variant: Variant = result[&"video"][&"resolution"]
	var resolution := resolution_variant as Vector2i if resolution_variant is Vector2i else Vector2i(1920, 1080)
	result[&"video"][&"resolution"] = Vector2i(clampi(resolution.x, 640, 7680), clampi(resolution.y, 360, 4320))
	var vsync := StringName(result[&"video"][&"vsync"])
	result[&"video"][&"vsync"] = vsync if vsync in VSYNC_MODES else &"on"
	var frame_limit := int(result[&"video"][&"frame_limit"])
	result[&"video"][&"frame_limit"] = frame_limit if frame_limit in FRAME_LIMITS else 0

	result[&"controls"][&"controller_deadzone"] = clampf(float(result[&"controls"][&"controller_deadzone"]), 0.1, 0.9)
	if not result[&"controls"][&"bindings"] is Dictionary:
		result[&"controls"][&"bindings"] = {}
	else:
		result[&"controls"][&"bindings"] = (result[&"controls"][&"bindings"] as Dictionary).duplicate(true)

	result[&"accessibility"][&"ui_scale"] = clampf(float(result[&"accessibility"][&"ui_scale"]), 0.8, 1.5)
	var typewriter := StringName(result[&"accessibility"][&"typewriter_speed"])
	result[&"accessibility"][&"typewriter_speed"] = typewriter if typewriter in TYPEWRITER_SPEEDS else &"normal"
	result[&"accessibility"][&"reduced_motion"] = bool(result[&"accessibility"][&"reduced_motion"])
	result[&"accessibility"][&"damage_numbers"] = bool(result[&"accessibility"][&"damage_numbers"])
	var flash := StringName(result[&"accessibility"][&"combat_flash"])
	result[&"accessibility"][&"combat_flash"] = flash if flash in FLASH_LEVELS else &"full"
	return result
