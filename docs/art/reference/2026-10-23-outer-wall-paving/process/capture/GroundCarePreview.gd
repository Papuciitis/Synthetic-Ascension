extends "/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261022/final-combined-r4/FinalCombinedCityPreview.gd"
## Capture-only attribution; the inherited real-Game exterior controls stay live.


func _district_evidence() -> Dictionary:
	var result: Dictionary = super._district_evidence()
	result["capture_scene"] = "/home/user/Nauris/Synthetic-Ascension/.superpowers/continuation-20261023-ground/GroundCarePreview.tscn"
	var splat: GroundSplatRenderer = _chunks.get_ground_splat()
	var canvas: Transform2D = get_viewport().get_canvas_transform()
	var view: Rect2 = canvas.affine_inverse() * get_viewport().get_visible_rect()
	var first := Vector2i(floori(view.position.x / splat.cell_px), floori(view.position.y / splat.cell_px))
	var last := Vector2i(ceili(view.end.x / splat.cell_px), ceili(view.end.y / splat.cell_px))
	var cared: Array[Dictionary] = []
	for y: int in range(first.y, last.y):
		for x: int in range(first.x, last.x):
			var cell := Vector2i(x, y)
			var amount: float = splat.care_at(cell)
			if amount <= 0.0:
				continue
			var screen: Vector2 = canvas * (Vector2(cell) * splat.cell_px)
			cared.append({"cell": [x, y], "screen_origin": [screen.x, screen.y], "care": amount, "material": splat.material_at(cell)})
	result["visible_care_attribution"] = {"cell_px": splat.cell_px, "camera_view": str(view), "positive_cells": cared, "scope": "Observed final light-map blue and semantic material for every positive care cell in the actual logical view; no care or terrain writes."}
	return result
