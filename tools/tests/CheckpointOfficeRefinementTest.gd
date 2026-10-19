extends "res://tools/tests/CheckpointOfficeRenderTest.gd"

func _run() -> void:
	# These checks catch a missing material binding, an unsupported plinth,
	# or a cardinal approach cue moved away from the actual carved opening.
	for irregular: bool in [false,true]:
		for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var fixture := _fixture(direction,irregular)
			var roof: RoofOverlay = fixture.roof
			var kit: Node2D = fixture.kit
			var plan: Dictionary = roof.get_meta(&"district_form_plan")
			var infill_count := 0
			for face: Node in kit.find_children("*","Polygon2D",true,false):
				if face.get_meta(&"guard_surface",&"") != &"infill": continue
				infill_count+=1
				_check((face as Polygon2D).texture!=null,"Fitted wall infill consumes the original quiet material")
				_check((face as Polygon2D).uv.size()==(face as Polygon2D).polygon.size(),"Wall material uses explicit surface-aligned coordinates")
			_check(infill_count>0,"Guard family retains finished material on supported wall faces")
			for portal: Node in kit.find_children("GuardEntryPortal","",true,false):
				if direction==Vector2i.DOWN: continue
				var gap: Rect2 = portal.get_meta(&"door_cells_px")
				var landings := portal.find_children("GuardThreshold","Polygon2D",true,false)
				_check(landings.size()==1,"Each actual side/rear entry has a readable grounded threshold")
				if landings.is_empty(): continue
				var shape := landings[0] as Polygon2D
				var center := Vector2.ZERO
				for point: Vector2 in shape.polygon: center+=point
				center/=shape.polygon.size()
				var boundary := gap.get_center()+Vector2(direction)*gap.size*0.5
				_check(is_equal_approx((center-boundary).dot(Vector2(direction)),24.0),"Threshold is centered 24 px outside the real wall opening")
				var across := Vector2(-direction.y,direction.x)
				_check(is_zero_approx((center-gap.get_center()).dot(across)),"Threshold stays centered on the original even-width doorway")
				_check(absf(absf(_polygon_area(shape.polygon))-6144.0)<0.01,"Threshold remains within the existing 128 by 48 px apron strip")
				for point: Vector2 in shape.polygon:
					_check((point-boundary).dot(Vector2(direction))>=-0.01,"Approach material does not close the carved doorway")
			if plan.has_watch:
				var front := roof.find_children("GuardWatchFront","Polygon2D",true,false)[0] as Polygon2D
				_check(front.texture!=null,"The raised watch body shares finished infill material")
				_check(not roof.find_children("GuardWatchPlinth","Polygon2D",true,false).is_empty(),"Watch body has a grounded architectural base")
				_check(not roof.find_children("GuardWatchEaveShadow","Polygon2D",true,false).is_empty(),"Watch eave separates its body from the cap")
				var side := roof.find_children("GuardWatchSide","Polygon2D",true,false)[0] as Polygon2D
				var support: PackedVector2Array = plan.watch_support
				var max_x := -INF
				for point: Vector2 in support: max_x=maxf(max_x,point.x)
				for point: Vector2 in side.polygon: _check(point.x<=max_x+16.01,"Watch side return stays in the existing fitting margin")
			kit.free()
			roof.free()
	print("CheckpointOfficeRefinementTest: %d passed, %d failed" % [passed,failed])
	get_tree().quit(1 if failed else 0)

func _polygon_area(points: PackedVector2Array) -> float:
	var total := 0.0
	for index: int in points.size(): total+=points[index].cross(points[(index+1)%points.size()])
	return total*0.5
