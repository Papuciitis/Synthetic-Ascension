extends "res://.superpowers/sdd/2026-10-18-city-block/CityActualGenerationCapture.gd"
## Frozen production Game inspection, without substituting parcel fixtures.

var _sampled: Dictionary = {}
var _census: Array = []

func _shot_pair(key: String, note: String, metadata: Dictionary) -> void:
	var rows: Array = []
	for kit: Node2D in get_tree().get_nodes_in_group(&"city_block_building"):
		var roof: RoofOverlay = kit.get("_roof")
		rows.append({"chunk":str(kit.get_parent().position),"bounds":str(kit.get("bounds")),"family":String(kit.get_meta(&"city_role")),"irregular":kit.has_meta(&"city_irregular_outline"),"doors":str(roof._doors)})
	_census.append({"panel":key,"loaded_buildings":rows})
	await super._shot_pair(key,note,metadata)
	var saved_camera := _camera.global_position
	var jobs: Array = []
	for kit: Node2D in get_tree().get_nodes_in_group(&"city_block_building"):
		var roof: RoofOverlay = kit.get("_roof")
		if roof._doors.is_empty(): continue
		var direction: Vector2i = roof._doors[0].dir
		var label := "east" if direction == Vector2i.RIGHT else "west" if direction == Vector2i.LEFT else "north" if direction == Vector2i.UP else "south"
		if kit.has_meta(&"city_irregular_outline"): label = "irregular"
		if _sampled.has(label): continue
		_sampled[label] = true
		var box: Rect2 = kit.get("bounds")
		jobs.append({"label":label,"at":kit.to_global(box.get_center())+Vector2(0,40),"metadata":{"family":String(kit.get_meta(&"city_role")),"bounds":str(box),"doors":str(roof._doors),"irregular":kit.has_meta(&"city_irregular_outline")}})
	for job: Dictionary in jobs:
		await _visit(job.at)
		_cm.set_process(false)
		await super._shot_pair("frontage-"+job.label,"Actual streamed production parcel; frozen exterior, real footprint and door orientation",job.metadata)
	if not jobs.is_empty():
		await _visit(saved_camera)
		_cm.set_process(false)
	var file := FileAccess.open(_out.path_join("family-census.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples":_sampled,"visits":_census},"\t"))
