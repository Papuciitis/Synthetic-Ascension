extends RefCounted
## One guard-office family fitted to existing parcel/door data. The plan is
## presentation-only; it owns no blocks, rooms, rewards or random state.

static func plan(footprint_px: PackedVector2Array, roof_support_px: PackedVector2Array, doors: Array, cell_px: int, visual_seed: int) -> Dictionary:
	var result := {
		"arch_bays": [], "entry_recesses": [], "roof_planes": [], "wall_faces": [],
		"watch_support": PackedVector2Array(), "has_watch": false,
		"fallback_reason": &"invalid_footprint",
	}
	if footprint_px.size() < 3 or absf(_area(footprint_px)) < 1.0 or cell_px <= 0:
		return result
	var scale_value := float(cell_px) / 64.0
	var facade_height := (192.0 if footprint_px.size() == 4 else 112.0) * scale_value
	var pier := 24.0 * scale_value
	for door: Dictionary in doors:
		result.entry_recesses.append({
			"door": door.duplicate(true), "opening": _door_rect(door,cell_px),
			"height": facade_height, "depth": 24.0 * scale_value,
		})
	for index: int in footprint_px.size():
		var a := footprint_px[index]
		var b := footprint_px[(index+1) % footprint_px.size()]
		if not is_equal_approx(a.y,b.y) or is_equal_approx(a.x,b.x): continue
		var midpoint := (a+b)*0.5
		if Geometry2D.is_point_in_polygon(midpoint+Vector2(0,1),footprint_px): continue
		var runs: Array[Vector2] = [Vector2(minf(a.x,b.x)+pier,maxf(a.x,b.x)-pier)]
		var wall_runs: Array[Vector2] = [Vector2(minf(a.x,b.x)+16.0*scale_value,maxf(a.x,b.x)-16.0*scale_value)]
		for entry: Dictionary in result.entry_recesses:
			var gap: Rect2 = entry.opening
			if entry.door.dir != Vector2i.DOWN or not is_equal_approx(gap.end.y,a.y): continue
			var remaining: Array[Vector2] = []
			for run: Vector2 in runs:
				# The original open master has 72 px returns at the fitted 128 px
				# doorway scale. Reserve 80 including its contact/coping margin.
				var entry_margin := 80.0*scale_value
				if run.x < gap.position.x-entry_margin: remaining.append(Vector2(run.x,minf(run.y,gap.position.x-entry_margin)))
				if run.y > gap.end.x+entry_margin: remaining.append(Vector2(maxf(run.x,gap.end.x+entry_margin),run.y))
			runs = remaining
			var wall_remaining: Array[Vector2] = []
			for run: Vector2 in wall_runs:
				if run.x < gap.position.x: wall_remaining.append(Vector2(run.x,minf(run.y,gap.position.x)))
				if run.y > gap.end.x: wall_remaining.append(Vector2(maxf(run.x,gap.end.x),run.y))
			wall_runs = wall_remaining
		for run: Vector2 in wall_runs:
			if run.y > run.x: result.wall_faces.append(Rect2(run.x,a.y-16.0*scale_value-facade_height,run.y-run.x,facade_height))
		for run: Vector2 in runs:
			var available := run.y-run.x
			if available < 128.0*scale_value: continue
			var count := maxi(1,int(floor((available+pier)/(160.0*scale_value+pier))))
			var width := minf(160.0*scale_value,available)
			var group_width := width*count+pier*(count-1)
			var start := run.x+(available-group_width)*0.5
			for bay_index: int in count:
				var x := start+bay_index*(width+pier)
				var support := Rect2(x,a.y-float(cell_px),width,float(cell_px))
				if not _rect_fits(support,footprint_px): continue
				result.arch_bays.append({
					"kind": &"closed_inspection", "span": Vector2(x,x+width),
					"face": Rect2(x,a.y-16.0*scale_value-facade_height,width,facade_height),
					"support": support, "depth": 24.0*scale_value,
				})
	if roof_support_px.size() >= 3 and absf(_area(roof_support_px)) >= 1.0:
		result.roof_planes.append({"kind":&"guard_hall","polygon":roof_support_px.duplicate(),"lift":0.0,"support":roof_support_px.duplicate()})
		var box := _bounds(roof_support_px)
		var margin := 16.0*scale_value
		var size_value := Vector2.ONE*128.0*scale_value
		var candidates: Array[Vector2] = [
			box.position+Vector2.ONE*margin,
			Vector2(box.end.x-size_value.x-margin,box.position.y+margin),
			Vector2(box.position.x+margin,box.end.y-size_value.y-margin),
			box.end-size_value-Vector2.ONE*margin,
		]
		for offset: int in 4:
			var candidate := Rect2(candidates[posmod(visual_seed+offset,4)],size_value)
			if not _rect_fits(candidate.grow(margin),roof_support_px): continue
			var watch_support := _rect_polygon(candidate)
			result.watch_support = watch_support
			result.has_watch = true
			result.roof_planes.append({"kind":&"guard_watch","polygon":watch_support.duplicate(),"lift":128.0*scale_value,"support":watch_support.duplicate()})
			break
	result["fallback_reason"] = &"" if result.has_watch else &"no_watch_support"
	return result

static func _door_rect(door: Dictionary, cell_px: int) -> Rect2:
	var direction: Vector2i = door.dir
	var across := Vector2i(-direction.y,direction.x)
	var width := maxi(1,int(door.get("width",2)))
	var first: Vector2i = door.pos-across*(width >> 1)
	var last := first+across*(width-1)
	return Rect2(Vector2(first)*cell_px,Vector2.ONE*cell_px).merge(Rect2(Vector2(last)*cell_px,Vector2.ONE*cell_px))

static func _rect_fits(rect: Rect2, polygon: PackedVector2Array) -> bool:
	return rect.has_area() and polygon.size() >= 3 and Geometry2D.clip_polygons(_rect_polygon(rect),polygon).is_empty()

static func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])

static func _bounds(polygon: PackedVector2Array) -> Rect2:
	var box := Rect2(polygon[0],Vector2.ZERO)
	for point: Vector2 in polygon: box = box.expand(point)
	return box

static func _area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index: int in polygon.size():
		var a := polygon[index]
		var b := polygon[(index+1)%polygon.size()]
		area += a.x*b.y-b.x*a.y
	return area*0.5


static func compose_roof(roof: RoofOverlay, form_plan: Dictionary, textures: Dictionary) -> void:
	var host := roof.get_node("RoofPoly") as Polygon2D
	var group := Node2D.new()
	group.name = "GuardRoofComposition"
	host.add_child(group)
	if host.material is ShaderMaterial:
		var material := host.material as ShaderMaterial
		material.set_shader_parameter("gable",1.0)
		material.set_shader_parameter("ridge_along_x",1.0)
		material.set_shader_parameter("material_contrast",0.22)
		material.set_shader_parameter("ridge_light",0.22)
	if not bool(form_plan.get("has_watch",false)): return
	var support: PackedVector2Array = form_plan.watch_support
	var box := _bounds(support)
	var scale_value := float(roof._cell_px)/64.0
	# Rebalance cap/body inside the original full visible envelope: raising
	# the wall head32 and insetting the rear eave32 keeps the ridge unchanged.
	var lift := 128.0*scale_value
	var front_end := box.end.x-28.0*scale_value
	var front_width := front_end-box.position.x
	var cast := support.duplicate()
	var depth_style := preload("res://core/systems/world/WorldDepthStyle.gd")
	var offset := depth_style.offset_for_height(lift)
	for point: Vector2 in support: cast.append(point+offset)
	# The raised watch casts onto the hall roof with the shared sun shade.
	for shadow: PackedVector2Array in Geometry2D.intersect_polygons(Geometry2D.convex_hull(cast),host.polygon):
		var roof_cast := _face(group,shadow,Color(1,1,1,0.85))
		roof_cast.name = "GuardWatchRoofCast"
		roof_cast.material = depth_style.SUN_SHADOW_MATERIAL
	var front := PackedVector2Array([Vector2(box.position.x,box.end.y-lift),Vector2(front_end,box.end.y-lift),Vector2(front_end,box.end.y),Vector2(box.position.x,box.end.y)])
	var body := _surface(group,front,textures,Color("c2c5b7"),&"infill")
	body.name = "GuardWatchFront"
	var side_points := PackedVector2Array([front[1],Vector2(box.end.x,box.end.y-lift-24.0*scale_value),Vector2(box.end.x,box.end.y-24.0*scale_value),front[2]])
	var rear_contact := _face(group,PackedVector2Array([side_points[1],side_points[1]+Vector2(7,5),side_points[2]+Vector2(7,5),side_points[2]]),Color(0.08,0.14,0.13,0.38))
	rear_contact.name = "GuardWatchRearContact"
	# The side return faces east, toward the sun: lit above the shaded front.
	var side := _surface(group,side_points,textures,Color("ccd0bf"),&"infill")
	side.name = "GuardWatchSide"
	# A compact raised pitch makes this a watch pavilion rather than another
	# flat equipment box. Its small overhang stays within the fitted margin.
	var cap_points := PackedVector2Array([
		Vector2(box.position.x-8,box.position.y+32.0*scale_value-lift+8),
		Vector2(box.get_center().x,box.position.y+32.0*scale_value-lift-32),
		Vector2(box.end.x+8,box.position.y+32.0*scale_value-lift+8),
		Vector2(box.end.x+8,box.end.y-lift),
		Vector2(box.position.x-8,box.end.y-lift),
	])
	cap_points = roof._notch_doors(cap_points,true)
	var cap := _face(group,cap_points,Color(0.91,0.97,1.0))
	cap.name = "GuardWatchCap"
	cap.texture = textures.get("slate") as Texture2D
	cap.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	cap.texture_scale = host.texture_scale
	if host.material is ShaderMaterial:
		var cap_material := (host.material as ShaderMaterial).duplicate() as ShaderMaterial
		cap_material.set_shader_parameter("bounds",Vector4(box.position.x,box.position.y-lift,box.end.x,box.end.y-lift))
		cap_material.set_shader_parameter("ridge_along_x",0.0)
		cap.material = cap_material
	_occlusion_form(cap,&"guard_watch",lift,true)
	# Remove only what the final door-notched cap actually covers. Usually
	# this is one compact lower body; a notch can expose a small side corner.
	# Exact polygon subtraction retains that corner without redundant masks.
	var coverage_index := 0
	for body_union: PackedVector2Array in Geometry2D.merge_polygons(front,side_points):
		for uncovered: PackedVector2Array in Geometry2D.clip_polygons(body_union,cap_points):
			var body_coverage := _face(group,uncovered,Color(0,0,0,0))
			body_coverage.name = "GuardWatchBodyCoverage" if coverage_index==0 else "GuardWatchBodyCoverage%d" % coverage_index
			_occlusion_form(body_coverage,&"guard_watch_body",0.0,true)
			coverage_index+=1
	# These joins sit inside the already covered body; only its existing
	# front/side/cap consume actor-mask geometry, not every surface detail.
	var plinth := _surface(group,_rect_polygon(Rect2(box.position.x,box.end.y-14,front_width,14)),textures,Color("88988b"),&"plinth")
	plinth.name = "GuardWatchPlinth"
	_surface(group,PackedVector2Array([side_points[2]-Vector2(0,14),side_points[2],side_points[3],side_points[3]-Vector2(0,14)]),textures,Color("7f9383"),&"plinth")
	for x: float in [box.position.x,front_end-12]:
		_surface(group,_rect_polygon(Rect2(x,box.end.y-lift+6,12,lift-20)),textures,Color("d1d1ba"),&"return")
	var eave_shadow := _face(group,_rect_polygon(Rect2(box.position.x,box.end.y-lift+5,front_width,9)),Color(0.13,0.21,0.20,0.66))
	eave_shadow.name = "GuardWatchEaveShadow"
	var window := Rect2(box.position.x+front_width*0.5-28,box.end.y-lift+34,56,56)
	_surface(group,_rect_polygon(window.grow(6)),textures,Color("8b9a8b"),&"return")
	_face(group,_rect_polygon(window),Color("293f3e"))
	_face(group,_rect_polygon(Rect2(window.get_center().x-2,window.position.y,4,window.size.y)),Color("a1ad98"))
	_face(group,_rect_polygon(Rect2(window.position.x,window.get_center().y-2,window.size.x,4)),Color("7e9386"))
	_face(group,_rect_polygon(Rect2(window.position.x-6,window.end.y+1,window.size.x+12,7)),Color("c4c8ad"))
	_face(group,_rect_polygon(Rect2(box.position.x-4,box.end.y-lift-4,box.size.x+8,9)),Color("c5cab5"))

static func compose_frontage(kit: Node2D, form_plan: Dictionary, textures: Dictionary) -> void:
	var group := Node2D.new()
	group.name = "GuardFrontage"
	group.set_meta(&"city_facade_detail",true)
	kit.add_child(group)
	for wall: Rect2 in form_plan.get("wall_faces",[]):
		var face := _surface(group,_rect_polygon(wall),textures,Color.WHITE,&"infill")
		face.vertex_colors = PackedColorArray([Color("c7c8b9"),Color("d0cdbd"),Color("adb5a5"),Color("a4b1a3")])
		_face(group,_rect_polygon(Rect2(wall.position+Vector2(0,4),Vector2(wall.size.x,10))),Color("c3c5ad"))
		_surface(group,_rect_polygon(Rect2(wall.position.x,wall.end.y-22,wall.size.x,22)),textures,Color("8b9c8e"),&"plinth")
		for x: float in [wall.position.x,wall.end.x-12]:
			_surface(group,_rect_polygon(Rect2(x,wall.position.y+14,12,wall.size.y-36)),textures,Color("bbc3ab"),&"return")
	for bay: Dictionary in form_plan.arch_bays:
		var face: Rect2 = bay.face
		_face(group,_rect_polygon(face.grow(5)),Color("56685f"))
		var texture := textures.get("arch_closed") as Texture2D
		if texture != null:
			_sprite(group,"GuardInspectionBay",texture,Rect2(71,65,1002,1245),face)
		else:
			_face(group,_rect_polygon(face),Color("53665e"))
	for entry: Dictionary in form_plan.entry_recesses:
		var gap: Rect2 = entry.opening
		var direction: Vector2i = entry.door.dir
		var portal := Node2D.new()
		portal.name = "GuardEntryPortal"
		portal.set_meta(&"door_cells_px",gap)
		portal.set_meta(&"door_direction",direction)
		group.add_child(portal)
		if direction == Vector2i.DOWN:
			var height: float = entry.height
			var baseline := gap.end.y-16
			var texture := textures.get("arch_open") as Texture2D
			var width := gap.size.x*1232.0/580.0
			var frame := Rect2(gap.get_center().x-width*0.5,baseline-height,width,height)
			var support := Rect2(frame.position.x,gap.position.y,frame.size.x,gap.size.y)
			var footprint: PackedVector2Array = (kit.get("_roof") as RoofOverlay).footprint_outline_px
			if texture != null and _rect_fits(support,footprint):
				_sprite(portal,"GuardOpenArch",texture,Rect2(152,37,1232,941),frame)
			else:
				_face(portal,_rect_polygon(Rect2(gap.position.x-24,baseline-height,24,height)),Color("96a590"))
				_face(portal,_rect_polygon(Rect2(gap.end.x,baseline-height,24,height)),Color("b2b59d"))
				_face(portal,_rect_polygon(Rect2(gap.position.x-24,baseline-height,gap.size.x+48,18)),Color("bbc0a4"))
		else:
			# Cardinal contacts remain ground-aligned geometry, never a rotated
			# south facade that paints a false door or wall across the opening.
			_face(portal,_rect_polygon(gap.grow(-7)),Color(0.13,0.23,0.23,0.32))
			_threshold(portal,gap,direction,textures)

static func _threshold(parent: Node2D, gap: Rect2, direction: Vector2i, textures: Dictionary) -> void:
	# Join the already carved sill to48px of its existing clear apron as one
	# continuous surface. Its material changes no floor/nav/collision data.
	var depth := minf(gap.size.x,gap.size.y)*0.75
	var landing: Rect2
	if direction == Vector2i.RIGHT: landing=Rect2(gap.end.x,gap.position.y,depth,gap.size.y)
	elif direction == Vector2i.LEFT: landing=Rect2(gap.position.x-depth,gap.position.y,depth,gap.size.y)
	else: landing=Rect2(gap.position.x,gap.position.y-depth,gap.size.x,depth)
	landing=landing.merge(gap)
	var slab := _surface(parent,_rect_polygon(landing),textures,Color("8b9e8d"),&"threshold")
	slab.name = "GuardThreshold"
	var outward := Vector2(direction)
	var across := Vector2(-direction.y,direction.x)
	var boundary := gap.get_center()+outward*gap.size*0.5
	var span := gap.size.y if direction.x!=0 else gap.size.x
	for end_sign: float in [-1.0,1.0]:
		var at := boundary+across*(span*0.5)*end_sign
		var foot := Rect2(at-Vector2(9,5),Vector2(18,10))
		var jamb := _surface(parent,_rect_polygon(Rect2(foot.position.x,foot.end.y-20,foot.size.x,20)),textures,Color("99a88f"),&"return")
		jamb.name = "GuardJambReturn"
		_surface(parent,_rect_polygon(Rect2(foot.position-Vector2(0,20),foot.size)),textures,Color("aab49b"),&"return")
	if direction.x != 0:
		var edge_x := landing.end.x-2 if direction.x>0 else landing.position.x
		_face(parent,_rect_polygon(Rect2(edge_x,landing.position.y+8,2,landing.size.y-16)),Color(0.40,0.48,0.42,0.45))
	else:
		_face(parent,_rect_polygon(Rect2(landing.position.x+8,landing.position.y,landing.size.x-16,2)),Color(0.40,0.48,0.42,0.45))

static func _surface(parent: Node2D, points: PackedVector2Array, textures: Dictionary, color: Color, kind: StringName) -> Polygon2D:
	var face := _face(parent,points,color)
	face.set_meta(&"guard_surface",kind)
	face.texture = textures.get("infill") as Texture2D
	face.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var uv := PackedVector2Array()
	for point: Vector2 in points: uv.append(point*4.0)
	face.uv = uv
	return face

static func _occlusion_form(shape: Polygon2D, kind: StringName, lift: float, full_form: bool) -> void:
	shape.set_meta(&"city_roof_form",kind)
	shape.set_meta(&"city_roof_lift",lift)
	if full_form: shape.set_meta(&"roof_occlusion_full_form",true)

static func _face(parent: Node2D, points: PackedVector2Array, color: Color) -> Polygon2D:
	var face := Polygon2D.new()
	face.polygon = points
	face.color = color
	parent.add_child(face)
	return face

static func _sprite(parent: Node2D, sprite_name: String, texture: Texture2D, source: Rect2, target: Rect2) -> void:
	var sprite := Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = source
	sprite.position = target.position
	sprite.scale = target.size/source.size
	parent.add_child(sprite)
