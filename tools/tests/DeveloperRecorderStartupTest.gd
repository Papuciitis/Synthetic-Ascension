extends Node

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
	PerformanceFlightRecorder.set_enabled(false)
	Global.debug_performance_lab = false
	var packed := load("res://ui/screens/MainMenu.tscn") as PackedScene
	_check(packed != null, "main menu scene loads")
	if packed == null:
		_finish()
		return
	var menu := packed.instantiate()
	add_child(menu)
	await get_tree().process_frame
	_check(not PerformanceFlightRecorder.enabled, "main menu starts with capture disabled")
	_check(menu.has_method("arm_developer_flight_recorder"), "main menu exposes developer recorder arming")
	if menu.has_method("arm_developer_flight_recorder"):
		Global.debug_performance_lab = false
		menu.call("arm_developer_flight_recorder")
		_check(PerformanceFlightRecorder.enabled, "developer recorder arms while overlay is hidden")
		_check(not Global.debug_performance_lab, "arming preserves hidden overlay state")

		PerformanceFlightRecorder.set_enabled(false)
		Global.debug_performance_lab = true
		menu.call("arm_developer_flight_recorder")
		_check(PerformanceFlightRecorder.enabled, "developer recorder arms while overlay is visible")
		_check(Global.debug_performance_lab, "arming preserves visible overlay state")
	menu.queue_free()
	await get_tree().process_frame
	_finish()


func _finish() -> void:
	PerformanceFlightRecorder.set_enabled(false)
	Global.debug_performance_lab = false
	Global.debug_dev_mode = false
	print("DeveloperRecorderStartupTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
