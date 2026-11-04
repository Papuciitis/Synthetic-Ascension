extends SceneTree
## Standalone data test: no scene, autoload, asset, or gameplay RNG dependency.

const SOURCE := "res://core/systems/world/ground/CityYardSupport.gd"
const CELL := 64
const N := 32
var passed := 0
var failed := 0
var planner: GDScript


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		print("FAIL: ", message)


func _spec() -> Dictionary:
	return {"footprint_px": PackedVector2Array([Vector2(512,512),Vector2(1152,512),Vector2(1152,1152),Vector2(512,1152)]),
		"doors":[{"pos":Vector2i(12,17),"dir":Vector2i.DOWN,"width":2}],
		"garden_contact_px":Vector2(512,1152),"visual_seed":944996572}


func _plan(spec: Dictionary, coord := Vector2i.ZERO, cell := CELL, n := N) -> PackedByteArray:
	return planner.plan(coord,spec,cell,n)


func _count(weights: PackedByteArray) -> int:
	var count := 0
	for value in weights:
		if value > 0:
			count += 1
	return count


func _shape(spec: Dictionary, label: String) -> void:
	var weights := _plan(spec)
	_check(weights.size() == N*N,label+": chunk-local byte field")
	var points := PackedVector2Array()
	var strong := 0
	var soft := 0
	var footprint_clear := true
	var garden_clear := true
	var near_corner := false
	var bounds := Rect2()
	for y in N:
		for x in N:
			var value := weights[y*N+x]
			if value == 0:
				continue
			var point := (Vector2(x,y)+Vector2(0.5,0.5))*CELL
			points.append(point)
			bounds = Rect2(Vector2(x,y),Vector2.ONE) if points.size() == 1 else bounds.expand(Vector2(x+1,y+1)).expand(Vector2(x,y))
			footprint_clear = footprint_clear and not Geometry2D.is_point_in_polygon(point,spec.footprint_px)
			garden_clear = garden_clear and point.distance_to(spec.garden_contact_px) > 3.0*CELL
			for corner: Vector2 in spec.footprint_px:
				near_corner = near_corner or point.distance_to(corner) < 1.5*CELL
			strong += int(value >= 96)
			soft += int(value > 0 and value < 96)
	_check(points.size() >= 8 and points.size() <= 80,label+": useful bounded patch")
	_check(strong >= 3 and soft >= 3,label+": soft falloff with a useful core")
	_check(points.size() < int(bounds.size.x*bounds.size.y),label+": outline is nonrectangular")
	_check(footprint_clear,label+": no indoor footprint coverage")
	_check(garden_clear,label+": planted contact remains clear")
	_check(near_corner,label+": patch meets actual corner surroundings")
	var shared_corner := false
	for corner: Vector2 in spec.footprint_px:
		var contains_all := true
		for point: Vector2 in points:
			contains_all = contains_all and point.distance_to(corner) <= CELL*5.0
		shared_corner = shared_corner or contains_all
	_check(shared_corner,label+": support stays near one corner, never a ring")


func _test_rotated_access() -> void:
	# Hand-derived cell rectangles, including the signed even-width correction:
	# UP at (15,8) protects x13..16/y4..8. Quarter-turns about pixel (832,832)
	# map cell (x,y) to (25-y,x), producing the three literal regions below.
	# The NE corner (18,8) and its patch centre lie beyond the UP corridor;
	# its ellipse still reaches that corridor, so candidate rejection cannot
	# substitute for the per-cell access veto being exercised here.
	var cases := [
		{"pos":Vector2i(15,8),"dir":Vector2i.UP,"region":Rect2i(13,4,4,5)},
		{"pos":Vector2i(17,15),"dir":Vector2i.RIGHT,"region":Rect2i(17,13,5,4)},
		{"pos":Vector2i(10,17),"dir":Vector2i.DOWN,"region":Rect2i(9,17,4,5)},
		{"pos":Vector2i(8,10),"dir":Vector2i.LEFT,"region":Rect2i(4,9,5,4)}]
	for quarter_turns in cases.size():
		var fixture := _spec()
		fixture.doors = []
		for turn in quarter_turns:
			var rotated := PackedVector2Array()
			for point: Vector2 in fixture.footprint_px:
				rotated.append(Vector2(1664-point.y,point.x))
			fixture.footprint_px = rotated
			var garden: Vector2 = fixture.garden_contact_px
			fixture.garden_contact_px = Vector2(1664-garden.y,garden.x)
		var record: Dictionary = cases[quarter_turns]
		var region: Rect2i = record.region
		var control := _plan(fixture)
		fixture.doors = [{"pos":record.pos,"dir":record.dir,"width":2}]
		var protected := _plan(fixture)
		var control_inside := 0
		var protected_inside := 0
		var useful_outside := 0
		for y in N:
			for x in N:
				if region.has_point(Vector2i(x,y)):
					control_inside += int(control[y*N+x] > 0)
					protected_inside += int(protected[y*N+x] > 0)
				else:
					useful_outside += int(protected[y*N+x] > 0)
		var label := "rotated access "+str(record.dir)
		_check(control_inside > 0,label+": no-door control reaches literal protected region")
		_check(useful_outside >= 8,label+": door-equipped patch keeps useful support outside approach")
		_check(protected_inside == 0,label+": per-cell clipping clears every protected cell")


func _run() -> void:
	_check(FileAccess.file_exists(SOURCE),"yard support helper exists")
	if not FileAccess.file_exists(SOURCE):
		_finish()
		return
	planner = load(SOURCE)
	_check(planner != null and planner.can_instantiate(),"yard support helper loads independently")
	if planner == null or not planner.can_instantiate():
		_finish()
		return
	_shape(_spec(),"rectangle")
	var notched := _spec()
	notched.footprint_px = PackedVector2Array([Vector2(512,768),Vector2(768,768),Vector2(768,512),Vector2(1152,512),Vector2(1152,1152),Vector2(512,1152)])
	_shape(notched,"concave footprint")
	var before := _spec()
	var snapshot := before.duplicate(true)
	seed(819273)
	var expected_rng := randi()
	seed(819273)
	var first := _plan(before,Vector2i(-7,-11))
	_check(randi() == expected_rng,"planner preserves global RNG state")
	_check(before == snapshot,"planner preserves nested input values")
	_check(first == _plan(before,Vector2i(-7,-11)),"negative chunk coordinates are deterministic")
	_check(_count(first) >= 8,"negative coordinates retain useful local support")
	var changed := false
	for value in range(1,9):
		var variant := _spec()
		variant.visual_seed = value
		changed = changed or _plan(variant) != _plan(before)
	_check(changed,"visual seed varies support")
	_test_rotated_access()
	for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
		var access := _spec()
		# Every vertex is blocked, so this fixture must reject every candidate.
		access.doors = []
		for pos: Vector2i in [Vector2i(8,8),Vector2i(18,8),Vector2i(18,18),Vector2i(8,18)]:
			access.doors.append({"pos":pos,"dir":direction,"width":2})
		var weights := _plan(access)
		_check(_count(weights) == 0,"doors at every corner reject all patch candidates: "+str(direction))
		var clear := true
		for door: Dictionary in access.doors:
			# Width two spans the door cell and the previous across cell.
			var across := Vector2i(-direction.y,direction.x)
			for outward in range(0,5):
				for offset in range(-2,2):
					var cell: Vector2i = door.pos+direction*outward+across*offset
					clear = clear and weights[cell.y*N+cell.x] == 0
		_check(clear,"signed doorway corridor stays clear: "+str(direction))
	# Practical side-centred entrances leave an unused corner available in every orientation.
	var side_doors := [
		{"pos":Vector2i(12,8),"dir":Vector2i.UP,"width":2},
		{"pos":Vector2i(17,12),"dir":Vector2i.RIGHT,"width":2},
		{"pos":Vector2i(12,17),"dir":Vector2i.DOWN,"width":2},
		{"pos":Vector2i(8,12),"dir":Vector2i.LEFT,"width":2}]
	for door: Dictionary in side_doors:
		var practical := _spec()
		practical.doors = [door]
		_check(_count(_plan(practical)) >= 8,"one practical entrance leaves a useful corner: "+str(door.dir))
	var reverse := _spec()
	var outline: PackedVector2Array = reverse.footprint_px
	outline.reverse()
	reverse.footprint_px = outline
	_shape(reverse,"reversed winding")
	for bad in [{},{"footprint_px":42},{"footprint_px":PackedVector2Array([Vector2.ZERO,Vector2.ONE])},
		{"footprint_px":PackedVector2Array([Vector2.ZERO,Vector2(64,0),Vector2(128,0)])},
		{"footprint_px":PackedVector2Array([Vector2(512,512),Vector2(1152,1152),Vector2(512,1152),Vector2(1152,512)])},
		{"footprint_px":PackedVector2Array([Vector2(512,512),Vector2(1152,512),Vector2(1152,512),Vector2(512,1152)])}]:
		var result := _plan(bad)
		_check(result.size() == N*N and _count(result) == 0,"invalid footprint yields zero: "+str(bad))
	for field in ["doors","garden_contact_px","visual_seed"]:
		var bad := _spec()
		bad[field] = "malformed"
		_check(_count(_plan(bad)) == 0,"malformed "+field+" yields zero")
	for bad_door in [{"pos":Vector2i.ZERO,"dir":Vector2i(1,1)},
		{"pos":Vector2i.ZERO,"dir":Vector2i.ZERO},
		{"pos":"wrong","dir":Vector2i.UP},
		{"pos":Vector2i.ZERO,"dir":Vector2i.UP,"width":1000000000},42]:
		var bad := _spec()
		bad.doors = [bad_door]
		_check(_count(_plan(bad)) == 0,"invalid access metadata fails closed: "+str(bad_door))
	for bad_point: Vector2 in [Vector2(INF,0),Vector2(NAN,0),Vector2(1e20,0)]:
		var bad := _spec()
		bad.footprint_px[0] = bad_point
		_check(_count(_plan(bad)) == 0,"nonfinite or extreme geometry fails closed: "+str(bad_point))
	var excessive := _spec()
	var too_many := PackedVector2Array()
	for i in 4096:
		too_many.append(Vector2(1000,1000)+Vector2.from_angle(float(i)*TAU/4096.0)*300.0)
	excessive.footprint_px = too_many
	_check(_count(_plan(excessive)) == 0,"excessive polygon vertex count is bounded")
	var no_garden := _spec()
	no_garden.erase("garden_contact_px")
	_check(_count(_plan(no_garden)) >= 8,"missing garden uses the actual southwest footprint corner")
	_check(_count(_plan(_spec(),Vector2i(2147483647,0))) == 0,"extreme chunk coordinates fail closed")
	for cell in [0,-1,2147483647]:
		_check(_count(_plan(_spec(),Vector2i.ZERO,cell)) == 0,"invalid cell dimension is bounded: "+str(cell))
	for n in [0,-1,2147483647]:
		_check(_plan(_spec(),Vector2i.ZERO,CELL,n).is_empty(),"invalid grid dimension cannot allocate: "+str(n))
	var outside := _spec()
	outside.footprint_px = PackedVector2Array([Vector2(10000,10000),Vector2(11000,10000),Vector2(11000,11000),Vector2(10000,11000)])
	_check(_count(_plan(outside)) == 0,"off-chunk footprint produces zero")
	_finish()


func _finish() -> void:
	print("CityYardSupportTest: ",passed," passed, ",failed," failed")
	quit(1 if failed else 0)
