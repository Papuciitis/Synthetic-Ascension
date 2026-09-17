class_name EnemySpatialGrid
extends RefCounted

var cell_size: float
var _buckets: Dictionary = {} # Vector2i -> Array[int]
var _slot_cells: Dictionary = {} # int -> Vector2i
var _slot_bucket_indices: Dictionary = {} # int -> int


func _init(p_cell_size: float = 64.0) -> void:
	cell_size = maxf(p_cell_size, 1.0)


func _cell_for(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / cell_size), floori(position.y / cell_size))


func insert(slot: int, position: Vector2) -> void:
	if slot < 0:
		return
	if _slot_cells.has(slot):
		move(slot, position)
		return
	var cell := _cell_for(position)
	var bucket: Array = _buckets.get(cell, [])
	_slot_cells[slot] = cell
	_slot_bucket_indices[slot] = bucket.size()
	bucket.append(slot)
	_buckets[cell] = bucket


func move(slot: int, position: Vector2) -> void:
	var next_cell := _cell_for(position)
	if _slot_cells.has(slot) and _slot_cells[slot] == next_cell:
		return
	remove(slot)
	insert(slot, position)


func remove(slot: int) -> void:
	if not _slot_cells.has(slot):
		return
	var cell: Vector2i = _slot_cells[slot]
	var bucket: Array = _buckets[cell]
	var index: int = int(_slot_bucket_indices[slot])
	var last_index := bucket.size() - 1
	if index != last_index:
		var moved_slot: int = int(bucket[last_index])
		bucket[index] = moved_slot
		_slot_bucket_indices[moved_slot] = index
	bucket.pop_back()
	if bucket.is_empty():
		_buckets.erase(cell)
	else:
		_buckets[cell] = bucket
	_slot_cells.erase(slot)
	_slot_bucket_indices.erase(slot)


func gather_candidate_slots(origin: Vector2, radius: float, out: Array[int]) -> void:
	out.clear()
	if _buckets.is_empty():
		return
	var safe_radius := maxf(radius, 0.0)
	var center := _cell_for(origin)
	var cell_radius := maxi(1, ceili(safe_radius / cell_size))
	var diameter := 2 * cell_radius + 1
	if diameter * diameter > _buckets.size():
		for cell_variant in _buckets.keys():
			var cell: Vector2i = cell_variant
			if absi(cell.x - center.x) > cell_radius or absi(cell.y - center.y) > cell_radius:
				continue
			var bucket: Array = _buckets[cell]
			for slot_variant in bucket:
				out.append(int(slot_variant))
		return
	for y_offset in range(-cell_radius, cell_radius + 1):
		for x_offset in range(-cell_radius, cell_radius + 1):
			var cell := Vector2i(center.x + x_offset, center.y + y_offset)
			var bucket_variant: Variant = _buckets.get(cell)
			if bucket_variant == null:
				continue
			var bucket: Array = bucket_variant
			for slot_variant in bucket:
				out.append(int(slot_variant))


func has_slot(slot: int) -> bool:
	return _slot_cells.has(slot)


func active_cell_count() -> int:
	return _buckets.size()


func max_cell_occupancy() -> int:
	var maximum := 0
	for bucket_variant in _buckets.values():
		var bucket: Array = bucket_variant
		maximum = maxi(maximum, bucket.size())
	return maximum


func clear() -> void:
	_buckets.clear()
	_slot_cells.clear()
	_slot_bucket_indices.clear()
