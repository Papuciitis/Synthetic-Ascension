extends Node
## Real home identity/fit tests plus pure floor/door/RNG regression cases.

const ADAPTER_PATH := "res://scenes/world/buildings/CityDomesticInterior.gd"
const CELL := 64.0
const ASSETS := {
	&"cot": {"path":"res://assets/world/domestic_interiors/v1/timber_cot.png", "anchor":Vector2(530,1345), "scale":60.0/632.0, "ground":Rect2(215,230,632,1129)},
	&"hearth": {"path":"res://assets/world/domestic_interiors/v1/cooking_hearth.png", "anchor":Vector2(800,805), "scale":120.0/1465.0, "ground":Rect2(69,265,1465,554)},
}
var _adapter: GDScript
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		push_error("FAIL: " + message)


func _run() -> void:
	_check(ResourceLoader.exists(ADAPTER_PATH), "Actual ordinary homes need the measured domestic interior adapter")
	if not ResourceLoader.exists(ADAPTER_PATH):
		_finish()
		return
	_adapter = load(ADAPTER_PATH) as GDScript
	var methods: Array[StringName] = []
	for method: Dictionary in _adapter.get_script_method_list():
		methods.append(StringName(method.name))
	_check(methods.has(&"plan") and methods.has(&"mark_walls"), "Domestic adapter exposes pure plan and ownership-based wall marking")
	if not methods.has(&"plan") or not methods.has(&"mark_walls"):
		_finish()
		return
	_test_plan()
	var previous_segment := Global.attempt_segment
	var dummy := Node2D.new()
	dummy.add_to_group(&"player")
	add_child(dummy)
	Global.attempt_segment = 2
	for fixture: Dictionary in [
		{"seed":16102026,"coord":Vector2i(0,3),"id":944996572},
		{"seed":17,"coord":Vector2i(-3,5),"id":2128236757},
	]:
		await _test_actual_home(fixture)
	dummy.free()
	Global.attempt_segment = previous_segment
	_finish()


func _finish() -> void:
	print("CityDomesticInteriorTest: %d passed, %d failed" % [_passed,_failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _bed_context() -> Dictionary:
	var footprint: Dictionary = {}
	for y in range(9,17):
		for x in range(3,14):
			if y >= 12 or x >= 6:
				footprint[Vector2i(x,y)] = true
	var walls: Dictionary = {}
	for cell: Vector2i in footprint:
		for offset: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)]:
			if not footprint.has(cell+offset):
				walls[cell] = true
				break
	walls.erase(Vector2i(8,16))
	walls.erase(Vector2i(9,16))
	var floor_cells: Dictionary = footprint.duplicate()
	for cell: Vector2i in walls:
		floor_cells.erase(cell)
	var protected: Dictionary = {}
	for y in range(10,17):
		for x in range(8,10):
			if floor_cells.has(Vector2i(x,y)):
				protected[Vector2i(x,y)] = true
	return {"segment":2,"usage":&"row_house","civic":false,"building_id":944996572,"visual_seed":944996572,"small_count_max":1,"local_encounter_enabled":false,"force_large_loot":false,"cell_px":64,"footprint_px":PackedVector2Array([Vector2(192,768),Vector2(384,768),Vector2(384,576),Vector2(896,576),Vector2(896,1088),Vector2(192,1088)]),"doors":[{"pos":Vector2i(8,16),"dir":Vector2i.DOWN,"width":2}],"floor_cells":floor_cells,"wall_cells":walls,"protected_cells":protected,"world_origin":Vector2(0,6144)}


func _test_plan() -> void:
	var context := _bed_context()
	var before := var_to_str(context)
	var run_rng_state := Global._rng.state
	seed(20261020)
	var expected_next := randi()
	seed(20261020)
	var layout: Array = _adapter.call("plan",context)
	_check(randi() == expected_next and Global._rng.state == run_rng_state, "Domestic fitting consumes neither engine-global nor run-owned RNG")
	_check(var_to_str(context) == before, "Fitting does not mutate actual floor/wall/door context")
	_check(var_to_str(layout) == var_to_str(_adapter.call("plan",context)), "Repeated fitting is deterministic")
	_check_layout(layout,context,true,"bed floor")
	for change: Dictionary in [{"small_count_max":2},{"local_encounter_enabled":true},{"force_large_loot":true}]:
		var sensitive := context.duplicate(true)
		sensitive.merge(change,true)
		var sensitive_layout: Array = _adapter.call("plan",sensitive)
		_check(sensitive_layout.is_empty(),"Furniture preserves multi-item/security seeded reward policy "+str(change))
	var translated := context.duplicate(true)
	translated.world_origin = Vector2(-6144,10240)
	_check(var_to_str(layout) == var_to_str(_adapter.call("plan",translated)), "Negative streamed origin preserves the same local layout")
	var untended := context.duplicate(true)
	untended.visual_seed = 944996575
	var untended_layout: Array = _adapter.call("plan",untended)
	_check(not untended_layout.is_empty(), "Untended exterior variant alone does not reclassify an actual dwelling as uninhabited")
	for change: Dictionary in [{"segment":1},{"segment":3},{"civic":true},{"usage":&"workshop"},{"usage":&"shop"},{"usage":&"passage"},{"usage":&"service_annex"}]:
		var excluded := context.duplicate(true)
		excluded.merge(change,true)
		var excluded_layout: Array = _adapter.call("plan",excluded)
		_check(excluded_layout.is_empty(), "Household dressing excludes noneligible ownership " + str(change))
	var tiny := context.duplicate(true)
	tiny.floor_cells = {Vector2i(8,15):true}
	tiny.protected_cells = {Vector2i(8,15):true}
	var no_fit: Array = _adapter.call("plan",tiny)
	_check(no_fit.is_empty(), "A protected one-cell remainder does not force furniture into the door route")
	var partitioned := context.duplicate(true)
	for y in range(10,16):
		if y == 13:
			continue
		var cell := Vector2i(10,y)
		(partitioned.floor_cells as Dictionary).erase(cell)
		(partitioned.wall_cells as Dictionary)[cell] = true
	var partitioned_layout: Array = _adapter.call("plan",partitioned)
	_check_layout(partitioned_layout,partitioned,false,"partitioned floor")
	_check((partitioned.wall_cells as Dictionary).has(Vector2i(10,12)), "Existing partitions remain authoritative inputs")


func _check_layout(layout: Array, context: Dictionary, require_all: bool, tag: String) -> void:
	var kinds: Dictionary = {}
	var reserved: Dictionary = {}
	for record: Dictionary in layout:
		var complete := record.has_all(["kind","source_path","anchor_px","scale","contact_px","ground_rect_px","visible_rect_px","reserved_cells"])
		_check(complete,tag+" exports measured placement data")
		if not complete:
			continue
		var kind := StringName(record.kind)
		_check(not kinds.has(kind),tag+" has one purposeful "+String(kind))
		kinds[kind] = true
		var ground: Rect2 = record.ground_rect_px
		_check(ground.has_area(),tag+" has a real fitted ground footprint")
		for corner: Vector2 in [ground.position,Vector2(ground.end.x,ground.position.y),ground.end,Vector2(ground.position.x,ground.end.y)]:
			_check(Geometry2D.is_point_in_polygon(corner,context.footprint_px),tag+" keeps the measured ground inside the actual outline")
		var cells: Array = record.reserved_cells
		_check(not cells.is_empty(),tag+" declares its low-cover cells")
		var first := Vector2i((ground.position/CELL).floor())
		var last := Vector2i(((ground.end-Vector2.ONE*0.001)/CELL).floor())
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				var cell := Vector2i(x,y)
				_check((context.floor_cells as Dictionary).has(cell) and cells.has(cell),tag+" measured ground agrees with its actual floor reservation")
		for cell: Vector2i in cells:
			_check((context.floor_cells as Dictionary).has(cell) and not (context.wall_cells as Dictionary).has(cell),tag+" furniture uses genuine available floor")
			_check(not (context.protected_cells as Dictionary).has(cell) and not reserved.has(cell),tag+" leaves protected access clear and groups separate")
			reserved[cell] = true
		if ASSETS.has(kind):
			var expected: Dictionary = ASSETS[kind]
			_check(String(record.source_path) == String(expected.path),tag+" uses the supplied original "+String(kind))
			_check((record.anchor_px as Vector2).is_equal_approx(expected.anchor) and is_equal_approx(float(record.scale),float(expected.scale)),tag+" preserves original contact and uniform fitting scale")
			var contact: Vector2 = record.contact_px
			var source_ground: Rect2 = expected.ground
			var expected_ground := Rect2(contact+(source_ground.position-(expected.anchor as Vector2))*float(expected.scale),source_ground.size*float(expected.scale))
			_check(ground.is_equal_approx(expected_ground),tag+" measured footprint follows source datum instead of PNG center")
	if require_all:
		_check(kinds.size() == 4 and kinds.has_all([&"cot",&"hearth",&"table",&"crate"]),tag+" reads as sleeping, cooking and table/storage purpose")
	var available: Dictionary = (context.floor_cells as Dictionary).duplicate()
	for cell: Vector2i in reserved:
		available.erase(cell)
	var reached := _flood(available,Vector2i(9,16))
	_check(reached.size() == available.size(),tag+" retains every remaining room connection around furniture")
	for cell: Vector2i in context.protected_cells:
		_check(reached.has(cell),tag+" preserves the actual central doorway circulation")


func _flood(available: Dictionary, start: Vector2i) -> Dictionary:
	var reached: Dictionary = {}
	if not available.has(start):
		return reached
	var queue: Array[Vector2i] = [start]
	reached[start] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next := cell+direction
			if available.has(next) and not reached.has(next):
				reached[next] = true
				queue.append(next)
	return reached


func _manager(attempt_seed: int) -> ChunkManager:
	var theme := SegmentThemePicker.get_theme(2,attempt_seed)
	var plan := DistrictPlan.generate(2,attempt_seed,2048,theme)
	var manager := ChunkManager.new()
	theme.apply_to_chunk_manager(manager)
	manager.generation_enabled = false
	manager.ground_enabled = false
	manager.ground_splat_enabled = false
	manager.decals_enabled = false
	manager.deco_enabled = false
	manager.sites_enabled = false
	manager.parcels_chunk_chance = 0.95
	manager.district_sidewalk_width_cells = 1
	manager.district_sidewalk_corner_pad_cells = 1
	manager.cover_full_scene = load("res://scenes/world/cover/CoverFull.tscn")
	manager.cover_window_scene = load("res://scenes/world/cover/CoverWindow.tscn")
	manager.cover_half_scene = load("res://scenes/world/cover/CoverHalf.tscn")
	add_child(manager)
	manager.set_process(false)
	manager.configure_procedural_world(int(plan.seed),plan.connectors_by_chunk,plan.urban_access_by_chunk,plan.role_by_chunk,plan.terrain_by_chunk,plan.archetype_by_chunk)
	return manager


func _find_kit(chunk: Node2D, building_id: int) -> Node2D:
	for candidate: Node in chunk.get_children():
		if not candidate.is_in_group(&"city_block_building"):
			continue
		var roof := candidate.get("_roof") as RoofOverlay
		for child: Node in chunk.get_children():
			if not child is IndoorVolume or (child as IndoorVolume).building_id != building_id:
				continue
			for connection: Dictionary in child.body_entered.get_connections():
				if (connection.callable as Callable).get_object() == roof:
					return candidate as Node2D
	return null


func _test_actual_home(sample: Dictionary) -> void:
	var manager := _manager(int(sample.seed))
	var coord: Vector2i = sample.coord
	var signature := ""
	for generation in range(2):
		var chunk := manager._create_chunk(coord)
		manager._chunks[coord] = chunk
		var kit := _find_kit(chunk,int(sample.id))
		_check(kit != null,"Production still generates the actual kept home id="+str(sample.id))
		if kit == null:
			manager.free()
			return
		_check(kit.get_meta(&"building_usage",&"") == &"row_house" and not bool(kit.get("civic")),"Actual home has domestic usage and final noncivic ownership")
		_check_actual_volume_context(kit,manager.get_chunk_build_data(coord),int(sample.id))
		var group := kit.get_node_or_null("CityDomesticInterior") as Node2D
		var owner_ref: WeakRef
		_check(group != null,"Actual production home composes its purposeful domestic groups id="+str(sample.id))
		if group != null:
			owner_ref = weakref(group)
			var layout: Array = group.get_meta(&"domestic_layout",[])
			_check(layout.size() == 4,"Both genuine home fits supply cot, hearth, table and storage")
			var records: Dictionary = {}
			var data := manager.get_chunk_build_data(coord)
			for record: Dictionary in layout:
				records[StringName(record.kind)] = record
				for cell: Vector2i in record.reserved_cells:
					_check(data.kind_at(cell) == WorldBlockerGeometry.Kind.HALF_COVER,"Visible solid furniture records the existing low-cover physical contract")
					var global_cell := coord*32+cell
					_check(not manager.is_cell_walkable(global_cell),"Furniture collision and streamed pathing agree")
					var center := manager.cell_to_world_center(global_cell)
					_check(manager.projectile_hit_t(center-Vector2(24,0),center+Vector2(24,0),0.0) >= 0.0,"Furniture low-cover geometry participates in projectile queries")
			var current := var_to_str(layout)
			if generation == 0:
				signature = current
			else:
				_check(current == signature,"Actual chunk regeneration restores exactly the same measured furnishings")
			var seen: Dictionary = {}
			for child: Node in group.find_children("*","Sprite2D",true,false):
				var sprite := child as Sprite2D
				if not sprite.has_meta(&"domestic_kind"):
					continue
				var kind := StringName(sprite.get_meta(&"domestic_kind"))
				_check(not seen.has(kind),"Irregular volumes do not duplicate household sprites")
				seen[kind] = true
				_check(sprite.texture != null and sprite.is_visible_in_tree(),"Domestic original artwork remains a live sprite")
				if ASSETS.has(kind) and sprite.texture != null:
					var expected: Dictionary = ASSETS[kind]
					_check(sprite.texture.resource_path == String(expected.path) and sprite.scale.is_equal_approx(Vector2.ONE*float(expected.scale)),"Production uses the original prop source at measured uniform scale")
					if records.has(kind):
						var source_datum: Vector2 = expected.anchor
						var actual_contact := sprite.to_global(source_datum-sprite.texture.get_size()*0.5)
						_check(actual_contact.is_equal_approx(kit.to_global(records[kind].contact_px)),"Actual sprite feet use the measured source datum in the real streamed transform")
			_check(seen.size() == 4,"Actual household owner renders four purposeful original props")
			var roof := kit.get("_roof") as RoofOverlay
			var roof_poly: Node = roof.get_node_or_null("RoofPoly") if roof != null else null
			_check(roof_poly != null,"Actual household retains its roof polygon")
			if roof_poly != null:
				_check(not roof_poly.is_ancestor_of(group),"Cutaway reveal does not inherit the disappearing roof polygon's alpha")
			_check(group.z_index+kit.z_index == ChunkBlockVisualCatalog.PROP_Z,"Furnishings stay below the existing opaque roof and frontage")
		manager._unregister_chunk_cells(coord)
		manager._chunks.erase(coord)
		chunk.free()
		await get_tree().process_frame
		if owner_ref != null:
			_check(owner_ref.get_ref() == null,"Streamed chunk retirement releases its household owner")
	manager.free()


func _check_actual_volume_context(kit: Node2D, data: ChunkBuildData, building_id: int) -> void:
	var roof := kit.get("_roof") as RoofOverlay
	var connected: IndoorVolume
	for child: Node in kit.get_parent().get_children():
		if not child is IndoorVolume or (child as IndoorVolume).building_id != building_id:
			continue
		for connection: Dictionary in child.body_entered.get_connections():
			if (connection.callable as Callable).get_object() == roof:
				connected = child as IndoorVolume
	_check(connected != null,"Actual household context follows its connected reward owner")
	if connected == null:
		return
	var context: Dictionary = _adapter.call("context_for",kit,data,{},building_id)
	_check(int(context.get("small_count_max",0)) == 1 and not bool(context.get("local_encounter_enabled",true)),"Both kept real homes hand off their single-item ambient volume policy")
	var original_max := connected.small_count_max
	var original_encounter := connected.local_encounter_enabled
	connected.small_count_max = 2
	context = _adapter.call("context_for",kit,data,{},building_id)
	_check(int(context.get("small_count_max",0)) == 2,"Actual connected multi-item volume policy reaches furniture eligibility")
	connected.small_count_max = original_max
	connected.local_encounter_enabled = true
	context = _adapter.call("context_for",kit,data,{},building_id)
	_check(bool(context.get("local_encounter_enabled",false)),"Actual connected encounter policy reaches furniture eligibility")
	connected.local_encounter_enabled = original_encounter
