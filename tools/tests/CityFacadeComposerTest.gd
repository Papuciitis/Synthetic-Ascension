extends Node2D
## Composed frontages in every city segment keep the physical and coverage
## contracts the earlier domestic facade tests protected: the real doorway gap,
## no collision, aspect-true modules, one registered owner per opaque pixel,
## roof-driven fading, and deterministic per-building variety.

const KIT := preload("res://scenes/world/buildings/CityBlockKit.gd")
const COMPOSER := preload("res://scenes/world/buildings/CityFacadeComposer.gd")
const ROOF := preload("res://scenes/world/buildings/RoofOverlay.tscn")
const OUTLINE_POINTS := [Vector2(192,768),Vector2(384,768),Vector2(384,576),Vector2(896,576),Vector2(896,1088),Vector2(192,1088)]
## A recessed south bay: the door sits in the bay's back wall between two wings.
const BAY_POINTS := [Vector2(192,576),Vector2(896,576),Vector2(896,1088),Vector2(640,1088),Vector2(640,1024),Vector2(320,1024),Vector2(320,1088),Vector2(192,1088)]
const SOLID_GROUP := &"foreground_solid_occluders"
var _passed := 0
var _failed := 0


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		push_error("FAIL: "+message)


func _fixture(segment: int, usage: StringName, door_dir: Vector2i, irregular: bool, seed_value: int, family: StringName = &"service_courtyards", bay: bool = false) -> Dictionary:
	Global.attempt_segment = segment
	var host := Node2D.new()
	add_child(host)
	var roof := ROOF.instantiate() as RoofOverlay
	host.add_child(roof)
	var rect := Rect2i(3,9,11,8) if irregular else Rect2i(3,15,12,8)
	var doors: Array = []
	match door_dir:
		Vector2i.DOWN: doors = [{"pos":Vector2i(8,16) if irregular else Vector2i(9,22),"dir":Vector2i.DOWN,"width":2}]
		Vector2i.UP: doors = [{"pos":Vector2i(9,15),"dir":Vector2i.UP,"width":2}]
		Vector2i.RIGHT: doors = [{"pos":Vector2i(14,19),"dir":Vector2i.RIGHT,"width":2}]
	var outline := PackedVector2Array(OUTLINE_POINTS) if irregular else PackedVector2Array()
	if bay:
		outline = PackedVector2Array(BAY_POINTS)
		# Generator geometry: the door sits 128 px from the bay's west end, 64 px from its east end.
		doors = [{"pos":Vector2i(7,15),"dir":Vector2i.DOWN,"width":2}]
	if irregular:
		roof.configure_polygon(outline,Vector2(192,1088),Vector2(896,1088),[],usage,seed_value,doors,64)
	else:
		roof.configure(rect,64,door_dir,null,usage,seed_value,doors)
	var kit := KIT.new()
	host.add_child(kit)
	kit.configure(rect,64,doors,roof,false,outline,true,{"building_usage":usage,"visual_seed":seed_value,"family_id":family})
	return {"host":host,"kit":kit,"roof":roof,"doors":doors}


## Registered coverage faces of the composed frontage.
func _solids(kit: Node2D) -> Array[Polygon2D]:
	var result: Array[Polygon2D] = []
	for node: Node in kit.find_children("*","Polygon2D",true,false):
		if node.is_in_group(SOLID_GROUP) and node.has_meta(&"facade_coverage"):
			result.append(node)
	return result


## Visible opaque pieces: wall fields, plinths and modules.
func _visible(kit: Node2D) -> Array[Polygon2D]:
	var result: Array[Polygon2D] = []
	for node: Node in kit.find_children("*","Polygon2D",true,false):
		# Weathering stains are opaque wall pieces cut from the field (one owner per pixel).
		if node.has_meta(&"facade_wall_field") or node.has_meta(&"facade_plinth") or node.has_meta(&"facade_module") or node.has_meta(&"facade_weathering"):
			result.append(node)
	return result


func _covered(kit: Node2D, point: Vector2) -> bool:
	for face: Polygon2D in _solids(kit):
		if Geometry2D.is_point_in_polygon(face.to_local(kit.to_global(point)),face.polygon): return true
	return false


func _rect_of(shape: Polygon2D) -> Rect2:
	# In the parent's space: weathering pieces are unit squares scaled to their area.
	var box := Rect2(shape.transform * shape.polygon[0],Vector2.ZERO)
	for point: Vector2 in shape.polygon: box = box.expand(shape.transform * point)
	return box


func _layout(kit: Node2D) -> String:
	var parts: Array[String] = []
	for shape: Polygon2D in _visible(kit):
		if shape.has_meta(&"facade_module"): parts.append("%s@%s" % [shape.get_meta(&"facade_module"),_rect_of(shape)])
	parts.sort()
	return ",".join(parts)


func _run() -> void:
	var previous_segment := Global.attempt_segment
	var dummy := Node2D.new()
	dummy.add_to_group(&"player")
	add_child(dummy)
	var layouts: Dictionary = {}
	for segment: int in [2,5,9]:
		for usage: StringName in [&"row_house",&"shop",&"workshop",&"passage"]:
			for door_dir: Vector2i in [Vector2i.DOWN,Vector2i.UP,Vector2i.RIGHT]:
				for irregular: bool in [false,true]:
					if irregular and door_dir != Vector2i.DOWN: continue
					var label := "seg%d %s %s %s" % [segment,usage,door_dir,"L" if irregular else "rect"]
					var fixture := _fixture(segment,usage,door_dir,irregular,1000+segment*17+int(usage.hash()%97))
					var kit: Node2D = fixture.kit
					_check(COMPOSER.owns(kit),label+": ordinary building uses the composed frontage in every segment")
					_check(kit.find_children("*","CollisionObject2D",true,false).is_empty(),label+": composed frontage adds no collision")
					var solids := _solids(kit)
					_check(not solids.is_empty(),label+": south wall has registered composed masonry")
					var runs := kit.find_children("*","Polygon2D",true,false).filter(func(node: Node) -> bool: return node.has_meta(&"facade_wall_field")).map(func(node: Node) -> Rect2: return node.get_meta(&"facade_wall_field"))
					var distinct_runs: Dictionary = {}
					for run_rect: Rect2 in runs: distinct_runs[run_rect] = true
					_check(solids.size() <= 4*maxi(1,distinct_runs.size()),label+": a few coverage faces per run keep WorldCover's per-frame scan small (%d)" % solids.size())
					var overlap := false
					for a: int in solids.size():
						for b: int in range(a+1,solids.size()):
							if _rect_of(solids[a]).intersection(_rect_of(solids[b])).get_area() > 0.5: overlap = true
					_check(not overlap,label+": coverage faces never double an actor's cover")
					var visible := _visible(kit)
					var visible_overlap := false
					for a: int in visible.size():
						for b: int in range(a+1,visible.size()):
							if _rect_of(visible[a]).intersection(_rect_of(visible[b])).get_area() > 0.5: visible_overlap = true
					_check(not visible_overlap,label+": every opaque facade pixel is drawn by exactly one piece")
					for shape: Polygon2D in visible:
						if not shape.has_meta(&"facade_module") or shape.texture == null: continue
						# Doorways fit the physical gap exactly and may compress under the eave.
						if String(shape.get_meta(&"facade_module")).begins_with("door"): continue
						# Uniform scale between the mapped texture region and the drawn rect.
						var box := _rect_of(shape)
						var uv_box := Rect2(shape.uv[0],Vector2.ZERO)
						for uv: Vector2 in shape.uv: uv_box = uv_box.expand(uv)
						var sx := box.size.x/uv_box.size.x
						var sy := box.size.y/uv_box.size.y
						_check(absf(sx-sy) < sy*0.02,label+": module keeps its source aspect")
					var frames := kit.find_children("FacadeDoorFrame*","Polygon2D",true,false)
					var openings := kit.find_children("FacadeDoorOpening*","Sprite2D",true,false)
					if door_dir == Vector2i.DOWN:
						var gap := COMPOSER.door_box(fixture.doors[0],64)
						_check(frames.size() >= 3 and openings.size() == 1,label+": real south door gets one doorway module")
						if openings.size() == 1:
							var opening: Rect2 = openings[0].get_meta(&"facade_door_opening")
							_check(absf(opening.position.x-gap.position.x) < 0.5 and absf(opening.size.x-gap.size.x) < 0.5,label+": painted opening equals the carver's physical gap")
							_check(not openings[0].is_in_group(&"foreground_occluders"),label+": walkable opening stays uncovered")
							for shape: Polygon2D in solids:
								_check(not _rect_of(shape).intersects(opening.grow(-1.0)),label+": no masonry or module covers the open doorway")
							# Feet on the threshold, just inside or just outside the facade foot.
							for probe_y: float in [gap.end.y-24.0,gap.end.y-8.0,gap.end.y+2.0]:
								_check(not _covered(kit,Vector2(gap.get_center().x,probe_y)),label+": walkable threshold stays uncovered at y=%d" % probe_y)
						for frame: Node in frames:
							# Side jambs cover like the wall; the head above an arch is open.
							var frame_box := _rect_of(frame as Polygon2D)
							if frame_box.end.x <= gap.position.x+0.5 or frame_box.position.x >= gap.end.x-0.5:
								_check(_covered(kit,frame_box.get_center()),label+": doorway frame occludes like the wall around it")
					else:
						_check(frames.is_empty() and openings.is_empty(),label+": visible south wall invents no door for a %s entry" % door_dir)
					if door_dir == Vector2i.RIGHT:
						var side := COMPOSER.door_box(fixture.doors[0],64)
						var bounds: Rect2 = kit.get("bounds")
						_check(float(kit.get("_facade_height")) <= maxf(96.0,bounds.end.y-16.0-side.end.y)+0.01,label+": south facade stays below the side doorway")
					var roof: RoofOverlay = fixture.roof
					roof._set_alpha(0)
					var faded := true
					for shape: Polygon2D in solids:
						var item: CanvasItem = shape
						var strength := 1.0
						while item != null and item != kit:
							strength *= item.modulate.a
							item = item.get_parent() as CanvasItem
						if strength > 0.001: faded = false
					_check(faded,label+": composed frontage fades with the actual roof cutaway")
					roof._set_alpha(1)
					layouts[_layout(kit)] = true
					var again := _fixture(segment,usage,door_dir,irregular,1000+segment*17+int(usage.hash()%97))
					_check(_layout(again.kit) == _layout(kit),label+": composition is deterministic for one building")
					(again.host as Node).free()
					(fixture.host as Node).free()
	for usage: StringName in [&"row_house",&"workshop",&"passage"]:
		var recessed := _fixture(3,usage,Vector2i.DOWN,true,4242,&"service_courtyards",true)
		var pieces := _visible(recessed.kit)
		var clash := false
		for a: int in pieces.size():
			for b: int in range(a+1,pieces.size()):
				if _rect_of(pieces[a]).intersection(_rect_of(pieces[b])).get_area() > 0.5: clash = true
		_check(not clash,"recessed %s bay: quoins never overlap the doorway frame" % usage)
		var bay_quoins := 0
		for piece: Polygon2D in pieces:
			var box := _rect_of(piece)
			if piece.get_meta(&"facade_module",&"") == &"quoin" and box.end.y > 1024.0-40.0 and box.end.y < 1024.0: bay_quoins += 1
		_check(bay_quoins == 0,"recessed %s bay: inner corners of the bay carry no quoins" % usage)
		(recessed.host as Node).free()
	var seeds: Dictionary = {}
	var slate := 0
	for seed_value: int in range(1,41):
		var sample := _fixture(5,&"row_house",Vector2i.DOWN,false,seed_value,&"checkpoint_lanes")
		seeds[_layout(sample.kit)] = true
		var pale: bool = COMPOSER.family_for(sample.kit) == &"pale"
		var slate_roof: bool = StringName(sample.kit.get_meta(&"city_roof_material")) == &"slate"
		_check(pale == slate_roof,"slate roofs carry pale ashlar walls and clay roofs warm plaster")
		if slate_roof: slate += 1
		(sample.host as Node).free()
	_check(seeds.size() >= 6,"building seeds vary window rhythm and fittings (%d layouts)" % seeds.size())
	_check(slate > 6 and slate < 34,"district roof share mixes slate and clay houses (%d/40 slate)" % slate)
	dummy.free()
	Global.attempt_segment = previous_segment
	print("CityFacadeComposerTest: %d passed, %d failed" % [_passed,_failed])
	get_tree().quit(1 if _failed > 0 else 0)
