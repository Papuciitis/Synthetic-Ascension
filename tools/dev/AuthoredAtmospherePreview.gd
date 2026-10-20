extends "res://tools/dev/EliteCrowdFightPreview.gd"
## Native owner regression for actual S1 Game and actual Hub, not a procedural
## preview with its segment clamped. -- --review=small|normal|reduced --out=...
## Optional --authored-context=s1|hub|both. Both is the normal bounded run.
## Opening is marked completed; combat/progression are muted only in this
## isolated fixture. Lighting, VisionRig and authored Hub assets stay live.

const HUB := preload("res://scenes/hub/HubWorld.tscn")
const VISION := preload("res://scenes/vision/VisionRig.tscn")
const BINDER_PATH := "res://core/systems/world/atmosphere/GameAtmosphereBinder.gd"
const AUTHORED_SEED := 16102026
var _authored_review := "small"
var _authored_context := "both"
var _hub: HubWorld
var _authored_passes := 0
var _contexts: Array[Dictionary] = []


func _enter_tree() -> void:
	super._enter_tree()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--review="):
			_authored_review = arg.trim_prefix("--review=")
		if arg.begins_with("--authored-context="):
			_authored_context = arg.trim_prefix("--authored-context=")
	if _out == "user://dev_previews/elite_crowd_fight":
		_out = "user://dev_previews/authored_atmosphere"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Actual authored-space screenshots require a native renderer")
		await _shutdown()
		return
	if _authored_context not in ["s1","hub","both"] or _authored_review not in ["small","normal","reduced"]:
		_fail("Unknown authored context or review size")
		await _shutdown()
		return
	_reduced_motion = _authored_review == "reduced"
	_prepare_runtime() # Established isolated Game setup; no selected save.
	Global.attempt_world_seed = AUTHORED_SEED
	get_window().title = "Synthetic Ascension — authored atmosphere regression"
	get_window().size = Vector2i(1280,720) if _authored_review == "normal" else Vector2i(960,540)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	if _authored_context in ["s1","both"]:
		await _capture_s1()
	if _authored_context in ["hub","both"]:
		await _capture_hub()
	var writes := SaveManager.debug_save_writes-_save_writes_before
	_check(writes == 0 and SaveManager.current_save == null and SaveManager.current_slot == -1, "authored-context preview selects no profile and performs no save writes")
	var report := FileAccess.open(_out.path_join("authored-atmosphere-info.json"),FileAccess.WRITE)
	if report == null:
		_fail("Cannot write authored atmosphere report")
	else:
		report.store_string(JSON.stringify({"tool":"res://tools/dev/AuthoredAtmospherePreview.tscn",
			"args":OS.get_cmdline_user_args(),"contexts":_contexts,"passes":_authored_passes,
			"failures":_failures,"save_writes":writes,"source_hashes":_source_hashes(),
			"limits":"Stationary native owner regression in an isolated process. S1 opening is already completed, ambient spawner and player physics/attacks are muted, and progression stops after construction. Hub uses the production completed-S2 arrival transaction with mandatory UI choices cleared for this fixture, a fixed crowd seed and a staged overview camera. Authored lighting and VisionRig are not replaced. This is not prologue, traversal, combat, balance or all-theme acceptance."},"\t"))
		report.close()
	print("AuthoredAtmospherePreview: %d passed, %d failed, save_writes=%d" % [_authored_passes,_failures,writes])
	if is_instance_valid(_hub):
		_hub.queue_free()
	await _frames(2)
	await _shutdown()


func _capture_s1() -> void:
	Global.attempt_segment = 1 # Explicit actual S1: no inherited >=2 clamp.
	_game = GAME.instantiate() as Node2D
	_game.get_node("Spawner").process_mode = Node.PROCESS_MODE_DISABLED
	(_game.get_node("Player") as CharacterBody2D).set_physics_process(false)
	get_tree().root.add_child(_game)
	get_tree().current_scene = _game
	_player = _game.get_node("Player") as CharacterBody2D
	_player.set_physics_process(false)
	_player.set("_cinematic_attack_locked",true)
	var runner := _player.get_node_or_null("AscensionRunner")
	if runner != null:
		runner.set("combat_inputs_enabled",false)
	_camera = _player.get_node("Camera2D") as Camera2D
	_chunks = _game.get_node("ChunkManager") as ChunkManager
	var level := _game.get_node_or_null("Level1") as Level1Builder
	var settled := false
	for frame: int in range(600):
		await get_tree().process_frame
		if frame >= 30 and level != null and level.initial_world_ready and _chunks.debug_chunk_queue().is_empty() and _chunks.pending_blocker_stage_count() == 0:
			settled = true
			break
	_check(settled, "actual authored Level1Builder and its real world rendering finish construction")
	_dismiss_dossiers()
	if level != null:
		level.set_process(false)
	_chunks.set_process(false)
	_camera.reset_smoothing()
	_camera.force_update_scroll()
	# VisionRig must discover the actual volumes on its own normal interval.
	await get_tree().create_timer(1.4).timeout
	await _wait_for_quiet(_game)
	var atmosphere := _chunks.get_node_or_null("WorldAtmosphere") as WorldAtmosphere
	var rig := _game.get_node_or_null("VisionRig") as VisionRig
	var profile: Dictionary = atmosphere.get_profile() if atmosphere != null else {}
	_check(Global.attempt_segment == 1 and level != null and not _chunks.generation_enabled and get_tree().get_nodes_in_group(&"segment_proc_builder").is_empty(), "actual Game retains S1 authored ownership rather than a procedural segment")
	_check(atmosphere != null and not atmosphere.visible and profile.get("context") == &"institution" and profile.get("enabled") == false, "actual S1 binder applies the explicit disabled institution context")
	var atmospheric_nodes := _atmosphere_nodes(_game)
	_check(atmospheric_nodes.atmospheres.size() == 1 and atmospheric_nodes.binders.size() == 1, "actual S1 has exactly one configured atmosphere and its normal Game binder")
	var vision := _vision_record(rig)
	_check(bool(vision.get("same_scene_shader",false)) and bool(vision.get("owns_material_copy",false)) and bool(vision.get("rite_signal_connected",false)), "the actual VisionRig retains its own vignette material and Rite signal ownership")
	_check(rig != null and rig.lightweight_vignette_only and rig.is_processing() and bool(rig.get("_was_indoors")) and is_equal_approx(float(vision.get("strength",-1.0)),rig.indoor_vignette_strength), "the live S1 VisionRig detects its actual indoor spawn and retains its authored strength")
	_check(EnemyWorld.active_count() == 0, "muted S1 fixture has no ambient combat population")
	var screenshot := await _capture("s1-institution")
	_contexts.append({"context":"institution","scene":"res://scenes/game.tscn","actual_segment":Global.attempt_segment,
		"seed":Global.attempt_world_seed,"level_owner":_node_record(level),"atmosphere_owner":_node_record(atmosphere),
		"atmosphere":atmosphere.diagnostics() if atmosphere != null else {},"atmosphere_nodes":atmospheric_nodes,
		"vision":vision,"player_world":_player.global_position,"camera":_camera_record(_camera),"screenshot":screenshot,
		"indoor_volumes":get_tree().get_nodes_in_group(&"indoor_volume").size(),"spawner_process_mode":_game.get_node("Spawner").process_mode,
		"player_physics":_player.is_physics_processing(),"opening_completed_fixture":Global.attempt_opening_completed,
		"builder_process_after_ready":level.is_processing() if level != null else false,"normal_hud":true})
	get_tree().current_scene = null
	_game.queue_free()
	_game = null
	_player = null
	_camera = null
	_chunks = null
	await _frames(3)


func _capture_hub() -> void:
	# Same arrival state as HubWorldTest, with no SaveData selected at all.
	Global.attempt_segment = 2
	Global.on_segment_completed(2)
	Global.pending_big_choice = false
	Global.pending_augment_pick = false
	_hub = HUB.instantiate() as HubWorld
	_hub.departure_scene_change_enabled = false
	_hub.crowd_seed = AUTHORED_SEED
	get_tree().root.add_child(_hub)
	get_tree().current_scene = _hub
	await _frames(3)
	var player := _hub.get("_player") as CharacterBody2D
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D if player != null else null
	if player != null:
		player.set_physics_process(false)
	var driver := _hub.get_node_or_null("ConversationCamera")
	if driver != null:
		driver.set_process(false)
	if camera != null:
		camera.top_level = true
		camera.global_position = HubWorld.PLAZA_CENTER*HubWorld.CELL+Vector2(0,64)
		camera.reset_smoothing()
		camera.force_update_scroll()
	# Wait out the production arrival notice rather than hiding its renderer.
	await get_tree().create_timer(5.3).timeout
	await _wait_for_quiet(_hub)
	var atmospheric_nodes := _atmosphere_nodes(get_tree().root)
	_check(Global.attempt_segment == 3 and _hub._stations.size() == 6 and player != null, "actual Hub uses the production completed-S2 arrival and six authored stations")
	_check(atmospheric_nodes.atmospheres.is_empty() and atmospheric_nodes.binders.is_empty(), "actual Hub has no procedural atmosphere or Game binder, including stale scene owners")
	var dusk: Array[Dictionary] = []
	var lights: Array[Dictionary] = []
	var visible_lights := 0
	for node: Node in _hub.find_children("*","",true,false):
		if node is CanvasModulate:
			var modulate := node as CanvasModulate
			dusk.append({"owner":_node_record(modulate),"color":_color(modulate.color)})
			_check(modulate.color.is_equal_approx(HubWorld.DUSK), "actual Hub CanvasModulate keeps its authored dusk color")
		elif node is PointLight2D:
			var light := node as PointLight2D
			var on_screen := get_viewport().get_visible_rect().has_point(get_viewport().get_canvas_transform()*light.global_position)
			if on_screen and light.enabled and light.energy > 0.0:
				visible_lights += 1
			lights.append({"owner":_node_record(light),"world":light.global_position,"color":_color(light.color),"energy":light.energy,
				"texture_scale":light.texture_scale,"texture_present":light.texture != null,"enabled":light.enabled,"centre_in_view":on_screen})
	_check(dusk.size() == 1 and not lights.is_empty() and visible_lights > 0, "authored Hub dusk has real enabled practical lights in the captured view")
	var runner: Node = player.get_node_or_null("AscensionRunner") if player != null else null
	_check(player != null and bool(player.get("_cinematic_attack_locked")) and runner != null and not bool(runner.get("combat_inputs_enabled")), "the actual safe-Hub controller retains its native combat lock")
	var screenshot := await _capture("hub-authored-dusk")
	_contexts.append({"context":"authored_hub","scene":"res://scenes/hub/HubWorld.tscn","actual_segment":Global.attempt_segment,
		"completed_segment_fixture":2,"crowd_seed":_hub.crowd_seed,"owner":_node_record(_hub),"atmosphere_nodes":atmospheric_nodes,
		"canvas_modulates":dusk,"practical_lights":lights,"visible_light_centres":visible_lights,"camera":_camera_record(camera),
		"player_world":player.global_position if player != null else Vector2.ZERO,"player_physics":player.is_physics_processing() if player != null else false,
		"camera_overview_fixture":true,"conversation_camera_processing":driver.is_processing() if driver != null else false,
		"station_count":_hub._stations.size(),"screenshot":screenshot})


func _vision_record(rig: VisionRig) -> Dictionary:
	if rig == null or rig.vignette_rect == null:
		return {}
	var expected := VISION.instantiate() as Node2D
	var source := (expected.get_node("VignetteLayer/Vignette") as ColorRect).material as ShaderMaterial
	var actual := rig.vignette_rect.material as ShaderMaterial
	var connected := false
	for connection: Dictionary in RunEvents.rite_distortion_changed.get_connections():
		var callback: Callable = connection.callable
		connected = connected or callback.get_object() == rig
	var record := {"owner":_node_record(rig),"vignette_owner":_node_record(rig.vignette_rect),
		"material_id":actual.get_instance_id() if actual != null else 0,"scene_material_id":source.get_instance_id(),
		"same_scene_shader":actual != null and actual.shader == source.shader,"owns_material_copy":actual != source,
		"rite_signal_connected":connected,"lightweight":rig.lightweight_vignette_only,"actual_indoors":rig.get("_was_indoors"),
		"authored_indoor_strength":rig.indoor_vignette_strength,"strength":actual.get_shader_parameter("strength") if actual != null else -1.0,
		"inner_radius":actual.get_shader_parameter("inner_radius") if actual != null else -1.0,
		"fog_visible":rig.fog_layer.visible if rig.fog_layer != null else false,"vignette_visible":rig.vignette_rect.visible}
	expected.free()
	return record


func _atmosphere_nodes(root: Node) -> Dictionary:
	var atmospheres: Array[Dictionary] = []
	var binders: Array[Dictionary] = []
	for node: Node in root.find_children("*","",true,false):
		if node is WorldAtmosphere:
			atmospheres.append(_node_record(node))
		var script := node.get_script() as Script
		if script != null and script.resource_path == BINDER_PATH:
			binders.append(_node_record(node))
	return {"atmospheres":atmospheres,"binders":binders}


func _node_record(node: Node) -> Dictionary:
	if node == null:
		return {}
	var script := node.get_script() as Script
	var record := {"path":String(node.get_path()),"id":node.get_instance_id(),"class":node.get_class(),
		"script":script.resource_path if script != null else "","processing":node.is_processing()}
	if node is CanvasItem:
		var item := node as CanvasItem
		record["visible_in_tree"] = item.is_visible_in_tree()
		record["world_id"] = item.get_world_2d().get_instance_id()
		record["canvas"] = str(item.get_canvas())
	return record


func _camera_record(camera: Camera2D) -> Dictionary:
	return {"owner":_node_record(camera),"world":camera.global_position,"centre":camera.get_screen_center_position(),"zoom":camera.zoom} if camera != null else {}


func _wait_for_quiet(root: Node) -> void:
	for _step: int in range(200):
		var busy := false
		for controller: Node in root.find_children("TutorialTipController","",true,false):
			busy = busy or bool(controller.get("_running"))
		for notice: Node in root.find_children("HubNotices","",true,false):
			var entries: Array = notice.get("notices")
			busy = busy or not entries.is_empty()
		if not busy:
			return
		await get_tree().create_timer(0.1).timeout
	_fail("Production transient HUD/arrival notices did not clear within the bounded wait")


func _capture(plate: String) -> Dictionary:
	await RenderingServer.frame_post_draw
	var pixels := get_viewport().get_texture().get_image()
	_save_image(pixels,_out.path_join(plate+".png"))
	return {"file":plate+".png","image_size":pixels.get_size(),"logical_viewport":get_viewport().get_visible_rect().size}


func _source_hashes() -> Dictionary:
	var hashes: Dictionary = {}
	for path: String in ["res://tools/dev/AuthoredAtmospherePreview.gd","res://scenes/game.tscn","res://scenes/game.gd",
		"res://scenes/hub/HubWorld.gd","res://core/systems/vision/VisionRig.gd",BINDER_PATH,
		"res://core/systems/world/atmosphere/WorldAtmosphere.gd","res://core/systems/world/atmosphere/ThemeAtmosphereProfiles.gd",
		"res://core/systems/world/atmosphere/world_atmosphere.gdshader","res://core/systems/world/atmosphere/ground_air.gdshader"]:
		hashes[path] = FileAccess.get_sha256(path)
	return hashes


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _color(value: Color) -> Array[float]:
	return [value.r,value.g,value.b,value.a]


func _check(ok: bool, message: String) -> void:
	if ok:
		_authored_passes += 1
		print("PASS: ",message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures += 1
	push_error("AuthoredAtmospherePreview: "+message)
