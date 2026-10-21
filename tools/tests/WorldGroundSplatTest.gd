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
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	_test_base_and_stamps()
	_test_z_order()
	_test_authored_stamps_survive_bases()
	_test_stains()
	_test_wrap_reclaims_block()
	_test_slots()
	_test_domestic_care_data_contract()
	_test_district_policy_presentation()
	_test_district_care_eligibility()
	_test_ground_occlusion()
	_test_planting()
	_test_base_margin_rects()
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
	_check(splat.slot_borrow_count() == 0 and splat.active_slot_materials().size() == 8, "eight materials fit without borrowing")
	splat.paint_rect(Rect2i(9, 0, 1, 1), 10, 0.9)
	var borrowed := splat.material_at(Vector2i(9, 0))
	_check(borrowed == 0, "a ninth, grass-like material borrows the grass slot (%d)" % borrowed)
	_check(splat.slot_borrow_count() == 1, "a borrowed slot is counted so district tests can forbid it (%d)" % splat.slot_borrow_count())
	splat.paint_rect(Rect2i(10, 0, 1, 1), 9, 0.9)
	var paving := splat.material_at(Vector2i(10, 0))
	_check(paving != 0 and paving != 5 and paving >= 0, "a ninth paving material borrows a paving slot (%d)" % paving)
	splat.queue_free()


func _test_domestic_care_data_contract() -> void:
	var splat := _splat()
	var available := splat.has_method("paint_domestic_care") and splat.has_method("care_at") and splat.has_method("care_signature")
	_check(available,"domestic care has a presentation-only mask API")
	if not available:
		splat.queue_free()
		return
	var spec := {"footprint_px":PackedVector2Array([Vector2(192,960),Vector2(960,960),Vector2(960,1472),Vector2(192,1472)]),"doors":[{"pos":Vector2i(9,15),"dir":Vector2i.UP,"width":2}],"visual_seed":2128236757,"garden_contact_px":Vector2(200,1451)}
	splat.set_chunk_base(Vector2i.ZERO,0,0.93)
	splat.paint_rect(Rect2i(3,15,12,8),2,0.9)
	splat.paint_rect(Rect2i(7,12,5,3),4,0.9)
	splat.paint_rect(Rect2i(1,22,1,1),5,0.12)
	var before_a: PackedByteArray = (splat.get("_cover_a") as Image).get_data()
	var before_b: PackedByteArray = (splat.get("_cover_b") as Image).get_data()
	var before_light: PackedByteArray = (splat.get("_light") as Image).get_data()
	var before_slots: PackedInt32Array = splat.get("_slot_material").duplicate()
	splat.call("paint_domestic_care",Vector2i.ZERO,spec)
	var signature: PackedByteArray = splat.call("care_signature",Vector2i.ZERO)
	_check(signature.size() == 32*32,"care signatures contain exactly one byte per owning chunk cell")
	_check(signature.count(0) < signature.size()-3,"the kept tree home receives visible care on available vegetation")
	_check(before_a == (splat.get("_cover_a") as Image).get_data() and before_b == (splat.get("_cover_b") as Image).get_data(),"care leaves all material coverage bytes unchanged")
	_check(before_slots == splat.get("_slot_material"),"lawn presentation allocates no ninth semantic coverage slot")
	var after_light: PackedByteArray = (splat.get("_light") as Image).get_data()
	var preserved := true
	for index in before_light.size():
		if index % 4 != 2 and before_light[index] != after_light[index]: preserved = false
	_check(preserved,"care writes only light-map blue and preserves brightness, stains and alpha exactly")
	_check(splat.material_at(Vector2i(1,22)) == 0 and splat.material_at(Vector2i(3,20)) == 2 and splat.material_at(Vector2i(8,14)) == 4,"care preserves vegetated, indoor and paved terrain ownership")
	_check(float(splat.call("care_at",Vector2i(3,20))) == 0.0 and float(splat.call("care_at",Vector2i(8,14))) == 0.0,"indoor floor and door-apron stamps reject care")
	splat.set_chunk_base(Vector2i.ZERO,0,0.93)
	var cleared: PackedByteArray = splat.call("care_signature",Vector2i.ZERO)
	_check(cleared.count(0) == cleared.size(),"replacing a chunk base clears its old household care")
	splat.call("paint_domestic_care",Vector2i.ZERO,spec)
	@warning_ignore("integer_division")
	var far := Vector2i(GroundSplatRenderer.MAP_SIZE/32,0)
	splat.set_chunk_base(far,0)
	var wrapped: PackedByteArray = splat.call("care_signature",far)
	_check(wrapped.count(0) == wrapped.size(),"wrapped map reuse cannot inherit an old home's care")
	splat.set_chunk_base(Vector2i.ZERO,0,0.93)
	splat.paint_rect(Rect2i(3,15,12,8),2,0.9)
	splat.paint_rect(Rect2i(7,12,5,3),4,0.9)
	splat.paint_rect(Rect2i(1,22,1,1),5,0.12)
	splat.call("paint_domestic_care",Vector2i.ZERO,spec)
	_check(signature == splat.call("care_signature",Vector2i.ZERO),"a deterministic streamed rebuild restores the exact care field")
	splat.clear()
	var empty: PackedByteArray = splat.call("care_signature",Vector2i.ZERO)
	_check(empty.count(0) == empty.size(),"world clear removes household care completely")
	splat.queue_free()


func _bytes(splat: GroundSplatRenderer, field: String) -> PackedByteArray:
	return (splat.get(field) as Image).get_data()


func _test_district_policy_presentation() -> void:
	var splat := _splat()
	splat.set_chunk_base(Vector2i.ZERO, 6)
	splat.paint_rect(Rect2i(4, 4, 10, 3), 7, 0.9)
	splat.paint_rect(Rect2i(4, 7, 10, 1), 2, 0.9)
	splat.paint_rect(Rect2i(20, 4, 3, 3), 0, 0.95)
	var a := _bytes(splat, "_cover_a")
	var b := _bytes(splat, "_cover_b")
	var light := _bytes(splat, "_light")
	var slots := splat.active_slot_materials()
	splat.set_ground_family(&"collapsed_ward")
	splat.set_ground_family(&"collapsed_ward")
	splat.set_ground_family(&"rail_yard")
	_check(a == _bytes(splat, "_cover_a") and b == _bytes(splat, "_cover_b") and light == _bytes(splat, "_light") and slots == splat.active_slot_materials(), "switching district policies leaves coverage, light bytes and slots untouched")
	_check(StringName(splat.ground_policy().get("id", &"")) == &"rail_yard" and splat.ground_policy_enabled(), "the renderer reports the active district policy")
	var roles: PackedFloat32Array = splat.get_shader_material().get_shader_parameter("slot_role")
	var road: Vector4 = splat.get_shader_material().get_shader_parameter("road_a")
	var hard: Vector4 = splat.get_shader_material().get_shader_parameter("hard_a")
	_check(int(roles[0]) == 4 and int(roles[1]) == 1 and int(roles[2]) == 3 and int(roles[3]) == 5, "yard, road, footway and lawn slots carry their presentation roles (%s)" % str(roles))
	_check(road == Vector4(0, 1, 0, 0) and hard == Vector4(1, 1, 1, 0), "only the carriageway is kerbed; yard, road and footway are paved, lawn is not")
	splat.set_ground_family(&"")
	roles = splat.get_shader_material().get_shader_parameter("slot_role")
	_check(not splat.ground_policy_enabled() and roles.count(0.0) == roles.size(), "no district family presents every slot raw")
	splat.queue_free()


func _test_district_care_eligibility() -> void:
	var splat := _splat()
	splat.set_ground_family(&"service_courtyards")
	splat.set_chunk_base(Vector2i.ZERO, 6)
	splat.paint_rect(Rect2i(0, 0, 32, 2), 7, 0.9)
	splat.paint_rect(Rect2i(0, 2, 16, 1), 2, 0.9)
	splat.paint_rect(Rect2i(8, 3, 5, 2), 4, 0.92)
	splat.paint_rect(Rect2i(20, 20, 4, 4), 0, 0.95)
	splat.paint_rect(Rect2i(26, 20, 4, 4), 1, 0.95)
	var eligible := splat.care_eligibility(Vector2i.ZERO)
	var exact := true
	for y in 32:
		for x in 32:
			var material := splat.material_at(Vector2i(x, y))
			var expected := GroundSplatRenderer.care_eligible_index(material)
			if expected and material == 6:
				# The district surface keeps a paved margin beside streets.
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if splat.material_at(Vector2i(x + dx, y + dy)) in [3, 4, 7, 8, 9] and x + dx >= 0 and y + dy >= 0 and x + dx < 32 and y + dy < 32:
							expected = false
			if eligible[y * 32 + x] != (1 if expected else 0):
				exact = false
	_check(exact, "the block-read care eligibility matches per-cell material probes and the street margin exactly")
	_check(eligible[10 * 32 + 10] == 1 and eligible[21 * 32 + 21] == 1 and eligible[21 * 32 + 27] == 1, "the district surface, lawn and bare earth can be tended")
	_check(eligible[0] == 0 and eligible[2 * 32 + 3] == 0 and eligible[3 * 32 + 9] == 0, "roads, footways and door aprons never become lawn")
	_check(eligible[2 * 32 + 20] == 0 and eligible[5 * 32 + 9] == 0 and eligible[6 * 32 + 20] == 1, "a garden on the district surface keeps a paved margin beside the carriageway and the apron")
	_check(eligible[3 * 32 + 4] == 1, "a garden may still meet a footway or a house floor")
	var spec := {"footprint_px": PackedVector2Array([Vector2(640, 640), Vector2(1152, 640), Vector2(1152, 1024), Vector2(640, 1024)]), "doors": [{"pos": Vector2i(14, 15), "dir": Vector2i.DOWN, "width": 2}], "visual_seed": 944996572, "garden_contact_px": Vector2(660, 1040)}
	var before_a := _bytes(splat, "_cover_a")
	splat.paint_domestic_care(Vector2i.ZERO, spec, eligible)
	var cared := 0
	var off_ground := 0
	for y in 32:
		for x in 32:
			if splat.care_at(Vector2i(x, y)) > 0.0:
				cared += 1
				if eligible[y * 32 + x] == 0: off_ground += 1
	_check(cared >= 8 and off_ground == 0, "a home on the district surface gets a tended pocket on eligible ground only (%d cells)" % cared)
	_check(before_a == _bytes(splat, "_cover_a"), "district care leaves material ownership untouched")
	splat.queue_free()


func _test_ground_occlusion() -> void:
	var splat := _splat()
	splat.set_chunk_base(Vector2i.ZERO, 6)
	var data := ChunkBuildData.new(Vector2i.ZERO, 32)
	for x in range(10, 16):
		data.add_blocker(Vector2i(x, 10), WorldBlockerGeometry.Kind.WALL)
	data.add_blocker(Vector2i(25, 25), WorldBlockerGeometry.Kind.HALF_COVER)
	var before := _bytes(splat, "_light")
	var a := _bytes(splat, "_cover_a")
	splat.paint_occlusion(Vector2i.ZERO, data)
	var after := _bytes(splat, "_light")
	var alpha_only := true
	for index in before.size():
		if index % 4 != 3 and before[index] != after[index]: alpha_only = false
	_check(alpha_only and a == _bytes(splat, "_cover_a"), "occlusion writes only light-map alpha")
	_check(splat.openness_at(Vector2i(2, 2)) == 1.0 and splat.openness_at(Vector2i(30, 2)) == 1.0, "open ground far from any blocker stays fully lit")
	_check(splat.openness_at(Vector2i(12, 11)) < 0.9 and splat.openness_at(Vector2i(12, 11)) < splat.openness_at(Vector2i(12, 9)), "a wall shades the ground at its feet, more on its shadow (south-west) side")
	var prop := splat.openness_at(Vector2i(24, 26))
	_check(prop < 1.0 and prop > splat.openness_at(Vector2i(12, 11)), "half cover casts a lighter contact shade than a wall (%.3f)" % prop)
	splat.paint_occlusion(Vector2i.ZERO, data)
	_check(after == _bytes(splat, "_light"), "repainting occlusion reproduces the exact bytes")
	splat.set_chunk_base(Vector2i.ZERO, 6)
	_check(splat.openness_at(Vector2i(12, 11)) == 1.0, "replacing the chunk base clears its old occlusion")
	splat.queue_free()


func _test_planting() -> void:
	var splat := _splat()
	splat.set_chunk_base(Vector2i.ZERO, 7)
	splat.paint_rect(Rect2i(10, 10, 4, 3), 6, 0.95)
	var a := _bytes(splat, "_cover_a")
	splat.paint_planting(Vector2i.ZERO, Rect2i(9, 9, 6, 5))
	_check(splat.care_at(Vector2i(11, 11)) == 1.0 and splat.care_at(Vector2i(10, 12)) == 1.0, "a recorded plaza island becomes a fully tended bed")
	_check(splat.care_at(Vector2i(9, 9)) == 0.0 and splat.care_at(Vector2i(14, 13)) == 0.0, "the bed never spills onto the surrounding carriageway")
	_check(a == _bytes(splat, "_cover_a"), "planting leaves material ownership untouched")
	var light := _bytes(splat, "_light")
	splat.paint_planting(Vector2i.ZERO, Rect2i(9, 9, 6, 5))
	_check(light == _bytes(splat, "_light"), "replanting is idempotent")
	splat.queue_free()


func _test_base_margin_rects() -> void:
	var splat := _splat()
	splat.set_chunk_base(Vector2i.ZERO, 6)
	var rects: Array[Rect2i] = [Rect2i(0, 0, 4, 2), Rect2i(4, 0, 4, 3)]
	splat.paint_base_rects(rects, 0, 0.96)
	_check(splat.material_at(Vector2i(1, 1)) == 0 and splat.material_at(Vector2i(5, 2)) == 0 and splat.material_at(Vector2i(1, 2)) == 6, "a district margin lays wild cells exactly where asked")
	splat.queue_free()


func _test_chunk_manager_path() -> void:
	var manager := ChunkManager.new()
	# This fixture exercises ground streaming, without furnishing content scenes.
	manager.generation_enabled = false
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
