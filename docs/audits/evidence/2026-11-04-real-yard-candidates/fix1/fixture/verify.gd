extends SceneTree
# METHOD EXTRACTION ONLY: verbatim source-pinned _mix_seed, not a manager implementation.
const CARVER = preload("res://core/systems/world/proc/RectFacilityCarver.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		print("FAIL: " + label)

func cells(values: Array) -> Array:
	var out: Array = []
	for v: Vector2i in values: out.append([v.x,v.y])
	out.sort_custom(func(a: Array,b: Array) -> bool: return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0]))
	return out

func rect_array(r: Rect2i) -> Array:
	return [r.position.x,r.position.y,r.size.x,r.size.y]

func _initialize() -> void:
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://observed-inputs.json"))
	var output: Dictionary = {"observed_historical":input,"derived_verified":[],"missing_fields":{"garden_contact":"unknown; no kit created","care_spec":"unknown; no kit created","semantic_and_care_bytes":"unknown; no ground planner created","native_game":"pending; no Game, district regeneration or activated target"},"method":"verbatim _mix_seed extraction plus actual unchanged RectFacilityCarver/DonjonCarver"}
	var coord := Vector2i(-8,-4)
	var index: int = 0
	for c: Dictionary in input.candidates:
		var b: Dictionary = c.observed_historical
		var r := Rect2i(int(b.rect[0]),int(b.rect[1]),int(b.rect[2]),int(b.rect[3]))
		var tl: Vector2i = coord * 32 + r.grow(-1).position
		var mixed: int = _mix_seed(int(input.theme.plan_seed),tl.x,tl.y,77)
		var ident: int = int(mixed & 0x7fffffff) + 1
		var variant: int = absi(ident) % 4
		check(ident == int(c.host_expected_id),"signed64 id " + str(index))
		check(variant == int(c.host_expected_variant),"variant " + str(index))
		var row: Dictionary = {"rect":b.rect,"global_interior_tl_cells":[tl.x,tl.y],"signed64_mixed":str(mixed),"visual_seed":ident,"variant":variant,"care_eligibility_from_id_only":variant != 3,"footprint_before_roof_inset_px":[[r.position.x*64,r.position.y*64],[r.end.x*64,r.position.y*64],[r.end.x*64,r.end.y*64],[r.position.x*64,r.end.y*64]],"carve":"omitted for third candidate"}
		if index < 2:
			var d: Array = b.doors[0]
			var pos := Vector2i(int(d[0]),int(d[1]))
			var direction := Vector2i(int(d[2]),int(d[3]))
			var entrances: Array[Dictionary] = [{"pos":pos,"dir":direction,"width":2}]
			var rng := RandomNumberGenerator.new()
			var carve_seed: int = _mix_seed(int(input.theme.plan_seed),coord.x,coord.y,4027 + r.position.x*19 + r.position.y*23)
			rng.seed = carve_seed
			var max_room := Vector2i(maxi(5,mini(9,r.size.x-2)),maxi(5,mini(8,r.size.y-2)))
			var carve = CARVER.carve_room_first(r,rng,12,Vector2i(4,4),max_room,1,1,0.22,entrances,2,2)
			var door_cells: Dictionary = CARVER._collect_door_cells(r,entrances)
			check(door_cells.size() == 2,"derived door width " + str(index))
			var doors_open: bool = true
			for p: Vector2i in door_cells:
				if carve.wall_cells.has(p): doors_open = false
			check(doors_open,"source door cells open " + str(index))
			var walls_bounded: bool = true
			var partitions: Array = []
			for p: Vector2i in carve.wall_cells:
				if not r.has_point(p): walls_bounded = false
				if r.grow(-1).has_point(p): partitions.append(p)
			check(walls_bounded,"returned walls bounded " + str(index))
			var perimeter_closed: bool = true
			for y: int in range(r.position.y,r.end.y):
				for x: int in range(r.position.x,r.end.x):
					var p := Vector2i(x,y)
					if (x == r.position.x or x == r.end.x-1 or y == r.position.y or y == r.end.y-1) and not door_cells.has(p) and not carve.wall_cells.has(p): perimeter_closed = false
			check(perimeter_closed,"perimeter except doors " + str(index))
			var stamps: Array = []
			for stamp: Dictionary in carve.floor_stamps:
				stamps.append({"rect":rect_array(stamp.rect),"tex":stamp.tex,"alpha":stamp.alpha,"z":stamp.z})
			row.carve = {"classification":"current actual source geometry replay; normal width2 DERIVED, not historically observed","source_parameters":{"rng_seed_signed64":str(carve_seed),"room_attempts":12,"room_min":[4,4],"room_max":[max_room.x,max_room.y],"room_padding":1,"corridor_width":1,"window_chance":0.22,"door_width":2,"floor_room_tex":2,"floor_corr_tex":2},"door_cells":cells(door_cells.keys()),"wall_cells":cells(carve.wall_cells.keys()),"window_cells":cells(carve.window_cells.keys()),"partition_cells":cells(partitions),"floor_stamps":stamps,"half_cover_cells":cells(carve.half_cover_cells),"rng_state_after_signed64":str(rng.state)}
		output.derived_verified.append(row)
		index += 1
	output["passed"] = passed
	output["failed"] = failed
	var file := FileAccess.open("res://derived-results.json",FileAccess.WRITE)
	if file == null:
		print("FAIL: unable to write derived results")
		quit(1)
		return
	file.store_string(JSON.stringify(output,"  "))
	file.close()
	print("RealCandidateVerify: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)

func _mix_seed(a: int, b: int, c: int, d: int) -> int:
	var x: int = a * 1103515245 + 12345
	x = int(x ^ (b * 374761393))
	x = int(x ^ (c * 668265263))
	x = int(x ^ (d * 2246822519))
	x = int((x ^ (x >> 13)) * 1274126177)
	x = int(x ^ (x >> 16))
	return x
