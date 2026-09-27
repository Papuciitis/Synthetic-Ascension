extends Node
## Renders the hub square to PNGs (needs a display, not --headless):
## an overview of the whole square and a gameplay-zoom shot at the arrival.
## Run: <godot> --path . res://tools/dev/HubScreenshotProbe.tscn -- --out=/abs/dir

const HUB_WORLD := preload("res://scenes/hub/HubWorld.tscn")


func _ready() -> void:
	var out_dir := "/tmp"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	# A mid-run hub: the attempt started, ~6k Followers (17 people).
	if not Global.attempt_active:
		Global.start_new_attempt()
	SaveManager.current_save = null
	Global.followers = 6000
	var hub: HubWorld = HUB_WORLD.instantiate()
	hub.crowd_seed = 7
	hub.departure_scene_change_enabled = false
	add_child(hub)
	for i in range(30):
		await get_tree().process_frame
	var camera := hub._player.get_node_or_null("Camera2D") as Camera2D
	await _shot("%s/hub_play.png" % out_dir)
	hub._player.global_position = hub._cell(16, 8.5)
	for i in range(20):
		await get_tree().process_frame
	await _shot("%s/hub_center.png" % out_dir)
	# The Quiet Alcove, where Beka keeps her bed.
	hub._player.global_position = hub._cell(6.5, 12.6)
	for i in range(20):
		await get_tree().process_frame
	await _shot("%s/hub_alcove.png" % out_dir)
	if camera != null:
		camera.limit_left = -100000
		camera.limit_right = 100000
		camera.limit_top = -100000
		camera.limit_bottom = 100000
		camera.position_smoothing_enabled = false
		camera.zoom = Vector2.ONE * 0.52
		hub._player.global_position = hub._cell(16, 9.5)
	for i in range(20):
		await get_tree().process_frame
	await _shot("%s/hub_overview.png" % out_dir)
	# The same overview with every blocker drawn where the FEET meet it
	# (collision is authored in feet space on a lifted body).
	var overlay := CollisionOverlay.new()
	overlay.body = hub._ground_body
	overlay.lift = Vector2(0.0, HubWorld.FEET)
	overlay.z_index = 200
	hub.add_child(overlay)
	for i in range(4):
		await get_tree().process_frame
	await _shot("%s/hub_collision.png" % out_dir)
	get_tree().quit(0)


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("HubScreenshotProbe -> ", path)


class CollisionOverlay extends Node2D:
	var body: StaticBody2D = null
	var lift := Vector2.ZERO

	func _draw() -> void:
		if body == null:
			return
		var fill := Color(1.0, 0.1, 0.6, 0.35)
		var edge := Color(1.0, 0.2, 0.7, 0.9)
		for child in body.get_children():
			var at: Vector2 = body.position + lift + (child as Node2D).position
			if child is CollisionPolygon2D:
				var pts := PackedVector2Array()
				for p in (child as CollisionPolygon2D).polygon:
					pts.append(at + p)
				draw_colored_polygon(pts, fill)
			elif child is CollisionShape2D:
				var shape := (child as CollisionShape2D).shape
				if shape is CircleShape2D:
					draw_circle(at, (shape as CircleShape2D).radius, fill)
					draw_arc(at, (shape as CircleShape2D).radius, 0, TAU, 24, edge, 2.0)
				elif shape is RectangleShape2D:
					var size: Vector2 = (shape as RectangleShape2D).size
					draw_rect(Rect2(at - size * 0.5, size), fill)
					draw_rect(Rect2(at - size * 0.5, size), edge, false, 2.0)
