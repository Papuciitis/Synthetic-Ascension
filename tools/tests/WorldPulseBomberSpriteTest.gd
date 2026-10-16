extends Node

# Regression targets: coarse shared kit art, shrinking blast warnings,
# unobservable fuse progress, pooled state leakage and owner-bound bursts.
const PULSE := preload("res://assets/vfx/world/sets/conduit/VFX_PulseRing.tscn")
const BOMBER := preload("res://scenes/world/enemies/EnemyBomber.tscn")
const PULSE_ART := "res://assets/textures/vfx/encounters/pulse_ripple_v1.png"
const PERIMETER_ART := "res://assets/textures/vfx/encounters/bomber_perimeter_v1.png"
const BLAST_ART := "res://assets/textures/vfx/encounters/bomber_blast_v1.png"

var _passes := 0
var _failures := 0
var _player: Node2D
var _content_radius: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _sprite_for(node: Node, path: String) -> Sprite2D:
	if node is Sprite2D and node.texture != null and node.texture.resource_path == path:
		return node as Sprite2D
	var largest: Sprite2D
	for child in node.get_children():
		var found := _sprite_for(child, path)
		if found != null and (largest == null or found.global_scale.length_squared() > largest.global_scale.length_squared()):
			largest = found
	return largest


# Derive coverage from actual imported pixels, not production calibration.
func _painted_radius(sprite: Sprite2D) -> float:
	var key := sprite.texture.resource_path
	if not _content_radius.has(key):
		var pixels := sprite.texture.get_image()
		var center := Vector2(pixels.get_size()) * 0.5
		var furthest := 0.0
		for y in range(pixels.get_height()):
			for x in range(pixels.get_width()):
				if pixels.get_pixel(x, y).a > 0.2:
					furthest = maxf(furthest, center.distance_to(Vector2(x + 0.5, y + 0.5)))
		_content_radius[key] = furthest
	return float(_content_radius[key]) * absf(sprite.global_scale.x)


func _has_native_effect(node: Node) -> bool:
	if node is Line2D or node is GPUParticles2D or node is CPUParticles2D:
		return true
	for child in node.get_children():
		if _has_native_effect(child):
			return true
	return false


func _run() -> void:
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://world_pulse_bomber_%d/" % Time.get_ticks_usec()
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	Global.debug_disable_autosave = true
	var previous_motion: Variant = SettingsManager.get_value(&"accessibility", &"reduced_motion", false)
	var previous_flash: Variant = SettingsManager.get_value(&"accessibility", &"combat_flash", &"full")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	SettingsManager.set_value(&"accessibility", &"combat_flash", &"full", false)
	_player = Node2D.new()
	_player.add_to_group(&"player")
	_player.position = Vector2(-600, -400)
	add_child(_player)
	await _test_pulse()
	await _test_bomber()
	get_tree().paused = false
	SettingsManager.set_value(&"accessibility", &"reduced_motion", previous_motion, false)
	SettingsManager.set_value(&"accessibility", &"combat_flash", previous_flash, false)
	_player.queue_free()
	await get_tree().process_frame
	print("WorldPulseBomberSpriteTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_pulse() -> void:
	var pulse := PooledVfx.obtain(PULSE, self) as PulseRing
	pulse.set_process(false)
	pulse.setup(Vector2(140, 90), 120.0)
	var ripple := _sprite_for(pulse, PULSE_ART)
	_check(ripple != null and ripple.visible, "Pulse displays its dedicated raster ripple artwork")
	_check(not _has_native_effect(pulse), "Pulse has no native line or particle effects")
	if ripple != null:
		_check(ripple.material == null and pulse.material == null, "Pulse art uses normal blending")
		var initial_radius := _painted_radius(ripple)
		pulse.call("_process", 0.10)
		_check(_painted_radius(ripple) > initial_radius + 30.0, "normal Pulse visibly expands during its existing lifetime")
		var before := float(pulse.get("_t"))
		var before_scale := ripple.scale
		get_tree().paused = true
		pulse.call("_process", 0.15)
		_check(is_equal_approx(float(pulse.get("_t")), before) and ripple.scale == before_scale, "pausing preserves Pulse time and visible radius")
		get_tree().paused = false
		SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
		pulse.call("_process", 0.0)
		_check(absf(_painted_radius(ripple) - 120.0) <= 3.0, "live Reduced Motion retains a static full-radius ripple")
		var fixed_scale := ripple.scale
		pulse.call("_process", 0.03)
		_check(ripple.scale == fixed_scale, "Reduced Motion keeps the ripple radius still")
		SettingsManager.set_value(&"accessibility", &"combat_flash", &"off", false)
		pulse.call("_process", 0.0)
		_check(ripple.modulate.a <= 0.001, "combat flash Off suppresses the decorative Pulse flash")
	pulse.call("_process", 1.0)
	_check(bool(pulse.get_meta("__in_pool", false)), "Pulse returns to its pool after the existing finite lifetime")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	SettingsManager.set_value(&"accessibility", &"combat_flash", &"full", false)
	var reused := PooledVfx.obtain(PULSE, self) as PulseRing
	reused.set_process(false)
	reused.setup(Vector2(-20, 15), 40.0)
	var fresh_ripple := _sprite_for(reused, PULSE_ART)
	_check(is_zero_approx(float(reused.get("_t"))) and reused.global_position == Vector2(-20, 15), "pooled Pulse resets its age and world origin")
	_check(fresh_ripple != null and fresh_ripple.modulate.a > 0.0 and _painted_radius(fresh_ripple) < 15.0, "pooled Pulse forgets the previous opacity and radius")
	reused.call("_process", 1.0)
	await get_tree().process_frame


func _test_bomber() -> void:
	var bomber := BOMBER.instantiate() as EnemyActor
	bomber.position = Vector2(240, 180)
	bomber.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(bomber)
	bomber.player = _player
	var cue: VFX_BomberHazardRing
	for child in bomber.get_children():
		if child is VFX_BomberHazardRing:
			cue = child
	_check(cue != null, "production Bomber constructs its persistent warning")
	if cue == null:
		bomber.queue_free()
		await get_tree().process_frame
		return
	cue.call("_process", 0.0)
	var perimeter := _sprite_for(cue, PERIMETER_ART)
	_check(perimeter != null and perimeter.visible, "Bomber displays a dedicated explosive perimeter sprite")
	_check(not _has_native_effect(cue), "Bomber warning has no native line or particle effects")
	if perimeter != null:
		_check(absf(_painted_radius(perimeter) - 105.0) <= 3.0, "idle Bomber warning depicts its actual 105px blast radius")
		cue.call("_process", 0.13)
		_check(absf(_painted_radius(perimeter) - 105.0) <= 3.0, "idle breathing does not shrink the blast boundary")
		var module := bomber.get("_bomber") as EnemyBomber
		module.set("_fuse_left", 0.35)
		cue.call("_process", 0.0)
		var first_alpha := perimeter.modulate.a
		module.set("_fuse_left", 0.07)
		cue.call("_process", 0.15)
		_check(perimeter.modulate.a > first_alpha + 0.1, "visible Bomber fuse builds toward detonation instead of alternating white flashes")
		SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
		SettingsManager.set_value(&"accessibility", &"combat_flash", &"off", false)
		cue.call("_process", 0.0)
		var fixed_rotation := perimeter.rotation
		var fixed_scale := perimeter.scale
		cue.call("_process", 0.08)
		_check(perimeter.visible and perimeter.modulate.a >= 0.25, "flash Off keeps the necessary Bomber danger boundary readable")
		_check(perimeter.rotation == fixed_rotation and perimeter.scale == fixed_scale, "live Reduced Motion keeps Bomber's boundary still")
		var before := float(cue.get("_t"))
		get_tree().paused = true
		cue.call("_process", 0.2)
		_check(is_equal_approx(float(cue.get("_t")), before), "pause preserves Bomber warning time")
		get_tree().paused = false
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	SettingsManager.set_value(&"accessibility", &"combat_flash", &"full", false)
	var at := bomber.global_position
	(bomber.get("_bomber") as EnemyBomber).explode_now()
	var blast_root := get_node_or_null("BomberBlast")
	var blast_sprite := _sprite_for(blast_root, BLAST_ART) if blast_root != null else null
	_check(blast_sprite != null, "Bomber detonation creates a real raster blast")
	if blast_sprite != null:
		var burst := blast_sprite.get_parent() as Node2D
		burst.set_process(false)
		_check(burst.global_position.distance_to(at) < 0.01, "blast stays at the actual detonation world origin")
		await get_tree().process_frame
		_check(is_instance_valid(burst) and not burst.is_queued_for_deletion(), "blast survives deletion of its Bomber owner")
		var before := float(burst.get("_t"))
		get_tree().paused = true
		burst.call("_process", 0.5)
		_check(is_equal_approx(float(burst.get("_t")), before), "pause preserves the finite blast's remaining lifetime")
		get_tree().paused = false
		burst.call("_process", 1.0)
		_check(burst.is_queued_for_deletion(), "blast cleans itself up after its finite lifetime")
	else:
		await get_tree().process_frame
	await get_tree().process_frame
