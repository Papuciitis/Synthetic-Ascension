extends Node2D
## These fixtures catch source-coordinate, ground-depth and lifetime errors
## before any consumer samples the foreground texture on the GPU.

const COVERAGE_PATH := "res://core/systems/world/visibility/ForegroundSpriteCoverage.gd"
const GROUP := &"foreground_occluders"
var _coverage: GDScript
var _passed := 0
var _failed := 0

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		push_error(message)

func _texture(size: Vector2i = Vector2i(8, 4)) -> ImageTexture:
	var pixels := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	return ImageTexture.create_from_image(pixels)

func _sprite(parent: Node2D, texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	parent.add_child(sprite)
	return sprite

func _describe(sprite: Sprite2D) -> Dictionary:
	return _coverage.call("describe", sprite)

func _register(sprite: Sprite2D, ground: Vector2) -> void:
	_coverage.call("register", sprite, ground)

func _uv(descriptor: Dictionary, point: Vector2) -> Vector2:
	var mapping: Transform2D = descriptor.get("world_to_uv", Transform2D.IDENTITY)
	return mapping * point

func _run() -> void:
	_check(ResourceLoader.exists(COVERAGE_PATH), "live foreground sprites need a coverage descriptor provider")
	if not ResourceLoader.exists(COVERAGE_PATH):
		_finish()
		return
	_coverage = load(COVERAGE_PATH) as GDScript
	var methods: Array[StringName] = []
	for method: Dictionary in _coverage.get_script_method_list():
		methods.append(StringName(method.name))
	_check(methods.has(&"register") and methods.has(&"describe"), "foreground descriptor provider exposes registration and live description")
	if not methods.has(&"register") or not methods.has(&"describe"):
		_finish()
		return
	_test_transform_and_depth()
	_test_center_offset_and_flips()
	_test_regions_and_frames()
	_test_atlas_coordinates()
	await _test_visibility_alpha_and_lifetime()
	_test_actual_city_trees()
	await get_tree().process_frame
	_finish()

func _finish() -> void:
	print("ForegroundSpriteCoverageTest: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)

func _test_transform_and_depth() -> void:
	var parent := Node2D.new()
	parent.position = Vector2(100, 200)
	parent.rotation = PI * 0.5
	parent.scale = Vector2(2, 3)
	add_child(parent)
	var sprite := _sprite(parent, _texture())
	sprite.position = Vector2(10, 20)
	sprite.scale = Vector2(0.5, 2)
	sprite.centered = false
	sprite.offset = Vector2(3, -2)
	_register(sprite, Vector2(7, 9))
	var descriptor := _describe(sprite)
	_check(not descriptor.is_empty(), "a live registered foreground returns a descriptor")
	_check(_uv(descriptor, Vector2(52, 223)).is_equal_approx(Vector2.ZERO), "rotated scaled parent maps the real draw origin to source UV zero")
	_check(_uv(descriptor, Vector2(28, 231)).is_equal_approx(Vector2.ONE), "nonuniform transforms preserve the opposite source corner")
	_check(is_equal_approx(float(descriptor.get("front_y", 0)), 214.0), "foreground depth transforms the parent-local ground contact rather than the sprite centre")
	_check((descriptor.get("bounds", Rect2()) as Rect2).is_equal_approx(Rect2(28, 223, 24, 8)), "broad-phase bounds enclose the transformed artwork")
	_check(descriptor.get("texture") == sprite.texture, "descriptors retain the shared original texture resource")
	var owner: WeakRef = descriptor.get("owner")
	_check(owner != null and owner.get_ref() == sprite, "descriptors hold a weak foreground owner")
	_register(sprite, Vector2(8, 10))
	_check(get_tree().get_nodes_in_group(GROUP).count(sprite) == 1, "reregistering one sprite does not duplicate coverage")
	_check(is_equal_approx(float(_describe(sprite).get("front_y", 0)), 216.0), "reregistration updates the transformed ground contact")
	parent.free()

func _test_center_offset_and_flips() -> void:
	var sprite := _sprite(self, _texture())
	sprite.offset = Vector2(3, -2)
	_register(sprite, Vector2.ZERO)
	_check(_uv(_describe(sprite), Vector2(1, -3)).is_equal_approx(Vector2(0.25, 0.25)), "centering and authored offset select the correct source pixel")
	sprite.flip_h = true
	_check(_uv(_describe(sprite), Vector2(1, -3)).is_equal_approx(Vector2(0.75, 0.25)), "horizontal flip mirrors source selection without moving the draw bounds")
	sprite.flip_v = true
	_check(_uv(_describe(sprite), Vector2(1, -3)).is_equal_approx(Vector2(0.75, 0.75)), "vertical flip composes with horizontal flip")
	sprite.centered = false
	sprite.flip_h = false
	sprite.flip_v = false
	_check(_uv(_describe(sprite), Vector2(5, -1)).is_equal_approx(Vector2(0.25, 0.25)), "uncentered sprites keep their authored offset")
	sprite.free()

func _test_regions_and_frames() -> void:
	var sprite := _sprite(self, _texture(Vector2i(16, 12)))
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = Rect2(4, 2, 8, 8)
	sprite.hframes = 2
	sprite.vframes = 2
	sprite.frame = 3
	_register(sprite, Vector2.ZERO)
	var descriptor := _describe(sprite)
	_check((descriptor.get("source_rect", Rect2()) as Rect2).is_equal_approx(Rect2(8, 6, 4, 4)), "animation frames select their region inside the authored source rectangle")
	_check(_uv(descriptor, Vector2(1, 3)).is_equal_approx(Vector2(0.25, 0.75)), "frame UV normalization uses frame size rather than the full sheet")
	sprite.frame = 0
	_check((_describe(sprite).get("source_rect", Rect2()) as Rect2).is_equal_approx(Rect2(4, 2, 4, 4)), "changing frame refreshes source metadata without image decoding")
	sprite.free()

func _test_atlas_coordinates() -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = _texture(Vector2i(16, 12))
	atlas.region = Rect2(6, 3, 4, 6)
	var sprite := _sprite(self, atlas)
	sprite.centered = false
	_register(sprite, Vector2.ZERO)
	var descriptor := _describe(sprite)
	_check(descriptor.get("texture") == atlas, "atlas descriptors identify the logical cropped texture for shared image caching")
	_check((descriptor.get("source_rect", Rect2()) as Rect2).is_equal_approx(Rect2(0, 0, 4, 6)), "atlas source pixels index its cropped get_image rather than neighboring sheet cells")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(1, 2, 2, 3)
	descriptor = _describe(sprite)
	_check((descriptor.get("source_rect", Rect2()) as Rect2).is_equal_approx(Rect2(1, 2, 2, 3)), "Sprite2D regions stay relative to the selected atlas image")
	_check(_uv(descriptor, Vector2(0.5, 1.5)).is_equal_approx(Vector2(0.25, 0.5)), "atlas subregions preserve their local draw-to-source mapping")
	sprite.region_enabled = false
	atlas.margin = Rect2(2, 1, 6, 4)
	descriptor = _describe(sprite)
	_check((descriptor.get("bounds", Rect2()) as Rect2).is_equal_approx(Rect2(2, 1, 4, 6)), "atlas margins stay transparent instead of stretching the cropped pixels across them")
	_check(_uv(descriptor, Vector2(2, 1)).is_equal_approx(Vector2.ZERO) and _uv(descriptor, Vector2(6, 7)).is_equal_approx(Vector2.ONE), "atlas margin clipping maps only actual artwork to the cached image")
	sprite.flip_h = true
	sprite.flip_v = true
	descriptor = _describe(sprite)
	_check((descriptor.get("bounds", Rect2()) as Rect2).is_equal_approx(Rect2(4, 3, 4, 6)), "flipped atlas margins move the artwork to its actual rendered bounds")
	_check(_uv(descriptor, Vector2(4, 3)).is_equal_approx(Vector2.ONE) and _uv(descriptor, Vector2(8, 9)).is_equal_approx(Vector2.ZERO), "flipped atlas margins preserve reversed source selection")
	sprite.free()

func _test_visibility_alpha_and_lifetime() -> void:
	var parent := Node2D.new()
	add_child(parent)
	var sprite := _sprite(parent, _texture())
	_register(sprite, Vector2.ZERO)
	parent.modulate.a = 0.5
	parent.self_modulate.a = 0.1
	sprite.modulate.a = 0.4
	sprite.self_modulate.a = 0.25
	_check(is_equal_approx(float(_describe(sprite).get("strength", 0)), 0.05), "coverage inherits parent modulation and leaf self modulation without inheriting parent self modulation")
	parent.visible = false
	_check(_describe(sprite).is_empty(), "hidden ancestors remove foreground coverage")
	parent.visible = true
	sprite.modulate.a = 0.0
	_check(_describe(sprite).is_empty(), "fully faded foreground removes coverage")
	sprite.modulate.a = 1.0
	sprite.scale.x = 0.0
	_check(_describe(sprite).is_empty(), "singular transforms cannot produce a valid inverse coverage mapping")
	sprite.scale.x = 1.0
	var owner: WeakRef = _describe(sprite).get("owner")
	var before := get_tree().get_nodes_in_group(GROUP).size()
	parent.queue_free()
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group(GROUP).size() == before - 1, "streaming out a foreground parent removes its coverage registration")
	_check(owner != null and owner.get_ref() == null, "saved descriptors cannot keep streamed foreground alive")
	_check(_describe(null).is_empty(), "missing foreground owners safely produce no coverage")

func _test_actual_city_trees() -> void:
	var previous_segment := Global.attempt_segment
	Global.attempt_segment = 2
	var parent := Node2D.new()
	parent.position = Vector2(1000, 2000)
	add_child(parent)
	var kit_script := preload("res://scenes/world/buildings/CityBlockKit.gd")
	for domestic: bool in [false, true]:
		var kit := kit_script.new()
		parent.add_child(kit)
		kit.configure(Rect2i(2, 3, 8, 7), 64, [], null, not domestic, PackedVector2Array(), true, {"building_usage": &"row_house" if domestic else &"workshop", "visual_seed": 1})
		var tree := kit.get_node_or_null("CityTemperateTree") as Sprite2D
		_check(tree != null, "actual city planting creates the selected domestic or ordinary foreground tree")
		if tree == null:
			continue
		_check(tree.is_in_group(GROUP), "actual city trees register their foreground lifetime")
		var descriptor := _describe(tree)
		_check(is_equal_approx(float(descriptor.get("front_y", 0)), 2619.0), "actual tree depth uses the measured root in a translated streamed chunk")
		var source_root := Vector2(660, 1060) if domestic else Vector2(650, 1170)
		_check(_uv(descriptor, Vector2(1136, 2619)).is_equal_approx(source_root / 1254.0), "actual ordinary and fruit-tree roots sample their distinct measured source anchors")
		_check(tree.texture.resource_path.ends_with("fruit_tree_overhead_v2.png" if domestic else "temperate_tree.png"), "coverage keeps the selected original tree resource")
		_check(tree.z_index == 1 and kit.z_index == -2, "coverage registration preserves existing tree presentation depth")
		var registered := 0
		for child: Node in kit.get_children():
			if child.is_in_group(GROUP):
				registered += 1
		_check(registered == 1, "low shrubs and foliage shadows do not enter the first foreground class")
	parent.free()
	Global.attempt_segment = previous_segment
