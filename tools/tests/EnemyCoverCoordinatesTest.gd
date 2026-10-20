extends Node2D
## Native preflight for the existing packed renderer. The temporary shader
## exposes world/feet coordinates after first checking the production atlas.

const RendererScript := preload("res://core/systems/enemy_world/EnemyProxyRenderer.gd")
const WorldScript := preload("res://core/systems/enemy_world/EnemyWorld.gd")
const SpawnState := preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const PRODUCTION_SHADER := preload("res://core/systems/enemy_world/EnemyProxyRegion.gdshader")
const TEXTURE_KEY := "enemy_cover_coordinate_fixture"

var _passes := 0
var _failures := 0
var _renderer: EnemyProxyRenderer


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error(message)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_check(false, "EnemyCoverCoordinatesTest requires a native rendering driver")
		_finish()
		return
	get_window().size = Vector2i(640, 360)
	get_window().content_scale_size = Vector2i(640, 360)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_factor = 1.0
	var camera := Camera2D.new()
	camera.position = Vector2(260, 160)
	add_child(camera)
	camera.make_current()
	camera.force_update_scroll()
	var world := WorldScript.new()
	add_child(world)
	_renderer = RendererScript.new()
	_renderer.setup(world)
	add_child(_renderer)
	var texture := _fixture_texture()
	(_renderer.get("_texture_cache") as Dictionary)[TEXTURE_KEY] = texture
	var first := _spawn(world, Vector2(96, 120), Rect2(0, 0, 0.5, 1))
	var second := _spawn(world, Vector2(240, 184), Rect2(0.5, 0, 0.5, 1))
	var actor := Node2D.new()
	actor.position = Vector2(400, 160)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(16, 0, 16, 16)
	sprite.position = Vector2(0, -12)
	sprite.scale = Vector2(3, 2)
	sprite.flip_h = true
	actor.add_child(sprite)
	add_child(actor)
	_renderer.register_actor(actor, sprite)
	sprite.visible = false
	var pixels := await _pixels()
	_check(_renderer.batch_count() == 2, "two separated proxies share one batch beside one actor batch")
	_check(_renderer.debug_instance_transform(first).origin.is_equal_approx(Vector2(96, 120)), "first proxy keeps its published world position")
	_check(_renderer.debug_instance_transform(second).origin.is_equal_approx(Vector2(240, 184)), "second proxy keeps its separate published world position")
	_expect(pixels, Vector2(96, 120), Color.RED, "production shader keeps the first atlas frame")
	_expect(pixels, Vector2(76, 100), Color.BLUE, "production shader keeps the first frame's asymmetric landmark")
	_expect(pixels, Vector2(240, 184), Color.GREEN, "production shader keeps the second atlas frame in the same batch")
	_expect(pixels, Vector2(220, 164), Color.YELLOW, "production shader keeps the second frame's atlas offset")
	_expect(pixels, Vector2(400, 148), Color.GREEN, "scaled offset actor keeps the selected frame")
	_expect(pixels, Vector2(414, 140), Color.YELLOW, "scaled actor's horizontal flip moves its landmark to the right")
	_expect(pixels, Vector2(386, 140), Color.GREEN, "horizontal flip does not leak an adjacent atlas frame")
	_instrument_shader()
	pixels = await _pixels()
	_check_coordinates(pixels, "initial camera")
	camera.position += Vector2(32, -18)
	camera.zoom = Vector2(0.85, 0.85)
	camera.force_update_scroll()
	pixels = await _pixels()
	_check_coordinates(pixels, "translated and zoomed camera")
	_check(_renderer.visible_count() == 3, "coordinate instrumentation leaves the rendered population unchanged")
	actor.queue_free()
	_renderer.queue_free()
	world.queue_free()
	camera.queue_free()
	await get_tree().process_frame
	_finish()


func _fixture_texture() -> ImageTexture:
	var image := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(0, 0, 16, 16), Color.RED)
	image.fill_rect(Rect2i(16, 0, 16, 16), Color.GREEN)
	image.fill_rect(Rect2i(2, 2, 4, 4), Color.BLUE)
	image.fill_rect(Rect2i(18, 2, 4, 4), Color.YELLOW)
	return ImageTexture.create_from_image(image)


func _spawn(world: EnemyWorldService, point: Vector2, region: Rect2) -> int:
	return world.create_enemy(SpawnState.new(&"coordinate", "res://coordinate.tscn", point, 10, 0, 8, 0, 0, {
		"proxy_visual_key": &"coordinate",
		"proxy_texture_path": TEXTURE_KEY,
		"proxy_color": Color.WHITE,
		"proxy_size": Vector2(64, 64),
		"proxy_region": region,
	}))


func _instrument_shader() -> void:
	var source := PRODUCTION_SHADER.code.replace("void vertex() {", """
varying vec2 cover_probe_world;
varying flat float cover_probe_feet_y;
void vertex() {
	cover_probe_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	cover_probe_feet_y = (MODEL_MATRIX * vec4(0.0, -0.5, 0.0, 1.0)).y;
""")
	var final_brace := source.rfind("}")
	source = source.left(final_brace) + """
	COLOR.rgb = vec3(step(96.0, cover_probe_world.x), step(184.0, cover_probe_world.y), step(158.0, cover_probe_feet_y));
}"""
	var shader := Shader.new()
	shader.code = source
	var material := ShaderMaterial.new()
	material.shader = shader
	for value: Variant in (_renderer.get("_batches") as Dictionary).values():
		var batch := value as Dictionary
		(batch["instance"] as MultiMeshInstance2D).material = material


func _check_coordinates(pixels: Image, label: String) -> void:
	# The first proxy straddles x96; its lower frame center is y152. The
	# second straddles y184 with feet y216. Actor center y148 has feet y164.
	_expect(pixels, Vector2(84, 120), Color.BLACK, label + ": first instance has world pixels left of x96 and feet below y158")
	_expect(pixels, Vector2(108, 120), Color.RED, label + ": first instance crosses the world x96 boundary per pixel")
	_expect(pixels, Vector2(240, 172), Color.MAGENTA, label + ": second instance has separate world position and flat feet above y158")
	_expect(pixels, Vector2(240, 196), Color.WHITE, label + ": second instance crosses world y184 without changing feet")
	_expect(pixels, Vector2(400, 140), Color.MAGENTA, label + ": scaled offset actor uses its lower frame center rather than sprite origin")
	_expect(pixels, Vector2(400, 156), Color.MAGENTA, label + ": scaled actor's feet depth remains flat over its frame")


func _pixels() -> Image:
	_renderer.publish()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _expect(pixels: Image, world_point: Vector2, expected: Color, label: String) -> void:
	var canvas_point := get_canvas_transform() * world_point
	var viewport_rect := get_viewport().get_visible_rect()
	var image_point := (canvas_point - viewport_rect.position) * Vector2(pixels.get_size()) / viewport_rect.size
	var point := Vector2i(image_point)
	if not Rect2i(Vector2i.ZERO, pixels.get_size()).has_point(point):
		_check(false, "%s: sample %s is outside image %s" % [label, point, pixels.get_size()])
		return
	var actual := pixels.get_pixelv(point)
	_check(absf(actual.r - expected.r) < 0.06 and absf(actual.g - expected.g) < 0.06 and absf(actual.b - expected.b) < 0.06, "%s (got %s expected %s)" % [label, actual, expected])


func _finish() -> void:
	print("EnemyCoverCoordinatesTest passes=%d failures=%d" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
