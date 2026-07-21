extends Node

# Central registry + lightweight spatial hashing for enemies.
# Goal: avoid repeated get_nodes_in_group("enemies") scans in hot paths.

@export var cell_size: float = 64.0

# Internal storage (do not modify returned arrays from outside)
var _enemies: Array = [] # Array[Enemy]
var _id_to_index: Dictionary = {} # int -> int
var _enemy_cell: Dictionary = {}  # int -> Vector2i
var _buckets: Dictionary = {}     # Vector2i -> Array[Enemy]
var _scene_counts: Dictionary = {} # String -> int

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(true)

func register(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	if _id_to_index.has(id):
		return

	_id_to_index[id] = _enemies.size()
	_enemies.append(enemy)

	# scene counts (for spawner per-type caps)
	var p := ""
	if enemy is Node:
		p = (enemy as Node).scene_file_path
	if p != "":
		_scene_counts[p] = int(_scene_counts.get(p, 0)) + 1

	var cell := _cell_for_pos((enemy as Node2D).global_position if enemy is Node2D else Vector2.ZERO)
	_enemy_cell[id] = cell
	_bucket_add(cell, enemy)

func unregister(enemy: Node) -> void:
	if enemy == null:
		return
	var id := enemy.get_instance_id()
	if not _id_to_index.has(id):
		return

	# scene counts
	var p := (enemy as Node).scene_file_path
	if p != "" and _scene_counts.has(p):
		var v: int = int(_scene_counts[p]) - 1
		if v <= 0:
			_scene_counts.erase(p)
		else:
			_scene_counts[p] = v

	# buckets
	if _enemy_cell.has(id):
		var cell: Vector2i = _enemy_cell[id]
		_bucket_remove(cell, enemy)
		_enemy_cell.erase(id)

	# swap-remove from list
	var idx: int = int(_id_to_index[id])
	var last_idx: int = _enemies.size() - 1
	if idx != last_idx:
		var last_enemy: Node = _enemies[last_idx]
		_enemies[idx] = last_enemy
		_id_to_index[last_enemy.get_instance_id()] = idx
	_enemies.pop_back()
	_id_to_index.erase(id)

func update_enemy(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	if not _id_to_index.has(id):
		return
	if not (enemy is Node2D):
		return
	var new_cell := _cell_for_pos((enemy as Node2D).global_position)
	var old_cell: Vector2i = _enemy_cell.get(id, new_cell)
	if new_cell == old_cell:
		return
	_enemy_cell[id] = new_cell
	_bucket_remove(old_cell, enemy)
	_bucket_add(new_cell, enemy)

func alive_count() -> int:
	return _enemies.size()

func alive_count_for_scene(scene: PackedScene) -> int:
	if scene == null:
		return 0
	var p := scene.resource_path
	if p == "":
		return 0
	return int(_scene_counts.get(p, 0))

func get_all() -> Array:
	# WARNING: do not mutate the returned array.
	return _enemies

func nearest_enemy(origin: Vector2, max_dist: float = 999999.0, exclude: Node = null) -> Node2D:
	var best: Node2D = null
	var best_d2: float = max_dist * max_dist

	var cs := maxf(cell_size, 1.0)
	var c0 := Vector2i(floori(origin.x / cs), floori(origin.y / cs))
	var cr: int = maxi(1, ceili(max_dist / cs))

	for oy in range(-cr, cr + 1):
		for ox in range(-cr, cr + 1):
			var cell := Vector2i(c0.x + ox, c0.y + oy)
			var arr = _buckets.get(cell)
			if arr == null:
				continue
			for n in arr:
				var e := n as Node2D
				if e == null or not is_instance_valid(e):
					continue
				if exclude != null and e == exclude:
					continue
				if "dead" in e and bool(e.get("dead")):
					continue
				var d2 := origin.distance_squared_to(e.global_position)
				if d2 < best_d2:
					best_d2 = d2
					best = e

	return best

func first_in_radius(origin: Vector2, radius: float, exclude: Node = null) -> Node2D:
	var r2: float = radius * radius
	var cs := maxf(cell_size, 1.0)
	var c0 := Vector2i(floori(origin.x / cs), floori(origin.y / cs))
	var cr: int = maxi(1, ceili(radius / cs))

	for oy in range(-cr, cr + 1):
		for ox in range(-cr, cr + 1):
			var cell := Vector2i(c0.x + ox, c0.y + oy)
			var arr = _buckets.get(cell)
			if arr == null:
				continue
			for n in arr:
				var e := n as Node2D
				if e == null or not is_instance_valid(e):
					continue
				if exclude != null and e == exclude:
					continue
				if "dead" in e and bool(e.get("dead")):
					continue
				if origin.distance_squared_to(e.global_position) <= r2:
					return e
	return null

func gather_in_radius(origin: Vector2, radius: float, out: Array) -> void:
	if out == null:
		return
	out.clear()

	var r2: float = radius * radius
	var cs := maxf(cell_size, 1.0)
	var c0 := Vector2i(floori(origin.x / cs), floori(origin.y / cs))
	var cr: int = maxi(1, ceili(radius / cs))

	for oy in range(-cr, cr + 1):
		for ox in range(-cr, cr + 1):
			var cell := Vector2i(c0.x + ox, c0.y + oy)
			var arr = _buckets.get(cell)
			if arr == null:
				continue
			for n in arr:
				var e := n as Node2D
				if e == null or not is_instance_valid(e):
					continue
				if "dead" in e and bool(e.get("dead")):
					continue
				if origin.distance_squared_to(e.global_position) <= r2:
					out.append(e)

func sample_sep(e: Node2D, radius: float, max_neighbors: int = 8) -> Vector2:
	if e == null or not is_instance_valid(e):
		return Vector2.ZERO
	if radius <= 0.0:
		return Vector2.ZERO

	var pos: Vector2 = e.global_position
	var r2: float = radius * radius
	var cs := maxf(cell_size, 1.0)
	var c0 := Vector2i(floori(pos.x / cs), floori(pos.y / cs))
	var cr: int = maxi(1, ceili(radius / cs))

	var sum: Vector2 = Vector2.ZERO
	var count: int = 0

	for oy in range(-cr, cr + 1):
		for ox in range(-cr, cr + 1):
			var cell := Vector2i(c0.x + ox, c0.y + oy)
			var arr = _buckets.get(cell)
			if arr == null:
				continue
			for n in arr:
				var other := n as Node2D
				if other == null or other == e or not is_instance_valid(other):
					continue
				if "dead" in other and bool(other.get("dead")):
					continue
				var d: Vector2 = pos - other.global_position
				var d2: float = d.length_squared()
				if d2 <= 0.0001 or d2 > r2:
					continue
				sum += d / d2
				count += 1
				if count >= max_neighbors:
					break
			if count >= max_neighbors:
				break
		if count >= max_neighbors:
			break

	return (sum.normalized() if sum.length_squared() > 0.0001 else Vector2.ZERO)

func count_allies(e: Node2D, radius: float, max_count: int = 999) -> int:
	if e == null or not is_instance_valid(e):
		return 0
	if radius <= 0.0:
		return 0

	var pos: Vector2 = e.global_position
	var r2: float = radius * radius
	var cs := maxf(cell_size, 1.0)
	var c0 := Vector2i(floori(pos.x / cs), floori(pos.y / cs))
	var cr: int = maxi(1, ceili(radius / cs))

	var count: int = 0

	for oy in range(-cr, cr + 1):
		for ox in range(-cr, cr + 1):
			var cell := Vector2i(c0.x + ox, c0.y + oy)
			var arr = _buckets.get(cell)
			if arr == null:
				continue
			for n in arr:
				var other := n as Node2D
				if other == null or other == e or not is_instance_valid(other):
					continue
				if "dead" in other and bool(other.get("dead")):
					continue
				if pos.distance_squared_to(other.global_position) > r2:
					continue
				count += 1
				if count >= max_count:
					return count
	return count

func _cell_for_pos(pos: Vector2) -> Vector2i:
	var cs := maxf(cell_size, 1.0)
	return Vector2i(floori(pos.x / cs), floori(pos.y / cs))

func _bucket_add(cell: Vector2i, enemy: Node) -> void:
	var arr = _buckets.get(cell)
	if arr == null:
		arr = []
		_buckets[cell] = arr
	arr.append(enemy)

func _bucket_remove(cell: Vector2i, enemy: Node) -> void:
	var arr = _buckets.get(cell)
	if arr == null:
		return
	arr.erase(enemy)
	if arr.is_empty():
		_buckets.erase(cell)
