extends "res://tools/dev/CitySegmentSurvey.gd"
## Gameplay-zoom close-ups of the small half-cover props (crates, rubble,
## tables, pillars, statues) and their sun casts on the actual Game: for each
## HALF_TEXTURES variant, the loaded prop nearest the start, framed in the
## centre. Same framing on any branch, so prop shadows compare before/after.
## Also frames the nearest upright objective form (wardstone, relay, wager).
## -- --segment=6 [--world-seed=16102026] [--theme=industrial_cutthrough] --out=/abs/dir

const WORLD_ART := preload("res://core/systems/world/objectives/ObjectiveWorldArt.gd")

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
	_dismiss_dossiers()
	var start := _player.global_position
	var renderer: ChunkBlockRenderer = _chunks.get("_block_renderer")
	var found: Dictionary = {}
	for variant: int in ChunkBlockVisualCatalog.HALF_TEXTURES.size():
		var texture := ChunkBlockVisualCatalog.half_texture(variant)
		for batch: ChunkBlockRenderer.TextureBatch in renderer.get("_batches").values():
			if batch.texture != texture: continue
			for transform: Transform2D in batch.transforms:
				var at := transform.origin
				if not found.has(variant) or at.distance_to(start) < (found[variant] as Vector2).distance_to(start):
					found[variant] = at
	var variants: Array = found.keys()
	variants.sort()
	# The nearest upright objective form (wardstone, relay, wager), if one is loaded.
	var objective: Sprite2D
	for node: Node in get_tree().root.find_children("*", "Sprite2D", true, false):
		if node.get_script() != WORLD_ART or bool(node.get("_ground")): continue
		if objective == null or (node as Sprite2D).global_position.distance_to(start) < objective.global_position.distance_to(start):
			objective = node as Sprite2D
	var objective_point := {} if objective == null else {"name": "objective_art", "world": objective.global_position, "texture": objective.texture.resource_path}
	for variant: int in variants:
		await _capture_point({"name": "prop%d" % variant, "world": found[variant], "texture": ChunkBlockVisualCatalog.half_texture(variant).resource_path}, false)
	if not objective_point.is_empty():
		await _capture_point(objective_point, false)
	var file := FileAccess.open(_out.path_join("survey.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"segment": _survey_segment, "world_seed": _survey_seed, "points": _records, "failures": _failures}, "  ") + "\n")
	await _shutdown()


## Stages the player a few cells east of the framed prop, so the prop and its
## cast stay in view beside an actor for scale.
func _open_cell_near(world: Vector2) -> Vector2:
	return super._open_cell_near(world + Vector2(float(_chunks.cell_size_px) * 3.0, 0.0))
