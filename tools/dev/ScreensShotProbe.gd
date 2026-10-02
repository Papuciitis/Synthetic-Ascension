extends Node
## Renders the in-run menus to PNGs (needs a display, not --headless): the
## augment pick, the major choice, the Ascension tree, the Exchange (shop) and
## the augment library. A throwaway attempt with no current save, so nothing is
## written to the player's slots.
## Run: <godot> --path . res://tools/dev/ScreensShotProbe.tscn -- --out=/abs/dir [--only=augments|major|ascension|shop|library]

var _out := "/tmp"
var _only := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(_out)
	SaveManager.current_save = null
	if not Global.attempt_active:
		Global.start_new_attempt()
	Global.transaction_followers(6000 - Global.followers, &"dev_grant", {}, false, false)
	await _wait(0.3)
	if _want("augments"):
		await _augments()
	if _want("major"):
		await _major()
	if _want("ascension"):
		await _ascension()
	if _want("shop"):
		await _scene_shot("res://ui/screens/HubShop.tscn", "shop", 1.2)
	if _want("library"):
		await _scene_shot("res://ui/screens/AugmentLibrary.tscn", "library", 1.0)
	if _want("misc"):
		await _scene_shot("res://ui/screens/GameOverUI.tscn", "gameover", 1.0)
		await _scene_shot("res://ui/screens/InventoryStash.tscn", "stash", 1.0)
		await _scene_shot("res://ui/screens/base.tscn", "base", 1.0)
	if _want("chronicle"):
		var bg := _backdrop()
		var base := (load("res://ui/screens/base.tscn") as PackedScene).instantiate()
		add_child(base)
		await _wait(1.6)
		await _shot("chronicle")
		var tile := base.find_child("Race_elf", true, false) as Control
		if tile != null:
			get_viewport().warp_mouse(tile.get_global_rect().get_center())
			await _wait(0.2)
			(tile as BaseButton).emit_signal("pressed")
			await _wait(0.8)
			await _shot("chronicle_elf")
		var style := base.find_child("Style_melee", true, false) as BaseButton
		if style != null:
			style.emit_signal("pressed")
			await _wait(0.9)
			await _shot("chronicle_melee")
		base.queue_free()
		bg.queue_free()
		await _wait(0.2)
	if _want("firsthover"):
		# The very first tooltip of a session, a frame at a time.
		for scene_path in ["res://ui/screens/HubShop.tscn", "res://ui/screens/InventoryStash.tscn"]:
			var bg := _backdrop()
			var screen := (load(scene_path) as PackedScene).instantiate()
			add_child(screen)
			await _wait(1.6)
			var slots := screen.find_children("*", "Control", true, false).filter(func(c: Node) -> bool:
				var tex := (c as Control).find_child("Icon", true, false) as TextureRect
				return c.get_class() == "PanelContainer" and tex != null and tex.texture != null and (c as Control).is_visible_in_tree())
			if not slots.is_empty():
				var slot := slots[0] as Control
				get_viewport().warp_mouse(slot.get_global_rect().get_center())
				var ev := InputEventMouseMotion.new()
				ev.position = slot.get_global_rect().get_center()
				ev.global_position = ev.position
				Input.parse_input_event(ev)
				var tag: String = String(scene_path).get_file().get_basename()
				for f in range(3):
					await get_tree().process_frame
					await _shot("firsthover_%s_f%d" % [tag, f])
				await _wait(0.4)
				await _shot("firsthover_%s_settled" % tag)
			screen.queue_free()
			bg.queue_free()
			await _wait(0.2)
	if _want("scrim"):
		var scrim := LoadingScrim.new()
		add_child(scrim)
		scrim.show_for("SEGMENT 3", self)
		await _wait(0.2)
		await _shot("scrim")
		scrim.queue_free()
	print("ScreensShotProbe: done -> ", _out)
	get_tree().quit(0)


func _want(area: String) -> bool:
	return _only == "" or _only == area


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [_out, shot_name])
	print("shot ", shot_name, " ", image.get_size())


func _backdrop() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.1, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	return bg


func _scene_shot(path: String, shot_name: String, settle: float) -> void:
	var bg := _backdrop()
	var node := (load(path) as PackedScene).instantiate()
	add_child(node)
	await _wait(settle)
	await _shot(shot_name)
	node.queue_free()
	bg.queue_free()
	await _wait(0.2)


func _augments() -> void:
	var bg := _backdrop()
	var screen := (load("res://ui/augments/AugmentSelect.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	screen.call("open_choose_3")
	await _wait(0.15)
	await _shot("augments_open_early")
	await _wait(1.0)
	await _shot("augments_open")
	var cards := screen.find_children("*", "Button", true, false)
	for card in cards:
		if card.has_signal("picked"):
			var rect := (card as Control).get_global_rect()
			get_viewport().warp_mouse(rect.get_center() + Vector2(rect.size.x * 0.3, -rect.size.y * 0.25))
			await _wait(0.6)
			await _shot("augments_hover")
			get_viewport().warp_mouse(rect.get_center() + Vector2(rect.size.x * 0.45, 0.0))
			await _wait(0.6)
			await _shot("augments_hover_right_edge")
			# The pick: the chosen card stays lit and glazes, the rest sink.
			# (No HUD here, so nothing flies; AugmentSelect closes right after.)
			screen.set("_locked", false)
			var others := cards.filter(func(c: Node) -> bool: return c != card and c.has_signal("picked"))
			for other in others:
				(other as BaseButton).disabled = true
			card.set("_picked", true)
			(card as BaseButton).disabled = true
			await _wait(0.35)
			await _shot("augments_picked")
			break
	screen.queue_free()
	bg.queue_free()
	await _wait(0.2)


func _major() -> void:
	var bg := _backdrop()
	var screen := (load("res://ui/screens/MajorChoice.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	if screen.has_method("open"):
		screen.call("open")
	await _wait(1.2)
	await _shot("major")
	screen.queue_free()
	bg.queue_free()
	await _wait(0.2)


func _ascension() -> void:
	var bg := _backdrop()
	Global.selected_style_id = "melee"
	Global.attempt_ascension = AscensionLedger.fresh_state("melee")
	var screen := (load("res://ui/screens/AscensionScreen.tscn") as PackedScene).instantiate()
	add_child(screen)
	screen.call("open", false)
	await _wait(1.0)
	await _shot("ascension")
	screen.queue_free()
	bg.queue_free()
	await _wait(0.2)
