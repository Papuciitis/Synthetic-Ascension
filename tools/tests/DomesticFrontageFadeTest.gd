extends "res://tools/tests/DomesticFrontageFinishTest.gd"
## An opaque domestic face must fade once at every occupied image point.


func _run() -> void:
	var previous_segment: int = Global.attempt_segment
	var dummy := Node2D.new()
	dummy.add_to_group(&"player")
	add_child(dummy)
	var fixture: Dictionary = _fixture(2,&"row_house")
	var kit: Node2D = fixture.kit
	var roof: RoofOverlay = fixture.roof
	var points: Array[Vector2] = []
	for node: Node in kit.find_children("*","Polygon2D",true,false):
		var pier := node as Polygon2D
		var bounds: Rect2 = _bounds(pier.polygon)
		if pier.texture != null and is_equal_approx(bounds.size.x,12.0) and is_equal_approx(bounds.size.y,64.0):
			points.append(pier.to_global(bounds.get_center()))
	var header := kit.find_child("DomesticDoorHeader",true,false) as Polygon2D
	var lintel := kit.find_child("Lintel",true,false) as Polygon2D
	_check(header != null and lintel != null,"Actual domestic portal supplies its supported header and lintel")
	if header != null and lintel != null:
		points.append(lintel.to_global(_bounds(lintel.polygon).get_center()))
	_check(points.size() == 3,"Retained bed home probes both upper piers and the supported entry junction")
	# These inherited jamb/field junctions are separate from the three new
	# detail points above. Actual bed-kit coordinates come from its real door.
	for local_point: Vector2 in [Vector2(504,930),Vector2(647,930),Vector2(504,900),Vector2(647,900)]:
		points.append(kit.to_global(local_point))
	roof._set_alpha(0.5)
	for point: Vector2 in points:
		var count := 0
		var transmittance := 1.0
		var strongest := 0.0
		for node: Node in kit.find_children("*","Polygon2D",true,false):
			var face := node as Polygon2D
			if not face.is_in_group(&"foreground_solid_occluders") or not Geometry2D.is_point_in_polygon(face.to_local(point),face.polygon):
				continue
			count += 1
			var alpha: float = _live_alpha(face)
			transmittance *= 1.0-alpha
			strongest = maxf(strongest,alpha)
		_check(count == 1,"Domestic solid details replace their background field at "+str(point))
		_check(is_equal_approx(1.0-transmittance,strongest),"Fractional opaque render coverage matches the shared maximum-strength query at "+str(point))
	(fixture.host as Node).free()
	dummy.free()
	Global.attempt_segment = previous_segment
	print("DomesticFrontageFadeTest: %d passed, %d failed" % [_passed,_failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _live_alpha(face: Polygon2D) -> float:
	var alpha: float = face.color.a*face.self_modulate.a
	var cursor: CanvasItem = face
	while cursor != null:
		alpha *= cursor.modulate.a
		if cursor.is_set_as_top_level():
			break
		cursor = cursor.get_parent() as CanvasItem
	return alpha
