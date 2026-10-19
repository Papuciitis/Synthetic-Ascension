extends RefCounted
## Presentation follows the complete dungeon plan; each chunk owns only its
## clipped pixels. Geometry, collision and rewards remain with the generator.

const ROOF := preload("res://scenes/world/buildings/DungeonRoof.gd")
const KIT := preload("res://scenes/world/buildings/CityBlockKit.gd")
const STONE := preload("res://assets/world/walls/wall_stone_face.png")

static func attach(chunk: Node2D, plan: Dictionary, offset: Vector2i, cells_per_chunk: int, cell_px: int) -> Node2D:
	var host := Node2D.new()
	host.name = "DungeonArchitecture"
	host.position = -Vector2(offset)*cell_px
	host.set_meta(&"dungeon_region",plan.region)
	host.set_meta(&"dungeon_seed",plan.seed)
	host.add_to_group(&"dungeon_architecture")
	chunk.add_child(host)
	var clip := Rect2(Vector2(offset)*cell_px,Vector2.ONE*cells_per_chunk*cell_px)
	var region: Rect2i = plan.region
	# Paved compound floors receive deliberate planting, not ambient weed scatter.
	var deco_clear: Dictionary = chunk.get_meta(&"_proc_deco_clear_cells",{}).duplicate()
	var local_region := Rect2i(region.position-offset,region.size).intersection(Rect2i(0,0,cells_per_chunk,cells_per_chunk))
	ChunkShapeGen.add_rect(deco_clear,local_region)
	chunk.set_meta(&"_proc_deco_clear_cells",deco_clear)
	if not plan.get("court_outdoor",true):
		# Compact halls are indoors even when their surrounding segment uses
		# mossy street paving. Restrict this opt-in floor to the real enclosure.
		var area := Rect2(Vector2(region.position)*cell_px,Vector2(region.size)*cell_px).grow(-24)
		var interior_floor := _panel(host,area,clip,Color(0.78,0.81,0.78),-92)
		if interior_floor != null:
			interior_floor.name = "DungeonInteriorFloor"
			interior_floor.texture = KIT._texture("paving.png")
			interior_floor.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			interior_floor.texture_scale = Vector2.ONE*3.0
			var material := ShaderMaterial.new()
			material.shader = preload("res://scenes/world/buildings/city_paving.gdshader")
			material.set_shader_parameter("area",Vector4(area.position.x,area.position.y,area.end.x,area.end.y))
			material.set_shader_parameter("edge_feather",2.0)
			material.set_shader_parameter("surface_contrast",0.30)
			interior_floor.material = material
	var covered: Array[Rect2] = []
	for wing: Rect2i in plan.roofs:
		var interior := wing.intersection(region.grow(-1))
		covered.append(Rect2(host.global_position+Vector2(interior.position)*cell_px,Vector2(interior.size)*cell_px))
	# Broad wing shadows, quiet court/hall floor, not a second decorative tile grid.
	for wing: Rect2i in plan.roofs:
		var area := Rect2(Vector2(wing.position)*cell_px,Vector2(wing.size)*cell_px)
		_panel(host,area.grow(18).intersection(Rect2(Vector2(region.position)*cell_px,Vector2(region.size)*cell_px)),clip,Color(0.06,0.12,0.13,0.15),-8)
	_wall_relief(host,plan,clip,cell_px)
	var holes := _portal_roof_holes(plan,cell_px)
	# Three separately shaded gables share the full-plan texture/ridge origin.
	for index in range(plan.roofs.size()):
		var wing: Rect2i = plan.roofs[index]
		var area := Rect2(Vector2(wing.position)*cell_px,Vector2(wing.size)*cell_px)
		if not area.intersects(clip): continue
		var roof := ROOF.new()
		roof.name = "DungeonWing%d" % index
		host.add_child(roof)
		roof.configure_slice(area,clip,covered,minf(148.0 if index == 2 else 128.0,area.size.y*0.40),false,holes)
		roof.set_meta(&"dungeon_wing",wing)
	for accent: Rect2i in plan.get("roof_accents",[]):
		var area := Rect2(Vector2(accent.position)*cell_px,Vector2(accent.size)*cell_px)
		if not area.grow(96).intersects(clip): continue
		var roof := ROOF.new()
		roof.name = "DungeonGatehouseCap"
		host.add_child(roof)
		roof.configure_slice(area,clip,covered,minf(128,area.size.y*0.4),false,holes,96,KIT._texture("donjon_masonry_bay.png"))
		roof.set_meta(&"dungeon_wing",accent)
	# One attached clay service cap contrasts with the slate halls.
	if region.size.y >= 24:
		var west: Rect2i = plan.roofs[2]
		var service := Rect2i(west.position+Vector2i(0,maxi(0,west.size.y-5)),Vector2i(west.size.x,mini(5,west.size.y)))
		var roof := ROOF.new()
		roof.name = "DungeonServiceCap"
		host.add_child(roof)
		roof.configure_slice(Rect2(Vector2(service.position)*cell_px,Vector2(service.size)*cell_px),clip,covered,80,true,holes)
		roof.set_meta(&"dungeon_wing",service)
	_entrance(host,plan,clip,cell_px)
	_chambers(host,plan,clip,cell_px)
	_court(host,plan,clip,cell_px)
	return host

static func _panel(host: Node2D, area: Rect2, clip: Rect2, color: Color, layer: int = -2) -> Polygon2D:
	var part := area.intersection(clip)
	if not part.has_area(): return null
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array([part.position,Vector2(part.end.x,part.position.y),part.end,Vector2(part.position.x,part.end.y)])
	polygon.color = color
	polygon.z_index = layer
	host.add_child(polygon)
	return polygon

static func _image(host: Node2D, area: Rect2, clip: Rect2, texture: Texture2D, layer: int = -2) -> Polygon2D:
	if texture == null: return null
	var polygon := _panel(host,area,clip,Color.WHITE,layer)
	if polygon == null: return null
	polygon.texture = texture
	var uvs := PackedVector2Array()
	for point: Vector2 in polygon.polygon: uvs.append((point-area.position)/area.size*texture.get_size())
	polygon.uv = uvs
	return polygon

static func _image_region(host: Node2D, area: Rect2, clip: Rect2, texture: Texture2D, source: Rect2, layer: int = -2) -> Polygon2D:
	var polygon := _panel(host,area,clip,Color.WHITE,layer)
	if polygon == null: return null
	polygon.texture = texture
	var uv := PackedVector2Array()
	for point: Vector2 in polygon.polygon: uv.append(source.position+(point-area.position)/area.size*source.size)
	polygon.uv = uv
	return polygon

static func _masonry_run(host: Node2D, area: Rect2, clip: Rect2, phase_x: float) -> void:
	var source := KIT._texture("donjon_masonry_bay.png")
	if source == null: return
	var scale_value := area.size.y/414.0
	var width := 2020.0*scale_value
	var run_clip := area.intersection(clip)
	if not run_clip.has_area(): return
	var first := floori((area.position.x-phase_x)/width)
	var last := ceili((area.end.x-phase_x)/width)
	for tile in range(first,last):
		var start := Vector2(phase_x+tile*width-64*scale_value,area.end.y-542*scale_value)
		_image(host,Rect2(start,source.get_size()*scale_value),run_clip,source)

static func _pier(host: Node2D, foot: Vector2, clip: Rect2, height: float = 152.0) -> void:
	var source := KIT._texture("donjon_gate_arch.png")
	if source == null: return
	var width := height*315.0/800.0
	_panel(host,Rect2(foot+Vector2(-width*0.5+12,-height+12),Vector2(width,height)),clip,Color(0.04,0.08,0.08,0.25),-5)
	_image_region(host,Rect2(foot-Vector2(width*0.5,height),Vector2(width,height)),clip,source,Rect2(165,112,315,800))

static func _wall_relief(host: Node2D, plan: Dictionary, clip: Rect2, cell_px: int) -> void:
	var walls: Dictionary = plan.carve.wall_cells
	var region: Rect2i = plan.region
	for y in range(region.position.y,region.end.y):
		var x := region.position.x
		while x < region.end.x:
			if not walls.has(Vector2i(x,y)):
				x += 1
				continue
			var begin := x
			while x < region.end.x and walls.has(Vector2i(x,y)): x += 1
			if x-begin < 2: continue
			var area := Rect2(begin*cell_px+16,y*cell_px-68,(x-begin)*cell_px-32,112)
			_panel(host,Rect2(area.position+Vector2(10,16),area.size+Vector2(16,12)),clip,Color(0.03,0.08,0.09,0.26),-5)
			_masonry_run(host,area,clip,region.position.x*cell_px+16.0)
			for pier_x in range(begin+3,x,7):
				var p := Vector2(pier_x*cell_px+32,y*cell_px+32)
				_pier(host,p+Vector2(0,16),clip)
	# A few structural buttresses give long envelopes mass, without a second ring.
	for x: int in [region.position.x,region.end.x-1]:
		for y in range(region.position.y,region.end.y,8):
			var cell := Vector2i(x,y)
			if not walls.has(cell): continue
			var p := (Vector2(cell)+Vector2.ONE*0.5)*cell_px
			_pier(host,p+Vector2(0,16),clip,128)

static func _entrance(host: Node2D, plan: Dictionary, clip: Rect2, cell_px: int) -> void:
	var entries: Array[Vector2i] = plan.entrance_cells
	if entries.is_empty(): return
	var gap := Rect2(Vector2(entries[0])*cell_px,Vector2.ONE*cell_px)
	for cell: Vector2i in entries: gap = gap.merge(Rect2(Vector2(cell)*cell_px,Vector2.ONE*cell_px))
	var horizontal := gap.size.x >= gap.size.y
	var portal := Node2D.new()
	portal.name = "ActualDungeonEntrance"
	portal.set_meta(&"opening_cells",entries)
	portal.set_meta(&"opening_pixels",gap)
	host.add_child(portal)
	# Jambs flank the actual opening. No gate leaf or invented collision plane.
	for end in range(2):
		var p := Vector2(gap.position.x-22 if end == 0 else gap.end.x+2,gap.end.y-112) if horizontal else Vector2(gap.position.x+10,gap.position.y-82 if end == 0 else gap.end.y-34)
		_pier(portal,Vector2(gap.position.x-32 if end == 0 else gap.end.x+32,gap.end.y-16) if horizontal else p+Vector2(22,58),clip,164 if horizontal else 112)
		_lamp(portal,p+Vector2(0,55),clip)
	if horizontal:
		_masonry_run(portal,Rect2(gap.position.x-64,gap.end.y-180,gap.size.x+128,34),clip,gap.position.x-64)
		_panel(portal,Rect2(gap.position.x,gap.end.y-102,gap.size.x,8),clip,Color("354b46"))
		var arch := KIT._texture("donjon_gate_arch.png")
		if arch != null and gap.position.y > region_top(plan,cell_px):
			# Original transparent source: aperture x522..1013, baseline y912.
			# Preserve aspect ratio and fit the aperture to the actual carved span.
			var scale_value := gap.size.x/491.0
			var threshold := Vector2(gap.get_center().x,gap.end.y-16)
			_image(portal,Rect2(threshold-Vector2(768,912)*scale_value,arch.get_size()*scale_value),clip,arch)
	else:
		_panel(portal,Rect2(gap.position.x+8,gap.position.y-30,12,gap.size.y+16),clip,Color("4e635b"))
	_panel(portal,gap.grow(-8),clip,Color(0.49,0.54,0.47,0.35),-7)

static func _chambers(host: Node2D, plan: Dictionary, clip: Rect2, cell_px: int) -> void:
	for index in range(plan.rooms.size()):
		var room: Rect2i = plan.rooms[index]
		if not room.has_area(): continue
		var p := Vector2(room.position)*cell_px+Vector2(38,14)
		# Dressing remains wall-bound and nonblocking. Real cover comes from carve.
		_lamp(host,p,clip)
		if index == plan.rooms.size()-1:
			var source := KIT._texture("pressure_plant.png")
			if source != null: _image(host,Rect2(p+Vector2(18,24),source.get_size()*(100.0/source.get_width())),clip,source,-5)
			_panel(host,Rect2(p+Vector2(47,38),Vector2(5,18)),clip,Color(0.27,0.64,0.66,0.6),-4)
		elif index%3 == 0 and room.size.x > 3:
			_panel(host,Rect2(p+Vector2(8,15),Vector2(76,18)),clip,Color("675d44"),-5)
			for bar in range(5): _panel(host,Rect2(p+Vector2(14+bar*13,-15),Vector2(5,40)),clip,Color("35453f"),-4)
		# A barred bay sits only on an actual solid chamber boundary.
		var wall_y := room.end.y if room.position.y < plan.court.position.y else room.position.y-1
		var support := Vector2i(room.position.x+1,wall_y)
		if plan.carve.wall_cells.has(support) and plan.carve.wall_cells.has(support+Vector2i.RIGHT):
			var grille := KIT._texture("donjon_cell_grille.png")
			if grille != null:
				var scale_value := 128.0/1413.0
				var base := (Vector2(support)+Vector2(1,0.5))*cell_px
				_image(host,Rect2(base-Vector2(887,753)*scale_value,grille.get_size()*scale_value),clip,grille)
	# A north entrance presents its monumental arch on the real court-facing
	# gallery passage, where the camera-facing source projection agrees.
	var entries: Array[Vector2i] = plan.entrance_cells
	if plan.get("court_outdoor",true) and not entries.is_empty() and entries[0].y == plan.region.position.y:
		var chosen := _gallery_portal(plan)
		var arch := KIT._texture("donjon_gate_arch.png")
		if chosen.x >= 0 and arch != null:
			var scale_value := 128.0/491.0
			var foot := Vector2((chosen.x+1)*cell_px,(chosen.y+1)*cell_px-16)
			_image(host,Rect2(foot-Vector2(768,912)*scale_value,arch.get_size()*scale_value),clip,arch)

static func region_top(plan: Dictionary, cell_px: int) -> float:
	return float(plan.region.position.y*cell_px)

static func _gallery_portal(plan: Dictionary) -> Vector2i:
	var entries: Array[Vector2i] = plan.entrance_cells
	var chosen := Vector2i(-999,-999)
	var best := 999999
	if not plan.get("court_outdoor",true) or entries.is_empty() or entries[0].y != plan.region.position.y: return chosen
	var aligned := Vector2i(mini(entries[0].x,entries[-1].x),plan.court.position.y-1)
	if not plan.carve.wall_cells.has(aligned) and not plan.carve.wall_cells.has(aligned+Vector2i.RIGHT): return aligned
	for index in range(0,plan.portals.size()-1,2):
		var at: Vector2i = plan.portals[index]
		if at.y != plan.court.position.y-1: continue
		var distance := absi(at.x-entries[0].x)
		if distance < best: best = distance; chosen = at
	return chosen

static func _portal_roof_holes(plan: Dictionary, cell_px: int) -> Array[Rect2]:
	var entries: Array[Vector2i] = plan.entrance_cells
	var holes: Array[Rect2] = []
	if entries.is_empty(): return holes
	var gap := Rect2(Vector2(entries[0])*cell_px,Vector2.ONE*cell_px)
	for cell: Vector2i in entries: gap = gap.merge(Rect2(Vector2(cell)*cell_px,Vector2.ONE*cell_px))
	if gap.size.x >= gap.size.y: holes.append(Rect2(gap.position-Vector2(14,200),gap.size+Vector2(28,300)))
	else: holes.append(gap.grow(24))
	var portal := _gallery_portal(plan)
	if portal.x >= 0: holes.append(Rect2(Vector2(portal)*cell_px-Vector2(14,210),Vector2(cell_px*2+28,cell_px+260)))
	return holes

static func _lamp(host: Node2D, at: Vector2, clip: Rect2) -> void:
	var texture := KIT._texture("wall_lantern.png")
	if texture == null: return
	var scale_value := 84.0/texture.get_height()
	_image(host,Rect2(at-Vector2(205,425)*scale_value,texture.get_size()*scale_value),clip,texture,-4)
	for radius: float in [28.0,15.0,6.0]:
		_panel(host,Rect2(at-Vector2.ONE*radius,Vector2.ONE*radius*2),clip,Color(0.8,0.52,0.16,0.025),-5)

static func _court(host: Node2D, plan: Dictionary, clip: Rect2, cell_px: int) -> void:
	var feature: Vector2i = plan.get("court_feature",Vector2i(-999,-999))
	if feature.x < 0: return
	var foot := (Vector2(feature)+Vector2.ONE*0.5)*cell_px
	var planter := KIT._texture("planted_corner.png")
	if planter != null:
		var scale_value := 210.0/planter.get_width()
		_panel(host,Rect2(foot+Vector2(-108,-12),Vector2(190,50)),clip,Color(0.05,0.11,0.10,0.22),-7)
		_image(host,Rect2(foot-Vector2(800,870)*scale_value,planter.get_size()*scale_value),clip,planter,-4)
	var tree := KIT._texture("temperate_tree.png")
	if tree != null:
		var scale_value := 280.0/tree.get_width()
		_image(host,Rect2(foot-Vector2(650,1170)*scale_value,tree.get_size()*scale_value),clip,tree,-4)
