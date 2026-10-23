extends "res://tools/tests/PlazaPresentationTest.gd"
## One real S6 fixture and an isolated five-state underlay contract. No full suite.
const UNDERLAY_COORD := Vector2i(0, -1)
const UNDERLAY_BED := Rect2i(23, 19, 3, 2)
var _underlay_rows: Array[Dictionary] = []


func _run() -> void:
	AudioManager.stop_all(true)
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	var writes_before: int = SaveManager.debug_save_writes
	var old_segment: int = Global.attempt_segment
	var old_seed: int = Global.attempt_world_seed
	Global.attempt_segment = 6
	Global.attempt_world_seed = 4
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	var theme: SegmentThemeData = SegmentThemePicker.get_theme(6, 4)
	var district: Dictionary = DistrictPlan.generate(6, 4, 2048, theme)
	_check(theme.district_family == &"industrial_cutthrough" and district.role_by_chunk[UNDERLAY_COORD] == &"entry_court", "exact natural S6 seed4 entry-court fixture")
	var original: Dictionary = _fixture(theme, district, UNDERLAY_COORD, false)
	var natural: Dictionary = _fixture(theme, district, UNDERLAY_COORD, true)
	var repeated: Dictionary = _fixture(theme, district, UNDERLAY_COORD, true)
	var chunk: Node2D = natural.chunk as Node2D
	var presentation: Dictionary = chunk.get_meta(PLAZA.META_PLAN, {})
	var beds: Array[Rect2i] = []
	var islands: Dictionary = {}
	for island: Dictionary in presentation.get("islands", []):
		ChunkShapeGen.add_rect(islands, island.rect)
		if (island.bed as Rect2i).has_area(): beds.append(island.bed)
	_check(beds == [UNDERLAY_BED] and (presentation.get("centrepiece", {}) as Dictionary).is_empty(), "real generated bed topology and empty centrepiece match the rejected native image")
	_check(str(presentation) == str((repeated.chunk as Node2D).get_meta(PLAZA.META_PLAN, {})) and (natural.data as ChunkBuildData).floor_rect_and_style == (repeated.data as ChunkBuildData).floor_rect_and_style, "real generated plan and floor stamps repeat identically")
	_check((natural.data as ChunkBuildData).blocker_kind_code == (repeated.data as ChunkBuildData).blocker_kind_code and (natural.data as ChunkBuildData).blocker_variant == (repeated.data as ChunkBuildData).blocker_variant, "body blockers and low-cover art owners repeat identically")
	var original_data: ChunkBuildData = original.data as ChunkBuildData
	var natural_data: ChunkBuildData = natural.data as ChunkBuildData
	var baseline: GroundSplatRenderer = _underlay_splat(original_data, chunk)
	var observed: GroundSplatRenderer = _underlay_splat(natural_data, chunk)
	var probe: Vector2i = UNDERLAY_COORD * CPC + UNDERLAY_BED.position
	print("NATURAL_S6_UNDERLAY material=%d care=%.3f repave=%d" % [observed.material_at(probe), observed.care_at(probe), int(presentation.get("repave_tex", -1))])
	observed.free()
	var protected_before: String = str(chunk.get_meta(&"_proc_clear_cells", {}))
	var foliage_before: String = str(chunk.get_meta(&"_foliage_placements", []))
	var landmark_before: Variant = chunk.get_meta(&"_landmark_cell", Vector2i(-1, -1))
	var manager: ChunkManager = original.manager as ChunkManager
	for state: int in range(5):
		var data := ChunkBuildData.new(UNDERLAY_COORD, CPC)
		data.blocker_kind_code = natural_data.blocker_kind_code.duplicate()
		data.blocker_mask = natural_data.blocker_mask.duplicate()
		data.blocker_variant = natural_data.blocker_variant.duplicate()
		data.set("_occupied", natural_data.occupied_indices().duplicate())
		data.plaza_edge_state = state
		data.floor_rect_and_style = original_data.floor_rect_and_style.duplicate()
		data.floor_alpha = original_data.floor_alpha.duplicate()
		var input: Dictionary = presentation.duplicate(true)
		input.state = state
		manager._active_build_data = data
		PLAZA._apply_physical(manager.get("_content_gen") as ChunkGenImpl, original.chunk as Node2D, input)
		manager._active_build_data = null
		var splat: GroundSplatRenderer = _underlay_splat(data, chunk)
		var underlay_ok: bool = true
		var care_ok: bool = true
		var outside_ok: bool = true
		var observed_bed: Array[Dictionary] = []
		for y: int in CPC:
			for x: int in CPC:
				var local := Vector2i(x, y)
				var world: Vector2i = UNDERLAY_COORD * CPC + local
				if UNDERLAY_BED.has_point(local):
					var expected: int = 6 if state == 0 else int(input.repave_tex)
					underlay_ok = underlay_ok and splat.material_at(world) == expected
					care_ok = care_ok and is_equal_approx(splat.care_at(world), 1.0 if state == 0 else 0.0)
					observed_bed.append({"cell": [x, y], "material": splat.material_at(world), "care": splat.care_at(world)})
				if not islands.has(local):
					outside_ok = outside_ok and splat.material_at(world) == baseline.material_at(world) and is_equal_approx(splat.care_at(world), baseline.care_at(world))
		_check(underlay_ok, "state%d bed underlay keeps tended urban ground only in state0; worn states use own plaza paving" % state)
		_check(care_ok, "state%d tended care is1 only in state0 and0 under every worn bed" % state)
		_check(outside_ok, "state%d material/care outside existing island footprints stays identical" % state)
		_check(data.blocker_kind_code == natural_data.blocker_kind_code and data.blocker_mask == natural_data.blocker_mask and data.blocker_variant == natural_data.blocker_variant, "state%d body blockers and declared low-cover owners unchanged" % state)
		_check(data.floor_rect_and_style.slice(0, original_data.floor_rect_and_style.size()) == original_data.floor_rect_and_style and data.floor_alpha.slice(0, original_data.floor_alpha.size()) == original_data.floor_alpha, "state%d original generator floor stamps unchanged" % state)
		_check(str(input.islands) == str(presentation.islands) and int(input.repave_tex) == int(presentation.repave_tex), "state%d bed topology and native plaza material unchanged" % state)
		if state == 1:
			_check(data.floor_rect_and_style == natural_data.floor_rect_and_style, "isolated working-state contract matches actual natural S6 integration")
		_underlay_rows.append({"state": state, "material_ok": underlay_ok, "care_ok": care_ok, "outside_ok": outside_ok, "bed_cells": observed_bed})
		splat.free()
		await get_tree().process_frame
	_check(str(chunk.get_meta(&"_proc_clear_cells", {})) == protected_before and str(chunk.get_meta(&"_foliage_placements", [])) == foliage_before and chunk.get_meta(&"_landmark_cell", Vector2i(-1, -1)) == landmark_before, "protected routes, foliage RNG result and landmark seed result unchanged")
	baseline.free()
	for fixture: Dictionary in [original, natural, repeated]:
		(fixture.manager as Node).free()
		fixture.clear()
	KIT.release_static_caches()
	PLAZA.enabled = true
	player.free()
	Global.attempt_segment = old_segment
	Global.attempt_world_seed = old_seed
	await get_tree().process_frame
	_check(SaveManager.debug_save_writes == writes_before and SaveManager.current_save == null, "underlay fixture makes no save writes")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			var file: FileAccess = FileAccess.open(arg.trim_prefix("--out="), FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify({"passes": _passes, "failures": _failures, "states": _underlay_rows, "fixture": "S6seed4entry_court(0,-1)", "save_writes": SaveManager.debug_save_writes - writes_before}, "\t"))
			else: _check(false, "cannot write underlay diagnostic output")
	print("PlazaBedUnderlayTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _underlay_splat(data: ChunkBuildData, chunk: Node2D) -> GroundSplatRenderer:
	var splat := GroundSplatRenderer.new()
	splat.configure(64, CPC)
	splat.set_ground_family(&"industrial_cutthrough")
	add_child(splat)
	splat.set_chunk_base(UNDERLAY_COORD, 6)
	splat.paint_chunk_stamps(data)
	for rect: Rect2i in chunk.get_meta(&"_ground_planting_rects", []):
		splat.paint_planting(UNDERLAY_COORD, rect)
	return splat
