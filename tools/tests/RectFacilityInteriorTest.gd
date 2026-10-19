extends Node

var _passes := 0
var _failures := 0

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok: _passes += 1
	else:
		_failures += 1
		push_error(message)

func _run() -> void:
	# An 8x7 parcel cannot fit two 4x4 rooms with padding. Its single-room
	# fallback must use the parcel envelope, rather than enclose it again.
	var region := Rect2i(9,2,8,7)
	var cases: Array[Dictionary] = [
		{"dir":Vector2i.UP,"pos":Vector2i(13,2),"gap":[Vector2i(12,2),Vector2i(13,2)]},
		{"dir":Vector2i.RIGHT,"pos":Vector2i(16,5),"gap":[Vector2i(16,4),Vector2i(16,5)]},
		{"dir":Vector2i.DOWN,"pos":Vector2i(13,8),"gap":[Vector2i(14,8),Vector2i(13,8)]},
		{"dir":Vector2i.LEFT,"pos":Vector2i(9,5),"gap":[Vector2i(9,6),Vector2i(9,5)]},
	]
	for sample: Dictionary in cases:
		var direction: Vector2i = sample.dir
		var position: Vector2i = sample.pos
		var entrances: Array[Dictionary] = [{"pos":position,"dir":direction,"width":2}]
		var rng := RandomNumberGenerator.new()
		rng.seed = 211
		var result := RectFacilityCarver.carve_room_first(region,rng,10,Vector2i(4,4),Vector2i(6,5),1,1,0.0,entrances,4,2)
		var inner := region.grow(-1)
		var redundant: Array[Vector2i] = []
		for cell: Vector2i in result.wall_cells:
			if inner.has_point(cell): redundant.append(cell)
		_check(redundant.is_empty(),"Single-room fallback must not add an inner enclosing shell dir=%s cells=%s" % [direction,redundant])
		var door_cells: Array = sample.gap
		for y in range(region.position.y,region.end.y):
			for x in range(region.position.x,region.end.x):
				var cell := Vector2i(x,y)
				if not inner.has_point(cell):
					_check(result.wall_cells.has(cell) != door_cells.has(cell),"Fallback preserves the exact outer envelope and real door at %s" % cell)
		for cell: Vector2i in result.half_cover_cells:
			_check(not result.wall_cells.has(cell),"Cover never overlaps a wall")
			_check(inner.has_point(cell) and not door_cells.has(cell+direction),"Fallback cover keeps the actual door and inner approach clear at %s" % cell)
		print("Fallback cells dir=%s walls=%s" % [direction,result.wall_cells.keys()])
	# A larger, successful multi-room carve must keep its physical partitions.
	var large_rng := RandomNumberGenerator.new()
	large_rng.seed = 17
	var large_region := Rect2i(2,2,24,20)
	var large_entries: Array[Dictionary] = [{"pos":Vector2i(14,21),"dir":Vector2i.DOWN,"width":2}]
	var large := RectFacilityCarver.carve_room_first(large_region,large_rng,24,Vector2i(4,4),Vector2i(8,7),1,1,0.0,large_entries,4,2)
	var partition_cells := 0
	for cell: Vector2i in large.wall_cells:
		if large_region.grow(-1).has_point(cell): partition_cells += 1
	var room_stamps := 0
	for stamp: Dictionary in large.floor_stamps:
		if int(stamp.tex) == 4: room_stamps += 1
	_check(room_stamps >= 3,"Large fixture exercises successful room placement rather than fallback")
	_check(partition_cells > 0,"Successful multi-room layouts keep real interior partitions")
	var signature := str([large.wall_cells.keys(),large.window_cells.keys(),large.floor_stamps,large.half_cover_cells,large_rng.state]).sha256_text()
	_check(signature == "7869acf9e414d40487334a74d234f11f3d52a7d48b2fc2d13f9b3ae8601354c7","Successful multi-room output and RNG remain equal to the pre-repair baseline")
	print("Multi-room baseline: rooms=%d partitions=%d signature=%s" % [room_stamps,partition_cells,signature])
	# Same production plans used by the independently captured 2x2/2x1 sites.
	var manager := ChunkManager.new()
	manager.world_seed = 436524753
	var overlay := SiteOverlayImpl.new()
	var site_baselines := {Vector2i(-16,-22):"b6bd7c08b71256b66fa63221e843111c1354c53dff4fbef016cef8162b0eafdc",Vector2i(-14,-22):"180742beba38c2ec6354cebaba537dad5ebb56272aff6b2a0634065da3b36c31"}
	for root: Vector2i in [Vector2i(-16,-22),Vector2i(-14,-22)]:
		var site := overlay._get_plan(root,manager,{"site_padding_cells":2,"dungeon_architecture":false})
		var carve := site.carve
		var site_signature := str([site.site_seed,site.region,site.size_chunks,site.door_pos,site.door_width,carve.wall_cells.keys(),carve.window_cells.keys(),carve.floor_stamps,carve.half_cover_cells]).sha256_text()
		_check(site_signature == site_baselines[root],"Captured actual facility retains its full pre-repair output at %s" % root)
		print("Actual facility baseline: root=%s walls=%d signature=%s" % [root,carve.wall_cells.size(),site_signature])
	manager.free()
	print("RectFacilityInteriorTest: %d passed, %d failed" % [_passes,_failures])
	get_tree().quit(1 if _failures > 0 else 0)
