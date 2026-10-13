extends SceneTree

# Displayed visual fixture with isolated saves:
# <godot> --path . --script res://tools/dev/TutorialGuidanceShotProbe.gd -- --out=/abs/dir
var _out := "user://tutorial_guidance_shots"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	var global := root.get_node("Global")
	var saves := root.get_node("SaveManager")
	saves.set("current_save", null)
	saves.set("current_slot", -1)
	saves.set("save_dir", "user://tests/tutorial_guidance_shots/")
	global.set("debug_disable_autosave", true)
	global.set("attempt_active", true)
	global.set("attempt_segment", 1)
	global.set("attempt_opening_completed", true)
	global.set("tip_shown_intro_move", true)
	global.get("attempt_segment1_milestones").clear()
	for milestone in [&"synthesis", &"first_confrontation", &"assistant_commitment"]:
		global.call("record_segment1_milestone", milestone)
	global.call("reset_run_inventory")
	global.call("reset_run_bag_inventory")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_factor = 1.0
	var story := load("res://core/systems/narrative/StoryDirector.gd")
	story.cards_override = 0
	if change_scene_to_file("res://scenes/game.tscn") != OK:
		quit(1)
		return
	for _frame in range(15):
		await process_frame
	var level := current_scene.get_node("Level1")
	var player := get_first_node_in_group(&"player") as Node2D
	player.global_position = Vector2(672, 736)
	player.call("set_cinematic_input", true, true)
	var camera := player.get_node("Camera2D") as Camera2D
	camera.make_current()
	camera.reset_smoothing()
	for spawner in get_nodes_in_group(&"enemy_spawner"):
		spawner.call("set_spawning_enabled", false)
	for enemy in get_nodes_in_group(&"enemies"):
		enemy.queue_free()
	level.call("_update_objective")
	# Capture after the old 3-second collapse deadline to show persistence.
	await create_timer(3.4, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := _out.path_join("tutorial_guidance_1280.png")
	var result := image.save_png(path)
	print("TutorialGuidanceShotProbe -> ", path)
	quit(0 if result == OK else 1)
