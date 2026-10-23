extends "res://tools/dev/CitySegmentSurvey.gd"
## Lists every loaded, visible, untextured flat-colour Polygon2D or Line2D in
## the sage family (the blank grey-green paint the playtest called bland), by
## node and parent name with counts and on-screen examples, so each remaining
## flat face can be traced to its owner.
## -- --segment=2 [--world-seed=16102026] [--theme=...] --out=/abs/dir

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Native renderer is required")
		get_tree().quit(1)
		return
	if not _survey_theme.is_empty():
		for step: int in 400:
			if String(SegmentThemePicker.get_theme(_survey_segment, _survey_seed + step).id) == _survey_theme:
				_survey_seed += step
				break
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_prepare_runtime()
	Global.attempt_segment = _survey_segment
	Global.attempt_world_seed = _survey_seed
	get_window().size = Vector2i(1280, 720)
	_game = GAME.instantiate() as Node2D
	_game.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as CharacterBody2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_camera.top_level = true
	_chunks = _game.get_node("ChunkManager") as ChunkManager
	await _settle_streaming()
	await _frames(4)
	var groups: Dictionary = {}
	for node: Node in _game.find_children("*", "CanvasItem", true, false):
		var item := node as CanvasItem
		if not item.is_visible_in_tree(): continue
		var color := Color.TRANSPARENT
		var rect := Rect2()
		if node is Polygon2D:
			var shape := node as Polygon2D
			if shape.texture != null or shape.material != null or not shape.vertex_colors.is_empty() or shape.polygon.is_empty(): continue
			color = shape.color
			rect = Rect2(shape.global_transform * shape.polygon[0], Vector2.ZERO)
			for point: Vector2 in shape.polygon: rect = rect.expand(shape.global_transform * point)
		elif node is Line2D:
			var line := node as Line2D
			if line.texture != null or line.points.is_empty(): continue
			color = line.default_color
			rect = Rect2(line.global_transform * line.points[0], Vector2.ZERO)
			for point: Vector2 in line.points: rect = rect.expand(line.global_transform * point)
		else:
			continue
		if not _sage(color) or rect.get_area() < 20.0: continue
		var key := "%s/%s" % [node.get_parent().name, node.name]
		var entry: Dictionary = groups.get(key, {"count": 0, "color": color.to_html(false), "examples": []})
		entry.count = int(entry.count) + 1
		if (entry.examples as Array).size() < 3:
			(entry.examples as Array).append({"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "path": str(_game.get_path_to(node))})
		groups[key] = entry
	var rows: Array = []
	for key: String in groups:
		rows.append({"key": key, "count": groups[key].count, "color": groups[key].color, "examples": groups[key].examples})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.count) > int(b.count))
	var file := FileAccess.open(_out.path_join("flat-sage.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(rows, "  ") + "\n")
	for row: Dictionary in rows.slice(0, 25):
		print("FLAT SAGE %4d  #%s  %s  e.g. %s" % [row.count, row.color, row.key, str(row.examples[0].path)])
	await _shutdown()


## Grey-green, mid-valued and only slightly saturated: the blank sage paint.
static func _sage(color: Color) -> bool:
	if color.a < 0.5: return false
	var value := maxf(color.r, maxf(color.g, color.b))
	return color.g >= color.r + 0.015 and absf(color.b - color.g) < 0.07 and value > 0.28 and value < 0.75 and color.s < 0.25
