extends Node2D
class_name ChunkBlockPhysics

const WALL_LAYER := 257
const WINDOW_LAYER := 513
const HALF_COVER_LAYER := 1025

var _bodies: Array[StaticBody2D] = []
var _body_by_category: Dictionary = {}


func build(data: ChunkBuildData, cell_size: int) -> void:
	clear()
	var safe_cell_size := maxi(1, cell_size)
	_add_rectangle_kind(data, WorldBlockerGeometry.Kind.SOLID_CELL, safe_cell_size, WALL_LAYER, WorldBlockerGeometry.Kind.WALL)
	_add_rectangle_kind(data, WorldBlockerGeometry.Kind.WALL, safe_cell_size, WALL_LAYER, WorldBlockerGeometry.Kind.WALL)
	_add_rectangle_kind(data, WorldBlockerGeometry.Kind.FENCE, safe_cell_size, WALL_LAYER, WorldBlockerGeometry.Kind.WALL)
	_add_rectangle_kind(data, WorldBlockerGeometry.Kind.WINDOW, safe_cell_size, WINDOW_LAYER, WorldBlockerGeometry.Kind.WINDOW)
	_add_half_covers(data, safe_cell_size)


func clear() -> void:
	for body in _bodies:
		if is_instance_valid(body):
			if body.get_parent() == self:
				remove_child(body)
			body.queue_free()
	_bodies.clear()
	_body_by_category.clear()


func body_count() -> int:
	var total := 0
	for body in _bodies:
		if is_instance_valid(body) and body.get_parent() == self:
			total += 1
	return total


func shape_count() -> int:
	var total := 0
	for body in _bodies:
		total += _body_shape_count(body)
	return total


func shape_count_for_kind(kind: int) -> int:
	var body := _body_by_category.get(_category_for_kind(kind)) as StaticBody2D
	return _body_shape_count(body)


func collision_layers() -> PackedInt32Array:
	var layers := PackedInt32Array()
	for body in _bodies:
		layers.append(body.collision_layer)
	return layers


static func rectangles_for_kind(data: ChunkBuildData, kind: int, cell_size: int) -> Array[Rect2]:
	var rectangles: Array[Rect2] = []
	var horizontal: Array[Vector3] = [] # line, start, end
	var vertical: Array[Vector3] = [] # line, start, end
	var safe_cell_size := float(maxi(1, cell_size))
	var half_cell := safe_cell_size * 0.5
	var thickness := _thickness_for_kind(kind)
	var post_size := _post_size_for_kind(kind)
	for index in data.occupied_indices():
		var cell := data.cell_for_index(index)
		if data.kind_at(cell) != kind:
			continue
		var center := (Vector2(cell) + Vector2(0.5, 0.5)) * safe_cell_size
		if kind == WorldBlockerGeometry.Kind.SOLID_CELL:
			rectangles.append(Rect2(center - Vector2.ONE * half_cell, Vector2.ONE * safe_cell_size))
			continue
		var mask := data.mask_at(cell)
		if mask == 0:
			rectangles.append(Rect2(center - Vector2.ONE * post_size * 0.5, Vector2.ONE * post_size))
			continue
		if (mask & WorldBlockerGeometry.N) != 0:
			vertical.append(Vector3(center.x, center.y - half_cell, center.y))
		if (mask & WorldBlockerGeometry.E) != 0:
			horizontal.append(Vector3(center.y, center.x, center.x + half_cell))
		if (mask & WorldBlockerGeometry.S) != 0:
			vertical.append(Vector3(center.x, center.y, center.y + half_cell))
		if (mask & WorldBlockerGeometry.W) != 0:
			horizontal.append(Vector3(center.y, center.x - half_cell, center.x))
	horizontal.sort_custom(_sort_intervals)
	vertical.sort_custom(_sort_intervals)
	_append_merged_intervals(rectangles, horizontal, thickness, true)
	_append_merged_intervals(rectangles, vertical, thickness, false)
	return rectangles


func _add_rectangle_kind(data: ChunkBuildData, kind: int, cell_size: int, layer: int, category: int) -> void:
	var rectangles := rectangles_for_kind(data, kind, cell_size)
	if rectangles.is_empty():
		return
	var body := _body_for_category(category, layer)
	for rectangle in rectangles:
		var shape := RectangleShape2D.new()
		shape.size = rectangle.size
		_add_shape(body, shape, Transform2D(0.0, rectangle.get_center()))


func _add_half_covers(data: ChunkBuildData, cell_size: int) -> void:
	var category := WorldBlockerGeometry.Kind.HALF_COVER
	var body: StaticBody2D
	for index in data.occupied_indices():
		var cell := data.cell_for_index(index)
		if data.kind_at(cell) != category:
			continue
		if body == null:
			body = _body_for_category(category, HALF_COVER_LAYER)
		var shape := CircleShape2D.new()
		shape.radius = WorldBlockerGeometry.HALF_COVER_RADIUS
		var center := (Vector2(cell) + Vector2(0.5, 0.5)) * float(cell_size)
		_add_shape(body, shape, Transform2D(0.0, center))


func _body_for_category(category: int, layer: int) -> StaticBody2D:
	if _body_by_category.has(category):
		return _body_by_category[category] as StaticBody2D
	var body := StaticBody2D.new()
	body.name = _category_name(category)
	body.collision_layer = layer
	body.collision_mask = 0
	add_child(body)
	_bodies.append(body)
	_body_by_category[category] = body
	return body


func _add_shape(body: StaticBody2D, shape: Shape2D, transform: Transform2D) -> void:
	var owner_id: int = body.create_shape_owner(body)
	body.shape_owner_set_transform(owner_id, transform)
	body.shape_owner_add_shape(owner_id, shape)


func _body_shape_count(body: StaticBody2D) -> int:
	if not is_instance_valid(body):
		return 0
	var total := 0
	for owner_id in body.get_shape_owners():
		total += body.shape_owner_get_shape_count(owner_id)
	return total


static func _append_merged_intervals(rectangles: Array[Rect2], intervals: Array[Vector3], thickness: float, horizontal: bool) -> void:
	if intervals.is_empty():
		return
	var line := intervals[0].x
	var start := intervals[0].y
	var finish := intervals[0].z
	for index in range(1, intervals.size()):
		var interval := intervals[index]
		if is_equal_approx(interval.x, line) and interval.y <= finish + 0.001:
			finish = maxf(finish, interval.z)
			continue
		append_interval_rect(rectangles, line, start, finish, thickness, horizontal)
		line = interval.x
		start = interval.y
		finish = interval.z
	append_interval_rect(rectangles, line, start, finish, thickness, horizontal)


static func append_interval_rect(rectangles: Array[Rect2], line: float, start: float, finish: float, thickness: float, horizontal: bool) -> void:
	if horizontal:
		rectangles.append(Rect2(start, line - thickness * 0.5, finish - start, thickness))
	else:
		rectangles.append(Rect2(line - thickness * 0.5, start, thickness, finish - start))


static func _sort_intervals(first: Vector3, second: Vector3) -> bool:
	if not is_equal_approx(first.x, second.x):
		return first.x < second.x
	if not is_equal_approx(first.y, second.y):
		return first.y < second.y
	return first.z < second.z


static func _thickness_for_kind(kind: int) -> float:
	return WorldBlockerGeometry.FENCE_THICKNESS if kind == WorldBlockerGeometry.Kind.FENCE else WorldBlockerGeometry.WALL_THICKNESS


static func _post_size_for_kind(kind: int) -> float:
	return WorldBlockerGeometry.FENCE_POST_SIZE if kind == WorldBlockerGeometry.Kind.FENCE else WorldBlockerGeometry.WALL_POST_SIZE


static func _category_for_kind(kind: int) -> int:
	if kind == WorldBlockerGeometry.Kind.WINDOW:
		return WorldBlockerGeometry.Kind.WINDOW
	if kind == WorldBlockerGeometry.Kind.HALF_COVER:
		return WorldBlockerGeometry.Kind.HALF_COVER
	return WorldBlockerGeometry.Kind.WALL


static func _category_name(category: int) -> String:
	if category == WorldBlockerGeometry.Kind.WINDOW:
		return "WindowBlockPhysics"
	if category == WorldBlockerGeometry.Kind.HALF_COVER:
		return "HalfCoverBlockPhysics"
	return "WallBlockPhysics"
