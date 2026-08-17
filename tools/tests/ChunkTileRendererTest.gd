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
	var renderer_script := load("res://core/systems/world/ChunkTileRenderer.gd") as Script
	_check(renderer_script != null, "chunk tile renderer script loads")
	if renderer_script == null:
		_finish()
		return

	var renderer = renderer_script.new()
	_check(renderer != null, "chunk tile renderer can be created")
	_check(renderer.has_method("begin_chunk"), "renderer exposes chunk setup")
	_check(renderer.has_method("paint_texture"), "renderer exposes tile painting")
	_check(renderer.has_method("paint_sprite"), "renderer exposes transformed sprite painting")
	_check(renderer.has_method("get_chunk_stats"), "renderer exposes diagnostics")

	var tile_host := Node2D.new()
	root.add_child(tile_host)
	var chunk := Node2D.new()
	tile_host.add_child(chunk)
	renderer.configure_host(tile_host, 64)
	chunk.set_meta(&"_chunk_tile_coord", Vector2i.ZERO)
	chunk.set_meta(&"_chunk_cells_per_side", 32)
	renderer.begin_chunk(chunk, 64)
	var texture := ImageTexture.create_from_image(Image.create(64, 64, false, Image.FORMAT_RGBA8))
	_check(renderer.paint_texture(chunk, &"structure", Vector2i(3, 4), texture, 0), "renderer paints a structure tile")
	_check(renderer.paint_texture(chunk, &"structure", Vector2i(4, 4), texture, 0), "renderer reuses the structure layer")
	var stats: Dictionary = renderer.get_chunk_stats(chunk)
	_check(int(stats.get("layers", 0)) == 1, "two structure tiles use one layer")
	_check(int(stats.get("cells", 0)) == 2, "renderer reports painted cells")
	_check(renderer.erase_cell(chunk, &"structure", Vector2i(4, 4)), "renderer erases dynamic structure tile")
	_check(int(renderer.get_chunk_stats(chunk).get("cells", 0)) == 1, "erased tile updates diagnostics")

	renderer.enabled = false
	_check(not renderer.paint_texture(chunk, &"structure", Vector2i(5, 4), texture, 0), "disabled renderer leaves legacy path available")
	_check(int(renderer.get_chunk_stats(chunk).get("cells", 0)) == 1, "disabled renderer does not mutate tiled output")
	var persistent_layer_count := tile_host.find_children("WorldTiles_*", "TileMapLayer", false, false).size()
	renderer.enabled = true
	renderer.clear_chunk(chunk)
	_check(int(renderer.get_chunk_stats(chunk).get("cells", 0)) == 1, "chunk clear does not mutate historical diagnostics")
	_check(tile_host.find_children("WorldTiles_*", "TileMapLayer", false, false).size() == persistent_layer_count, "chunk clear preserves persistent layers")
	var cleared_layer := tile_host.find_children("WorldTiles_*", "TileMapLayer", false, false)[0] as TileMapLayer
	_check(cleared_layer.get_used_cells().is_empty(), "chunk clear erases its cells from persistent layers")

	tile_host.queue_free()
	await process_frame

	var manager_script := load("res://core/systems/world/ChunkManager.gd") as Script
	var manager = manager_script.new()
	manager.tiled_world_rendering = true
	manager.world_seed = 424242
	manager.ground_enabled = true
	manager.decals_enabled = false
	manager.deco_enabled = false
	manager.sites_enabled = false
	manager.debug_draw_chunk_outlines = false
	manager.debug_force_content = true
	manager.weight_empty = 0.0
	manager.weight_building = 1.0
	manager.weight_ruins = 0.0
	manager.cover_full_scene = load("res://scenes/world/cover/CoverFull.tscn") as PackedScene
	manager.cover_window_scene = load("res://scenes/world/cover/CoverWindow.tscn") as PackedScene
	manager.cover_half_scene = load("res://scenes/world/cover/CoverHalf.tscn") as PackedScene
	root.add_child(manager)
	var generated_chunk := manager.call("_create_chunk", Vector2i.ZERO) as Node2D
	manager.set("_chunks", {Vector2i.ZERO: generated_chunk})
	await process_frame
	var generated_stats: Dictionary = manager.call("get_chunk_render_stats")
	_check(int(generated_stats.get("ground_sprites", 0)) == 1, "procedural chunk keeps one region-repeated ground sprite")
	_check(int(generated_stats.get("floor_sprites", 0)) > 0, "procedural floor stamps stay as region sprites")
	_check(int(generated_stats.get("block_instances", 0)) > 0, "procedural blockers use MultiMesh instances")
	_check(int(generated_stats.get("procedural_tile_cells", -1)) == 0, "procedural generation paints zero TileMap cells")
	_check(generated_chunk.find_children("*", "TileMapLayer", true, false).is_empty(), "procedural chunk owns no tile layers")
	_check(manager.find_children("WorldTiles_*", "TileMapLayer", false, false).is_empty(), "procedural generation creates no shared tile layers")
	var per_block_sprites := 0
	for sprite in generated_chunk.find_children("*", "Sprite2D", true, false):
		if sprite.get_parent() is StaticBody2D:
			per_block_sprites += 1
	_check(per_block_sprites == 0, "procedural blockers create no per-block sprites")
	manager.queue_free()
	await process_frame

	var level_script := load("res://core/systems/world/Level1Builder.gd") as Script
	var level = level_script.new()
	_check(level.has_method("_tile_authored_geometry"), "handcrafted segment exposes tile conversion")
	var authored_manager = manager_script.new()
	authored_manager.tiled_world_rendering = true
	root.add_child(authored_manager)
	var authored_geo := Node2D.new()
	root.add_child(authored_geo)
	var authored_block := (load("res://scenes/world/cover/CoverFull.tscn") as PackedScene).instantiate() as Node2D
	authored_block.position = Vector2(-96, 160)
	authored_block.set_meta(&"_tile_repeat_visual", true)
	authored_geo.add_child(authored_block)
	authored_block.set("connections_mask", 5)
	level.set("_cm", authored_manager)
	level.set("_geo", authored_geo)
	level.call("_tile_authored_geometry")
	await process_frame
	_check(authored_block.get_node_or_null("Sprite2D") == null, "handcrafted geometry uses tile visuals")
	_check(authored_block.get_node_or_null("CollisionN") != null, "handcrafted geometry retains collision shapes")
	authored_block.set("connections_mask", 10)
	await process_frame
	var collision_n := authored_block.get_node("CollisionN") as CollisionShape2D
	var collision_e := authored_block.get_node("CollisionE") as CollisionShape2D
	_check(collision_n.disabled and not collision_e.disabled, "collision connections still refresh after sprite removal")
	_check(authored_manager.erase_repeated_visual(authored_geo, Vector2i(-2, 2)), "handcrafted barrier tiles can be erased")
	level.free()
	authored_manager.queue_free()
	authored_geo.queue_free()
	await process_frame
	_finish()
func _finish() -> void:
	print("ChunkTileRendererTest: %d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)
