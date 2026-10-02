extends Node

# GroundSplatRenderer (2026-09-27, world look pass): the ground as splat maps
# painted from the same floor data the sprite floors used. Checks the data
# contract (what material a cell ends up with), not the shader's look -
# WorldLookProbe renders that.
#
# Run: <godot> --headless --path . res://tools/tests/WorldGroundSplatTest.tscn

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	_test_base_and_stamps()
	_test_z_order()
	_test_authored_stamps_survive_bases()
	_test_stains()
	_test_wrap_reclaims_block()
	_test_slots()
	await _test_chunk_manager_path()
	print("WorldGroundSplatTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _splat() -> GroundSplatRenderer:
	var splat := GroundSplatRenderer.new()
	splat.configure(64, 32)
	add_child(splat)
	return splat


func _test_base_and_stamps() -> void:
	var splat := _splat()
	_check(splat.material_at(Vector2i(5, 5)) == -1, "an unpainted cell has no ground")
	splat.set_chunk_base(Vector2i.ZERO, 0)
	_check(splat.material_at(Vector2i(5, 5)) == 0 and splat.material_at(Vector2i(31, 31)) == 0, "a chunk base covers its whole block")
	_check(splat.material_at(Vector2i(32, 5)) == -1, "a chunk base stops at its block")
	splat.paint_rect(Rect2i(4, 4, 3, 2), 7, 0.88)
	_check(splat.material_at(Vector2i(4, 4)) == 7 and splat.material_at(Vector2i(6, 5)) == 7, "an opaque stamp owns its cells")
	_check(splat.material_at(Vector2i(7, 4)) == 0, "a stamp leaves its neighbours on the base")
	_check(splat.quad_count() == 1, "one draw quad per chunk touched (%d)" % splat.quad_count())
	splat.paint_rect(Rect2i(30, 0, 4, 1), 7, 0.9)
	_check(splat.quad_count() == 2, "a stamp crossing into the next chunk adds its quad (%d)" % splat.quad_count())
	splat.queue_free()


func _test_z_order() -> void:
	var splat := _splat()
	splat.set_chunk_base(Vector2i.ZERO, 0)
	var data := ChunkBuildData.new(Vector2i.ZERO, 32)
	# Recorded out of z order: a plaza (-94) first, then the road (-95) through it.
	data.add_floor_stamp(Rect2i(2, 2, 6, 6), 3, 0.95, -94)
	data.add_floor_stamp(Rect2i(0, 4, 12, 2), 7, 0.88, -95)
	splat.paint_chunk_stamps(data)
	_check(splat.material_at(Vector2i(4, 4)) == 3, "the higher-z plaza wins over the road recorded after it")
	_check(splat.material_at(Vector2i(10, 4)) == 7, "the road still owns cells the plaza does not cover")
	splat.queue_free()


func _test_authored_stamps_survive_bases() -> void:
	var splat := _splat()
	splat.paint_rect(Rect2i(-3, -3, 6, 6), 2, 0.9, 0.7, true)
	_check(splat.material_at(Vector2i(0, 0)) == 2, "an authored stamp paints before any base exists")
	splat.set_chunk_base(Vector2i.ZERO, 0)
	splat.set_chunk_base(Vector2i(-1, -1), 0)
	_check(splat.material_at(Vector2i(0, 0)) == 2 and splat.material_at(Vector2i(-2, -2)) == 2, "authored stamps are laid back over chunk bases that stream in later")
	_check(splat.material_at(Vector2i(5, 5)) == 0, "the base fills around the authored stamp")
	splat.queue_free()


func _test_stains() -> void:
	var splat := _splat()
	splat.set_chunk_base(Vector2i.ZERO, 0)
	splat.paint_rect(Rect2i(0, 0, 8, 8), 7, 0.9)
	splat.paint_rect(Rect2i(2, 2, 1, 1), 5, 0.12)
	_check(splat.material_at(Vector2i(2, 2)) == 7, "a light stamp (mud chip) stains the paving instead of replacing it")
	splat.queue_free()


func _test_wrap_reclaims_block() -> void:
	var splat := _splat()
	splat.set_chunk_base(Vector2i.ZERO, 0)
	splat.paint_rect(Rect2i(3, 3, 2, 2), 7, 0.9)
	@warning_ignore("integer_division")
	var far := Vector2i(GroundSplatRenderer.MAP_SIZE / 32, 0)
	splat.set_chunk_base(far, 10)
	_check(splat.material_at(far * 32 + Vector2i(3, 3)) == 10, "a chunk sharing the wrapped block repaints it with its own base")
	_check(splat.material_at(Vector2i(3, 3)) == 10, "the far chunk's base clears the old stamp (the map is a window, not a world)")
	splat.queue_free()


func _test_slots() -> void:
	var splat := _splat()
	for material in [0, 1, 2, 3, 4, 5, 7, 8]:
		splat.paint_rect(Rect2i(material, 0, 1, 1), material, 0.9)
	_check(splat.material_at(Vector2i(8, 0)) == 8, "eight materials each get a slot")
	splat.paint_rect(Rect2i(9, 0, 1, 1), 10, 0.9)
	var borrowed := splat.material_at(Vector2i(9, 0))
	_check(borrowed == 0, "a ninth, grass-like material borrows the grass slot (%d)" % borrowed)
	splat.paint_rect(Rect2i(10, 0, 1, 1), 9, 0.9)
	var paving := splat.material_at(Vector2i(10, 0))
	_check(paving != 0 and paving != 5 and paving >= 0, "a ninth paving material borrows a paving slot (%d)" % paving)
	splat.queue_free()


func _test_chunk_manager_path() -> void:
	var manager := ChunkManager.new()
	manager.world_seed = 424242
	manager.load_radius = 0
	manager.unload_radius = 1
	add_child(manager)
	manager.start_streaming(Vector2(1024, 1024))
	manager.process_chunk_generation_queue(4)
	await get_tree().process_frame
	var splat := manager.get_ground_splat()
	_check(splat != null, "the chunk manager draws its ground through the splat")
	if splat != null:
		_check(splat.material_at(Vector2i(16, 16)) >= 0, "the streamed chunk painted its ground")
	var stats := manager.get_chunk_render_stats()
	_check(int(stats.get("ground_sprites", -1)) == 0 and int(stats.get("floor_sprites", -1)) == 0, "no per-chunk ground or floor-stamp sprites are created (%s)" % str(stats))
	manager.queue_free()
	await get_tree().process_frame
