extends Node
## Exact surface, local facing, and endpoint regressions for the printed curl.
const LEAF := preload("res://ui/widgets/library/LibraryLeafMesh.gd")
var _passes := 0
var _failures := 0
var _capture_out := ""

func _ready() -> void:
	SaveManager.save_dir = "user://saves_test_library_curl/"
	SaveManager.current_save = null
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--curl-out="):
			_capture_out = argument.trim_prefix("--curl-out=")
			DirAccess.make_dir_recursive_absolute(_capture_out)
	call_deferred(&"_run")

func _check(ok: bool, message: String) -> void:
	if ok:
		_passes += 1
	else:
		_failures += 1
		push_error("LibraryCurlTest: " + message)

func _run() -> void:
	var leaf := LEAF.new()
	leaf.size = Vector2(1000, 700)
	add_child(leaf)
	var baseline: Dictionary = leaf.mesh_geometry(0.5, 1)
	_check(baseline.has("surface_vertices") and baseline.has("strips") and baseline.has("parameters"), "curl exposes its physical surface and individual visible faces")
	if baseline.has("surface_vertices") and baseline.has("strips") and baseline.has("parameters"):
		for toward: int in [1, -1]:
			for phase: float in [0.0, 0.05, 0.15, 0.3, 0.45, 0.49, 0.5, 0.51, 0.55, 0.7, 0.85, 0.95, 1.0]:
				_check_surface(leaf.mesh_geometry(phase, toward), phase, toward)
			for phase: float in [0.35, 0.5, 0.65]:
				var sample: Dictionary = leaf.mesh_geometry(phase, toward)
				var front_count := 0
				var back_count := 0
				for strip: Dictionary in sample.strips:
					front_count += 1 if strip.front else 0
					back_count += 0 if strip.front else 1
				_check(front_count > 0 and back_count > 0, "localized bend has simultaneous front and back faces (%d, %.2f)" % [toward, phase])
			var before: Dictionary = leaf.mesh_geometry(0.499, toward)
			var after: Dictionary = leaf.mesh_geometry(0.501, toward)
			_check(absf(float(before.edge_position.x) - float(after.edge_position.x)) < 5.0, "free edge crosses midpoint continuously without a face-wide flip")
			var midpoint: Dictionary = leaf.mesh_geometry(0.5, toward)
			var minimum := INF
			var maximum := -INF
			for point: Vector2 in midpoint.vertices:
				minimum = minf(minimum, point.x)
				maximum = maxf(maximum, point.x)
			_check(maximum - minimum > 0.35 * 415.0, "midpoint retains a broad curled sheet instead of vanishing edge-on")
			_check(float(midpoint.flat_fraction) > 0.5, "most frozen print remains on flat paper away from the fold")
		var forward: Dictionary = leaf.mesh_geometry(0.37, 1)
		var backward: Dictionary = leaf.mesh_geometry(0.37, -1)
		var mirrored: bool = forward.vertices.size() == backward.vertices.size()
		for index: int in forward.vertices.size():
			mirrored = mirrored and is_equal_approx(forward.vertices[index].x + backward.vertices[index].x, 1000.0) and is_equal_approx(forward.vertices[index].y, backward.vertices[index].y)
		_check(mirrored, "both turn directions mirror the same physical surface")
	if DisplayServer.get_name() != "headless":
		await _render_phases()
	leaf.queue_free()
	await get_tree().process_frame
	print("LibraryCurlTest: %d passed, %d failed" % [_passes, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _check_surface(sample: Dictionary, phase: float, toward: int) -> void:
	var surface: PackedVector3Array = sample.surface_vertices
	var parameters: PackedFloat32Array = sample.parameters
	var front_uv: PackedVector2Array = sample.front_uvs
	var back_uv: PackedVector2Array = sample.back_uvs
	var count := parameters.size()
	var domains := front_uv.size() == surface.size() and back_uv.size() == surface.size()
	var inextensible := true
	for index: int in range(count - 1):
		var arc_length := 415.0 * (parameters[index + 1] - parameters[index])
		var chord := surface[index].distance_to(surface[index + 1])
		inextensible = inextensible and chord <= arc_length + 0.001 and chord >= arc_length * 0.995 - 0.001
	for index: int in surface.size():
		domains = domains and front_uv[index].x >= 0.0 and front_uv[index].x <= 1.0 and front_uv[index].y >= 0.0 and front_uv[index].y <= 1.0
		domains = domains and back_uv[index].x >= 0.0 and back_uv[index].x <= 1.0 and back_uv[index].y >= 0.0 and back_uv[index].y <= 1.0
	_check(domains and inextensible, "captured UV domain and paper arc length are preserved (%d, %.2f)" % [toward, phase])
	var readable := true
	var depth_ordered := true
	var previous_depth := -INF
	for strip: Dictionary in sample.strips:
		var column := int(strip.column)
		var uv: PackedVector2Array = front_uv if strip.front else back_uv
		var dx := float(sample.vertices[column + 1].x - sample.vertices[column].x)
		var du := uv[column + 1].x - uv[column].x
		readable = readable and dx * du >= -0.001
		depth_ordered = depth_ordered and float(strip.depth) >= previous_depth - 0.001
		previous_depth = float(strip.depth)
	_check(readable and depth_ordered, "local faces keep print readable and overlapping strips draw from far to near (%d, %.2f)" % [toward, phase])
	if phase == 0.0 or phase == 1.0:
		var right := (toward > 0) == (phase == 0.0)
		var expected := Rect2(505 if right else 80, 56, 415, 588)
		var bounds := Rect2(sample.vertices[0], Vector2.ZERO)
		var flat := true
		for index: int in sample.vertices.size():
			bounds = bounds.expand(sample.vertices[index])
			flat = flat and absf(surface[index].z) < 0.001
		_check(bounds.is_equal_approx(expected) and flat, "resting surface exactly matches the static paper rectangle (%d, %.2f)" % [toward, phase])

func _render_phases() -> void:
	# The real native alpha leaf is used by the book and this regression alike.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000, 700)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var paper := AtlasTexture.new()
	paper.atlas = load("res://assets/ui/library/right_leaf_pixel.png")
	paper.region = Rect2(75, 34, 983, 1295)
	var underleaf := Control.new()
	underleaf.visible = false
	viewport.add_child(underleaf)
	for side: int in [0, 1]:
		var flat := TextureRect.new()
		flat.texture = paper
		flat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flat.position = Vector2(80 if side == 0 else 505, 56)
		flat.size = Vector2(415, 588)
		flat.flip_h = side == 0
		underleaf.add_child(flat)
	var source := await _printed_face("DEPARTING  FRONT", Color(0.12, 0.055, 0.025), paper)
	var left_source := await _printed_face("DEPARTING  FRONT", Color(0.12, 0.055, 0.025), paper, true)
	var back := await _printed_face("INCOMING  BACK", Color(0.08, 0.15, 0.42), paper)
	var left_back := await _printed_face("INCOMING  BACK", Color(0.08, 0.15, 0.42), paper, true)
	var leaf := LEAF.new()
	leaf.size = Vector2(1000, 700)
	leaf.source_texture = source
	leaf.back_texture = back
	leaf.paper_texture = paper
	viewport.add_child(leaf)
	for toward: int in [1, -1]:
		leaf.direction = toward
		leaf.source_texture = left_source if toward < 0 else source
		leaf.back_texture = back if toward < 0 else left_back
		for phase: float in [0.0, 0.15, 0.3, 0.45, 0.49, 0.5, 0.51, 0.55, 0.7, 0.85, 0.99]:
			leaf.progress = phase
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			if not _capture_out.is_empty():
				image.save_png(_capture_out.path_join("curl_%s_%02d.png" % ["forward" if toward > 0 else "backward", roundi(phase * 100)]))
			if toward < 0 and phase == 0.15:
				var frozen_anchor := image.get_pixel(425, 382)
				_check(frozen_anchor.r > 0.8 and frozen_anchor.g < 0.15 and frozen_anchor.b < 0.15, "backward shadow UVs never mutate the frozen front print orientation")
			var opaque_samples := 0
			for y: int in range(0, 700, 4):
				for x: int in range(0, 1000, 4):
					if image.get_pixel(x, y).a > 0.9:
						opaque_samples += 1
			_check(opaque_samples > 2500, "rendered curl keeps a broad physical sheet through its central phases")
			if not _capture_out.is_empty():
				underleaf.visible = true
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png(_capture_out.path_join("curl_layered_%s_%02d.png" % ["forward" if toward > 0 else "backward", roundi(phase * 100)]))
				underleaf.visible = false
	# An asymmetric fallback proves adjacent strips cannot toggle shared UVs.
	underleaf.visible = false
	leaf.direction = 1
	leaf.progress = 0.99
	leaf.back_texture = null
	leaf.paper_texture = source
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var fallback_anchor := viewport.get_texture().get_image().get_pixel(154, 382)
	_check(fallback_anchor.r > 0.8 and fallback_anchor.g < 0.15 and fallback_anchor.b < 0.15, "blank fallback strips keep one stable native-paper UV orientation")
	viewport.queue_free()

func _printed_face(title: String, ink: Color, paper: Texture2D, mirrored_paper: bool = false) -> ImageTexture:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(415, 588)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var native := TextureRect.new()
	native.texture = paper
	native.flip_h = mirrored_paper
	native.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	native.size = Vector2(415, 588)
	viewport.add_child(native)
	for line: int in 15:
		var label := Label.new()
		label.position = Vector2(28, 40 + line * 32)
		label.text = title if line == 0 else "%02d  Quiet leaves remember their stories." % line
		label.add_theme_color_override("font_color", ink)
		label.add_theme_font_size_override("font_size", 18 if line == 0 else 15)
		viewport.add_child(label)
	var anchor := ColorRect.new()
	anchor.position = Vector2(338, 316)
	anchor.size = Vector2(12, 20)
	anchor.color = Color(0.95, 0.05, 0.05)
	viewport.add_child(anchor)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var texture := ImageTexture.create_from_image(viewport.get_texture().get_image())
	viewport.queue_free()
	return texture
