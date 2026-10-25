extends "/var/tmp/sa-menu25/tools/tests/PackedFrontEndFlowTest.gd"

var _retained: Array[Resource] = []
func _run() -> void:
	for path: String in ["res://ui/screens/Segment1NarrativeOverlay.tscn", "res://core/systems/world/opening/OpeningSequenceController.tscn", "res://scenes/world/dev_segment/DevSegment.tscn", "res://ui/screens/PauseMenu.tscn"]:
		print("SYNC_DIAGNOSTIC before ", path, " exists=", ResourceLoader.exists(path))
		var value := load(path)
		_retained.append(value)
		print("SYNC_DIAGNOSTIC after ", path, " loaded=", value != null)
	await super._run()
