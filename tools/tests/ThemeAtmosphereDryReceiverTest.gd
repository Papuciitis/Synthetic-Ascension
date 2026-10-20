extends Node
## A clean dry G0 pixel must stay dry even when stain noise is maximal and a
## real stain exists elsewhere. Controlled black ground makes any false air
## contribution measurable; this is a shader contract fixture, not Game art.

const ATMOSPHERE := preload("res://core/systems/world/atmosphere/WorldAtmosphere.gd")
const GROUND := preload("res://core/systems/world/ground/GroundSplatRenderer.gd")
const DIAGNOSTIC_MIST_OPACITY := 0.06 # The actual shader's allowed ceiling.
var _passes := 0
var _failures := 0


func _enter_tree() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/theme_atmosphere_dry_receiver/"
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
	_check(DisplayServer.get_name() != "headless", "native rendering is required for the dry-receiver regression")
	if DisplayServer.get_name() == "headless":
		_finish()
		return
	var rng_before := Global._rng.state
	var writes_before := SaveManager.debug_save_writes
	var view := SubViewport.new()
	view.size = Vector2i(256,128)
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var world := Node2D.new()
	view.add_child(world)
	var ground := GROUND.new() as GroundSplatRenderer
	ground.configure(64,32)
	world.add_child(ground)
	ground.set_chunk_base(Vector2i.ZERO,1)
	ground.paint_rect(Rect2i(3,0,1,1),5,0.12)
	ground.set_world_tint(Color.BLACK)
	ground.flush()
	var noise := Image.create(2,2,false,Image.FORMAT_RGBA8)
	noise.fill(Color(0.5,0.5,0.5,1.0))
	var source := ground.get_shader_material()
	source.set_shader_parameter("noise_tex",ImageTexture.create_from_image(noise))
	var light := ground.get("_light") as Image
	_check(ground.material_at(Vector2i.ZERO) == 1 and is_zero_approx(light.get_pixel(0,0).g) and light.get_pixel(3,0).g > 0.5, "real receiver data retains clean dry1 G0 beside a genuine mud stain")
	var camera := Camera2D.new()
	camera.position = Vector2(32,32)
	world.add_child(camera)
	camera.make_current()
	camera.force_update_scroll()
	var atmosphere := ATMOSPHERE.new() as Node2D
	world.add_child(atmosphere)
	atmosphere.set("weather_frozen",true)
	atmosphere.call("apply_theme",&"canal_services",&"procedural",false)
	atmosphere.call("refresh_environment",true)
	atmosphere.call("_process",0.0)
	var air := atmosphere.call("get_mist_material") as ShaderMaterial
	_check(air.get_shader_parameter("receiver_damp_stain") == true and air.get_shader_parameter("receiver_noise_tex") == source.get_shader_parameter("noise_tex"), "actual air receives the same high-alpha noise and enabled real-stain source")
	var dry_delta := await _air_delta(view,air,Vector2(32,32))
	print("NativeDryReceiver high-noise/G0 delta=%.6f" % dry_delta)
	_check(dry_delta < 0.00001, "native clean dry G0 ground receives no invented stain air at a noise peak")
	camera.position = Vector2(224,32)
	camera.force_update_scroll()
	atmosphere.call("_process",0.0)
	var stain_delta := await _air_delta(view,air,Vector2(224,32))
	print("NativeDryReceiver real-stain/G0.6 delta=%.6f" % stain_delta)
	_check(stain_delta > 0.002, "native actual stain still receives air under the same noise peak")
	view.queue_free()
	await get_tree().process_frame
	_check(Global._rng.state == rng_before and SaveManager.debug_save_writes == writes_before, "dry-receiver presentation fixture consumes no gameplay RNG or saves")
	_finish()


func _air_delta(view: SubViewport, air: ShaderMaterial, point: Vector2) -> float:
	# Exercise the shader's permitted ceiling so an incorrect tiny G0 term
	# survives8-bit readback. This is not a proposed canal profile change.
	air.set_shader_parameter("mist_opacity",DIAGNOSTIC_MIST_OPACITY)
	await RenderingServer.frame_post_draw
	var damp := view.get_texture().get_image()
	air.set_shader_parameter("mist_opacity",0.0)
	await RenderingServer.frame_post_draw
	var dry := view.get_texture().get_image()
	var maximum := 0.0
	for y: int in range(-16,17,4):
		for x: int in range(-16,17,4):
			var screen := Vector2i(view.get_canvas_transform()*(point+Vector2(x,y)))
			var a := damp.get_pixelv(screen)
			var b := dry.get_pixelv(screen)
			maximum = maxf(maximum,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
	return maximum


func _finish() -> void:
	print("ThemeAtmosphereDryReceiverTest: %d passed, %d failed" % [_passes,_failures])
	get_tree().quit(1 if _failures > 0 else 0)
