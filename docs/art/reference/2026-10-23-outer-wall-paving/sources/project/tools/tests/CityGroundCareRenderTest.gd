extends Node2D
## Native pixel regression for fractional household care on district paving.
## Only the test light-map blue channel changes between matched readbacks.
## This tiny fixture does not establish whole-city appearance or performance.

const SPLAT := preload("res://core/systems/world/ground/GroundSplatRenderer.gd")
const ART := preload("res://core/systems/world/WorldArt.gd")
const CELL := 64
const VIEW_SIZE := Vector2i(512, 384)
const SUPPORT := Rect2i(1, 2, 4, 3)
const CORE := Rect2i(128, 176, 128, 96)
const ROAD := Rect2i(96, 16, 224, 32)
const LANE := Rect2i(432, 112, 48, 240)
const OUTSIDE := Rect2i(16, 144, 24, 112)
const DOOR := Rect2i(272, 272, 32, 32)
const WEIGHTS: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]

var _passed: int = 0
var _failed: int = 0
var _view: SubViewport
var _splat: GroundSplatRenderer
var _out: String = ""


func _ready() -> void:
	Engine.max_fps = 20
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
		print("PASS: ", message)
	else:
		_failed += 1
		push_error("FAIL: " + message)


func _run() -> void:
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "gl_compatibility":
		_check(false, "CityGroundCareRenderTest requires native Compatibility rendering")
		_finish()
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = ProjectSettings.globalize_path(argument.trim_prefix("--out="))
	if not _out.is_empty():
		_check(DirAccess.make_dir_recursive_absolute(_out) == OK, "finite native evidence directory is writable")
	_view = SubViewport.new()
	_view.size = VIEW_SIZE
	_view.disable_3d = true
	_view.transparent_bg = true
	_view.world_2d = World2D.new()
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	_splat = SPLAT.new()
	_view.add_child(_splat)
	_splat.configure(CELL, 8)
	_splat.set_ground_family(&"service_courtyards")
	_splat.get_shader_material().set_shader_parameter("debug_view", 0)
	_reset_ground()
	await _fractional_sweep()
	await _household_access_control()
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_splat.clear()
	_view.queue_free()
	_splat = null
	_view = null
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	ART.release_static_caches()
	SPLAT.release_static_caches()
	_finish()


func _finish() -> void:
	print("CityGroundCareRenderTest: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _reset_ground() -> void:
	_splat.set_chunk_base(Vector2i.ZERO, 6)
	_splat.paint_rect(Rect2i(0, 0, 8, 1), 7, 1.0)
	_splat.paint_rect(Rect2i(6, 1, 2, 5), 4, 1.0)


func _pixels(label: String) -> Image:
	_splat.flush()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var pixels: Image = _view.get_texture().get_image()
	_check(pixels != null and pixels.get_size() == VIEW_SIZE, label + " reads the actual native ground target")
	if pixels != null and not _out.is_empty():
		_check(pixels.save_png(_out.path_join(label + ".png")) == OK, label + " saves its unmodified native pixels")
	return pixels


func _set_weight(weight: float) -> void:
	# A controlled input to the real transport, rather than a replacement
	# shader or stand-in texture. All five observations share world position,
	# source art, coverage, noise, brightness, stain and occlusion bytes.
	var light: Image = _splat.get("_light") as Image
	for y: int in range(SUPPORT.position.y, SUPPORT.end.y):
		for x: int in range(SUPPORT.position.x, SUPPORT.end.x):
			var value: Color = light.get_pixel(x, y)
			value.b = weight
			light.set_pixel(x, y, value)
	_splat.set("_dirty", true)


func _fractional_sweep() -> void:
	var cover_a: PackedByteArray = (_splat.get("_cover_a") as Image).get_data()
	var cover_b: PackedByteArray = (_splat.get("_cover_b") as Image).get_data()
	var light_before: PackedByteArray = (_splat.get("_light") as Image).get_data()
	var images: Array[Image] = []
	for index: int in WEIGHTS.size():
		_set_weight(WEIGHTS[index])
		images.append(await _pixels("care-%03d" % roundi(WEIGHTS[index] * 100.0)))
	for pixels: Image in images:
		if pixels == null or pixels.get_size() != VIEW_SIZE:
			return
	var bare: Image = images[0]
	var full: Image = images[4]
	var endpoint: Dictionary = _influence(bare, full, full, CORE)
	_check(float(endpoint.energy) > 0.005, "a fully cared core remains visibly distinct from the same bare paving")
	var bare_mean: Vector3 = _mean_rgb(bare, CORE)
	var full_mean: Vector3 = _mean_rgb(full, CORE)
	var bare_green: float = bare_mean.y - (bare_mean.x + bare_mean.z) * 0.5
	var full_green: float = full_mean.y - (full_mean.x + full_mean.z) * 0.5
	_check(full_green > 0.035 and full_green > bare_green + 0.025, "full care retains the green lawn core rather than merely darkening stone")
	var previous: float = 0.0
	for index: int in range(1, WEIGHTS.size()):
		var measured: Dictionary = _influence(bare, full, images[index], CORE)
		var amount: float = float(measured.amount)
		print("CityGroundCareRenderTest weight=%.2f influence=%.4f relative_residual=%.4f endpoint_energy=%.6f" % [WEIGHTS[index], amount, float(measured.residual), float(measured.energy)])
		if index < 4:
			_check(absf(amount - WEIGHTS[index]) < 0.16, "care %.2f has proportional native influence (observed %.4f)" % [WEIGHTS[index], amount])
			_check(float(measured.residual) < 0.20, "care %.2f blends toward its full cared appearance at matching pixels" % WEIGHTS[index])
		_check(amount > previous + 0.08, "care %.2f visibly advances beyond the preceding weight; no threshold plateau" % WEIGHTS[index])
		previous = amount
		_check(_max_delta(bare, images[index], OUTSIDE) <= 2.0 / 255.0, "care %.2f leaves zero-mask outer yard pixels unchanged" % WEIGHTS[index])
		_check(_max_delta(bare, images[index], ROAD) <= 2.0 / 255.0, "care %.2f leaves the stamped road pixels unchanged" % WEIGHTS[index])
		_check(_max_delta(bare, images[index], LANE) <= 2.0 / 255.0, "care %.2f leaves the stamped access lane pixels unchanged" % WEIGHTS[index])
	var light_after: PackedByteArray = (_splat.get("_light") as Image).get_data()
	var other_channels_unchanged: bool = true
	for index: int in light_before.size():
		if index % 4 != 2 and light_before[index] != light_after[index]:
			other_channels_unchanged = false
	_check(other_channels_unchanged and cover_a == (_splat.get("_cover_a") as Image).get_data() and cover_b == (_splat.get("_cover_b") as Image).get_data(), "the matched sweep changes only care, preserving coverage and all other light channels")
	_set_weight(0.0)
	var restored: Image = await _pixels("care-restored-zero")
	if restored != null and restored.get_size() == VIEW_SIZE:
		_check(_max_delta(bare, restored, Rect2i(Vector2i.ZERO, VIEW_SIZE)) <= 2.0 / 255.0, "clearing care restores every original rendered ground pixel")


func _household_access_control() -> void:
	_reset_ground()
	_splat.paint_rect(Rect2i(2, 1, 4, 2), 3, 1.0)
	var bare: Image = await _pixels("household-bare")
	var spec: Dictionary = {
		"footprint_px": PackedVector2Array([Vector2(128, 64), Vector2(384, 64), Vector2(384, 192), Vector2(128, 192)]),
		"doors": [{"pos": Vector2i(4, 2), "dir": Vector2i.DOWN, "width": 1}],
		"visual_seed": 944996572,
		"garden_contact_px": Vector2(132, 190),
	}
	_splat.paint_domestic_care(Vector2i.ZERO, spec)
	var cared: Image = await _pixels("household-cared")
	var signature: PackedByteArray = _splat.care_signature(Vector2i.ZERO)
	_check(signature.count(0) < signature.size(), "the public household planner actually places a bounded cared pocket")
	_check(_splat.care_at(Vector2i(4, 4)) == 0.0 and _splat.material_at(Vector2i(4, 4)) == 6, "the actual door veto keeps its district-ground approach free of care")
	_check(_splat.care_at(Vector2i(2, 0)) == 0.0 and _splat.care_at(Vector2i(7, 3)) == 0.0, "public care preserves road and access-lane restrictions")
	if bare == null or cared == null or bare.get_size() != VIEW_SIZE or cared.get_size() != VIEW_SIZE:
		return
	_check(_max_delta(bare, cared, Rect2i(80, 208, 96, 96)) > 0.05, "the public household pocket has visible cared pixels beside the house")
	_check(_max_delta(bare, cared, DOOR) <= 2.0 / 255.0, "the real reserved door approach retains its original native pixels")
	_check(_max_delta(bare, cared, ROAD) <= 2.0 / 255.0 and _max_delta(bare, cared, LANE) <= 2.0 / 255.0, "public household care leaves road and lane pixels unchanged")


func _influence(bare: Image, full: Image, sample: Image, rect: Rect2i) -> Dictionary:
	var energy: float = 0.0
	var projection: float = 0.0
	var observed: float = 0.0
	var count: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var original: Vector3 = _rgb(bare.get_pixel(x, y))
			var direction: Vector3 = _rgb(full.get_pixel(x, y)) - original
			var delta: Vector3 = _rgb(sample.get_pixel(x, y)) - original
			energy += direction.length_squared()
			projection += delta.dot(direction)
			observed += delta.length_squared()
			count += 1
	var amount: float = projection / maxf(energy, 0.000001)
	var residual: float = sqrt(maxf(0.0, observed - projection * amount) / maxf(energy, 0.000001))
	return {"amount": amount, "residual": residual, "energy": energy / maxi(1, count)}


func _mean_rgb(pixels: Image, rect: Rect2i) -> Vector3:
	var total: Vector3 = Vector3.ZERO
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			total += _rgb(pixels.get_pixel(x, y))
	return total / float(rect.get_area())


func _rgb(value: Color) -> Vector3:
	return Vector3(value.r, value.g, value.b)


func _max_delta(first: Image, second: Image, rect: Rect2i) -> float:
	var maximum: float = 0.0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var a: Color = first.get_pixel(x, y)
			var b: Color = second.get_pixel(x, y)
			maximum = maxf(maximum, maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), maxf(absf(a.b - b.b), absf(a.a - b.a)))))
	return maximum
