extends RefCounted
## One guard-office family fitted to existing parcel/door data. The plan is
## presentation-only; it owns no blocks, rooms, rewards or random state.

static func plan(footprint_px: PackedVector2Array, roof_support_px: PackedVector2Array, doors: Array, cell_px: int, visual_seed: int) -> Dictionary:
	var result := {
		"arch_bays": [], "entry_recesses": [], "roof_planes": [],
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
		for entry: Dictionary in result.entry_recesses:
			var gap: Rect2 = entry.opening
			if entry.door.dir != Vector2i.DOWN or not is_equal_approx(gap.end.y,a.y): continue
			var remaining: Array[Vector2] = []
			for run: Vector2 in runs:
				if run.x < gap.position.x-pier: remaining.append(Vector2(run.x,minf(run.y,gap.position.x-pier)))
				if run.y > gap.end.x+pier: remaining.append(Vector2(maxf(run.x,gap.end.x+pier),run.y))
			runs = remaining
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
			result.roof_planes.append({"kind":&"guard_watch","polygon":watch_support.duplicate(),"lift":96.0*scale_value,"support":watch_support.duplicate()})
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
