extends SceneTree
## Pure data contract; missing owner is an assertion failure, not a parse error.

const SOURCE := "res://core/systems/world/ground/CityYardSupportMap.gd"
var passed := 0
var failed := 0
var owner: RefCounted


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		print("FAIL: ", message)


func _bytes(n: int, value: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(n)
	result.fill(value)
	return result


func _ids(n: int, value := 6) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(n)
	result.fill(value)
	return result


func _write(coord: Vector2i, n: int, value: int) -> bool:
	return owner.replace_chunk(coord, n, _bytes(n*n, value), _ids(n*n), _bytes(n*n, 0))


func _test_clip_replace() -> void:
	# Wrong semantic equality or allowing fractional/nonzero care breaks these literals.
	var proposed := PackedByteArray([9, 31, 127, 255, 62, 81, 100, 200, 254])
	var semantic := PackedInt32Array([6, 8, 5, 6, 6, -6, 262, 6, 6])
	var care := PackedByteArray([0, 0, 0, 1, 0, 0, 0, 255, 0])
	var proposed_before := proposed.duplicate()
	var semantic_before := semantic.duplicate()
	var care_before := care.duplicate()
	_check(owner.replace_chunk(Vector2i.ZERO, 3, proposed, semantic, care), "valid row-major inputs accepted")
	var expected := PackedByteArray([9, 0, 0, 0, 62, 0, 0, 0, 254])
	_check(owner.signature(Vector2i.ZERO, 3) == expected, "only exact index 6 and care byte 0 survive")
	_check(proposed == proposed_before and semantic == semantic_before and care == care_before, "all caller arrays untouched")
	_check(owner.replace_chunk(Vector2i.ZERO, 3, proposed, semantic, care), "identical replacement accepted")
	_check(owner.signature(Vector2i.ZERO, 3) == expected, "replacement idempotent")
	proposed.fill(0)
	semantic.fill(0)
	care.fill(255)
	_check(owner.signature(Vector2i.ZERO, 3) == expected, "later caller mutations cannot change stored bytes")
	_check(_write(Vector2i.ZERO, 3, 1), "lower replacement accepted")
	_check(owner.signature(Vector2i.ZERO, 3) == _bytes(9, 1), "replacement lowers old bytes rather than maxing stale data")
	var signature: PackedByteArray = owner.signature(Vector2i.ZERO, 3)
	signature.fill(89)
	_check(owner.signature(Vector2i.ZERO, 3) == _bytes(9, 1), "signature is an independent copy")


func _test_invalid() -> void:
	# Every malformed field must clear its valid target and preserve an unrelated cell.
	for field in 3:
		for count in [3, 5]:
			owner.clear()
			_write(Vector2i.ZERO, 2, 200)
			_write(Vector2i(20, 20), 1, 77)
			var p := _bytes(count if field == 0 else 4, 255)
			var s := _ids(count if field == 1 else 4)
			var c := _bytes(count if field == 2 else 4, 0)
			_check(not owner.replace_chunk(Vector2i.ZERO, 2, p, s, c), "malformed field rejected: %s/%s" % [field, count])
			_check(owner.signature(Vector2i.ZERO, 2) == _bytes(4, 0), "malformed field clears stale valid target")
			_check(owner.signature(Vector2i(20, 20), 1) == PackedByteArray([77]), "malformed field preserves unrelated target")
	for n in [0, -1, 257, 2147483647, 9223372036854775807]:
		var before: PackedByteArray = owner.snapshot_image().get_data()
		_check(not owner.replace_chunk(Vector2i.ZERO, n, PackedByteArray(), PackedInt32Array(), PackedByteArray()), "invalid dimensions rejected before allocation: " + str(n))
		_check(owner.signature(Vector2i.ZERO, n).is_empty(), "invalid signature bounded: " + str(n))
		_check(owner.snapshot_image().get_data() == before, "invalid dimensions leave existing data intact")


func _test_wrap_and_reset() -> void:
	owner.clear()
	# (-1,-1)*3 starts at (253,253); literal image positions check both axes.
	var p := PackedByteArray([1,2,3,4,5,6,7,8,9])
	_check(owner.replace_chunk(Vector2i(-1,-1), 3, p, _ids(9), _bytes(9,0)), "negative nondivisor chunk accepted")
	var image: Image = owner.snapshot_image()
	_check(image.get_pixel(253,253).r8 == 1 and image.get_pixel(255,253).r8 == 3 and image.get_pixel(253,255).r8 == 7 and image.get_pixel(255,255).r8 == 9, "negative origin maps to literal wrapped image coordinates")
	# 85*3=255: this chunk crosses each edge and reuses one previous corner.
	_check(owner.replace_chunk(Vector2i(85,85), 3, p, _ids(9), _bytes(9,0)), "nondivisor chunk crosses both wrapped edges")
	image = owner.snapshot_image()
	_check(image.get_pixel(255,255).r8 == 1 and image.get_pixel(0,255).r8 == 2 and image.get_pixel(1,0).r8 == 6 and image.get_pixel(1,1).r8 == 9, "edge crossing preserves local row-major order")
	_check(owner.signature(Vector2i(85,85), 3) == p, "wrapped signature reconstructs local field")
	_check(_write(Vector2i(341,341), 3, 0), "aliased chunk replacement accepted")
	_check(owner.signature(Vector2i(85,85), 3) == _bytes(9,0), "aliased old chunk bytes cleared completely")
	# Vector2i extrema with n=255: origins are (1,0), computed by hand modulo 256.
	owner.clear()
	_check(_write(Vector2i(2147483647,-2147483648),255,23), "extreme coordinates accepted without multiplication overflow")
	image = owner.snapshot_image()
	_check(image.get_pixel(1,0).r8 == 23 and image.get_pixel(255,254).r8 == 23 and image.get_pixel(0,0).r8 == 0 and image.get_pixel(1,255).r8 == 0, "extreme coordinate wrapping has literal origin and extent")
	owner.clear()
	_check(owner.snapshot_image().get_data() == _bytes(65536,0), "clear resets the complete fixed buffer")
	_check(_write(Vector2i(-8,8),32,56), "divisor chunk accepted")
	_check(_write(Vector2i.ZERO,32,0), "wrapped divisor alias replaced")
	_check(owner.signature(Vector2i(-8,8),32) == _bytes(1024,0), "divisor wrapped reuse clears old bytes")


func _test_rects_and_snapshot() -> void:
	owner.clear()
	_check(_write(Vector2i.ZERO,256,111), "maximum bounded chunk accepted")
	var saved: Image = owner.snapshot_image()
	_check(saved.get_width() == 256 and saved.get_height() == 256 and saved.get_format() == Image.FORMAT_L8 and not saved.has_mipmaps(), "snapshot is fixed single-channel L8 without mipmaps")
	owner.clear_rect(Rect2i(255,255,2,2))
	var image: Image = owner.snapshot_image()
	_check(image.get_pixel(255,255).r8 == 0 and image.get_pixel(0,255).r8 == 0 and image.get_pixel(255,0).r8 == 0 and image.get_pixel(0,0).r8 == 0, "rect clear wraps across both edges")
	_check(image.get_pixel(1,0).r8 == 111 and image.get_pixel(254,255).r8 == 111, "rect clear preserves neighboring bytes")
	_check(saved.get_pixel(255,255).r8 == 111, "snapshot retains bytes after owner clears")
	saved.fill(Color.WHITE)
	_check(owner.snapshot_image().get_pixel(255,255).r8 == 0, "editing snapshot cannot mutate owner")
	var before: PackedByteArray = owner.snapshot_image().get_data()
	for rect: Rect2i in [Rect2i(0,0,0,1), Rect2i(0,0,1,0), Rect2i(0,0,-1,2), Rect2i(0,0,2,-1)]:
		owner.clear_rect(rect)
	_check(owner.snapshot_image().get_data() == before, "empty and negative-size rectangles do nothing")
	# Huge extents must visit at most 256*256 cells, with no position+size overflow.
	owner.clear_rect(Rect2i(2147483647,-2147483648,2147483647,2147483647))
	_check(owner.snapshot_image().get_data() == _bytes(65536,0), "huge rectangle clears once per wrapped cell with bounded CPU")
	_write(Vector2i.ZERO,256,19)
	owner.clear_rect(Rect2i(-1,-1,1,1))
	image = owner.snapshot_image()
	_check(image.get_pixel(255,255).r8 == 0 and image.get_pixel(254,255).r8 == 19 and image.get_pixel(0,0).r8 == 19, "negative single-cell rect wraps without expanding")
	owner.clear_rect(Rect2i(-2147483648,2147483647,2147483647,1))
	image = owner.snapshot_image()
	_check(image.get_pixel(0,255).r8 == 0 and image.get_pixel(255,255).r8 == 0 and image.get_pixel(0,254).r8 == 19, "huge width and one-row height preserve other rows")
	owner.clear()
	_check(saved.get_pixel(1,1).r8 == 255, "owner reset leaves caller-edited old snapshot independent")


func _run() -> void:
	_check(FileAccess.file_exists(SOURCE), "yard support map owner exists")
	if FileAccess.file_exists(SOURCE):
		var script: GDScript = load(SOURCE)
		_check(script != null and script.can_instantiate(), "owner loads with no autoloads or assets")
		if script != null and script.can_instantiate():
			owner = script.new()
			_check(owner.snapshot_image().get_data() == _bytes(65536,0), "new owner starts entirely clear")
			_test_clip_replace()
			_test_invalid()
			_test_wrap_and_reset()
			_test_rects_and_snapshot()
	print("CityYardSupportMapTest: ",passed," passed, ",failed," failed")
	quit(1 if failed else 0)
