extends Node2D
## Later real procedural L parcels must use the same exact caster as S2.
## Independent reference: a ground point is shadowed only when the finite
## ray toward the light enters the actual occupied outline.

const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")
var _passes := 0
var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if ok: _passes += 1
	else:
		_failures += 1
		push_error(label)


func _reference(outline: PackedVector2Array, point: Vector2, offset: Vector2) -> bool:
	if Geometry2D.is_point_in_polygon(point,outline): return false
	if Geometry2D.is_point_in_polygon(point-offset,outline): return true
	for index in outline.size():
		var hit: Variant = Geometry2D.segment_intersects_segment(point,point-offset,outline[index],outline[(index+1)%outline.size()])
		if hit != null and Geometry2D.is_point_in_polygon((hit as Vector2)-offset.normalized()*0.05,outline): return true
	return false


func _covered(kit: Node, point: Vector2) -> bool:
	for node: Node in kit.get_children():
		if node is Polygon2D and node.texture == null and node.has_meta(&"city_sun_shadow") and Geometry2D.is_point_in_polygon(point,node.polygon): return true
	return false


func _test_segment(segment: int, direction: Vector2i) -> void:
	Global.attempt_segment = segment
	var manager := ChunkManager.new()
	manager.world_seed = 16102026
	manager.generation_enabled = false
	manager.ground_enabled = false
	manager.ground_splat_enabled = false
	manager.world_atmosphere_enabled = false
	manager.decals_enabled = false
	manager.deco_enabled = false
	manager.sites_enabled = false
	manager.cover_full_scene = load("res://scenes/world/cover/CoverFull.tscn")
	manager.cover_window_scene = load("res://scenes/world/cover/CoverWindow.tscn")
	add_child(manager)
	manager._gen_coord = Vector2i.ZERO
	manager._chunk_blocked[Vector2i.ZERO] = []
	manager._active_build_data = ChunkBuildData.new(Vector2i.ZERO,32)
	var chunk := Node2D.new()
	manager.add_child(chunk)
	var family := SegmentThemePicker.get_theme(segment,16102026).district_family
	var cfg := {"city_block_style":true,"city_shared_ground":true,"district_family":family,"secondary_objective_id":0,"local_encounter_enabled":false,"parcel_loot_chance":0.0,"parcel_recess_chance":0.0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 16102026
	var placed: Array[Rect2i] = []
	var carver := SiteParcelsImpl.new()
	var generated := carver._spawn_building_footprint(manager,chunk,Vector2i.ZERO,Rect2i(3,9,11,8),direction,&"row_house",[],placed,cfg,rng,Rect2i(0,0,32,32))
	_check(generated,"S%d actual procedural L parcel generates for direction%s" % [segment,str(direction)])
	var kit: Node2D
	for child: Node in chunk.get_children():
		if child.is_in_group(&"city_block_building"): kit = child as Node2D
	_check(kit != null,"S%d actual generated parcel has its production kit" % segment)
	if kit != null:
		var roof := kit.get("_roof") as RoofOverlay
		var outline := roof.footprint_outline_px
		_check(outline.size() >= 6 and not bool(kit.call("_is_guard")),"S%d fixture is an actual nonrectangular nonguard family%s" % [segment,String(family)])
		kit.trim_paving(placed,64)
		await get_tree().process_frame
		var bounds := Rect2(outline[0],Vector2.ZERO)
		for point: Vector2 in outline: bounds = bounds.expand(point)
		bounds = bounds.grow(130)
		var false_positive := 0
		var false_negative := 0
		var positives := 0
		var offset := DEPTH.offset_for_height(126.0)
		for y in range(int(bounds.position.y),int(bounds.end.y),19):
			for x in range(int(bounds.position.x),int(bounds.end.x),17):
				var point := Vector2(x+0.37,y+0.61)
				var expected := _reference(outline,point,offset)
				var actual := _covered(kit,point)
				if expected: positives += 1
				if actual and not expected: false_positive += 1
				if expected and not actual: false_negative += 1
		_check(positives > 20,"S%d independent light-ray probes exercise real cast ground" % segment)
		_check(false_positive == 0,"S%d actual L has no phantom bounding-box caster; false positives=%d" % [segment,false_positive])
		_check(false_negative == 0,"S%d actual L keeps casts in its true concave ground; false negatives=%d" % [segment,false_negative])
		print("CityNonGuardFootprintShadowTest S%d direction=%s family=%s outline=%s positives=%d false_positive=%d false_negative=%d" % [segment,str(direction),String(family),str(outline),positives,false_positive,false_negative])
	manager._active_build_data = null
	manager.queue_free()
	await get_tree().process_frame


func _run() -> void:
	var previous_segment := Global.attempt_segment
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	for segment: int in [4,7]:
		for direction: Vector2i in [Vector2i.DOWN,Vector2i.RIGHT]:
			await _test_segment(segment,direction)
	player.queue_free()
	await get_tree().process_frame
	Global.attempt_segment = previous_segment
	print("CityNonGuardFootprintShadowTest: %d passed, %d failed" % [_passes,_failures])
	get_tree().quit(1 if _failures > 0 else 0)
