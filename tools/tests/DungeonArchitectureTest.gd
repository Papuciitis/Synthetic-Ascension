extends Node

var passed := 0
var failed := 0
const PATH := "res://core/systems/world/proc/DungeonLayout.gd"

func _check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		if failed < 12: push_error(message)

func _ready() -> void:
	if not ResourceLoader.exists(PATH):
		_check(false,"Recognizable enclosed dungeon layout is not implemented")
		_finish()
		return
	var layout = load(PATH)
	for size: Vector2i in [Vector2i(60,28),Vector2i(28,60),Vector2i(60,60),Vector2i(28,28),Vector2i(10,12),Vector2i(15,10),Vector2i(8,8),Vector2i(9,9)]:
		for side in range(4):
			var region := Rect2i(Vector2i(2,2),size)
			var outward: Vector2i = [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][side]
			var first := Vector2i(region.get_center())
			if outward.x != 0: first.x = region.position.x if outward.x < 0 else region.end.x-1
			else: first.y = region.position.y if outward.y < 0 else region.end.y-1
			var doors: Array[Vector2i] = [first,first+(Vector2i.DOWN if outward.x != 0 else Vector2i.RIGHT)]
			var plan: Dictionary = layout.build(region,7149,doors)
			var again: Dictionary = layout.build(region,7149,doors)
			_check(_signature(plan) == _signature(again),"Dungeon topology and presentation metadata deterministic")
			var walls: Dictionary = plan.carve.wall_cells
			for y in range(region.position.y,region.end.y):
				for x in range(region.position.x,region.end.x):
					var p := Vector2i(x,y)
					if x in [region.position.x,region.end.x-1] or y in [region.position.y,region.end.y-1]:
						_check(walls.has(p) != doors.has(p),"Complete envelope except the actual declared doorway")
			var seen := {doors[0]:true}
			var queue: Array[Vector2i] = [doors[0]]
			var cursor := 0
			while cursor < queue.size():
				var cell := queue[cursor]
				cursor += 1
				for dir: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
					var next := cell+dir
					if region.has_point(next) and not walls.has(next) and not seen.has(next):
						seen[next] = true
						queue.append(next)
			for y in range(region.position.y+1,region.end.y-1):
				for x in range(region.position.x+1,region.end.x-1):
					var p := Vector2i(x,y)
					_check(walls.has(p) or seen.has(p),"Every usable interior cell connects to actual entrance")
			_check(plan.roofs.size() == 3,"Three coherent roof wings, not one slab or cloned small houses")
			_check(plan.court.has_area(),"Open court or hall has intentional extent")
			if mini(size.x,size.y) < 20: _check(not plan.get("court_outdoor",true),"Compact Donjons use an enclosed central hall, not a miniature outdoor courtyard")
			else:
				var west_rooms := 0
				for room: Rect2i in plan.rooms:
					if plan.roofs[2].encloses(room): west_rooms += 1
				_check(west_rooms >= 3,"Large west wing has a connected hall/cell/service sequence")
			for roof: Rect2i in plan.roofs:
				_check(region.encloses(roof),"Roof footprint remains inside actual building")
			for cell: Vector2i in plan.carve.half_cover_cells:
				_check(seen.has(cell) and not walls.has(cell),"Cover rests on connected floor")
	var region := Rect2i(2,2,15,28)
	var protected: Array[Rect2i] = [Rect2i(0,13,32,5),Rect2i(14,0,4,32)]
	var fitted: Rect2i = layout.fit_region(region,protected)
	_check(region.encloses(fitted) and fitted.size.x >= 8 and fitted.size.y >= 8,"Compact enclosure fits actual protected-space remainder")
	for keepout: Rect2i in protected: _check(not fitted.intersects(keepout),"Dungeon envelope/roof/indoor ownership exclude street access")
	var all_blocked: Array[Rect2i] = [region]
	_check(not layout.fit_region(region,all_blocked).has_area(),"Fully protected region explicitly cannot receive an enclosure")
	var manager := ChunkManager.new()
	manager.world_seed = 436524753
	var overlay := SiteOverlayImpl.new()
	for root: Vector2i in [Vector2i(-16,-22),Vector2i(-14,-22),Vector2i(-24,-16)]:
		var site := overlay._get_plan(root,manager,{"site_padding_cells":2})
		_check(site.get("architecture") != null,"Actual production site carries authoritative architecture metadata")
	manager.free()
	_check(ResourceLoader.exists("res://scenes/world/buildings/DungeonBuilding.gd"),"Dungeon has streamed roof and entrance presentation")
	_finish()

func _finish() -> void:
	print("DungeonArchitectureTest: %d passed, %d failed" % [passed,failed])
	get_tree().quit(1 if failed else 0)

func _signature(plan: Dictionary) -> String:
	var carve = plan.carve
	return str([carve.wall_cells,carve.window_cells,carve.floor_stamps,carve.half_cover_cells,plan.roofs,plan.rooms,plan.court,plan.entrance_cells,plan.portals,plan.get("roof_accents"),plan.get("court_feature")])
