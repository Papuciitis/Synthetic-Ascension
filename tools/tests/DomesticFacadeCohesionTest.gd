extends "res://tools/tests/DomesticFrontageFinishTest.gd"
## Original window details belong to one wall instead of repeated house tiles.


func _run() -> void:
	var previous_segment: int = Global.attempt_segment
	var dummy := Node2D.new()
	dummy.add_to_group(&"player")
	add_child(dummy)
	var fixture: Dictionary = _fixture(2,&"row_house")
	var kit: Node2D = fixture.kit
	var windows: Array[Sprite2D] = []
	var crops: Dictionary = {}
	for node: Node in kit.find_children("*","Sprite2D",true,false):
		var sprite := node as Sprite2D
		if not sprite.has_meta(&"domestic_window_opening"): continue
		windows.append(sprite)
		crops[sprite.region_rect] = true
		_check(sprite.region_enabled and sprite.region_rect.size.x < 600 and sprite.region_rect.size.y < 600,"Domestic windows crop only their authored detail, excluding whole building corners and roof/base borders")
		_check(is_equal_approx(sprite.scale.x,sprite.scale.y),"Each original window keeps its source aspect instead of filling a rectangular tile")
		_check(sprite.is_in_group(&"foreground_occluders"),"Actual window detail retains per-pixel foreground alpha coverage")
		var point: Vector2 = sprite.to_global(sprite.get_rect().get_center())
		_check(_cohesion_solid_count(kit,point) == 1,"A cropped window replaces its wall area instead of doubling fractional coverage")
	_check(windows.size() == 2 and crops.size() == 2,"The real home uses two distinct original window details rather than three copied boxed house panels")
	var fields := 0
	var plinths := 0
	for node: Node in kit.find_children("*","Polygon2D",true,false):
		var face := node as Polygon2D
		if face.has_meta(&"domestic_wall_field"):
			fields += 1
			_check(face.color == Color.WHITE,"One wall keeps the original warm plaster colour without a separately tinted green upper strip")
		if face.has_meta(&"domestic_masonry_plinth"):
			plinths += 1
			_check(face.texture != null and face.texture.resource_path == "res://assets/world/walls/kit/wall34_10.png","Quiet lower plinth reuses the country's actual rough wall source")
	_check(fields >= 2 and plinths >= 2,"Both actual wings have continuous warm wall and a quiet original masonry base")
	var leaf := kit.find_child("DomesticOpenDoorLeaf",true,false) as Polygon2D
	_check(leaf != null,"Domestic entrance has a visibly folded-back timber leaf beside its open recess")
	if leaf != null:
		var bounds: Rect2 = _bounds(leaf.polygon)
		var gap: Rect2 = FRONTAGES._door_box(DOOR,64)
		_check(bounds.size.x >= 32 and bounds.size.y >= 80 and bounds.end.x <= gap.position.x,"Open timber leaf has readable scale and leaves the full128px physical doorway clear")
		_check(_cohesion_solid_count(kit,leaf.to_global(bounds.get_center())) == 1,"Folded leaf replaces its wall area and fades exactly once")
	var portal := kit.find_child("IrregularUprightPortal",true,false) as Node2D
	if portal != null:
		var opening: Rect2 = portal.get_meta(&"opening_face",Rect2())
		_check(is_equal_approx(opening.size.x,128.0) and opening.size.y <= 112.0,"Visual domestic door height is human scale while its physical width remains unchanged")
	_check(kit.find_children("*","CollisionObject2D",true,false).is_empty(),"Cohesive façade creates no replacement physical wall or door")
	(fixture.host as Node).free()
	var north: Dictionary = _fixture(2,&"row_house",false)
	var north_kit: Node2D = north.kit
	var north_windows := 0
	for node: Node in north_kit.find_children("*","Sprite2D",true,false):
		var sprite := node as Sprite2D
		if sprite.has_meta(&"domestic_window_opening"):
			north_windows += 1
			_check(_cohesion_solid_count(north_kit,sprite.to_global(sprite.get_rect().get_center())) == 1,"The north-entry fruit home's south windows also replace their wall field")
	_check(north_windows == 2,"Rectangular fruit home receives the same coherent two-detail wall rather than repeated whole-house tiles")
	var north_recess := north_kit.find_child("CardinalDoorRecess",true,false) as Node2D
	_check(north_recess != null and north_recess.get_meta(&"door_direction",Vector2i.ZERO) == Vector2i.UP,"Cohesive visible south wall preserves the fruit home's genuine north-facing entry")
	_check(north_kit.find_child("DomesticOpenDoorLeaf",true,false) == null,"Visible south wall does not invent a second physical or painted fruit-home entrance")
	(north.host as Node).free()
	dummy.free()
	Global.attempt_segment = previous_segment
	print("DomesticFacadeCohesionTest: %d passed, %d failed" % [_passed,_failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _cohesion_solid_count(kit: Node2D, point: Vector2) -> int:
	var count := 0
	for node: Node in kit.find_children("*","",true,false):
		if node is Polygon2D and node.is_in_group(&"foreground_solid_occluders"):
			if Geometry2D.is_point_in_polygon((node as Polygon2D).to_local(point),(node as Polygon2D).polygon): count += 1
		if node is Sprite2D and node.is_in_group(&"foreground_occluders"):
			var sprite := node as Sprite2D
			if sprite.get_rect().has_point(sprite.to_local(point)): count += 1
	return count
