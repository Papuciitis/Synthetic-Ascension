extends "res://tools/tests/CityDomesticInteriorTest.gd"
## A sleeping corner and a reachable cooking/work/storage group in real homes.

const MAT_PATH := "res://assets/world/domestic_interiors/rush_mat_v1/rush_mat.png"
const MAT_VISIBLE := Rect2(53,50,932,1431)
const MAT_ANCHOR := Vector2(519,765.5)


func _run() -> void:
	var previous_segment: int = Global.attempt_segment
	var previous_rng: int = Global._rng.state
	_adapter = load(ADAPTER_PATH) as GDScript
	var dummy := Node2D.new()
	dummy.add_to_group(&"player")
	add_child(dummy)
	Global.attempt_segment = 2
	for sample: Dictionary in HOME_FIXTURES:
		await _check_composed_home(sample)
	_check(Global._rng.state == previous_rng,"Composed households consume no run-owned RNG")
	dummy.free()
	Global.attempt_segment = previous_segment
	print("DomesticCompositionTest: %d passed, %d failed" % [_passed,_failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check_composed_home(sample: Dictionary) -> void:
	Global.attempt_segment = int(sample.get("segment",2))
	var manager: ChunkManager = _manager(int(sample.seed),int(sample.get("segment",2)))
	var coord: Vector2i = sample.coord
	var chunk: Node2D = manager._create_chunk(coord)
	manager._chunks[coord] = chunk
	var kit: Node2D = _find_kit(chunk,int(sample.id))
	_check(kit != null,"Composition uses the actual retained household "+str(sample.id))
	if kit == null:
		manager.free()
		return
	var group := kit.get_node_or_null("CityDomesticInterior") as Node2D
	_check(group != null,"Actual home retains its purposeful furniture owner")
	if group == null:
		manager.free()
		return
	var records: Dictionary = {}
	var reserved: Dictionary = {}
	for record: Dictionary in group.get_meta(&"domestic_layout",[]):
		records[StringName(record.kind)] = record
		for cell: Vector2i in record.reserved_cells:
			reserved[cell] = StringName(record.kind)
	_check(records.size() == 4 and reserved.size() == 6,"Composition retains four original props and six physical low-cover cells")
	if records.has_all([&"cot",&"hearth",&"table",&"crate"]):
		var cot: Vector2 = records[&"cot"].contact_px
		var hearth: Vector2 = records[&"hearth"].contact_px
		var table: Vector2 = records[&"table"].contact_px
		var crate: Vector2 = records[&"crate"].contact_px
		_check(cot.distance_to(hearth) >= 192.0,"Cooking heat is separate from the sleeping corner")
		_check(hearth.distance_to(table) <= 192.0,"A nearby table belongs to the hearth's working area")
		_check(table.distance_to(crate) <= 128.0,"Storage belongs to that reachable cooking/work group")
	var mat := group.get_node_or_null("DomesticRushMat") as Sprite2D
	_check(mat != null,"Actual cot corner includes the supplied flat rush mat")
	if mat != null:
		_check(mat.texture != null and mat.texture.resource_path == MAT_PATH,"Sleeping corner uses the unchanged supplied original mat")
		_check(mat.scale.is_equal_approx(Vector2.ONE*(96.0/932.0)),"Mat preserves aspect at a restrained96px visible width")
		_check(mat.z_index < 0 and not mat.is_in_group(&"foreground_occluders") and not mat.is_in_group(&"foreground_solid_occluders"),"Mat stays beneath props and supplies no foreground coverage")
		_check(mat.find_children("*","CollisionObject2D",true,false).is_empty(),"Flat sleeping décor adds no collider")
		if mat.texture != null and records.has(&"cot"):
			var contact: Vector2 = kit.to_local(mat.to_global(MAT_ANCHOR-mat.texture.get_size()*0.5))
			var visible := Rect2(contact+(MAT_VISIBLE.position-MAT_ANCHOR)*mat.scale,MAT_VISIBLE.size*mat.scale)
			var cot_ground: Rect2 = records[&"cot"].ground_rect_px
			_check(visible.intersection(cot_ground).get_area() >= cot_ground.get_area()*0.3,"Mat partly underlaps the cot rather than becoming isolated floor clutter")
			var data: ChunkBuildData = manager.get_chunk_build_data(coord)
			var first := Vector2i((visible.position/64.0).floor())
			var last := Vector2i(((visible.end-Vector2.ONE*0.001)/64.0).floor())
			for y in range(first.y,last.y+1):
				for x in range(first.x,last.x+1):
					var cell := Vector2i(x,y)
					_check(data.kind_at(cell) < 0 or reserved.get(cell,&"") == &"cot","Mat fits actual open sleeping floor without crossing walls or another activity")
					_check(not _entry_columns(kit).has(cell),"Sleeping décor leaves the central physical door route clear")
	var roof: RoofOverlay = kit.get("_roof") as RoofOverlay
	if roof != null and mat != null:
		roof._set_alpha(0.0)
		_check(mat.is_visible_in_tree() and is_equal_approx(mat.modulate.a,1.0),"The floor mat remains visible in the genuine roof cutaway")
	manager._unregister_chunk_cells(coord)
	manager._chunks.erase(coord)
	chunk.free()
	manager.free()
	await get_tree().process_frame


func _entry_columns(kit: Node2D) -> Dictionary:
	var protected: Dictionary = {}
	for door: Dictionary in kit.get("_doors"):
		var direction: Vector2i = door.dir
		var perpendicular := Vector2i(-direction.y,direction.x)
		var first: Vector2i = door.pos-perpendicular*(int(door.get("width",2))>>1)
		for index in int(door.get("width",2)):
			for depth in 32:
				protected[first+perpendicular*index-direction*depth] = true
	return protected
