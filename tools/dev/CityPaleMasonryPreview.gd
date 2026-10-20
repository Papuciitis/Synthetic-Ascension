extends "res://tools/dev/CityDomesticInteriorPreview.gd"
## Actual adjacent slate civic building, matched relief-off/on native controls.
## --world-seed=16102026 --target-chunk=0,3 --target-building-id=944996572
## --review=small|normal --out=<fresh directory>

var _pale_plates: Array[Dictionary] = []
var _pale_materials: Array[Dictionary] = []


func _enter_tree() -> void:
	super._enter_tree()
	_domestic_occupied = false
	_domestic_walkthrough = false
	if _out.begins_with("user://dev_previews/city_domestic_interiors/"):
		_out = "user://dev_previews/city_pale_masonry/%d/%s" % [Time.get_ticks_usec(),_review]


func _capture_ground_review() -> void:
	if _city_segment != 2 or _roof == null:
		_fail("Pale masonry control requires the actual retained S2 home context")
		await _shutdown()
		return
	var home_id: int = _volume.building_id
	var home_bounds: Rect2 = _roof_bounds(_roof)
	var candidates: Array[Dictionary] = []
	for node: Node in _chunks.find_children("*","",true,false):
		if not node.is_in_group(&"city_block_building") or not bool(node.get("civic")): continue
		var roof := node.get("_roof") as RoofOverlay
		if roof == null: continue
		var volume: IndoorVolume = _connected_volume(roof)
		if volume == null or volume.local_encounter_enabled: continue
		var bounds: Rect2 = _roof_bounds(roof)
		var distance: float = bounds.get_center().distance_to(home_bounds.get_center())
		if distance <= 1536.0:
			candidates.append({"roof":roof,"volume":volume,"bounds":bounds,"distance":distance})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.distance) < float(b.distance))
	if candidates.is_empty():
		_fail("No actual adjacent ambient slate civic building fits this household control")
		await _shutdown()
		return
	var selected: Dictionary = candidates[0]
	_roof = selected.roof
	_volume = selected.volume
	var renderer := _chunks.get("_block_renderer") as ChunkBlockRenderer
	var seen: Dictionary = {}
	if renderer != null:
		for batch: ChunkBlockRenderer.TextureBatch in (renderer.get("_batches") as Dictionary).values():
			var material := batch.visual.material as ShaderMaterial
			if material == null or material.shader == null or material.shader.resource_path != "res://scenes/world/buildings/city_stone.gdshader" or seen.has(material.get_instance_id()): continue
			var raw: Variant = material.get_shader_parameter("source_relief")
			if raw == null or float(raw) <= 0.0: continue
			seen[material.get_instance_id()] = true
			_pale_materials.append({"material":material,"relief":float(raw)})
	if _pale_materials.is_empty():
		_fail("Actual S2 pale renderer has no bound relief material")
		await _shutdown()
		return
	var combined: Rect2 = home_bounds.merge(selected.bounds)
	var viewport: Vector2 = get_viewport().get_visible_rect().size
	var zoom: float = minf(1.0,minf((viewport.x-400.0)/combined.size.x,(viewport.y-180.0)/combined.size.y))
	_camera.zoom = Vector2.ONE*zoom
	_camera.global_position = combined.get_center()-Vector2(200,70)/zoom
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	var coord: Vector2i = _chunks._world_to_chunk(_volume.global_position)
	var physical_before: String = _physical_signature(coord)
	var door: Vector2 = _volume.to_global(_volume.get("_presentation_entry"))
	var outward: Vector2 = _volume.get("_presentation_outward")
	await _walk_to(door+outward*96.0)
	await _wait_for_temporary_tips()
	_set_relief(false)
	await _pale_plate("blue-exterior-baseline")
	_set_relief(true)
	await _pale_plate("blue-exterior-relief")
	await _walk_to(door-outward*float(_chunks.cell_size_px))
	await _frames(30)
	var roof_poly := _roof.get_node_or_null("RoofPoly") as Polygon2D
	if roof_poly == null or _roof._inside_count <= 0 or roof_poly.modulate.a > 0.01:
		_fail("Physical civic doorway entry did not produce the actual cutaway")
	_set_relief(false)
	await _pale_plate("blue-cutaway-baseline")
	_set_relief(true)
	await _pale_plate("blue-cutaway-relief")
	await _walk_to(door+outward*160.0)
	await _frames(30)
	if roof_poly == null or _roof._inside_count != 0 or roof_poly.modulate.a < 0.99:
		_fail("Physical civic doorway exit did not restore its slate roof")
	await _pale_plate("blue-exterior-restored")
	var unchanged: bool = physical_before == _physical_signature(coord)
	if not unchanged: _fail("Relief comparison changed physical wall/mask/variant data")
	var writes: int = SaveManager.debug_save_writes-_save_writes_before
	if writes != 0 or SaveManager.current_save != null: _fail("Pale masonry comparison wrote or selected a profile")
	var report: Dictionary = _district_evidence()
	report.merge({"capture_scene":"res://tools/dev/CityPaleMasonryPreview.tscn","scene":"res://scenes/game.tscn","args":OS.get_cmdline_user_args(),"segment":_city_segment,"attempt_seed":_city_world_seed,"requested_home_id":home_id,"selected_civic_id":_volume.building_id,"neighbor_distance_px":selected.distance,"comparison_bounds":str(combined),"plates":_pale_plates,"route":_route_notes,"physical_unchanged":unchanged,"source_hashes":_source_hashes(),"failures":_failures,"save_writes":writes,"limits":"Controlled actual generated Game. Nearest ambient civic slate building selected within1536px of the explicit retained home after the inherited home-context reload. Matched relief0/current-material controls change only the separate S2 palette uniform; default S3 and warm-home materials are not toggled. Same camera, scene and player in each immediate pair; physical doorway entry/exit uses production inputs, collisions and roof Area2D signals. God mode, disabled ambient spawner/encounter beats, frozen streaming after reload, no extra encounter or spontaneous-play claim. Roof counters/alpha are never manually changed. This is a material comparison, not performance or full-city acceptance."},true)
	var file := FileAccess.open(_out.path_join("capture-info.json"),FileAccess.WRITE)
	if file == null:
		_fail("Cannot write pale masonry capture manifest")
	else:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	print("CityPaleMasonryPreview: plates=%d failures=%d save_writes=%d -> %s" % [_pale_plates.size(),_failures,writes,_out])
	await _shutdown()


func _connected_volume(roof: RoofOverlay) -> IndoorVolume:
	for node: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		var volume := node as IndoorVolume
		if volume == null or float(volume.get("_presentation_width")) <= 0.0: continue
		for connection: Dictionary in volume.body_entered.get_connections():
			if (connection.callable as Callable).get_object() == roof:
				return volume
	return null


func _roof_bounds(roof: RoofOverlay) -> Rect2:
	var outline: PackedVector2Array = roof.footprint_outline_px
	if outline.is_empty(): return Rect2(roof.global_position,Vector2.ONE)
	var bounds := Rect2(roof.to_global(outline[0]),Vector2.ZERO)
	for point: Vector2 in outline:
		bounds = bounds.expand(roof.to_global(point))
	return bounds


func _set_relief(enabled: bool) -> void:
	for entry: Dictionary in _pale_materials:
		(entry.material as ShaderMaterial).set_shader_parameter("source_relief",float(entry.relief) if enabled else 0.0)


func _pale_plate(name: String) -> void:
	await _frames(4)
	await _still(name)
	var roof_poly := _roof.get_node_or_null("RoofPoly") as Polygon2D
	var values: Array[float] = []
	for entry: Dictionary in _pale_materials:
		values.append(float((entry.material as ShaderMaterial).get_shader_parameter("source_relief")))
	_pale_plates.append({"file":name+".png","window":str(get_window().size),"camera":str(_camera.global_position),"zoom":str(_camera.zoom),"player":str(_player.global_position),"roof_alpha":roof_poly.modulate.a if roof_poly != null else -1.0,"inside_count":_roof._inside_count,"source_relief":values})


func _physical_signature(coord: Vector2i) -> String:
	var data: ChunkBuildData = _chunks.get_chunk_build_data(coord)
	return var_to_str([data.blocker_kind_code,data.blocker_mask,data.blocker_variant]) if data != null else "missing"


func _source_hashes() -> Dictionary:
	var result: Dictionary = super._source_hashes()
	for path: String in ["res://tools/dev/CityPaleMasonryPreview.gd","res://tools/dev/CityPaleMasonryPreview.tscn","res://core/systems/world/chunks/ChunkBlockRenderer.gd","res://scenes/world/buildings/city_stone.gdshader","res://assets/world/city_block/civic_arcade.png","res://assets/world/city_block/slate.png"]:
		result[path] = FileAccess.get_sha256(path)
	return result
