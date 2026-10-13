extends SceneTree

# Representative Sprite2D frames read the real EnemySpec art, scales and tints.
# <godot> --path . --script res://tools/dev/EnemyRosterShotProbe.gd -- --out=/abs/dir
const SPECS := [
	"Bomber", "Runner", "Charger", "Sniper", "Herald", "Summoner", "Leech", "Orbiter",
	"Brute", "SummonedMinion", "SplitterSlime", "Warden", "Lurker", "Siphon", "Chanter",
	"OpeningOfficer", "ContainmentConstruct", "BossBulldozer", "BossArcanist", "Grunt", "Spitter",
]
const PREVIEW_SCALE := 1.5
var _out := "user://enemy_roster_shots"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	root.get_node("Global").set("debug_disable_autosave", true)
	root.get_node("SaveManager").set("save_dir", "user://tests/enemy_roster_shots/")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 960)
	root.content_scale_size = Vector2i(1280, 960)
	root.content_scale_factor = 1.0
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("101716")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)
	_label(canvas, Vector2(40, 16), Vector2(1200, 32), "ENFORCER ROSTER — ROLE ART AND EXISTING VARIANTS", 24, Color("e7d8b3"))
	_label(canvas, Vector2(40, 50), Vector2(1200, 22), "Preview at 1.5× · dimensions below are before parent/boss/split scaling · existing tints retained", 16, Color("a8b8b1"))
	var renderer := load("res://core/systems/enemy_world/EnemyProxyRenderer.gd")
	for index in range(SPECS.size()):
		var spec := load("res://core/actors/enemy/EnemySpec_%s.tres" % SPECS[index])
		var texture: Texture2D = spec.portrait_texture()
		if texture == null:
			push_error("Missing roster texture: " + SPECS[index])
			quit(1)
			return
		var origin := Vector2(40 + (index % 5) * 240, 88 + (index / 5) * 170)
		var tile := ColorRect.new()
		tile.color = Color("1b2522") if index % 2 == 0 else Color("202925")
		tile.position = origin
		tile.size = Vector2(230, 162)
		canvas.add_child(tile)
		_label(canvas, origin + Vector2(8, 5), Vector2(214, 26), spec.display_name, 17, Color("eadcbc"))
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = renderer.texture_filter_for(texture)
		sprite.position = origin + Vector2(115, 85)
		sprite.scale = spec.sprite_scale * PREVIEW_SCALE
		sprite.modulate = spec.sprite_modulate
		canvas.add_child(sprite)
		var size: Vector2 = texture.get_size() * spec.sprite_scale
		_label(canvas, origin + Vector2(8, 138), Vector2(214, 20), "%.1f × %.1f px%s" % [size.x, size.y, " · animated" if spec.visual_frames != null else ""], 15, Color("a8b8b1"))
	for _frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := _out.path_join("enemy_roster_1280.png")
	var error := root.get_texture().get_image().save_png(path)
	print("EnemyRosterShotProbe -> ", path)
	quit(0 if error == OK else 1)


func _label(parent: Control, position: Vector2, size: Vector2, text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.position = position
	label.size = size
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
