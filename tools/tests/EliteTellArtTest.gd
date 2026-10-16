extends Node

# These checks catch missing dedicated resources, scale-dependent shield
# coverage, invisible stationary FAST, moving reduced-motion trails, and
# a lost VAMPIRIC feed flash. Pixel checks run with a real display driver.
const ART_SCRIPT_PATH := "res://core/systems/vfx/EliteTellArt.gd"
const ENEMY_SCENE := preload("res://core/actors/enemy/enemy.tscn")

var _passes := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	Global.debug_disable_autosave = true
	var previous_reduced: Variant = SettingsManager.get_value(&"accessibility", &"reduced_motion", false)
	var has_art := ResourceLoader.exists(ART_SCRIPT_PATH)
	_check(has_art, "elite tells have a dedicated art loader")
	if has_art:
		var art := load(ART_SCRIPT_PATH) as Script
		for id in EliteModifiers.ALL:
			var texture := art.call("texture", id) as Texture2D
			_check(texture != null and texture.resource_path == "res://assets/textures/vfx/elites/%s.png" % id, "%s resolves dedicated art instead of a shared generic stamp" % id)
			if texture != null:
				_check(art.call("texture", id) == texture, "%s reuses its loaded texture" % id)
		_check(art.call("texture", &"unknown") == null, "unknown modifiers safely use the existing fallback")
	if DisplayServer.get_name() != "headless":
		await _test_rendered_marks()
	SettingsManager.set_value(&"accessibility", &"reduced_motion", previous_reduced, false)
	print("EliteTellArtTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _capture(id: StringName, parent_scale: float = 1.0, reduced: bool = true, velocity: Vector2 = Vector2.ZERO, feed: bool = false, elapsed_after_feed: float = 0.0) -> Image:
	SettingsManager.set_value(&"accessibility", &"reduced_motion", reduced, false)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var host := Node2D.new()
	host.position = Vector2(256.0, 256.0)
	host.scale = Vector2.ONE * parent_scale
	viewport.add_child(host)
	# An unregistered real actor supplies the mark's state; it has no scene
	# visuals or movement that could contaminate this transparent capture.
	var enemy := ENEMY_SCENE.instantiate() as EnemyActor
	enemy.velocity = velocity
	enemy.player = host
	var mark := VFX_EliteModifierMark.new()
	mark.setup(enemy, [id], EliteModifiers.tint(id))
	host.add_child(mark)
	mark.set_process(false)
	# Settle the static draw before feeding; the expiry must schedule its
	# own redraw rather than borrowing the initial queue_redraw from ready.
	mark.call("_process", 0.0)
	if feed:
		mark.note_feed()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if elapsed_after_feed > 0.0:
		mark.call("_process", elapsed_after_feed)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	enemy.free()
	await get_tree().process_frame
	return image


func _alpha_sum(image: Image, area: Rect2i) -> float:
	var total := 0.0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			total += image.get_pixel(x, y).a
	return total


func _painted_bounds(image: Image) -> Rect2i:
	var first := Vector2i(image.get_width(), image.get_height())
	var last := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.10:
				first = first.min(Vector2i(x, y))
				last = last.max(Vector2i(x, y))
	return Rect2i(first, last - first + Vector2i.ONE) if last.x >= first.x else Rect2i()


func _test_rendered_marks() -> void:
	var shield := await _capture(EliteModifiers.SHIELDED)
	var shield_scaled := await _capture(EliteModifiers.SHIELDED, 2.0)
	var shield_bounds := _painted_bounds(shield)
	var scaled_bounds := _painted_bounds(shield_scaled)
	_check(maxi(shield_bounds.size.x, shield_bounds.size.y) >= 350 and maxi(shield_bounds.size.x, shield_bounds.size.y) <= 364, "painted shield reaches the 180px protection radius")
	_check(shield_bounds == scaled_bounds, "doubling the parent scale leaves the shield's world coverage unchanged")
	_check(_alpha_sum(shield, Rect2i(226, 226, 60, 60)) < 0.1, "the shield ward keeps an empty transparent interior")
	var still_fast := await _capture(EliteModifiers.FAST, 1.0, false)
	var moving_fast := await _capture(EliteModifiers.FAST, 1.0, false, Vector2(300.0, 0.0))
	var reduced_fast := await _capture(EliteModifiers.FAST, 1.0, true, Vector2(300.0, 0.0))
	var glyph_area := Rect2i(220, 278, 72, 28)
	var trail_area := Rect2i(175, 235, 65, 42)
	_check(_alpha_sum(still_fast, glyph_area) > 5.0, "stationary primary FAST paints a visible ribbon")
	_check(_alpha_sum(moving_fast, trail_area) > 5.0, "moving FAST adds a velocity-aligned ribbon behind the body")
	_check(_alpha_sum(reduced_fast, trail_area) < 0.1 and _alpha_sum(reduced_fast, glyph_area) > 5.0, "reduced motion suppresses the trail while retaining the static ribbon")
	var vampiric := await _capture(EliteModifiers.VAMPIRIC)
	var feeding := await _capture(EliteModifiers.VAMPIRIC, 1.0, true, Vector2.ZERO, true)
	_check(_alpha_sum(feeding, Rect2i(220, 220, 72, 72)) > _alpha_sum(vampiric, Rect2i(220, 220, 72, 72)) * 1.3, "a feed visibly brightens the painted VAMPIRIC ring even under reduced motion")
	var expired_feed := await _capture(EliteModifiers.VAMPIRIC, 1.0, true, Vector2.ZERO, true, 0.45)
	_check(absf(_alpha_sum(expired_feed, Rect2i(220, 220, 72, 72)) - _alpha_sum(vampiric, Rect2i(220, 220, 72, 72))) < 0.1, "the reduced-motion feed flash returns to baseline on expiry without another redraw trigger")
	await _test_secondary_tells_in_overlap()


## The real painted tells over three overlapping production Brute sprites,
## rendered at the crowd preview's 1280/1920 screen scale. Keeping simulation
## out of this fixture lets the trough and still-frame checks be repeatable.
func _capture_overlap(secondary: StringName, reduced: bool, feed: bool = false) -> Image:
	SettingsManager.set_value(&"accessibility", &"reduced_motion", reduced, false)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128, 128)
	viewport.transparent_bg = false
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.color = Color(0.27, 0.25, 0.20, 1.0)
	background.size = Vector2(128, 128)
	viewport.add_child(background)
	var host := Node2D.new()
	host.position = Vector2(64, 64)
	host.scale = Vector2.ONE * (2.0 / 3.0)
	viewport.add_child(host)
	var spec := load("res://core/actors/enemy/EnemySpec_Brute.tres") as EnemySpec
	for at in [Vector2(-18, 8), Vector2(18, -8), Vector2.ZERO]:
		var sprite := Sprite2D.new()
		sprite.texture = spec.sprite_texture
		sprite.scale = spec.sprite_scale
		sprite.position = at
		sprite.modulate = EliteModifiers.tint(EliteModifiers.ARMOURED) if at == Vector2.ZERO else Color.WHITE
		host.add_child(sprite)
	var enemy := ENEMY_SCENE.instantiate() as EnemyActor
	enemy.player = host
	var mark := VFX_EliteModifierMark.new()
	var ids: Array[StringName] = [EliteModifiers.ARMOURED]
	if secondary != &"":
		ids.append(secondary)
	mark.setup(enemy, ids, EliteModifiers.tint(EliteModifiers.ARMOURED))
	host.add_child(mark)
	mark.set_process(false)
	# sin(1.5 * PI) is the blood pulse's trough, where the secondary tell
	# previously faded into overlapping bodies.
	mark.set("_t", 0.75 / mark.vampiric_pulse_hz)
	mark.call("_process", 0.0)
	if feed:
		mark.note_feed()
	mark.call("_queue_marks_redraw")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	enemy.free()
	await get_tree().process_frame
	return image


func _tell_coverage(image: Image, red: bool, baseline: Image) -> Dictionary:
	var count := 0
	var first_x := image.get_width()
	var last_x := -1
	var energy := 0.0
	for y in range(37, 91):
		for x in range(34, 94):
			var pixel := image.get_pixel(x, y)
			var body := baseline.get_pixel(x, y)
			var hue_gain := ((pixel.r - pixel.g) - (body.r - body.g)) if red else ((pixel.g - (pixel.r + pixel.b) * 0.5) - (body.g - (body.r + body.b) * 0.5))
			var matches := hue_gain > 0.12 and ((pixel.r > 0.35 and pixel.r > pixel.g * 1.65 and pixel.r > pixel.b * 1.4) if red else (pixel.g > 0.45 and pixel.g > pixel.r * 1.06 and pixel.g > pixel.b * 1.2))
			if matches:
				count += 1
				first_x = mini(first_x, x)
				last_x = maxi(last_x, x)
				energy += pixel.r if red else pixel.g
	return {"count": count, "width": last_x - first_x + 1, "energy": energy}


func _test_secondary_tells_in_overlap() -> void:
	var baseline := await _capture_overlap(&"", true)
	var trough := await _capture_overlap(EliteModifiers.VAMPIRIC, false)
	var still := await _capture_overlap(EliteModifiers.VAMPIRIC, true)
	var feeding := await _capture_overlap(EliteModifiers.VAMPIRIC, true, true)
	var seam := await _capture_overlap(EliteModifiers.SPLITTING, true)
	var trough_red := _tell_coverage(trough, true, baseline)
	var still_red := _tell_coverage(still, true, baseline)
	var feed_red := _tell_coverage(feeding, true, baseline)
	var seam_green := _tell_coverage(seam, false, baseline)
	print("Secondary native tell coverage: trough=", trough_red, " still=", still_red, " feed=", feed_red, " seam=", seam_green)
	_check(int(trough_red["count"]) >= 45, "secondary VAMPIRIC retains a readable red collar at its dimmest pulse over overlapping Brutes")
	_check(int(still_red["count"]) >= 45, "reduced-motion secondary VAMPIRIC retains the same clear static red collar")
	_check(float(feed_red["energy"]) > float(still_red["energy"]) * 1.12, "secondary VAMPIRIC feeding still visibly brightens its stronger static collar")
	_check(int(seam_green["count"]) >= 80 and int(seam_green["width"]) >= 40, "secondary SPLITTING paints clear lime branches across and beyond overlapping Brute shoulders")
	var output := ProjectSettings.globalize_path("res://.godot/secondary-tell-pixels")
	DirAccess.make_dir_recursive_absolute(output)
	trough.save_png(output.path_join("vampiric-trough.png"))
	still.save_png(output.path_join("vampiric-still.png"))
	feeding.save_png(output.path_join("vampiric-feed.png"))
	seam.save_png(output.path_join("splitting-still.png"))
