class_name CityYardSupportMap
extends RefCounted
## Presentation-only wrapped bytes. No Game, autoload, texture or asset dependency.
## Callers max-composite household proposals before replacing a chunk.

const SIZE := 256
var _bytes := PackedByteArray()


func _init() -> void:
	_bytes.resize(SIZE * SIZE)
	clear()


func replace_chunk(coord: Vector2i, cells_per_chunk: int, proposed: PackedByteArray,
		semantic: PackedInt32Array, care: PackedByteArray) -> bool:
	if not _valid_dimension(cells_per_chunk):
		return false
	var origin := _origin(coord, cells_per_chunk)
	clear_rect(Rect2i(origin, Vector2i(cells_per_chunk, cells_per_chunk)))
	var count := cells_per_chunk * cells_per_chunk
	if proposed.size() != count or semantic.size() != count or care.size() != count:
		return false
	for y in cells_per_chunk:
		var row := ((origin.y + y) % SIZE) * SIZE
		for x in cells_per_chunk:
			var local := y * cells_per_chunk + x
			if semantic[local] == 6 and care[local] == 0:
				_bytes[row + (origin.x + x) % SIZE] = proposed[local]
	return true


func clear_rect(rect: Rect2i) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	# More than one complete wrap touches the same cells again. Never iterate
	# unbounded supplied extents or add an extent to an extreme Vector2i position.
	var width := mini(rect.size.x, SIZE)
	var height := mini(rect.size.y, SIZE)
	var start_x := posmod(rect.position.x, SIZE)
	var start_y := posmod(rect.position.y, SIZE)
	for y in height:
		var row := ((start_y + y) % SIZE) * SIZE
		for x in width:
			_bytes[row + (start_x + x) % SIZE] = 0


func clear() -> void:
	_bytes.fill(0)


func signature(coord: Vector2i, cells_per_chunk: int) -> PackedByteArray:
	var result := PackedByteArray()
	if not _valid_dimension(cells_per_chunk):
		return result
	result.resize(cells_per_chunk * cells_per_chunk)
	var origin := _origin(coord, cells_per_chunk)
	for y in cells_per_chunk:
		var row := ((origin.y + y) % SIZE) * SIZE
		for x in cells_per_chunk:
			result[y * cells_per_chunk + x] = _bytes[row + (origin.x + x) % SIZE]
	return result


func snapshot_image() -> Image:
	return Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_L8, _bytes.duplicate())


func _valid_dimension(n: int) -> bool:
	return n > 0 and n <= SIZE


func _origin(coord: Vector2i, n: int) -> Vector2i:
	# Reduce before multiplication: valid n keeps each intermediate below 65536.
	return Vector2i(posmod(posmod(coord.x, SIZE) * n, SIZE),
		posmod(posmod(coord.y, SIZE) * n, SIZE))
