extends Node2D

const SpawnState = preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const WorldScript = preload("res://core/systems/enemy_world/EnemyWorld.gd")
const RendererScript = preload("res://core/systems/enemy_world/EnemyProxyRenderer.gd")

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("EnemyProxyRendererVisualTest skipped: real renderer required")
		get_tree().quit(0)
		return
	var world := WorldScript.new()
	add_child(world)
	var renderer := RendererScript.new()
	renderer.setup(world)
	add_child(renderer)
	var handle := world.create_enemy(SpawnState.new(
		&"visual_probe",
		"res://visual_probe.tscn",
		Vector2(64.0, 64.0),
		10.0,
		0.0,
		8.0,
		0,
		0,
		{
			"proxy_visual_key": &"visual_probe",
			"proxy_color": Color(1.0, 0.0, 0.8, 1.0),
			"proxy_size": Vector2(16.0, 16.0),
		},
	))
	renderer.publish(1.0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var gpu_transform := renderer.debug_rendered_instance_transform(handle)
	var gpu_color := renderer.debug_rendered_instance_color(handle)
	_check(gpu_transform.origin.is_equal_approx(Vector2(64.0, 64.0)), "real renderer receives the packed proxy transform")
	_check(
		absf(gpu_color.r - 1.0) < 0.01
		and absf(gpu_color.g) < 0.01
		and absf(gpu_color.b - 0.8) < 0.01
		and absf(gpu_color.a - 1.0) < 0.01,
		"real renderer receives the packed proxy color (got %s)" % gpu_color,
	)
	var image := get_viewport().get_texture().get_image()
	_check(_contains_probe_pixel(image), "real viewport contains visible proxy pixels")

	world.set_representation(handle, 1)
	renderer.publish(1.0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	image = get_viewport().get_texture().get_image()
	_check(not _contains_probe_pixel(image), "materialization removes real proxy pixels without a ghost frame")

	renderer.queue_free()
	world.queue_free()
	await get_tree().process_frame
	print("EnemyProxyRendererVisualTest passes=", _passes, " failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _contains_probe_pixel(image: Image) -> bool:
	if image == null or image.is_empty():
		return false
	var max_x := mini(image.get_width(), 88)
	var max_y := mini(image.get_height(), 88)
	for y in range(40, max_y):
		for x in range(40, max_x):
			var color := image.get_pixel(x, y)
			if color.r > 0.65 and color.b > 0.4 and color.a > 0.5:
				return true
	return false
