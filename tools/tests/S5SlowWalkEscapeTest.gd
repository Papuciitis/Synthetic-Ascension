extends "res://tools/tests/S5TeachingEscapeTest.gd"
## Paired actual-Game checks of the slow race's production 80 px/s walk.
## Native input, player geometry and normal damage resolution stay enabled.
func _execute() -> void:
	_immortal = false
	_ambient = false
	_expected_results = 6
	for world_seed in [16102026, 16102027, 18102026]:
		if not await _setup_world("tank", world_seed):
			continue
		_player.set("speed", 80.0)
		_check(is_equal_approx(float(_player.call("get_sustained_move_speed")), 80.0), "actual player keeps an 80 px/s walk with no temporary boost")
		var stationary := await _escape_attempt("slam", "stay")
		var walking := await _escape_attempt("slam", "walk")
		_check(int(stationary.get("danger_attempts", 0)) > 0, "slow-walk seed%d stationary control is reached by the real slam" % world_seed)
		_check(int(walking.get("danger_attempts", 1)) == 0 and int(walking.get("dashes", -1)) == 0, "slow-walk seed%d native walking after150ms escapes the full Hurtbox without dash" % world_seed)
	_execution_completed = _results.size() == _expected_results
	_check(_execution_completed, "all six paired actual-Game slow-walk cases completed")
	var out := ProjectSettings.globalize_path(_out)
	DirAccess.make_dir_recursive_absolute(out)
	_write_json(out.path_join("slow-walk-results.json"), {"passes": _passes, "failures": _failures, "speed": 80.0, "cases": _results})
