extends "res://tools/dev/EliteCrowdFightPreview.gd"
## External unchanged before/after actual-Game scenery timer. No readback.
## Atmosphere/profile/material processing remains live after simulation staging.

var _cost_segment: int = 2
var _cost_seed: int = 16102026
var _cost_camera: Vector2 = Vector2.INF
var _cost_size: Vector2i = Vector2i(960, 540)
var _cost_frames: int = 120
var _cost_rounds: int = 3
var _cost_warmup: int = 45
var _cost_fps: int = 30
var _cost_json: String = ""
var _cost_theme: String = ""
var _cost_select_theme: String = ""
var _cost_requested_seed: int = 16102026
var _cost_fullscreen: bool = false
var _cost_shader_sources: Dictionary = {}
var _cost_hidden: Array[String] = []
var _cost_parking: Dictionary = {}
var _cost_volumes: Array[IndoorVolume] = []
var _cost_roofs: Array[RoofOverlay] = []
var _cost_kits: Array[Node2D] = []
var _cost_diagnose_only: bool = false
var _cost_phase: String = "arguments"
var _cost_before_freeze: Dictionary = {}
var _cost_after_freeze: Dictionary = {}
var _cost_before_visibility: Array[Dictionary] = []
var _cost_after_visibility: Array[Dictionary] = []
var _cost_report_written: bool = false


func _enter_tree() -> void:
	super._enter_tree()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--segment="): _cost_segment = int(arg.trim_prefix("--segment="))
		elif arg.begins_with("--world-seed="): _cost_seed = int(arg.trim_prefix("--world-seed="))
		elif arg.begins_with("--frames="): _cost_frames = clampi(int(arg.trim_prefix("--frames=")), 10, 600)
		elif arg.begins_with("--rounds="): _cost_rounds = clampi(int(arg.trim_prefix("--rounds=")), 1, 8)
		elif arg.begins_with("--warmup="): _cost_warmup = clampi(int(arg.trim_prefix("--warmup=")), 12, 300)
		elif arg.begins_with("--sample-fps="): _cost_fps = 30 if int(arg.trim_prefix("--sample-fps=")) < 45 else 60
		elif arg.begins_with("--json="): _cost_json = arg.trim_prefix("--json=")
		elif arg.begins_with("--expect-theme="): _cost_theme = arg.trim_prefix("--expect-theme=")
		elif arg.begins_with("--theme="): _cost_select_theme = arg.trim_prefix("--theme=")
		elif arg == "--fullscreen": _cost_fullscreen = true
		elif arg == "--diagnose-only": _cost_diagnose_only = true
		elif arg.begins_with("--camera="):
			var parts: PackedStringArray = arg.trim_prefix("--camera=").split(",")
			if parts.size() == 2 and parts[0].is_valid_float() and parts[1].is_valid_float(): _cost_camera = Vector2(float(parts[0]), float(parts[1]))
		elif arg.begins_with("--size="):
			var parts: PackedStringArray = arg.trim_prefix("--size=").split("x")
			if parts.size() == 2: _cost_size = Vector2i(clampi(int(parts[0]), 640, 1920), clampi(int(parts[1]), 360, 1080))


func _run() -> void:
	if DisplayServer.get_name() == "headless" or _cost_camera == Vector2.INF or not _cost_json.is_absolute_path() or _cost_segment not in [2, 6, 7, 9]:
		_fail("Native S2/S6/S7/S9, explicit --camera and absolute --json are required")
		await _shutdown()
		return
	_cost_phase = "runtime_setup"
	var setup_started: int = Time.get_ticks_usec()
	_cost_requested_seed = _cost_seed
	if not _cost_select_theme.is_empty():
		var found: bool = false
		for step: int in range(400):
			if String(SegmentThemePicker.get_theme(_cost_segment, _cost_requested_seed + step).id) == _cost_select_theme:
				_cost_seed = _cost_requested_seed + step
				found = true
				break
		if not found:
			_fail("Theme selector could not find a seed in its disclosed 400-seed window")
			await _shutdown()
			return
	_prepare_runtime()
	Engine.max_fps = 30
	Global.attempt_segment = _cost_segment
	Global.attempt_world_seed = _cost_seed
	Global.attempt_checkpoint_pos = _cost_camera
	Global._rng.seed = _cost_seed
	seed(_cost_seed)
	get_window().size = _cost_size
	if _cost_fullscreen: get_window().mode = Window.MODE_FULLSCREEN
	_game = GAME.instantiate() as Node2D
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as CharacterBody2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_camera.top_level = true
	_camera.zoom = Vector2.ONE
	_camera.global_position = _cost_camera
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	_chunks = _game.get_node("ChunkManager") as ChunkManager
	await _cost_settle()
	_dismiss_dossiers()
	var builder: Node = get_tree().get_first_node_in_group(&"segment_proc_builder")
	if builder == null or _failures > 0:
		_fail("Actual generated Game did not establish its segment builder")
		await _shutdown()
		return
	var theme: String = String(_chunks.get("district_family"))
	if _cost_fullscreen and get_window().size != _cost_size: _fail("Fullscreen did not supply the requested native dimensions; actual dimensions are recorded")
	if not _cost_theme.is_empty() and theme != _cost_theme: _fail("Actual theme differs from --expect-theme; seed was not rerolled")
	if not _cost_select_theme.is_empty() and theme != _cost_select_theme: _fail("Generated theme differs from its selected seed")
	_cost_phase = "exterior_parking"
	var parking: Vector2 = _cost_find_exterior_parking()
	if parking == Vector2.INF:
		_fail("No nearby real walkable exterior cell clears indoor bounds and the actual player capsule")
		await _shutdown()
		return
	_cost_parking = {"selected_world": [parking.x, parking.y], "selected_cell": str(_chunks.world_to_cell(parking)), "clearance_px": 64.0, "static_capsule_checked": true, "camera_unchanged": str(_cost_camera)}
	_player.global_position = parking
	_player.velocity = Vector2.ZERO
	_camera.global_position = _cost_camera
	_camera.force_update_scroll()
	await _cost_settle()
	_dismiss_dossiers()
	_cost_collect_exterior_owners()
	_cost_phase = "ordinary_exterior_settle"
	var parking_physics_start: int = Engine.get_physics_frames()
	var stable: int = 0
	for settle_frame: int in range(240):
		await get_tree().physics_frame
		await get_tree().process_frame
		if get_tree().paused: _dismiss_dossiers()
		stable = stable + 1 if _cost_exterior_ready() else 0
		if stable >= 3 and Engine.get_physics_frames() - parking_physics_start >= 4: break
	_cost_parking["after_settle_world"] = [_player.global_position.x, _player.global_position.y]
	_cost_parking["ordinary_physics_frames_after_stream_settle"] = Engine.get_physics_frames() - parking_physics_start
	_cost_parking["outside_and_opaque_before_freeze"] = stable >= 3 and _cost_exterior_ready()
	_cost_before_freeze = _cost_exterior_state()
	_cost_before_visibility = _cost_visibility_chain(_chunks)
	if not bool(_cost_parking.outside_and_opaque_before_freeze) or _player.global_position.distance_to(parking) > 1.0:
		_fail("Ordinary exterior parking did not settle all indoor exits and opaque roof/facade owners before freeze")
		await _shutdown()
		return
	_cost_phase = "freeze_non_scenery"
	# Only after ordinary settle: freeze simulation/streaming and exclude
	# non-scenery drawing. Chunk scenery and its atmosphere remain processing.
	builder.set_process(false)
	_chunks.set_process(false)
	_game.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
	EnemySimulationScheduler.set_physics_process(false)
	ProjectileManager.set_physics_process(false)
	var physics_count: int = 0
	for node: Node in [_game] + _game.find_children("*", "", true, false):
		if node.is_physics_processing(): physics_count += 1
		node.set_physics_process(false)
	for actor: Node in get_tree().get_nodes_in_group(&"enemies"): actor.process_mode = Node.PROCESS_MODE_DISABLED
	for child: Node in _game.get_children() + get_tree().root.get_children():
		if child in [_chunks, _game, self]: continue
		if child is CanvasItem or child is CanvasLayer:
			_cost_hidden.append(str(child.get_path()))
			child.set("visible", false)
			child.process_mode = Node.PROCESS_MODE_DISABLED
	_camera.global_position = _cost_camera
	_camera.force_update_scroll()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var viewport_rid: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	_cost_phase = "initial_full_fixture"
	var initial: Dictionary = _cost_fixture()
	_cost_after_freeze = initial
	_cost_after_visibility = _cost_visibility_chain(_chunks)
	if not bool(initial.exterior_state.all_opaque_outside):
		_fail("Exterior fixture has no in-view opaque roof/facade owners or failed normal outside state")
		await _shutdown()
		return
	if _cost_diagnose_only:
		_cost_phase = "diagnostic_complete_before_ready"
		_cost_write_diagnostic("diagnostic_complete")
		await _shutdown()
		return
	_cost_phase = "sampling"
	var setup_seconds: float = float(Time.get_ticks_usec()-setup_started)/1000000.0
	print("TOOL_COST_READY")
	await get_tree().create_timer(1.0, true, false, true).timeout
	Engine.max_fps = _cost_fps
	await _cost_wait_frames(_cost_warmup)
	var available_wait: int = 0
	while RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid) <= 0.0 and available_wait < 120:
		available_wait += 1
		await get_tree().process_frame
	var rounds: Array[Dictionary] = []
	var sampling_started: int = Time.get_ticks_usec()
	var drawn_start: int = Engine.get_frames_drawn()
	for round_index: int in range(_cost_rounds):
		if round_index > 0:
			Engine.max_fps = 10
			await get_tree().create_timer(1.0, true, false, true).timeout
			Engine.max_fps = _cost_fps
			await _cost_wait_frames(_cost_warmup)
		var values: Dictionary = {"gpu_ms":[], "viewport_cpu_ms":[], "setup_cpu_ms":[], "process_ms":[], "frame_ms":[], "draw_calls":[], "primitives":[]}
		var samples: Array[Dictionary] = []
		var drawn_round_start: int = Engine.get_frames_drawn()
		var last: int = Time.get_ticks_usec()
		for _frame: int in range(_cost_frames):
			await get_tree().process_frame
			var now: int = Time.get_ticks_usec()
			var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
			var row: Dictionary = {"drawn_frame":Engine.get_frames_drawn(), "gpu_ms":gpu, "viewport_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid), "setup_cpu_ms":RenderingServer.get_frame_setup_time_cpu(), "process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0, "frame_ms":float(now-last)/1000.0, "draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
			last = now
			samples.append(row)
			for key: String in values:
				if key != "gpu_ms" or gpu > 0.0: (values[key] as Array).append(float(row[key]))
		var summary: Dictionary = {}
		for key: String in values: summary[key] = _cost_distribution(values[key])
		rounds.append({"round":round_index, "requested_frames":_cost_frames, "drawn_frames":Engine.get_frames_drawn()-drawn_round_start, "gpu_positive_samples":(values.gpu_ms as Array).size(), "summary":summary, "samples":samples})
		if (values.gpu_ms as Array).size() != _cost_frames: _fail("Viewport GPU timer did not supply positive observations for every sampled frame")
	var sampling_seconds: float = float(Time.get_ticks_usec()-sampling_started)/1000000.0
	var final: Dictionary = _cost_fixture()
	if initial.physical_sha256 != final.physical_sha256 or initial.chunks != final.chunks: _fail("Frozen fixture geometry/chunk set changed during sampling")
	if initial.exterior_state_sha256 != final.exterior_state_sha256 or not bool(initial.exterior_state.all_opaque_outside) or not bool(final.exterior_state.all_opaque_outside): _fail("Roof/facade/exterior owner state changed or was not opaque during sampling")
	if SaveManager.debug_save_writes != _save_writes_before or SaveManager.current_save != null: _fail("Static cost fixture selected or wrote a profile")
	var report: Dictionary = {"tool":get_script().resource_path, "helper_sha256":FileAccess.get_sha256(get_script().resource_path), "args":OS.get_cmdline_user_args(), "segment":_cost_segment, "requested_seed":_cost_requested_seed, "seed":_cost_seed, "requested_theme":_cost_select_theme, "actual_theme":theme, "requested_fullscreen":_cost_fullscreen, "sample_fps_cap":Engine.max_fps, "warmup_frames":_cost_warmup, "setup_wall_seconds":setup_seconds, "sampling_with_round_cooldowns_seconds":sampling_seconds, "gpu_availability_wait_frames":available_wait, "drawn_frames_during_rounds":Engine.get_frames_drawn()-drawn_start, "rounds":rounds, "fixture_initial":initial, "fixture_final":final, "hidden_non_scenery":_cost_hidden, "physics_nodes_disabled_after_settle":physics_count, "reduced_motion":_reduced_motion, "shader_source_fingerprints":_cost_shader_sources, "renderer":RenderingServer.get_current_rendering_method(), "adapter":RenderingServer.get_video_adapter_name(), "api":RenderingServer.get_video_adapter_api_version(), "save_writes":SaveManager.debug_save_writes-_save_writes_before, "failures":_failures, "limits":"Actual generated Game, staged checkpoint/camera. AI/physics/streaming frozen only after settle; non-scenery Game/root canvas/HUD owners hidden and disabled. Chunk scenery, atmosphere motion/profile and materials remain live, without strength overrides or shader substitutions. No framebuffer readback, PNG or per-frame I/O. GPU values are positive last-frame viewport timer observations; timestamp-query identity is not exposed. CPU viewport/setup timers cover rendering; process timer is this static fixture, not live-Game CPU budget. Frame periods include the cap; no throughput claim. Shader hashes identify source/includes, not compiled driver binaries."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_cost_json.get_base_dir()))
	var file: FileAccess = FileAccess.open(_cost_json, FileAccess.WRITE)
	if file == null: _fail("Cannot write cost JSON")
	else:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
		_cost_report_written = true
	print("Stage4StaticCostProbe: rounds=%d frames=%d failures=%d -> %s" % [_cost_rounds, _cost_frames, _failures, _cost_json])
	await _shutdown()


func _cost_settle() -> void:
	for frame: int in range(900):
		await get_tree().process_frame
		if frame >= 30 and _chunks.loaded_chunk_count() > 0 and _chunks.debug_chunk_queue().is_empty() and _chunks.pending_blocker_stage_count() == 0: return
	_fail("Actual Game streaming did not settle")


func _cost_wait_frames(count: int) -> void:
	for _frame: int in range(count): await get_tree().process_frame


func _cost_distribution(values: Array) -> Dictionary:
	if values.is_empty(): return {"count":0, "p50":-1.0, "p95":-1.0}
	var sorted: Array = values.duplicate()
	sorted.sort()
	return {"count":sorted.size(), "min":sorted.front(), "p50":sorted[(sorted.size()-1)>>1], "p95":sorted[ceili(float(sorted.size()-1)*0.95)], "max":sorted.back()}


func _cost_fixture() -> Dictionary:
	var coords: Array = (_chunks.get("_chunks") as Dictionary).keys()
	coords.sort()
	var geometry_digest: HashingContext = HashingContext.new()
	geometry_digest.start(HashingContext.HASH_SHA256)
	var chunks: Array[Dictionary] = []
	for coord: Vector2i in coords:
		var data: ChunkBuildData = _chunks.get_chunk_build_data(coord)
		if data == null: continue
		var bytes: PackedByteArray = var_to_bytes([coord, data.blocker_kind_code, data.blocker_mask, data.blocker_variant, data.floor_rect_and_style, data.floor_alpha])
		geometry_digest.update(bytes)
		chunks.append({"coord":str(coord), "blocker_bytes":data.blocker_kind_code.size(), "floors":data.floor_alpha.size()})
	var materials: Dictionary = {}
	var polygons: int = 0
	for node: Node in [_chunks] + _chunks.find_children("*", "", true, false):
		var item: CanvasItem = node as CanvasItem
		if item == null or not item.is_visible_in_tree(): continue
		if item is Polygon2D: polygons += 1
		var material: ShaderMaterial = item.material as ShaderMaterial
		if material == null or material.shader == null: continue
		var shader: Shader = material.shader
		var key: String = shader.resource_path if not shader.resource_path.is_empty() else "inline:" + shader.code.sha256_text()
		if not materials.has(key): materials[key] = {"owners":0, "material_ids":[], "sample_uniforms":{}, "shader_code_sha256":shader.code.sha256_text()}
		materials[key].owners = int(materials[key].owners) + 1
		var ids: Array = materials[key].material_ids
		if not ids.has(material.get_instance_id()): ids.append(material.get_instance_id())
		if (materials[key].sample_uniforms as Dictionary).is_empty():
			for uniform: Dictionary in shader.get_shader_uniform_list():
				var value: Variant = material.get_shader_parameter(uniform.name)
				materials[key].sample_uniforms[String(uniform.name)] = (value as Resource).resource_path if value is Resource else var_to_str(value)
		_cost_shader_source(shader.resource_path)
	for key: String in materials:
		materials[key].unique_materials = (materials[key].material_ids as Array).size()
		materials[key].erase("material_ids")
	var atmosphere: Node = _chunks.get_node_or_null("WorldAtmosphere")
	var air: Dictionary = atmosphere.call("diagnostics") as Dictionary if atmosphere != null and atmosphere.has_method("diagnostics") else {}
	var inverse: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var world_rect: Rect2 = inverse * viewport_rect
	var splat: GroundSplatRenderer = _chunks.get_ground_splat()
	var terrain: Array[Dictionary] = []
	var globals: Dictionary = {}
	# Project declarations only. RenderingServer global get/list are editor APIs;
	# runtime overrides are deliberately not queried or claimed here.
	for property: Dictionary in ProjectSettings.get_property_list():
		var setting: String = String(property.name)
		if setting.begins_with("shader_globals/"):
			globals[setting.trim_prefix("shader_globals/")] = var_to_str(ProjectSettings.get_setting(setting))
	for offset: Vector2i in [Vector2i(-8,-4),Vector2i(0,-4),Vector2i(8,-4),Vector2i(-8,0),Vector2i.ZERO,Vector2i(8,0),Vector2i(-8,4),Vector2i(0,4),Vector2i(8,4)]:
		var cell: Vector2i = _chunks.world_to_cell(_cost_camera) + offset
		terrain.append({"cell":str(cell), "material":splat.material_at(cell) if splat != null else -1})
	var exterior: Dictionary = _cost_exterior_state()
	return {"player_parking":_cost_parking, "exterior_state":exterior, "exterior_state_sha256":JSON.stringify(exterior).sha256_text(), "camera":str(_camera.global_position), "zoom":str(_camera.zoom), "requested_window":str(_cost_size), "actual_window":str(get_window().size), "viewport_texture_size":str(get_viewport().get_texture().get_size()), "window_mode":get_window().mode, "viewport":str(viewport_rect), "canvas_transform":str(get_viewport().get_canvas_transform()), "world_bounds":str(world_rect), "chunks":chunks, "physical_sha256":geometry_digest.finish().hex_encode(), "visible_polygons":polygons, "material_counts":materials, "atmosphere":air, "atmosphere_processing":atmosphere.is_processing() if atmosphere != null else false, "declared_project_shader_globals":globals, "shader_global_observation":"Declared project defaults only; live overrides are not queried", "terrain_samples":terrain, "ground_quads":splat.quad_count() if splat != null else 0}


func _cost_shader_source(path: String) -> void:
	if path.is_empty() or _cost_shader_sources.has(path) or not FileAccess.file_exists(path): return
	_cost_shader_sources[path] = FileAccess.get_sha256(path)
	var includes: RegEx = RegEx.new()
	includes.compile('#include\\s+"([^"]+)"')
	for match_result: RegExMatch in includes.search_all(FileAccess.get_file_as_string(path)):
		var dependency: String = match_result.get_string(1)
		_cost_shader_source(dependency if dependency.begins_with("res://") else path.get_base_dir().path_join(dependency))


## Reject actual indoor rectangles and conservative whole kit bounds, including
## irregular compound footprints, with clearance for the unchanged capsule.
func _cost_outside_bounds(point: Vector2, margin: float) -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"indoor_volume"):
		var volume: IndoorVolume = node as IndoorVolume
		if volume == null or not _chunks.is_ancestor_of(volume): continue
		var extent: Vector2 = Vector2(volume.size_cells) * float(volume.cell_size_px)
		if Rect2(volume.global_position - extent * 0.5, extent).grow(margin).has_point(point): return false
	for node: Node in get_tree().get_nodes_in_group(&"city_block_building"):
		var kit: Node2D = node as Node2D
		if kit == null or not _chunks.is_ancestor_of(kit): continue
		var local: Rect2 = kit.get("bounds")
		if (kit.global_transform * local).grow(margin).has_point(point): return false
	return true


func _cost_find_exterior_parking() -> Vector2:
	var capsule: CollisionShape2D = _player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if capsule == null or capsule.shape == null: return Vector2.INF
	var centre: Vector2i = _chunks.world_to_cell(_cost_camera)
	var candidates: Array[Vector2i] = []
	for y: int in range(-16, 17):
		for x: int in range(-16, 17): candidates.append(centre + Vector2i(x, y))
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = (a-centre).length_squared()
		var db: int = (b-centre).length_squared()
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = capsule.shape
	query.collision_mask = _player.collision_mask & ~2 # Static world/cover; exclude live enemy placement from selection.
	query.exclude = [_player.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = 2.0
	for cell: Vector2i in candidates:
		if not _chunks.is_cell_walkable(cell): continue
		var point: Vector2 = _chunks.cell_to_world_center(cell)
		if not _cost_outside_bounds(point, 64.0): continue
		var placement: Transform2D = capsule.global_transform
		placement.origin += point - _player.global_position
		query.transform = placement
		if _player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty(): return point
	return Vector2.INF


func _cost_collect_exterior_owners() -> void:
	_cost_volumes.clear()
	_cost_roofs.clear()
	_cost_kits.clear()
	for node: Node in _chunks.find_children("*", "", true, false):
		if node is IndoorVolume: _cost_volumes.append(node as IndoorVolume)
		if node is RoofOverlay: _cost_roofs.append(node as RoofOverlay)
		if node is Node2D and node.is_in_group(&"city_block_building"): _cost_kits.append(node as Node2D)


func _cost_exterior_ready() -> bool:
	if _cost_roofs.is_empty() or _cost_kits.is_empty() or not _cost_outside_bounds(_player.global_position, 64.0): return false
	for volume: IndoorVolume in _cost_volumes:
		if not is_instance_valid(volume) or volume.contains_world_point(_player.global_position) or volume.overlaps_body(_player) or bool(volume.get("_player_inside")): return false
	for roof: RoofOverlay in _cost_roofs:
		if not is_instance_valid(roof) or int(roof.get("_inside_count")) != 0: return false
		var host: Polygon2D = roof.get_node_or_null("RoofPoly") as Polygon2D
		var tween: Tween = roof.get("_tween") as Tween
		if host == null or host.modulate.a < 0.99999 or roof.effective_outside_alpha() < 0.99999 or (tween != null and tween.is_running()): return false
	for kit: Node2D in _cost_kits:
		if not is_instance_valid(kit) or float(kit.get("_facade_alpha")) < 0.99999: return false
		for child: Node in kit.get_children():
			if child is CanvasItem and child.has_meta(&"city_facade_detail") and _cost_inherited_alpha(child as CanvasItem) < 0.99999: return false
	return true


func _cost_inherited_alpha(item: CanvasItem) -> float:
	var alpha: float = item.self_modulate.a
	var parent: Node = item
	while parent != null:
		if parent is CanvasItem: alpha *= (parent as CanvasItem).modulate.a
		parent = parent.get_parent()
	return alpha


func _cost_world_points(owner: Node2D, points: PackedVector2Array) -> Array:
	var result: Array = []
	for point: Vector2 in points:
		var world: Vector2 = owner.to_global(point)
		result.append([world.x, world.y])
	return result


func _cost_rect_points(owner: Node2D, rect: Rect2) -> Array:
	return _cost_world_points(owner, PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]))


## Stable keys use actual world geometry/anchors, never NodeIDs or names.
func _cost_exterior_state() -> Dictionary:
	var roofs: Array[Dictionary] = []
	var planes: Array[Dictionary] = []
	var facades: Array[Dictionary] = []
	var volumes: Array[Dictionary] = []
	var world_view: Rect2 = get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
	var visible_roof_planes: int = 0
	var visible_facades: int = 0
	var opaque: bool = _cost_exterior_ready()
	var issues: Array[Dictionary] = []
	var non_drawable: Array[Dictionary] = []
	var transparent_hosts: Array[Dictionary] = []
	if not opaque: issues.append({"reason":"normal_exterior_readiness_false"})
	for volume: IndoorVolume in _cost_volumes:
		var size: Vector2 = Vector2(volume.size_cells) * float(volume.cell_size_px)
		var rect: Rect2 = Rect2(volume.global_position - size * 0.5, size)
		var geometry: Array = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		var connected: Array[String] = []
		for connection: Dictionary in volume.body_entered.get_connections():
			var owner: Object = (connection.callable as Callable).get_object()
			if owner is RoofOverlay:
				var linked: RoofOverlay = owner as RoofOverlay
				connected.append("roof:" + JSON.stringify(_cost_world_points(linked, linked.footprint_outline_px)).sha256_text())
		connected.sort()
		volumes.append({"key": "volume:" + JSON.stringify(geometry).sha256_text(), "rect": geometry, "connected_roof_keys": connected, "contains_player": volume.contains_world_point(_player.global_position), "overlaps_player_body": volume.overlaps_body(_player), "player_inside_flag": bool(volume.get("_player_inside"))})
	for roof: RoofOverlay in _cost_roofs:
		var outline: Array = _cost_world_points(roof, roof.footprint_outline_px)
		var key: String = "roof:" + JSON.stringify(outline).sha256_text()
		var host: Polygon2D = roof.get_node("RoofPoly") as Polygon2D
		var tween: Tween = roof.get("_tween") as Tween
		roofs.append({"key": key, "world_footprint": outline, "inside_count": int(roof.get("_inside_count")), "host_modulate_alpha": host.modulate.a, "host_inherited_alpha": _cost_inherited_alpha(host), "host_color_alpha": host.color.a, "outside_target_alpha": roof.effective_outside_alpha(), "tween_running": tween != null and tween.is_running()})
		for node: Node in [host] + host.find_children("*", "", true, false):
			var plane: Polygon2D = node as Polygon2D
			if plane == null: continue
			if plane.color.a <= 0.0:
				transparent_hosts.append({"roof":key, "is_host":plane == host, "vertex_alpha":plane.color.a, "polygon_vertices":plane.polygon.size(), "form":String(plane.get_meta(&"city_roof_form", &""))})
				continue # Original gate: a compound host is transparent; children draw.
			var material: ShaderMaterial = plane.material as ShaderMaterial
			if material == null or material.shader == null or material.shader.resource_path != "res://scenes/world/buildings/roof.gdshader": continue
			if plane.polygon.size() < 3:
				opaque = false # Preserve the original failure; classify before changing it.
				var classification: String = "non_drawable_or_degenerate_plane"
				if plane.polygon.is_empty() and plane.has_meta(&"city_roof_form") and plane.get_parent().name == &"CityRoofComposition":
					classification = "empty_compound_cap_candidate_after_door_notching"
				var rejected: Dictionary = {"roof":key, "reason":"roof_shader_plane_has_fewer_than_three_vertices", "classification":classification, "polygon_vertices":plane.polygon.size(), "form":String(plane.get_meta(&"city_roof_form", &"")), "partition":String(plane.get_meta(&"city_roof_partition", &"")), "parent_kind":String(plane.get_parent().name), "visible":plane.is_visible_in_tree(), "inherited_alpha":_cost_inherited_alpha(plane), "color_alpha":plane.color.a}
				non_drawable.append(rejected)
				issues.append(rejected)
				continue
			var geometry: Array = _cost_world_points(plane, plane.polygon)
			var box: Rect2 = plane.global_transform * Rect2(plane.polygon[0], Vector2.ZERO)
			for point: Vector2 in plane.polygon: box = box.expand(plane.to_global(point))
			var in_view: bool = plane.is_visible_in_tree() and box.intersects(world_view)
			if in_view: visible_roof_planes += 1
			var alpha: float = _cost_inherited_alpha(plane) * plane.color.a
			opaque = opaque and alpha >= 0.99999 and plane.is_visible_in_tree()
			if alpha < 0.99999 or not plane.is_visible_in_tree():
				issues.append({"roof":key, "reason":"drawable_roof_plane_hidden_or_faded", "world_polygon":geometry, "visible":plane.is_visible_in_tree(), "inherited_alpha":_cost_inherited_alpha(plane), "color_alpha":plane.color.a})
			planes.append({"key": "roof-plane:" + JSON.stringify(geometry).sha256_text(), "roof": key, "world_polygon": geometry, "visible": plane.is_visible_in_tree(), "in_view_bounds": in_view, "inherited_alpha": _cost_inherited_alpha(plane), "color_alpha": plane.color.a})
	for kit: Node2D in _cost_kits:
		var bounds: Rect2 = kit.get("bounds")
		var geometry: Array = _cost_rect_points(kit, bounds)
		var key: String = "kit:" + JSON.stringify(geometry).sha256_text()
		var facade_rect: Rect2 = Rect2(bounds.position.x, float(kit.get("_front")) - float(kit.get("_facade_height")), bounds.size.x, float(kit.get("_facade_height")))
		var in_view: bool = (kit.global_transform * facade_rect).intersects(world_view)
		var groups: Array[Dictionary] = []
		for child: Node in kit.get_children():
			var owner: CanvasItem = child as CanvasItem
			if owner == null or not child.has_meta(&"city_facade_detail"): continue
			var anchor: Vector2 = (child as Node2D).global_position if child is Node2D else kit.global_position
			var alpha: float = _cost_inherited_alpha(owner)
			opaque = opaque and alpha >= 0.99999 and owner.is_visible_in_tree()
			if alpha < 0.99999 or not owner.is_visible_in_tree():
				issues.append({"kit":key, "reason":"facade_owner_hidden_or_faded", "owner_kind":String(child.name), "visible":owner.is_visible_in_tree(), "inherited_alpha":alpha, "modulate_alpha":owner.modulate.a, "self_modulate_alpha":owner.self_modulate.a})
			groups.append({"anchor": [anchor.x, anchor.y], "native_type": owner.get_class(), "inherited_alpha": alpha, "modulate_alpha": owner.modulate.a, "self_modulate_alpha": owner.self_modulate.a, "visible": owner.is_visible_in_tree()})
		groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return JSON.stringify(a) < JSON.stringify(b))
		if in_view and not groups.is_empty(): visible_facades += 1
		facades.append({"key": key, "world_bounds": geometry, "world_facade_bounds": _cost_rect_points(kit, facade_rect), "facade_alpha": float(kit.get("_facade_alpha")), "in_view_bounds": in_view, "owners": groups})
	for records: Array in [roofs, planes, facades, volumes]: records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.key) < String(b.key))
	opaque = opaque and visible_roof_planes > 0 and visible_facades > 0
	if visible_roof_planes <= 0: issues.append({"reason":"no_in_view_drawable_roof_plane"})
	if visible_facades <= 0: issues.append({"reason":"no_in_view_facade_owner"})
	return {"owner_issues":issues, "non_drawable_roof_planes":non_drawable, "transparent_roof_hosts":transparent_hosts, "all_opaque_outside": opaque, "player_world": [_player.global_position.x, _player.global_position.y], "player_walkable": _chunks.is_cell_walkable(_chunks.world_to_cell(_player.global_position)), "outside_all_bounds_with_clearance": _cost_outside_bounds(_player.global_position, 64.0), "indoor_volume_checks": volumes, "roofs": roofs, "roof_planes": planes, "facades": facades, "in_view_roof_planes": visible_roof_planes, "in_view_facades": visible_facades}


## Setup-only diagnostics. No state or shader writes, readback, timing samples,
## release marker, or comparative performance verdict on this path.
func _cost_visibility_chain(item: CanvasItem) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var current: Node = item
	while current != null:
		if current is CanvasItem:
			var canvas: CanvasItem = current as CanvasItem
			result.append({"path":str(canvas.get_path()), "visible":canvas.visible, "visible_in_tree":canvas.is_visible_in_tree(), "modulate_alpha":canvas.modulate.a, "self_modulate_alpha":canvas.self_modulate.a})
		current = current.get_parent()
	return result


func _cost_write_diagnostic(status: String) -> void:
	if not _cost_json.is_absolute_path(): return
	var report: Dictionary = {"status":status, "phase":_cost_phase, "diagnose_only":_cost_diagnose_only, "sampling_started":_cost_phase == "sampling", "tool":get_script().resource_path, "helper_sha256":FileAccess.get_sha256(get_script().resource_path), "args":OS.get_cmdline_user_args(), "segment":_cost_segment, "seed":_cost_seed, "expected_theme":_cost_theme, "actual_theme":String(_chunks.get("district_family")) if is_instance_valid(_chunks) else "", "requested_camera":str(_cost_camera), "requested_window":str(_cost_size), "pre_freeze_exterior_state":_cost_before_freeze, "post_freeze_fixture":_cost_after_freeze, "pre_freeze_scenery_visibility":_cost_before_visibility, "post_freeze_scenery_visibility":_cost_after_visibility, "hidden_non_scenery":_cost_hidden, "rounds":[], "save_writes":SaveManager.debug_save_writes-_save_writes_before, "failures":_failures, "limits":"Setup diagnostic only. Original drawable opacity, visibility, geometry and in-view gates remain unchanged. Empty compound-cap candidates are classified but still fail. Declared project shader defaults are separate from actual atmosphere diagnostics. No TOOL_COST_READY, timing samples, performance or pair acceptance."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_cost_json.get_base_dir()))
	var file: FileAccess = FileAccess.open(_cost_json, FileAccess.WRITE)
	if file == null:
		_fail("Cannot persist pre-shutdown cost diagnostic")
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	_cost_report_written = true
	print("Stage4StaticCostProbe diagnostic: phase=%s failures=%d -> %s" % [_cost_phase, _failures, _cost_json])


func _shutdown() -> void:
	if not _cost_report_written:
		_cost_write_diagnostic("failed_before_or_during_sampling" if _failures > 0 else "diagnostic_incomplete")
	await super._shutdown()
