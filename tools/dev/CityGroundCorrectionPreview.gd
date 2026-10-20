extends "res://tools/dev/CityBlockPlayablePreview.gd"
## Actual generated-ground controls for the bounded L2 review. No terrain edits.
## --seam-review: retain both sides of the bed's x=0 boundary before/after reload.
## --dry-survey: choose an actual clean dry1 patch among the loaded final cells.

var _seam_review := false
var _dry_survey := false
var _correction_evidence: Dictionary = {}


func _enter_tree() -> void:
	super._enter_tree()
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--seam-review": _seam_review = true
		if arg == "--dry-survey": _dry_survey = true


func _reload_ground_context() -> void:
	if _dry_survey:
		_select_real_dry_control()
	if _failures > 0: return
	if not _seam_review:
		await super._reload_ground_context()
		return
	var coords: Array[Vector2i] = [Vector2i(-1,3),Vector2i(0,3)]
	var before: Array[Dictionary] = []
	for coord: Vector2i in coords:
		if not _chunks._chunks.has(coord):
			_fail("Seam review requires both actual neighboring chunks: " + str(coord))
			return
		before.append(_signature(coord))
	_correction_evidence["seam_before"] = _seam_cells()
	_player.global_position = _free_spawn_position(_ground_context)
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_camera.global_position = _ground_context
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	_chunks.set_process(false)
	await _wait_for_temporary_tips()
	await _frames(4)
	await _still("seam-before-reload")
	await super._reload_ground_context()
	var equal := true
	for index: int in coords.size():
		var coord := coords[index]
		if not _chunks._chunks.has(coord):
			equal = false
			continue
		equal = equal and before[index] == _signature(coord)
	if not equal: _fail("Both sides of the real care boundary must survive independent streamed rebuild")
	_correction_evidence["seam_after"] = _seam_cells()
	_correction_evidence["neighbor_signatures_equal"] = equal
	_correction_evidence["seam_cell_grids_equal"] = _correction_evidence.seam_before == _correction_evidence.seam_after


func _seam_cells() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var splat := _chunks.get_ground_splat()
	for y: int in range(108,115):
		for x: int in range(-4,6):
			var cell := Vector2i(x,y)
			var light := splat._light.get_pixel(posmod(x,splat.MAP_SIZE),posmod(y,splat.MAP_SIZE))
			result.append({"cell":[x,y],"material":splat.material_at(cell),"care_byte":light.b8,"brightness_byte":light.r8,"stain_byte":light.g8,"walkable":_chunks.is_cell_walkable(cell)})
	return result


func _select_real_dry_control() -> void:
	var splat := _chunks.get_ground_splat()
	var request := _ground_context
	var side := splat.cells_per_chunk
	var best := INF
	var selected := Vector2i.ZERO
	var found := false
	var coords: Array = _chunks._chunks.keys()
	coords.sort()
	for value: Variant in coords:
		var coord: Vector2i = value
		for y: int in range(2,side-2):
			for x: int in range(2,side-2):
				var cell := coord*side+Vector2i(x,y)
				var point := _chunks.cell_to_world_center(cell)
				var distance := point.distance_squared_to(request)
				if distance >= best or not _chunks.is_cell_walkable(cell): continue
				var clean := true
				for oy: int in range(-1,2):
					for ox: int in range(-1,2):
						var at := cell+Vector2i(ox,oy)
						var light := splat._light.get_pixel(posmod(at.x,splat.MAP_SIZE),posmod(at.y,splat.MAP_SIZE))
						if splat.material_at(at) != 1 or light.g8 > 2:
							clean = false
				if clean:
					best = distance
					selected = cell
					found = true
	if not found:
		_fail("Loaded generated S7 has no final 3x3 dry1 control without mud staining")
		return
	_ground_context = _chunks.cell_to_world_center(selected)
	_player.global_position = _ground_context
	_camera.global_position = _ground_context
	_correction_evidence["dry_control"] = {"requested_world_px":[request.x,request.y],"selected_cell":[selected.x,selected.y],"selected_world_px":[_ground_context.x,_ground_context.y],"minimum_clean_patch_cells":[3,3],"terrain_material":1,"max_stain_byte":2,"selection":"nearest actual loaded final dry1 patch; fixed camera and same production atmosphere"}


func _district_evidence() -> Dictionary:
	var result := super._district_evidence()
	result["ground_correction"] = _correction_evidence.duplicate(true)
	return result
