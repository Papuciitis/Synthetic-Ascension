extends "res://tools/dev/CitySegmentSurvey.gd"
## Read-only instrumentation of the inherited actual-Game survey. Adds no
## capture points, camera movement, generator calls, forced states or nodes.
## Existing parent survey freezes Player/Spawner and visits its normal points.
## Node AABB intersections are framing evidence, not visible-pixel assertions.

var _plaza_context_records: Array[Dictionary] = []


func _save_image(pixels: Image, path: String) -> void:
	super._save_image(pixels, path)
	if _chunks == null:
		return
	var loaded: Dictionary = _chunks.get("_chunks")
	var coordinates: Array = loaded.keys()
	coordinates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var view: Rect2 = _context_view_rect()
	var plazas: Array[Dictionary] = []
	var best: Dictionary = {}
	for coordinate: Vector2i in coordinates:
		var chunk: Node2D = loaded[coordinate] as Node2D
		if chunk == null or not chunk.has_meta(&"_plaza_presentation"):
			continue
		var presentation: Dictionary = chunk.get_meta(&"_plaza_presentation")
		var plan: Dictionary = chunk.get_meta(&"_plaza_dressing_plan", {})
		var summary: Dictionary = {
			"chunk": [coordinate.x, coordinate.y],
			"role": str(presentation.get("role", "")),
			"archetype": str(presentation.get("archetype", "")),
			"family": str(plan.get("family", "")),
			"state": int(presentation.get("state", -1)),
			"balustrade": bool(presentation.get("balustrade", false)),
			"plaza_cells": (presentation.get("plaza", {}) as Dictionary).size(),
			"surviving_ring_cells": (presentation.get("ring", []) as Array).size(),
			"plan_features": {}, "plan_islands": [], "plan_edge_wear_by_kind": {},
			"node_piece_counts": {}, "node_framing_counts": {}, "bed_nodes": [],
			"centrepiece": _context_json(plan.get("centrepiece", {})),
		}
		for key: String in ["islands", "lamps", "benches", "drains", "stalls", "pots", "accents", "ring_props", "debris", "edge_wear", "notice_boards"]:
			summary.plan_features[key] = (plan.get(key, []) as Array).size()
		for island: Dictionary in plan.get("islands", []):
			summary.plan_islands.append(_context_json(island))
		for wear: Dictionary in plan.get("edge_wear", []):
			var kind: String = str(wear.get("kind", ""))
			summary.plan_edge_wear_by_kind[kind] = int(summary.plan_edge_wear_by_kind.get(kind, 0)) + 1
		var dressing: Node = chunk.get_node_or_null("PlazaDressing")
		if dressing != null:
			for node: Node in dressing.find_children("*", "", true, false):
				if not node.has_meta(&"plaza_piece"):
					continue
				var piece: String = str(node.get_meta(&"plaza_piece"))
				summary.node_piece_counts[piece] = int(summary.node_piece_counts.get(piece, 0)) + 1
				var bounds: Rect2 = _context_node_rect(node)
				var framed: bool = node is CanvasItem and (node as CanvasItem).is_visible_in_tree() and bounds.has_area() and view.intersects(bounds)
				if framed:
					summary.node_framing_counts[piece] = int(summary.node_framing_counts.get(piece, 0)) + 1
				if piece == "bed":
					var bed: Dictionary = {"node": str(chunk.get_path_to(node)), "world_aabb": _context_json(bounds), "intersects_current_view": framed}
					if node is Polygon2D:
						var polygon: Polygon2D = node as Polygon2D
						var alpha_min: float = 1.0
						var alpha_max: float = 0.0
						for color: Color in polygon.vertex_colors:
							alpha_min = minf(alpha_min, color.a)
							alpha_max = maxf(alpha_max, color.a)
						bed["vertex_color_count"] = polygon.vertex_colors.size()
						bed["vertex_alpha_min"] = alpha_min if not polygon.vertex_colors.is_empty() else 1.0
						bed["vertex_alpha_max"] = alpha_max if not polygon.vertex_colors.is_empty() else 1.0
						bed["texture"] = polygon.texture.resource_path if polygon.texture != null else ""
					summary.bed_nodes.append(bed)
					if best.is_empty() and bounds.has_area():
						best = {"source": "existing bed node in an already loaded chunk", "chunk": [coordinate.x, coordinate.y], "state": summary.state, "role": summary.role, "node": bed.node, "world_focus": _context_json(bounds.get_center()), "intersects_current_view": framed, "camera_was_moved_to_recommendation": false}
		plazas.append(summary)
	_plaza_context_records.append({
		"image": path.get_file(), "engine_process_frame": Engine.get_process_frames(),
		"camera_position": _context_json(_camera.global_position), "camera_zoom": _context_json(_camera.zoom),
		"viewport_canvas_world_aabb": _context_json(view), "loaded_chunks": loaded.size(),
		"loaded_plaza_chunks": plazas,
		"recommended_existing_bed_focus": best,
		"no_loaded_bed_available": best.is_empty(),
	})
	_write_plaza_context()


func _context_view_rect() -> Rect2:
	var inverse: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var rect: Rect2 = get_viewport().get_visible_rect()
	var out: Rect2 = Rect2(inverse * rect.position, Vector2.ZERO)
	for corner: Vector2 in [Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		out = out.expand(inverse * corner)
	return out


func _context_node_rect(node: Node) -> Rect2:
	var vertices: PackedVector2Array = PackedVector2Array()
	if node is Polygon2D:
		vertices = (node as Polygon2D).polygon
	elif node is Sprite2D:
		var rect: Rect2 = (node as Sprite2D).get_rect()
		vertices = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	if vertices.is_empty() or not node is Node2D:
		return Rect2()
	var transform: Transform2D = (node as Node2D).global_transform
	var out: Rect2 = Rect2(transform * vertices[0], Vector2.ZERO)
	for vertex: Vector2 in vertices:
		out = out.expand(transform * vertex)
	return out


func _context_json(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i:
		return [value.x, value.y]
	if value is Rect2 or value is Rect2i:
		return {"position": [value.position.x, value.position.y], "size": [value.size.x, value.size.y]}
	if value is StringName:
		return str(value)
	if value is Dictionary:
		var mapped_dictionary: Dictionary = {}
		for key: Variant in value:
			mapped_dictionary[str(key)] = _context_json(value[key])
		return mapped_dictionary
	if value is Array:
		var mapped_array: Array = []
		for entry: Variant in value:
			mapped_array.append(_context_json(entry))
		return mapped_array
	return value


func _write_plaza_context() -> void:
	var helper_path: String = get_script().resource_path
	var sources: Dictionary = {}
	for path: String in [helper_path, "res://tools/dev/CitySegmentSurvey.gd", "res://tools/dev/EliteCrowdFightPreview.gd", "res://core/systems/world/proc/chunkgen/PlazaPresentation.gd", "res://scenes/world/plazas/PlazaDressing.gd"]:
		sources[path] = FileAccess.get_sha256(path)
	var result: Dictionary = {
		"scope": "Read-only metadata and existing-node inspection at inherited image capture points; no extra generation, styles, nodes or camera moves.",
		"limitations": "Framing counts use node world AABB intersection and tree visibility; they do not prove unoccluded visible pixels. Parent survey freezes Player/Spawner and disables encounter beats; this is not live gameplay acceptance.",
		"segment": _survey_segment, "world_seed": _survey_seed,
		"original_survey_unchanged": true, "source_sha256": sources,
		"save_writes_since_start": SaveManager.debug_save_writes - _save_writes_before,
		"failures": _failures, "captures": _plaza_context_records,
	}
	var path: String = _out.path_join("plaza-context.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Cannot write read-only plaza context manifest: " + path)
		return
	file.store_string(JSON.stringify(result, "  ") + "\n")
	file.close()
	print("PLAZA_CONTEXT captures=%d last_image=%s json=%s" % [_plaza_context_records.size(), str(_plaza_context_records[-1].get("image", "")) if not _plaza_context_records.is_empty() else "", path])


func _shutdown() -> void:
	_write_plaza_context()
	await super._shutdown()
