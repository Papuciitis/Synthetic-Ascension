extends RefCounted
## Geometry around real cardinal openings; painted facades stay north-up.

const FOREGROUND := preload("res://core/systems/world/visibility/ForegroundSpriteCoverage.gd")
const SOLID_GROUP := &"foreground_solid_occluders"
const GROUND_META := &"foreground_ground_contact"
const DOMESTIC_PLASTER := preload("res://scenes/world/buildings/domestic_plaster.gdshader")

static func compose(kit: Node2D, doors: Array, cell_px: int, outline: PackedVector2Array, lantern_texture: Texture2D = null, portal_masonry: Texture2D = null) -> void:
	var group := Node2D.new()
	group.name = "CardinalWallReturns"
	group.set_meta(&"city_facade_detail", true)
	kit.add_child(group)
	var box: Rect2 = kit.get("bounds")
	var finish: Texture2D = kit.get("_facade") if Global.attempt_segment == 2 and not bool(kit.get("civic")) else null
	var domestic: bool = Global.attempt_segment == 2 and not bool(kit.get("civic")) and StringName(kit.get_meta(&"building_usage",&"")) == &"row_house"
	var plaster_material: ShaderMaterial
	if domestic and finish != null:
		plaster_material = ShaderMaterial.new()
		plaster_material.shader = DOMESTIC_PLASTER
		var size := finish.get_size()
		plaster_material.set_shader_parameter("source_rect",Vector4(size.x*0.335,size.y*0.30,size.x*0.038,size.y*0.36))
	if outline.is_empty():
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
				var bay_height := minf(height,144.0 if domestic else 112.0)
				if domestic:
					var window_run: Vector2 = run
					for door: Dictionary in doors:
						if door.dir != Vector2i.DOWN: continue
						var gap := _door_box(door,cell_px)
						if not is_equal_approx(gap.end.y,b.y): continue
						if is_equal_approx(window_run.y,gap.position.x): window_run.y -= 15.0
						if is_equal_approx(window_run.x,gap.end.x): window_run.x += 15.0
					_domestic_window_run(group,kit.get("_facade"),window_run,b.y-16,bay_height,plaster_material)
				else:
					_wall_bays(group,kit.get("_facade"),run,b.y-16,bay_height,bool(kit.get("civic")))
				if height > bay_height:
					var upper_finish := finish if finish != null else portal_masonry
					if domestic:
						_domestic_upper_field(group,upper_finish,run,b.y-16-height,height-bay_height,b.y,plaster_material,doors,cell_px)
					else:
						var upper := _panel(group,Rect2(run.x,b.y-16-height,run.y-run.x,height-112),Color.WHITE)
						if upper_finish != null: _plaster(upper,upper_finish,Color("b9b9a8"),plaster_material)
						_register_solid(upper,Vector2((run.x+run.y)*0.5,b.y))
	for door: Dictionary in doors:
		if door.dir == Vector2i.DOWN and outline.is_empty(): continue
		var gap := _door_box(door,cell_px)
		var entry := Node2D.new()
		entry.name = "CardinalDoorRecess"
		entry.set_meta(&"door_cells_px",gap)
		entry.set_meta(&"door_direction",door.dir)
		group.add_child(entry)
		var dir: Vector2i = door.dir
		if not outline.is_empty() and dir == Vector2i.DOWN:
			_upright_irregular_portal(entry,gap,float(kit.get("_facade_height")),portal_masonry,domestic,plaster_material)
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
	var opening_height := minf(height,128.0) if domestic else height
	var opening_top := bottom-opening_height
	portal.set_meta(&"opening_face",Rect2(left,opening_top,gap.size.x,opening_height))
	var recess := _panel(portal,Rect2(left,opening_top,gap.size.x,opening_height),Color.WHITE)
	recess.name = "Recess"
	recess.vertex_colors = PackedColorArray([Color("1d2c2e"),Color("1d2c2e"),Color("42514a"),Color("374840")])
	var supported_header: bool = domestic and opening_top > top
	var lintel_height := minf(14.0,opening_top-top) if supported_header else 14.0
	if supported_header and opening_top-lintel_height > top:
		var header := _panel(portal,Rect2(left,top,gap.size.x,opening_top-lintel_height-top),Color("b9b9a8"))
		header.name = "DomesticDoorHeader"
		if facade != null: _plaster(header,facade,Color("b9b9a8"),plaster_material)
		_register_solid(header,Vector2((left+right)*0.5,gap.end.y))
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
	_panel(portal,Rect2(left,opening_top if domestic else top+22,gap.size.x,7),Color("263b39"))
	# A short, flush floor transition is distinct from the upright recess;
	# there is no door leaf, raised step, collision or change to entry width.
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
		_masonry(timber,facade,Rect2(920,217,11,420))
		_register_solid(timber,ground)

static func _masonry(shape: Polygon2D, texture: Texture2D, source: Rect2) -> void:
	shape.texture = texture
	shape.uv = PackedVector2Array([source.position,Vector2(source.end.x,source.position.y),source.end,Vector2(source.position.x,source.end.y)])
	shape.color = Color.WHITE

static func _plaster(shape: Polygon2D, texture: Texture2D, tint: Color, material: ShaderMaterial = null) -> void:
	# Plain field beside the existing shutter bay; no additional windows or
	# stretched ornament. Shared quiet material retains a broad limewash plane.
	_masonry(shape,texture,Rect2(texture.get_size()*Vector2(0.335,0.30),texture.get_size()*Vector2(0.038,0.36)))
	shape.color = tint
	if material != null:
		var uv := PackedVector2Array()
		for point: Vector2 in shape.polygon:
			uv.append(point*2.0)
		shape.uv = uv
		shape.material = material

static func _domestic_upper_field(parent: Node2D, texture: Texture2D, run: Vector2, top: float, height: float, ground_y: float, material: ShaderMaterial, doors: Array, cell_px: int) -> void:
	# One short continuous head course belongs to the taller window bays.
	# No repeated little upper panels or fake vertical joints. Existing jambs
	# still replace their field area so fractional roof fades composite once.
	var jambs: Array[Rect2] = []
	for door: Dictionary in doors:
		if door.dir != Vector2i.DOWN: continue
		var gap := _door_box(door,cell_px)
		if not is_equal_approx(gap.end.y,ground_y): continue
		# Match the existing portal's actual15px jamb and8px top setback.
		jambs.append(Rect2(gap.position.x-15,top+8,15,height))
		jambs.append(Rect2(gap.end.x,top+8,15,height))
	var pieces: Array[Rect2] = [Rect2(run.x,top,run.y-run.x,height)]
	for jamb: Rect2 in jambs:
		var next: Array[Rect2] = []
		for piece: Rect2 in pieces:
			next.append_array(_subtract_rect(piece,jamb))
		pieces = next
	for piece: Rect2 in pieces:
		var field := _panel(parent,piece,Color("b9b9a8"))
		if field == null: continue
		if texture != null: _plaster(field,texture,Color("b9b9a8"),material)
		field.set_meta(&"domestic_upper_run" if is_equal_approx(piece.size.y,height) else &"domestic_upper_jamb_cap",Rect2(run.x,top,run.y-run.x,height))
		_register_solid(field,Vector2((run.x+run.y)*0.5,ground_y))

static func _domestic_window_run(parent: Node2D, texture: Texture2D, run: Vector2, bottom: float, height: float, material: ShaderMaterial) -> void:
	if texture == null: return
	var nominal := texture.get_width()*0.40/texture.get_height()*height
	var width := run.y-run.x
	# A narrow wing gets one proportionate window with quiet side plaster,
	# rather than stretching it to fill the wing or repeating squeezed shutters.
	if int(round(width/nominal)) == 1 and width > nominal*1.25:
		var margin := (width-nominal)*0.5
		for x: float in [run.x,run.y-margin]:
			var field := _panel(parent,Rect2(x,bottom-height,margin,height),Color.WHITE)
			_plaster(field,texture,Color("b9b9a8"),material)
			_register_solid(field,Vector2(x+margin*0.5,bottom+16))
		_wall_bays(parent,texture,Vector2(run.x+margin,run.y-margin),bottom,height,false)
	else:
		_wall_bays(parent,texture,run,bottom,height,false)

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
