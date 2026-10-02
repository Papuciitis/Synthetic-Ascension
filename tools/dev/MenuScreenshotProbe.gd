extends Node
## Renders the front-end screens to PNGs (needs a display, not --headless):
## the main menu on each selection (the backdrop's mood follows it), the
## developer panel, Settings over the menu, and the Archives. A short burst
## of frames per shot shows the weather actually moves.
## Run: <godot> --path . res://tools/dev/MenuScreenshotProbe.tscn -- --out=/abs/dir [--only=menu|archives|settings]

const MAIN_MENU := preload("res://ui/screens/MainMenu.tscn")
const SAVE_SELECT := preload("res://ui/screens/SaveSelect.tscn")

var _out := "/tmp"
var _only := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(_out)
	if _only == "title":
		await _title_shots()
	if _only == "" or _only == "menu" or _only == "settings":
		await _menu_shots()
	if _only == "" or _only == "archives":
		await _archive_shots()
	print("MenuScreenshotProbe: done -> ", _out)
	get_tree().quit(0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [_out, shot_name])
	print("shot ", shot_name, " ", image.get_size())


## The title's draw-on, frame by frame.
func _title_shots() -> void:
	var menu := MAIN_MENU.instantiate()
	add_child(menu)
	var at := 0.0
	for when in [0.7, 1.2, 1.7, 2.2, 2.7, 3.2, 3.6, 4.6]:
		await _wait(when - at)
		at = when
		await _shot("title_%04d" % int(when * 1000.0))
	# Static checks of the shader at fixed draw values.
	var mat := (menu.get_node("Title") as CanvasItem).material as ShaderMaterial
	for v in [0.0, 0.5]:
		mat.set_shader_parameter("draw", v)
		await _wait(0.15)
		await _shot("title_static_%02d" % int(v * 10.0))
	menu.queue_free()
	await _wait(0.2)


func _menu_shots() -> void:
	var menu := MAIN_MENU.instantiate()
	add_child(menu)
	await _wait(0.45)
	await _shot("menu_intro")
	await _wait(2.4)
	await _shot("menu_continue")
	if _only == "settings":
		await _settings_shot(menu)
		menu.queue_free()
		await _wait(0.2)
		return
	for entry in [["NewRun", "menu_new_run"], ["Archives", "menu_archives"], ["Settings", "menu_settings"], ["Quit", "menu_quit"]]:
		(menu.get_node("Menu/" + entry[0]) as Control).grab_focus()
		await _wait(1.6)
		await _shot(entry[1])
	(menu.get_node("Menu/Continue") as Control).grab_focus()
	await _wait(0.12)
	await _shot("menu_flare_mid")
	await _wait(1.5)
	for i in range(3):
		await _wait(0.8)
		await _shot("menu_motion_%d" % i)
	var dev := menu.get_node_or_null("Menu/DevMode") as BaseButton
	if dev != null and dev.visible:
		dev.grab_focus()
		dev.button_pressed = true
		await _wait(1.0)
		await _shot("menu_dev")
		dev.button_pressed = false
	await _settings_shot(menu)
	menu.queue_free()
	await _wait(0.2)


func _settings_shot(menu: Node) -> void:
	(menu.get_node("Menu/Settings") as BaseButton).pressed.emit()
	await _wait(0.8)
	await _shot("settings_audio")
	var screens := menu.find_children("SettingsScreen", "Control", true, false)
	if not screens.is_empty():
		for section in [&"video", &"controls", &"accessibility"]:
			screens[0].call("_set_section", section)
			await _wait(0.5)
			await _shot("settings_" + String(section))
		screens[0].call("close")


## Fixture chronicles in a scratch save folder, so the shots show filled cards
## without touching the player's real slots.
func _archive_shots() -> void:
	var real_dir: String = SaveManager.save_dir
	SaveManager.save_dir = "user://probe_saves/"
	for slot in range(1, 4):
		SaveManager.delete_slot(slot)
	var elf: SaveData = SaveManager.create_slot(1, "Ilyra Vey")
	elf.mortal_name = "Ilyra Vey"
	elf.last_race_id = "elf"
	elf.last_style_id = "magic"
	elf.attempt_active = true
	elf.attempt_segment = 4
	elf.attempt_followers = 1240
	elf.attempt_resume_scene = "res://scenes/game.tscn"
	elf.total_runs = 3
	elf.best_followers = 2210
	SaveManager.save_slot(elf)
	var construct: SaveData = SaveManager.create_slot(3, "Brass Penitent")
	construct.mortal_name = "Brass Penitent"
	construct.last_race_id = "warforged"
	construct.last_style_id = "melee"
	construct.total_runs = 11
	construct.best_followers = 5300
	SaveManager.save_slot(construct)
	await _archive_screen()
	for slot in range(1, 4):
		SaveManager.delete_slot(slot)
	SaveManager.save_dir = real_dir


func _archive_screen() -> void:
	var screen := SAVE_SELECT.instantiate()
	add_child(screen)
	await _wait(2.6)
	await _shot("archives")
	if screen.has_method("_card"):
		for slot in [1, 2, 3]:
			var card: Control = screen.call("_card", slot)
			if card != null:
				card.grab_focus()
				await _wait(0.9)
				await _shot("archives_slot_%d" % slot)
	screen.queue_free()
	await _wait(0.2)
