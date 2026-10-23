extends Node
## Cache lifetime across real segment maintenance changes. Existing nodes and
## batches own their textures; the shared warm cache owns only the next state.
const KIT := preload("res://core/systems/world/chunks/PlazaEdgeKit.gd")
const DRESSING := preload("res://scenes/world/plazas/PlazaDressing.gd")
var _passes := 0
var _failures := 0
var _frames := 0


func _process(_delta: float) -> void:
	_frames += 1


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _data(state: int, coord := Vector2i.ZERO) -> ChunkBuildData:
	var data := ChunkBuildData.new(coord, 4)
	data.plaza_edge_state = state
	data.add_blocker(Vector2i.ONE, WorldBlockerGeometry.Kind.WALL, 10, KIT.VARIANT_PLAZA_EDGE)
	return data


func _run() -> void:
	# Merely loading the dressing script must not pin all worn-state textures.
	KIT.warm_state(KIT.STATE_TENDED)
	_check(not ResourceLoader.has_cached(KIT.WORN_ATLAS_PATH), "tended dressing does not preload the worn atlas")
	_check(not ResourceLoader.has_cached(KIT.WEEDS_GROUND_PATH), "tended dressing does not preload ruined bed fill")
	_check(not ResourceLoader.has_cached(KIT.MOSS_SOIL_PATH), "tended dressing does not preload damp bed fill")
	var expected_styles := [0, 2, 3, 4, 1, 3, 0, 4, 1]
	var states := [0, 1, 2, 3, 4, 2, 0, 3, 4]
	for i in states.size():
		var state: int = states[i]
		var style: int = expected_styles[i]
		KIT.warm_state(state)
		var worn := style in [2, 3, 4]
		_check(KIT.resident_style() == (style if worn else -1), "state %d retains only its own worn edge style" % state)
		_check(KIT._loaded_pieces.is_empty() == (not worn), "state %d releases unused piece references" % state)
		_check((KIT._loaded_fill == null) == (not worn), "state %d releases unused fill reference" % state)
		_check(KIT._dressing.has(&"worn_atlas") == (state != 0), "state %d owns only applicable prop atlas" % state)
		_check(KIT._dressing.has(&"weeds_ground") == (state == 2), "state %d owns only applicable ruined fill" % state)
		_check(KIT._dressing.has(&"moss_soil") == (state == 3), "state %d owns only applicable damp fill" % state)
		var data := _data(state)
		var piece := KIT.texture_for(data, Vector2i.ONE)
		var fill := KIT.fill_texture(style)
		KIT.warm_state(state)
		_check(piece == KIT.texture_for(data, Vector2i.ONE) and fill == KIT.fill_texture(style), "state %d repeated warm/lookup reuses exact resources" % state)
		_check(KIT.resident_texture_count(state) == (38 + ([0, 19, 37, 37, 0][state])), "state %d declares its edge residency bound" % state)
	# Keep an old state's batch alive while the shared cache changes. Loading a
	# later state must not rebind or retire the visible earlier chunk's art.
	var host := Node2D.new()
	add_child(host)
	var renderer := ChunkBlockRenderer.new()
	renderer.configure(host, 256, 64)
	var old_data := _data(KIT.STATE_RUINED)
	renderer.add_chunk(old_data)
	var old_piece := KIT.texture_for(old_data, Vector2i.ONE)
	_check(old_piece != null, "ruined source texture imported for the live-batch control")
	var old_id := old_piece.get_instance_id() if old_piece != null else 0
	KIT.warm_state(KIT.STATE_TENDED)
	var live_old := false
	for batch: ChunkBlockRenderer.TextureBatch in renderer.get("_batches").values():
		live_old = live_old or (old_id != 0 and batch.texture.get_instance_id() == old_id)
	_check(live_old and int(renderer.get_stats().instances) == 1, "live ruined batch keeps its texture after tended state warms")
	_check(KIT.resident_style() == -1, "live old batch does not make old style shared-cache resident")
	var new_data := _data(KIT.STATE_WORKING, Vector2i(1, 0))
	renderer.add_chunk(new_data)
	_check(int(renderer.get_stats().instances) == 2, "mixed old/new states coexist until the old chunk unloads")
	renderer.remove_chunk(old_data.coord)
	_check(int(renderer.get_stats().instances) == 1, "removing old state leaves the new state's batch")
	renderer.clear()
	host.free()
	old_piece = null
	KIT.release_static_caches()
	await get_tree().process_frame
	await _check_preparation()
	KIT.release_static_caches()
	print("PlazaResourceResidencyTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)


func _check_preparation() -> void:
	for state in [KIT.STATE_WORKING, KIT.STATE_RUINED, KIT.STATE_DAMP]:
		var before := _frames
		var started := Time.get_ticks_usec()
		await KIT.prepare_state_for_transition(get_tree(), state)
		var frames := _frames - before
		var paths := KIT.state_texture_paths(state)
		_check(frames >= KIT.style_texture_count(KIT.style_for_state(state)) - 1, "state %d first-touch textures are spread across loading frames" % state)
		_check(KIT.resident_style() == KIT.style_for_state(state), "state %d incremental preparation hands references to the warm cache" % state)
		print("PLAZA_FIRST_TOUCH state=%d paths=%d loading_frames=%d elapsed_ms=%.3f" % [state, paths.size(), frames, float(Time.get_ticks_usec() - started) / 1000.0])
		before = _frames
		await KIT.prepare_state_for_transition(get_tree(), state)
		_check(_frames == before, "state %d repeated preparation adds no loading frames" % state)
	await KIT.prepare_state_for_transition(get_tree(), KIT.STATE_TENDED)
	_check(KIT.resident_style() == -1 and KIT._dressing.is_empty(), "incremental transition back to tended releases worn shared refs")
