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
	var aim_state_script := load("res://core/actors/player/PlayerAimState.gd") as Script
	_check(aim_state_script != null, "player aim state loads")
	if aim_state_script != null:
		var aim = aim_state_script.new()
		_check(not aim.using_controller(), "mouse aim is the startup mode")
		_check(aim.resolve_target(Vector2(10, 20), Vector2(90, 40), 100.0) == Vector2(90, 40), "mouse mode uses cursor target")
		_check(not aim.update_stick(Vector2(0.1, 0.0), 0.2), "sub-deadzone stick does not steal aim")
		_check(aim.update_stick(Vector2(0.0, -1.0), 0.2), "valid right stick selects controller aim")
		_check(aim.resolve_target(Vector2(10, 20), Vector2.ZERO, 100.0) == Vector2(10, -80), "controller aim projects directly along stick")
		aim.update_stick(Vector2.ZERO, 0.2)
		_check(aim.direction() == Vector2.UP, "centered stick retains last valid direction")
		aim.note_mouse_motion()
		_check(not aim.using_controller(), "mouse motion returns control to cursor aim")
	print("PlayerAimStateTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
