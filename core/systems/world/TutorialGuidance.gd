extends Node2D

# Segment 1 guidance shares the authored collision plan. A short trail leads
# through doors and around cover; the existing HUD arrow points at its next turn.
const MARKER_COLOR := Color("f5cc78")
const MARKER_FONT := preload("res://assets/fonts/eb_garamond/EBGaramond-Variable.ttf")
const REFRESH_SECONDS := 0.25
const MARKER_RESPONSE := 8.0
const MARKER_SPEED_CELLS := 8.0

var _grid := AStarGrid2D.new()
var _cell_size: int = 64
var _player: Node2D = null
var _destination := Vector2.INF
var _tracked_target: Node2D = null
var _caption: String = ""
var _path: Array[Vector2i] = []
var _next_point := Vector2.INF
var _marker_world := Vector2.INF
var _marker_route := PackedVector2Array()
var _goal_world := Vector2.INF
var _refresh_left: float = 0.0
var _last_player_cell := Vector2i(-10000, -10000)
var _last_target_cell := Vector2i(-10000, -10000)


func configure(cell_size: int, regions: Array[Rect2i], blockers: Array[Dictionary]) -> void:
	_cell_size = cell_size
	var bounds: Rect2i = regions[0]
	for region in regions:
		bounds = bounds.merge(region)
	_grid.region = bounds
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_grid.update()
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			var playable := false
			for region in regions:
				if region.has_point(cell):
					playable = true
					break
			_grid.set_point_solid(cell, not playable)
	for cells in blockers:
		for cell: Vector2i in cells:
			if bounds.has_point(cell):
				_grid.set_point_solid(cell)
	_last_player_cell = Vector2i(-10000, -10000)
	_marker_route.clear()
	_refresh_path()


func set_destination(position_world: Vector2, caption: String, tracked_target: Node2D = null) -> void:
	_destination = position_world
	_tracked_target = tracked_target
	_caption = caption
	queue_redraw()
	_last_target_cell = Vector2i(-10000, -10000)
	_refresh_path()
	set_process(_destination != Vector2.INF)


func _ready() -> void:
	z_index = 50
	_player = get_tree().get_first_node_in_group(&"player") as Node2D
	set_process(_destination != Vector2.INF)


func _exit_tree() -> void:
	if Global != null and Global.objective_target_pos == _marker_world:
		Global.objective_target_pos = Vector2.INF


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_SECONDS
		_refresh_path()
	if not _path.is_empty():
		_update_next_point()
	_advance_marker(delta)


func _refresh_path() -> void:
	if _destination == Vector2.INF:
		_path.clear()
		_publish_next(Vector2.INF)
		return
	if _tracked_target != null and is_instance_valid(_tracked_target):
		_destination = _tracked_target.global_position
	if _player == null or not is_instance_valid(_player):
		return
	var start := Vector2i((_player.global_position / _cell_size).floor())
	var finish := Vector2i((_destination / _cell_size).floor())
	if start == _last_player_cell and finish == _last_target_cell:
		return
	_last_player_cell = start
	_last_target_cell = finish
	_path.clear()
	queue_redraw()
	_goal_world = Vector2.INF
	if _grid.region.has_point(start) and _grid.region.has_point(finish) and not _grid.is_point_solid(start):
		var goals: Array[Vector2i] = [finish]
		if _grid.is_point_solid(finish):
			# Authored trigger areas are wider than one cell; a cover cluster
			# can occupy their centre. An adjacent floor cell still reaches
			# that trigger (and is within an alignment node's interaction radius).
			goals.clear()
			for y in range(finish.y - 1, finish.y + 2):
				for x in range(finish.x - 1, finish.x + 2):
					var nearby := Vector2i(x, y)
					if _grid.region.has_point(nearby) and not _grid.is_point_solid(nearby):
						goals.append(nearby)
			goals.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _cell_center(a).distance_squared_to(_destination) < _cell_center(b).distance_squared_to(_destination))
		for goal in goals:
			_path = _grid.get_id_path(start, goal)
			if not _path.is_empty():
				_goal_world = _destination if goal == finish else _cell_center(goal)
				break
	if _path.is_empty():
		# Do not direct the player through a closed seal or an unwalkable cell.
		_publish_next(Vector2.INF)
		return
	_update_next_point()


func _update_next_point() -> void:
	if _path.size() == 1:
		_publish_next(_goal_world)
		return
	# Project onto the cached route so sub-cell player movement also advances
	# the lookahead. Keep it on the current straight leg until its next turn.
	var closest_index := 0
	var closest_point := _cell_center(_path[0])
	var closest_distance := INF
	for index in range(_path.size() - 1):
		var start := _cell_center(_path[index])
		var edge := _cell_center(_path[index + 1]) - start
		var fraction := clampf((_player.global_position - start).dot(edge) / edge.length_squared(), 0.0, 1.0)
		var point := start + edge * fraction
		var distance := point.distance_squared_to(_player.global_position)
		if distance < closest_distance:
			closest_index = index
			closest_point = point
			closest_distance = distance
	var direction := _path[closest_index + 1] - _path[closest_index]
	var corner_index := closest_index + 1
	while corner_index < _path.size() - 1 and _path[corner_index + 1] - _path[corner_index] == direction:
		corner_index += 1
	var corner := _cell_center(_path[corner_index])
	var lookahead := 4.0 * _cell_size
	if closest_point.distance_to(corner) <= lookahead:
		_publish_next(_goal_world if corner_index == _path.size() - 1 else corner)
	else:
		_publish_next(closest_point + Vector2(direction) * lookahead)


func _publish_next(position_world: Vector2) -> void:
	var previous_cell := Vector2i((_next_point / _cell_size).floor()) if _next_point != Vector2.INF else Vector2i(-10000, -10000)
	_next_point = position_world
	if position_world == Vector2.INF:
		_marker_route.clear()
		_marker_world = Vector2.INF
		_publish_marker()
		return
	if _marker_world == Vector2.INF:
		_marker_world = position_world
		_publish_marker()
	elif not _marker_route.is_empty() and previous_cell == Vector2i((position_world / _cell_size).floor()):
		_marker_route[-1] = position_world
	elif not _marker_world.is_equal_approx(position_world):
		_route_marker(position_world)


func _route_marker(position_world: Vector2) -> void:
	_marker_route.clear()
	var start := Vector2i((_marker_world / _cell_size).floor())
	var finish := Vector2i((position_world / _cell_size).floor())
	var route: Array[Vector2i] = []
	if _grid.region.has_point(start) and not _grid.is_point_solid(start):
		route = _grid.get_id_path(start, finish)
	if route.is_empty():
		# A rebuilt seal can invalidate the old marker's floor cell. Place the
		# replacement on the newly validated route instead of crossing that seal.
		_marker_world = position_world
		_publish_marker()
		return
	if route.size() > 1:
		var centre := _cell_center(start)
		var direction := Vector2(route[1] - start)
		var offset := _marker_world - centre
		# Do not retreat to a cell centre when already travelling toward the
		# next cell. At a turn, visit the centre before changing direction.
		if not is_zero_approx(offset.cross(direction)) or offset.dot(direction) < 0.0:
			_marker_route.append(centre)
	for index in range(1, route.size()):
		_marker_route.append(_cell_center(route[index]))
	if _marker_route.is_empty():
		_marker_route.append(position_world)
	else:
		_marker_route[-1] = position_world


func _advance_marker(delta: float) -> void:
	if _marker_route.is_empty():
		return
	var remaining := 0.0
	var previous := _marker_world
	for point in _marker_route:
		remaining += previous.distance_to(point)
		previous = point
	var budget := minf(_cell_size * MARKER_SPEED_CELLS * delta, remaining * (1.0 - exp(-MARKER_RESPONSE * delta)))
	if remaining < 0.5:
		budget = remaining
	while not _marker_route.is_empty():
		var point := _marker_route[0]
		var distance := _marker_world.distance_to(point)
		if distance > budget:
			_marker_world = _marker_world.move_toward(point, budget)
			break
		_marker_world = point
		_marker_route.remove_at(0)
		budget -= distance
	_publish_marker()


func _publish_marker() -> void:
	if Global != null:
		Global.objective_target_pos = _marker_world
	queue_redraw()


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * _cell_size


func _draw() -> void:
	if _marker_world == Vector2.INF:
		return
	for index in range(1, mini(9, _path.size())):
		var point := to_local(_cell_center(_path[index]))
		draw_circle(point, 4.0, Color(MARKER_COLOR, 0.65))
	var marker := to_local(_marker_world)
	draw_circle(marker, 24.0, Color(0.02, 0.03, 0.04, 0.75))
	draw_arc(marker, 19.0, 0.0, TAU, 32, MARKER_COLOR, 3.0, true)
	draw_polyline(PackedVector2Array([marker + Vector2(-7, 0), marker + Vector2(0, -7), marker + Vector2(7, 0), marker + Vector2(0, 7), marker + Vector2(-7, 0)]), MARKER_COLOR, 2.5, true)
	var text := _caption if _marker_world.distance_squared_to(_goal_world) < 1.0 else "FOLLOW"
	var text_size := MARKER_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19)
	draw_string_outline(MARKER_FONT, marker + Vector2(-text_size.x * 0.5, -32), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, 5, Color(0.02, 0.03, 0.04))
	draw_string(MARKER_FONT, marker + Vector2(-text_size.x * 0.5, -32), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, MARKER_COLOR)
