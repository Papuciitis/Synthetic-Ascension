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
		var level := current_scene.get_node("Level1")
		var half_cells: Dictionary = level.get("_half_cells")
		var block_renderer: Variant = level.get("_wall_renderer")
		var expected: Dictionary = {}
		for key in half_cells:
			var cell: Vector2i = key
			var at := (Vector2(cell) + Vector2(0.5, 0.5)) * float(level.get("cell_size_px"))
			var path := ChunkBlockVisualCatalog.half_texture(CoverHalfLab.half_variant(at)).resource_path
			expected[path] = int(expected.get(path, 0)) + 1
		var actual: Dictionary = {}
		if block_renderer != null:
			for batch: ChunkBlockRenderer.TextureBatch in block_renderer._batches.values():
				if expected.has(batch.texture.resource_path):
					actual[batch.texture.resource_path] = int(actual.get(batch.texture.resource_path, 0)) + batch.transforms.size()
		_check(not expected.is_empty() and actual == expected, "actual segment 1 batches every authored half-cover with its deterministic matching art")
		var generated := 0
		for path: String in actual:
			if path.begins_with("res://assets/world/dressing/generated/"):
				generated += int(actual[path])
		_check(generated > 0, "actual segment 1 displays generated crate, rubble and pillar art")
	var manager := get_first_node_in_group(&"chunk_manager") as Node
	_check(manager != null and not (manager.get("_manual_blocked_cells") as Dictionary).is_empty(), "handcrafted BFS blockers remain populated")
	_check(manager != null and not manager.find_children("WorldTiles_*", "TileMapLayer", false, false).is_empty(), "chunk manager owns handcrafted world tile layers")
	print("Segment1TileIntegrationTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
