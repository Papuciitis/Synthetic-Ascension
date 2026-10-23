extends Node2D
## Native still of the sniper's aim and shot on street paving: three snipers
## at early, middle and full charge, and one fired shot (flash and impact).
## -- --out=/abs/dir [--reduced-motion]

const ENEMY := preload("res://core/actors/enemy/enemy.tscn")
const SPEC := preload("res://core/actors/enemy/EnemySpec_Sniper.tres")
const PAVING := preload("res://assets/world/city_block/worn_setts.png")
const CHARGES: Array[float] = [0.15, 0.55, 0.97]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://dev_previews/sniper_shot"
	var reduced := false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument == "--reduced-motion": reduced = true
	SettingsManager.set_value(&"accessibility", &"reduced_motion", reduced, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	get_window().size = Vector2i(1280, 720)
	var ground := TextureRect.new()
	ground.texture = PAVING
	ground.stretch_mode = TextureRect.STRETCH_TILE
	# The street's own sett repeat (272 px per tile).
	ground.scale = Vector2.ONE * (272.0 / float(PAVING.get_width()))
	ground.position = Vector2(-900.0, -600.0)
	ground.size = Vector2(1800.0, 1200.0) / ground.scale
	ground.z_as_relative = false
	ground.z_index = -100
	add_child(ground)
	var camera := Camera2D.new()
	add_child(camera)
	camera.make_current()
	camera.zoom = Vector2.ONE * 1.6
	# A short range so the lock-on at the line's end sits in frame.
	var spec := SPEC.duplicate() as EnemySpec
	spec.set(&"sniper_beam_length", 620.0)
	var snipers: Array[EnemyActor] = []
	for index in CHARGES.size() + 1:
		var sniper := ENEMY.instantiate() as EnemyActor
		sniper.spec = spec
		sniper.position = Vector2(-340.0, -150.0 + 95.0 * index)
		add_child(sniper)
		sniper.set_physics_process(false)
		sniper.set_process(false)
		snipers.append(sniper)
	await get_tree().process_frame
	var windup := maxf(float(SPEC.get(&"sniper_windup")) if SPEC.get(&"sniper_windup") != null else 0.9, 0.05)
	for index in CHARGES.size():
		var module: EnemySniper = snipers[index]._sniper
		module._aim_dir = Vector2.RIGHT
		module._ensure_telegraph()
		module.set("_windup_left", windup * (1.0 - CHARGES[index]))
		module._tele.set_meta("_t", 0.37 * index)
		module._update_telegraph()
	var shooter: EnemySniper = snipers[CHARGES.size()]._sniper
	var from := snipers[CHARGES.size()].global_position
	var width := float(SPEC.get(&"sniper_beam_width"))
	shooter._spawn_beam_flash(from, from + Vector2(620.0, 0.0), width)
	shooter._spawn_end_pop(from + Vector2(620.0, 0.0), Vector2.RIGHT, width)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(out).path_join("sniper%s.png" % ("-reduced" if reduced else ""))
	var result := image.save_png(path)
	print("SniperShotPreview: %s (%s)" % [path, error_string(result)])
	for sniper: EnemyActor in snipers:
		sniper._sniper.cleanup()
	get_tree().quit(0 if result == OK else 1)
