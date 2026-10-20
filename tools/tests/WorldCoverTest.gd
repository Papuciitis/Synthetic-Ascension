extends Node2D

const COVER_PATH := "res://core/systems/world/visibility/WorldCover.gd"
const ROOF := preload("res://scenes/world/buildings/RoofOverlay.tscn")
var _passed := 0
var _failed := 0

func _check(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
		print("PASS: ", message)
	else:
		_failed += 1
		push_error(message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(ResourceLoader.exists(COVER_PATH), "entities need a shared live world-cover query, not the player's actor-filtered mask")
	if ResourceLoader.exists(COVER_PATH):
		var script: GDScript = load(COVER_PATH)
		var cover: Node = script.call("get_for", self)
		_check(cover == script.call("get_for", self), "consumers in one viewport share one coverage provider")
		var roof := ROOF.instantiate() as RoofOverlay
		add_child(roof)
		roof.configure(Rect2i(2,2,8,7),64,Vector2i.DOWN,null)
		var covered := (roof.get_node("RoofPoly") as Polygon2D).to_global(Vector2(300,144))
		cover.call("refresh",self,true)
		_check(float(cover.call("strength_at",covered,110.0)) > 0.99, "shared coverage reaches a roof-covered fragment for a behind actor")
		_check(is_zero_approx(float(cover.call("strength_at",Vector2(300,60),110.0))), "uncovered pixels remain clear")
		_check(is_zero_approx(float(cover.call("strength_at",covered,640.0))), "the same covered pixel remains clear for an actor in front")
		roof._set_alpha(0.4)
		cover.call("refresh",self,true)
		_check(is_equal_approx(float(cover.call("strength_at",covered,110.0)),0.4), "cover retains continuous live roof opacity")
		roof._inside_count = 1
		cover.call("refresh",self,true)
		_check(is_zero_approx(float(cover.call("strength_at",covered,110.0))), "an actual cutaway stops shadowing covered entities")
		roof._inside_count = 0
		roof._set_alpha(1.0)
		var courtyard := PackedVector2Array([Vector2(128,128),Vector2(640,128),Vector2(640,576),Vector2(128,576),Vector2(128,448),Vector2(512,448),Vector2(512,256),Vector2(128,256)])
		roof.configure_polygon(courtyard,Vector2(128,576),Vector2(640,576),[])
		cover.call("refresh",self,true)
		_check(is_zero_approx(float(cover.call("strength_at",Vector2(300,200),350.0))), "courtyard rear span remains behind its actor")
		_check(float(cover.call("strength_at",Vector2(300,430),350.0)) > 0.99, "the same actor is covered by its southern courtyard wing")
		roof.visible = false
		cover.call("refresh",self,true)
		_check(is_zero_approx(float(cover.call("strength_at",Vector2(300,430),350.0))), "hidden cover never leaves stale world coverage")
		roof.queue_free()
		await get_tree().process_frame
		cover.call("refresh",self,true)
		_check(is_zero_approx(float(cover.call("strength_at",covered,110.0))), "streaming removal clears shared coverage")
		var roofs: Array[RoofOverlay] = []
		for index in 35:
			var small := ROOF.instantiate() as RoofOverlay
			add_child(small)
			small.position = Vector2(index%7,index/7)*Vector2(192,160)
			small.configure(Rect2i(0,0,2,2),64,Vector2i.DOWN,null)
			roofs.append(small)
		cover.call("refresh",self,true)
		var stats: Dictionary = cover.call("snapshot_stats")
		_check(int(stats.get("primitive_count",0)) > 32, "shared batches retain more than the old actor-local32 triangles")
		var last: RoofOverlay = roofs.back()
		var last_sample := (last.get_node("RoofPoly") as Polygon2D).to_global(Vector2(64,64))
		_check(float(cover.call("strength_at",last_sample,last.position.y-100.0)) > 0.99, "a covering roof beyond the old capacity is not silently discarded")
		var generation := int(stats.get("generation",-1))
		cover.call("refresh",self)
		_check(int((cover.call("snapshot_stats") as Dictionary).get("generation",-2)) == generation, "multiple consumers share one snapshot in a render frame")
		for item: RoofOverlay in roofs:
			item.queue_free()
		await get_tree().process_frame
		cover.call("refresh",self,true)
		_check(int((cover.call("snapshot_stats") as Dictionary).get("primitive_count",-1)) == 0, "unloading every cover removes all shared primitives")
		await _test_solid_faces(cover)
		await _test_world_isolation(cover)
	print("WorldCoverTest: %d passed, %d failed" % [_passed,_failed])
	get_tree().quit(1 if _failed > 0 else 0)

func _test_solid_faces(cover: Node) -> void:
	var parent := Node2D.new()
	parent.position = Vector2(80,100)
	parent.modulate.a = 0.8
	add_child(parent)
	var face := Polygon2D.new()
	face.position = Vector2(10,10)
	face.polygon = PackedVector2Array([Vector2.ZERO,Vector2(100,0),Vector2(100,40),Vector2(40,40),Vector2(40,100),Vector2(0,100)])
	face.color.a = 0.5
	parent.add_child(face)
	face.add_to_group(&"foreground_solid_occluders")
	face.set_meta(&"foreground_ground_contact",Vector2(50,150))
	var opaque := face.to_global(Vector2(20,70))
	var gap := face.to_global(Vector2(70,70))
	cover.call("refresh",self,true)
	_check(is_equal_approx(float(cover.call("strength_at",opaque,249.0)),0.4), "real masonry uses polygon opacity and inherited fade")
	_check(is_zero_approx(float(cover.call("strength_at",opaque,251.0))), "masonry uses its registered parent-local ground depth")
	_check(is_zero_approx(float(cover.call("strength_at",gap,249.0))), "concave masonry does not fill an absent wall section")
	face.visible = false
	cover.call("refresh",self,true)
	_check(is_zero_approx(float(cover.call("strength_at",opaque,249.0))), "hidden masonry removes its live coverage")
	face.visible = true
	face.color.a = 0.0
	cover.call("refresh",self,true)
	_check(is_zero_approx(float(cover.call("strength_at",opaque,249.0))), "transparent real masonry stays clear independently of virtual roof helper masks")
	parent.queue_free()
	await get_tree().process_frame

func _test_world_isolation(cover: Node) -> void:
	var foreign_view := SubViewport.new()
	foreign_view.size = Vector2i(640,360)
	foreign_view.world_2d = World2D.new()
	add_child(foreign_view)
	var foreign := Node2D.new()
	foreign_view.add_child(foreign)
	var roof := ROOF.instantiate() as RoofOverlay
	foreign.add_child(roof)
	roof.configure(Rect2i(4,4,4,4),64,Vector2i.DOWN,null)
	var poly := roof.get_node("RoofPoly") as Polygon2D
	var roof_sample := Vector2.ZERO
	for point: Vector2 in poly.polygon:
		roof_sample += poly.to_global(point)
	roof_sample /= poly.polygon.size()
	var image := Image.create(8,8,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.position = Vector2(100,100)
	foreign.add_child(sprite)
	preload("res://core/systems/world/visibility/ForegroundSpriteCoverage.gd").register(sprite,Vector2(100,200))
	var face := Polygon2D.new()
	face.polygon = PackedVector2Array([Vector2(140,90),Vector2(180,90),Vector2(180,130),Vector2(140,130)])
	foreign.add_child(face)
	face.add_to_group(&"foreground_solid_occluders")
	face.set_meta(&"foreground_ground_contact",Vector2(160,200))
	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)
	var ui_parent := Node2D.new()
	ui_layer.add_child(ui_parent)
	var ui_sprite := Sprite2D.new()
	ui_sprite.texture = sprite.texture
	ui_sprite.position = Vector2(220,100)
	ui_parent.add_child(ui_sprite)
	preload("res://core/systems/world/visibility/ForegroundSpriteCoverage.gd").register(ui_sprite,Vector2(220,200))
	var shared_view := SubViewport.new()
	shared_view.size = Vector2i(640,360)
	shared_view.world_2d = get_viewport().find_world_2d()
	add_child(shared_view)
	var shared_parent := Node2D.new()
	shared_view.add_child(shared_parent)
	var shared_sprite := Sprite2D.new()
	shared_sprite.texture = sprite.texture
	shared_sprite.position = Vector2(280,100)
	shared_parent.add_child(shared_sprite)
	preload("res://core/systems/world/visibility/ForegroundSpriteCoverage.gd").register(shared_sprite,Vector2(280,200))
	cover.call("refresh",self,true)
	_check(is_zero_approx(float(cover.call("strength_at",roof_sample,0.0))), "another viewport's independent world does not contribute roof coverage")
	_check(is_zero_approx(float(cover.call("strength_at",Vector2(100,100),0.0))), "another world does not contribute sprite coverage")
	_check(is_zero_approx(float(cover.call("strength_at",Vector2(160,100),0.0))), "another world does not contribute masonry coverage")
	_check(is_zero_approx(float(cover.call("strength_at",Vector2(220,100),0.0))), "a separate CanvasLayer in the same world cannot cast cover onto the camera canvas")
	_check(float(cover.call("strength_at",Vector2(280,100),0.0)) > 0.99, "a second viewport sharing the actual world canvas retains its visible geometry")
	foreign_view.queue_free()
	ui_layer.queue_free()
	shared_view.queue_free()
	await get_tree().process_frame
