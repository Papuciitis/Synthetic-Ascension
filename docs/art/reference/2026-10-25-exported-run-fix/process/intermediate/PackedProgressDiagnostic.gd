extends "/var/tmp/sa-menu25/tools/tests/PackedFrontEndFlowTest.gd"
var _next_trace: int = 0
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() < _next_trace:
		return false
	_next_trace = Time.get_ticks_msec() + 5000
	var g: Node = root.get_node_or_null("Global")
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status("res://scenes/game.tscn", progress)
	print("PACKED_LOAD_TRACE ", JSON.stringify({"ticks_ms": Time.get_ticks_msec(), "game_status": status, "progress": progress, "transition_active": g.get("_scene_transition_active") if g != null else null, "current_scene": current_scene.scene_file_path if current_scene != null else "none", "paused": paused}))
	return false
