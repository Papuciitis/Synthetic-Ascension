extends Node2D
## Low-memory native production-chunk inspection. No authored parcel fixture,
## no Game/HUD/combat claim. Uses the same plan/theme/generator/renderers.

var out := "res://docs/art/reference/2026-10-20-s2-street/environment-v2"
var seed_value := 16102026
var target_coord := Vector2i(999999,999999)

func _enter_tree() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/street_environment/"
	PerformanceFlightRecorder.set_enabled(false)
	PerformanceFlightRecorder.automatic_capture = false
	BalanceRecorder.set_enabled(false)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--seed="): seed_value = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--coord="):
			var parts := arg.trim_prefix("--coord=").split(",")
			if parts.size() == 2: target_coord = Vector2i(int(parts[0]),int(parts[1]))
	get_window().position = Vector2i(-10000,-10000)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)

func _ready() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for index in count: await get_tree().process_frame

func run() -> void:
	get_tree().create_timer(100).timeout.connect(func() -> void: get_tree().quit(1))
	Global.attempt_segment = 2
	Global.attempt_world_seed = seed_value
	var theme := SegmentThemePicker.get_theme(2,seed_value)
	var plan := DistrictPlan.generate(2,seed_value,2048,theme)
	var coord := Vector2i.ZERO
	for candidate: Vector2i in plan.role_by_chunk:
		if plan.role_by_chunk[candidate] == &"service_lane":
			coord = candidate
			break
	if target_coord != Vector2i(999999,999999): coord = target_coord
	var at := (Vector2(coord)+Vector2.ONE*0.5)*2048
	var player := Node2D.new()
	player.add_to_group(&"player")
	player.position = at+Vector2(0,700)
	add_child(player)
	var camera := Camera2D.new()
	camera.position = at
	add_child(camera)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_size = Vector2i(1920,1080)
	get_window().size = Vector2i(1280,720)
	Engine.max_fps = 30
	var cm := ChunkManager.new()
	theme.apply_to_chunk_manager(cm)
	cm.generation_enabled = false
	cm.use_camera_stream_bounds = false
	cm.load_radius = 0
	cm.unload_radius = 0
	cm.district_sidewalk_width_cells = 1
	cm.district_sidewalk_corner_pad_cells = 1
	cm.parcels_chunk_chance = 0.95
	cm.parcels_chance_per_side = 0.80
	cm.parcels_max_per_side = 2
	cm.cover_full_scene = load("res://scenes/world/cover/CoverFull.tscn")
	cm.cover_window_scene = load("res://scenes/world/cover/CoverWindow.tscn")
	cm.cover_half_scene = load("res://scenes/world/cover/CoverHalf.tscn")
	add_child(cm)
	cm.configure_procedural_world(int(plan.seed),plan.connectors_by_chunk,plan.urban_access_by_chunk,plan.role_by_chunk,plan.terrain_by_chunk,plan.archetype_by_chunk)
	cm.start_streaming(player.position)
	await frames(35)
	cm.set_process(false)
	var rows: Array = []
	var chunk: Node = cm._chunks.get(coord)
	for kit: Node in chunk.get_children():
		if not kit.is_in_group(&"city_block_building"): continue
		rows.append({"bounds":str(kit.get("bounds")),"usage":String(kit.get_meta(&"building_usage",&"")),"civic":kit.get("civic"),"annex":kit.get_meta(&"city_service_annex",false),"doors":str(kit.get("_doors"))})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for size: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		get_window().size = size
		camera.force_update_scroll()
		await frames(8)
		await RenderingServer.frame_post_draw
		var pixels := get_viewport().get_texture().get_image()
		pixels.save_png(out.path_join("service_lane-1-%dx%d.png" % [size.x,size.y]))
	var file := FileAccess.open(out.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed":seed_value,"plan_seed":plan.seed,"coord":str(coord),"parcels":rows,"camera":str(camera.position),"zoom":str(camera.zoom),"world_viewport":"1920x1080","streaming_radius":0,"presentation":"Frozen native production ChunkManager, exact plan/theme; natural ground/props; no Game scene, HUD, player body, objectives, entry or combat proof","save_writes":SaveManager.debug_save_writes},"\t"))
	file.close()
	print("StreetEnvironmentCapture: captures=2 save_writes=%d" % SaveManager.debug_save_writes)
	cm.queue_free()
	player.queue_free()
	camera.queue_free()
	await frames(3)
	get_tree().quit()
