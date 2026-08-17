extends RefCounted
class_name ChunkBuildData

var coord: Vector2i
var cells_per_side: int
var blocker_kind_code := PackedByteArray()
var blocker_mask := PackedByteArray()
var blocker_variant := PackedByteArray()
var floor_rect_and_style := PackedInt32Array()
var floor_alpha := PackedFloat32Array()
var interactive_nodes: Array[Node] = []

var _occupied := PackedInt32Array()


func _init(p_coord: Vector2i, p_cells_per_side: int) -> void:
	coord = p_coord
	cells_per_side = maxi(1, p_cells_per_side)
	var count := cells_per_side * cells_per_side
	blocker_kind_code.resize(count)
	blocker_mask.resize(count)
	blocker_variant.resize(count)


func add_blocker(cell: Vector2i, kind: int, mask: int = 0, variant: int = 0) -> bool:
	var index := _index(cell)
	if index < 0 or blocker_kind_code[index] != 0:
		return false
	blocker_kind_code[index] = clampi(kind + 1, 1, 255)
	blocker_mask[index] = mask & 0xFF
	blocker_variant[index] = variant & 0xFF
	_occupied.append(index)
	return true


func kind_at(cell: Vector2i) -> int:
	var index := _index(cell)
	return -1 if index < 0 or blocker_kind_code[index] == 0 else int(blocker_kind_code[index]) - 1


func mask_at(cell: Vector2i) -> int:
	var index := _index(cell)
	return 0 if index < 0 else int(blocker_mask[index])


func variant_at(cell: Vector2i) -> int:
	var index := _index(cell)
	return 0 if index < 0 else int(blocker_variant[index])


func occupied_indices() -> PackedInt32Array:
	return _occupied


func add_floor_stamp(rect: Rect2i, texture_index: int, alpha: float, z: int) -> void:
	floor_rect_and_style.append_array(PackedInt32Array([
		rect.position.x,
		rect.position.y,
		rect.size.x,
		rect.size.y,
		texture_index,
		z,
	]))
	floor_alpha.append(alpha)


func floor_stamp_count() -> int:
	return floor_alpha.size()


func cell_for_index(index: int) -> Vector2i:
	return Vector2i(index % cells_per_side, floori(float(index) / float(cells_per_side)))


func _index(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= cells_per_side or cell.y >= cells_per_side:
		return -1
	return cell.x + cell.y * cells_per_side
