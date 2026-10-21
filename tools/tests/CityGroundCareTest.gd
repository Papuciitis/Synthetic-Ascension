extends Node
## Household ground follows actual use, footprint and planted corner without
## changing parcels. These checks fail if care becomes a global lawn or ring.

const KIT := preload("res://scenes/world/buildings/CityBlockKit.gd")
const ROOF := preload("res://scenes/world/buildings/RoofOverlay.tscn")
const CELL := 64
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
		print("PASS: ", message)
	else:
		_failed += 1
		push_error("FAIL: " + message)


func _bed_spec() -> Dictionary:
	return {
		"footprint_px": PackedVector2Array([Vector2(192,768),Vector2(384,768),Vector2(384,576),Vector2(896,576),Vector2(896,1088),Vector2(192,1088)]),
		"doors": [{"pos":Vector2i(8,16),"dir":Vector2i.DOWN,"width":2}],
		"visual_seed": 944996572,
		"garden_contact_px": Vector2(266,1102),
	}


func _tree_spec() -> Dictionary:
	return {
		"footprint_px": PackedVector2Array([Vector2(192,960),Vector2(960,960),Vector2(960,1472),Vector2(192,1472)]),
		"doors": [{"pos":Vector2i(9,15),"dir":Vector2i.UP,"width":2}],
		"visual_seed": 2128236757,
		"garden_contact_px": Vector2(200,1451),
	}


func _kit_fixture(spec: Dictionary, usage: StringName = &"row_house", civic: bool = false) -> Node2D:
	var roof := ROOF.instantiate() as RoofOverlay
	add_child(roof)
	var outline: PackedVector2Array = spec.footprint_px
	var rect := Rect2(outline[0],Vector2.ZERO)
	for point: Vector2 in outline:
		rect = rect.expand(point)
	roof.configure_polygon(outline,outline[-2],outline[-1],[],usage,int(spec.visual_seed),spec.doors,CELL)
	var kit := KIT.new()
	add_child(kit)
	kit.configure(Rect2i(Vector2i(rect.position/CELL),Vector2i(rect.size/CELL)),CELL,spec.doors,roof,civic,outline,true,{"building_usage":usage,"visual_seed":spec.visual_seed})
	return kit


func _test_policy() -> void:
	var probe := KIT.new()
	var available := probe.has_method("ground_care_spec")
	_check(available,"city kits expose actual domestic care context")
	probe.free()
	if not available:
		return
	Global.attempt_segment = 2
	for context: Dictionary in [_bed_spec(),_tree_spec()]:
		var kit := _kit_fixture(context)
		var expected_doors: Array = context.doors.duplicate(true)
		var spec: Dictionary = kit.call("ground_care_spec")
		_check(not spec.is_empty(),"the kept real home is eligible without relying on its facade role")
		_check(spec.get("footprint_px",PackedVector2Array()) == context.footprint_px,"care retains the exact actual roof footprint, including the L notch")
		_check(spec.get("doors",[]) == context.doors,"care retains the real signed door records")
		_check(spec.get("garden_contact_px",Vector2.INF).is_equal_approx(context.garden_contact_px),"care retains the measured bed/tree contact")
		var changed: Array = spec.get("doors",[])
		if not changed.is_empty():
			changed[0]["width"] = 99
		var again: Dictionary = kit.call("ground_care_spec")
		_check(again.get("doors",[]) == expected_doors,"care context cannot mutate production door records")
	for usage: StringName in [&"workshop",&"passage",&"shop"]:
		var kit := _kit_fixture(_bed_spec(),usage)
		_check((kit.call("ground_care_spec") as Dictionary).is_empty(),"noncivic %s is not classified as a home" % usage)
	var civic := _kit_fixture(_bed_spec(),&"row_house",true)
	_check((civic.call("ground_care_spec") as Dictionary).is_empty(),"civic row-house presentation receives no household care")
	var neglected := _bed_spec()
	neglected["visual_seed"] = 944996575
	var untended := _kit_fixture(neglected)
	_check((untended.call("ground_care_spec") as Dictionary).is_empty(),"stable variant three leaves a real home untended")
	# Care follows the household in every procedural district (S2..S10 and the
	# S11+ fallback), not the segment number; authored S1 never takes it.
	for segment: int in [3,7,11]:
		Global.attempt_segment = segment
		var later := _kit_fixture(_bed_spec())
		var later_spec: Dictionary = later.call("ground_care_spec")
		_check(not later_spec.is_empty() and later_spec.get("footprint_px",PackedVector2Array()) == _bed_spec().footprint_px and later_spec.get("doors",[]) == _bed_spec().doors,"segment %d homes are tended with their exact footprint and doors" % segment)
	Global.attempt_segment = 1
	var authored := _kit_fixture(_bed_spec())
	_check((authored.call("ground_care_spec") as Dictionary).is_empty(),"authored Segment 1 architecture never receives household care")
	Global.attempt_segment = 4
	var replaced := _kit_fixture(_bed_spec())
	var bed := Node2D.new()
	bed.name = "ReplacementGardenBed"
	bed.set_meta(&"city_garden_contact",Vector2(300,1110))
	replaced.add_child(bed)
	replaced.move_child(bed,0)
	var replaced_spec: Dictionary = replaced.call("ground_care_spec")
	_check(replaced_spec.get("garden_contact_px",Vector2.INF).is_equal_approx(Vector2(300,1110)),"any garden art that declares a garden contact anchors the household pocket")
	Global.attempt_segment = 2


func _test_pockets() -> void:
	var probe := GroundSplatRenderer.new()
	var available := probe.has_method("paint_domestic_care") and probe.has_method("care_at") and probe.has_method("care_signature")
	_check(available,"the renderer supports bounded care painting and deterministic probes")
	probe.free()
	if not available:
		return
	for context: Dictionary in [_bed_spec(),_tree_spec()]:
		var splat := GroundSplatRenderer.new()
		splat.configure(CELL,32)
		add_child(splat)
		splat.set_chunk_base(Vector2i.ZERO,0)
		# The mask must reject footprint cells even when no indoor floor stamp
		# hides them, and reserve door access independently of paving.
		splat.call("paint_domestic_care",Vector2i.ZERO,context)
		var count := 0
		var fractional := 0
		var near_garden := 0
		var west := 0
		for y in 32:
			for x in 32:
				var cell := Vector2i(x,y)
				var value: float = splat.call("care_at",cell)
				if value <= 0.0:
					continue
				count += 1
				if value < 0.98: fractional += 1
				var center := (Vector2(cell)+Vector2(0.5,0.5))*CELL
				_check(not Geometry2D.is_point_in_polygon(center,context.footprint_px),"care never enters the actual footprint at %s" % cell)
				_check(center.distance_to(context.garden_contact_px) < CELL*6.0,"care remains local to the planted household corner")
				if center.distance_to(context.garden_contact_px) < CELL*3.0: near_garden += 1
				if center.x < 192.0: west += 1
		_check(count >= 4 and count < 90,"one soft pocket occupies a bounded minority of the chunk (%d cells)" % count)
		_check(fractional >= 2,"care has soft intermediate coverage rather than a solid rectangle")
		_check(near_garden >= 3 and west >= 2,"care joins the kept planted corner to nearby side ground, including the north-entry tree")
		_check(float(splat.call("care_at",Vector2i(16,16))) == 0.0 and float(splat.call("care_at",Vector2i(30,30))) == 0.0,"opposite-side and outer wild ground remain rough instead of forming a ring")
		var door: Dictionary = context.doors[0]
		var direction: Vector2i = door.dir
		var across := Vector2i(-direction.y,direction.x)
		for distance in range(1,4):
			for offset in range(-1,2):
				var access: Vector2i = door.pos+direction*distance+across*offset
				_check(float(splat.call("care_at",access)) == 0.0,"real door access stays outside care even on vegetated base")
		var before: PackedByteArray = splat.call("care_signature",Vector2i.ZERO)
		splat.call("paint_domestic_care",Vector2i.ZERO,context)
		_check(before == splat.call("care_signature",Vector2i.ZERO),"reapplying the same footprint context reproduces exact care bytes")
		_check(float(splat.call("care_at",Vector2i(-1,20))) == 0.0,"a local household pocket does not write into a neighboring chunk")
		splat.queue_free()


func _test_production_footway_pockets() -> void:
	# The unpaved policy fixtures cannot catch a pocket whose useful center is
	# lost under the final production frontage. Generate the same real homes,
	# retaining their floor stamps, then require usable care on actual vegetation.
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	Global.attempt_segment = 2
	for sample: Dictionary in [
		{"seed":16102026,"coord":Vector2i(0,3),"id":944996572,"spec":_bed_spec()},
		{"seed":17,"coord":Vector2i(-3,5),"id":2128236757,"spec":_tree_spec()},
	]:
		var theme := SegmentThemePicker.get_theme(2,int(sample.seed))
		var plan := DistrictPlan.generate(2,int(sample.seed),2048,theme)
		var cm := ChunkManager.new()
		theme.apply_to_chunk_manager(cm)
		cm.generation_enabled = false
		cm.decals_enabled = false
		cm.deco_enabled = false
		cm.sites_enabled = false
		cm.parcels_chunk_chance = 0.95
		cm.district_sidewalk_width_cells = 1
		cm.district_sidewalk_corner_pad_cells = 1
		cm.cover_full_scene = load("res://scenes/world/cover/CoverFull.tscn")
		cm.cover_window_scene = load("res://scenes/world/cover/CoverWindow.tscn")
		cm.cover_half_scene = load("res://scenes/world/cover/CoverHalf.tscn")
		add_child(cm)
		cm.set_process(false)
		cm.configure_procedural_world(int(plan.seed),plan.connectors_by_chunk,plan.urban_access_by_chunk,plan.role_by_chunk,plan.terrain_by_chunk,plan.archetype_by_chunk)
		var coord: Vector2i = sample.coord
		var chunk := cm._create_chunk(coord)
		cm._chunks[coord] = chunk
		var splat := cm.get_ground_splat()
		var counts: Dictionary = {}
		var positive := 0
		var strong := 0
		var eligible := true
		var local_context: Dictionary = sample.spec
		for y in 32:
			for x in 32:
				var cell := coord*32+Vector2i(x,y)
				var material := splat.material_at(cell)
				counts[material] = int(counts.get(material,0))+1
				var care := splat.care_at(cell)
				if care <= 0.0: continue
				if material != 0: eligible = false
				var point := (Vector2(x,y)+Vector2(0.5,0.5))*CELL
				if point.distance_to(local_context.garden_contact_px) >= CELL*6.0: continue
				positive += 1
				if care >= 0.7: strong += 1
		if int(sample.id) == 944996572:
			_check(counts == {0:716,2:125,3:6,4:177},"the bed fixture retains the production floor ownership from the failed native trial")
			var compact_core := true
			for core_y in range(14,17):
				for core_x in range(0,3):
					if splat.care_at(coord*32+Vector2i(core_x,core_y)) < 0.7:
						compact_core = false
			_check(compact_core,"the legal three-by-three bed pocket reads as a useful cared core rather than a thin strip")
			_check(positive >= 15,"readability correction preserves the existing fifteen-cell legal bed support")
		_check(eligible,"production-footway care stays on actual available vegetation id=%d" % int(sample.id))
		_check(positive >= 8,"production footways leave at least eight cared vegetation cells near the kept garden id=%d actual=%d" % [int(sample.id),positive])
		_check(strong >= 3,"the actual garden has at least three substantial lawn cells beyond paving id=%d actual=%d" % [int(sample.id),strong])
		print("Production care fixture: id=%d positive=%d strong=%d materials=%s" % [int(sample.id),positive,strong,str(counts)])
		cm.free()
	player.free()


func _run() -> void:
	var previous_segment := Global.attempt_segment
	_test_policy()
	_test_pockets()
	_test_production_footway_pockets()
	Global.attempt_segment = previous_segment
	print("CityGroundCareTest: %d passed, %d failed" % [_passed,_failed])
	get_tree().quit(1 if _failed else 0)
