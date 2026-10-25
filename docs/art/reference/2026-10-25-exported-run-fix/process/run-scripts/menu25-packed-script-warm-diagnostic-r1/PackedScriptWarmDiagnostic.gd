extends "/var/tmp/sa-menu25/tools/tests/PackedFrontEndFlowTest.gd"
var _retained: Resource
func _run() -> void:
	print("SCRIPT_WARM_DIAGNOSTIC before sync game.gd")
	_retained = load("res://scenes/game.gd")
	print("SCRIPT_WARM_DIAGNOSTIC after sync game.gd loaded=", _retained != null)
	await super._run()
