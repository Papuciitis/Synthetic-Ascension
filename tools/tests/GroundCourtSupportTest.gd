extends Node

# District-fill court support (2026-10-31 yard pass): a court's setts present
# along its actual use (passage mouths and doorways into its working middle)
# and hand unused corners back to the district yard, without changing any
# semantic ground, care, light or generation data. Checks the planner, the
# renderer's support map contract and real Segment 9 district-fill chunks.
# Native appearance: GroundCourtSupportRenderTest.
#
# Run: <godot> --headless --path . res://tools/tests/GroundCourtSupportTest.tscn

const SUPPORT := preload("res://core/systems/world/ground/CityCourtSupport.gd")
const POLICY := preload("res://core/systems/world/ground/DistrictGroundPolicy.gd")
const COVER_FULL := preload("res://scenes/world/cover/CoverFull.tscn")
const COVER_WINDOW := preload("res://scenes/world/cover/CoverWindow.tscn")
const COVER_HALF := preload("res://scenes/world/cover/CoverHalf.tscn")
const CPC := 32
const REAL_CHUNKS := 6

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
	_test_planner()
	_test_renderer_contract()
	_test_uniforms()
	_test_real_district_fill()
	print("GroundCourtSupportTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _value(plan: Dictionary, cell: Vector2i) -> int:
	var region: Rect2i = plan.region
	return plan.support[(cell.y - region.position.y) * region.size.x + (cell.x - region.position.x)]


func _test_planner() -> void:
	var court := Rect2i(10, 10, 11, 11)
	var north_mouth := Vector2(15.5, 10.5)
	var south_west_door := Vector2(12.5, 22.5)
	var plan := SUPPORT.plan(court, [north_mouth, south_west_door] as Array[Vector2], CPC)
	_check(plan.region == court.grow(1), "support covers the court and its one-cell ring (%s)" % str(plan.region))
	_check((plan.support as PackedByteArray).size() == court.grow(1).get_area(), "one support byte per region cell")
	_check(_value(plan, Vector2i(15, 15)) == 255, "the court's working middle keeps its setts")
	_check(_value(plan, Vector2i(15, 10)) == 255 and _value(plan, Vector2i(15, 12)) == 255, "the walking line from the passage mouth keeps its setts")
	_check(_value(plan, Vector2i(12, 20)) == 255, "the walking line from the doorway keeps its setts")
	_check(_value(plan, Vector2i(20, 10)) <= 8 and _value(plan, Vector2i(20, 20)) <= 8, "unused far corners hand their ground back (%d, %d)" % [_value(plan, Vector2i(20, 10)), _value(plan, Vector2i(20, 20))])
	_check(_value(plan, Vector2i(21, 10)) == _value(plan, Vector2i(20, 10)) and _value(plan, Vector2i(15, 9)) == _value(plan, Vector2i(15, 10)), "ring cells mirror the court cell beside them, so used edges never recede")
	var unused := 0
	for y in range(court.position.y, court.end.y):
		for x in range(court.position.x, court.end.x):
			if _value(plan, Vector2i(x, y)) < 64:
				unused += 1
	var share := float(unused) / float(court.get_area())
	_check(share >= 0.25 and share <= 0.60, "a sparsely used court releases its corners but keeps its use (%d of %d cells)" % [unused, court.get_area()])
	var again := SUPPORT.plan(court, [north_mouth, south_west_door] as Array[Vector2], CPC)
	_check(again.support == plan.support, "the plan is deterministic")
	var busier := SUPPORT.plan(court, [north_mouth, south_west_door, Vector2(21.5, 15.5), Vector2(9.5, 13.5)] as Array[Vector2], CPC)
	var never_less := true
	for index in plan.support.size():
		never_less = never_less and busier.support[index] >= plan.support[index]
	_check(never_less, "another entrance only ever keeps more setts")
	var clipped := SUPPORT.plan(Rect2i(0, 0, 9, 9), [Vector2(4.5, 0.5)] as Array[Vector2], CPC)
	_check(clipped.region == Rect2i(0, 0, 10, 10), "the ring is clipped to the chunk")
	_check(SUPPORT.plan(Rect2i(), [] as Array[Vector2], CPC).support.is_empty(), "an empty court plans nothing")


func _splat() -> GroundSplatRenderer:
	var splat := GroundSplatRenderer.new()
	splat.configure(64, CPC)
	add_child(splat)
	splat.set_ground_family(&"outer_wall")
	return splat


func _images(splat: GroundSplatRenderer) -> Array[PackedByteArray]:
	return [splat._cover_a.get_data(), splat._cover_b.get_data(), splat._light.get_data()]


func _test_renderer_contract() -> void:
	var splat := _splat()
	var coord := Vector2i(1, 0)
	var origin := coord * CPC
	splat.set_chunk_base(coord, POLICY.DISTRICT_GROUND_INDEX)
	var court := Rect2i(10, 10, 11, 11)
	splat.paint_rect(Rect2i(origin + court.position, court.size), 8, 0.88)
	splat.paint_rect(Rect2i(origin + Vector2i(14, 0), Vector2i(3, 11)), 4, 0.80)
	_check(is_equal_approx(splat.support_at(origin + Vector2i(20, 20)), 1.0) and is_equal_approx(splat.kerb_allowed_at(origin + Vector2i(20, 20)), 1.0), "untouched ground presents fully and may draw kerbs")
	var before := _images(splat)
	var materials := PackedInt32Array()
	for y in CPC:
		for x in CPC:
			materials.append(splat.material_at(origin + Vector2i(x, y)))
	splat.paint_court_support(coord, court, [Vector2(15.5, 10.5)] as Array[Vector2])
	_check(_images(splat) == before, "the support pass writes no coverage, brightness, stain, care or occlusion byte")
	var after := PackedInt32Array()
	for y in CPC:
		for x in CPC:
			after.append(splat.material_at(origin + Vector2i(x, y)))
	_check(after == materials, "every semantic material is unchanged")
	_check(splat.support_at(origin + Vector2i(15, 15)) > 0.99, "the court middle presents fully")
	_check(splat.support_at(origin + Vector2i(20, 20)) < 0.05, "an unused court corner is released")
	_check(splat.kerb_allowed_at(origin + Vector2i(15, 15)) < 0.01 and splat.kerb_allowed_at(origin + Vector2i(9, 15)) < 0.01, "no kerb draws in the court or its ring")
	_check(is_equal_approx(splat.support_at(origin + Vector2i(8, 15)), 1.0) and is_equal_approx(splat.kerb_allowed_at(origin + Vector2i(8, 15)), 1.0), "ground beyond the ring is untouched")
	var signature := splat.support_signature(coord)
	splat.paint_court_support(coord, court, [Vector2(15.5, 10.5)] as Array[Vector2])
	_check(splat.support_signature(coord) == signature, "repainting the same court is idempotent")
	splat.set_chunk_base(coord, POLICY.DISTRICT_GROUND_INDEX)
	_check(is_equal_approx(splat.support_at(origin + Vector2i(20, 20)), 1.0) and is_equal_approx(splat.kerb_allowed_at(origin + Vector2i(15, 15)), 1.0), "a new chunk base forgets the old court support")
	splat.paint_court_support(coord, court, [Vector2(15.5, 10.5)] as Array[Vector2])
	splat.clear()
	_check(is_equal_approx(splat.support_at(origin + Vector2i(20, 20)), 1.0), "clear() resets the support map")
	splat.queue_free()


func _test_uniforms() -> void:
	var splat := _splat()
	splat.set_chunk_base(Vector2i.ZERO, 11)
	var material := splat.get_shader_material()
	_check(int(material.get_shader_parameter(&"support_fallback_slot")) == -1, "no district yard slot: support stays off")
	splat.set_chunk_base(Vector2i(1, 0), POLICY.DISTRICT_GROUND_INDEX)
	splat.paint_rect(Rect2i(42, 10, 4, 4), 8, 0.88)
	splat.paint_rect(Rect2i(42, 2, 3, 6), 4, 0.80)
	splat.paint_rect(Rect2i(48, 2, 3, 6), 2, 0.80)
	var yard_slot := -1
	var mask: Array[float] = []
	var a: Vector4 = material.get_shader_parameter(&"support_a")
	var b: Vector4 = material.get_shader_parameter(&"support_b")
	mask.assign([a.x, a.y, a.z, a.w, b.x, b.y, b.z, b.w])
	var expected := true
	for slot in GroundSplatRenderer.SLOTS:
		var index: int = splat._slot_material[slot]
		if index == POLICY.DISTRICT_GROUND_INDEX:
			yard_slot = slot
		var role := POLICY.role_for_index(index) if index >= 0 else POLICY.ROLE_RAW
		var wanted := 1.0 if role == POLICY.ROLE_ROAD or role == POLICY.ROLE_LANE else 0.0
		expected = expected and is_equal_approx(mask[slot], wanted)
	_check(int(material.get_shader_parameter(&"support_fallback_slot")) == yard_slot and yard_slot >= 0, "the fallback is the district yard's slot")
	_check(expected, "only road and lane slots follow support (%s)" % str(mask))
	_check(int(material.get_shader_parameter(&"court_release")) == POLICY.COURT_TO_YARD, "outer wall releases unused court cells to its yard")
	splat.set_ground_family(&"canal_services")
	_check(int(material.get_shader_parameter(&"court_release")) == POLICY.COURT_KEEP, "canal services keeps its courts' setts (only made flush)")
	splat.set_ground_family(&"")
	_check(int(material.get_shader_parameter(&"support_fallback_slot")) == -1 and int(material.get_shader_parameter(&"court_release")) == POLICY.COURT_KEEP, "the legacy palette keeps support off")
	splat.queue_free()


func _manager(theme: SegmentThemeData, plan: Dictionary) -> ChunkManager:
	var cm := ChunkManager.new()
	theme.apply_to_chunk_manager(cm)
	cm.generation_enabled = false
	cm.ground_enabled = true
	cm.ground_splat_enabled = true
	cm.decals_enabled = false
	cm.deco_enabled = false
	cm.sites_enabled = false
	cm.parcels_chunk_chance = 0.95
	cm.parcels_chance_per_side = 0.80
	cm.parcels_max_per_side = 2
	cm.district_sidewalk_width_cells = 1
	cm.district_sidewalk_corner_pad_cells = 1
	cm.cover_full_scene = COVER_FULL
	cm.cover_window_scene = COVER_WINDOW
	cm.cover_half_scene = COVER_HALF
	add_child(cm)
	cm.set_process(false)
	cm.configure_procedural_world(int(plan.seed), plan.connectors_by_chunk, plan.urban_access_by_chunk, plan.role_by_chunk, plan.terrain_by_chunk, plan.archetype_by_chunk)
	return cm


func _test_real_district_fill() -> void:
	Global.attempt_segment = 9
	var theme := SegmentThemePicker.get_theme(9, 16102026)
	var plan := DistrictPlan.generate(9, 16102026, 2048, theme)
	var cm := _manager(theme, plan)
	var coords: Array[Vector2i] = []
	for coord: Vector2i in plan.role_by_chunk:
		if StringName(plan.role_by_chunk[coord]) == &"district_fill":
			coords.append(coord)
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	_check(coords.has(Vector2i(-2, -1)), "the reviewed S9 chunk (-2,-1) is district fill")
	coords = coords.slice(0, REAL_CHUNKS)
	if not coords.has(Vector2i(-2, -1)):
		coords[0] = Vector2i(-2, -1)
	var released_total := 0
	var court_total := 0
	for coord in coords:
		var chunk: Node2D = cm._create_chunk(coord)
		cm._chunks[coord] = chunk
		var splat := cm.get_ground_splat()
		var court: Dictionary = chunk.get_meta(&"_ground_court", {})
		_check(not court.is_empty(), "%s records its court for presentation" % str(coord))
		if court.is_empty():
			continue
		var rect: Rect2i = court.rect
		var origin := coord * CPC
		# Passages and aprons are stamped over the court's edge cells; the rest
		# is court setts, as generated.
		var setts := 0
		var only_court_or_lane := true
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var index := splat.material_at(origin + Vector2i(x, y))
				setts += 1 if index == 8 else 0
				only_court_or_lane = only_court_or_lane and (index == 8 or index == 4)
		_check(only_court_or_lane and setts * 4 >= rect.get_area() * 3, "%s court keeps its generated ground: court setts and the lanes stamped over them (%d of %d setts)" % [str(coord), setts, rect.get_area()])
		var images := _images(splat)
		var signature_first := splat.support_signature(coord)
		var entrances := SUPPORT.entrances(chunk, rect, court.passages, 64.0)
		splat.paint_court_support(coord, rect, entrances)
		_check(_images(splat) == images and splat.support_signature(coord) == signature_first, "%s repainting its support changes no ground byte and repeats the streamed support exactly" % str(coord))
		_check(entrances.size() >= 2, "%s court has passage and doorway entrances (%d)" % [str(coord), entrances.size()])
		var kept := true
		var lo := Vector2(rect.position) + Vector2(0.5, 0.5)
		var hi := Vector2(rect.end) - Vector2(0.5, 0.5)
		for entrance: Vector2 in entrances:
			var mouth := Vector2i(entrance.clamp(lo, hi).floor())
			kept = kept and splat.support_at(origin + mouth) > 0.95
		_check(kept, "%s every passage mouth and doorway keeps its setts" % str(coord))
		var released := 0
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if splat.support_at(origin + Vector2i(x, y)) < 0.25:
					released += 1
		released_total += released
		court_total += rect.get_area()
		_check(released < rect.get_area() / 2, "%s keeps most of its court (%d of %d released)" % [str(coord), released, rect.get_area()])
		var signature := splat.support_signature(coord)
		var care := splat.care_signature(coord)
		cm._unregister_chunk_cells(coord)
		chunk.free()
		cm._chunks.erase(coord)
		var rebuilt: Node2D = cm._create_chunk(coord)
		cm._chunks[coord] = rebuilt
		_check(splat.support_signature(coord) == signature and splat.care_signature(coord) == care, "%s streams back with identical support and care bytes" % str(coord))
	_check(released_total > 0, "real courts release unused corners (%d of %d cells)" % [released_total, court_total])
	cm.queue_free()
