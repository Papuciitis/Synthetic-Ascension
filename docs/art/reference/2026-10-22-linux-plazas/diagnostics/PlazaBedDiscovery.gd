extends "res://tools/tests/PlazaPresentationTest.gd"
## Bounded fixture discovery only. Uses the existing production-plan fixture;
## this is candidate selection, never native-Game visual validation.
const BED_TARGETS: Array[Dictionary] = [
	{"segment": 6, "family": &"industrial_cutthrough"},
	{"segment": 7, "family": &"canal_services"},
	{"segment": 8, "family": &"military_staging"},
]
const BED_ROLES: Array[StringName] = [&"landmark_plaza", &"entry_court", &"wardstone_court", &"exploration_reward", &"checkpoint", &"gate", &"miniboss_arena", &"boss_arena", &"primary_objective", &"secondary_wager_shrine"]
var _bed_output: String = ""
var _bed_attempts: Array[Dictionary] = []
var _bed_results: Array[Dictionary] = []


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_bed_output = arg.trim_prefix("--out=")
	if not _bed_output.is_absolute_path() or FileAccess.file_exists(_bed_output):
		_check(false, "bed discovery requires --out=<fresh absolute JSON file>")
		get_tree().quit(1)
		return
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	var writes_before: int = SaveManager.debug_save_writes
	var previous_segment: int = Global.attempt_segment
	var previous_seed: int = Global.attempt_world_seed
	var player: Node2D = Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	for target: Dictionary in BED_TARGETS:
		var matching: int = 0
		var result: Dictionary = {}
		Global.attempt_segment = int(target.segment)
		for attempt_seed: int in range(1, 401):
			if matching >= 8 or not result.is_empty():
				break
			var theme: SegmentThemeData = SegmentThemePicker.get_theme(int(target.segment), attempt_seed)
			if theme.district_family != target.family:
				continue
			matching += 1
			Global.attempt_world_seed = attempt_seed
			var plan: Dictionary = DistrictPlan.generate(int(target.segment), attempt_seed, 2048, theme)
			var picked: Dictionary = {}
			var coords: Array = plan.role_by_chunk.keys()
			coords.sort()
			for coord: Vector2i in coords:
				var role: StringName = plan.role_by_chunk[coord]
				if role in BED_ROLES and not picked.has(role):
					picked[role] = coord
			for role: StringName in picked:
				var coord: Vector2i = picked[role]
				var fixture: Dictionary = _fixture(theme, plan, coord, true)
				var chunk: Node2D = fixture.chunk as Node2D
				var dressing: Node = chunk.get_node_or_null("PlazaDressing")
				var beds: Array[Dictionary] = []
				if dressing != null:
					for node: Node in dressing.get_children():
						if node is Polygon2D and str(node.get_meta(&"plaza_piece", "")) == "bed":
							var polygon: Polygon2D = node as Polygon2D
							if polygon.polygon.is_empty():
								continue
							var bounds: Rect2 = Rect2(polygon.to_global(polygon.polygon[0]), Vector2.ZERO)
							for vertex: Vector2 in polygon.polygon:
								bounds = bounds.expand(polygon.to_global(vertex))
							beds.append({"node": str(chunk.get_path_to(node)), "bounds": {"position": [bounds.position.x, bounds.position.y], "size": [bounds.size.x, bounds.size.y]}, "camera_world_px": [bounds.get_center().x, bounds.get_center().y]})
				var plaza_plan: Dictionary = chunk.get_meta(PLAZA.META_PLAN, {})
				_bed_attempts.append({"family": str(target.family), "attempt_seed": attempt_seed, "plan_seed": int(plan.seed), "coord": [coord.x, coord.y], "role": str(role), "actual_bed_nodes": beds.size(), "matching_seed_number": matching})
				if not beds.is_empty():
					var focus: Array = beds[0].camera_world_px
					var local_cell: Vector2i = Vector2i(Vector2(float(focus[0]), float(focus[1])) - chunk.global_position) / int(fixture.manager.cell_size_px)
					var bed_rect: Rect2i = Rect2i()
					for island: Dictionary in plaza_plan.get("islands", []):
						var rect: Rect2i = island.get("bed", Rect2i())
						if rect.has_area() and rect.has_point(local_cell):
							bed_rect = rect
							break
					result = {"segment": int(target.segment), "family": str(target.family), "attempt_seed": attempt_seed, "plan_seed": int(plan.seed), "coord": [coord.x, coord.y], "role": str(role), "state": int(plaza_plan.get("state", -1)), "bed_rect_cells": {"position": [bed_rect.position.x, bed_rect.position.y], "size": [bed_rect.size.x, bed_rect.size.y]}, "camera_world_px": focus, "actual_fixture_bed_nodes": beds, "candidate_only_not_native_validated": true, "fixture_ground_splat_enabled": false, "matching_seed_number": matching}
				fixture.manager.free()
				fixture.clear()
				PLAZA.enabled = true
				await get_tree().process_frame
				if not result.is_empty():
					break
		_check(not result.is_empty(), "bounded natural fixture bed found for " + str(target.family))
		if not result.is_empty():
			_bed_results.append(result)
		print("BED_DISCOVERY family=%s matching_seeds=%d found=%s" % [str(target.family), matching, str(not result.is_empty())])
	PLAZA.enabled = true
	KIT.release_static_caches()
	player.free()
	Global.attempt_segment = previous_segment
	Global.attempt_world_seed = previous_seed
	_check(SaveManager.debug_save_writes == writes_before, "bed discovery makes no save writes")
	var helper: String = get_script().resource_path
	var hashes: Dictionary = {}
	for source: String in [helper, "res://tools/tests/PlazaPresentationTest.gd", "res://core/systems/world/proc/chunkgen/PlazaPresentation.gd", "res://scenes/world/plazas/PlazaDressing.gd"]:
		hashes[source] = FileAccess.get_sha256(source)
	var report: Dictionary = {"scope": "Bounded headless existing _fixture discovery; no HUD or native visual claim. First planned coord per role, <=8 naturally matching seeds per family within1..400, first actual bed node only.", "source_sha256": hashes, "results": _bed_results, "attempts": _bed_attempts, "failures": _failures, "save_writes": SaveManager.debug_save_writes - writes_before}
	var file: FileAccess = FileAccess.open(_bed_output, FileAccess.WRITE)
	if file == null:
		_check(false, "cannot write bed discovery JSON")
	else:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	await get_tree().process_frame
	print("PlazaBedDiscovery: results=%d fixtures=%d failures=%d" % [_bed_results.size(), _bed_attempts.size(), _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _exit_tree() -> void:
	PLAZA.enabled = true
