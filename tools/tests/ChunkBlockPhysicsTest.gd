extends Node

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	_test_half_arms_merge()
	_test_isolated_post()
	_test_corner_geometry()
	_test_kinds_remain_separate()
	_test_shape_owner_bodies()
	print("ChunkBlockPhysicsTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_half_arms_merge() -> void:
	var data := ChunkBuildData.new(Vector2i.ZERO, 4)
	data.add_blocker(Vector2i(1, 1), WorldBlockerGeometry.Kind.WALL, WorldBlockerGeometry.E)
	data.add_blocker(Vector2i(2, 1), WorldBlockerGeometry.Kind.WALL, WorldBlockerGeometry.W)
	var rectangles := ChunkBlockPhysics.rectangles_for_kind(data, WorldBlockerGeometry.Kind.WALL, 64)
	_check(rectangles == [Rect2(96, 84, 64, 24)], "two half-arms merge into one run")


func _test_isolated_post() -> void:
	var data := ChunkBuildData.new(Vector2i.ZERO, 4)
	data.add_blocker(Vector2i(1, 2), WorldBlockerGeometry.Kind.WALL)
	var rectangles := ChunkBlockPhysics.rectangles_for_kind(data, WorldBlockerGeometry.Kind.WALL, 64)
	_check(rectangles == [Rect2(84, 148, 24, 24)], "an unconnected wall becomes one centered post")


func _test_corner_geometry() -> void:
	var data := ChunkBuildData.new(Vector2i.ZERO, 4)
	data.add_blocker(Vector2i(1, 1), WorldBlockerGeometry.Kind.WALL, WorldBlockerGeometry.N | WorldBlockerGeometry.E)
	var rectangles := ChunkBlockPhysics.rectangles_for_kind(data, WorldBlockerGeometry.Kind.WALL, 64)
	_check(rectangles == [Rect2(96, 84, 32, 24), Rect2(84, 64, 24, 32)], "an L corner emits one horizontal and one vertical arm")


func _test_kinds_remain_separate() -> void:
	var data := ChunkBuildData.new(Vector2i.ZERO, 4)
	data.add_blocker(Vector2i(0, 0), WorldBlockerGeometry.Kind.WALL, WorldBlockerGeometry.E)
	data.add_blocker(Vector2i(1, 0), WorldBlockerGeometry.Kind.WINDOW, WorldBlockerGeometry.W)
	var walls := ChunkBlockPhysics.rectangles_for_kind(data, WorldBlockerGeometry.Kind.WALL, 64)
	var windows := ChunkBlockPhysics.rectangles_for_kind(data, WorldBlockerGeometry.Kind.WINDOW, 64)
	_check(walls == [Rect2(32, 20, 32, 24)], "wall geometry contains only wall arms")
	_check(windows == [Rect2(64, 20, 32, 24)], "window geometry is batched separately")


func _test_shape_owner_bodies() -> void:
	var data := ChunkBuildData.new(Vector2i.ZERO, 4)
	data.add_blocker(Vector2i(0, 0), WorldBlockerGeometry.Kind.WALL)
	data.add_blocker(Vector2i(1, 0), WorldBlockerGeometry.Kind.WINDOW)
	data.add_blocker(Vector2i(2, 0), WorldBlockerGeometry.Kind.HALF_COVER)
	data.add_blocker(Vector2i(3, 0), WorldBlockerGeometry.Kind.HALF_COVER)
	var physics := ChunkBlockPhysics.new()
	add_child(physics)
	physics.build(data, 64)
	_check(physics.body_count() == 3, "one body is created for each present collision category")
	_check(physics.shape_count() == 4, "merged rectangles and two half covers create four shapes")
	_check(physics.shape_count_for_kind(WorldBlockerGeometry.Kind.HALF_COVER) == 2, "two half covers use two circle shape owners")
	var owners_use_container := true
	for body_candidate in physics.find_children("*", "StaticBody2D", true, false):
		var body := body_candidate as StaticBody2D
		for owner_id in body.get_shape_owners():
			owners_use_container = owners_use_container and body.shape_owner_get_owner(owner_id) == physics
	_check(owners_use_container, "shape owners outlive their body during streamed-scene teardown")
	_check(physics.find_children("*", "CollisionShape2D", true, false).is_empty(), "batched collision creates no CollisionShape2D nodes")
	_check(physics.collision_layers() == PackedInt32Array([257, 513, 1025]), "wall, window, and half-cover bodies retain legacy layers")
	physics.clear()
	_check(physics.body_count() == 0 and physics.shape_count() == 0, "clear releases every batched collision body")
	physics.queue_free()
