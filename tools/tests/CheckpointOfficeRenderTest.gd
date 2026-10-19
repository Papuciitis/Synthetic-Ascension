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
					mask.update(actor,feet,bounds)
					_check(mask.strength_at(sample)>0.99,"Neighbouring roof cannot exhaust coverage of the raised guard mass")
					_check(mask._triangles.size()<=32,"Guard family stays within the existing actor coverage capacity")
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
