extends SceneTree

var _passes := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var global := root.get_node("Global")
	global.set("attempt_active", true)
	global.set("attempt_segment", 1)
	global.set("attempt_opening_completed", true)
	if global.get("run_inventory") == null:
		global.call("reset_run_inventory")
	if global.get("run_bag") == null:
		global.call("reset_run_bag_inventory")
	_check(change_scene_to_file("res://scenes/game.tscn") == OK, "segment 1 game scene starts")
	for _frame in range(12):
		await process_frame
	var geometry := current_scene.get_node_or_null("Level1/Level1_Geometry") as Node2D
	_check(geometry != null, "handcrafted geometry exists")
	if geometry != null:
		var remaining_sprites := geometry.find_children("*", "Sprite2D", true, false)
		var map_sprites := remaining_sprites.filter(func(node: Node) -> bool:
			var parent := node.get_parent()
			return parent == null or parent.get_script() == null \
				or String((parent.get_script() as Script).resource_path) != "res://scenes/world/waypoints/WaypointSigil.gd"
		)
		_check(
			map_sprites.is_empty(),
			"handcrafted map geometry contains no non-interactive Sprite2D descendants"
		)
		_check(
			geometry.find_children("*", "TileMapLayer", true, false).is_empty(),
			"handcrafted geometry owns no tile layers"
		)
	var manager := get_first_node_in_group(&"chunk_manager") as Node
	_check(manager != null and not (manager.get("_manual_blocked_cells") as Dictionary).is_empty(), "handcrafted BFS blockers remain populated")
	_check(manager != null and not manager.find_children("WorldTiles_*", "TileMapLayer", false, false).is_empty(), "chunk manager owns handcrafted world tile layers")
	print("Segment1TileIntegrationTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
