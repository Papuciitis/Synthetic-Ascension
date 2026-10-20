extends "res://tools/dev/CityBlockPlayablePreview.gd"
## Actual Game capture using the existing seeded home/ground/traversal fixture.
## --still-only, --entry-only and --ground-context retain their existing meaning.
## Each still is a stationary paired daylight ablation, qualified in its report.
## Optional --atmosphere-pan proves world anchoring; --weather-phase=120 sets
## presentation phase only. --atmosphere-motion-seconds=1 captures low-rate
## weather-only motion while the same actual actors remain paused.

const LEGACY_SHADER := preload("res://tools/dev/theme_atmosphere_legacy.gdshader")
var _weather_phase := 120.0
var _atmosphere_pan := false
var _weather_motion_seconds := 0.0
var _pair_capture := false
var _atmosphere_plates: Array[Dictionary] = []


func _enter_tree() -> void:
	super._enter_tree()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--weather-phase="):
			_weather_phase = maxf(0.0,arg.trim_prefix("--weather-phase=").to_float())
		if arg == "--atmosphere-pan":
			_atmosphere_pan = true
		if arg.begins_with("--atmosphere-motion-seconds="):
			_weather_motion_seconds = clampf(arg.trim_prefix("--atmosphere-motion-seconds=").to_float(),0.0,3.0)


func _process(delta: float) -> void:
	if not _pair_capture:
		super._process(delta)


func _physics_process(delta: float) -> void:
	if not _pair_capture:
		super._physics_process(delta)


func _still(plate_name: String) -> void:
	await _wait_for_temporary_tips()
	# Real status callouts live 0.9s. Let staging callouts expire naturally;
	# live combat can still produce legitimate new callouts and remains stated.
	await get_tree().create_timer(1.05).timeout
	var atmosphere := _chunks.get_node_or_null("WorldAtmosphere") as WorldAtmosphere
	if atmosphere == null:
		_fail("Actual Game did not create its native WorldAtmosphere")
		return
	var profile := atmosphere.get_profile()
	if StringName(profile.get("id",&"")) != _chunks.district_family:
		_fail("Applied atmosphere does not match the actual selected family")
		return
	var prior_pause := get_tree().paused
	var prior_recording := _recording
	var prior_frozen := atmosphere.weather_frozen
	var prior_phase := atmosphere.weather_time
	var camera_position := _camera.global_position
	var rng_before := Global._rng.state
	var writes_before := SaveManager.debug_save_writes
	_pair_capture = true
	_recording = false
	get_tree().paused = true
	atmosphere.weather_frozen = true
	atmosphere.weather_time = _weather_phase
	# Reapply at the requested frozen phase so Reduced Motion keeps that same
	# phase in the actual shader, rather than silently showing its old phase.
	atmosphere.apply_theme(_chunks.district_family,&"procedural",_reduced_motion)
	atmosphere._process(0.0)
	await super._still(plate_name+"-profile")
	var initial_pixels := get_viewport().get_texture().get_image()
	var first_screen := _image_point(initial_pixels,_camera.get_screen_center_position())
	# Select the centre of an actual rendered texel, then invert the captured
	# canvas transform. A world point on a texel boundary can floor into the
	# adjacent row after floating-point cancellation during camera movement.
	var first_rect := get_viewport().get_visible_rect()
	var first_pixel_center := Vector2(first_screen)+Vector2(0.5,0.5)
	var first_logical := first_rect.position+first_pixel_center*first_rect.size/Vector2(initial_pixels.get_size())
	var world_probe := get_viewport().get_canvas_transform().affine_inverse()*first_logical
	var first_fractional := _image_position(initial_pixels,world_probe)
	var record := {"plate":plate_name,"profile":atmosphere.diagnostics(),
		"actual_theme":String(_chunks.district_family),"seed":_city_world_seed,"segment":_city_segment,
		"camera_world":[camera_position.x,camera_position.y],"player_world":[_player.global_position.x,_player.global_position.y],
		"image_size_px":initial_pixels.get_size(),"logical_viewport_size":get_viewport().get_visible_rect().size,
		"roof_alpha":(_roof.get_node("RoofPoly") as Polygon2D).modulate.a if _roof != null else -1.0,
		"roof_inside_count":_roof._inside_count if _roof != null else -1,
		"enemies":EnemyWorld.active_count(),"projectiles":ProjectileManager.active_count(),
		"legacy_ablation":"Same paused actual Game/camera/actors; previous daylight shader only. Current profile roof/shadow factors retained. Former randomized blue flies omitted from both plates.",
		"weather_motion_qualifier":"Only presentation phase advances in optional weather frames; gameplay is paused for this pair. Parent traversal/fight frames remain live.",
		"world_probe":[world_probe.x,world_probe.y],"normal_hud":true,"ambient_spawner":false,"god_mode":true}
	# This reproduces the exact preceding daylight shader on its existing quad.
	# It does not rerun generation, replace scenery or change any actor material.
	var daylight := atmosphere.get_node("Daylight") as ColorRect
	var air := atmosphere.get_node("GroundAir") as ColorRect
	var actual_material := daylight.material
	var actual_air_visibility := air.visible
	var legacy := ShaderMaterial.new()
	legacy.shader = LEGACY_SHADER
	var viewport_size := get_viewport().get_visible_rect().size
	legacy.set_shader_parameter("aspect",viewport_size.x/maxf(1.0,viewport_size.y))
	daylight.material = legacy
	air.visible = false
	await super._still(plate_name+"-legacy-daylight")
	daylight.material = actual_material
	air.visible = actual_air_visibility
	if _atmosphere_pan:
		# 96 world pixels maps to whole output pixels at both1280 and960
		# against this project's1920-wide logical viewport.
		_camera.global_position = camera_position+Vector2(96,0)
		_camera.reset_smoothing()
		_camera.force_update_scroll()
		atmosphere._process(0.0)
		await super._still(plate_name+"-profile-pan")
		var moved := get_viewport().get_texture().get_image()
		var moved_fractional := _image_position(moved,world_probe)
		var moved_screen := Vector2i(moved_fractional.floor())
		var first_cell := first_screen
		var moved_cell := moved_screen
		var image_bounds := Rect2i(Vector2i.ZERO,moved.get_size())
		if image_bounds.has_point(first_cell) and image_bounds.has_point(moved_cell):
			var a := initial_pixels.get_pixelv(first_cell)
			var b := moved.get_pixelv(moved_cell)
			var delta := maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
			var first_residual := first_fractional-(Vector2(first_cell)+Vector2(0.5,0.5))
			var moved_residual := moved_fractional-(Vector2(moved_cell)+Vector2(0.5,0.5))
			record["world_anchor_probe"] = {"first_screen":first_cell,"moved_screen":moved_cell,"delta":delta,"tolerance":0.012,
				"selection":"initial rendered texel centre through inverse canvas transform",
				"first_fractional":[first_fractional.x,first_fractional.y],"moved_fractional":[moved_fractional.x,moved_fractional.y],
				"first_centre_residual":[first_residual.x,first_residual.y],"moved_centre_residual":[moved_residual.x,moved_residual.y]}
			if delta > 0.012: _fail("Actual Game fixed-world sample changed during the fixed-phase camera pan")
		else:
			_fail("Actual Game world-anchor probe left its rendered image")
		_camera.global_position = camera_position
		_camera.reset_smoothing()
		_camera.force_update_scroll()
		atmosphere._process(0.0)
	if _weather_motion_seconds > 0.0:
		var count := ceili(_weather_motion_seconds*8.0)
		for index: int in range(count+1):
			atmosphere.weather_time = _weather_phase+float(index)/8.0 if not _reduced_motion else _weather_phase
			atmosphere._process(0.0)
			await super._still("weather-%s/frame-%03d" % [plate_name,index])
		record["weather_frames"] = count+1
		record["weather_frame_step_seconds"] = 0.125
	atmosphere.weather_time = prior_phase
	atmosphere.weather_frozen = prior_frozen
	atmosphere.apply_theme(_chunks.district_family,&"procedural",_reduced_motion)
	atmosphere._process(0.0)
	record["rng_unchanged_during_pair"] = Global._rng.state == rng_before
	record["save_writes_during_pair"] = SaveManager.debug_save_writes-writes_before
	if not bool(record.rng_unchanged_during_pair): _fail("Atmosphere-only comparison consumed gameplay RNG")
	if int(record.save_writes_during_pair) != 0: _fail("Atmosphere-only comparison wrote a profile")
	_atmosphere_plates.append(record)
	var report := FileAccess.open(_out.path_join("atmosphere-info.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"scene":"res://scenes/game.tscn","tool":"res://tools/dev/ThemeAtmospherePreview.tscn",
		"args":OS.get_cmdline_user_args(),"plates":_atmosphere_plates,"failures":_failures,
		"limits":"Controlled native samples only; no acceptance inferred for all fourteen themes, continuous human play, or performance/balance."},"\t"))
	report.close()
	get_tree().paused = prior_pause
	_recording = prior_recording
	_pair_capture = false


func _save_image(pixels: Image, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	super._save_image(pixels,path)


func _image_point(pixels: Image, world_point: Vector2) -> Vector2i:
	return Vector2i(_image_position(pixels,world_point).floor())


func _image_position(pixels: Image, world_point: Vector2) -> Vector2:
	# The project's logical1920x1080 canvas is rendered to960/1280 images.
	# Camera coordinates are logical viewport pixels, not texture pixels.
	var logical := get_viewport().get_canvas_transform()*world_point
	var rect := get_viewport().get_visible_rect()
	return (logical-rect.position)*Vector2(pixels.get_size())/rect.size
