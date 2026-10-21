extends Node2D
## Live-transform contract of the indexed shared cover (phase-1 lead review,
## 21 October 2026). The view index must never change what is covered: an
## occluder whose geometry changes while outside the view is covered on the
## very next refresh, exactly as an uncached provider sees it. Cases: a roof
## form below the roof plane moved, reshaped, added and removed; a roof root
## and its ancestor moved; masonry faces moved by themselves or by an
## ancestor and reshaped. The control is a fresh provider with its index
## disabled, created for every comparison.

const COVER := preload("res://core/systems/world/visibility/WorldCover.gd")
const ROOF := preload("res://scenes/world/buildings/RoofOverlay.tscn")
const FOREGROUND := preload("res://core/systems/world/visibility/ForegroundSpriteCoverage.gd")
const INDEX_DISABLED_META := &"world_cover_index_disabled"
## Far outside the grown view area and its 512 px buckets.
const FAR := Vector2(24000,0)
## Actor feet far behind every occluder used here: presence, not depth.
const BEHIND := -100000.0
const LATENCY_LIMIT := 40
var _passed := 0
var _failed := 0
var _cover: Node
var _view_area := Rect2()


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
		print("PASS: ",message)
	else:
		_failed += 1
		push_error("FAIL: "+message)


func _provider(uncached: bool) -> Node:
	var cover := COVER.new() as Node
	cover.name = "UncachedControlCover" if uncached else "IndexedCover"
	if uncached:
		cover.set_meta(INDEX_DISABLED_META,true)
	get_viewport().add_child(cover)
	cover.set_process(false)
	return cover


func _stats(cover: Node) -> Dictionary:
	return cover.call("snapshot_stats") as Dictionary


## One refresh of a brand-new uncached provider: its records and samples.
func _control(samples: Array[Vector2]) -> Dictionary:
	var control := _provider(true)
	control.call("refresh",self,true)
	var strengths: Array[float] = []
	for point: Vector2 in samples:
		strengths.append(float(control.call("strength_at",point,BEHIND)))
	var result := {"semantics":control.call("_semantic_records"),"strengths":strengths,"stats":_stats(control)}
	control.free()
	return result


func _strengths(cover: Node, samples: Array[Vector2]) -> Array[float]:
	var result: Array[float] = []
	for point: Vector2 in samples:
		result.append(float(cover.call("strength_at",point,BEHIND)))
	return result


## Exactly one indexed refresh after the change must match the control.
## A mismatch keeps refreshing (no assertion) only to report the latency.
func _expect_next_refresh(label: String, samples: Array[Vector2], covered: bool) -> void:
	_cover.call("refresh",self,true)
	var control := _control(samples)
	var same: bool = _cover.call("_semantic_records") == control.semantics
	var strengths := _strengths(_cover,samples)
	_check(same,label+": the next indexed refresh has exactly the uncached control's records")
	_check(strengths == control.strengths,label+": the next indexed refresh samples the same coverage as the control")
	var expected := true
	for value: float in control.strengths:
		expected = expected and (value > 0.99 if covered else is_zero_approx(value))
	_check(expected,label+(": the control covers every changed sample" if covered else ": the control leaves every changed sample clear"))
	var all_match := true
	for value: float in strengths:
		all_match = all_match and (value > 0.99 if covered else is_zero_approx(value))
	_check(all_match,label+(": covered on the next refresh" if covered else ": cleared on the next refresh"))
	if strengths == control.strengths:
		return
	# Diagnostic latency of this case's own samples (an earlier case's
	# omission must not hide a later case's recovery).
	var waited := 1
	while waited < LATENCY_LIMIT:
		waited += 1
		_cover.call("refresh",self,true)
		if _strengths(_cover,samples) == control.strengths:
			print("INFO: %s samples matched the control only after %d refreshes" % [label,waited])
			return
	print("INFO: %s samples still differed from the control after %d refreshes" % [label,LATENCY_LIMIT])


func _in_view(rect: Rect2) -> bool:
	return _view_area.encloses(rect)


func _square(at: Vector2, size: float) -> PackedVector2Array:
	return PackedVector2Array([at,at+Vector2(size,0),at+Vector2(size,size),at+Vector2(0,size)])


## A full-form roof return below RoofPoly, under its own composition group:
## the depth at which city roof forms actually live.
func _composition(roof: RoofOverlay) -> Node2D:
	var group := Node2D.new()
	group.name = "TestComposition"
	(roof.get_node("RoofPoly") as Polygon2D).add_child(group)
	return group


func _form(group: Node2D, global_points: PackedVector2Array) -> Polygon2D:
	var form := Polygon2D.new()
	form.name = "TestFullForm"
	form.set_meta(&"city_roof_form",&"test_return")
	form.set_meta(&"roof_occlusion_full_form",true)
	group.add_child(form)
	var local := PackedVector2Array()
	for point: Vector2 in global_points:
		local.append(form.to_local(point))
	form.polygon = local
	return form


func _centroid(roof: RoofOverlay) -> Vector2:
	var poly := roof.get_node("RoofPoly") as Polygon2D
	var sum := Vector2.ZERO
	for point: Vector2 in poly.polygon:
		sum += poly.to_global(point)
	return sum/float(poly.polygon.size())


func _roof_at(parent: Node, offset: Vector2) -> RoofOverlay:
	var roof := ROOF.instantiate() as RoofOverlay
	parent.add_child(roof)
	roof.position = offset
	roof.configure(Rect2i(2,2,4,3),64,Vector2i.DOWN,null)
	return roof


func _face_at(parent: Node2D, global_points: PackedVector2Array) -> Polygon2D:
	var face := Polygon2D.new()
	parent.add_child(face)
	var local := PackedVector2Array()
	for point: Vector2 in global_points:
		local.append(face.to_local(point))
	face.polygon = local
	face.add_to_group(&"foreground_solid_occluders")
	face.set_meta(FOREGROUND.GROUND_CONTACT,Vector2(0,4000))
	return face


func _run() -> void:
	_cover = _provider(false)
	_cover.call("refresh",self,true)
	var origin: Vector2 = _cover.get("_origin")
	var grid: Vector2i = _cover.get("_grid_size")
	_view_area = Rect2(origin,Vector2(grid)*float(COVER.CELL_PX))
	_check(_view_area.has_point(Vector2(1200,700)) and not _view_area.grow(1024.0).has_point(FAR),"fixture: the far occluders start well outside the grown view area")
	# Unchanged offscreen decoys: an old rolling re-validation slice would need
	# many refreshes to reach any one changed occluder among them.
	var decoy_roofs := Node2D.new()
	add_child(decoy_roofs)
	for index in 30:
		_roof_at(decoy_roofs,FAR+Vector2(index%6,index/6)*Vector2(400,360)+Vector2(0,2400))
	var decoy_faces := Node2D.new()
	decoy_faces.position = FAR+Vector2(0,5000)
	add_child(decoy_faces)
	for index in 60:
		_face_at(decoy_faces,_square(decoy_faces.position+Vector2(index%10,index/10)*Vector2(120,120),80.0))
	# Changing occluders, all far away at first.
	var form_roof := _roof_at(self,FAR+Vector2(0,0))
	var form_group := _composition(form_roof)
	_form(form_group,_square(FAR+Vector2(220,260),60.0))
	var reshaped_roof := _roof_at(self,FAR+Vector2(800,0))
	var reshaped_form := _form(_composition(reshaped_roof),_square(FAR+Vector2(900,120),40.0))
	var added_roof := _roof_at(self,FAR+Vector2(1600,0))
	var added_group := _composition(added_roof)
	_form(added_group,_square(FAR+Vector2(1700,120),40.0))
	var hidden_roof := _roof_at(self,FAR+Vector2(2400,0))
	var hidden_group := _composition(hidden_roof)
	var hidden_form := _form(hidden_group,_square(FAR+Vector2(2500,260),60.0))
	hidden_form.visible = false
	var leaf_roof := _roof_at(self,FAR+Vector2(3200,0))
	var leaf := Polygon2D.new()
	leaf.name = "TestShadeLeaf"
	leaf.polygon = _square(Vector2(0,0),8.0)
	_composition(leaf_roof).add_child(leaf)
	# A long roof whose footprint straddles the right view edge; its plane
	# first covers only the far part of that footprint.
	var plane_roof := ROOF.instantiate() as RoofOverlay
	add_child(plane_roof)
	plane_roof.position = Vector2(_view_area.end.x-400.0,400)
	plane_roof.configure(Rect2i(0,0,14,3),64,Vector2i.DOWN,null)
	var plane := plane_roof.get_node("RoofPoly") as Polygon2D
	plane.polygon = PackedVector2Array([Vector2(640,8),Vector2(888,8),Vector2(888,184),Vector2(640,184)])
	var root_roof := _roof_at(self,FAR+Vector2(0,1000))
	var carrier := Node2D.new()
	carrier.position = FAR+Vector2(800,1000)
	add_child(carrier)
	var carried_roof := _roof_at(carrier,Vector2.ZERO)
	var face_parent := Node2D.new()
	face_parent.position = FAR+Vector2(0,1800)
	add_child(face_parent)
	var moved_face := _face_at(face_parent,_square(FAR+Vector2(1400,1800),60.0))
	var ancestor := Node2D.new()
	ancestor.position = FAR+Vector2(400,1800)
	add_child(ancestor)
	var carried_face := _face_at(ancestor,_square(FAR+Vector2(400,1800),60.0))
	var reshaped_face := _face_at(face_parent,_square(FAR+Vector2(200,1800),60.0))
	# A long-running provider: steady cached entries before anything moves.
	for step in 3:
		_cover.call("refresh",self,true)
	var steady := _stats(_cover)
	_check(int(steady.primitive_count) == 0,"fixture: nothing far away is covered before the changes")
	_check(int(steady.visited_roofs) == 0 and int(steady.visited_faces) == 0,"the index visits no far occluder while the view is empty")
	var initial_control := _control([])
	_check(bool((initial_control.stats as Dictionary).get("index_disabled",false)),"the uncached control reports its disabled index")
	_check(int((initial_control.stats as Dictionary).get("visited_roofs",-1)) == 38 and int((initial_control.stats as Dictionary).get("visited_faces",-1)) == 63,"the uncached control visits every loaded roof and face")
	# 1. A descendant form moved by its composition group into view.
	form_group.global_position -= FAR
	var moved_rect := Rect2(220,260,60,60)
	_check(_in_view(moved_rect),"fixture: the moved form now lies in view")
	_expect_next_refresh("descendant roof form moved into view",[moved_rect.get_center()],true)
	# 2. A descendant form reshaped from far away into view.
	var reshape_target := _square(Vector2(520,260),60.0)
	var reshaped_local := PackedVector2Array()
	for point: Vector2 in reshape_target:
		reshaped_local.append(reshaped_form.to_local(point))
	reshaped_form.polygon = reshaped_local
	_expect_next_refresh("descendant roof form reshaped into view",[Vector2(550,290)],true)
	# 3. A new form added below an existing composition group (not a direct
	# child of the roof plane) whose polygon lies in view.
	var added_form := _form(added_group,_square(Vector2(820,260),60.0))
	_expect_next_refresh("descendant roof form added in view",[Vector2(850,290)],true)
	# ... and removed again.
	added_form.free()
	_expect_next_refresh("descendant roof form removed from view",[Vector2(850,290)],false)
	# ... and a form added below a leaf node (no form had a child there).
	var leaf_form := Polygon2D.new()
	leaf_form.set_meta(&"city_roof_form",&"test_return")
	leaf_form.set_meta(&"roof_occlusion_full_form",true)
	leaf.add_child(leaf_form)
	var leaf_local := PackedVector2Array()
	for point: Vector2 in _square(Vector2(820,500),60.0):
		leaf_local.append(leaf_form.to_local(point))
	leaf_form.polygon = leaf_local
	_expect_next_refresh("roof form added below a leaf node in view",[Vector2(850,530)],true)
	leaf_form.queue_free()
	await get_tree().process_frame
	_expect_next_refresh("roof form below a leaf node freed",[Vector2(850,530)],false)
	# 4. A hidden form moved into view while hidden, then shown.
	hidden_group.global_position -= FAR+Vector2(1400,0)
	_check(_in_view(Rect2(1100,260,60,60)),"fixture: the hidden form now lies in view")
	_expect_next_refresh("hidden descendant form moved into view",[Vector2(1130,290)],false)
	hidden_form.visible = true
	_expect_next_refresh("hidden descendant form shown in view",[Vector2(1130,290)],true)
	# 5. A roof root moved into view.
	root_roof.position = Vector2(0,400)
	var root_sample := _centroid(root_roof)
	_expect_next_refresh("roof root moved into view",[root_sample],true)
	# 6. A roof moved into view by an ancestor.
	carrier.position = Vector2(1200,400)
	var carried_sample := _centroid(carried_roof)
	_expect_next_refresh("roof ancestor moved into view",[carried_sample],true)
	# 6b. A roof plane reshaped from the far part of its footprint into view.
	var plane_sample := plane.to_global(Vector2(160,96))
	_check(_view_area.has_point(plane_sample) and not _view_area.intersects(Rect2(plane.to_global(Vector2(640,8)),Vector2(248,176))),"fixture: the plane starts outside the view over a footprint that reaches into it")
	plane.polygon = PackedVector2Array([Vector2(8,8),Vector2(888,8),Vector2(888,184),Vector2(8,184)])
	_expect_next_refresh("roof plane reshaped into view",[plane_sample],true)
	# 7. A masonry face moved by its own transform.
	moved_face.position -= FAR+Vector2(0,1000)
	_expect_next_refresh("masonry face moved into view",[moved_face.to_global(moved_face.polygon[0]+Vector2(30,30))],true)
	# 8. A masonry face moved by an ancestor.
	ancestor.position -= FAR+Vector2(0,1000)
	_expect_next_refresh("masonry face ancestor moved into view",[carried_face.to_global(carried_face.polygon[0]+Vector2(30,30))],true)
	# 9. A masonry face reshaped from far away into view.
	var face_local := PackedVector2Array()
	for point: Vector2 in _square(Vector2(1500,900),60.0):
		face_local.append(reshaped_face.to_local(point))
	reshaped_face.polygon = face_local
	_expect_next_refresh("masonry face reshaped into view",[Vector2(1530,930)],true)
	# 10. Everything moved back out leaves no stale coverage.
	form_group.global_position += FAR
	hidden_group.global_position += FAR+Vector2(1400,0)
	root_roof.position = FAR+Vector2(0,1000)
	carrier.position = FAR+Vector2(800,1000)
	moved_face.position += FAR+Vector2(0,1000)
	ancestor.position += FAR
	reshaped_face.position += FAR
	reshaped_form.position += FAR
	plane_roof.position += FAR
	_expect_next_refresh("every changed occluder moved back out of view",[moved_rect.get_center(),Vector2(550,290),Vector2(1130,290),root_sample,carried_sample,plane_sample,Vector2(1530,930)],false)
	# The index still pays only for the view, and unchanged frames reuse.
	_cover.call("refresh",self,true)
	var quiet := _stats(_cover)
	_cover.call("refresh",self,true)
	var after := _stats(_cover)
	_check(int(after.visited_roofs) == 0 and int(after.visited_faces) == 0,"the index still visits no far occluder after the changes")
	_check(int(after.snapshot_reuses) == int(quiet.snapshot_reuses)+1 and int(after.snapshot_builds) == int(quiet.snapshot_builds),"an unchanged refresh still reuses the packed snapshot")
	moved_face.position -= FAR+Vector2(0,1000)
	_cover.call("refresh",self,true)
	var one := _stats(_cover)
	_check(int(one.visited_faces) == 1 and int(one.visited_roofs) == 0,"one occluder back in view is the only one the index visits")
	moved_face.position += FAR+Vector2(0,1000)
	# Leaving the uncached control rebuilds a watched index, including a roof
	# that was first loaded while the provider ran as the control.
	_cover.set_meta(INDEX_DISABLED_META,true)
	var round_trip_roof := _roof_at(self,FAR+Vector2(4000,0))
	var round_trip_group := _composition(round_trip_roof)
	_cover.call("refresh",self,true)
	_check(bool(_stats(_cover).get("index_disabled",false)) and int(_stats(_cover).visited_roofs) == 39,"the provider itself can run as the uncached control")
	_cover.set_meta(INDEX_DISABLED_META,false)
	_cover.call("refresh",self,true)
	_check(not bool(_stats(_cover).get("index_disabled",true)) and int(_stats(_cover).visited_roofs) == 0,"leaving the control resumes the view index")
	var late_form := _form(round_trip_group,_square(FAR+Vector2(4000,0),10.0))
	var late_local := PackedVector2Array()
	for point: Vector2 in _square(Vector2(220,560),60.0):
		late_local.append(late_form.to_local(point))
	late_form.polygon = late_local
	_expect_next_refresh("form added after the control round trip",[Vector2(250,590)],true)
	_cover.free()
	# Watches die with their provider: later structural edits are harmless.
	leaf.add_child(Node2D.new())
	late_form.free()
	await get_tree().process_frame
	print("WorldCoverInvalidationTest: %d passed, %d failed" % [_passed,_failed])
	get_tree().quit(1 if _failed > 0 else 0)
