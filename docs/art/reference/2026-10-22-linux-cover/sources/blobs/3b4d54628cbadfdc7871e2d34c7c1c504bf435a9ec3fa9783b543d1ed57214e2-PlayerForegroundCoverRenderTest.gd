extends Node2D
## Native pixel probe for the production player body/head material and shared
## coverage transport. Fixtures use original cover art; this is not a human run.

const HELPER := preload("res://core/actors/player/PlayerRoofOcclusion.gd")
const FOREGROUND := preload("res://core/systems/world/visibility/ForegroundSpriteCoverage.gd")
const COVER := preload("res://core/systems/world/visibility/WorldCover.gd")
const ROOF := preload("res://scenes/world/buildings/RoofOverlay.tscn")
const BODY_COLOR := Color(0.95, 0.18, 0.08, 1.0)
const HEAD_COLOR := Color(0.20, 0.80, 0.95, 1.0)
var _passed := 0
var _failed := 0
var _out := "user://player_foreground_cover_render"
var _viewport: SubViewport
var _world: Node2D
var _actor: Node2D
var _fixture: Node2D
var _body: AnimatedSprite2D
var _head: AnimatedSprite2D
var _helper: RefCounted
var _cover: Node
var _material: Material
var _scale := 1.0
var _size_name := "normal"
var _captures: Array[Dictionary] = []
var _real_samples: Array[Dictionary] = []
var _save_writes_before := 0

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
		print("PASS: ", _size_name, " ", message)
	else:
		_failed += 1
		push_error(_size_name + " " + message)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("PlayerForegroundCoverRenderTest requires the native renderer")
		get_tree().quit(1)
		return
	var arguments := OS.get_cmdline_user_args()
	for index in arguments.size():
		if arguments[index].begins_with("--out="):
			_out = arguments[index].trim_prefix("--out=")
		elif arguments[index] == "--out" and index + 1 < arguments.size():
			_out = arguments[index + 1]
	_out = ProjectSettings.globalize_path(_out)
	DirAccess.make_dir_recursive_absolute(_out)
	_save_writes_before = SaveManager.debug_save_writes
	for size: Vector2i in [Vector2i(960, 540), Vector2i(640, 360)]:
		await _setup(size)
		await _rgba_fixture()
		await _atlas_fixture()
		await _real_tree_fixture(false)
		await _real_tree_fixture(true)
		await _roof_fixture()
		await _capacity_fixture()
		_check(_body.material == _material and _head.material == _material, "body and head retain their one shared production material across every cover state")
		_viewport.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_check(SaveManager.debug_save_writes == _save_writes_before, "the isolated native probe writes no profile saves")
	var report := {"passed": _passed, "failed": _failed, "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "captures": _captures, "real_art_samples": _real_samples, "save_writes": SaveManager.debug_save_writes - _save_writes_before, "limits": "Native material-path fixtures with original ordinary/fruit tree art; synthetic actor blocks use the production PlayerRoofOcclusion body/head material. No human traversal, combat or whole-street acceptance is claimed."}
	var file := FileAccess.open(_out.path_join("result.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	else:
		_check(false, "native probe can save its result manifest")
	print("PlayerForegroundCoverRenderTest: %d passed, %d failed; output=%s" % [_passed, _failed, _out])
	get_tree().quit(1 if _failed > 0 else 0)

func _setup(size: Vector2i) -> void:
	_scale = float(size.x) / 960.0
	_size_name = "normal" if size.x == 960 else "small"
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.world_2d = World2D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_world = Node2D.new()
	_viewport.add_child(_world)
	_viewport.canvas_transform = Transform2D.IDENTITY.scaled(Vector2.ONE * _scale)
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(960, 0), Vector2(960, 540), Vector2(0, 540)])
	background.color = Color(0.65, 0.65, 0.65)
	background.z_index = -1000
	_world.add_child(background)
	_actor = Node2D.new()
	_world.add_child(_actor)
	_body = _animated(Vector2i(64, 96), BODY_COLOR, Vector2(-32, -96))
	_head = _animated(Vector2i(32, 32), HEAD_COLOR, Vector2(-16, -128))
	_helper = HELPER.new()
	_helper.configure(_body, _head)
	_material = _body.material
	_cover = COVER.get_for(_world)
	_new_fixture()
	await get_tree().process_frame

func _animated(size: Vector2i, color: Color, offset: Vector2) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.add_frame(&"default", _solid(size, color))
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.position = offset
	_actor.add_child(sprite)
	return sprite

func _solid(size: Vector2i, color: Color) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func _new_fixture() -> void:
	if is_instance_valid(_fixture):
		_fixture.free()
	_fixture = Node2D.new()
	_world.add_child(_fixture)
	_body.modulate = Color.WHITE
	_head.modulate = Color.WHITE

func _pattern() -> Image:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.20, 0.58, 0.18, 1))
	image.fill_rect(Rect2i(0, 0, 4, 16), Color.TRANSPARENT)
	image.fill_rect(Rect2i(4, 0, 4, 16), Color(0.20, 0.58, 0.18, 0.5))
	image.fill_rect(Rect2i(9, 12, 2, 2), Color.TRANSPARENT)
	return image

func _pattern_sprite(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = Vector2(3, -2)
	sprite.scale = Vector2(8, 12)
	sprite.position = Vector2(152, 128)
	sprite.z_index = -1
	_fixture.add_child(sprite)
	FOREGROUND.register(sprite, Vector2(224, 288))
	return sprite

func _frame(feet: Vector2) -> Image:
	_actor.position = feet
	_helper.update(_world, feet, Rect2(feet - Vector2(80, 150), Vector2(160, 165)))
	_cover.call("refresh", _world, true)
	await get_tree().process_frame
	_helper.update(_world, feet, Rect2(feet - Vector2(80, 150), Vector2(160, 165)))
	_cover.call("refresh", _world, true)
	await RenderingServer.frame_post_draw
	return _viewport.get_texture().get_image()

func _color(image: Image, world_point: Vector2) -> Color:
	return image.get_pixelv(Vector2i(world_point * _scale))

func _distance(first: Color, second: Color) -> float:
	return Vector3(first.r - second.r, first.g - second.g, first.b - second.b).length()

func _save(image: Image, label: String) -> void:
	var name := _size_name + "-" + label + ".png"
	_check(image.save_png(_out.path_join(name)) == OK, "native capture saves " + label)
	_captures.append({"name": name, "size": [image.get_width(), image.get_height()], "stats": _cover.call("snapshot_stats")})

func _rgba_fixture() -> void:
	_new_fixture()
	var tree := _pattern_sprite(ImageTexture.create_from_image(_pattern()))
	var behind := await _frame(Vector2(224, 272))
	_save(behind, "rgba-behind")
	var hole := _color(behind, Vector2(196, 232))
	var partial := _color(behind, Vector2(220, 232))
	var opaque := _color(behind, Vector2(252, 232))
	_check(_distance(hole, BODY_COLOR) < 0.04, "true transparent leaf columns retain the authored body color")
	_check(_distance(_color(behind, Vector2(252, 256)), BODY_COLOR) < 0.04, "an internal leaf hole stays fully colored inside the foreground bounds")
	_check(opaque.r < 0.40, "opaque foreground produces the quiet dark body silhouette")
	_check(partial.r > opaque.r + 0.12 and partial.r < hole.r - 0.12, "partial leaf alpha produces intermediate coverage rather than a rectangle")
	_check(_color(behind, Vector2(224, 156)).g < HEAD_COLOR.g - 0.10, "the head shares the same sampled partial coverage")
	var reads := int((_cover.call("snapshot_stats") as Dictionary).get("source_reads", -1))
	for index in 3:
		await _frame(Vector2(224, 272))
	_check(int((_cover.call("snapshot_stats") as Dictionary).get("source_reads", -2)) == reads, "stable frames reuse the shared foreground source image")
	var front := await _frame(Vector2(224, 304))
	_save(front, "rgba-front")
	_check(_distance(_color(front, Vector2(252, 232)), BODY_COLOR) < 0.04, "an actual actor moved south of the root remains fully colored under the same canopy")
	tree.modulate.a = 0.5
	var faded := await _frame(Vector2(224, 272))
	var fade_color := _color(faded, Vector2(252, 232))
	_check(fade_color.r > opaque.r + 0.10 and fade_color.r < BODY_COLOR.r - 0.10, "live foreground modulation composes continuously with source alpha")
	tree.modulate.a = 0.0
	var clear := await _frame(Vector2(224, 272))
	_check(_distance(_color(clear, Vector2(252, 232)), BODY_COLOR) < 0.04, "fully faded foreground restores normal body presentation")
	_body.modulate = Color(0.55, 0.80, 0.70, 0.65)
	var authored := await _frame(Vector2(224, 272))
	tree.modulate.a = 1.0
	await _frame(Vector2(224, 272))
	tree.visible = false
	var restored := await _frame(Vector2(224, 272))
	_check(_distance(_color(authored, Vector2(252, 232)), _color(restored, Vector2(252, 232))) < 0.025, "clearing cover restores the preexisting authored tint and alpha")
	_check(_body.modulate.is_equal_approx(Color(0.55, 0.80, 0.70, 0.65)), "coverage leaves body modulation under its original owner")

func _atlas_fixture() -> void:
	_new_fixture()
	var sheet := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.MAGENTA)
	sheet.blit_rect(_pattern(), Rect2i(0, 0, 16, 16), Vector2i(8, 0))
	var atlas := AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(sheet)
	atlas.region = Rect2(8, 0, 16, 16)
	var tree := _pattern_sprite(atlas)
	tree.region_enabled = true
	tree.region_rect = Rect2(0, 0, 16, 16)
	tree.flip_h = true
	var image := await _frame(Vector2(256, 272))
	_save(image, "atlas-flipped")
	_check(_distance(_color(image, Vector2(280, 232)), BODY_COLOR) < 0.04, "flipped atlas leaf holes use the cropped region rather than opaque neighboring cells")
	_check(_color(image, Vector2(232, 232)).r < 0.40, "flipped atlas opaque pixels cover the opposite side of the body")
	var partial := _color(image, Vector2(256, 232))
	_check(partial.r > 0.35 and partial.r < 0.80, "flipped atlas pixels retain continuous partial alpha")
	image = await _frame(Vector2(184, 272))
	_check(_distance(_color(image, Vector2(172, 232)), BODY_COLOR) < 0.04, "pixels outside the atlas draw region remain normal at its edge")
	_check(_color(image, Vector2(180, 232)).r < 0.40, "pixels just inside the atlas draw region receive foreground coverage")

func _real_tree_fixture(domestic: bool) -> void:
	_new_fixture()
	var path := "res://assets/world/domestic_gardens/v1/fruit_tree_overhead_v2.png" if domestic else "res://assets/world/city_block/temperate_tree.png"
	var texture := load(path) as Texture2D
	var tree := Sprite2D.new()
	tree.texture = texture
	var anchor := Vector2(660, 1060) if domestic else Vector2(650, 1170)
	var scale_value := 135.0 / 1167.0 if domestic else 280.0 / 1254.0
	tree.scale = Vector2.ONE * scale_value
	tree.position = Vector2(650, 420) + (texture.get_size() * 0.5 - anchor) * scale_value
	tree.z_index = -1
	_fixture.add_child(tree)
	FOREGROUND.register(tree, Vector2(650, 420))
	var feet := Vector2(650, 419 if domestic else 350)
	var image := await _frame(feet)
	var source := texture.get_image()
	var hole := _find_art_pixel(tree, source, Vector2(750, 985) if domestic else Vector2(730, 585), feet, false)
	var opaque := _find_art_pixel(tree, source, Vector2(800, 900) if domestic else Vector2(700, 750), feet, true)
	_check(hole.x >= 0 and opaque.x >= 0, "real tree source supplies a visible internal gap and opaque leaf probe")
	if hole.x >= 0 and opaque.x >= 0:
		_check(_distance(image.get_pixelv(hole), BODY_COLOR) < 0.055, "actual tree internal low-alpha gaps retain the authored body color")
		_check(image.get_pixelv(opaque).r < 0.45, "actual ordinary or fruit-tree leaf pixels render the quiet silhouette")
		_real_samples.append({"size": _size_name, "tree": path, "root": [anchor.x, anchor.y], "scale": scale_value, "hole_pixel": [hole.x, hole.y], "opaque_pixel": [opaque.x, opaque.y], "hole_color": str(image.get_pixelv(hole)), "opaque_color": str(image.get_pixelv(opaque))})
	_save(image, "fruit-behind" if domestic else "ordinary-behind")
	image = await _frame(Vector2(650, 450))
	_check(_distance(_color(image, Vector2(650, 400)), BODY_COLOR) < 0.04, "moving in front of the actual measured tree root restores normal presentation")
	_save(image, "fruit-front" if domestic else "ordinary-front")

func _find_art_pixel(tree: Sprite2D, image: Image, source_point: Vector2, feet: Vector2, opaque: bool) -> Vector2i:
	var target := Vector2i(tree.to_global(source_point - tree.texture.get_size() * 0.5) * _scale)
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for y in range(target.y - 6, target.y + 7):
		for x in range(target.x - 6, target.x + 7):
			var world_point := (Vector2(x, y) + Vector2.ONE * 0.5) / _scale
			if not Rect2(feet + Vector2(-30, -94), Vector2(60, 92)).has_point(world_point):
				continue
			var texel := tree.to_local(world_point) + tree.texture.get_size() * 0.5
			var alpha := _linear_alpha(image, texel)
			if (opaque and alpha < 0.94) or (not opaque and alpha > 0.005):
				continue
			var distance := Vector2(x, y).distance_squared_to(Vector2(target))
			if distance < best_distance:
				best_distance = distance
				best = Vector2i(x, y)
	return best

func _linear_alpha(image: Image, texel: Vector2) -> float:
	var position := texel - Vector2.ONE * 0.5
	var low := Vector2i(position.floor())
	if low.x < 0 or low.y < 0 or low.x + 1 >= image.get_width() or low.y + 1 >= image.get_height():
		return 1.0
	var fraction := position - Vector2(low)
	var top := lerpf(image.get_pixel(low.x, low.y).a, image.get_pixel(low.x + 1, low.y).a, fraction.x)
	var bottom := lerpf(image.get_pixel(low.x, low.y + 1).a, image.get_pixel(low.x + 1, low.y + 1).a, fraction.x)
	return lerpf(top, bottom, fraction.y)

func _roof_fixture() -> void:
	_new_fixture()
	var roof := ROOF.instantiate() as RoofOverlay
	_fixture.add_child(roof)
	roof.configure(Rect2i(3, 3, 5, 4), 64, Vector2i.DOWN, null)
	roof._set_alpha(1.0)
	var image := await _frame(Vector2(350, 350))
	_save(image, "roof-opaque")
	var full := _color(image, Vector2(350, 290))
	_check(full.r < 0.40, "existing opaque roofs keep the player's established silhouette")
	# The polygon's own modulate remains opaque here. Legacy triangle strength
	# must not override the shared query's actual inherited/self alpha.
	var poly := roof.get_node("RoofPoly") as Polygon2D
	poly.self_modulate.a = 0.0
	image = await _frame(Vector2(350, 350))
	_check(_distance(_color(image, Vector2(350, 290)), BODY_COLOR) < 0.04, "a self-transparent roof leaves the player normal despite opaque polygon modulation")
	poly.self_modulate.a = 1.0
	roof.modulate.a = 0.0
	image = await _frame(Vector2(350, 350))
	_check(_distance(_color(image, Vector2(350, 290)), BODY_COLOR) < 0.04, "a transparent roof ancestor leaves the player normal despite opaque polygon modulation")
	roof.modulate.a = 0.4
	image = await _frame(Vector2(350, 350))
	var partial := _color(image, Vector2(350, 290))
	_check(partial.r > full.r + 0.12 and partial.r < BODY_COLOR.r - 0.12, "partial roof ancestor alpha produces intermediate player coverage")
	_save(image, "roof-ancestor-partial")
	roof.modulate.a = 1.0
	roof._inside_count = 1
	roof._set_alpha(0.0)
	image = await _frame(Vector2(350, 350))
	_save(image, "roof-cutaway")
	_check(_distance(_color(image, Vector2(350, 290)), BODY_COLOR) < 0.04, "the actual roof cutaway restores the normal player material presentation")
	roof.queue_free()
	await get_tree().process_frame
	image = await _frame(Vector2(350, 350))
	_check(_distance(_color(image, Vector2(350, 290)), BODY_COLOR) < 0.04, "streamed roof removal clears both shared and legacy player state")

func _capacity_fixture() -> void:
	_new_fixture()
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(12, 0, 4, 16), Color(0.2, 0.58, 0.18))
	var texture := ImageTexture.create_from_image(image)
	var last: Sprite2D
	for index in 35:
		var tree := Sprite2D.new()
		tree.texture = texture
		tree.centered = false
		tree.scale = Vector2.ONE * 4.0
		tree.position = Vector2(168 if index == 34 else 200, 200)
		tree.z_index = -1
		_fixture.add_child(tree)
		FOREGROUND.register(tree, Vector2(224, 320))
		last = tree
	var pixels := await _frame(Vector2(224, 272))
	var stats: Dictionary = _cover.call("snapshot_stats")
	_check(int(stats.get("primitive_count", 0)) >= 35 and int(stats.get("max_candidates", 0)) >= 35, "the native shared cell retains more than32 foreground candidates")
	_check(_color(pixels, Vector2(224, 232)).r < 0.40, "the only opaque foreground candidate beyond the old32 limit still covers the player")
	_save(pixels, "capacity-35")
	var reads := int(stats.get("source_reads", -1))
	last.queue_free()
	await get_tree().process_frame
	pixels = await _frame(Vector2(224, 272))
	_check(_distance(_color(pixels, Vector2(224, 232)), BODY_COLOR) < 0.04, "streaming out the covering candidate clears its silhouette while transparent neighbors remain")
	var reloaded := Sprite2D.new()
	reloaded.texture = texture
	reloaded.centered = false
	reloaded.scale = Vector2.ONE * 4.0
	reloaded.position = Vector2(168, 200)
	reloaded.z_index = -1
	_fixture.add_child(reloaded)
	FOREGROUND.register(reloaded, Vector2(224, 320))
	pixels = await _frame(Vector2(224, 272))
	_check(_color(pixels, Vector2(224, 232)).r < 0.40, "reloading the same cover resource restores foreground coverage")
	_check(int((_cover.call("snapshot_stats") as Dictionary).get("source_reads", -2)) == reads, "cover reload reuses the original cached texture image")
