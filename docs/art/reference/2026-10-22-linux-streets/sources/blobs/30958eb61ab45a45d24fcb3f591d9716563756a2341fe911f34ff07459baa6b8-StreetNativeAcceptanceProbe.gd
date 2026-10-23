extends "res://tools/dev/CityStreetTraversalProbe.gd"
## Observation-only wrapper around the unchanged real-physics route. The
## inherited _enter_tree records _save_writes_before after isolating saves.
var _street_render_fps: int = 60


func _enter_tree() -> void:
	super._enter_tree()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--runtime-fps="):
			var requested: String = arg.trim_prefix("--runtime-fps=")
			if requested not in ["20", "30", "60"]:
				_fail("Street acceptance runtime FPS must be explicitly 20, 30 or 60")
			else:
				_street_render_fps = int(requested)


func _prepare_runtime() -> void:
	super._prepare_runtime()
	Engine.max_fps = _street_render_fps


func _shutdown() -> void:
	# The parent writes its manifest before queuing Game for deletion. Observe
	# the actual API counter at that same acceptance endpoint, not save files.
	var writes_after: int = SaveManager.debug_save_writes
	var writes: int = writes_after - _save_writes_before
	if writes != 0 or SaveManager.current_save != null:
		_fail("Street native acceptance selected a profile or wrote a save")
	if _report.is_empty():
		_report = {"capture_scene": "res://tools/dev/CityStreetTraversalProbe.tscn", "args": OS.get_cmdline_user_args(), "segment": _city_segment, "world_seed": _city_world_seed, "discovery": _discovery, "staging": _staging, "encounter_director_start": _director_start, "failures": _failures}
	_report["failures"] = _failures
	_report["acceptance_entrypoint"] = "/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/StreetNativeAcceptanceProbe.tscn"
	_report["save_observation"] = {"baseline_api_counter": _save_writes_before, "acceptance_end_api_counter": writes_after, "writes_during_acceptance": writes, "current_profile_is_null": SaveManager.current_save == null, "autosave_disabled": Global.debug_disable_autosave, "scope": "Inherited isolated setup through final route acceptance, before Game teardown; counters are read from SaveManager, not inferred from absent files."}
	_report["runtime_fixture"] = {"engine_max_fps": Engine.max_fps, "physics_ticks_per_second": Engine.physics_ticks_per_second, "actual_window": str(get_window().size), "game_was_instantiated": _game != null}
	await super._shutdown()
