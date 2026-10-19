extends RefCounted
## Geometry around real cardinal openings; painted facades stay north-up.

static func compose(kit: Node2D, doors: Array, cell_px: int, outline: PackedVector2Array, lantern_texture: Texture2D = null, portal_masonry: Texture2D = null) -> void:
	var group := Node2D.new()
	group.name = "CardinalWallReturns"
	group.set_meta(&"city_facade_detail", true)
	kit.add_child(group)
	var box: Rect2 = kit.get("bounds")
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
				_panel(group,Rect2(x-7,run.x,14,run.y-run.x),Color("57635f") if dir.x < 0 else Color("92998a"))
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
				_wall_bays(group,kit.get("_facade"),run,b.y-16,112,bool(kit.get("civic")))
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
			_upright_irregular_portal(entry,gap,float(kit.get("_facade_height")),portal_masonry)
			continue
		# These are contact/soffit planes within the actual carved opening,
		# never a rotated south-facing image or a new collision shape.
		_panel(entry,gap.grow(-6),Color(0.12,0.19,0.20,0.38))
		if dir.x != 0:
			var x := gap.end.x-12 if dir.x > 0 else gap.position.x+12
			_panel(entry,Rect2(x-9,gap.position.y+4,18,12),Color("9ca28f"))
			_panel(entry,Rect2(x-9,gap.end.y-16,18,12),Color("768174"))
			_panel(entry,Rect2(gap.position.x+8,gap.position.y+16,6,gap.size.y-32),Color(0.15,0.22,0.23,0.5))
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

static func _upright_irregular_portal(parent: Node2D, gap: Rect2, height: float, facade: Texture2D) -> void:
	var portal := Node2D.new()
	portal.name = "IrregularUprightPortal"
	parent.add_child(portal)
	# Same wall baseline/height as its neighboring footprint bays. The jambs
	# stand on the adjacent wall, outside the carver's complete opening span.
	var bottom := gap.end.y-16.0
	var top := bottom-height
	var left := gap.position.x
	var right := gap.end.x
	portal.set_meta(&"opening_face",Rect2(left,top,gap.size.x,height))
	var recess := _panel(portal,Rect2(left,top,gap.size.x,height),Color.WHITE)
	recess.name = "Recess"
	recess.vertex_colors = PackedColorArray([Color("1d2c2e"),Color("1d2c2e"),Color("42514a"),Color("374840")])
	var left_jamb := _panel(portal,Rect2(left-15,top+8,15,height-8),Color("8c9585"))
	left_jamb.name = "LeftJamb"
	var right_jamb := _panel(portal,Rect2(right,top+8,15,height-8),Color("b0af96"))
	right_jamb.name = "RightJamb"
	var lintel := _panel(portal,Rect2(left-15,top+8,gap.size.x+30,14),Color("b0b19c"))
	lintel.name = "Lintel"
	# Crop only the original entrance's masonry components, without a door
	# leaf or surrounding window bays. The shared roof still owns the eave.
	if facade != null:
		var size := facade.get_size()
		_masonry(left_jamb,facade,Rect2(size*Vector2(0.391,0.29),size*Vector2(0.034,0.63)))
		_masonry(right_jamb,facade,Rect2(size*Vector2(0.575,0.29),size*Vector2(0.034,0.63)))
		_masonry(lintel,facade,Rect2(size*Vector2(0.391,0.205),size*Vector2(0.218,0.085)))
	_panel(portal,Rect2(left,top+22,gap.size.x,7),Color("263b39"))
	# A short, flush floor transition is distinct from the upright recess;
	# there is no door leaf, raised step, collision or change to entry width.
	var threshold := _panel(portal,Rect2(left,bottom-10,gap.size.x,14),Color.WHITE)
	threshold.name = "FlushThreshold"
	threshold.vertex_colors = PackedColorArray([Color("657367"),Color("657367"),Color("949b89"),Color("949b89")])
	_panel(portal,Rect2(left,bottom+4,gap.size.x,2),Color(0.19,0.27,0.25,0.35))

static func _masonry(shape: Polygon2D, texture: Texture2D, source: Rect2) -> void:
	shape.texture = texture
	shape.uv = PackedVector2Array([source.position,Vector2(source.end.x,source.position.y),source.end,Vector2(source.position.x,source.end.y)])
	shape.color = Color.WHITE

static func _panel(parent: Node2D, rect: Rect2, color: Color) -> Polygon2D:
	if not rect.has_area(): return null
	var shape := Polygon2D.new()
	shape.polygon = PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	shape.color = color
	parent.add_child(shape)
	return shape

static func _wall_bays(parent: Node2D, texture: Texture2D, run: Vector2, bottom: float, height: float, civic: bool) -> void:
	if texture == null or run.y-run.x < 12: return
	if run.y-run.x < 80:
		_panel(parent,Rect2(run.x,bottom-height,run.y-run.x,height),Color("9ca18f"))
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
