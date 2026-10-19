extends RefCounted
## Authoritative enclosed compound: roofed chambers around a connected court/hall.
## Coordinates stay in the caller's complete site space until streaming clips them.

const CARVE := preload("res://core/systems/world/proc/DonjonCarver.gd")

static func build(region: Rect2i, seed_value: int, entrance_cells: Array[Vector2i]) -> Dictionary:
	if mini(region.size.x,region.size.y) < 20: return _compact(region,seed_value,entrance_cells)
	var carve := CARVE.CarveResult.new()
	var depth := clampi(int(mini(region.size.x,region.size.y)*0.24),3,10)
	var top := Rect2i(region.position,Vector2i(region.size.x,depth))
	var bottom := Rect2i(Vector2i(region.position.x,region.end.y-depth),Vector2i(region.size.x,depth))
	var west := Rect2i(Vector2i(region.position.x,top.end.y),Vector2i(depth,region.size.y-depth*2))
	var court := Rect2i(Vector2i(west.end.x,top.end.y),Vector2i(region.end.x-west.end.x-1,bottom.position.y-top.end.y))
	var rooms: Array[Rect2i] = []
	var portals: Array[Vector2i] = []
	for x in range(region.position.x,region.end.x):
		carve.wall_cells[Vector2i(x,region.position.y)] = true
		carve.wall_cells[Vector2i(x,region.end.y-1)] = true
	for y in range(region.position.y,region.end.y):
		carve.wall_cells[Vector2i(region.position.x,y)] = true
		carve.wall_cells[Vector2i(region.end.x-1,y)] = true
	# Shared gallery walls define a court rather than disconnected maze fragments.
	for y: int in [top.end.y-1,bottom.position.y]:
		for x in range(west.end.x-1,region.end.x-1): carve.wall_cells[Vector2i(x,y)] = true
	for y in range(top.end.y-1,bottom.position.y+1): carve.wall_cells[Vector2i(west.end.x-1,y)] = true
	var bay_count := maxi(1,int((region.size.x-depth)/11.0))
	var width := region.size.x-depth-1
	for bay in range(bay_count):
		var x0 := west.end.x-1+int(float(width)*bay/bay_count)
		var x1 := west.end.x-1+int(float(width)*(bay+1)/bay_count)
		for north: bool in [true,false]:
			var y0 := region.position.y if north else bottom.position.y
			var room := Rect2i(x0+1,y0+1,maxi(1,x1-x0-1),depth-2)
			rooms.append(room)
			if bay > 0:
				for y in range(y0+1,y0+depth-1): carve.wall_cells[Vector2i(x0,y)] = true
			var door_x := clampi(x0+int((x1-x0)*0.5),x0+1,x1-1)
			var door_y := top.end.y-1 if north else bottom.position.y
			for shift in range(2):
				var p := Vector2i(door_x+shift,door_y)
				carve.wall_cells.erase(p)
				portals.append(p)
	var west_door := Vector2i(west.end.x-1,court.get_center().y)
	for shift in range(3):
		carve.wall_cells.erase(west_door+Vector2i(0,shift-1))
		portals.append(west_door+Vector2i(0,shift-1))
	# A connected hall/cell/service sequence in the west wing gives the compound
	# an indoor route as well as its court-facing chamber entrances.
	for section in range(3):
		var y0 := west.position.y+int(float(west.size.y)*section/3.0)
		var y1 := west.position.y+int(float(west.size.y)*(section+1)/3.0)
		rooms.append(Rect2i(west.position.x+1,y0+1,west.size.x-2,maxi(1,y1-y0-1)))
		if section > 0:
			var center_x := west.position.x+int(west.size.x*0.5)
			for x in range(west.position.x+1,west.end.x-1):
				if x not in [center_x-1,center_x]: carve.wall_cells[Vector2i(x,y0)] = true
			portals.append(Vector2i(center_x-1,y0))
			portals.append(Vector2i(center_x,y0))
	# The original actual opening always reaches the central usable court. Carve
	# the same two lanes all the way through any chamber boundary it intersects.
	_connect_entries(carve,region,entrance_cells,Vector2i(court.get_center()))
	for y in range(region.position.y+1,region.end.y-1):
		for x in range(region.position.x+1,region.end.x-1):
			var p := Vector2i(x,y)
			if not carve.wall_cells.has(p) and (x+y*3+absi(seed_value%19))%19 == 0:
				# Sparse original wall windows, never disconnected decoration blockers.
				var edge := Vector2i(x,region.position.y)
				if y == region.position.y+1 and carve.wall_cells.has(edge) and _far_from_entries(edge,entrance_cells,4): carve.window_cells[edge] = true
	carve.floor_stamps.append({"rect":region.grow(-1),"tex":3,"alpha":0.98,"z":-94})
	carve.floor_stamps.append({"rect":court,"tex":2,"alpha":0.78,"z":-93})
	# A few real cover cells belong to chamber corners, away from threshold lanes.
	for room: Rect2i in rooms:
		var p := room.position+Vector2i.ONE
		if room.has_point(p) and not carve.wall_cells.has(p) and _far_from_entries(p,entrance_cells,5) and _far_from_entries(p,portals,4):
			carve.half_cover_cells.append(p)
	var court_feature := Vector2i(-999,-999)
	if court.size.x >= 12 and court.size.y >= 8:
		court_feature = Vector2i(court.get_center())+Vector2i(3,1)
		carve.half_cover_cells.insert(0,court_feature)
	var accents: Array[Rect2i] = []
	if region.size.x >= 24 and region.size.y >= 24 and not entrance_cells.is_empty():
		var entry := entrance_cells[0]
		var along_y := entry.x in [region.position.x,region.end.x-1]
		for sign_value in [-1,1]:
			var center := entry+(Vector2i(0,sign_value*3) if along_y else Vector2i(sign_value*3,0))
			var accent := Rect2i(center-Vector2i(1,1),Vector2i(3,5)).intersection(region)
			if accent.size.x >= 2 and accent.size.y >= 3: accents.append(accent)
	return {"region":region,"carve":carve,"roofs":[top,bottom,west],"roof_accents":accents,"rooms":rooms,"court":court,"court_outdoor":true,"court_feature":court_feature,"entrance_cells":entrance_cells,"portals":portals,"seed":seed_value}

static func _compact(region: Rect2i, seed_value: int, entries: Array[Vector2i]) -> Dictionary:
	var carve := CARVE.CarveResult.new()
	var side_width := maxi(3,int(region.size.x*0.28))
	var west := Rect2i(region.position,Vector2i(side_width,region.size.y))
	var east := Rect2i(region.end.x-side_width,region.position.y,side_width,region.size.y)
	var middle := Rect2i(west.end.x,region.position.y,region.size.x-side_width*2,region.size.y)
	var hall := middle.intersection(region.grow(-1))
	var rooms: Array[Rect2i] = []
	var portals: Array[Vector2i] = []
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			if x in [region.position.x,region.end.x-1,west.end.x-1,east.position.x] or y in [region.position.y,region.end.y-1]: carve.wall_cells[Vector2i(x,y)] = true
	var sections := 2 if region.size.y >= 14 else 1
	for section in range(sections):
		var y0 := region.position.y+int(float(region.size.y-1)*section/sections)
		var y1 := region.position.y+int(float(region.size.y-1)*(section+1)/sections)
		for wing: Rect2i in [west,east]:
			var room := Rect2i(wing.position.x+1,y0+1,wing.size.x-2,maxi(1,y1-y0-1))
			rooms.append(room)
			if section > 0:
				for x in range(wing.position.x,wing.end.x): carve.wall_cells[Vector2i(x,y0)] = true
			var wall_x := west.end.x-1 if wing == west else east.position.x
			var door_y := clampi(room.get_center().y,room.position.y,room.end.y-1)
			for shift in range(2):
				var cell := Vector2i(wall_x,mini(door_y+shift,y1-1))
				carve.wall_cells.erase(cell)
				portals.append(cell)
	_connect_entries(carve,region,entries,Vector2i(hall.get_center()))
	carve.floor_stamps.append({"rect":region.grow(-1),"tex":3,"alpha":0.98,"z":-94})
	carve.floor_stamps.append({"rect":hall,"tex":2,"alpha":0.76,"z":-93})
	for room: Rect2i in rooms:
		var cell := room.position
		if room.size.x >= 2 and not carve.wall_cells.has(cell) and _far_from_entries(cell,entries,4) and _far_from_entries(cell,portals,3): carve.half_cover_cells.append(cell)
	return {"region":region,"carve":carve,"roofs":[west,east,middle],"roof_accents":[],"rooms":rooms,"court":hall,"court_outdoor":false,"court_feature":Vector2i(-999,-999),"entrance_cells":entries,"portals":portals,"seed":seed_value}

static func _connect_entries(carve: CARVE.CarveResult, region: Rect2i, entries: Array[Vector2i], center: Vector2i) -> void:
	for entry: Vector2i in entries:
		var at := entry
		var horizontal := entry.x in [region.position.x,region.end.x-1]
		while at != center:
			carve.wall_cells.erase(at)
			if horizontal and at.x != center.x: at.x += signi(center.x-at.x)
			elif at.y != center.y: at.y += signi(center.y-at.y)
			else: at.x += signi(center.x-at.x)
		carve.wall_cells.erase(center)
	for entry: Vector2i in entries: carve.wall_cells.erase(entry)

static func _far_from_entries(cell: Vector2i, entries: Array[Vector2i], distance: int) -> bool:
	for entry: Vector2i in entries:
		if absi(cell.x-entry.x)+absi(cell.y-entry.y) < distance: return false
	return true

static func fit_region(region: Rect2i, keepouts: Array[Rect2i]) -> Rect2i:
	# Maximum axis-aligned free rectangle. Side regions are at most one chunk,
	# so a bounded cell scan is cheap and avoids eroding an already-built shell.
	var best := Rect2i()
	for y0 in range(region.position.y,region.end.y-7):
		for x0 in range(region.position.x,region.end.x-7):
			var max_x := region.end.x
			for y1 in range(y0,region.end.y):
				for keepout: Rect2i in keepouts:
					if y1 >= keepout.position.y and y1 < keepout.end.y and keepout.end.x > x0:
						max_x = mini(max_x,maxi(x0,keepout.position.x))
				if max_x-x0 < 8: break
				var candidate := Rect2i(x0,y0,max_x-x0,y1-y0+1)
				if candidate.size.y >= 8 and candidate.get_area() > best.get_area(): best = candidate
	return best
