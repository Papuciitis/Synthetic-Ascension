extends RefCounted
## Small compound roof compositions, owned by the existing fading RoofPoly.
## They change projected building forms, never parcel/door/collision data.

static func compose(host: Polygon2D, civic: bool, box: Rect2) -> void:
	var group := Node2D.new()
	group.name = "CityRoofComposition"
	host.add_child(group)
	var x := box.position.x
	var y := box.position.y
	var w := box.size.x
	var h := box.size.y
	if civic:
		# Long public hall, a perpendicular stair/service wing and a lower
		# portico cap. The hierarchy reads before individual slate courses.
		var hall := _cap(group, host, Rect2(x + w*0.23, y + h*0.15, w*0.77, h*0.72), true, 16, "hall", true)
		_cap(group, host, Rect2(x, y, w*0.29, h*0.86), false, 38, "stair_wing", true)
		_cap(group, host, Rect2(x, y + h*0.79, w, h*0.21), true, 0, "portico", true)
		_chimney(group, hall, true)
	else:
		# An inhabited narrow gable beside a lower attached service room;
		# deliberately unlike the civic hall's broad horizontal composition.
		var dwelling := _cap(group, host, Rect2(x, y, w*0.64, h), false, 23, "dwelling", false)
		_cap(group, host, Rect2(x + w*0.61, y + h*0.29, w*0.39, h*0.71), true, 0, "service_room", false)
		_chimney(group, dwelling, false)

static func _cap(group: Node2D, source: Polygon2D, area: Rect2, along_x: bool, lift: float, kind: String, civic: bool) -> Polygon2D:
	var top := area.position + Vector2(0, -lift)
	var end := area.end + Vector2(0, -lift)
	var depth := 12.0 + lift
	if kind == "dwelling":
		# The main domestic roof meets the same front eave as its service
		# wing. Keep the raised rear silhouette without a tall blank fascia.
		end.y += lift
		depth = 12.0
	var cross_wing := kind == "stair_wing"
	var ridge_end := Vector2((top.x + end.x) * 0.5, end.y - 54)
	if cross_wing:
		# The gable terminates on the hall: two diagonal roof edges meet at
		# its ridge, with a masonry end and one contact shadow below it.
		_face(group, PackedVector2Array([Vector2(top.x-6, end.y+5), ridge_end + Vector2(0, 14), end + Vector2(7, 5), end + Vector2(7, 20), Vector2(top.x-6, end.y+20)]), Color("293b3d"))
		_face(group, PackedVector2Array([Vector2(top.x, end.y), ridge_end, end]), Color("89958b"))
	# A lit eave cap, a shaded south fascia and the short side return make
	# each height change physical; no second outline around every roof tile.
	if not cross_wing:
		_face(group, PackedVector2Array([Vector2(top.x, end.y), end, end + Vector2(0, depth), Vector2(top.x, end.y + depth)]), Color("777e79") if civic else Color("62685f"))
	_face(group, PackedVector2Array([Vector2(end.x, top.y), end, end + Vector2(0, depth), Vector2(end.x + 7, top.y + depth)]), Color("505d5e"))
	var roof := Polygon2D.new()
	roof.name = "Roof_" + kind
	roof.set_meta(&"city_roof_form", kind)
	roof.set_meta(&"city_roof_lift", lift)
	roof.polygon = PackedVector2Array([top, Vector2(end.x, top.y), end, Vector2(top.x, end.y)])
	if cross_wing:
		roof.polygon = PackedVector2Array([top, Vector2(end.x, top.y), end, ridge_end, Vector2(top.x, end.y)])
	roof.texture = source.texture
	roof.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	roof.texture_scale = source.texture_scale
	roof.color = source.color
	var material := (source.material as ShaderMaterial).duplicate() as ShaderMaterial
	material.set_shader_parameter("bounds", Vector4(top.x, top.y, end.x, end.y))
	material.set_shader_parameter("ridge_along_x", 1.0 if along_x else 0.0)
	material.set_shader_parameter("gable", 1.0)
	material.set_shader_parameter("material_contrast", 0.42 if civic else 0.28)
	material.set_shader_parameter("material_mid", Vector3(0.29, 0.35, 0.40) if civic else Vector3(0.52, 0.29, 0.20))
	material.set_shader_parameter("ridge_light", 0.19)
	roof.material = material
	group.add_child(roof)
	var eave := Line2D.new()
	eave.points = PackedVector2Array([Vector2(top.x, end.y), ridge_end, end]) if cross_wing else PackedVector2Array([Vector2(top.x, end.y), end])
	eave.width = (3 if cross_wing else 4) if civic else 2
	eave.default_color = Color("99a69c") if civic else Color("8c7962")
	group.add_child(eave)
	if not civic:
		var underside := Line2D.new()
		underside.points = PackedVector2Array([Vector2(top.x,end.y+depth),end+Vector2(0,depth)])
		underside.width = 3
		underside.default_color = Color("35413d")
		group.add_child(underside)
	if cross_wing:
		var ridge := Line2D.new()
		ridge.points = PackedVector2Array([Vector2(ridge_end.x, top.y), ridge_end])
		ridge.width = 4
		ridge.default_color = Color("91a29a")
		group.add_child(ridge)
	return roof

static func _face(parent: Node2D, points: PackedVector2Array, color: Color) -> Polygon2D:
	var face := Polygon2D.new()
	face.polygon = points
	face.color = color
	parent.add_child(face)
	return face

static func _chimney(parent: Node2D, plane: Polygon2D, civic: bool) -> bool:
	var box := Rect2(plane.polygon[0],Vector2.ZERO)
	for point: Vector2 in plane.polygon: box = box.expand(point)
	var span_variant := absi(int(box.position.x/64)+int(box.position.y/64)*3+int(box.size.x/64)) % 3
	var flashing_points := PackedVector2Array([Vector2(-25,5),Vector2(-12,-13),Vector2(30,-9),Vector2(17,11)])
	var base := Vector2.ZERO
	var found := false
	for fraction_y: float in ([0.24,0.28,0.32] if civic else [0.28,0.36,0.44]):
		var fraction_x: float = [0.64,0.72,0.80][span_variant] if civic else [0.72,0.76,0.70][span_variant]
		var candidate := box.position+box.size*Vector2(fraction_x,fraction_y)
		# Keep the complete assembly clear of the rear eave and the ridge.
		if candidate.y-box.position.y < 64: continue
		var ridge_distance := absf(candidate.y-(box.position.y+box.size.y*0.42)) if civic else absf(candidate.x-box.get_center().x)
		if ridge_distance < 27: continue
		var fits := true
		for corner: Vector2 in flashing_points:
			if not Geometry2D.is_point_in_polygon(candidate+corner,plane.polygon): fits = false
		if not fits: continue
		base = candidate
		found = true
		break
	if not found: return false
	var stack := Node2D.new()
	stack.name = "CivicFlue" if civic else "DomesticFlue"
	stack.position = base
	stack.set_meta(&"city_chimney",&"civic" if civic else &"domestic")
	stack.set_meta(&"support_polygon",plane.polygon)
	stack.set_meta(&"supporting_roof_form",plane.get_meta(&"city_roof_form"))
	parent.add_child(stack)
	var w := 32.0 if civic else 26.0
	var height := 43.0 if civic else 25.0
	var side := Vector2(9,-7)
	var left := -w*0.5
	var right := w*0.5
	var footprint := PackedVector2Array([Vector2(left,0),Vector2(right,0),Vector2(right,0)+side,Vector2(left,0)+side])
	var shadow_points := footprint.duplicate()
	var shift := preload("res://core/systems/world/WorldDepthStyle.gd").offset_for_height(38)
	for point: Vector2 in footprint: shadow_points.append(point+shift)
	_face(stack,Geometry2D.convex_hull(shadow_points),Color(0.02,0.04,0.04,0.20))
	var flashing := _face(stack,flashing_points,Color("414d49"))
	flashing.name = "RoofFlashing"
	_face(stack,PackedVector2Array([Vector2(-23,3),Vector2(-12,-10),Vector2(27,-7),Vector2(16,7)]),Color("68756b"))
	_face(stack,PackedVector2Array([Vector2(left,0),Vector2(left,-height),Vector2(right,-height),Vector2(right,0)]),Color("7e8575") if civic else Color("8a7f6c"))
	_face(stack,PackedVector2Array([Vector2(right,0),Vector2(right,-height),Vector2(right,-height)+side,Vector2(right,0)+side]),Color("515f54") if civic else Color("5f6557"))
	# Broad weathering and two selected masonry courses, not brick outlines.
	_face(stack,PackedVector2Array([Vector2(left+3,-height+10),Vector2(2,-height+12),Vector2(5,-12),Vector2(left+4,-8)]),Color(0.53,0.57,0.47,0.45))
	for row in range(2):
		var yy := -9.0-row*13.0
		_face(stack,PackedVector2Array([Vector2(left+3,yy),Vector2(right-6,yy),Vector2(right-6,yy+1.5),Vector2(left+3,yy+1.5)]),Color(0.27,0.34,0.28,0.35))
	if civic:
		# Projecting coping, substantial dark opening and a grouped soot patch.
		_face(stack,PackedVector2Array([Vector2(left-5,-height-3),Vector2(right+5,-height-3),Vector2(right+5,-height+4),Vector2(left-5,-height+4)]),Color("697562"))
		_face(stack,PackedVector2Array([Vector2(left-5,-height-3),Vector2(right+5,-height-3),Vector2(right+5,-height-3)+side,Vector2(left-5,-height-3)+side]),Color("a0a78e"))
		var mouth := _face(stack,PackedVector2Array([Vector2(left+4,-height-4),Vector2(right-2,-height-4),Vector2(right+4,-height-9),Vector2(left+10,-height-9)]),Color("25332e"))
		mouth.name = "FlueMouth"
		_face(stack,PackedVector2Array([Vector2(-8,-height+4),Vector2(9,-height+4),Vector2(6,-height+15),Vector2(-5,-height+12)]),Color(0.13,0.19,0.16,0.27))
	else:
		_face(stack,PackedVector2Array([Vector2(left,-height),Vector2(right,-height),Vector2(right,-height)+side,Vector2(left,-height)+side]),Color("9a9a80"))
		var pot := Vector2(4,-height-3)
		_face(stack,PackedVector2Array([pot+Vector2(-7,0),pot+Vector2(-10,-17),pot+Vector2(9,-17),pot+Vector2(7,0)]),Color("a0714d"))
		_face(stack,PackedVector2Array([pot+Vector2(2,0),pot+Vector2(2,-17),pot+Vector2(9,-17),pot+Vector2(7,0)]),Color("795640"))
		_oval(stack,pot+Vector2(0,-17),Vector2(12,5),Color("ac805b"))
		var mouth := _oval(stack,pot+Vector2(0,-18),Vector2(7,2.8),Color("29372f"))
		mouth.name = "FlueMouth"
	return true

static func _oval(parent: Node2D, center: Vector2, radius: Vector2, color: Color) -> Polygon2D:
	var points := PackedVector2Array()
	for step in range(12):
		var angle := TAU*float(step)/12.0
		points.append(center+Vector2(cos(angle),sin(angle))*radius)
	return _face(parent,points,color)
