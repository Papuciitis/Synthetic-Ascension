extends Node2D
## Real batch consumers must apply cover per pixel after their own atlas,
## elite and damage presentation, without changing eligibility or world state.

const COVER_PATH := "res://core/systems/world/visibility/WorldCover.gd"
const RendererScript := preload("res://core/systems/enemy_world/EnemyProxyRenderer.gd")
const WorldScript := preload("res://core/systems/enemy_world/EnemyWorld.gd")
const SpawnState := preload("res://core/systems/enemy_world/EnemySpawnState.gd")
const Types := preload("res://core/systems/enemy_world/EnemyWorldTypes.gd")
const ENEMY := preload("res://core/actors/enemy/enemy.tscn")
const ROOF := preload("res://scenes/world/buildings/RoofOverlay.tscn")
const TEXTURE_KEY := "enemy_cover_render_fixture"

class ProxyRoot:
	extends Node2D
	var renderer: Node

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
	if not ResourceLoader.exists(COVER_PATH):
		_check(false, "enemy cover requires the shared WorldCover service")
		_finish()
		return
	if DisplayServer.get_name() == "headless":
		_check(false, "EnemyCoverRenderTest requires a native rendering driver")
		_finish()
		return
	var old_batching: bool = Global.debug_enemy_visual_batching
	var old_motion: bool = SettingsManager.get_value(&"accessibility", &"reduced_motion", false)
	var old_flash: Variant = SettingsManager.get_value(&"accessibility", &"combat_flash", &"full")
	Global.debug_enemy_visual_batching = true
	SettingsManager.set_value(&"accessibility", &"reduced_motion", true, false)
	SettingsManager.set_value(&"accessibility", &"combat_flash", &"off", false)
	get_window().size = Vector2i(720, 360)
	get_window().content_scale_size = Vector2i(720, 360)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_factor = 1.0
	var background := ColorRect.new()
	background.color = Color(0.12, 0.14, 0.16)
	background.size = Vector2(720, 360)
	background.z_index = -100
	add_child(background)
	var roof := _roof_fixture()
	var world := WorldScript.new()
	add_child(world)
	var proxy_root := ProxyRoot.new()
	proxy_root.z_index = 10
	proxy_root.add_to_group(&"enemy_proxy_root")
	_renderer = RendererScript.new()
	proxy_root.renderer = _renderer
	proxy_root.add_child(_renderer)
	add_child(proxy_root)
	_renderer.setup(world)
	var texture := _fixture_texture()
	(_renderer.get("_texture_cache") as Dictionary)[TEXTURE_KEY] = texture
	var behind := _spawn_proxy(world, Vector2(128, 144), Rect2(0, 0, 0.5, 1))
	var front := _spawn_proxy(world, Vector2(280, 176), Rect2(0.5, 0, 0.5, 1))
	var elite_proxy := _spawn_proxy(world, Vector2(664, 144), Rect2(0, 0, 0.5, 1), true)
	var ordinary := _spawn_actor(texture, Vector2(432, 144), false)
	var elite := _spawn_actor(texture, Vector2(552, 144), true)
	var initial_counts := world.get_debug_counters()
	var initial_health := world.get_health(behind)
	roof._set_alpha(0)
	var clear := await _pixels()
	var clear_proxy := _sample(clear, Vector2(144, 144))
	var clear_ordinary := _sample(clear, Vector2(432, 144))
	var clear_elite := _sample(clear, Vector2(552, 144))
	var clear_elite_proxy := _sample(clear, Vector2(664, 144))
	_check(clear_proxy.r > 0.9 and clear_proxy.g < 0.05, "uncovered proxy renders its authored red atlas frame")
	_check(clear_ordinary.g > 0.9 and clear_ordinary.r < 0.05, "uncovered materialized actor renders its selected green frame")
	_check(_renderer.visible_count() == 5, "fixture renders ordinary and elite proxies alongside two materialized bodies")
	var published_transform := _renderer.debug_instance_transform(behind)
	roof._set_alpha(1)
	var covered := await _pixels(false)
	_check(_renderer.debug_instance_transform(behind).is_equal_approx(published_transform), "retained half-rate proxy keeps its existing pose")
	_assert_dark(_sample(covered, Vector2(144, 144)), "retained proxy receives live opaque-roof coverage")
	_check(_distance(_sample(covered, Vector2(112, 144)), _sample(clear, Vector2(112, 144))) < 0.04, "exposed pixels of the same proxy retain authored colour")
	_check(_distance(_sample(covered, Vector2(280, 160)), _sample(clear, Vector2(280, 160))) < 0.04, "front-depth proxy stays normal where its artwork overlaps the roof")
	_assert_dark(_sample(covered, Vector2(432, 144)), "ordinary materialized batch receives coverage")
	_assert_dark(_sample(covered, Vector2(552, 144)), "elite materialized batch receives coverage after its own surface")
	_assert_dark(_sample(covered, Vector2(664, 144)), "elite data-only batch receives coverage during a representation shortage")
	_check(_distance(_sample(covered, Vector2(140, 140)), _sample(covered, Vector2(160, 100))) < 0.04, "cover never fills a transparent hole in the enemy's atlas frame")
	roof._set_alpha(0.4)
	var partial := await _pixels(false)
	var partly_covered := _sample(partial, Vector2(144, 144))
	_check(partly_covered.r > _sample(covered, Vector2(144, 144)).r + 0.08 and partly_covered.r < clear_proxy.r - 0.08, "partial roof opacity produces partial silhouette strength")
	roof._set_alpha(0)
	var restored := await _pixels(false)
	_check(_distance(_sample(restored, Vector2(144, 144)), clear_proxy) < 0.04, "cutaway roof restores the proxy's current authored presentation")
	_check(_distance(_sample(restored, Vector2(432, 144)), clear_ordinary) < 0.04, "cutaway restores ordinary materialized modulation")
	_check(_distance(_sample(restored, Vector2(552, 144)), clear_elite) < 0.04, "cutaway restores the existing elite surface")
	_check(_distance(_sample(restored, Vector2(664, 144)), clear_elite_proxy) < 0.04, "cutaway restores the data-only elite surface")
	await _check_flashes(roof, behind, elite_proxy, elite)
	SettingsManager.set_value(&"accessibility", &"combat_flash", &"off", false)
	roof._set_alpha(1)
	ordinary.is_elite = true
	var promoted := await _pixels()
	_assert_dark(_sample(promoted, Vector2(432, 144)), "live ordinary-to-elite batch switch keeps coverage")
	_check(_renderer.visible_count() == 5, "elite surface promotion draws exactly one body")
	ordinary.set_meta(&"__in_pool", true)
	await _pixels()
	_check(_renderer.visible_count() == 4, "pooled actor leaves the covered drawing population")
	ordinary.remove_meta(&"__in_pool")
	ordinary.is_elite = false
	_renderer.reset_actor_snapshot(ordinary)
	var reused := await _pixels()
	_assert_dark(_sample(reused, Vector2(432, 144)), "pooled actor reuse restores one covered ordinary body")
	_check(_renderer.visible_count() == 5, "pool reuse leaves no duplicate body")
	roof.queue_free()
	await get_tree().process_frame
	var streamed := await _pixels(false)
	_check(_distance(_sample(streamed, Vector2(144, 144)), clear_proxy) < 0.04, "streaming removal clears retained proxy cover")
	_check(_distance(_sample(streamed, Vector2(432, 144)), clear_ordinary) < 0.04, "streaming removal clears materialized cover")
	var final_counts := world.get_debug_counters()
	_check(int(final_counts.get("logical", -1)) == int(initial_counts.get("logical", -2)) and int(final_counts.get("data_only", -1)) == int(initial_counts.get("data_only", -2)), "coverage changes preserve authoritative enemy-world population")
	_check(world.get_position(behind).is_equal_approx(Vector2(128, 144)) and world.get_position(front).is_equal_approx(Vector2(280, 176)) and is_equal_approx(world.get_health(behind), initial_health), "coverage changes preserve authoritative enemy positions and health")
	ordinary.queue_free()
	elite.queue_free()
	proxy_root.queue_free()
	world.queue_free()
	background.queue_free()
	await get_tree().process_frame
	SettingsManager.set_value(&"accessibility", &"reduced_motion", old_motion, false)
	SettingsManager.set_value(&"accessibility", &"combat_flash", old_flash, false)
	Global.debug_enemy_visual_batching = old_batching
	_finish()


func _roof_fixture() -> RoofOverlay:
	var roof := ROOF.instantiate() as RoofOverlay
	add_child(roof)
	roof.footprint_outline_px = PackedVector2Array([Vector2(128, 32), Vector2(704, 32), Vector2(704, 192), Vector2(128, 192)])
	var poly := roof.get_node("RoofPoly") as Polygon2D
	poly.polygon = PackedVector2Array([Vector2(128, 80), Vector2(704, 80), Vector2(704, 180), Vector2(128, 180)])
	poly.color = Color(0.21, 0.24, 0.28)
	poly.z_index = -1
	(roof.get_node("FrontEdge") as Line2D).visible = false
	return roof


func _fixture_texture() -> ImageTexture:
	var image := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(0, 0, 16, 16), Color.RED)
	image.fill_rect(Rect2i(16, 0, 16, 16), Color.GREEN)
	image.fill_rect(Rect2i(10, 6, 2, 2), Color.TRANSPARENT)
	return ImageTexture.create_from_image(image)


func _spawn_proxy(world: EnemyWorldService, point: Vector2, region: Rect2, elite: bool = false) -> int:
	return world.create_enemy(SpawnState.new(&"covered_proxy", "res://covered_proxy.tscn", point, 10, 0, 8, 0, Types.Flags.ELITE if elite else 0, {
		"proxy_visual_key": &"covered_proxy",
		"proxy_texture_path": TEXTURE_KEY,
		"proxy_color": Color.WHITE,
		"proxy_size": Vector2(64, 64),
		"proxy_region": region,
	}))


func _spawn_actor(texture: Texture2D, point: Vector2, elite: bool) -> EnemyActor:
	var spec := EnemySpec.new()
	spec.sprite_texture = texture
	spec.sprite_scale = Vector2(4, 4)
	var actor := ENEMY.instantiate() as EnemyActor
	actor.spec = spec
	actor.position = point
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(actor)
	actor.is_elite = elite
	var sprite := actor.get_node("Sprite2D") as Sprite2D
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, 16, 16) if elite else Rect2(16, 0, 16, 16)
	sprite.modulate = Color(1, 0.7, 0.3) if elite else Color.WHITE
	_renderer.register_actor(actor, sprite)
	sprite.visible = false
	return actor


func _check_flashes(roof: RoofOverlay, handle: int, elite_handle: int, elite: EnemyActor) -> void:
	for setting: StringName in [&"full", &"reduced", &"off"]:
		SettingsManager.set_value(&"accessibility", &"combat_flash", setting, false)
		roof._set_alpha(1)
		_renderer.flash_handle(handle)
		_renderer.flash_handle(elite_handle)
		_renderer.flash_actor(elite)
		var pixels := await _pixels()
		_assert_dark(_sample(pixels, Vector2(144, 144)), "%s proxy flash still composes beneath quiet cover" % setting)
		_assert_dark(_sample(pixels, Vector2(552, 144)), "%s elite flash still composes beneath quiet cover" % setting)
		_assert_dark(_sample(pixels, Vector2(664, 144)), "%s data-only elite flash still composes beneath quiet cover" % setting)
		var exposed := _sample(pixels, Vector2(112, 144))
		if setting == &"full":
			_check(exposed.r > 0.9 and exposed.g > 0.9 and exposed.b > 0.9, "full flash remains white on exposed enemy pixels")
		elif setting == &"reduced":
			_check(exposed.r > 0.9 and exposed.g > 0.25 and exposed.g < 0.6, "reduced flash retains its intermediate exposed intensity")
		else:
			_check(exposed.r > 0.9 and exposed.g < 0.05, "flashes off leaves exposed enemy pixels authored")
	SettingsManager.set_value(&"accessibility", &"combat_flash", &"full", false)
	roof._set_alpha(0)
	_renderer.flash_handle(handle)
	var clear_flash := await _pixels()
	var current := _sample(clear_flash, Vector2(144, 144))
	_check(current.r > 0.9 and current.g > 0.9 and current.b > 0.9, "clearing cover restores a live full flash rather than resetting the enemy to plain colour")


func _pixels(include_proxies: bool = true) -> Image:
	_renderer.publish(1, include_proxies)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _sample(pixels: Image, world_point: Vector2) -> Color:
	var viewport_rect := get_viewport().get_visible_rect()
	var canvas_point := get_canvas_transform() * world_point
	var point := Vector2i((canvas_point - viewport_rect.position) * Vector2(pixels.get_size()) / viewport_rect.size)
	if not Rect2i(Vector2i.ZERO, pixels.get_size()).has_point(point):
		_check(false, "cover sample %s is outside native image %s" % [point, pixels.get_size()])
		return Color.MAGENTA
	return pixels.get_pixelv(point)


func _assert_dark(color: Color, label: String) -> void:
	_check(maxf(color.r, maxf(color.g, color.b)) < 0.6 and color.b > 0.04, "%s (got %s)" % [label, color])


func _distance(first: Color, second: Color) -> float:
	return absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)


func _finish() -> void:
	print("EnemyCoverRenderTest passes=%d failures=%d" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
