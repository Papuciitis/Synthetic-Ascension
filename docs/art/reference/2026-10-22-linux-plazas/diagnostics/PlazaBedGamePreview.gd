extends "res://tools/dev/CityBlockPlayablePreview.gd"
## Validate a headless-discovered candidate against the untouched native Game,
## stream it out/back with the parent fixture, then capture its actual bed.
var _bed_discovery_path: String = ""
var _bed_family: String = ""
var _expected_bed: Dictionary = {}
var _bed_render_fps: int = 20


func _enter_tree() -> void:
	super._enter_tree()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--discovery="):
			_bed_discovery_path = arg.trim_prefix("--discovery=")
		elif arg.begins_with("--family="):
			_bed_family = arg.trim_prefix("--family=")
		elif arg.begins_with("--render-fps="):
			_bed_render_fps = clampi(int(arg.trim_prefix("--render-fps=")), 20, 60)
	if _playable or _ground_fight or _district_common_base or _hide_district_details or _review == "before":
		_fail("Native bed review requires the normal candidate scene, static capture and all optional details")
		return
	if not FileAccess.file_exists(_bed_discovery_path):
		_fail("Native bed review requires its actual discovery JSON")
		return
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(_bed_discovery_path))
	if not decoded is Dictionary:
		_fail("Invalid bed discovery JSON")
		return
	for entry: Dictionary in decoded.get("results", []):
		if str(entry.get("family", "")) == _bed_family:
			_expected_bed = entry.duplicate(true)
			break
	if _expected_bed.is_empty():
		_fail("Discovery has no actual fixture bed for requested family")
		return
	_city_segment = int(_expected_bed.segment)
	_city_world_seed = int(_expected_bed.attempt_seed)
	_ground_context = Vector2(float(_expected_bed.camera_world_px[0]), float(_expected_bed.camera_world_px[1]))
	_has_ground_context = true
	_ground_review = true
	_ground_fight = false
	_playable = false
	_still_only = false
	_entry_only = false


func _prepare_runtime() -> void:
	super._prepare_runtime()
	Engine.max_fps = _bed_render_fps


func _capture_ground_review() -> void:
	var evidence: Dictionary = _actual_bed_evidence()
	if not bool(evidence.get("matches_expected", false)):
		_fail("Actual Game after reload lacks the discovered family/state/planned bed/real bed node")
		await _shutdown()
		return
	await super._capture_ground_review()


func _district_evidence() -> Dictionary:
	var result: Dictionary = super._district_evidence()
	result["plaza_bed"] = _actual_bed_evidence()
	result["bed_render_fps_cap"] = _bed_render_fps
	result["physics_ticks_per_second"] = Engine.physics_ticks_per_second
	return result


func _actual_bed_evidence() -> Dictionary:
	var result: Dictionary = {"expected": _expected_bed, "matches_expected": false, "actual_bed_nodes": [], "limits": "Existing native Game metadata/nodes after real streaming reload; native PNG must still be visually reviewed. No forced styles or injected dressing."}
	if _chunks == null or _expected_bed.is_empty():
		return result
	var coord: Vector2i = Vector2i(int(_expected_bed.coord[0]), int(_expected_bed.coord[1]))
	var chunk: Node2D = _chunks._chunks.get(coord) as Node2D
	if chunk == null:
		return result
	var expected_rect: Rect2i = Rect2i(Vector2i(int(_expected_bed.bed_rect_cells.position[0]), int(_expected_bed.bed_rect_cells.position[1])), Vector2i(int(_expected_bed.bed_rect_cells.size[0]), int(_expected_bed.bed_rect_cells.size[1])))
	var plan: Dictionary = chunk.get_meta(&"_plaza_dressing_plan", {})
	var presentation: Dictionary = chunk.get_meta(&"_plaza_presentation", {})
	var planned_bed_matches: bool = false
	var island_rects: Array = []
	for island: Dictionary in plan.get("islands", []):
		var bed: Rect2i = island.get("bed", Rect2i())
		island_rects.append({"position": [bed.position.x, bed.position.y], "size": [bed.size.x, bed.size.y]})
		planned_bed_matches = planned_bed_matches or (bed.has_area() and bed == expected_rect)
	var node_covers_focus: bool = false
	var dressing: Node = chunk.get_node_or_null("PlazaDressing")
	var pieces: Dictionary = {}
	if dressing != null:
		for node: Node in dressing.get_children():
			var kind: String = str(node.get_meta(&"plaza_piece", ""))
			if not kind.is_empty():
				pieces[kind] = int(pieces.get(kind, 0)) + 1
			if not node is Polygon2D or kind != "bed":
				continue
			var polygon: Polygon2D = node as Polygon2D
			if polygon.polygon.is_empty():
				continue
			var bounds: Rect2 = Rect2(polygon.to_global(polygon.polygon[0]), Vector2.ZERO)
			for vertex: Vector2 in polygon.polygon:
				bounds = bounds.expand(polygon.to_global(vertex))
			node_covers_focus = node_covers_focus or bounds.has_point(_ground_context)
			var min_alpha: float = 1.0
			var max_alpha: float = 0.0
			for color: Color in polygon.vertex_colors:
				min_alpha = minf(min_alpha, color.a)
				max_alpha = maxf(max_alpha, color.a)
			result.actual_bed_nodes.append({"node": str(chunk.get_path_to(node)), "world_aabb": {"position": [bounds.position.x, bounds.position.y], "size": [bounds.size.x, bounds.size.y]}, "contains_expected_focus": bounds.has_point(_ground_context), "vertex_color_count": polygon.vertex_colors.size(), "vertex_alpha_min": min_alpha, "vertex_alpha_max": max_alpha if not polygon.vertex_colors.is_empty() else 1.0, "texture": polygon.texture.resource_path if polygon.texture != null else ""})
	result["actual_family"] = str(_chunks.district_family)
	result["actual_state"] = int(plan.get("state", -1))
	result["actual_role"] = str(plan.get("role", ""))
	result["actual_plan_island_beds"] = island_rects
	result["actual_piece_counts"] = pieces
	result["actual_ring_cells"] = (presentation.get("ring", []) as Array).size()
	result["actual_edge_wear_count"] = (plan.get("edge_wear", []) as Array).size()
	result["planned_bed_matches"] = planned_bed_matches
	result["node_covers_expected_focus"] = node_covers_focus
	result["matches_expected"] = str(_chunks.district_family) == _bed_family and int(plan.get("state", -1)) == int(_expected_bed.state) and str(plan.get("role", "")) == str(_expected_bed.role) and planned_bed_matches and node_covers_focus
	return result


func _shutdown() -> void:
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
		var report: Dictionary = _actual_bed_evidence()
		report["failures"] = _failures
		report["save_writes"] = SaveManager.debug_save_writes - _save_writes_before
		report["discovery_json"] = _bed_discovery_path
		report["discovery_sha256"] = FileAccess.get_sha256(_bed_discovery_path) if FileAccess.file_exists(_bed_discovery_path) else ""
		var helper: String = get_script().resource_path
		var hashes: Dictionary = {}
		for source: String in [helper, "res://tools/dev/CityBlockPlayablePreview.gd", "res://tools/tests/PlazaPresentationTest.gd", "res://core/systems/world/proc/chunkgen/PlazaPresentation.gd", "res://scenes/world/plazas/PlazaDressing.gd"]:
			hashes[source] = FileAccess.get_sha256(source)
		report["source_sha256"] = hashes
		var file: FileAccess = FileAccess.open(_out.path_join("bed-validation.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "  ") + "\n")
			file.close()
		else:
			_fail("Cannot write actual Game bed-validation JSON")
	await super._shutdown()
