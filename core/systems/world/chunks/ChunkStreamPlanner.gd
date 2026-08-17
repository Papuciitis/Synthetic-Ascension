extends RefCounted
class_name ChunkStreamPlanner


static func desired_coords(center: Vector2i, visible_world_rect: Rect2, chunk_size: int, prefetch: int) -> Array[Vector2i]:
	var safe_size := float(maxi(1, chunk_size))
	var margin := maxi(0, prefetch)
	var minimum := Vector2i(
		floori(visible_world_rect.position.x / safe_size),
		floori(visible_world_rect.position.y / safe_size)
	) - Vector2i.ONE * margin
	var inclusive_end := visible_world_rect.end - Vector2(0.001, 0.001)
	var maximum := Vector2i(
		floori(inclusive_end.x / safe_size),
		floori(inclusive_end.y / safe_size)
	) + Vector2i.ONE * margin
	minimum.x = mini(minimum.x, center.x)
	minimum.y = mini(minimum.y, center.y)
	maximum.x = maxi(maximum.x, center.x)
	maximum.y = maxi(maximum.y, center.y)
	var result: Array[Vector2i] = []
	for y in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			result.append(Vector2i(x, y))
	return result


static func ordered_missing(desired: Array[Vector2i], loaded: Dictionary, center: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for coord in desired:
		if not loaded.has(coord):
			result.append(coord)
	result.sort_custom(func(first: Vector2i, second: Vector2i) -> bool:
		var first_distance := maxi(absi(first.x - center.x), absi(first.y - center.y))
		var second_distance := maxi(absi(second.x - center.x), absi(second.y - center.y))
		if first_distance != second_distance:
			return first_distance < second_distance
		if first.y != second.y:
			return first.y < second.y
		return first.x < second.x
	)
	return result
