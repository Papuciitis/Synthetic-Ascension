extends Node2D

const OVERLAY := preload("res://core/systems/world/proc/SiteOverlayImpl.gd")
const WALL := preload("res://scenes/world/cover/CoverFull.tscn")
const WINDOW := preload("res://scenes/world/cover/CoverWindow.tscn")
const HALF := preload("res://scenes/world/cover/CoverHalf.tscn")
var passed := 0
var failed := 0

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		if failed <= 12: push_error(message)

func _plan(size_chunks: Vector2i):
	var plan := OVERLAY.SitePlan.new()
	plan.root_chunk = Vector2i.ZERO
	plan.size_chunks = size_chunks
	plan.site_seed = 17211
	plan.region = Rect2i(Vector2i(2,2),size_chunks*32-Vector2i(4,4))
	plan.door_side = 0
	plan.door_pos = Vector2i(6,2)
	plan.door_width = 2
	plan.carve = DonjonCarver.CarveResult.new()
	for y in range(plan.region.position.y,plan.region.end.y):
		for x in range(plan.region.position.x,plan.region.end.x):
			if x == 2 or y == 2 or x == plan.region.end.x-1 or y == plan.region.end.y-1:
				plan.carve.wall_cells[Vector2i(x,y)] = true
	# Deliberate room divider crosses the vertical streamed boundary; a second
	# one crosses the horizontal boundary. Their openings remain real doors.
	for x in range(3,plan.region.end.x-1):
		if x not in [12,13]: plan.carve.wall_cells[Vector2i(x,16)] = true
	for y in range(3,plan.region.end.y-1):
		if y not in [20,21]: plan.carve.wall_cells[Vector2i(18,y)] = true
	for x in [6,7]: plan.carve.wall_cells.erase(Vector2i(x,2))
	for cell: Vector2i in [Vector2i(31,16),Vector2i(18,31)]:
		if plan.carve.wall_cells.has(cell): plan.carve.window_cells[cell] = true
	return plan

func _mask(cell: Vector2i, walls: Dictionary) -> int:
	var result := 0
	for index in range(4):
		if walls.has(cell+[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][index]): result |= 1<<index
	return result

func _slice(overlay, plan, coord: Vector2i) -> Dictionary:
	var manager := ChunkManager.new()
	manager.generation_enabled = false
	manager.ground_enabled = false
	manager.ground_splat_enabled = false
	manager.decals_enabled = false
	manager.deco_enabled = false
	manager.sites_enabled = false
	manager.cover_full_scene = WALL
	manager.cover_window_scene = WINDOW
	manager.cover_half_scene = HALF
	add_child(manager)
	manager._gen_coord = coord
	manager._chunk_blocked[coord] = []
	manager._active_build_data = ChunkBuildData.new(coord,32)
	var chunk := Node2D.new()
	chunk.position = Vector2(coord)*2048
	manager.add_child(chunk)
	_check(overlay.decorate_chunk(manager,chunk,coord,{"anchor_spacing":2,"anchor_chance":1.0,"max_site_chunks_x":2,"max_site_chunks_y":2}),"cached authoritative site decorates every intended streamed slice")
	var actual: Dictionary = {}
	var data: ChunkBuildData = manager._active_build_data
	var wall_rects := ChunkBlockPhysics.rectangles_for_kind(data,WorldBlockerGeometry.Kind.WALL,64)
	var window_rects := ChunkBlockPhysics.rectangles_for_kind(data,WorldBlockerGeometry.Kind.WINDOW,64)
	for y in range(32):
		for x in range(32):
			var local := Vector2i(x,y)
			var site := coord*32+local
			var exists: bool = plan.carve.wall_cells.has(site)
			_check((data.kind_at(local)>=0) == exists,"streamed site wall cells must equal complete plan; no trimmed jambs or boundary endpoints: "+str(site))
			if not exists: continue
			_check(data.mask_at(local) == _mask(site,plan.carve.wall_cells),"streamed wall retains complete-plan connection arms across chunk seam: "+str(site))
			var expected := WorldBlockerGeometry.Kind.WINDOW if plan.carve.window_cells.has(site) else WorldBlockerGeometry.Kind.WALL
			_check(data.kind_at(local) == expected,"window classification survives site slicing")
			_check((data.variant_at(local)&ChunkBlockVisualCatalog.VARIANT_BUILDING_ENVELOPE) != 0,"intact facility walls cannot select random broken ruin or raised-pier art")
			for index in range(4):
				var dir: Vector2i = [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][index]
				var neighbor := local+dir
				if Rect2i(0,0,32,32).has_point(neighbor) or not plan.carve.wall_cells.has(site+dir): continue
				var probe := (Vector2(local)+Vector2(0.5,0.5))*64+Vector2(dir)*31.5
				var covered := false
				for rect: Rect2 in wall_rects+window_rects:
					if rect.has_point(probe): covered = true
				_check(covered,"actual merged wall/window collider reaches shared boundary without a half-cell hole")
			actual[site] = WorldBlockerGeometry.pack(data.kind_at(local),data.mask_at(local))
	var volumes := 0
	for child: Node in chunk.get_children():
		if child is IndoorVolume:
			volumes += 1
			_check(child.building_id == plan.site_seed,"site slices keep one shared reward identity")
	_check(volumes == 1,"one indoor volume per nonempty streamed site slice")
	manager.free()
	return actual

func _run() -> void:
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	var writes_before := SaveManager.debug_save_writes
	for dimensions: Vector2i in [Vector2i(2,1),Vector2i(1,2),Vector2i(2,2)]:
		var overlay := OVERLAY.new()
		var plan = _plan(dimensions)
		overlay._cache[Vector2i.ZERO] = plan
		var coordinates: Array[Vector2i] = []
		for y in range(dimensions.y):
			for x in range(dimensions.x): coordinates.append(Vector2i(x,y))
		var baseline: Dictionary = {}
		for coord: Vector2i in coordinates: baseline[coord] = _slice(overlay,plan,coord)
		coordinates.reverse()
		for coord: Vector2i in coordinates:
			_check(_slice(overlay,plan,coord) == baseline[coord],"reverse load/reload order preserves site cells, windows and physical connections")
	_check(SaveManager.debug_save_writes == writes_before,"continuity check does not write a profile")
	print("SiteWallContinuityTest: %d passed, %d failed; 2x1/1x2/2x2 sites, normal/reverse reload order" % [passed,failed])
	get_tree().quit(1 if failed else 0)
