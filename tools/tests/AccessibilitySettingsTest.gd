extends SceneTree

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
	var policy := load("res://core/settings/AccessibilityPresentation.gd") as Script
	_check(policy != null, "accessibility presentation policy loads")
	if policy != null:
		_check(is_inf(float(policy.call("typewriter_characters_per_second", &"instant"))), "Instant text has no timed reveal")
		_check(float(policy.call("typewriter_characters_per_second", &"slow")) == 30.0, "Slow text uses 30 characters per second")
		_check(float(policy.call("typewriter_characters_per_second", &"normal")) == 58.0, "Normal text preserves current speed")
		_check(float(policy.call("typewriter_characters_per_second", &"fast")) == 100.0, "Fast text uses 100 characters per second")
		_check(float(policy.call("motion_duration", 0.75, true)) == 0.01, "reduced motion minimizes cosmetic tween duration")
		_check(float(policy.call("motion_duration", 0.75, false)) == 0.75, "normal motion preserves cosmetic tween duration")
		_check(is_equal_approx(float(policy.call("flash_alpha", 0.95, &"reduced")), 0.38), "reduced flashes lower peak opacity")
		_check(float(policy.call("flash_alpha", 0.95, &"off")) == 0.0, "disabled flashes remove decorative opacity")
	print("AccessibilitySettingsTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
