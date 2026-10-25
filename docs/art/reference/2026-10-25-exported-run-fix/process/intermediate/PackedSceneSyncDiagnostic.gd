extends "/var/tmp/sa-menu25/tools/tests/PackedFrontEndFlowTest.gd"
var _retained: Resource
func _run() -> void:
	print("SCENE_SYNC_DIAGNOSTIC before game.tscn")
	_retained = load("res://scenes/game.tscn")
	print("SCENE_SYNC_DIAGNOSTIC after game.tscn loaded=", _retained != null)
	await super._run()
