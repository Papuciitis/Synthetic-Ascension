extends "res://tools/dev/EliteCrowdFightPreview.gd"
## Matched, NO-READBACK GPU cost probe for the district ground shader
## (2026-10-21, ground GPU review item). The production Game streams a real
## district, simulation frozen; then every canvas item except the ground splat
## is hidden and the ground's shared material is switched between shader
## variants at the same camera and the same streamed chunk set. Each variant
## is warmed up (first-use compile excluded), then sampled with vsync off.
## The default has no frame cap; --sample-fps adds a cap and makes frame
## periods cadence measurements, not shader cost. Use valid viewport GPU
## timestamps for capped comparisons. Nothing is read back (no get_image).
## The "none" variant (ground hidden) measures the render floor. Variants are
## interleaved in rounds so drift and heat spread over all of them; the
## median of the per-round medians is reported. Where the driver supports it,
## Godot's own viewport GPU timer is reported beside the frame period.
##
## <godot> --path . --rendering-driver opengl3 --audio-driver Dummy res://tools/dev/GroundShaderCostProbe.tscn --
##   --segment=2 [--theme=service_courtyards] [--world-seed=16102026]
##   --variants=none,current,pre_policy=/abs/old.gdshader,phase1=/abs/p1.gdshader
##   [--rounds=5] [--frames=180] [--warmup=45] [--size=1920x1080] [--points=start,route1]
##   [--full] (keep the whole scene visible; only the ground variant changes)
##   [--compile-only] (draw each variant a few frames, print markers, no timing)
##   [--cooldown-seconds=3] (cap setup at30FPS, cool at10FPS between variants)
##   [--sample-fps=60] (use GPU timestamp results; frame periods include this cap)
##   [--json=/abs/out.json]
## A variant path is any ground_splat.gdshader revision; uniforms it shares with
## the production material keep the production values (ShaderMaterial keeps its
## parameters across a shader swap). A revision with the pre-policy
## city_streetscape switch is drawn with it on (the S2 look it was measured as).

const SPLAT_NAME := &"GroundSplat"

var _segment := 2
var _seed := 16102026
var _theme := ""
var _variant_specs: Array[Dictionary] = []
var _rounds := 5
var _frame_count := 180
var _warmup := 45
var _size := Vector2i(1920, 1080)
var _point_names: Array[String] = ["start", "route1"]
var _full := false
var _compile_only := false
var _json_path := ""
var _cooldown_seconds := 0.0
var _sample_fps := 0


func _enter_tree() -> void:
	super._enter_tree()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--segment="): _segment = maxi(2, int(arg.trim_prefix("--segment=")))
		elif arg.begins_with("--world-seed="): _seed = int(arg.trim_prefix("--world-seed="))
		elif arg.begins_with("--theme="): _theme = arg.trim_prefix("--theme=")
		elif arg.begins_with("--rounds="): _rounds = clampi(int(arg.trim_prefix("--rounds=")), 1, 20)
		elif arg.begins_with("--frames="): _frame_count = clampi(int(arg.trim_prefix("--frames=")), 10, 2000)
		elif arg.begins_with("--warmup="): _warmup = clampi(int(arg.trim_prefix("--warmup=")), 2, 600)
		elif arg.begins_with("--json="): _json_path = arg.trim_prefix("--json=")
		elif arg.begins_with("--cooldown-seconds="): _cooldown_seconds = clampf(float(arg.trim_prefix("--cooldown-seconds=")), 0.0, 30.0)
		elif arg.begins_with("--sample-fps="): _sample_fps = clampi(int(arg.trim_prefix("--sample-fps=")), 0, 240)
		elif arg == "--full": _full = true
		elif arg == "--compile-only": _compile_only = true
		elif arg.begins_with("--points="):
			_point_names.clear()
			for name: String in arg.trim_prefix("--points=").split(",", false): _point_names.append(name)
		elif arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			if parts.size() == 2: _size = Vector2i(maxi(64, int(parts[0])), maxi(64, int(parts[1])))
		elif arg.begins_with("--variants="):
			for item: String in arg.trim_prefix("--variants=").split(",", false):
				var eq := item.find("=")
				_variant_specs.append({"name": item if eq < 0 else item.substr(0, eq), "path": "" if eq < 0 else item.substr(eq + 1)})
	# Limit setup load; sampling uses the requested cap (0 stays uncapped).
	if _cooldown_seconds > 0.0:
		Engine.max_fps = 30
	if _variant_specs.is_empty():
		_variant_specs = [{"name": "none", "path": ""}, {"name": "current", "path": ""}]


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Native renderer is required")
		get_tree().quit(1)
		return
	if not _theme.is_empty():
		var found := false
		for step: int in 400:
			if String(SegmentThemePicker.get_theme(_segment, _seed + step).id) == _theme:
				_seed += step
				found = true
				break
		if not found:
			_fail("No seed selects theme %s for segment %d" % [_theme, _segment])
			get_tree().quit(1)
			return
	_prepare_runtime()
	if _cooldown_seconds > 0.0:
		Engine.max_fps = 30
	Global.attempt_segment = _segment
	Global.attempt_world_seed = _seed
	get_window().size = _size
	_game = GAME.instantiate() as Node2D
	_game.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
	_game.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as CharacterBody2D
	_camera = _player.get_node("Camera2D") as Camera2D
	_camera.top_level = true
	_chunks = _game.get_node("ChunkManager") as ChunkManager
	if _cooldown_seconds > 0.0:
		Engine.max_fps = 30
	await _settle()
	_dismiss_dossiers()
	var builder := get_tree().get_first_node_in_group(&"segment_proc_builder")
	if builder == null:
		_fail("Missing production segment builder")
		await _shutdown()
		return
	builder.set_process(false)
	var splat := _chunks.get_ground_splat()
	if splat == null:
		_fail("The district has no ground splat")
		await _shutdown()
		return
	var material := splat.get_shader_material()
	var production_shader := material.shader
	var variants: Array[Dictionary] = []
	for spec: Dictionary in _variant_specs:
		var entry := {"name": String(spec.name), "path": String(spec.path), "shader": null, "streetscape": false, "sha256": ""}
		if entry.name == "current":
			entry.shader = production_shader
			entry.path = production_shader.resource_path
			entry.sha256 = FileAccess.get_sha256(production_shader.resource_path)
		elif not String(entry.path).is_empty():
			if not FileAccess.file_exists(entry.path):
				_fail("Missing variant source " + String(entry.path))
				continue
			var shader := Shader.new()
			shader.code = FileAccess.get_file_as_string(entry.path)
			entry.shader = shader
			entry.sha256 = FileAccess.get_sha256(entry.path)
			entry.streetscape = shader.code.contains("uniform bool city_streetscape")
		variants.append(entry)
	var plan: Dictionary = builder.get("_plan")
	var cameras: Array[Dictionary] = []
	for name: String in _point_names:
		if name == "start":
			cameras.append({"name": name, "world": _player.global_position})
		elif name.begins_with("route"):
			var route: Array = plan.get("main_route", [])
			var index := clampi(int(name.trim_prefix("route")), 1, 8)
			if route.size() >= 2:
				var at := clampi(int(round(float(route.size() - 1) * float(index) / 3.0)), 0, route.size() - 1)
				cameras.append({"name": name, "world": (Vector2(route[at]) + Vector2.ONE * 0.5) * _chunks.chunk_size_px, "chunk": str(route[at])})
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 30 if _cooldown_seconds > 0.0 else 0
	var viewport_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	var report := {
		"segment": _segment, "world_seed": _seed, "theme": _theme, "window": [get_window().size.x, get_window().size.y],
		"ground_only": not _full, "rounds": _rounds, "frames": _frame_count, "warmup": _warmup,
		"cooldown_seconds": _cooldown_seconds, "sampling_fps_cap": _sample_fps, "setup_fps_cap": 30 if _cooldown_seconds > 0.0 else 0,
		"renderer": "%s / %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()],
		"variants": [], "points": [],
	}
	for variant: Dictionary in variants:
		(report.variants as Array).append({"name": variant.name, "path": variant.path, "sha256": variant.sha256, "streetscape": variant.streetscape})
	for camera_point: Dictionary in cameras:
		_camera.zoom = Vector2.ONE
		_camera.global_position = camera_point.world
		_player.global_position = camera_point.world
		_camera.reset_smoothing()
		_camera.force_update_scroll()
		await _settle()
		_chunks.set_process(false)
		var hidden: Array[CanvasItem] = []
		if not _full:
			hidden = _isolate_ground(splat)
		var point := {"name": camera_point.name, "world": [camera_point.world.x, camera_point.world.y], "chunks_loaded": _chunks._chunks.size(), "quads": splat.quad_count(), "results": {}}
		var samples: Dictionary = {}
		var gpu_samples: Dictionary = {}
		for variant: Dictionary in variants:
			samples[variant.name] = []
			gpu_samples[variant.name] = []
		for round_index in (1 if _compile_only else _rounds):
			for variant: Dictionary in variants:
				if _cooldown_seconds > 0.0:
					Engine.max_fps = 10
					await get_tree().create_timer(_cooldown_seconds, true, false, true).timeout
				Engine.max_fps = _sample_fps
				_apply_variant(splat, material, production_shader, variant)
				# Markers also go to stderr, in order with the driver's own compile
				# diagnostics (Mesa INTEL_DEBUG=perf writes there).
				_marker("GROUND_PROBE_VARIANT_BEGIN %s point=%s round=%d" % [variant.name, camera_point.name, round_index])
				await _frames_n(_warmup if not _compile_only else 8)
				_marker("GROUND_PROBE_VARIANT_DRAWN %s" % variant.name)
				if _compile_only:
					continue
				var periods := PackedFloat64Array()
				var gpu := PackedFloat64Array()
				var last := Time.get_ticks_usec()
				for frame in _frame_count:
					await get_tree().process_frame
					var now := Time.get_ticks_usec()
					periods.append(float(now - last) / 1000.0)
					last = now
					gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
				(samples[variant.name] as Array).append(_median(periods))
				(gpu_samples[variant.name] as Array).append(_median(gpu))
		Engine.max_fps = 30 if _cooldown_seconds > 0.0 else 0
		_apply_variant(splat, material, production_shader, {"name": "current", "shader": production_shader, "streetscape": false})
		for item: CanvasItem in hidden:
			if is_instance_valid(item): item.visible = true
		_chunks.set_process(true)
		for variant: Dictionary in variants:
			var series: Array = samples[variant.name]
			var gpu_series: Array = gpu_samples[variant.name]
			point.results[variant.name] = {
				"frame_ms_median": _median(PackedFloat64Array(series)) if not series.is_empty() else -1.0,
				"frame_ms_rounds": series,
				"gpu_ms_median": _median(PackedFloat64Array(gpu_series)) if not gpu_series.is_empty() else -1.0,
				"gpu_ms_rounds": gpu_series,
			}
		(report.points as Array).append(point)
		print("GROUND_PROBE_POINT ", JSON.stringify(point))
	print("GROUND_PROBE ", JSON.stringify(report))
	if not _json_path.is_empty():
		var file := FileAccess.open(_json_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, " ") + "\n")
	await _shutdown()


## Hide every visible canvas item of the frame except the ground splat and its
## quads (top-level game children, chunk contents, HUD layers). Returns what it
## hid so the caller can restore it.
func _isolate_ground(splat: GroundSplatRenderer) -> Array[CanvasItem]:
	var hidden: Array[CanvasItem] = []
	for child in get_tree().root.get_children():
		if child == _game or child == self:
			continue
		if child is CanvasItem and (child as CanvasItem).visible:
			(child as CanvasItem).visible = false
			hidden.append(child)
	for child in _game.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		elif child == _chunks:
			for inner in _chunks.get_children():
				if inner != splat and inner is CanvasItem and (inner as CanvasItem).visible:
					(inner as CanvasItem).visible = false
					hidden.append(inner)
		elif child is CanvasItem and (child as CanvasItem).visible and child != _camera:
			(child as CanvasItem).visible = false
			hidden.append(child)
	return hidden


func _apply_variant(splat: GroundSplatRenderer, material: ShaderMaterial, production: Shader, variant: Dictionary) -> void:
	if variant.name == "none":
		splat.visible = false
		material.shader = production
		return
	splat.visible = true
	material.shader = variant.shader if variant.shader != null else production
	if bool(variant.get("streetscape", false)):
		material.set_shader_parameter("city_streetscape", true)


func _marker(text: String) -> void:
	print(text)
	printerr(text)


func _settle() -> void:
	for frame in range(600):
		await get_tree().process_frame
		if frame >= 20 and _chunks.debug_chunk_queue().is_empty() and _chunks.pending_blocker_stage_count() == 0:
			return
	_fail("Streaming did not settle")


func _frames_n(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


static func _median(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return -1.0
	var sorted := values.duplicate()
	sorted.sort()
	var mid := sorted.size() >> 1
	return sorted[mid] if sorted.size() % 2 == 1 else 0.5 * (sorted[mid - 1] + sorted[mid])
