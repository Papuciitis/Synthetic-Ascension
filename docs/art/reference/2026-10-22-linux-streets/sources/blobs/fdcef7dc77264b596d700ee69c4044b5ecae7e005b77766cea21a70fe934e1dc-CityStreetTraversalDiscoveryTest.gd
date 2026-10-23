extends "res://tools/dev/CityStreetTraversalProbe.gd"
## The route's staged search must stream a distant candidate before asking
## ChunkManager whether it is walkable. Real unloaded cells stay unwalkable.

func _run() -> void:
	_player = CharacterBody2D.new()
	_player.add_to_group(&"player")
	add_child(_player)
	_chunks = ChunkManager.new()
	_chunks.generation_enabled = false
	_chunks.ground_enabled = false
	_chunks.ground_splat_enabled = false
	_chunks.decals_enabled = false
	_chunks.deco_enabled = false
	_chunks.world_atmosphere_enabled = false
	_chunks.use_camera_stream_bounds = false
	_chunks.load_radius = 0
	_chunks.unload_radius = 1
	add_child(_chunks)
	_chunks.start_streaming(_player.global_position)
	var coord := Vector2i(6, -4)
	var desired := (Vector2(coord) + Vector2.ONE * 0.5) * _chunks.chunk_size_px
	var cell := _chunks.world_to_cell(desired)
	var failures: Array[String] = []
	if _chunks.is_cell_walkable(cell):
		failures.append("unloaded candidate unexpectedly walkable")
	if not has_method("_stream_walkable_near"):
		failures.append("passage search has no stream-before-query operation")
	else:
		var result: Vector2 = await call("_stream_walkable_near", desired)
		if result == Vector2.INF or _chunks._world_to_chunk(result) != coord:
			failures.append("distant candidate was not streamed and resolved")
		if not _chunks.is_cell_walkable(cell) or _chunks._current_center != coord:
			failures.append("candidate search did not complete ordinary chunk streaming")
		# The search result must still reject a loaded blocked centre and choose
		# an actual nearby free cell, rather than treating streaming as arrival.
		_chunks._manual_blocked_cells[cell] = true
		var nearby: Vector2 = await call("_stream_walkable_near", desired)
		if nearby == Vector2.INF or _chunks.world_to_cell(nearby) == cell:
			failures.append("candidate search returned its blocked staging cell")
	for failure: String in failures:
		push_error(failure)
	print("CityStreetTraversalDiscoveryTest: failures=%d" % failures.size())
	get_tree().quit(1 if not failures.is_empty() else 0)
