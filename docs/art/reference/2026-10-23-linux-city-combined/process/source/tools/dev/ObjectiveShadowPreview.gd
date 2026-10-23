extends Node2D
## Native side-by-side of every objective world form on street paving, to
## judge their shade against the shared sun (WorldDepthStyle): the upright
## forms (wardstone, relay, wager, and a whole Wardstone scene) and, as
## controls, the ground forms (rite, vigil, breach, vault).
## -- --out=/abs/dir

const WORLD_ART := preload("res://core/systems/world/objectives/ObjectiveWorldArt.gd")
const WARD := preload("res://scenes/world/wardstones/Wardstone.tscn")
const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")
const PAVING := preload("res://assets/world/city_block/worn_setts.png")
## Names and heights as their objectives install them.
const UPRIGHT := [["wardstone", 142.0], ["relay", 83.0], ["wager", 120.0]]
const GROUND := [["exit_rite", 184.0], ["vigil", 105.0], ["breach", 100.0], ["vault", 76.0]]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://dev_previews/objective_shadow"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	get_window().size = Vector2i(1280, 720)
	Global.debug_disable_autosave = true
	DEPTH.reset_light()
	var ground := TextureRect.new()
	ground.texture = PAVING
	ground.stretch_mode = TextureRect.STRETCH_TILE
	ground.position = Vector2(-800.0, -500.0)
	ground.size = Vector2(1600.0, 1000.0)
	ground.z_as_relative = false
	ground.z_index = -100
	add_child(ground)
	var camera := Camera2D.new()
	add_child(camera)
	camera.make_current()
	for index in UPRIGHT.size():
		WORLD_ART.install(self, UPRIGHT[index][0], UPRIGHT[index][1], Vector2(-480.0 + 320.0 * index, -40.0), "Upright%d" % index)
	var ward := WARD.instantiate()
	ward.position = Vector2(480.0, -40.0)
	add_child(ward)
	ward.set_process(false)
	for index in GROUND.size():
		WORLD_ART.install(self, GROUND[index][0], GROUND[index][1], Vector2(-480.0 + 320.0 * index, 220.0), "Ground%d" % index)
	for _frame in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(out).path_join("objectives.png")
	var result := image.save_png(path)
	print("ObjectiveShadowPreview: %s (%s)" % [path, error_string(result)])
	get_tree().quit(0 if result == OK else 1)
