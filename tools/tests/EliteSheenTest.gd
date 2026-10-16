extends Node

# Promotion must change the material submitted by the real batch renderer,
# even when the texture is cached, and recycling must remove that effect.
const RendererScript = preload("res://core/systems/enemy_world/EnemyProxyRenderer.gd")
const WorldScript = preload("res://core/systems/enemy_world/EnemyWorld.gd")
const ENEMY = preload("res://core/actors/enemy/enemy.tscn")

class ProxyRoot:
	extends Node2D
	var renderer: Node

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error(message)


func _material(renderer: Node, actor: Node2D) -> ShaderMaterial:
	var entry: Dictionary = renderer.get("_actors").get(actor.get_instance_id(), {})
	var batch: Dictionary = renderer.get("_batches").get(entry.get("batch_key"), {})
	var instance := batch.get("instance") as MultiMeshInstance2D
	return instance.material as ShaderMaterial if instance != null else null


func _enabled(material: ShaderMaterial) -> bool:
	return material != null and material.get_shader_parameter("elite_enabled") == true


func _spawn(spec: EnemySpec = null) -> EnemyActor:
	var actor := ENEMY.instantiate() as EnemyActor
	actor.spec = spec if spec != null else load("res://core/actors/enemy/EnemySpec_Grunt.tres")
	add_child(actor)
	actor.set_physics_process(false)
	return actor


func _run() -> void:
	Global.debug_disable_autosave = true
	var batching: bool = Global.debug_enemy_visual_batching
	var reduced: bool = SettingsManager.get_value(&"accessibility", &"reduced_motion", false)
	var flash: Variant = SettingsManager.get_value(&"accessibility", &"combat_flash", &"full")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	Global.debug_enemy_visual_batching = true
	var world := WorldScript.new()
	add_child(world)
	var proxy_root := ProxyRoot.new()
	proxy_root.z_index = 10  # Same sibling-actor topology as EnemyProxyRoot.
	proxy_root.add_to_group(&"enemy_proxy_root")
	var renderer := RendererScript.new()
	renderer.setup(world)
	proxy_root.renderer = renderer
	proxy_root.add_child(renderer)
	add_child(proxy_root)
	var ordinary := _spawn()
	var promoted := _spawn()
	renderer.publish()
	_check(_material(renderer, ordinary) == _material(renderer, promoted), "ordinary peers share their drawing material")
	promoted.apply_elite_modifiers([])
	renderer.publish()
	var elite_material := _material(renderer, promoted)
	_check(_enabled(elite_material), "promotion submits the elite surface even with an already cached texture")
	_check(not _enabled(_material(renderer, ordinary)), "an elite does not give its ordinary texture peers a sheen")
	_check(elite_material != _material(renderer, ordinary), "elite and ordinary instances are drawn with distinct shared materials")
	_check(renderer.visible_count() == 2, "promotion draws exactly one body per actor")
	var sprite := promoted.get_node("Sprite2D") as Sprite2D
	_check(_enabled(sprite.material as ShaderMaterial), "elite keeps the same surface in scenes without a batch renderer")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	_check(elite_material != null and elite_material.get_shader_parameter("glint_motion") == false, "reduced motion stops the batch glint while retaining its elite surface")
	var fallback := sprite.material as ShaderMaterial
	_check(fallback != null and fallback.get_shader_parameter("glint_motion") == false, "reduced motion also stops the fallback sprite glint")
	SettingsManager.set_value(&"accessibility", &"combat_flash", &"off", false)
	_check(elite_material != null and elite_material.get_shader_parameter("hit_flash_strength") == 0.0, "elite batch respects combat flashes off")
	promoted.call("_on_pool_recycle")
	promoted.call("_reset_for_pool_obtain", false)
	promoted.set_physics_process(false)
	renderer.publish()
	_check(not _enabled(_material(renderer, promoted)), "pooled elite reappears as an ordinary body without a stale sheen")
	_check(sprite.material == null, "pool reuse restores the sprite's previous material")
	_check(renderer.visible_count() == 2, "pool reuse leaves no duplicate elite body")
	ordinary.queue_free()
	promoted.queue_free()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await _check_rendered_surface(renderer)
	proxy_root.queue_free()
	world.queue_free()
	SettingsManager.set_value(&"accessibility", &"reduced_motion", reduced, false)
	SettingsManager.set_value(&"accessibility", &"combat_flash", flash, false)
	Global.debug_enemy_visual_batching = batching
	await get_tree().process_frame
	print("EliteSheenTest passes=%d failures=%d" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _pixels(renderer: Node) -> Image:
	renderer.publish()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _patch_difference(a: Image, b: Image, origin: Vector2i) -> float:
	var difference := 0.0
	for y in range(origin.y - 32, origin.y + 32):
		for x in range(origin.x - 32, origin.x + 32):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			difference += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
	return difference


func _check_rendered_surface(renderer: Node) -> void:
	get_window().size = Vector2i(640, 360)
	get_window().content_scale_size = Vector2i(640, 360)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_factor = 1.0
	# A dark asymmetric silhouette beside an opaque green atlas neighbour
	# catches lost frame bounds, unwanted alpha and incorrect local sampling.
	var image := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(2, 3, 8, 10), Color(0.16, 0.16, 0.16, 1.0))
	image.fill_rect(Rect2i(16, 0, 16, 16), Color.GREEN)
	var spec := EnemySpec.new()
	spec.sprite_texture = ImageTexture.create_from_image(image)
	spec.sprite_scale = Vector2(4, 4)
	var regular := _spawn(spec)
	var elite := _spawn(spec)
	var fallback := _spawn(spec)
	regular.position = Vector2(160, 160)
	elite.position = Vector2(320, 160)
	fallback.position = Vector2(480, 160)
	for actor in [regular, elite, fallback]:
		var spr := actor.get_node("Sprite2D") as Sprite2D
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, 16, 16)
	# Role art uses AtlasTexture instead of Sprite2D.region_enabled. Both
	# must produce the same frame-local surface in fallback scenes.
	var atlas := AtlasTexture.new()
	atlas.atlas = spec.sprite_texture
	atlas.region = Rect2(0, 0, 16, 16)
	atlas.filter_clip = true
	var fallback_sprite := fallback.get_node("Sprite2D") as Sprite2D
	fallback_sprite.texture = atlas
	fallback_sprite.region_enabled = false
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	elite.apply_elite_modifiers([])
	fallback.apply_elite_modifiers([])
	fallback.call("_unregister_batched_visual")
	var still := await _pixels(renderer)
	still.save_png("res://.godot/elite-sheen-fixture.png")
	var edge := still.get_pixel(296, 160)
	var centre := still.get_pixel(312, 160)
	print("EliteSheen pixels: edge=%s centre=%s fallback=%s viewport=%s" % [edge, centre, still.get_pixel(456, 160), still.get_size()])
	_check(edge.r > 0.5 and edge.g > 0.35 and edge.b < edge.g, "real elite silhouette has a persistent warm edge")
	_check(centre.r < 0.3 and centre.g < 0.3, "steady elite surface retains the dark interior artwork")
	_check(still.get_pixel(136, 160).r < 0.3, "ordinary texture peers do not acquire the bright edge")
	var outside := still.get_pixel(284, 160)
	var background := still.get_pixel(124, 160)
	_check(outside.is_equal_approx(background), "elite effect does not fill transparent pixels or sample the adjacent atlas role")
	var fallback_edge := still.get_pixel(456, 160)
	_check(absf(fallback_edge.r - edge.r) < 0.03 and absf(fallback_edge.g - edge.g) < 0.03, "fallback sprite and batched actor render the same atlas edge")
	await get_tree().create_timer(0.3).timeout
	var still_later := await _pixels(renderer)
	_check(_patch_difference(still, still_later, Vector2i(320, 160)) < 0.1, "reduced motion leaves the rendered elite steady")
	SettingsManager.set_value(&"accessibility", &"reduced_motion", false, false)
	var moving := await _pixels(renderer)
	var motion_difference := 0.0
	var ordinary_steady := true
	# Observe a complete 2.6-second sweep regardless of the starting phase.
	for _sample in range(12):
		await get_tree().create_timer(0.25).timeout
		var later := await _pixels(renderer)
		motion_difference = maxf(motion_difference, _patch_difference(moving, later, Vector2i(320, 160)))
		ordinary_steady = ordinary_steady and _patch_difference(moving, later, Vector2i(160, 160)) < 0.1
	_check(ordinary_steady, "ordinary body remains steady while the elite glint travels")
	_check(motion_difference > 5.0, "the real shader produces a travelling glint")
	var sprite := elite.get_node("Sprite2D") as Sprite2D
	sprite.flip_h = true
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	var flipped := await _pixels(renderer)
	_check(flipped.get_pixel(343, 160).r > 0.5 and flipped.get_pixel(296, 160).is_equal_approx(background), "horizontal flipping retains the elite silhouette and its frame-local edge")
	for actor in [regular, elite, fallback]:
		actor.queue_free()
	await get_tree().process_frame
