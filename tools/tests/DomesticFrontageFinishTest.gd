extends Node2D
## The actual old upper-band mapping is 15x/11.84x anisotropic on this home.

const KIT := preload("res://scenes/world/buildings/CityBlockKit.gd")
const FRONTAGES := preload("res://scenes/world/buildings/CityBlockFrontages.gd")
const ROOF := preload("res://scenes/world/buildings/RoofOverlay.tscn")
const OUTLINE_POINTS := [Vector2(192,768),Vector2(384,768),Vector2(384,576),Vector2(896,576),Vector2(896,1088),Vector2(192,1088)]
const DOOR := {"pos":Vector2i(8,16),"dir":Vector2i.DOWN,"width":2}
const PLASTER_SHADER := "res://scenes/world/buildings/domestic_plaster.gdshader"
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


func _fixture(segment: int, usage: StringName, irregular: bool = true) -> Dictionary:
	Global.attempt_segment = segment
	var host := Node2D.new()
	add_child(host)
	var roof := ROOF.instantiate() as RoofOverlay
	host.add_child(roof)
	var doors: Array = [DOOR.duplicate(true)]
	var rect := Rect2i(3,9,11,8)
	var outline := PackedVector2Array(OUTLINE_POINTS)
	if irregular:
		roof.configure_polygon(outline,Vector2(192,1088),Vector2(896,1088),[],usage,944996572,doors,64)
	else:
		doors = [{"pos":Vector2i(9,15),"dir":Vector2i.UP,"width":2}]
		rect = Rect2i(3,15,12,8)
		roof.configure(rect,64,Vector2i.UP,null,usage,2128236757,doors)
	var kit := KIT.new()
	host.add_child(kit)
	kit.configure(rect,64,doors,roof,false,outline if irregular else PackedVector2Array(),true,{"building_usage":usage,"visual_seed":944996572})
	return {"host":host,"kit":kit,"roof":roof,"doors":doors}


func _bounds(points: PackedVector2Array) -> Rect2:
	var bounds := Rect2(points[0],Vector2.ZERO)
	for point: Vector2 in points:
		bounds = bounds.expand(point)
	return bounds


func _run() -> void:
	var previous_segment := Global.attempt_segment
	var dummy := Node2D.new()
	dummy.add_to_group(&"player")
	add_child(dummy)
	var fixture := _fixture(2,&"row_house")
	var kit: Node2D = fixture.kit
	var upper_count := 0
	var upper_runs: Dictionary = {}
	for node: Node in kit.find_children("*","Polygon2D",true,false):
		var face := node as Polygon2D
		if face.texture == null or face.texture.resource_path != "res://assets/world/city_block/house_front.png" or face.polygon.size() != 4:
			continue
		var bounds := _bounds(face.polygon)
		if not face.has_meta(&"domestic_upper_run"):
			continue
		upper_count += 1
		var run: Rect2 = face.get_meta(&"domestic_upper_run")
		upper_runs[run] = true
		_check(is_equal_approx(bounds.size.y,32.0) and run.size.x >= 240.0,"Continuous head courses retain a restrained height and actual window-wing ownership")
		_check(face.uv.size() == 4,"Domestic upper fields publish source sampling coordinates")
		if face.uv.size() == 4:
			var density_x := (face.uv[1]-face.uv[0]).length()/(face.polygon[1]-face.polygon[0]).length()
			var density_y := (face.uv[3]-face.uv[0]).length()/(face.polygon[3]-face.polygon[0]).length()
			_check(is_equal_approx(density_x,density_y),"Real304/240px upper fields preserve isotropic source detail instead of stretched tan grain")
			_check(is_equal_approx(density_x,2.0),"Plain plaster keeps a stable two-texel-per-world-pixel native material scale")
		var material := face.material as ShaderMaterial
		_check(material != null and material.shader != null and material.shader.resource_path == PLASTER_SHADER,"Domestic upper fields repeat only the original clean plaster region")
		_check(face.is_in_group(&"foreground_solid_occluders"),"Finished upper mass retains actual opaque-plane coverage")
	_check(upper_runs.size() == 2 and upper_count == 2,"The retained bed home has one quiet head course per window wing without repeated panel seams")
	var portal := kit.find_child("IrregularUprightPortal",true,false) as Node2D
	_check(portal != null,"The real irregular doorway retains its cardinal upright adapter")
	if portal != null:
		var gap := FRONTAGES._door_box(DOOR,64)
		var opening: Rect2 = portal.get_meta(&"opening_face",Rect2())
		_check(is_equal_approx(opening.size.x,gap.size.x) and is_equal_approx(opening.position.x,gap.position.x),"Visible entry preserves the entire physical128px opening width")
		_check(is_equal_approx(opening.size.y,128.0) and is_equal_approx(opening.end.y,gap.end.y-16.0),"Supported header reduces the blank void while preserving its original ground baseline")
		var header := portal.get_node_or_null("DomesticDoorHeader") as Polygon2D
		_check(header != null and header.is_in_group(&"foreground_solid_occluders"),"New supported entry header participates in per-pixel foreground coverage")
		var threshold := portal.get_node_or_null("FlushThreshold") as Polygon2D
		_check(threshold != null and not threshold.is_in_group(&"foreground_solid_occluders"),"Flush threshold stays a walkable surface rather than an opaque wall")
	_check(kit.find_children("*","CollisionObject2D",true,false).is_empty(),"Domestic facade finish adds no collision or replacement physical doors")
	(fixture.roof as RoofOverlay)._set_alpha(0.0)
	var returns := kit.get_node_or_null("CardinalWallReturns") as Node2D
	_check(returns != null,"Actual frontage owns its cutaway group")
	if returns != null:
		_check(is_zero_approx(returns.modulate.a),"Finished upper fields and doorway still clear with the actual roof cutaway")
	(fixture.host as Node).free()
	var north := _fixture(2,&"row_house",false)
	var recess := (north.kit as Node).find_child("CardinalDoorRecess",true,false)
	_check(recess != null and recess.get_meta(&"door_direction",Vector2i.ZERO) == Vector2i.UP,"Fruit home's north entrance retains its original direction and opening")
	_check((north.kit as Node).find_child("DomesticDoorHeader",true,false) == null,"Irregular south header repair does not manufacture a second north-facing portal")
	(north.host as Node).free()
	for context: Dictionary in [{"segment":2,"usage":&"workshop"},{"segment":3,"usage":&"row_house"}]:
		var control := _fixture(int(context.segment),StringName(context.usage))
		for node: Node in (control.kit as Node).find_children("*","Polygon2D",true,false):
			var material := (node as Polygon2D).material as ShaderMaterial
			_check(material == null or material.shader.resource_path != PLASTER_SHADER,"Nonhome and S3 facade presentation stays outside the new domestic material")
		(control.host as Node).free()
	dummy.free()
	Global.attempt_segment = previous_segment
	print("DomesticFrontageFinishTest: %d passed, %d failed" % [_passed,_failed])
	get_tree().quit(1 if _failed > 0 else 0)
