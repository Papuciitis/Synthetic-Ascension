extends RefCounted
## Recorded real S2 bed house944996572, seed16102026, chunk(0,3).
## Exercises the production kit/composer; owns no fake geometry implementation.

const KIT := preload("res://scenes/world/buildings/CityBlockKit.gd")
const GEOMETRY := preload("res://scenes/world/buildings/CityFootprintGeometry.gd")
const ROOF := preload("res://scenes/world/buildings/RoofOverlay.tscn")
const BED_RECT := Rect2i(3,9,11,8)
const BED_OUTLINE := [Vector2(192,768),Vector2(384,768),Vector2(384,576),Vector2(896,576),Vector2(896,1088),Vector2(192,1088)]


static func create(parent: Node2D, direction: Vector2i = Vector2i.DOWN, supplied_outline: PackedVector2Array = PackedVector2Array(), rect: Rect2i = BED_RECT) -> Dictionary:
	var outline := PackedVector2Array(BED_OUTLINE) if supplied_outline.is_empty() else supplied_outline.duplicate()
	var door := {"pos":Vector2i(8,16) if direction == Vector2i.DOWN else Vector2i(4,12),"dir":direction,"width":2}
	var doors: Array = [door]
	var roof := ROOF.instantiate() as RoofOverlay
	parent.add_child(roof)
	roof.configure_polygon(outline,Vector2(192,1088),Vector2(896,1088),[],&"row_house",944996572,doors,64)
	var kit := KIT.new()
	parent.add_child(kit)
	kit.configure(rect,64,doors,roof,false,outline,true,{"building_usage":&"row_house","visual_seed":944996572})
	return {"kit":kit,"roof":roof,"outline":outline,"rect":rect,"doors":doors}


static func untextured_shadows(kit: Node) -> Array[Polygon2D]:
	var result: Array[Polygon2D] = []
	for child: Node in kit.get_children():
		if child is Polygon2D and child.has_meta(&"city_sun_shadow") and child.texture == null:
			result.append(child as Polygon2D)
	return result


## Drawn shadow faces covering a ground point. A soft cast is one Polygon2D of
## disjoint faces (full-shade core plus feathered band), so faces are counted.
static func covering_pieces(kit: Node, point: Vector2) -> int:
	var count := 0
	for shade: Polygon2D in untextured_shadows(kit):
		for face: PackedVector2Array in GEOMETRY.faces_of(shade):
			if Geometry2D.is_point_in_polygon(point,face): count += 1
	return count


static func footway_covers(group: Node, point: Vector2) -> bool:
	for child: Node in group.get_children():
		if child is Polygon2D and Geometry2D.is_point_in_polygon(point,child.polygon): return true
	return false
