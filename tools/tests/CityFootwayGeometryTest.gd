extends Node2D
## A real door on an inner L edge must get its approach there, not at box.top.

const FIXTURE := preload("res://tools/tests/CitySceneDepthFixture.gd")
const FRONTAGE := preload("res://scenes/world/buildings/CityStreetFrontage.gd")
var _passes := 0
var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if ok: _passes += 1
	else:
		_failures += 1
		push_error(label)


func _run() -> void:
	var old_segment := Global.attempt_segment
	Global.attempt_segment = 2
	for direction: Vector2i in [Vector2i.DOWN,Vector2i.UP]:
		var chunk := Node2D.new()
		add_child(chunk)
		var fixture := FIXTURE.create(chunk,direction)
		var original_outline := (fixture.outline as PackedVector2Array).duplicate()
		var placed: Array[Rect2i] = [FIXTURE.BED_RECT]
		FRONTAGE.compose(chunk,placed,64,32)
		var group := chunk.get_node_or_null("ConnectedStreetFrontages")
		_check(group != null and group.get_child_count() > 0,"production composer supplies actual frontages for "+str(direction))
		if group != null:
			if direction == Vector2i.DOWN:
				_check(FIXTURE.footway_covers(group,Vector2(544,1120)),"actual bed south door retains an opaque geometrical approach core")
				_check(not FIXTURE.footway_covers(group,Vector2(544,528)),"south entry does not manufacture pavement behind its roof")
			else:
				_check(FIXTURE.footway_covers(group,Vector2(288,736)),"north-facing inner L door gets a landing on its real exposed edge")
				_check(not FIXTURE.footway_covers(group,Vector2(640,528)),"inner L entry does not paint a phantom landing along the bounding-box north wall")
			var outside_interiors := true
			for child: Node in group.get_children():
				if child is Polygon2D and not Geometry2D.intersect_polygons(child.polygon,original_outline).is_empty(): outside_interiors = false
			_check(outside_interiors,"actual footway geometry excludes every point of the real occupied outline")
		_check((fixture.roof as RoofOverlay).footprint_outline_px == original_outline,"presentation does not mutate the exact source footprint")
		chunk.queue_free()
		await get_tree().process_frame
	Global.attempt_segment = old_segment
	print("CityFootwayGeometryTest: %d passed, %d failed" % [_passes,_failures])
	get_tree().quit(1 if _failures > 0 else 0)
