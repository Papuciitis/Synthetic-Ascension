extends RefCounted
## Geometry around real cardinal openings; painted facades stay north-up.

const FOREGROUND := preload("res://core/systems/world/visibility/ForegroundSpriteCoverage.gd")
const COMPOSER := preload("res://scenes/world/buildings/CityFacadeComposer.gd")
const SOLID_GROUP := &"foreground_solid_occluders"
const GROUND_META := &"foreground_ground_contact"
const DOMESTIC_PLASTER := preload("res://scenes/world/buildings/domestic_plaster.gdshader")
const DOMESTIC_BASE := preload("res://assets/world/walls/kit/wall34_10.png")
const PLASTER_SOURCE := Rect2(1360,260,140,240)
const TIMBER_SOURCE := Rect2(920,217,11,420)
const WINDOW_SOURCES: Array[Rect2] = [Rect2(294,172,420,460),Rect2(1480,120,520,510)]

static func compose(kit: Node2D, doors: Array, cell_px: int, outline: PackedVector2Array, lantern_texture: Texture2D = null, portal_masonry: Texture2D = null) -> void:
	var group := Node2D.new()
	group.name = "CardinalWallReturns"
	group.set_meta(&"city_facade_detail", true)
	kit.add_child(group)
	var box: Rect2 = kit.get("bounds")
	# Composed frontages (every segment) own all south runs and south doors.
	var composed: bool = COMPOSER.owns(kit)
	var finish: Texture2D = kit.get("_facade") if Global.attempt_segment == 2 and not bool(kit.get("civic")) else null
	var domestic: bool = not composed and Global.attempt_segment == 2 and not bool(kit.get("civic")) and StringName(kit.get_meta(&"building_usage",&"")) == &"row_house"
	var plaster_material: ShaderMaterial
	var plinth_material: ShaderMaterial
	if domestic and finish != null:
		plaster_material = ShaderMaterial.new()
		plaster_material.shader = DOMESTIC_PLASTER
		# Plain plaster between the original right door jamb and awning. The
		# former narrow left strip included a recognizable chipped frame edge.
		plaster_material.set_shader_parameter("source_rect",Vector4(PLASTER_SOURCE.position.x,PLASTER_SOURCE.position.y,PLASTER_SOURCE.size.x,PLASTER_SOURCE.size.y))
		plaster_material.set_shader_parameter("organic_plaster",true)
		plaster_material.set_shader_parameter("plaster_origin_texels",kit.to_global(Vector2.ZERO)*2.0)
		plinth_material = ShaderMaterial.new()
		plinth_material.shader = DOMESTIC_PLASTER
		plinth_material.set_shader_parameter("source_rect",Vector4(0,205,256,90))
	if outline.is_empty():
		if domestic:
			# This replaces the old complete-house tiles only for actual homes.
			# Their roof and all physical/cardinal opening ownership stay intact.
			var previous := kit.get_node_or_null("FacadeFaces") as CanvasItem
			if previous != null:
				previous.hide()
				for node: Node in previous.find_children("*","Sprite2D",true,false):
					node.remove_from_group(&"foreground_occluders")
				previous.queue_free()
			var front_runs: Array[Vector2] = [Vector2(box.position.x+16,box.end.x-16)]
			for door: Dictionary in doors:
				if door.dir != Vector2i.DOWN: continue
				var gap := _door_box(door,cell_px)
				var remaining: Array[Vector2] = []
				for run: Vector2 in front_runs:
					if run.x < gap.position.x: remaining.append(Vector2(run.x,minf(run.y,gap.position.x)))
					if run.y > gap.end.x: remaining.append(Vector2(maxf(run.x,gap.end.x),run.y))
				front_runs = remaining
			for run: Vector2 in front_runs:
				_domestic_wall(group,finish,run,box.end.y-16,float(kit.get("_facade_height")),box.end.y,plaster_material,plinth_material,doors,cell_px)
		# A continuous shaded return beneath the eave, split around side doors.
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			var x := box.position.x+16 if dir.x < 0 else box.end.x-16
			var runs: Array[Vector2] = [Vector2(box.position.y+12, box.end.y-20)]
			for door: Dictionary in doors:
				if door.dir != dir: continue
				var gap := _door_box(door,cell_px)
				var next: Array[Vector2] = []
				for run: Vector2 in runs:
					if run.x < gap.position.y: next.append(Vector2(run.x,minf(run.y,gap.position.y)))
					if run.y > gap.end.y: next.append(Vector2(maxf(run.x,gap.end.y),run.y))
				runs = next
			for run: Vector2 in runs:
				if run.y <= run.x: continue
				var face := _panel(group,Rect2(x-7,run.x,14,run.y-run.x),Color("57635f") if dir.x < 0 else Color("92998a"))
				if finish != null: _plaster(face,finish,Color("858d80") if dir.x < 0 else Color("b7b8a5"),plaster_material)
	else:
		# Intentional irregular fallback: masonry/eave courses follow every
		# actual south edge, including the recessed bay and rear L wing.
		for index in outline.size():
			var a := outline[index]
			var b := outline[(index+1)%outline.size()]
			if not is_equal_approx(a.y,b.y) or b.x >= a.x: continue
			if composed:
				COMPOSER.compose_run(group,kit,Vector2(b.x+16,a.x-16),b.y-16,float(kit.get("_facade_height")),b.y,doors,cell_px)
				continue
			var runs: Array[Vector2] = [Vector2(b.x+16,a.x-16)]
			for door: Dictionary in doors:
				if door.dir != Vector2i.DOWN: continue
				var gap := _door_box(door,cell_px)
				if not is_equal_approx(gap.end.y,b.y): continue
				var remaining: Array[Vector2] = []
				for run: Vector2 in runs:
					if run.x < gap.position.x: remaining.append(Vector2(run.x,minf(run.y,gap.position.x)))
					if run.y > gap.end.x: remaining.append(Vector2(maxf(run.x,gap.end.x),run.y))
				runs = remaining
			for run: Vector2 in runs:
				var height := float(kit.get("_facade_height"))
				if domestic:
					_domestic_wall(group,finish,run,b.y-16,height,b.y,plaster_material,plinth_material,doors,cell_px)
					continue
				_wall_bays(group,kit.get("_facade"),run,b.y-16,minf(height,112.0),bool(kit.get("civic")))
				if height > 112.0:
					var upper_finish := finish if finish != null else portal_masonry
					var upper := _panel(group,Rect2(run.x,b.y-16-height,run.y-run.x,height-112),Color.WHITE)
					if upper_finish != null: _plaster(upper,upper_finish,Color("b9b9a8"),plaster_material)
					_register_solid(upper,Vector2((run.x+run.y)*0.5,b.y))
	for door: Dictionary in doors:
		if door.dir == Vector2i.DOWN and (composed or (outline.is_empty() and not domestic)): continue
		var gap := _door_box(door,cell_px)
		var entry := Node2D.new()
		entry.name = "CardinalDoorRecess"
		entry.set_meta(&"door_cells_px",gap)
		entry.set_meta(&"door_direction",door.dir)
		group.add_child(entry)
		var dir: Vector2i = door.dir
		if dir == Vector2i.DOWN and (not outline.is_empty() or domestic):
			_upright_irregular_portal(entry,gap,float(kit.get("_facade_height")),finish if domestic else portal_masonry,domestic,plaster_material)
			continue
		# These are contact/soffit planes within the actual carved opening,
		# never a rotated south-facing image or a new collision shape.
		_panel(entry,gap.grow(-6),Color(0.12,0.19,0.20,0.38))
		if dir.x != 0:
			var x := gap.end.x-12 if dir.x > 0 else gap.position.x+12
			_panel(entry,Rect2(x-9,gap.position.y+4,18,12),Color("9ca28f"))
			_panel(entry,Rect2(x-9,gap.end.y-16,18,12),Color("768174"))
			_panel(entry,Rect2(gap.position.x+8,gap.position.y+16,6,gap.size.y-32),Color(0.15,0.22,0.23,0.5))
			if finish != null:
				for y: float in [gap.position.y-18,gap.end.y-8]:
					var pier := _panel(entry,Rect2(x-15,y,30,26),Color.WHITE)
					_masonry(pier,finish,Rect2(finish.get_size()*Vector2(0.391,0.29),finish.get_size()*Vector2(0.034,0.18)))
				var landing := _panel(entry,Rect2(gap.position.x+5,gap.position.y+8,gap.size.x-10,gap.size.y-16),Color("8f9989"))
				landing.z_index = -1
		else:
			var y := gap.position.y+12 if dir.y < 0 else gap.end.y-16
			_panel(entry,Rect2(gap.position.x+4,y,12,20),Color("818c7d"))
			_panel(entry,Rect2(gap.end.x-16,y,12,20),Color("a3a692"))
			_panel(entry,Rect2(gap.position.x+16,y-4,gap.size.x-32,7),Color("53625d"))
		if bool(kit.get("civic")) and lantern_texture != null:
			var lantern := Sprite2D.new()
			lantern.name = "CardinalEntryLantern"
			lantern.texture = lantern_texture
			lantern.scale = Vector2.ONE*(48.0/lantern.texture.get_height())
			var mount := Vector2(gap.end.x-16 if dir.x > 0 else gap.position.x+16,gap.position.y-18)
			lantern.position = mount+(lantern.texture.get_size()*0.5-Vector2(205,425))*lantern.scale
			entry.add_child(lantern)

static func _door_box(door: Dictionary, cell_px: int) -> Rect2:
	var dir: Vector2i = door.dir
	var perp := Vector2i(-dir.y,dir.x)
	var width := int(door.get("width",2))
	var first: Vector2i = door.pos + perp * -(width >> 1)
	var last := first + perp * (width-1)
	return Rect2(Vector2(first)*cell_px,Vector2.ONE*cell_px).merge(Rect2(Vector2(last)*cell_px,Vector2.ONE*cell_px))

static func _upright_irregular_portal(parent: Node2D, gap: Rect2, height: float, facade: Texture2D, domestic: bool = false, plaster_material: ShaderMaterial = null) -> void:
	var portal := Node2D.new()
	portal.name = "IrregularUprightPortal"
	parent.add_child(portal)
	# Same wall baseline/height as its neighboring footprint bays. The jambs
	# stand on the adjacent wall, outside the carver's complete opening span.
	var bottom := gap.end.y-16.0
	var top := bottom-height
	var left := gap.position.x
	var right := gap.end.x
	var opening_height := minf(height,104.0) if domestic else height
	var opening_top := bottom-opening_height
	portal.set_meta(&"opening_face",Rect2(left,opening_top,gap.size.x,opening_height))
	var recess := _panel(portal,Rect2(left,opening_top,gap.size.x,opening_height),Color.WHITE)
	recess.name = "Recess"
	recess.vertex_colors = PackedColorArray([Color("1d2c2e"),Color("1d2c2e"),Color("42514a"),Color("374840")])
	var supported_header: bool = domestic and opening_top > top
	var lintel_height := minf(14.0,opening_top-top) if supported_header else 14.0
	if supported_header and opening_top-lintel_height > top:
		var header := _panel(portal,Rect2(left,top+8,gap.size.x,opening_top-lintel_height-top-8),Color.WHITE)
		header.name = "DomesticDoorHeader"
		if facade != null: _plaster(header,facade,Color.WHITE,plaster_material)
		_register_solid(header,Vector2((left+right)*0.5,gap.end.y))
		if facade != null:
			_domestic_eave_tie(portal,facade,Rect2(left,top,gap.size.x,8),Vector2((left+right)*0.5,gap.end.y))
	var left_jamb := _panel(portal,Rect2(left-15,top+8,15,height-8),Color("8c9585"))
	left_jamb.name = "LeftJamb"
	var right_jamb := _panel(portal,Rect2(right,top+8,15,height-8),Color("b0af96"))
	right_jamb.name = "RightJamb"
	var lintel := _panel(portal,Rect2(left if supported_header else left-15,opening_top-lintel_height if supported_header else top+8,gap.size.x if supported_header else gap.size.x+30,lintel_height),Color("b0b19c"))
	lintel.name = "Lintel"
	for face: Polygon2D in [left_jamb,right_jamb,lintel]:
		_register_solid(face,Vector2((left+right)*0.5,gap.end.y))
	# Crop only the original entrance's masonry components, without a door
	# leaf or surrounding window bays. The shared roof still owns the eave.
	if facade != null:
		var size := facade.get_size()
		_masonry(left_jamb,facade,Rect2(size*Vector2(0.391,0.29),size*Vector2(0.034,0.63)))
		_masonry(right_jamb,facade,Rect2(size*Vector2(0.575,0.29),size*Vector2(0.034,0.63)))
		_masonry(lintel,facade,Rect2(size*Vector2(0.391,0.205),size*Vector2(0.218,0.085)))
	if domestic:
		recess.vertex_colors = PackedColorArray([Color("29332e"),Color("29332e"),Color("5e6958"),Color("536151")])
		_domestic_entry_depth(portal,gap,opening_top,bottom,facade,left_jamb,right_jamb)
		if facade != null:
			var leaf := _panel(portal,_domestic_leaf_rect(gap,opening_top,bottom),Color.WHITE)
			leaf.name = "DomesticOpenDoorLeaf"
			# New open-leaf geometry uses the original timber lining as wood
			# surfacing; the source does not contain an authored complete door.
			_masonry(leaf,facade,TIMBER_SOURCE)
			leaf.vertex_colors = PackedColorArray([Color(0.85,0.82,0.76),Color.WHITE,Color(0.92,0.88,0.80),Color(0.72,0.70,0.65)])
			_register_solid(leaf,Vector2((left+right)*0.5,gap.end.y))
	_panel(portal,Rect2(left,opening_top if domestic else top+22,gap.size.x,7),Color("263b39"))
	# A short, flush floor transition stays within the existing carver span.
	# The open leaf beside it adds no raised step or collision.
	var threshold := _panel(portal,Rect2(left,bottom-10,gap.size.x,14),Color.WHITE)
	threshold.name = "FlushThreshold"
	threshold.vertex_colors = PackedColorArray([Color("657367"),Color("657367"),Color("949b89"),Color("949b89")])
	_panel(portal,Rect2(left,bottom+4,gap.size.x,2),Color(0.19,0.27,0.25,0.35))

static func _domestic_entry_depth(parent: Node2D, gap: Rect2, opening_top: float, bottom: float, facade: Texture2D, left_jamb: Polygon2D, right_jamb: Polygon2D) -> void:
	# A shallow lit floor return breaks the tall black rectangle. It remains
	# floor presentation across the whole carver span, with no new collider.
	var floor := _panel(parent,Rect2(gap.position.x,bottom-44,gap.size.x,34),Color.WHITE)
	floor.name = "DomesticEntryFloor"
	var paving := load("res://assets/world/city_block/paving.png") as Texture2D
	if paving != null:
		_masonry(floor,paving,Rect2(Vector2(gap.position.x,bottom-44)*2.0,Vector2(gap.size.x,34)*2.0))
		floor.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		floor.color = Color("aab29d")
	if facade == null: return
	var wing_top := opening_top+8.0
	var wing_height := bottom-12.0-wing_top
	if wing_height <= 0: return
	var ground := Vector2(gap.get_center().x,gap.end.y)
	for side: int in range(2):
		var jamb := left_jamb if side == 0 else right_jamb
		var wing := Rect2(gap.position.x-12.0 if side == 0 else gap.end.x,wing_top,12,wing_height)
		var original := Rect2(jamb.polygon[0],jamb.polygon[2]-jamb.polygon[0])
		var source := Rect2(jamb.uv[0],jamb.uv[2]-jamb.uv[0])
		var pieces := _subtract_rect(original,wing)
		for index: int in pieces.size():
			var rect: Rect2 = pieces[index]
			var piece := jamb if index == 0 else _panel(parent,rect,Color.WHITE)
			piece.polygon = PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
			piece.texture = facade
			var uv := PackedVector2Array()
			for point: Vector2 in piece.polygon:
				uv.append(source.position+(point-original.position)/original.size*source.size)
			piece.uv = uv
			_register_solid(piece,ground)
		var timber := _panel(parent,wing,Color.WHITE)
		timber.name = "DomesticOpenTimberLeft" if side == 0 else "DomesticOpenTimberRight"
		# Only the original door's narrow timber lining, with no painted shutter
		# or black opening pixels. Folded outward within the existing jamb area.
		_masonry(timber,facade,TIMBER_SOURCE)
		_register_solid(timber,ground)

static func _masonry(shape: Polygon2D, texture: Texture2D, source: Rect2) -> void:
	shape.texture = texture
	shape.uv = PackedVector2Array([source.position,Vector2(source.end.x,source.position.y),source.end,Vector2(source.position.x,source.end.y)])
	shape.color = Color.WHITE

static func _plaster(shape: Polygon2D, texture: Texture2D, tint: Color, material: ShaderMaterial = null) -> void:
	# Plain field beside the existing shutter bay; no additional windows or
	# stretched ornament. Shared quiet material retains a broad limewash plane.
	_masonry(shape,texture,PLASTER_SOURCE if material != null else Rect2(texture.get_size()*Vector2(0.335,0.30),texture.get_size()*Vector2(0.038,0.36)))
	shape.color = tint
	if material != null:
		var uv := PackedVector2Array()
		for point: Vector2 in shape.polygon:
			uv.append(point*2.0)
		shape.uv = uv
		shape.material = material

static func _domestic_wall(parent: Node2D, texture: Texture2D, run: Vector2, bottom: float, height: float, ground_y: float, material: ShaderMaterial, plinth_material: ShaderMaterial, doors: Array, cell_px: int) -> void:
	if texture == null or run.y <= run.x: return
	var top := bottom-height
	var ground := Vector2((run.x+run.y)*0.5,ground_y)
	var ownership := Rect2(run.x,top,run.y-run.x,height)
	_domestic_eave_tie(parent,texture,Rect2(run.x,top,run.y-run.x,8),ground)
	# The continuous wall yields its actual image area to each detail. This
	# keeps the live roof fade and shared foreground strength in agreement.
	var cuts: Array[Rect2] = []
	var usable := run
	var adjacent_south_door := false
	var source_index := 0
	for door: Dictionary in doors:
		if door.dir != Vector2i.DOWN: continue
		var gap := _door_box(door,cell_px)
		if not is_equal_approx(gap.end.y,ground_y): continue
		var opening_top := bottom-minf(height,104.0)
		var leaf := _domestic_leaf_rect(gap,opening_top,bottom)
		cuts.append(Rect2(gap.position.x-15,top+8,15,height-8))
		cuts.append(Rect2(gap.end.x,top+8,15,height-8))
		cuts.append(leaf)
		if is_equal_approx(run.y,gap.position.x):
			usable.y = minf(usable.y,leaf.position.x)
			adjacent_south_door = true
		elif is_equal_approx(run.x,gap.end.x):
			usable.x = maxf(usable.x,gap.end.x+15)
			adjacent_south_door = true
			source_index = 1
	var centers: Array[float] = []
	if adjacent_south_door:
		if usable.y-usable.x >= 144: centers.append((usable.x+usable.y)*0.5)
	elif usable.y-usable.x >= 320:
		centers = [lerpf(usable.x,usable.y,0.30),lerpf(usable.x,usable.y,0.70)]
	elif usable.y-usable.x >= 144:
		centers.append((usable.x+usable.y)*0.5)
	for index: int in centers.size():
		var source: Rect2 = WINDOW_SOURCES[(source_index+index)%WINDOW_SOURCES.size()]
		var width := clampf(height*0.55,96,114)
		var scale_factor := width/source.size.x
		var draw := Rect2(Vector2(centers[index]-width*0.5,bottom-28-source.size.y*scale_factor),source.size*scale_factor)
		var fits := ownership.encloses(draw)
		for cut: Rect2 in cuts:
			if draw.intersects(cut): fits = false
		if not fits: continue
		var window := Sprite2D.new()
		window.name = "DomesticWindow"
		window.texture = texture
		window.region_enabled = true
		window.region_rect = source
		window.region_filter_clip_enabled = true
		window.centered = false
		window.position = draw.position
		window.scale = Vector2.ONE*scale_factor
		window.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		window.set_meta(&"domestic_window_opening",draw)
		parent.add_child(window)
		FOREGROUND.register(window,Vector2(draw.get_center().x,ground_y))
		cuts.append(draw)
	var fields: Array[Rect2] = [Rect2(run.x,top+8,run.y-run.x,height-24)]
	var plinths: Array[Rect2] = [Rect2(run.x,bottom-16,run.y-run.x,16)]
	for cut: Rect2 in cuts:
		var next_fields: Array[Rect2] = []
		for field: Rect2 in fields: next_fields.append_array(_subtract_rect(field,cut))
		fields = next_fields
		var next_plinths: Array[Rect2] = []
		for plinth: Rect2 in plinths: next_plinths.append_array(_subtract_rect(plinth,cut))
		plinths = next_plinths
	for rect: Rect2 in fields:
		var field := _panel(parent,rect,Color.WHITE)
		_plaster(field,texture,Color.WHITE,material)
		field.set_meta(&"domestic_wall_field",ownership)
		_register_solid(field,ground)
	for rect: Rect2 in plinths:
		var plinth := _panel(parent,rect,Color.WHITE)
		plinth.texture = DOMESTIC_BASE
		plinth.material = plinth_material
		var uv := PackedVector2Array()
		for point: Vector2 in plinth.polygon: uv.append(point*4.0)
		plinth.uv = uv
		plinth.set_meta(&"domestic_masonry_plinth",ownership)
		_register_solid(plinth,ground)

static func _domestic_eave_tie(parent: Node2D, texture: Texture2D, rect: Rect2, ground: Vector2) -> void:
	var beam := _panel(parent,rect,Color.WHITE)
	if beam == null: return
	beam.name = "DomesticEaveTie"
	beam.texture = texture
	# Rotate the original vertical lining's grain along this horizontal tie.
	beam.uv = PackedVector2Array([TIMBER_SOURCE.position,Vector2(TIMBER_SOURCE.position.x,TIMBER_SOURCE.end.y),TIMBER_SOURCE.end,Vector2(TIMBER_SOURCE.end.x,TIMBER_SOURCE.position.y)])
	_register_solid(beam,ground)

static func _domestic_leaf_rect(gap: Rect2, opening_top: float, bottom: float) -> Rect2:
	return Rect2(gap.position.x-55,opening_top+8,40,bottom-opening_top-20)

static func _subtract_rect(field: Rect2, cut: Rect2) -> Array[Rect2]:
	var intersection := field.intersection(cut)
	if not intersection.has_area(): return [field]
	var pieces: Array[Rect2] = []
	# Keep full-height side pieces, then any cap within the cut's X span.
	var candidates: Array[Rect2] = [
		Rect2(field.position,Vector2(intersection.position.x-field.position.x,field.size.y)),
		Rect2(Vector2(intersection.end.x,field.position.y),Vector2(field.end.x-intersection.end.x,field.size.y)),
		Rect2(Vector2(intersection.position.x,field.position.y),Vector2(intersection.size.x,intersection.position.y-field.position.y)),
		Rect2(Vector2(intersection.position.x,intersection.end.y),Vector2(intersection.size.x,field.end.y-intersection.end.y)),
	]
	for piece: Rect2 in candidates:
		if piece.has_area(): pieces.append(piece)
	return pieces

static func _panel(parent: Node2D, rect: Rect2, color: Color) -> Polygon2D:
	if not rect.has_area(): return null
	var shape := Polygon2D.new()
	shape.polygon = PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	shape.color = color
	parent.add_child(shape)
	return shape

static func _register_solid(shape: Polygon2D, ground_parent_local: Vector2) -> void:
	# Only known opaque upright planes enter this class. Recesses, thresholds
	# and decorative translucent shadows keep their existing presentation.
	if shape == null: return
	shape.set_meta(GROUND_META,ground_parent_local)
	shape.add_to_group(SOLID_GROUP)

static func _wall_bays(parent: Node2D, texture: Texture2D, run: Vector2, bottom: float, height: float, civic: bool) -> void:
	if texture == null or run.y-run.x < 12: return
	if run.y-run.x < 80:
		var infill := _panel(parent,Rect2(run.x,bottom-height,run.y-run.x,height),Color("9ca18f"))
		_register_solid(infill,Vector2((run.x+run.y)*0.5,bottom+16))
		return
	var region := Rect2(0,0,texture.get_width()*(0.39 if civic else 0.40),texture.get_height())
	var nominal := region.size.x/region.size.y*height
	var count := maxi(1,int(round((run.y-run.x)/nominal)))
	var width := (run.y-run.x)/count
	for index in count:
		var bay := Sprite2D.new()
		bay.name = "FootprintWallBay"
		bay.texture = texture
		bay.region_enabled = true
		bay.region_rect = region
		bay.centered = false
		bay.scale = Vector2(width/region.size.x,height/region.size.y)
		bay.position = Vector2(run.x+index*width,bottom-height)
		bay.set_meta(&"wall_span",Rect2(bay.position,Vector2(width,height)))
		parent.add_child(bay)
		FOREGROUND.register(bay,Vector2(bay.position.x+width*0.5,bottom+16))
