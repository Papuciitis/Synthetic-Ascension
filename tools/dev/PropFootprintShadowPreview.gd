extends Node2D
## Native still of painted three-quarter props' sun casts on paving: plaza
## pieces (PlazaDressing._prop) and frontage piles (CityFrontageDressing),
## each row cast first from the sprite's bottom edge (the old pivot) and then
## from its footprint centre (WorldDepthStyle.footprint_pivot), through the
## real shadow code.
## -- --out=/abs/dir

const PLAZA := preload("res://scenes/world/plazas/PlazaDressing.gd")
const FRONTAGE := preload("res://scenes/world/buildings/CityFrontageDressing.gd")
const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")
const PAVING := preload("res://assets/world/city_block/worn_setts.png")
const PLAZA_IDS: Array[StringName] = [&"plaza_fountain", &"market_stall", &"bench_stone", &"well_stone", &"notice_board", &"lamp_post"]
const FRONTAGE_IDS: Array[StringName] = [&"crates_stack", &"barrels_group", &"sacks_pile", &"handcart", &"table_benches", &"pots_cluster"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://dev_previews/prop_footprint_shadow"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	get_window().size = Vector2i(1280, 720)
	DEPTH.reset_light()
	var ground := TextureRect.new()
	ground.texture = PAVING
	ground.stretch_mode = TextureRect.STRETCH_TILE
	ground.scale = Vector2.ONE * (272.0 / float(PAVING.get_width()))
	ground.position = Vector2(-1100.0, -700.0)
	ground.size = Vector2(2200.0, 1400.0) / ground.scale
	ground.z_as_relative = false
	ground.z_index = -100
	add_child(ground)
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE * 1.15
	add_child(camera)
	camera.make_current()
	for row in 2:
		var dressing := PLAZA.new() as Node2D
		dressing.position = Vector2(-640.0, -330.0 + 190.0 * row)
		add_child(dressing)
		for index in PLAZA_IDS.size():
			var foot := Vector2(110.0 + 210.0 * index, 120.0)
			if row == 0:
				_old_plaza(dressing, PLAZA_IDS[index], foot)
			else:
				dressing.call("_prop", PLAZA_IDS[index], foot, 1.0, false)
	for row in 2:
		var host := Node2D.new()
		host.position = Vector2(-640.0, 60.0 + 150.0 * row)
		add_child(host)
		for index in FRONTAGE_IDS.size():
			_frontage(host, FRONTAGE_IDS[index], Vector2(110.0 + 210.0 * index, 110.0), row == 1)
	for _frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(out).path_join("footprint-shadows.png")
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("PropFootprintShadowPreview: %s (%s)" % [path, error_string(result)])
	get_tree().quit(0 if result == OK else 1)


## The plaza prop with its cast pivoting on the sprite's bottom edge (the
## pre-2026-10-23 projection), drawn the way PlazaDressing._shadow_for does.
func _old_plaza(dressing: Node2D, id: StringName, foot: Vector2) -> void:
	var sprite: Sprite2D = dressing.call("_prop", id, foot, 1.0, false)
	for child: Node in dressing.get_children():
		if child is Polygon2D and child.has_meta(&"city_sun_shadow") and not child.has_meta(&"preview_old"):
			child.queue_free()
	var region := sprite.region_rect
	var half := region.size * 0.5
	var projection := DEPTH.project_transform(sprite.transform, foot)
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	for corner: Vector2 in [Vector2.ZERO, Vector2(region.size.x, 0.0), region.size, Vector2(0.0, region.size.y)]:
		points.append(projection * (corner - half))
		uv.append(region.position + corner)
	var shade := Polygon2D.new()
	shade.polygon = points
	shade.uv = uv
	shade.texture = sprite.texture
	shade.color = PLAZA.SHADOW_COLOR
	shade.z_index = PLAZA.SHADOW_Z
	shade.set_meta(&"city_sun_shadow", true)
	shade.set_meta(&"preview_old", true)
	dressing.add_child(shade)


func _frontage(host: Node2D, id: StringName, foot: Vector2, footprint: bool) -> void:
	var spec: Dictionary = FRONTAGE.PROPS[id]
	var texture := load(FRONTAGE.ROOT + String(spec.file)) as Texture2D
	if texture == null: return
	var rect: Rect2 = spec.rect
	var scale_value := float(spec.width) / rect.size.x
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2.ONE * scale_value
	sprite.position = foot + (texture.get_size() * 0.5 - Vector2(rect.get_center().x, rect.end.y)) * scale_value
	sprite.modulate = FRONTAGE.PROP_TINT
	sprite.z_index = 1
	host.add_child(sprite)
	FRONTAGE._add_shadow(host, sprite, foot, texture, DEPTH.footprint_pivot(foot, rect.size * scale_value) if footprint else null)
