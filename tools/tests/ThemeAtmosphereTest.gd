extends Node2D
## A missing profile/binder, a stale damp profile, universal magic, or a motion
## override that advances under Reduced Motion must fail this contract.

const PROFILES_PATH := "res://core/systems/world/atmosphere/ThemeAtmosphereProfiles.gd"
const ATMOSPHERE := preload("res://core/systems/world/atmosphere/WorldAtmosphere.gd")
const BINDER_PATH := "res://core/systems/world/atmosphere/GameAtmosphereBinder.gd"
const INDOOR := preload("res://scenes/world/volumes/IndoorVolume.tscn")
const GROUND := preload("res://core/systems/world/ground/GroundSplatRenderer.gd")
const THEME_IDS: Array[StringName] = [
	&"service_courtyards", &"checkpoint_lanes", &"collapsed_ward", &"civilian_cutthrough",
	&"inner_district_gate", &"industrial_cutthrough", &"ruined_services", &"underpass_veins",
	&"canal_services", &"rail_yard", &"military_staging", &"outer_wall", &"siege_services", &"gate_district",
]

var _passes := 0
var _failures := 0

class SelectedDistrict:
	extends Node2D
	var district_family: StringName = &""


func _enter_tree() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/theme_atmosphere/"
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	PerformanceFlightRecorder.set_enabled(false)
	BalanceRecorder.set_enabled(false)


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	_check(ResourceLoader.exists(PROFILES_PATH), "actual district themes have physical atmosphere profiles")
	if not ResourceLoader.exists(PROFILES_PATH):
		_finish()
		return
	var profiles := load(PROFILES_PATH) as GDScript
	var rng_before: int = Global._rng.state
	var writes_before := SaveManager.debug_save_writes
	for id: StringName in THEME_IDS:
		var profile: Dictionary = profiles.call("resolve", id)
		_check(StringName(profile.get("id", &"")) == id, "selected actual theme retains its own profile: " + String(id))
		var fill: Color = profile.get("ambient_fill", Color.BLACK)
		_check(minf(fill.r,minf(fill.g,fill.b)) >= 0.85, "daylight fill retains readable dark art: " + String(id))
		_check(float(profile.get("cloud_opacity",1.0)) <= 0.18 and float(profile.get("mist_opacity",1.0)) <= 0.06, "cloud and mist contribution stay bounded: " + String(id))
		_check(StringName(profile.get("particle_kind", &"fireflies")) != &"fireflies" and float(profile.get("vignette_strength",1.0)) <= 0.15, "ordinary climate avoids universal magic and heavy vignette: " + String(id))
		# Physical sun per theme: a daylight shade (never night-dark, never
		# erased), bounded cast length/softness/contact; direction is fixed.
		var shade: Color = profile.get("sun_shade", Color.BLACK)
		var shade_luma := shade.r*0.299+shade.g*0.587+shade.b*0.114
		_check(shade_luma >= 0.6 and shade_luma <= 0.88 and shade.b >= shade.r, "theme sun shade stays a cool readable daylight shadow: " + String(id))
		# Until lawns and dirt brighten, no theme casts deeper than clear S2
		# daylight; deeper casts become near-black slabs under dark armour.
		var clear_shade: Color = (profiles.call("resolve", &"service_courtyards") as Dictionary).get("sun_shade", Color.BLACK)
		_check(shade_luma >= clear_shade.r*0.299+clear_shade.g*0.587+clear_shade.b*0.114-0.0005, "theme shade is never deeper than clear S2 daylight: " + String(id))
		_check(float(profile.get("shadow_length",0.0)) >= 0.6 and float(profile.get("shadow_length",9.0)) <= 1.25 and float(profile.get("penumbra_px",99.0)) <= 12.0 and float(profile.get("contact_strength",0.0)) >= 0.8, "theme cast length, softness and contact stay bounded: " + String(id))
	var clear: Dictionary = profiles.call("resolve", &"service_courtyards")
	var checkpoint: Dictionary = profiles.call("resolve", &"checkpoint_lanes")
	var canal: Dictionary = profiles.call("resolve", &"canal_services")
	_check(float(checkpoint.cloud_opacity) > float(clear.cloud_opacity), "checkpoint exposure differs from the open courtyard sky")
	_check(float(canal.mist_opacity) > 0.0 and is_zero_approx(float(clear.mist_opacity)), "damp canal atmosphere differs from the dry courtyard")
	var underpass: Dictionary = profiles.call("resolve", &"underpass_veins")
	var outer: Dictionary = profiles.call("resolve", &"outer_wall")
	_check((underpass.sun_shade as Color).v > (clear.sun_shade as Color).v and float(underpass.shadow_length) < float(clear.shadow_length) and float(underpass.penumbra_px) > float(clear.penumbra_px), "sheltered overcast casts lighter, shorter, softer shadows than the open courtyard")
	_check(float(outer.shadow_length) > float(clear.shadow_length) and float(outer.penumbra_px) <= float(clear.penumbra_px), "open outer approaches cast longer, crisper shadows")
	var lights: Dictionary = {}
	for id: StringName in THEME_IDS:
		var light_profile: Dictionary = profiles.call("resolve", id)
		lights[[light_profile.sun_shade, light_profile.shadow_length, light_profile.penumbra_px]] = true
	_check(lights.size() >= 10, "themes express distinct physical light, not one shared grade; distinct=%d" % lights.size())
	var hub: Dictionary = profiles.call("resolve", &"canal_services", &"hub")
	var institution: Dictionary = profiles.call("resolve", &"canal_services", &"institution")
	_check(not bool(hub.get("enabled",true)) and is_zero_approx(float(hub.get("mist_opacity",1.0))), "authored Hub bypasses procedural lighting and damp air")
	_check(is_zero_approx(float(institution.get("mist_opacity",1.0))) and StringName(institution.get("context", &"")) == &"institution", "authored S1 cannot inherit a procedural canal's weather")
	var unknown: Dictionary = profiles.call("resolve", &"unknown_future_theme")
	_check(unknown.get("id") == &"service_courtyards", "unknown procedural context uses the known neutral fallback")
	canal["mist_opacity"] = 0.9
	var fresh: Dictionary = profiles.call("resolve", &"canal_services")
	_check(float(fresh.mist_opacity) < 0.06, "a caller cannot contaminate future profile instances")
	var atmosphere := ATMOSPHERE.new() as Node2D
	add_child(atmosphere)
	_check(atmosphere.has_method("apply_theme"), "the actual world renderer applies the selected profile")
	if atmosphere.has_method("apply_theme"):
		atmosphere.call("apply_theme", &"canal_services", &"procedural", false)
		var material := atmosphere.call("get_shader_material") as ShaderMaterial
		var mist := atmosphere.call("get_mist_material") as ShaderMaterial
		_check(float(mist.get_shader_parameter("mist_opacity")) > 0.0, "canal profile reaches the actual low-air shader")
		_check(is_equal_approx(float(material.get_shader_parameter("cloud_opacity")),float(fresh.cloud_opacity)), "actual daylight material receives the selected sky exposure")
		atmosphere.call("apply_theme", &"service_courtyards", &"procedural", false)
		_check(is_zero_approx(float(mist.get_shader_parameter("mist_opacity"))), "leaving a damp theme clears low air instead of leaking into dry streets")
		atmosphere.call("apply_theme", &"checkpoint_lanes", &"procedural", true)
		var clock_before := float(atmosphere.get("weather_time"))
		atmosphere.call("_process", 1.0)
		_check(is_equal_approx(float(atmosphere.get("weather_time")),clock_before), "Reduced Motion freezes the weather clock")
		_check(material.get_shader_parameter("weather_motion_enabled") == false, "Reduced Motion also disables weather motion in the submitted material")
		atmosphere.call("apply_theme", &"checkpoint_lanes", &"procedural", false)
		atmosphere.call("_process", 1.0)
		_check(float(atmosphere.get("weather_time")) > clock_before, "normal presentation advances only its own weather clock")
		await _check_receivers(atmosphere)
		atmosphere.call("apply_theme", &"canal_services", &"hub", false)
		_check(not atmosphere.visible, "switching to authored Hub context removes the procedural overlay")
		atmosphere.call("apply_theme", &"canal_services", &"institution", false)
		_check(not atmosphere.visible and is_zero_approx(float(mist.get_shader_parameter("mist_opacity"))), "S1 explicitly removes procedural weather after a damp theme")
	atmosphere.queue_free()
	await get_tree().process_frame
	await _check_binder()
	if DisplayServer.get_name() != "headless":
		await _check_rendered_world_space()
	_check(Global._rng.state == rng_before, "presentation profile resolution and switching consume no gameplay RNG")
	_check(SaveManager.debug_save_writes == writes_before, "theme atmosphere performs no profile writes")
	_finish()


func _room(parent: Node, tl: Vector2i = Vector2i(-1,-1), size: Vector2i = Vector2i(2,2), cell: int = 32) -> IndoorVolume:
	var room := INDOOR.instantiate() as IndoorVolume
	room.cell_tl = tl
	room.size_cells = size
	room.cell_size_px = cell
	room.exploration_loot_enabled = false
	room.local_encounter_enabled = false
	room.collision_layer = 0
	room.collision_mask = 0
	parent.add_child(room)
	return room


func _receiver_at(atmosphere: Node2D, point: Vector2) -> float:
	# This is the actual uploaded receiver source, not a proxy climate scalar.
	var image := atmosphere.get("_mask_image") as Image
	var material := atmosphere.call("get_mist_material") as ShaderMaterial
	var texture := material.get_shader_parameter("outdoor_mask") as Texture2D
	if image == null or texture == null or texture.get_size() != Vector2(image.get_size()):
		return -1.0
	var origin: Vector2 = material.get_shader_parameter("mask_origin")
	var extent: Vector2 = material.get_shader_parameter("mask_extent")
	var cell := Vector2i(((point-origin)/extent*Vector2(image.get_size())).floor())
	if cell.x < 0 or cell.y < 0 or cell.x >= image.get_width() or cell.y >= image.get_height():
		return -1.0
	return image.get_pixelv(cell).r


func _check_receivers(atmosphere: Node2D) -> void:
	atmosphere.call("apply_theme", &"canal_services", &"procedural", false)
	atmosphere.call("_process", 0.0)
	_check(is_equal_approx(_receiver_at(atmosphere,Vector2.ZERO),1.0), "a real view without rooms retains its outdoor receiver")
	var room := _room(self)
	room.rotation = 0.25
	room.scale = Vector2(1.4,0.8)
	atmosphere.call("_process", 0.0)
	_check(is_zero_approx(_receiver_at(atmosphere,room.global_position)), "a streamed transformed real room clears the actual air receiver immediately")
	var before: Dictionary = atmosphere.call("diagnostics")
	atmosphere.call("_process", 0.1)
	var after: Dictionary = atmosphere.call("diagnostics")
	_check(int(before.mask_rebuilds) == int(after.mask_rebuilds), "unchanged room/camera state reuses its receiver instead of rebuilding each frame")
	var size: Vector2i = after.mask_size
	_check(size.x <= 127 and size.y <= 127 and size.x > 0 and size.y > 0, "the receiver raster has a bounded view-sized budget")
	var other_world := SubViewport.new()
	other_world.world_2d = World2D.new()
	add_child(other_world)
	var remote := _room(other_world)
	var layer := CanvasLayer.new()
	add_child(layer)
	var other_canvas := _room(layer)
	_check(remote.get_world_2d() != atmosphere.get_world_2d() and other_canvas.get_canvas() != atmosphere.get_canvas(), "isolation fixtures use genuinely different world/canvas identities")
	atmosphere.call("_process", 0.0)
	var isolated: Dictionary = atmosphere.call("diagnostics")
	_check(int(isolated.room_count) == 1, "weather excludes rooms on another World2D or CanvasLayer")
	room.queue_free()
	await get_tree().process_frame
	atmosphere.call("_process", 0.0)
	var removed: Dictionary = atmosphere.call("diagnostics")
	_check(int(removed.room_count) == 0 and is_equal_approx(_receiver_at(atmosphere,Vector2.ZERO),1.0), "streamed room removal restores outdoor air without stale masks")
	other_world.queue_free()
	layer.queue_free()
	await get_tree().process_frame


func _check_binder() -> void:
	_check(ResourceLoader.exists(BINDER_PATH), "Game has a binder for the actual selected family")
	if not ResourceLoader.exists(BINDER_PATH):
		return
	var prior_segment := Global.attempt_segment
	var prior_motion := bool(SettingsManager.get_value(&"accessibility",&"reduced_motion",false))
	Global.attempt_segment = 7
	SettingsManager.set_value(&"accessibility",&"reduced_motion",false,false)
	var game := Node2D.new()
	var chunks := SelectedDistrict.new()
	chunks.name = "ChunkManager"
	game.add_child(chunks)
	var atmosphere := ATMOSPHERE.new() as Node2D
	chunks.add_child(atmosphere)
	var binder := (load(BINDER_PATH) as GDScript).new() as Node
	game.add_child(binder)
	add_child(game)
	binder.call("_process",0.0)
	_check(not atmosphere.visible, "binder waits for actual builder selection rather than applying a guessed S7 theme")
	chunks.district_family = &"canal_services"
	binder.call("_process",0.0)
	var profile: Dictionary = atmosphere.call("get_profile")
	_check(profile.id == &"canal_services", "binder uses the actual selected S7 alternative")
	chunks.district_family = &"rail_yard"
	binder.call("_process",0.0)
	var mist := atmosphere.call("get_mist_material") as ShaderMaterial
	_check(is_zero_approx(float(mist.get_shader_parameter("mist_opacity"))), "actual-family changes fully reset damp weather in the same live component")
	SettingsManager.set_value(&"accessibility",&"reduced_motion",true,false)
	binder.call("_process",0.0)
	var material := atmosphere.call("get_shader_material") as ShaderMaterial
	_check(material.get_shader_parameter("weather_motion_enabled") == false, "live accessibility changes reach the Game binder")
	Global.attempt_segment = 1
	binder.call("_process",0.0)
	_check(not atmosphere.visible, "the same binder hands S1 back to authored institution presentation")
	Global.attempt_segment = prior_segment
	SettingsManager.set_value(&"accessibility",&"reduced_motion",prior_motion,false)
	game.queue_free()
	await get_tree().process_frame


func _check_rendered_world_space() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(192,128)
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var world := Node2D.new()
	view.add_child(world)
	var ground := ColorRect.new()
	ground.position = Vector2(-512,-512)
	ground.size = Vector2(1024,1024)
	ground.color = Color(0.2,0.2,0.2)
	ground.z_index = -100
	world.add_child(ground)
	var camera := Camera2D.new()
	world.add_child(camera)
	camera.make_current()
	var atmosphere := ATMOSPHERE.new() as Node2D
	world.add_child(atmosphere)
	atmosphere.call("apply_theme",&"checkpoint_lanes",&"procedural",false)
	atmosphere.set("weather_frozen",true)
	atmosphere.set("weather_time",121.0)
	camera.force_update_scroll()
	atmosphere.call("_process",0.0)
	await RenderingServer.frame_post_draw
	var first := view.get_texture().get_image()
	camera.position = Vector2(32,0)
	camera.force_update_scroll()
	atmosphere.call("_process",0.0)
	await RenderingServer.frame_post_draw
	var moved := view.get_texture().get_image()
	_check(_color_delta(first.get_pixel(96,64),moved.get_pixel(64,64)) < 0.004, "native sky samples the same world point after camera movement")
	atmosphere.set("weather_time",181.0)
	atmosphere.call("_process",0.0)
	await RenderingServer.frame_post_draw
	var later := view.get_texture().get_image()
	var difference := 0.0
	for y: int in range(16,112,16):
		for x: int in range(16,176,16):
			difference = maxf(difference,_color_delta(moved.get_pixel(x,y),later.get_pixel(x,y)))
	_check(difference > 0.001, "native cloud daylight actually changes with presentation phase")
	var receiver := GROUND.new() as GroundSplatRenderer
	receiver.configure(16,32)
	world.add_child(receiver)
	for coord: Vector2i in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(-1,0),Vector2i.ZERO]:
		receiver.set_chunk_base(coord,5)
	receiver.flush()
	atmosphere.call("apply_theme",&"canal_services",&"procedural",false)
	camera.position = Vector2.ZERO
	camera.force_update_scroll()
	var room := _room(world,Vector2i.ZERO,Vector2i.ONE,16)
	atmosphere.call("_process",0.0)
	await RenderingServer.frame_post_draw
	var damp := view.get_texture().get_image()
	var mist := atmosphere.call("get_mist_material") as ShaderMaterial
	mist.set_shader_parameter("mist_opacity",0.0)
	await RenderingServer.frame_post_draw
	var dry := view.get_texture().get_image()
	_check(_color_delta(damp.get_pixel(104,72),dry.get_pixel(104,72)) < 0.002, "native low air never paints the actual room's cutaway floor")
	_check(_color_delta(damp.get_pixel(176,72),dry.get_pixel(176,72)) > 0.002, "native low air paints eligible outdoor ground using its actual material")
	_check((room.get_node("CollisionShape2D") as CollisionShape2D).shape != null, "native indoor comparison retains its real receiver geometry")
	view.queue_free()
	await get_tree().process_frame


func _color_delta(a: Color, b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))


func _finish() -> void:
	print("ThemeAtmosphereTest passes=%d failures=%d" % [_passes,_failures])
	get_tree().quit(1 if _failures > 0 else 0)
