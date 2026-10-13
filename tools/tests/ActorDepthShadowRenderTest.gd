extends Node2D

const Renderer = preload("res://core/systems/enemy_world/EnemyProxyRenderer.gd")
const World = preload("res://core/systems/enemy_world/EnemyWorld.gd")

var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	print("PASS: " if condition else "FAIL: ", message)
	if not condition:
		_failures += 1


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("ActorDepthShadowRenderTest skipped: real renderer required")
		get_tree().quit()
		return
	var background := ColorRect.new()
	background.color = Color(0.72, 0.70, 0.60)
	background.size = Vector2(1920, 1080)
	background.z_index = -100
	add_child(background)
	var world := World.new()
	add_child(world)
	var renderer := Renderer.new()
	renderer.setup(world)
	add_child(renderer)
	var actor := Node2D.new()
	actor.position = Vector2(160, 100)
	var sprite := Sprite2D.new()
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 1.0, 0.0, 1.0))
	image.fill_rect(Rect2i(16, 0, 20, 60), Color(1.0, 0.0, 0.0, 1.0))
	var atlas := AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(image)
	atlas.region = Rect2(16, 0, 20, 60)
	sprite.texture = atlas
	actor.add_child(sprite)
	add_child(actor)
	renderer.register_actor(actor, sprite)
	sprite.visible = false
	renderer.publish()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var pixels := get_viewport().get_texture().get_image()
	var body := _sample(pixels, Vector2(160, 100))
	_check(body.r > 0.8 and body.g < 0.1, "static AtlasTexture renders only its chosen red role")
	var cast := _sample(pixels, Vector2(132, 149))
	_check(cast.r < 0.60 and cast.g < 0.60, "hardware renderer draws the cast silhouette southwest of its feet")
	var clear := _sample(pixels, Vector2(200, 149))
	_check(clear.r > 0.65 and clear.g > 0.65, "shadow stays out of the opposite light direction")
	renderer.flash_actor(actor)
	renderer.publish()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	pixels = get_viewport().get_texture().get_image()
	var flashed_cast := _sample(pixels, Vector2(132, 149))
	_check(flashed_cast.r < 0.60 and flashed_cast.g < 0.60, "combat hit flash leaves the cast shadow dark")
	var output := OS.get_environment("TEMP").path_join("actor_depth_shadow_render.png")
	pixels.save_png(output)
	print("ActorDepthShadowRenderTest failures=", _failures, " image=", output)
	get_tree().quit(1 if _failures > 0 else 0)


func _sample(pixels: Image, world_point: Vector2) -> Color:
	# Saved window settings may override the requested capture dimensions.
	var rect := get_viewport().get_visible_rect()
	var point := (world_point - rect.position) * Vector2(pixels.get_size()) / rect.size
	return pixels.get_pixelv(Vector2i(point))
