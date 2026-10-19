extends Node2D

var _passed := 0
var _failed := 0

func _check(ok: bool, message: String) -> void:
	if ok: _passed += 1
	else:
		_failed += 1
		push_error(message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var path := "res://core/actors/player/PlayerRoofOcclusion.gd"
	_check(ResourceLoader.exists(path), "a covered player needs a shadow silhouette mask")
	if ResourceLoader.exists(path):
		var mask = load(path).new()
		var roof := preload("res://scenes/world/buildings/RoofOverlay.tscn").instantiate() as RoofOverlay
		add_child(roof)
		roof.configure(Rect2i(2, 2, 8, 7), 64, Vector2i.DOWN, null)
		var root := Node2D.new()
		add_child(root)
		var body := AnimatedSprite2D.new()
		var head := AnimatedSprite2D.new()
		root.add_child(body)
		root.add_child(head)
		mask.configure(body, head)
		# Actor's feet remain outside the north wall. Only the pixels under
		# the projected roof should change, not their unobstructed head.
		var covered: Vector2 = (roof.get_node("RoofPoly") as Polygon2D).to_global(Vector2(300, 144))
		mask.update(root, Vector2(300, 110), Rect2(240, 60, 120, 140))
		_check(mask.strength_at(covered) > 0.99, "opaque projected roof masks overlapping sprite pixels")
		_check(is_zero_approx(mask.strength_at(Vector2(300, 60))), "uncovered pixels retain normal presentation")
		_check(body.material != null and body.material == head.material, "body and head share the same occlusion material")
		roof._set_alpha(0.4)
		mask.update(root, Vector2(300, 110), Rect2(240, 60, 120, 140))
		_check(is_equal_approx(mask.strength_at(covered), 0.4), "silhouette follows roof fade instead of snapping")
		roof._inside_count = 1
		mask.update(root, Vector2(300, 110), Rect2(240, 60, 120, 140))
		_check(is_zero_approx(mask.strength_at(covered)), "interior entry preserves normal player and existing cutaway")
		roof._inside_count = 0
		roof._set_alpha(1.0)
		mask.update(root, Vector2(300, 640), Rect2(240, 60, 120, 140))
		_check(is_zero_approx(mask.strength_at(covered)), "actor in front of the building is not shadowed")
		var recessed := PackedVector2Array([Vector2(128,128),Vector2(640,128),Vector2(640,576),Vector2(384,576),Vector2(384,320),Vector2(128,320)])
		roof.configure_polygon(recessed, Vector2(384,576), Vector2(640,576), [])
		mask.update(root, Vector2(300,350), Rect2(240,220,120,180))
		_check(is_zero_approx(mask.strength_at(Vector2(300,280))), "recessed south-facing wing does not shadow an actor standing in front of it")
		var courtyard := PackedVector2Array([Vector2(128,128),Vector2(640,128),Vector2(640,576),Vector2(128,576),Vector2(128,448),Vector2(512,448),Vector2(512,256),Vector2(128,256)])
		roof.configure_polygon(courtyard, Vector2(128,576), Vector2(640,576), [])
		mask.update(root, Vector2(300,350), Rect2(240,160,120,350))
		_check(is_zero_approx(mask.strength_at(Vector2(300,200))), "courtyard rear wing stays behind the actor")
		_check(mask.strength_at(Vector2(300,430)) > 0.99, "the same courtyard actor is behind the southern wing")
		roof.queue_free()
		await get_tree().process_frame
		mask.update(root, Vector2(300, 110), Rect2(240, 60, 120, 140))
		_check(is_zero_approx(mask.strength_at(covered)), "streaming out a roof clears its mask")
		root.queue_free()
	await get_tree().process_frame
	print("PlayerRoofOcclusionTest: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)
