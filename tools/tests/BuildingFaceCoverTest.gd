extends Node2D
## Actual upright building art must cover entities below the projected roof,
## while its authored doorway holes and physical front edge remain clear.

const KIT := preload("res://scenes/world/buildings/CityBlockKit.gd")
const ROOF := preload("res://scenes/world/buildings/RoofOverlay.tscn")
const FOREGROUND := preload("res://core/systems/world/visibility/ForegroundSpriteCoverage.gd")
const WORLD_COVER := preload("res://core/systems/world/visibility/WorldCover.gd")
const SOLID_GROUP := &"foreground_solid_occluders"
const GROUND_META := &"foreground_ground_contact"
const OUTLINE := [Vector2(128,128),Vector2(640,128),Vector2(640,576),Vector2(384,576),Vector2(384,320),Vector2(128,320)]

var _passes := 0
var _failures := 0
var _cover: Node


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error(label)


func _run() -> void:
	var old_segment := Global.attempt_segment
	Global.attempt_segment = 2
	_cover = WORLD_COVER.get_for(self)
	await _test_irregular_faces()
	for civic: bool in [false,true]:
		for direction: Vector2i in [Vector2i.DOWN,Vector2i.UP]:
			await _test_rectangular_faces(civic,direction)
	Global.attempt_segment = old_segment
	print("BuildingFaceCoverTest passes=%d failures=%d" % [_passes,_failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _fixture(civic: bool, direction: Vector2i, irregular: bool) -> Dictionary:
	var parent := Node2D.new()
	add_child(parent)
	var roof := ROOF.instantiate() as RoofOverlay
	parent.add_child(roof)
	var door := {"pos":Vector2i(6,8) if direction == Vector2i.DOWN else Vector2i(6,2),"dir":direction,"width":2}
	var doors: Array = [door]
	var outline := PackedVector2Array(OUTLINE) if irregular else PackedVector2Array()
	if irregular:
		roof.configure_polygon(outline,Vector2(384,576),Vector2(640,576),[],&"row_house",0,doors)
	else:
		roof.configure(Rect2i(2,2,8,7),64,direction,null,&"row_house",0,doors)
	var kit := KIT.new()
	parent.add_child(kit)
	kit.configure(Rect2i(2,2,8,7),64,doors,roof,civic,outline,true,{"building_usage":&"row_house","visual_seed":1})
	return {"parent":parent,"kit":kit,"roof":roof,"door":door}


func _test_irregular_faces() -> void:
	var fixture := _fixture(false,Vector2i.DOWN,true)
	var kit := fixture.kit as Node2D
	var roof := fixture.roof as RoofOverlay
	# Composed frontage: the opaque wall field of the lower south run (wall base
	# 560 = footprint edge 576 - 16) is a bounded solid upright plane.
	var lower_field: Polygon2D
	for node: Node in kit.find_children("*","Polygon2D",true,false):
		if not node.has_meta(&"facade_wall_field"): continue
		var span: Rect2 = node.get_meta(&"facade_wall_field")
		if is_equal_approx(span.end.y,560.0) and node.is_in_group(SOLID_GROUP):
			lower_field = node
			break
	_check(lower_field != null,"actual irregular house supplies its existing painted window bays")
	_check(lower_field != null,"fixture has a lower south-facing wall bay below the roof")
	if lower_field != null:
		var ground: Vector2 = lower_field.get_meta(GROUND_META)
		_check(is_equal_approx(ground.y,576.0),"irregular bay ground depth uses the real footprint edge rather than its sprite bottom")
		var center := Vector2.ZERO
		for point: Vector2 in lower_field.polygon: center += point
		var point := lower_field.to_global(center/lower_field.polygon.size())
		_cover.call("refresh",self,true)
		_check(float(_cover.call("strength_at",point,575.0)) > 0.9,"opaque window pixels below the roof cover a behind entity")
		_check(is_zero_approx(float(_cover.call("strength_at",point,577.0))),"the same wall pixel leaves an entity in front of the footprint normal")
		roof._set_alpha(0)
		_cover.call("refresh",self,true)
		_check(is_zero_approx(float(_cover.call("strength_at",point,575.0))),"actual house cutaway clears its upright window coverage")
		roof._set_alpha(1)
	var frame := kit.find_child("FacadeDoorFrame*",true,false) as Polygon2D
	var opening_sprite := kit.find_child("FacadeDoorOpening",true,false) as Sprite2D
	_check(frame != null and opening_sprite != null,"actual irregular doorway retains its portal")
	if frame != null and opening_sprite != null:
		_check(frame.is_in_group(SOLID_GROUP) and frame.has_meta(GROUND_META),"opaque upright doorway frame has a bounded descriptor")
		_check(not opening_sprite.is_in_group(FOREGROUND.GROUP) and not opening_sprite.is_in_group(SOLID_GROUP),"walkable opening remains outside solid upright coverage")
		var opening: Rect2 = opening_sprite.get_meta(&"facade_door_opening")
		_cover.call("refresh",self,true)
		_check(is_zero_approx(float(_cover.call("strength_at",kit.to_global(Vector2(opening.get_center().x,opening.end.y-32)),575.0))),"actual doorway gap stays clear below its lintel")
	var upper_found := false
	for node: Node in kit.find_children("*","Polygon2D",true,false):
		var panel := node as Polygon2D
		if panel.is_in_group(SOLID_GROUP) and panel.get_parent().name == &"CardinalWallReturns":
			upper_found = true
	_check(upper_found,"opaque upper plaster receives real face coverage")
	(fixture.parent as Node).queue_free()
	await get_tree().process_frame


func _test_rectangular_faces(civic: bool, direction: Vector2i) -> void:
	var fixture := _fixture(civic,direction,false)
	var kit := fixture.kit as Node2D
	var faces: Array[Sprite2D] = []
	for node: Node in kit.find_children("*","Sprite2D",true,false):
		var sprite := node as Sprite2D
		if sprite.texture == kit.get("_facade") and sprite.is_in_group(FOREGROUND.GROUP):
			faces.append(sprite)
	var label := "%s %s frontage" % ["civic" if civic else "ordinary","open" if direction == Vector2i.DOWN else "closed"]
	if not civic:
		await _test_composed_rectangular(fixture,direction,label)
		return
	_check(faces.size() == 3 if direction == Vector2i.DOWN else not faces.is_empty(),label + " exposes its actual painted source slices as registered sprites")
	if not faces.is_empty():
		var face := faces[0]
		var descriptor := FOREGROUND.describe(face)
		_check(not descriptor.is_empty() and is_equal_approx(float(descriptor.get("front_y",0)),576.0),label + " retains footprint front depth")
		_check(face.get_parent() is CanvasItem and (face.get_parent() as CanvasItem).show_behind_parent,label + " keeps parent-drawn service props above the original facade")
		var point := _opaque_point(face)
		_cover.call("refresh",self,true)
		_check(float(_cover.call("strength_at",point,575.0)) > 0.9,label + " covers an entity at an opaque original source pixel")
		_check(is_zero_approx(float(_cover.call("strength_at",point,577.0))),label + " leaves an entity in front normal")
		if direction == Vector2i.DOWN:
			var door_x := float(kit.get("_door_x"))
			var front_y := float(kit.get("_front"))
			_check(is_zero_approx(float(_cover.call("strength_at",kit.to_global(Vector2(door_x,front_y-28)),575.0))),label + " retains the original transparent door opening")
		(fixture.roof as RoofOverlay)._set_alpha(0)
		_cover.call("refresh",self,true)
		_check(is_zero_approx(float(_cover.call("strength_at",point,575.0))),label + " fades coverage with the actual roof cutaway")
	(fixture.parent as Node).queue_free()
	await get_tree().process_frame


func _test_composed_rectangular(fixture: Dictionary, direction: Vector2i, label: String) -> void:
	# Ordinary buildings use the composed frontage: solid wall fields at the
	# real footprint depth, a doorway module only where a south door exists.
	var kit := fixture.kit as Node2D
	var fields: Array[Polygon2D] = []
	for node: Node in kit.find_children("*","Polygon2D",true,false):
		if node.has_meta(&"facade_wall_field") and node.is_in_group(SOLID_GROUP): fields.append(node)
	_check(not fields.is_empty(),label + " exposes its actual painted source slices as registered sprites")
	var frames := kit.find_children("FacadeDoorFrame*","Polygon2D",true,false)
	_check((frames.size() >= 3) if direction == Vector2i.DOWN else frames.is_empty(),label + " paints a doorway only where the real south door is")
	if fields.is_empty():
		(fixture.parent as Node).queue_free()
		await get_tree().process_frame
		return
	var field := fields[0]
	var ground: Vector2 = field.get_meta(GROUND_META)
	_check(is_equal_approx(ground.y,576.0),label + " retains footprint front depth")
	_check(field.get_parent() is CanvasItem and (field.get_parent() as CanvasItem).show_behind_parent,label + " keeps parent-drawn service props above the original facade")
	var center := Vector2.ZERO
	for p: Vector2 in field.polygon: center += p
	var point := field.to_global(center/field.polygon.size())
	_cover.call("refresh",self,true)
	_check(float(_cover.call("strength_at",point,575.0)) > 0.9,label + " covers an entity at an opaque original source pixel")
	_check(is_zero_approx(float(_cover.call("strength_at",point,577.0))),label + " leaves an entity in front normal")
	if direction == Vector2i.DOWN:
		var door_x := float(kit.get("_door_x"))
		var front_y := float(kit.get("_front"))
		_check(is_zero_approx(float(_cover.call("strength_at",kit.to_global(Vector2(door_x,front_y-28)),575.0))),label + " retains the original transparent door opening")
	(fixture.roof as RoofOverlay)._set_alpha(0)
	_cover.call("refresh",self,true)
	_check(is_zero_approx(float(_cover.call("strength_at",point,575.0))),label + " fades coverage with the actual roof cutaway")
	(fixture.parent as Node).queue_free()
	await get_tree().process_frame


func _opaque_point(sprite: Sprite2D) -> Vector2:
	# Test-only sampling selects an actually opaque lower wall pixel in the
	# original supplied bitmap, independently of the coverage descriptor.
	var image := sprite.texture.get_image()
	if image.is_compressed():
		image.decompress()
	var region := sprite.region_rect
	for y: float in [0.7,0.8,0.6]:
		for x: float in [0.5,0.3,0.7]:
			var source := region.position + region.size * Vector2(x,y)
			if image.get_pixelv(Vector2i(source)).a > 0.95:
				var point := sprite.to_global(source-region.position)
				var displayed := sprite.get_parent() as Node2D
				var target := Rect2(sprite.position,region.size*sprite.scale)
				_check(target.has_point(displayed.to_local(point)),"opaque source sample lies within its actual scaled wall rectangle")
				return point
	_check(false,"actual facade fixture needs an opaque lower wall sample")
	return sprite.global_position
