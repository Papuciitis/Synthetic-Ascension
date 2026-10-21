extends Node2D
## Additional review RED: a full-screen grade or generic outdoors mask cannot
## stand in for actual wet ground and environment direct/fill receivers.
## Theme sun (2026-10-21): themes vary the shared multiplicative sun shade
## (WorldDepthStyle), never roof-plane contrast or individual cast alpha.

const ATMOSPHERE := preload("res://core/systems/world/atmosphere/WorldAtmosphere.gd")
const GROUND := preload("res://core/systems/world/ground/GroundSplatRenderer.gd")
const ROOF := preload("res://scenes/world/buildings/RoofOverlay.tscn")
const ROOF_SHADER := preload("res://scenes/world/buildings/roof.gdshader")
const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")
const PROFILES := preload("res://core/systems/world/atmosphere/ThemeAtmosphereProfiles.gd")
var _passes := 0
var _failures := 0


func _enter_tree() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/theme_atmosphere_receivers/"
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir+"performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir+"balance/"
	PerformanceFlightRecorder.set_enabled(false)
	BalanceRecorder.set_enabled(false)


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ",message)
	else:
		_failures += 1
		push_error("FAIL: "+message)


func _run() -> void:
	var atmosphere := ATMOSPHERE.new() as Node2D
	add_child(atmosphere)
	_check(atmosphere.has_method("refresh_environment"), "weather owns actual wet-ground and environment direct/fill receivers")
	if not atmosphere.has_method("refresh_environment"):
		atmosphere.queue_free()
		await get_tree().process_frame
		_finish()
		return
	var rng_before := Global._rng.state
	var writes_before := SaveManager.debug_save_writes
	await _check_ground_binding(atmosphere)
	await _check_unset_defaults(atmosphere)
	await _check_environment_planes(atmosphere)
	atmosphere.queue_free()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await _check_rendered_receivers()
		await _check_rendered_roof()
	_check(Global._rng.state == rng_before, "receiver adaptation consumes no gameplay RNG")
	_check(SaveManager.debug_save_writes == writes_before, "receiver adaptation performs no save writes")
	_finish()


func _ground(parent: Node) -> GroundSplatRenderer:
	var ground := GROUND.new() as GroundSplatRenderer
	ground.configure(64,32)
	parent.add_child(ground)
	ground.set_chunk_base(Vector2i.ZERO,1)
	ground.paint_rect(Rect2i(1,0,1,1),5,1.0)
	ground.paint_rect(Rect2i(2,0,1,1),12,1.0)
	ground.paint_rect(Rect2i(3,0,1,1),5,0.12)
	ground.flush()
	return ground


func _check_ground_binding(atmosphere: Node2D) -> void:
	atmosphere.call("apply_theme",&"canal_services",&"procedural",false)
	atmosphere.call("refresh_environment",true)
	var air := atmosphere.call("get_mist_material") as ShaderMaterial
	_check(air.get_shader_parameter("ground_receiver_enabled") == false, "no matching ground host means no mist receiver")
	var ground := _ground(self)
	atmosphere.call("refresh_environment",true)
	var actual := ground.get_shader_material()
	_check(air.get_shader_parameter("ground_receiver_enabled") == true, "a live matching GroundSplat enables its physical receiver")
	_check(air.get_shader_parameter("receiver_cover_a") == actual.get_shader_parameter("cover_a") and air.get_shader_parameter("receiver_cover_b") == actual.get_shader_parameter("cover_b"), "low air samples the actual ground coverage textures")
	_check(air.get_shader_parameter("receiver_light_map") == actual.get_shader_parameter("light_map"), "low air samples the actual stain G texture")
	_check(ground.material_at(Vector2i.ZERO) == 1 and ground.material_at(Vector2i(1,0)) == 5 and ground.material_at(Vector2i(2,0)) == 12 and ground.material_at(Vector2i(3,0)) == 1, "receiver fixture retains dry1, wet5, moss12 and stained dry1 semantic ownership")
	var damp_a: Vector4 = air.get_shader_parameter("receiver_damp_a")
	_check(is_zero_approx(damp_a.x) and is_equal_approx(damp_a.y,1.0) and is_equal_approx(damp_a.z,1.0), "actual first-allocated dry/wet/moss slots receive only physical damp eligibility")
	var other_world := SubViewport.new()
	other_world.world_2d = World2D.new()
	add_child(other_world)
	var remote := _ground(other_world)
	ground.queue_free()
	await get_tree().process_frame
	atmosphere.call("refresh_environment",true)
	_check(air.get_shader_parameter("ground_receiver_enabled") == false and remote.get_world_2d() != atmosphere.get_world_2d(), "removing the local host disables air instead of borrowing another world's ground")
	other_world.queue_free()
	var layer := CanvasLayer.new()
	add_child(layer)
	var separate := _ground(layer)
	atmosphere.call("refresh_environment",true)
	_check(air.get_shader_parameter("ground_receiver_enabled") == false and separate.get_canvas() != atmosphere.get_canvas(), "another canvas cannot supply a ground receiver")
	layer.queue_free()
	await get_tree().process_frame


func _roof(parent: Node) -> RoofOverlay:
	var roof := ROOF.instantiate() as RoofOverlay
	parent.add_child(roof)
	roof.configure(Rect2i(-2,-1,4,2),64,Vector2i.DOWN,null,&"row_house",91)
	var material := (roof.get_node("RoofPoly") as Polygon2D).material as ShaderMaterial
	material.set_shader_parameter("lit_slope",1.16)
	material.set_shader_parameter("shade_slope",0.66)
	material.set_shader_parameter("ridge_light",0.35)
	return roof


func _check_unset_defaults(atmosphere: Node2D) -> void:
	var ground := GROUND.new() as GroundSplatRenderer
	ground.configure(64,32)
	add_child(ground)
	ground.set_chunk_base(Vector2i.ZERO,5)
	ground.flush()
	var source := ground.get_shader_material()
	_check(not ground.has_meta(&"_stain_set") and source.get_shader_parameter("stain_layer") == null, "default regression uses a real pure-wet host without an assigned stain uniform")
	atmosphere.call("apply_theme",&"canal_services",&"procedural",false)
	atmosphere.call("refresh_environment",true)
	var air := atmosphere.call("get_mist_material") as ShaderMaterial
	_check(air.get_shader_parameter("ground_receiver_enabled") == true and air.get_shader_parameter("receiver_damp_stain") == false, "a pure wet host renders wet receivers without inventing a stain or converting null")
	_check(is_equal_approx(float(air.get_shader_parameter("receiver_warp_cells")),0.62) and is_equal_approx(float(air.get_shader_parameter("receiver_grain")),0.3) and is_equal_approx(float(air.get_shader_parameter("receiver_stain_strength")),0.8), "unset ground uniforms submit actual source defaults to the air shader")
	source.set_shader_parameter("warp_cells",0.2)
	atmosphere.call("refresh_environment",true)
	_check(is_equal_approx(float(air.get_shader_parameter("receiver_warp_cells")),0.2), "explicit receiver uniform overrides remain owned by the ground material")
	source.set_shader_parameter("warp_cells",null)
	atmosphere.call("refresh_environment",true)
	_check(is_equal_approx(float(air.get_shader_parameter("receiver_warp_cells")),0.62), "clearing a source override restores the actual shader default instead of retaining the old value")
	var previous_kit := ChunkBlockVisualCatalog.three_quarter_walls
	ChunkBlockVisualCatalog.three_quarter_walls = true
	var kit := Node2D.new()
	add_child(kit)
	var roof := _roof(kit)
	var material := (roof.get_node("RoofPoly") as Polygon2D).material as ShaderMaterial
	for key: String in ["lit_slope","shade_slope","ridge_light"]:
		material.set_shader_parameter(key,null)
	_check(material.get_shader_parameter("lit_slope") == null, "default roof regression retains a genuinely unset source uniform")
	atmosphere.call("apply_theme",&"underpass_veins",&"procedural",false)
	atmosphere.call("refresh_environment",true)
	_check(material.get_shader_parameter("lit_slope") == null and material.get_shader_parameter("shade_slope") == null and material.get_shader_parameter("ridge_light") == null, "an overcast theme leaves unset actual roof uniforms at their source defaults")
	atmosphere.call("apply_theme",&"service_courtyards",&"procedural",false)
	_check(material.get_shader_parameter("lit_slope") == null and material.get_shader_parameter("shade_slope") == null and material.get_shader_parameter("ridge_light") == null, "clear daylight keeps the raw unset roof baseline exactly")
	atmosphere.call("apply_theme",&"underpass_veins",&"procedural",false)
	atmosphere.call("apply_theme",&"service_courtyards",&"institution",false)
	_check(material.get_shader_parameter("lit_slope") == null and material.get_shader_parameter("shade_slope") == null and material.get_shader_parameter("ridge_light") == null, "authored-space reset keeps raw unset roof uniform state exactly")
	kit.queue_free()
	ground.queue_free()
	await get_tree().process_frame
	ChunkBlockVisualCatalog.three_quarter_walls = previous_kit


func _check_environment_planes(atmosphere: Node2D) -> void:
	var previous_kit := ChunkBlockVisualCatalog.three_quarter_walls
	ChunkBlockVisualCatalog.three_quarter_walls = true
	var kit := Node2D.new()
	add_child(kit)
	var roof := _roof(kit)
	var poly := roof.get_node("RoofPoly") as Polygon2D
	var material := poly.material as ShaderMaterial
	var points := poly.polygon.duplicate()
	poly.color.a = 0.0 # New partitioned roofs keep this host visibility owner.
	poly.modulate.a = 0.4
	var attached := Polygon2D.new()
	attached.set_meta(&"city_roof_partition",&"attached")
	attached.polygon = points
	attached.material = material.duplicate() as ShaderMaterial
	poly.add_child(attached)
	var attached_material := attached.material as ShaderMaterial
	var shadow := Polygon2D.new()
	shadow.set_meta(&"city_sun_shadow",true)
	shadow.color = Color(0.02,0.03,0.04,0.3)
	shadow.modulate.a = 0.4
	kit.add_child(shadow)
	var control := Polygon2D.new()
	control.material = material.duplicate() as ShaderMaterial
	add_child(control)
	var control_material := control.material as ShaderMaterial
	var other_world := SubViewport.new()
	other_world.world_2d = World2D.new()
	add_child(other_world)
	var remote := _roof(other_world)
	var remote_material := (remote.get_node("RoofPoly") as Polygon2D).material as ShaderMaterial
	var layer := CanvasLayer.new()
	add_child(layer)
	var separate := _roof(layer)
	var separate_material := (separate.get_node("RoofPoly") as Polygon2D).material as ShaderMaterial
	atmosphere.call("apply_theme",&"underpass_veins",&"procedural",false)
	atmosphere.call("refresh_environment",true)
	var overcast_shade := DEPTH.sun_shade()
	var expected: Color = PROFILES.resolve(&"underpass_veins").sun_shade
	_check(overcast_shade.is_equal_approx(expected), "the selected theme's sun shade reaches the shared cast material")
	_check(is_equal_approx(float(material.get_shader_parameter("lit_slope")),1.16) and is_equal_approx(float(material.get_shader_parameter("shade_slope")),0.66), "overcast theme light never flattens actual roof-plane contrast")
	_check(is_equal_approx(float(attached_material.get_shader_parameter("ridge_light")),0.35), "attached plane material keeps its own ridge light under every theme")
	_check(is_equal_approx(shadow.color.a,0.3) and is_equal_approx(shadow.modulate.a,0.4), "theme light leaves each cast's own strength and cutaway modulation untouched")
	_check(poly.polygon == points and is_zero_approx(poly.color.a) and is_equal_approx(poly.modulate.a,0.4), "lighting preserves partition host draw alpha, geometry and roof coverage owner")
	_check(is_equal_approx(float(control_material.get_shader_parameter("shade_slope")),0.66), "ordinary actor/item/unowned materials receive no plane multiplier")
	_check(is_equal_approx(float(remote_material.get_shader_parameter("shade_slope")),0.66) and is_equal_approx(float(separate_material.get_shader_parameter("shade_slope")),0.66), "actual roof materials on another world/canvas retain their own lighting")
	atmosphere.call("apply_theme",&"service_courtyards",&"procedural",false)
	atmosphere.call("refresh_environment",true)
	var clear_shade := DEPTH.sun_shade()
	_check(clear_shade.v < overcast_shade.v and clear_shade.is_equal_approx(DEPTH.SUN_SHADE), "clear daylight casts a deeper shade than sheltered overcast air")
	_check(is_equal_approx(float(material.get_shader_parameter("shade_slope")),0.66) and is_equal_approx(float(attached_material.get_shader_parameter("ridge_light")),0.35) and is_equal_approx(shadow.color.a,0.3), "clear daylight leaves per-instance roof/shadow factors exact")
	atmosphere.call("apply_theme",&"underpass_veins",&"procedural",false)
	atmosphere.call("refresh_environment",true)
	atmosphere.call("apply_theme",&"canal_services",&"institution",false)
	atmosphere.call("refresh_environment",true)
	_check(is_equal_approx(float(material.get_shader_parameter("lit_slope")),1.16) and is_equal_approx(float(material.get_shader_parameter("shade_slope")),0.66) and is_equal_approx(shadow.color.a,0.3), "authored-space bypass keeps exact baseline environment materials")
	_check(DEPTH.sun_shade().is_equal_approx(DEPTH.SUN_SHADE), "authored-space bypass restores the neutral daylight shade")
	atmosphere.call("apply_theme",&"underpass_veins",&"procedural",false)
	atmosphere.call("refresh_environment",true)
	poly.remove_child(attached)
	atmosphere.call("refresh_environment",true)
	_check(is_equal_approx(float(attached_material.get_shader_parameter("ridge_light")),0.35), "a detached plane keeps its baseline instead of another environment's light")
	attached.free()
	kit.queue_free()
	control.queue_free()
	other_world.queue_free()
	layer.queue_free()
	await get_tree().process_frame
	ChunkBlockVisualCatalog.three_quarter_walls = previous_kit


func _check_rendered_receivers() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(384,128)
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var world := Node2D.new()
	view.add_child(world)
	var ground := _ground(world)
	var camera := Camera2D.new()
	camera.position = Vector2(128,32)
	world.add_child(camera)
	camera.make_current()
	camera.force_update_scroll()
	var atmosphere := ATMOSPHERE.new() as Node2D
	world.add_child(atmosphere)
	atmosphere.set("weather_frozen",true)
	atmosphere.call("apply_theme",&"canal_services",&"procedural",false)
	atmosphere.call("refresh_environment",true)
	atmosphere.call("_process",0.0)
	await RenderingServer.frame_post_draw
	var damp := view.get_texture().get_image()
	var air := atmosphere.call("get_mist_material") as ShaderMaterial
	air.set_shader_parameter("mist_opacity",0.0)
	await RenderingServer.frame_post_draw
	var dry := view.get_texture().get_image()
	var deltas: Array[float] = []
	for x: int in [32,96,160,224]:
		var screen := Vector2i(view.get_canvas_transform()*Vector2(x,32))
		var a := damp.get_pixelv(screen)
		var b := dry.get_pixelv(screen)
		deltas.append(maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
	_check(deltas[0] < 0.002, "native canal air leaves actual outdoor dry-earth1 untouched")
	_check(deltas[1] > 0.002 and deltas[2] > 0.002, "native canal air reaches actual wet5 and moss12 ground receivers")
	# A stain is noise-cut in the actual ground shader; its cell centre can be
	# perfectly clean. Compare stain-enabled/disabled AIR on the same rendered
	# ground, then search the real patch, excluding neighbouring material edges.
	# A drifting moss/wet winner cannot pass this isolated stain contribution.
	air.set_shader_parameter("mist_opacity",0.038)
	air.set_shader_parameter("receiver_damp_stain",false)
	await RenderingServer.frame_post_draw
	var no_stain_air := view.get_texture().get_image()
	var stain_max := 0.0
	var stain_at := Vector2i(-1,-1)
	var stain_samples := 0
	for y: int in range(4,61,4):
		for x: int in range(196,253,4):
			var world_point := Vector2i(x,y)
			var screen := Vector2i(view.get_canvas_transform()*Vector2(world_point))
			var a := damp.get_pixelv(screen)
			var b := no_stain_air.get_pixelv(screen)
			var delta := maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
			stain_samples += 1
			if delta > stain_max:
				stain_max = delta
				stain_at = world_point
	print("NativeReceiverDeltas dry/wet/moss/stain-centre=%s; isolated-stain-max=%.6f at=%s samples=%d" % [str(deltas),stain_max,str(stain_at),stain_samples])
	_check(stain_max > 0.001, "native canal air reaches an actual visible mud-stain patch without replacing its dry-earth material")
	_check(ground.material_at(Vector2i(3,0)) == 1, "rendered stained receiver keeps semantic dry ownership")
	view.queue_free()
	await get_tree().process_frame


func _check_rendered_roof() -> void:
	var previous_kit := ChunkBlockVisualCatalog.three_quarter_walls
	ChunkBlockVisualCatalog.three_quarter_walls = true
	var view := SubViewport.new()
	view.size = Vector2i(320,240)
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var world := Node2D.new()
	view.add_child(world)
	var ground := ColorRect.new()
	ground.position = Vector2(-512,-512)
	ground.size = Vector2(1024,1024)
	ground.color = Color(0.3,0.3,0.3)
	ground.z_index = -100
	world.add_child(ground)
	var kit := Node2D.new()
	world.add_child(kit)
	var roof := _roof(kit)
	var poly := roof.get_node("RoofPoly") as Polygon2D
	var image := Image.create(2,2,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.5,0.5,0.5))
	poly.texture = ImageTexture.create_from_image(image)
	(poly.material as ShaderMaterial).set_shader_parameter("material_contrast",1.0)
	var shadow := Polygon2D.new()
	shadow.set_meta(&"city_sun_shadow",true)
	shadow.polygon = PackedVector2Array([Vector2(-120,64),Vector2(-75,64),Vector2(-75,78),Vector2(-120,78)])
	shadow.material = DEPTH.SUN_SHADOW_MATERIAL
	shadow.z_index = -7
	kit.add_child(shadow)
	var camera := Camera2D.new()
	camera.position = Vector2(0,-32)
	world.add_child(camera)
	camera.make_current()
	camera.force_update_scroll()
	var atmosphere := ATMOSPHERE.new() as Node2D
	world.add_child(atmosphere)
	atmosphere.set("weather_frozen",true)
	# Isolate the actual roof/sun receiver from the separate daylight overlay;
	# a changed full-screen grade cannot pass this rendered plane assertion.
	(atmosphere.get_node("Daylight") as ColorRect).visible = false
	atmosphere.call("apply_theme",&"service_courtyards",&"procedural",false)
	atmosphere.call("refresh_environment",true)
	atmosphere.call("_process",0.0)
	await RenderingServer.frame_post_draw
	var clear := view.get_texture().get_image()
	var lit_at := Vector2i(view.get_canvas_transform()*poly.to_global(Vector2(0,-30)))
	var shade_at := Vector2i(view.get_canvas_transform()*poly.to_global(Vector2(0,30)))
	var shadow_at := Vector2i(view.get_canvas_transform()*Vector2(-96,70))
	atmosphere.call("apply_theme",&"underpass_veins",&"procedural",false)
	atmosphere.call("refresh_environment",true)
	atmosphere.call("_process",0.0)
	await RenderingServer.frame_post_draw
	var overcast := view.get_texture().get_image()
	var clear_contrast := clear.get_pixelv(lit_at).r-clear.get_pixelv(shade_at).r
	var overcast_contrast := overcast.get_pixelv(lit_at).r-overcast.get_pixelv(shade_at).r
	_check(overcast_contrast > 0.05 and absf(clear_contrast-overcast_contrast) < 0.01, "native overcast keeps the actual roof-plane hierarchy instead of flattening it")
	_check(overcast.get_pixelv(shadow_at).r > clear.get_pixelv(shadow_at).r+0.008, "native overcast lightens the shared sun shade without a global grade")
	var ground_value := 0.3
	_check(absf(clear.get_pixelv(shadow_at).r-ground_value*DEPTH.SUN_SHADE.r) < 0.02, "native clear-daylight cast multiplies the ground by the shared shade ratio")
	view.queue_free()
	await get_tree().process_frame
	ChunkBlockVisualCatalog.three_quarter_walls = previous_kit


func _finish() -> void:
	print("ThemeAtmosphereReceiversTest: %d passed, %d failed" % [_passes,_failures])
	get_tree().quit(1 if _failures > 0 else 0)
