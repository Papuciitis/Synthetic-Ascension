extends Node2D
## Native raster/shader proof, deliberately a representative isolated form
## rather than an actual Game capture or human motion/readability verdict.
const TANK := preload("res://scenes/world/bosses/BossBulldozer.tscn")
const MAGE := preload("res://scenes/world/bosses/BossArcanist.tscn")
const AFTERMATH := preload("res://scenes/world/bosses/BossDefeatAfterimage.gd")
var passes := 0
var failures := 0
var _out: String

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	AudioServer.set_bus_mute(0, true)
	check(DisplayServer.get_name() != "headless", "defeat material is evaluated by a native renderer")
	if failures:
		get_tree().quit(1)
		return
	_out = OS.get_environment("BOSS_DEFEAT_OUTPUT")
	if _out.is_empty():
		_out = ProjectSettings.globalize_path("user://boss_defeat_render")
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(640, 360)
	get_window().content_scale_size = Vector2i(640, 360)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_factor = 1.0
	RenderingServer.set_default_clear_color(Color("171b1e"))
	for packed: PackedScene in [TANK, MAGE]:
		var actor := packed.instantiate() as EnemyActor
		actor.position = Vector2(320, 180)
		add_child(actor)
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		var source := actor.get_node("Sprite2D") as Sprite2D
		for reduced: bool in [false, true]:
			SettingsManager.set_value(&"accessibility", &"reduced_motion", reduced, false)
			var ghost := AFTERMATH.new()
			ghost.setup(source, packed == TANK)
			add_child(ghost)
			ghost.set_process(false)
			source.hide()
			var snapshot := ghost.global_transform
			var label := "%s-%s" % [actor.spec.id, "reduced" if reduced else "normal"]
			var first := await capture(label + "-initial")
			ghost.call("_process", 0.35)
			var middle := await capture(label + "-dissipating")
			var region := Rect2i(250, 80, 140, 170)
			var initial := first.get_region(region)
			var faded := middle.get_region(region)
			var initial_luma := ink_energy(initial)
			var faded_luma := ink_energy(faded)
			check(initial_luma > 10.0 and faded_luma > 1.0 and faded_luma < initial_luma * 0.85, "%s retains the authored form then visibly dissipates without a shader error" % label)
			check(ghost.global_transform.is_equal_approx(snapshot) if reduced else not ghost.global_transform.is_equal_approx(snapshot), "%s respects its selected motion treatment" % label)
			ghost.call("_process", 1.0)
			check(ghost.is_queued_for_deletion(), "%s has a finite cleanup boundary" % label)
			await get_tree().process_frame
			source.show()
		actor.queue_free()
		await get_tree().process_frame
	print("BossDefeatRenderTest: %d passed, %d failed; representative captures=" % [passes, failures], _out)
	get_tree().quit(1 if failures else 0)

func capture(label: String) -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var pixels := get_viewport().get_texture().get_image()
	check(pixels.save_png(_out.path_join(label + ".png")) == OK, label + " representative raster capture saved")
	return pixels

func ink_energy(pixels: Image) -> float:
	var background := Color("171b1e")
	var energy := 0.0
	for y in pixels.get_height():
		for x in pixels.get_width():
			var color := pixels.get_pixel(x, y)
			energy += absf(color.r - background.r) + absf(color.g - background.g) + absf(color.b - background.b)
	return energy
