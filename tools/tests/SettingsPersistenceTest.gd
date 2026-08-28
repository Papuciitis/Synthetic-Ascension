extends SceneTree

const TEST_PATH := "user://tests/settings_test.cfg"

var _passes := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	_cleanup()
	var schema_script := load("res://core/settings/SettingsSchema.gd") as Script
	var store_script := load("res://core/settings/SettingsStore.gd") as Script
	_check(schema_script != null, "settings schema loads")
	_check(store_script != null, "settings store loads")
	if schema_script != null and store_script != null:
		var defaults: Dictionary = schema_script.call("defaults")
		_check(defaults[&"audio"][&"master_volume"] == 1.0, "master defaults to full volume")
		_check(defaults[&"accessibility"][&"typewriter_speed"] == &"normal", "typewriter defaults to normal")
		var store = store_script.new(TEST_PATH)
		var values := defaults.duplicate(true)
		values[&"audio"][&"music_volume"] = 0.42
		_check(store.save_settings(values), "isolated settings save succeeds")
		_check(is_equal_approx(float(store.load_settings()[&"audio"][&"music_volume"]), 0.42), "music volume round-trips")

		values[&"audio"][&"music_volume"] = 0.73
		_check(store.save_settings(values), "second settings generation saves")
		var primary := FileAccess.open(TEST_PATH, FileAccess.WRITE)
		primary.store_string("this is not a config")
		primary.close()
		_check(is_equal_approx(float(store.load_settings()[&"audio"][&"music_volume"]), 0.42), "corrupt primary falls back to previous generation")

		# A file from a newer schema is read best-effort (normalize clamps and
		# drops unknown keys) rather than thrown away; only its version is
		# reported. Wiping a player's settings on a downgrade would be worse than
		# reading them.
		var newer := ConfigFile.new()
		newer.set_value("schema", "version", int(schema_script.get("SCHEMA_VERSION")) + 1)
		newer.set_value("audio", "music_volume", 0.31)
		newer.set_value("audio", "future_only_key", 7)
		_check(newer.save(TEST_PATH) == OK, "fixture: a newer-schema settings file is written")
		var from_newer: Dictionary = store.load_settings()
		_check(is_equal_approx(float(from_newer[&"audio"][&"music_volume"]), 0.31), "a newer-schema file is still read")
		_check(not from_newer[&"audio"].has(&"future_only_key"), "unknown keys from a newer schema are dropped")
		_check(store.last_loaded_schema_version == int(schema_script.get("SCHEMA_VERSION")) + 1, "the store reports the schema version it read (got %d)" % store.last_loaded_schema_version)

		var malformed := {
			&"audio": {&"master_volume": 12.0},
			&"video": {&"frame_limit": 17},
			&"accessibility": {&"ui_scale": 9.0, &"typewriter_speed": &"warp"},
		}
		var normalized: Dictionary = schema_script.call("normalize", malformed)
		_check(normalized[&"audio"][&"master_volume"] == 1.0, "volume clamps to one")
		_check(normalized[&"video"][&"frame_limit"] == 0, "unsupported frame limit falls back to unlimited")
		_check(normalized[&"accessibility"][&"ui_scale"] == 1.5, "UI scale clamps to 150 percent")
		_check(normalized[&"accessibility"][&"typewriter_speed"] == &"normal", "unknown text speed uses default")
		# Damage numbers and ability callouts are two settings, not one. A save
		# written before the split has neither key here, and both must come back
		# ON - silently defaulting callouts off would mute the whole
		# Manifestation layer for every existing profile.
		_check(bool(defaults[&"accessibility"][&"damage_numbers"]), "damage numbers default on")
		_check(bool(defaults[&"accessibility"][&"ability_callouts"]), "ability callouts default on")
		_check(
			bool(normalized[&"accessibility"][&"ability_callouts"]),
			"a settings file predating the split still gets callouts on"
		)
	_cleanup()
	print("SettingsPersistenceTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func _cleanup() -> void:
	for path in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
