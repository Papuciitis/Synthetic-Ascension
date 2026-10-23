extends "/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/PlazaBedGamePreview.gd"
## Same actual Game/camera/reload; additionally require native worn underlay.

func _actual_bed_evidence() -> Dictionary:
	var result: Dictionary = super._actual_bed_evidence()
	result["underlay_matches"] = false
	result["actual_underlay_cells"] = []
	if _chunks == null or _expected_bed.is_empty():
		result["matches_expected"] = false
		return result
	var coord := Vector2i(int(_expected_bed.coord[0]), int(_expected_bed.coord[1]))
	var chunk: Node2D = _chunks._chunks.get(coord) as Node2D
	var splat: GroundSplatRenderer = _chunks.get_ground_splat()
	if chunk == null or splat == null:
		result["matches_expected"] = false
		return result
	var plan: Dictionary = chunk.get_meta(&"_plaza_dressing_plan", {})
	var rect := Rect2i(Vector2i(int(_expected_bed.bed_rect_cells.position[0]), int(_expected_bed.bed_rect_cells.position[1])), Vector2i(int(_expected_bed.bed_rect_cells.size[0]), int(_expected_bed.bed_rect_cells.size[1])))
	var expected_material: int = int(plan.get("repave_tex", -1))
	var matches: bool = int(plan.get("state", 0)) > 0 and expected_material in [7, 9] and rect.has_area()
	var rows: Array[Dictionary] = []
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var cell: Vector2i = coord * 32 + Vector2i(x, y)
			var material: int = splat.material_at(cell)
			var care: float = splat.care_at(cell)
			matches = matches and material == expected_material and is_zero_approx(care)
			rows.append({"cell": [cell.x, cell.y], "material": material, "care": care})
	result["actual_underlay_cells"] = rows
	result["underlay_matches"] = matches
	result["expected_underlay_material"] = expected_material
	result["matches_expected"] = bool(result.get("matches_expected", false)) and matches
	return result
