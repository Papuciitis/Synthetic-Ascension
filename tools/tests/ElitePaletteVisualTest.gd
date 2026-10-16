extends "res://tools/tests/EliteSheenTest.gd"

# Different modifier colours must coexist inside one elite texture batch.
# Real pixels catch a shared colour uniform or a remaining gold-only glint.
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("ElitePaletteVisualTest requires a real rendering driver")
		get_tree().quit(1)
		return
	Global.debug_disable_autosave = true
	var previous_batching := Global.debug_enemy_visual_batching
	var previous_motion: bool = SettingsManager.get_value(&"accessibility", &"reduced_motion", false)
	Global.debug_enemy_visual_batching = true
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	get_window().size = Vector2i(768, 320)
	get_window().content_scale_size = Vector2i(768, 320)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_factor = 1.0
	var world := WorldScript.new()
	add_child(world)
	var proxy_root := ProxyRoot.new()
	proxy_root.z_index = 10
	proxy_root.add_to_group(&"enemy_proxy_root")
	var renderer := RendererScript.new()
	renderer.setup(world)
	proxy_root.renderer = renderer
	proxy_root.add_child(renderer)
	add_child(proxy_root)
	var fixture := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	fixture.fill(Color.TRANSPARENT)
	fixture.fill_rect(Rect2i(2, 2, 12, 12), Color(0.12, 0.12, 0.12, 1.0))
	var spec := EnemySpec.new()
	spec.sprite_texture = ImageTexture.create_from_image(fixture)
	spec.sprite_scale = Vector2(4, 4)
	var actors: Array[EnemyActor] = []
	var modifiers: Array[StringName] = [&"armoured", &"vampiric", &"shielded", &"splitting", &"fast", &"", &"shielded"]
	for index in range(modifiers.size()):
		var actor := _spawn(spec)
		actor.position = Vector2(100 + index * 100, 100)
		var ids: Array[StringName] = []
		if modifiers[index] != &"":
			ids.append(modifiers[index])
		actor.apply_elite_modifiers(ids)
		actor.set_physics_process(false)
		var spr := actor.get_node("Sprite2D") as Sprite2D
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# This fixture isolates the body surface. Mark/ring rendering has its
		# own integration suite and could otherwise cover the sample pixels.
		for child in actor.get_children():
			if child is VFX_EliteModifierMark:
				child.visible = false
				child.set_process(false)
		actors.append(actor)
	actors[-1].call("_unregister_batched_visual")
	var still := await _pixels(renderer)
	var edge_colours: Array[Color] = []
	for index in range(actors.size()):
		edge_colours.append(still.get_pixel(76 + index * 100, 100))
	_assert_families(edge_colours, "steady edge")
	_check(_material(renderer, actors[0]) == _material(renderer, actors[1]) and _material(renderer, actors[1]) == _material(renderer, actors[2]), "different modifier families share one material without colour leaking between enemies")
	_check(edge_colours[2].is_equal_approx(edge_colours[6]), "fallback sprite matches the batched cyan family")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	var brightest: Array[Color] = []
	var light: Array[float] = []
	for _index in range(actors.size()):
		brightest.append(Color.BLACK)
		light.append(0.0)
	for _sample in range(12):
		await get_tree().create_timer(0.25).timeout
		var pixels := await _pixels(renderer)
		for index in range(actors.size()):
			var colour := pixels.get_pixel(100 + index * 100, 100)
			var intensity := colour.r + colour.g + colour.b
			if intensity > light[index]:
				light[index] = intensity
				brightest[index] = colour
	_assert_families(brightest, "travelling glint")
	for index in range(5):
		_check(light[index] > 0.6, "modifier %s has a visible glint through its dark interior" % modifiers[index])
	print("ElitePalette edge colours: ", edge_colours)
	print("ElitePalette glint colours: ", brightest)
	for actor in actors:
		actor.queue_free()
	await get_tree().process_frame
	proxy_root.queue_free()
	world.queue_free()
	SettingsManager.set_value(&"accessibility", &"reduced_motion", previous_motion, false)
	Global.debug_enemy_visual_batching = previous_batching
	await get_tree().process_frame
	print("ElitePaletteVisualTest passes=%d failures=%d" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _assert_families(colours: Array[Color], description: String) -> void:
	_check(colours[0].b > colours[0].r and colours[0].g > colours[0].r, "armoured %s reads as cool steel" % description)
	_check(colours[1].r > colours[1].g * 1.25 and colours[1].r > colours[1].b * 1.2, "vampiric %s reads as blood red" % description)
	_check(colours[2].b > colours[2].r * 1.15 and colours[2].g > colours[2].r * 1.1, "shielded %s reads as cyan" % description)
	_check(colours[3].g > colours[3].r * 1.05 and colours[3].g > colours[3].b * 1.2, "splitting %s reads as green" % description)
	_check(colours[4].r > colours[4].b * 1.1 and colours[4].g > colours[4].b * 1.1, "fast %s reads as yellow" % description)
	_check(colours[5].r > colours[5].g and colours[5].g > colours[5].b, "plain elite %s retains its gold family" % description)
