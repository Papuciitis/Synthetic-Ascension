extends "res://tools/tests/PauseMenuFlowTest.gd"
## The same behavioral checks, with a real-renderer preview at two sizes.
func _preview_pause(menu: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for _i in range(60):
		if not Global.loading_scrim().is_showing():
			break
		await frames(1)
	await frames(6)
	await RenderingServer.frame_post_draw
	var dir := "res://docs/art/reference/2026-10-16-pause-menu/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	menu.call("resume")
	await frames(6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "game-pause-entry-1280x720.png")
	menu.call("open")
	await frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "pause-game-1280x720.png")
	(menu.get("_menu_button") as Button).pressed.emit()
	DisplayServer.window_set_size(Vector2i(800, 500))
	await frames(12)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "save-exit-small-window.png")
	(menu.get("_confirm") as Control).call("cancel")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await frames(4)
