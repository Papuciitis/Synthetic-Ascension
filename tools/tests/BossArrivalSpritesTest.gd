extends Node

const PATH := "res://scenes/world/bosses/BossArrivalSprites.gd"
const Scope := preload("res://scenes/world/bosses/BossAttackScope.gd")
var _passes := 0
var _failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", label)
	else:
		_failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://boss_arrival_test_%d/" % Time.get_ticks_usec()
	Global.debug_disable_autosave = true
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	_check(ResourceLoader.exists(PATH), "announced arrivals have a production raster cue component")
	if ResourceLoader.exists(PATH):
		await _test_cues()
	print("BossArrivalSpritesTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures else 0)

func _test_cues() -> void:
	var script := load(PATH) as Script
	var world := Node2D.new()
	world.position = Vector2(310, -240)
	get_tree().root.add_child(world)
	var source := Node2D.new()
	world.add_child(source)
	var scope := Scope.new()
	source.add_child(scope)
	scope.setup(source)
	var previous_flash: Variant = SettingsManager.get_value(&"accessibility", &"combat_flash", &"full")
	var previous_motion: Variant = SettingsManager.get_value(&"accessibility", &"reduced_motion", false)
	var textures: Array[String] = []
	for kind: StringName in [&"blink", &"summon"]:
		var cue := script.new() as Node2D
		cue.call("setup", Vector2(1700, 950), 62.0, 0.8, kind)
		Scope.bind(cue, source)
		world.add_child(cue)
		cue.set_process(false)
		_check(cue.global_position.is_equal_approx(Vector2(1700, 950)), "%s cue preserves committed world position in translated scene" % kind)
		var sprite := cue.get_node_or_null("Arrival") as Sprite2D
		_check(sprite != null and sprite.texture != null and sprite.visible, "%s arrival is an actual visible raster sprite" % kind)
		if sprite != null and sprite.texture != null:
			textures.append(sprite.texture.resource_path)
			var expected: String = "blink_arrival_v1.png" if kind == &"blink" else "runner_arrival_v1.png"
			_check(sprite.texture.resource_path.ends_with(expected), "%s has its own arrival artwork" % kind)
			var first_scale := sprite.scale
			get_tree().paused = true
			cue.call("_physics_process", 1.0)
			_check(not cue.is_queued_for_deletion(), "%s lifetime cannot expire while paused" % kind)
			get_tree().paused = false
			SettingsManager.set_value(&"accessibility", &"combat_flash", &"off", false)
			SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
			cue.call("set_progress", 0.7)
			_check(sprite.visible and sprite.modulate.a >= 0.4, "%s essential arrival survives flash Off" % kind)
			_check(sprite.scale.is_equal_approx(first_scale), "%s progress cannot shrink or move the committed footprint" % kind)
		cue.call("_physics_process", 0.81)
		_check(cue.is_queued_for_deletion(), "%s cue has finite pause-aware lifetime" % kind)
	_check(textures.size() == 2 and textures[0] != textures[1], "blink and Runner arrival do not borrow the same icon")
	var canceled := script.new() as Node2D
	canceled.call("setup", Vector2(1700, 950), 62.0, 10.0, &"blink")
	Scope.bind(canceled, source)
	world.add_child(canceled)
	scope.cancel()
	_check(canceled.is_queued_for_deletion() and not canceled.visible, "source cancellation immediately hides and removes pending arrival")
	SettingsManager.set_value(&"accessibility", &"combat_flash", previous_flash, false)
	SettingsManager.set_value(&"accessibility", &"reduced_motion", previous_motion, false)
	await _test_physics_clock(script, world)
	world.queue_free()
	await get_tree().process_frame

func _test_physics_clock(script: Script, world: Node2D) -> void:
	var old_fps := Engine.max_fps
	var old_steps := Engine.max_physics_steps_per_frame
	Engine.max_fps = 5
	Engine.max_physics_steps_per_frame = 1
	var cue := script.new() as Node2D
	cue.call("setup", Vector2(1700, 950), 62.0, 0.12, &"blink")
	world.add_child(cue)
	var start_tick := Engine.get_physics_frames()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var physics_elapsed := float(Engine.get_physics_frames() - start_tick) / float(Engine.physics_ticks_per_second)
	_check(physics_elapsed < 0.12 and is_instance_valid(cue) and not cue.is_queued_for_deletion(), "low FPS cannot expire arrival before its gameplay physics duration")
	Engine.max_fps = old_fps
	Engine.max_physics_steps_per_frame = old_steps
	if is_instance_valid(cue):
		cue.queue_free()
	# Pin the component's callback contract independently of engine-specific
	# frame-delta clamping in the natural low-FPS control above.
	var callback_cue := script.new() as Node2D
	callback_cue.call("setup", Vector2(1700, 950), 62.0, 0.12, &"blink")
	world.add_child(callback_cue)
	callback_cue.call("_process", 0.4)
	_check(not callback_cue.is_queued_for_deletion(), "render-only callback cannot spend an arrival's gameplay fuse")
	callback_cue.queue_free()
	var physics_cue := script.new() as Node2D
	physics_cue.call("setup", Vector2(1700, 950), 62.0, 0.12, &"blink")
	world.add_child(physics_cue)
	physics_cue.call("_physics_process", 0.13)
	_check(physics_cue.is_queued_for_deletion(), "accepted gameplay physics duration releases the finite arrival cue")
	physics_cue.queue_free()
