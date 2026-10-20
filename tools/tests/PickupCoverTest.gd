extends Node2D
## Catches lost lock/polarity modulation, replaced atlas textures, stale ground
## depth on protected drops, and an uncovered health glow over a covered icon.

const ADAPTER_PATH := "res://core/systems/world/visibility/PickupCover.gd"
const ITEM := preload("res://scenes/world/pickups/ItemPickup.tscn")
const HEALTH := preload("res://scenes/world/pickups/HealthPickup.tscn")
const ROOF := preload("res://scenes/world/buildings/RoofOverlay.tscn")
const PAPER := Color(0.64, 0.64, 0.64, 1.0)

var _passes := 0
var _failures := 0


func _enter_tree() -> void:
	Global.debug_disable_autosave = true
	SaveManager.current_save = null
	SaveManager.current_slot = -1
	SaveManager.save_dir = "user://tests/pickup_cover/"
	PerformanceFlightRecorder.report_directory = SaveManager.save_dir + "performance/"
	BalanceRecorder.report_directory = SaveManager.save_dir + "balance/"
	PerformanceFlightRecorder.set_enabled(false)
	BalanceRecorder.set_enabled(false)


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _atlas() -> AtlasTexture:
	var image := Image.create(48, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color.GREEN)
	image.fill_rect(Rect2i(8, 4, 24, 16), Color(0.95, 0.24, 0.16, 1.0))
	image.fill_rect(Rect2i(18, 10, 4, 4), Color.TRANSPARENT)
	var atlas := AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(image)
	atlas.region = Rect2(8, 4, 24, 16)
	atlas.filter_clip = true
	return atlas


func _item(texture: Texture2D, polarity: int, at: Vector2, locked: bool = false, exploration: bool = false) -> ItemPickup:
	var data := ItemData.new()
	data.id = "pickup_cover_fixture"
	data.display_name = "Pickup cover fixture"
	data.icon = texture
	data.equip_slot = ItemData.EquipSlot.RING
	var pickup := ITEM.instantiate() as ItemPickup
	pickup.item_instance = ItemInstance.from_roll(data, 0, polarity, 0.4, false)
	pickup.pickup_delay = 60.0 if locked else 0.0
	pickup.drop_pickup_delay = 0.0
	pickup.persistent_world_drop = true
	pickup.is_exploration_loot = exploration
	pickup.position = at
	add_child(pickup)
	# The legacy mesh under an equipment pickup is outside the icon contract.
	(pickup.get_node("Glow") as Sprite2D).visible = false
	return pickup


func _run() -> void:
	var writes := SaveManager.debug_save_writes
	_check(ResourceLoader.exists(ADAPTER_PATH), "eligible pickup icons have a cover adapter")
	if not ResourceLoader.exists(ADAPTER_PATH):
		_finish()
		return
	var adapter_script := load(ADAPTER_PATH) as GDScript
	var adapter: RefCounted = adapter_script.new() as RefCounted
	_check(adapter.has_method("configure") and adapter.has_method("update"), "pickup cover accepts the live icon and refreshes its ground depth")
	if not adapter.has_method("configure") or not adapter.has_method("update"):
		_finish()
		return
	var texture := _atlas()
	var blessed := _item(texture, ItemInstance.Polarity.POS, Vector2(140, 140), true, true)
	var cursed := _item(texture, ItemInstance.Polarity.NEG, Vector2(220, 140))
	await get_tree().process_frame
	_check(blessed.icon_sprite.material is ShaderMaterial and cursed.icon_sprite.material is ShaderMaterial, "both ordinary and exploration equipment wire the real icon adapter")
	_check(blessed.icon_sprite.texture == texture and cursed.icon_sprite.texture == texture, "cover preserves native atlas resource and crop")
	_check(blessed.icon_sprite.modulate.is_equal_approx(Color(0.85, 1.0, 1.0, 0.55)), "covered presentation preserves the locked POS tint and alpha")
	_check(cursed.icon_sprite.modulate.is_equal_approx(Color(1.0, 0.75, 0.8, 1.0)), "NEG equipment retains its authored polarity tint")
	_check(blessed.vfx._locked and blessed.vfx._exploration, "coverage never unlocks equipment or removes its exploration marker")
	blessed.vfx.set_locked(false)
	_check(blessed.icon_sprite.modulate.is_equal_approx(Color(0.85, 1.0, 1.0, 1.0)), "unlock restores the preexisting POS presentation")
	var material := cursed.icon_sprite.material
	cursed.icon_sprite.visible = false
	cursed._process(0.0)
	_check(not cursed.icon_sprite.visible, "cover cannot reveal an explicitly hidden icon")
	cursed.icon_sprite.visible = true
	cursed._process(0.0)
	_check(cursed.icon_sprite.material == material, "refresh reuses the persistent icon material")
	cursed.position.y = 260.0
	cursed.icon_sprite.position.y = -120.0
	cursed._process(0.0)
	_check(is_equal_approx(float((material as ShaderMaterial).get_shader_parameter("world_cover_feet_y")), 260.0), "protected pickups refresh ground depth before the magnet's early return")
	cursed.position.y = 140.0
	cursed.icon_sprite.position.y = 0.0
	var owned := Sprite2D.new()
	var authored := CanvasItemMaterial.new()
	owned.material = authored
	cursed.add_child(owned)
	adapter.call("configure", cursed, owned)
	adapter.call("update")
	_check(owned.material == authored, "an existing material owner is preserved")
	var health := HEALTH.instantiate() as HealthPickup
	health.position = Vector2(300, 140)
	health.pickup_delay = 60.0
	add_child(health)
	await get_tree().process_frame
	_check(health.icon.material is ShaderMaterial and health.glow.material is ShaderMaterial, "healing icon and its duplicate glow both receive cover presentation")
	_check(health.glow.modulate.is_equal_approx(Color(1.0, 0.16, 0.22, 0.28)), "health glow keeps its original tint and alpha")
	if DisplayServer.get_name() != "headless":
		await _check_rendered(blessed, cursed, health)
	else:
		print("PickupCoverTest native pixel cases skipped: real renderer required")
	blessed.queue_free()
	cursed.queue_free()
	health.queue_free()
	await get_tree().process_frame
	_check(not is_instance_valid(blessed) and not is_instance_valid(health), "pickup removal releases icons without keeping their owners alive")
	_check(SaveManager.debug_save_writes == writes, "cover presentation performs no save writes")
	_finish()


func _check_rendered(blessed: ItemPickup, cursed: ItemPickup, health: HealthPickup) -> void:
	get_window().size = Vector2i(640, 360)
	get_window().content_scale_size = Vector2i(640, 360)
	var backdrop := Polygon2D.new()
	backdrop.polygon = PackedVector2Array([Vector2.ZERO, Vector2(640, 0), Vector2(640, 360), Vector2(0, 360)])
	backdrop.color = PAPER
	backdrop.z_index = -1000
	add_child(backdrop)
	var roof := ROOF.instantiate() as RoofOverlay
	add_child(roof)
	roof.footprint_outline_px = PackedVector2Array([Vector2(40, 40), Vector2(140, 40), Vector2(140, 240), Vector2(40, 240)])
	var poly := roof.get_node("RoofPoly") as Polygon2D
	poly.polygon = roof.footprint_outline_px
	poly.color = PAPER
	poly.z_index = -1
	blessed.vfx.set_exploration(false)
	cursed.visible = false
	health.visible = false
	roof._set_alpha(0.0)
	var clear := await _pixels()
	var left_clear := _sample(clear, Vector2(133, 136))
	var right_clear := _sample(clear, Vector2(147, 136))
	_check(left_clear.r > 0.7 and left_clear.g < 0.4, "atlas icon renders its selected art without the green neighbor")
	_check(_near(_sample(clear, Vector2(140, 140)), PAPER), "transparent atlas pixels retain the ground")
	roof._set_alpha(1.0)
	var covered := await _pixels()
	var left_covered := _sample(covered, Vector2(133, 136))
	_check(left_covered.r < left_clear.r - 0.15, "opaque roof applies the quiet silhouette to covered icon pixels")
	_check(_near(_sample(covered, Vector2(147, 136)), right_clear), "uncovered pixels of the same atlas icon keep their normal color")
	roof._set_alpha(0.5)
	var faded := _sample(await _pixels(), Vector2(133, 136))
	_check(faded.r > left_covered.r + 0.04 and faded.r < left_clear.r - 0.04, "partial roof alpha smoothly blends the pickup silhouette")
	roof._set_alpha(1.0)
	blessed.position.y = 260.0
	blessed.icon_sprite.position.y = -120.0
	var in_front := _sample(await _pixels(), Vector2(133, 136))
	_check(_near(in_front, left_clear), "a protected pickup in front uses ground depth instead of its thrown icon offset")
	blessed.position.y = 140.0
	blessed.icon_sprite.position.y = 0.0
	roof._inside_count = 1
	_check(_near(_sample(await _pixels(), Vector2(133, 136)), left_clear), "cutaway roof restores the normal pickup icon")
	roof._inside_count = 0
	blessed.icon_sprite.visible = false
	_check(_near(_sample(await _pixels(), Vector2(133, 136)), PAPER), "a covered hidden icon emits no visible hint")
	blessed.icon_sprite.visible = true
	roof.queue_free()
	await get_tree().process_frame
	_check(_near(_sample(await _pixels(), Vector2(133, 136)), left_clear), "streamed roof removal clears stale pickup coverage")
	await _check_foliage(blessed, health, left_clear, right_clear)
	backdrop.queue_free()


func _check_foliage(blessed: ItemPickup, health: HealthPickup, left_clear: Color, right_clear: Color) -> void:
	var image := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	image.fill(PAPER)
	image.fill_rect(Rect2i(16, 0, 16, 48), Color.TRANSPARENT)
	var tree := Sprite2D.new()
	tree.texture = ImageTexture.create_from_image(image)
	tree.position = Vector2(140, 140)
	tree.z_index = -1
	add_child(tree)
	var descriptors := load("res://core/systems/world/visibility/ForegroundSpriteCoverage.gd") as GDScript
	descriptors.call("register", tree, Vector2(140, 220))
	var foliage := await _pixels()
	var leaf := _sample(foliage, Vector2(133, 136))
	_check(leaf.r < left_clear.r - 0.15, "opaque foliage covers the actual equipment icon")
	_check(_near(_sample(foliage, Vector2(147, 136)), right_clear), "a transparent leaf gap preserves the uncovered equipment pixels")
	blessed.vfx.set_locked(true)
	var locked := await _pixels()
	_check(_sample(locked, Vector2(133, 136)).r > leaf.r + 0.04, "foliage composition retains the reduced alpha of a locked icon")
	_check(_sample(locked, Vector2(147, 136)).g > right_clear.g + 0.08, "a leaf gap keeps the original locked icon alpha")
	blessed.vfx.set_locked(false)
	blessed.icon_sprite.scale = Vector2(1.5, 1.5)
	blessed.icon_sprite.position.y = -6.0
	var pulsed := await _pixels()
	_check(_sample(pulsed, Vector2(129, 128)).r < left_clear.r - 0.15, "temporary icon scale and offset retain world-space foliage coverage")
	_check(_near(_sample(pulsed, Vector2(151, 128)), right_clear), "scaled icon pixels inside a leaf gap retain their authored color")
	blessed.icon_sprite.scale = Vector2.ONE
	blessed.icon_sprite.position = Vector2.ZERO
	blessed.visible = false
	health.visible = true
	health.set_process(false)
	health.position = Vector2(140, 140)
	health.glow.texture = blessed.icon_sprite.texture
	health.glow.scale = Vector2.ONE
	health.glow.position = Vector2.ZERO
	health.icon.visible = false
	# Isolate the real duplicate health glow so an icon cannot hide a missing
	# glow adapter. Its tint/alpha stay under HealthPickup's existing owner.
	health._process(0.0)
	health.glow.scale = Vector2.ONE
	health.glow.position = Vector2.ZERO
	var glow_covered := _sample(await _pixels(), Vector2(133, 136))
	tree.visible = false
	var glow_clear := _sample(await _pixels(), Vector2(133, 136))
	_check(glow_covered.r < glow_clear.r - 0.05, "the duplicate healing glow cannot repaint bright art over foliage coverage")
	_check(health.glow.modulate.is_equal_approx(Color(1.0, 0.16, 0.22, 0.28)), "native cover composition retains health glow modulation")
	tree.queue_free()


func _pixels() -> Image:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _sample(pixels: Image, world: Vector2) -> Color:
	var rect := get_viewport().get_visible_rect()
	var point := (get_viewport().get_canvas_transform() * world - rect.position) * Vector2(pixels.get_size()) / rect.size
	return pixels.get_pixelv(Vector2i(point))


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.04 and absf(a.g - b.g) < 0.04 and absf(a.b - b.b) < 0.04


func _finish() -> void:
	print("PickupCoverTest passes=%d failures=%d" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)
