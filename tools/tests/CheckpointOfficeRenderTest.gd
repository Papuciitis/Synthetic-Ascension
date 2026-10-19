extends Node2D

const KIT := preload("res://scenes/world/buildings/CityBlockKit.gd")
const PROFILES := preload("res://scenes/world/buildings/DistrictVisualProfiles.gd")
const ROOF := preload("res://scenes/world/buildings/RoofOverlay.tscn")
const MASK := preload("res://core/actors/player/PlayerRoofOcclusion.gd")
var passed := 0
var failed := 0

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(message)

func _budget_reference(mask: RefCounted, actor: Node2D, roofs: Array[RoofOverlay], feet: Vector2, bounds: Rect2) -> Array:
	# Isolate each real roof so its independent geometry cannot consume another
	# roof's budget. Their union is the reference for the shared capped mask.
	var reference: Array = []
	for roof: RoofOverlay in roofs: roof.remove_from_group(&"roof_occluders")
	for roof: RoofOverlay in roofs:
		roof.add_to_group(&"roof_occluders")
		mask.update(actor,feet,bounds)
		_check(mask._triangles.size()<32,"Each isolated reference roof is below the coverage cap")
		for index: int in mask._triangles.size():
			reference.append({"triangle":mask._triangles[index].duplicate(),"strength":mask._strengths[index]})
		roof.remove_from_group(&"roof_occluders")
	for roof: RoofOverlay in roofs: roof.add_to_group(&"roof_occluders")
	return reference

func _budget_samples_match(mask: RefCounted, reference: Array, bounds: Rect2) -> bool:
	# Dense interior/edge grid detects loss on either the guard or its neighbours;
	# checking a cap centroid alone could miss discarded late triangles.
	var samples := PackedVector2Array()
	for row: Dictionary in reference:
		var triangle: PackedVector2Array = row.triangle
		var center := (triangle[0]+triangle[1]+triangle[2])/3.0
		for edge: int in 3:
			for fraction: float in [0.1,0.5,0.9]:
				var point := triangle[edge].lerp(triangle[(edge+1)%3],fraction).lerp(center,0.01)
				if bounds.has_point(point): samples.append(point)
	for yy: int in range(1,30):
		for xx: int in range(1,22):
			samples.append(bounds.position + bounds.size*Vector2(float(xx)/22.0,float(yy)/30.0))
	for point: Vector2 in samples:
		var expected := 0.0
		for row: Dictionary in reference:
			if Geometry2D.is_point_in_polygon(point,row.triangle): expected=maxf(expected,row.strength)
		if not is_equal_approx(mask.strength_at(point),expected): return false
	return true

func _fixture(direction: Vector2i, irregular: bool) -> Dictionary:
	var roof := ROOF.instantiate() as RoofOverlay
	add_child(roof)
	var doors: Array = []
	var outline := PackedVector2Array()
	if irregular:
		outline = PackedVector2Array([Vector2(128,128),Vector2(640,128),Vector2(640,576),Vector2(384,576),Vector2(384,320),Vector2(128,320)])
		var anchor := Vector2i(5,2) if direction == Vector2i.UP else Vector2i(8,8) if direction == Vector2i.DOWN else Vector2i(9,5) if direction == Vector2i.RIGHT else Vector2i(2,3)
		doors.append({"pos":anchor,"dir":direction,"width":2})
		roof.configure_polygon(outline,Vector2(384,576),Vector2(640,576),[],&"workshop",17,doors,64)
	else:
		var anchor := Vector2i(7,4) if direction == Vector2i.UP else Vector2i(7,12) if direction == Vector2i.DOWN else Vector2i(12,8) if direction == Vector2i.RIGHT else Vector2i(2,8)
		doors.append({"pos":anchor,"dir":direction,"width":2})
		roof.configure(Rect2i(2,4,11,9),64,direction,null,&"workshop",17,doors)
	var kit := KIT.new()
	add_child(kit)
	var profile := PROFILES.resolve(&"checkpoint_lanes")
	profile["visual_seed"] = 17
	kit.configure(Rect2i(2,2,8,7) if irregular else Rect2i(2,4,11,9),64,doors,roof,true,outline,true,profile)
	return {"roof":roof,"kit":kit,"doors":doors}

func _run() -> void:
	for path: String in ["res://assets/world/districts/checkpoint_lanes/guard_arch_open.png","res://assets/world/districts/checkpoint_lanes/guard_arch_closed.png"]:
		var texture := KIT._texture(path)
		_check(texture != null,"Required original guard module is available through the production asset loader")
		_check(texture == KIT._texture(path),"Streamed guard instances share the original module texture resource")
	for irregular: bool in [false,true]:
		for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var fixture := _fixture(direction,irregular)
			var roof: RoofOverlay = fixture.roof
			var kit: Node2D = fixture.kit
			var plan: Dictionary = roof.get_meta(&"district_form_plan",{})
			_check(not plan.is_empty(),"Selected guard architecture builds a fitted plan dir=%s irregular=%s" % [direction,irregular])
			_check(roof.find_children("GuardRoofComposition","",true,false).size()==1,"Exactly one guard roof composition is present")
			_check(roof.find_children("CityRoofComposition","",true,false).is_empty(),"Guard family replaces the generic civic roof composition")
			_check(kit.find_children("GuardFrontage","",true,false).size()==1,"Guard frontage owns fitted arch/entry geometry")
			_check(kit.find_children("PaintedEntryLantern","",true,false).size()<=1,"Family does not duplicate common entry lantern")
			_check(roof.find_children("CivicRecordsBoard","",true,false).size()<=1,"Family does not duplicate the records board")
			_check(kit.find_children("*","PhysicsBody2D",true,false).is_empty(),"Architectural presentation adds no hidden physical geometry")
			_check(roof._doors == fixture.doors,"Roof retains all original normalised entry records")
			if not plan.is_empty() and plan.has_watch:
				var actor := Node2D.new()
				add_child(actor)
				var body := AnimatedSprite2D.new()
				var head := AnimatedSprite2D.new()
				actor.add_child(body)
				actor.add_child(head)
				var mask := MASK.new()
				mask.configure(body,head)
				var watch_caps := roof.find_children("GuardWatchCap","Polygon2D",true,false)
				_check(watch_caps.size()==1,"Supported guard office renders its compact watch roof")
				if not watch_caps.is_empty():
					var cap := watch_caps[0] as Polygon2D
					var cap_top := INF
					for point: Vector2 in cap.polygon: cap_top = minf(cap_top,point.y)
					var support_top := INF
					for point: Vector2 in plan.watch_support: support_top = minf(support_top,point.y)
					_check(cap_top < support_top-112.0,"Watch cap has an actual pitched silhouette above its upright wall head")
					var sample := Vector2.ZERO
					for point: Vector2 in cap.polygon: sample += cap.to_global(point)
					sample /= cap.polygon.size()
					var bounds := Rect2(sample-Vector2(55,75),Vector2(110,150))
					var feet := Vector2(sample.x,roof.footprint_outline_px[0].y-24)
					for alpha_value: float in [1.0,0.4,0.0]:
						roof._set_alpha(alpha_value)
						mask.update(actor,feet,bounds)
						_check(is_equal_approx(mask.strength_at(sample),alpha_value),"Raised roof pixel visibility follows the real roof alpha")
						for face_name: String in ["GuardWatchFront","GuardWatchSide"]:
							var face := roof.find_children(face_name,"Polygon2D",true,false)[0] as Polygon2D
							var face_sample := Vector2.ZERO
							for point: Vector2 in face.polygon: face_sample += face.to_global(point)
							face_sample /= face.polygon.size()
							mask.update(actor,feet,Rect2(face_sample-Vector2(55,75),Vector2(110,150)))
							_check(is_equal_approx(mask.strength_at(face_sample),alpha_value),"Full upright watch face follows its owning roof's visibility")
					var neighbour := ROOF.instantiate() as RoofOverlay
					add_child(neighbour)
					neighbour.position = Vector2(80,-40)
					neighbour.configure(Rect2i(2,4,11,9),64,Vector2i.DOWN,null)
					roof._set_alpha(1.0)
					var reference := _budget_reference(mask,actor,[roof,neighbour],feet,bounds)
					var budget_roofs: Array[RoofOverlay] = [roof,neighbour]
					var budget_kits: Array[Node2D] = []
					# Conservative projected-overlap stress, using actual
					# guard compositions; not a claim of natural parcel density.
					for offset: Vector2 in [Vector2(-32,0),Vector2(32,20),Vector2(0,-20),Vector2(-16,-32)]:
						if reference.size()>=28: break
						var extra_fixture := _fixture(Vector2i.DOWN,false)
						var extra: RoofOverlay = extra_fixture.roof
						var extra_cap := extra.find_children("GuardWatchCap","Polygon2D",true,false)[0] as Polygon2D
						var extra_center := Vector2.ZERO
						for point: Vector2 in extra_cap.polygon: extra_center+=extra_cap.to_global(point)
						extra.position=sample+offset-extra_center/extra_cap.polygon.size()
						budget_roofs.append(extra)
						budget_kits.append(extra_fixture.kit)
						reference = _budget_reference(mask,actor,budget_roofs,feet,bounds)
					print("Guard coverage stress dir=%s irregular=%s reference_triangles=%d roofs=%d" % [direction,irregular,reference.size(),budget_roofs.size()])
					_check(reference.size()>=28,"Neighbour fixture genuinely pressures the 32-triangle shared budget")
					for reverse_order: bool in [false,true]:
						move_child(roof,get_child_count()-1 if reverse_order else 0)
						mask.update(actor,feet,bounds)
						_check(mask._triangles.size()==mini(reference.size(),32),"Shared mask reaches the reference count or the actual fixed capacity")
						_check(_budget_samples_match(mask,reference,bounds),"Both roof stream orders match uncapped union coverage over the whole actor")
					mask.update(actor,feet,bounds)
					_check(mask.strength_at(sample)>0.99,"Neighbouring roof cannot exhaust coverage of the raised guard mass")
					_check(mask._triangles.size()<=32,"Guard family stays within the existing actor coverage capacity")
					for extra: RoofOverlay in budget_roofs.slice(2): extra.free()
					for extra_kit: Node2D in budget_kits: extra_kit.free()
					neighbour.free()
					var front_y := -INF
					for point: Vector2 in roof.footprint_outline_px: front_y = maxf(front_y,point.y)
					mask.update(actor,Vector2(sample.x,front_y+1),bounds)
					_check(is_zero_approx(mask.strength_at(sample)),"Actor in front of the whole building keeps ordinary appearance")
					roof._inside_count = 1
					roof._set_alpha(1.0)
					mask.update(actor,feet,bounds)
					_check(is_zero_approx(mask.strength_at(sample)),"Indoor ownership retains normal actor appearance")
					roof._inside_count = 0
					remove_child(roof)
					mask.update(actor,feet,bounds)
					_check(is_zero_approx(mask.strength_at(sample)),"Streaming the form out clears actor coverage")
					add_child(roof)
				actor.free()
			kit.free()
			roof.free()
	print("CheckpointOfficeRenderTest: %d passed, %d failed" % [passed,failed])
	get_tree().quit(1 if failed else 0)
