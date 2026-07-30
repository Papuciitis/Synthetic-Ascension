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
	global.set("attempt_segment", 2)
	global.set("attempt_opening_completed", true)
	if global.get("run_inventory") == null:
		global.call("reset_run_inventory")
	if global.get("run_bag") == null:
		global.call("reset_run_bag_inventory")
	var error := change_scene_to_file("res://scenes/game.tscn")
	_check(error == OK, "segment 2 game scene starts")
	for _frame in range(12):
		await process_frame
	var manager := get_first_node_in_group(&"chunk_manager") as Node
	_check(manager != null, "runtime chunk manager exists")
	if manager != null:
		manager.call("process_chunk_generation_queue", 25)
		await process_frame
		await process_frame
		var stats := manager.call("get_tiled_render_stats") as Dictionary
		print("Runtime tiled world stats: ", stats)
		_check(int(stats.get("cells", 0)) > 0, "runtime procedural segment paints tile cells")
		_check(int(stats.get("layers", 0)) > 0, "runtime procedural segment owns bounded tile layers")
		_check(int(manager.call("loaded_chunk_count")) > 0, "runtime chunk streaming remains active")
		var blocked := manager.get("_blocked_cells") as Dictionary
		_check(not blocked.is_empty(), "runtime BFS blocked-cell data remains populated")
		var sprite_count := 0
		var chunk_layer_count := 0
		for chunk_variant in (manager.get("_chunks") as Dictionary).values():
			var chunk := chunk_variant as Node2D
			if chunk != null:
				sprite_count += chunk.find_children("*", "Sprite2D", true, false).size()
				chunk_layer_count += chunk.find_children("*", "TileMapLayer", true, false).size()
		_check(sprite_count == 0, "streamed chunks contain zero Sprite2D descendants")
		_check(chunk_layer_count == 0, "streamed chunks contain zero TileMapLayer descendants")
		var manager_layers := manager.find_children("WorldTiles_*", "TileMapLayer", false, false)
		_check(not manager_layers.is_empty() and manager_layers.size() <= 12, "chunk manager owns a bounded persistent tile-layer set")
	_check(get_first_node_in_group(&"flow_field_nav") != null, "runtime flow-field navigation remains active")
	print("WorldTileIntegrationTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
