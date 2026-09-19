extends Node

# Break-the-game audit P6: the run RNG's state rides the save, so quitting
# before a kill cannot re-roll its drop.
#
# Run: <godot> --headless --path . --quit-after 3000 res://tools/tests/RunRngPersistenceTest.tscn

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	Global.start_new_attempt()
	Global.attempt_active = true
	var rng: RandomNumberGenerator = Global._rng
	rng.state = 123456789
	var save := SaveData.new()
	Global.write_save(save)
	_check(int(save.attempt_rng_state) == 123456789, "write_save carries the run RNG state")
	var first := rng.randi()
	var second := rng.randi()
	_check(int(rng.state) != 123456789, "rolling moves the state on")
	Global.apply_save(save)
	_check(int(Global._rng.state) == 123456789 and Global._rng.randi() == first and Global._rng.randi() == second, "apply_save restores it, so the same rolls come back in the same order")
	Global.attempt_active = false
	var idle := SaveData.new()
	Global.write_save(idle)
	_check(int(idle.attempt_rng_state) == 0, "without a live attempt nothing is carried")
	Global.apply_save(idle)
	_check(Global._rng.randi() != first or Global._rng.randi() != second, "and a zero state is not applied")
	print("RunRngPersistenceTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
