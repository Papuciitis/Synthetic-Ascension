extends RefCounted
## Small compound roof compositions, owned by the existing fading RoofPoly.
## They change projected building forms, never parcel/door/collision data.

const FOOTPRINT_GEOMETRY := preload("res://scenes/world/buildings/CityFootprintGeometry.gd")

## Fitted S2 L/recessed roofs: independent gable planes and a shallow rim,
## with exactly the original visible union and one inherited fade per pixel.
static func compose_irregular(host: Polygon2D, civic: bool) -> bool:
	if host.polygon.size() < 4 or not host.material is ShaderMaterial: return false
	for index in host.polygon.size():
		var a := host.polygon[index]
		var b := host.polygon[(index+1)%host.polygon.size()]
		if not is_equal_approx(a.x,b.x) and not is_equal_approx(a.y,b.y): return false
	var horizontal := FOOTPRINT_GEOMETRY.convex_parts(host.polygon)
	var swapped := PackedVector2Array()
	for point: Vector2 in host.polygon: swapped.append(Vector2(point.y,point.x))
	var vertical: Array[PackedVector2Array] = []
	for part: PackedVector2Array in FOOTPRINT_GEOMETRY.convex_parts(swapped):
		var restored := PackedVector2Array()
		for point: Vector2 in part: restored.append(Vector2(point.y,point.x))
		vertical.append(restored)
	var along_x := _largest_area(horizontal) >= _largest_area(vertical)
	var parts: Array[PackedVector2Array] = []
	if along_x: parts.assign(horizontal)
	else: parts.assign(vertical)
	if parts.size() < 2: return false
	var primary := 0
	for index in range(1,parts.size()):
		if FOOTPRINT_GEOMETRY.bounds_of(parts[index]).get_area() > FOOTPRINT_GEOMETRY.bounds_of(parts[primary]).get_area(): primary = index
	var group := Node2D.new()
	group.name = "CityIrregularRoofComposition"
	host.add_child(group)
	var rim := _irregular_rim(host.polygon)
	var rim_cuts: Array[PackedVector2Array] = []
	for entry: Dictionary in rim: rim_cuts.append(entry.points)
	for index in parts.size():
		var part := parts[index]
		var bounds := FOOTPRINT_GEOMETRY.bounds_of(part)
		var material := (host.material as ShaderMaterial).duplicate() as ShaderMaterial
		material.set_shader_parameter("bounds",Vector4(bounds.position.x,bounds.position.y,bounds.end.x,bounds.end.y))
		# The primary spine follows the decomposition's long direction. A
		# meaningful attached arm turns its ridge; tiny residual strips retain
		# the spine's axis instead of growing an extra ornamental gable.
		var arm := index != primary and minf(bounds.size.x,bounds.size.y) >= 48.0
		var plane_along_x := not along_x if arm else along_x
		material.set_shader_parameter("ridge_along_x",1.0 if plane_along_x else 0.0)
		material.set_shader_parameter("gable",1.0)
		material.set_shader_parameter("ridge_light",0.19)
		var candidates: Array[PackedVector2Array] = [part]
		for piece: PackedVector2Array in FOOTPRINT_GEOMETRY.difference(candidates,rim_cuts):
			_partition_plane(group,host,piece,material,host.color,&"main" if index == primary else &"attached",not plane_along_x)
	var rim_materials: Dictionary = {}
	for entry: Dictionary in rim:
		var normal: Vector2 = entry.normal
		if not rim_materials.has(normal):
			var material := (host.material as ShaderMaterial).duplicate() as ShaderMaterial
			var tone := Color("777e79") if civic else Color("62685f")
			if normal.x > 0.5: tone = Color("9aa69b") if civic else Color("929a87")
			elif normal.x < -0.5: tone = Color("505d5e") if civic else Color("48554c")
			material.set_shader_parameter("gable",0.0)
			material.set_shader_parameter("material_contrast",0.0)
			material.set_shader_parameter("material_mid",Vector3(tone.r,tone.g,tone.b))
			material.set_shader_parameter("eave_px",0.01)
			rim_materials[normal] = material
		_partition_plane(group,host,entry.points,rim_materials[normal],Color.WHITE,&"fascia")
	# Polygon2D.color is vertex tint for this mesh, not inherited modulation.
	# The unchanged host polygon/modulate remains the authoritative cover union;
	# children alone render it, avoiding .75 opacity during a .5 roof cutaway.
	var transparent_base := host.color
	transparent_base.a = 0.0
	host.color = transparent_base
	return true

static func _largest_area(parts: Array[PackedVector2Array]) -> float:
	var result := 0.0
	for part: PackedVector2Array in parts: result = maxf(result,FOOTPRINT_GEOMETRY.bounds_of(part).get_area())
	return result

static func _irregular_rim(outline: PackedVector2Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var occupied: Array[PackedVector2Array] = []
	var source := FOOTPRINT_GEOMETRY.convex_parts(outline)
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index+1)%outline.size()]
		var normal := Vector2((b-a).y,-(b-a).x).normalized()
		if Geometry2D.is_point_in_polygon((a+b)*0.5+normal,outline): normal = -normal
		if normal.y < -0.5: continue
		var depth := 8.0 if normal.y > 0.5 else 6.0
		var band := PackedVector2Array([a,b,b-normal*depth,a-normal*depth])
		for part: PackedVector2Array in source:
			var intersections: Array[PackedVector2Array] = Geometry2D.intersect_polygons(band,part)
			for piece: PackedVector2Array in FOOTPRINT_GEOMETRY.difference(intersections,occupied):
				result.append({"points":piece,"normal":normal})
				occupied.append(piece)
	return result

static func _partition_plane(group: Node2D, source: Polygon2D, points: PackedVector2Array, material: ShaderMaterial, tint: Color, role: StringName, turn_texture: bool = false) -> void:
	var plane := Polygon2D.new()
	plane.name = "RoofPartition_"+String(role)
	# These partition the unchanged host, rather than adding raised coverage.
	# Keep them separate from city_roof_form's additive visibility contract.
	plane.set_meta(&"city_roof_partition",role)
	plane.polygon = points
	# Clay barrels/slate courses retain their source density and turn with a
	# north-south ridge. The east-west arm keeps the original local mapping.
	if turn_texture:
		var uv := PackedVector2Array()
		for point: Vector2 in points: uv.append(Vector2(-point.y,point.x))
		plane.uv = uv
	plane.texture = source.texture
	plane.texture_repeat = source.texture_repeat
	plane.texture_scale = source.texture_scale
	plane.texture_offset = source.texture_offset
	plane.color = tint
	plane.material = material
	group.add_child(plane)

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
