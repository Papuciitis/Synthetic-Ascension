extends RefCounted
## Small compound roof compositions, owned by the existing fading RoofPoly.
## They change projected building forms, never parcel/door/collision data.

const FOOTPRINT_GEOMETRY := preload("res://scenes/world/buildings/CityFootprintGeometry.gd")
const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")
## Raised caps' east returns face the top-right sun. They take the tone of
## the cap's own sunlit slope (family mid x tint x lit slope), at most a
## step brighter, so a seven-pixel return reads as the roof plane turning a
## corner, never as a pale drawn stroke (simplified, not over-lined).
const RETURN_LIFT := 1.04
## roof.gdshader's lit_slope default, for materials that leave it unset.
const ROOF_LIT_SLOPE := 1.12
## The main domestic eave: a dark iron gutter with a lit lip, then the eave's
## soft shade on the wall below. A raised step's face takes the roof
## family's mid in shade.
const GUTTER_PX := 3.0
const GUTTER_IRON := Color(0.17, 0.19, 0.20)
const GUTTER_LIP := Color(0.55, 0.60, 0.58)
const EAVE_SHADE := Color(0.10, 0.09, 0.10, 0.35)
const STEP_FACE := 0.55

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
			var slate := civic or bool(host.get_meta(&"city_roof_slate", false))
			var tone := Color("777e79") if slate else Color("62685f")
			if normal.x > 0.5: tone = Color("9aa69b") if slate else Color("929a87")
			elif normal.x < -0.5: tone = Color("505d5e") if slate else Color("48554c")
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

static func compose(host: Polygon2D, civic: bool, box: Rect2, profile: Dictionary = {}) -> void:
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
		return
	# Ordinary roofs vary per building (stable visual seed, never generator
	# RNG): a dwelling gable beside its service room on either side, two
	# attached house gables, or one long street gable with a rear wing.
	var usage := StringName(profile.get("building_usage", &"row_house"))
	var seed_value := int(profile.get("visual_seed", int(x) * 31 + int(y)))
	var variant := posmod(hash(seed_value * 7919 + 4243), 100)
	var main: Polygon2D
	var ridged: Array[Polygon2D] = []
	if usage == &"workshop":
		# A working hall: one broad gable along the street with a glazed lantern.
		main = _cap(group, host, Rect2(x, y + h*0.22, w, h*0.78), true, 14, "hall_roof", false)
		_cap(group, host, Rect2(x + w*(0.64 if variant % 2 == 0 else 0.0), y, w*0.36, h*0.40), false, 22, "rear_wing", false)
		ridged.append(main)
	elif variant < 30:
		main = _cap(group, host, Rect2(x, y, w*0.64, h), false, 23, "dwelling", false)
		ridged.append(_cap(group, host, Rect2(x + w*0.61, y + h*0.29, w*0.39, h*0.71), true, 0, "service_room", false))
	elif variant < 52:
		main = _cap(group, host, Rect2(x + w*0.36, y, w*0.64, h), false, 23, "dwelling", false)
		ridged.append(_cap(group, host, Rect2(x, y + h*0.29, w*0.39, h*0.71), true, 0, "service_room", false))
	elif variant < 76 and w >= 448.0:
		# Two attached houses under their own gables, one slightly taller.
		var split := 0.5 + float(posmod(seed_value, 7) - 3) * 0.02
		main = _cap(group, host, Rect2(x, y, w*split, h), false, 23, "dwelling", false)
		_cap(group, host, Rect2(x + w*split, y + h*0.06, w*(1.0 - split), h*0.94), false, 11, "attached_house", false)
		ridged.append(_cap(group, host, Rect2(x + w*0.18, y + h*0.62, w*0.64, h*0.38), true, 0, "street_range", false))
	else:
		main = _cap(group, host, Rect2(x, y + h*0.30, w, h*0.70), true, 16, "street_gable", false)
		_cap(group, host, Rect2(x + w*(0.62 if variant % 2 == 0 else 0.0), y, w*0.38, h*0.46), false, 24, "rear_wing", false)
		ridged.append(main)
	if usage == &"workshop":
		_chimney(group, main, false, true)
		_rooftop(group, main, "roof_lantern.png", Vector2(0.50, 0.34), maxf(96.0, w*0.42), &"lantern")
		_rooftop(group, main, "roof_vents.png", Vector2(0.24 if variant % 2 == 0 else 0.76, 0.46), 46.0, &"vents")
	else:
		_chimney(group, main, false)
		# Dormers face the street on east-west gables (south slope). Native
		# review (2026-10-21, lead: attachment and scale need judgment before
		# repetition): at 44 px a dormer reads as a small pale box seated
		# mid-slope, and one or two on every house stamped the same mark down
		# whole streets. One at most per building, on its first street-facing
		# plane, on about half the houses (stable visual seed, not RNG).
		var dormer := "dormer_slate.png" if bool(host.get_meta(&"city_roof_slate", false)) else "dormer_clay.png"
		if not ridged.is_empty() and posmod(hash(seed_value * 7919 + 6151), 2) == 0:
			var fx := 0.5 + (float(posmod(seed_value >> 3, 5)) - 2.0) * 0.05
			_rooftop(group, ridged[0], dormer, Vector2(fx, 0.70), 44.0, &"dormer")

## A painted rooftop element seated on a roof plane (fraction of its bounds),
## with a short projected contact shadow. It belongs to the fading roof.
static func _rooftop(group: Node2D, plane: Polygon2D, file: String, at: Vector2, width: float, kind: StringName) -> Sprite2D:
	var path := "res://assets/world/rooftops_v1/" + file
	if not ResourceLoader.exists(path, "Texture2D"): return null
	var texture := load(path) as Texture2D
	if texture == null: return null
	var box := Rect2(plane.polygon[0], Vector2.ZERO)
	for point: Vector2 in plane.polygon: box = box.expand(point)
	var size := texture.get_size() * (width / texture.get_width())
	var base := box.position + box.size * at
	var rect := Rect2(base - Vector2(size.x * 0.5, size.y), size)
	for corner: Vector2 in [rect.position + Vector2(4, size.y * 0.55), Vector2(rect.end.x - 4, rect.position.y + size.y * 0.55), rect.end - Vector2(4, 2), Vector2(rect.position.x + 4, rect.end.y - 2)]:
		if not Geometry2D.is_point_in_polygon(corner, plane.polygon): return null
	# The roof is notched over every doorway after composition: keep clear.
	for notch: Rect2 in door_notches(plane):
		if notch.grow(6.0).intersects(rect): return null
	var shade := Polygon2D.new()
	shade.name = "RooftopShadow"
	var shift := DEPTH.offset_for_height(size.y * 0.55)
	var foot := PackedVector2Array([Vector2(rect.position.x + 3, rect.end.y - 6), Vector2(rect.end.x - 3, rect.end.y - 6), Vector2(rect.end.x - 3, rect.end.y), Vector2(rect.position.x + 3, rect.end.y)])
	var cast := foot.duplicate()
	for point: Vector2 in foot: cast.append(point + shift)
	shade.polygon = Geometry2D.convex_hull(cast)
	shade.color = Color(1, 1, 1, 0.9)
	shade.material = DEPTH.SUN_SHADOW_MATERIAL
	group.add_child(shade)
	var sprite := Sprite2D.new()
	sprite.name = "Rooftop" + String(kind).capitalize()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = rect.position
	sprite.scale = Vector2.ONE * (width / texture.get_width())
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.set_meta(&"city_rooftop", kind)
	group.add_child(sprite)
	return sprite

static func _cap(group: Node2D, source: Polygon2D, area: Rect2, along_x: bool, lift: float, kind: String, civic: bool) -> Polygon2D:
	# Massing follows the building's role; tones follow its actual roof stone.
	var slate := civic or bool(source.get_meta(&"city_roof_slate", false))
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
	# The main domestic eave meets the wall itself: an iron gutter, then the
	# eave's soft shade on the real facade below (plate 08), never a flat band.
	var dwelling_eave := kind == "dwelling" and not cross_wing
	if dwelling_eave:
		_face(group, PackedVector2Array([Vector2(top.x, end.y), end, end + Vector2(0, GUTTER_PX), Vector2(top.x, end.y + GUTTER_PX)]), GUTTER_IRON)
		_face(group, PackedVector2Array([Vector2(top.x, end.y), end, end + Vector2(0, 1), Vector2(top.x, end.y + 1)]), GUTTER_LIP)
		var shade := _face(group, PackedVector2Array([Vector2(top.x, end.y + GUTTER_PX), end + Vector2(0, GUTTER_PX), end + Vector2(0, depth + 6.0), Vector2(top.x, end.y + depth + 6.0)]), Color.WHITE)
		shade.vertex_colors = PackedColorArray([EAVE_SHADE, EAVE_SHADE, Color(EAVE_SHADE, 0.0), Color(EAVE_SHADE, 0.0)])
	elif not cross_wing:
		# A raised step over a lower roof: its face in the roof's own shaded tone.
		var mid: Vector3 = RoofOverlay.SLATE_MID if slate else RoofOverlay.CLAY_MID
		_face(group, PackedVector2Array([Vector2(top.x, end.y), end, end + Vector2(0, depth), Vector2(top.x, end.y + depth)]), Color(mid.x * STEP_FACE, mid.y * STEP_FACE, mid.z * STEP_FACE))
	# The short side return faces east, toward the sun: the lit roof's tone.
	_face(group, PackedVector2Array([Vector2(end.x, top.y), end, end + Vector2(0, depth), Vector2(end.x + 7, top.y + depth)]), return_tone(source, slate))
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
	material.set_shader_parameter("material_contrast", RoofOverlay.CITY_MATERIAL_CONTRAST)
	material.set_shader_parameter("material_mid", RoofOverlay.SLATE_MID if slate else RoofOverlay.CLAY_MID)
	material.set_shader_parameter("ridge_light", 0.19)
	roof.material = material
	group.add_child(roof)
	var eave := Line2D.new()
	eave.points = PackedVector2Array([Vector2(top.x, end.y), ridge_end, end]) if cross_wing else PackedVector2Array([Vector2(top.x, end.y), end])
	eave.width = (3 if cross_wing else 4) if civic else 2
	eave.default_color = Color("99a69c") if slate else Color("8c7962")
	group.add_child(eave)
	if not civic and not dwelling_eave:
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

## The east return's flat tone: the cap's family mid under the host tint,
## lit like the gable's sunlit slope and lifted a step.
static func return_tone(source: Polygon2D, slate: bool) -> Color:
	var mid: Vector3 = RoofOverlay.SLATE_MID if slate else RoofOverlay.CLAY_MID
	var lit: Variant = (source.material as ShaderMaterial).get_shader_parameter("lit_slope") if source.material is ShaderMaterial else null
	var gain := (float(lit) if lit != null else ROOF_LIT_SLOPE)*RETURN_LIFT
	var tint := source.color
	return Color(mid.x*tint.r*gain, mid.y*tint.g*gain, mid.z*tint.b*gain)

static func _face(parent: Node2D, points: PackedVector2Array, color: Color) -> Polygon2D:
	var face := Polygon2D.new()
	face.polygon = points
	face.color = color
	parent.add_child(face)
	return face

static func _chimney(parent: Node2D, plane: Polygon2D, civic: bool, brick: bool = false) -> bool:
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
		for notch: Rect2 in door_notches(plane):
			if notch.grow(8.0).intersects(Rect2(candidate+Vector2(-30,-60),Vector2(64,74))): fits = false
		if not fits: continue
		base = candidate
		found = true
		break
	if not found: return false
	var stack := Node2D.new()
	stack.name = "CivicFlue" if civic else ("WorkshopStack" if brick else "DomesticFlue")
	stack.position = base
	stack.set_meta(&"city_chimney",&"civic" if civic else (&"workshop" if brick else &"domestic"))
	stack.set_meta(&"support_polygon",plane.polygon)
	stack.set_meta(&"supporting_roof_form",plane.get_meta(&"city_roof_form"))
	parent.add_child(stack)
	# Painted stone stack with clay pots (homes, civic) or a tall sooted brick
	# workshop stack, seated in the same flashing skirt and casting the same sun.
	var path := "res://assets/world/rooftops_v1/" + ("chimney_brick.png" if brick else "chimney_stone.png")
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path,"Texture2D") else null
	var w := (24.0 if brick else 30.0) if not civic else 40.0
	var height: float = w * (texture.get_height() / float(texture.get_width())) if texture != null else 30.0
	var footprint := PackedVector2Array([Vector2(-w*0.5,0),Vector2(w*0.5,0),Vector2(w*0.5,-6),Vector2(-w*0.5,-6)])
	var shadow_points := footprint.duplicate()
	var shift := DEPTH.offset_for_height(height+8.0)
	for point: Vector2 in footprint: shadow_points.append(point+shift)
	# The stack casts onto its own roof with the shared sun shade.
	var cast := _face(stack,Geometry2D.convex_hull(shadow_points),Color(1,1,1,0.9))
	cast.name = "FlueCast"
	cast.material = DEPTH.SUN_SHADOW_MATERIAL
	var flashing := _face(stack,flashing_points,Color("414d49"))
	flashing.name = "RoofFlashing"
	if texture != null:
		var sprite := Sprite2D.new()
		sprite.name = "ChimneyStack"
		sprite.texture = texture
		sprite.centered = false
		sprite.scale = Vector2.ONE * (w / texture.get_width())
		sprite.position = Vector2(-w*0.5, 4.0-height)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		stack.add_child(sprite)
	var mouth := Node2D.new()
	mouth.name = "FlueMouth"
	mouth.position = Vector2(0, 8.0-height)
	stack.add_child(mouth)
	return true

## The rectangles RoofOverlay cuts out of its roof over each door (door cells
## plus the eave reach outward), in the roof polygon's space.
static func door_notches(plane: Node) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var overlay: Node = plane
	while overlay != null and not overlay is RoofOverlay: overlay = overlay.get_parent()
	if overlay == null: return result
	var cell := float(overlay.get("_cell_px"))
	for door_value: Variant in overlay.get("_doors"):
		var door := door_value as Dictionary
		if door == null or not door.has("pos") or not door.has("dir"): continue
		var pos: Vector2i = door["pos"]
		var dir: Vector2i = door["dir"]
		var width: int = int(door.get("width", 2))
		var perp := Vector2i(-dir.y, dir.x)
		var first := pos + perp * -(width >> 1)
		var last := first + perp * (width - 1)
		var cells := Rect2(Vector2(first) * cell, Vector2.ONE * cell).merge(Rect2(Vector2(last) * cell, Vector2.ONE * cell))
		var outward := Vector2(dir) * (RoofOverlay.ROOF_INSET_PX + 24.0)
		result.append(cells.merge(Rect2(cells.position + outward, cells.size)))
	return result

static func _oval(parent: Node2D, center: Vector2, radius: Vector2, color: Color) -> Polygon2D:
	var points := PackedVector2Array()
	for step in range(12):
		var angle := TAU*float(step)/12.0
		points.append(center+Vector2(cos(angle),sin(angle))*radius)
	return _face(parent,points,color)
