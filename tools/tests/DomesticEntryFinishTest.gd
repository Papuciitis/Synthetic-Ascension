extends "res://tools/tests/DomesticFrontageFinishTest.gd"
## The real entry gains readable depth without a narrower physical doorway.


func _run() -> void:
	var previous_segment: int = Global.attempt_segment
	var dummy := Node2D.new()
	dummy.add_to_group(&"player")
	add_child(dummy)
	var fixture: Dictionary = _fixture(2,&"row_house")
	var kit: Node2D = fixture.kit
	var head_fields := 0
	for node: Node in kit.find_children("*","Polygon2D",true,false):
		var field := node as Polygon2D
		if not field.has_meta(&"domestic_upper_run"): continue
		head_fields += 1
		var run: Rect2 = field.get_meta(&"domestic_upper_run")
		_check(run.size.y <= float(kit.get("_facade_height"))*0.25,"Domestic windows reach a restrained head course instead of sitting below a broad blank panel strip")
	_check(head_fields == 2,"Each real window wing has one continuous upper material field")
	_check(kit.find_child("DomesticUpperPier",true,false) == null,"Domestic upper wall avoids disconnected repeated narrow panel seams")
	var portal := kit.find_child("IrregularUprightPortal",true,false) as Node2D
	_check(portal != null,"Retained home has its actual south-facing entry")
	if portal != null:
		var gap: Rect2 = FRONTAGES._door_box(DOOR,64)
		var floor := portal.get_node_or_null("DomesticEntryFloor") as Polygon2D
		_check(floor != null,"Domestic entry breaks the unbroken dark recess with an actual shallow floor return")
		if floor != null:
			var bounds: Rect2 = _bounds(floor.polygon)
			_check(floor.texture != null and floor.texture.resource_path == "res://assets/world/city_block/paving.png","Entry return reuses the existing stone floor material")
			_check(is_equal_approx(bounds.size.x,gap.size.x) and bounds.size.y >= 24.0 and bounds.size.y <= 48.0,"Shallow return leaves the full128px clear entry span")
			_check(not floor.is_in_group(&"foreground_solid_occluders") and not floor.is_in_group(&"foreground_occluders"),"Walkable entry return remains floor décor")
		for side: String in ["Left","Right"]:
			var wing := portal.get_node_or_null("DomesticOpenTimber"+side) as Polygon2D
			_check(wing != null,"Existing timber gives the open domestic "+side.to_lower()+" jamb a visible return")
			if wing == null: continue
			var bounds: Rect2 = _bounds(wing.polygon)
			_check(wing.texture != null and wing.texture.resource_path == "res://assets/world/city_block/house_front.png","Open jamb reuses the original door lining")
			_check(bounds.end.x <= gap.position.x if side == "Left" else bounds.position.x >= gap.end.x,"Open timber preserves the complete physical doorway width")
			_check(wing.is_in_group(&"foreground_solid_occluders"),"Opaque jamb timber enters the actual coverage registry")
			var point: Vector2 = wing.to_global(bounds.get_center())
			var solids := 0
			for node: Node in kit.find_children("*","Polygon2D",true,false):
				var face := node as Polygon2D
				if face.is_in_group(&"foreground_solid_occluders") and Geometry2D.is_point_in_polygon(face.to_local(point),face.polygon):
					solids += 1
			_check(solids == 1,"Open timber replaces its jamb area, avoiding doubled fractional cutaway coverage")
		var opening: Rect2 = portal.get_meta(&"opening_face",Rect2())
		_check(opening.size == Vector2(128,128),"Domestic finish retains the existing opening width and supported-header height")
	_check(kit.find_children("*","CollisionObject2D",true,false).is_empty(),"Entry composition changes no physics or door collision")
	(fixture.roof as RoofOverlay)._set_alpha(0.0)
	var returns := kit.get_node_or_null("CardinalWallReturns") as Node2D
	_check(returns != null and is_zero_approx(returns.modulate.a),"Entry presentation follows the genuine roof cutaway")
	(fixture.host as Node).free()
	for control: Dictionary in [{"segment":2,"usage":&"workshop"},{"segment":3,"usage":&"row_house"}]:
		var untouched: Dictionary = _fixture(int(control.segment),StringName(control.usage))
		_check((untouched.kit as Node).find_child("DomesticEntryFloor",true,false) == null,"New entry depth stays within domestic S2 ownership")
		(untouched.host as Node).free()
	dummy.free()
	Global.attempt_segment = previous_segment
	print("DomesticEntryFinishTest: %d passed, %d failed" % [_passed,_failed])
	get_tree().quit(1 if _failed > 0 else 0)
