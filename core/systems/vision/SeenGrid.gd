extends RefCounted
class_name SeenGrid

# Chunked persistent "seen" memory.
# Stores 1 byte per cell (0/1) in chunk_size x chunk_size chunks.

var chunk_size: int = 32
var _chunks: Dictionary = {} # Vector2i(chunk_x, chunk_y) -> PackedByteArray

func _init(p_chunk_size: int = 32) -> void:
	chunk_size = max(1, p_chunk_size)

func _chunk_key(cell: Vector2i) -> Vector2i:
	# Safe for negatives too (procedural worlds sometimes go negative later).
	return Vector2i(
		floori(float(cell.x) / float(chunk_size)),
		floori(float(cell.y) / float(chunk_size))
	)

func _local_in_chunk(cell: Vector2i, key: Vector2i) -> Vector2i:
	return Vector2i(cell.x - key.x * chunk_size, cell.y - key.y * chunk_size)

func _get_or_make_chunk(key: Vector2i) -> PackedByteArray:
	var arr: PackedByteArray = _chunks.get(key, PackedByteArray())
	if arr.is_empty():
		arr.resize(chunk_size * chunk_size)
		_chunks[key] = arr
	return arr

func mark_seen(cell: Vector2i) -> void:
	var key := _chunk_key(cell)
	var local := _local_in_chunk(cell, key)
	if local.x < 0 or local.y < 0 or local.x >= chunk_size or local.y >= chunk_size:
		return
	var arr := _get_or_make_chunk(key)
	var idx := local.y * chunk_size + local.x
	arr[idx] = 1
	_chunks[key] = arr

func is_seen(cell: Vector2i) -> bool:
	var key := _chunk_key(cell)
	if not _chunks.has(key):
		return false
	var local := _local_in_chunk(cell, key)
	if local.x < 0 or local.y < 0 or local.x >= chunk_size or local.y >= chunk_size:
		return false
	var arr: PackedByteArray = _chunks[key]
	var idx := local.y * chunk_size + local.x
	return arr[idx] != 0

func clear() -> void:
	_chunks.clear()
