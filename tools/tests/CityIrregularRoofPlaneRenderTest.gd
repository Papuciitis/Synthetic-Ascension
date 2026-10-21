extends Node2D
## The real bed L must read as connected lit roof masses, not one horizontal
## bounding-box gradient. White probe input removes tile-art variation only.
## Every city segment now shares the reviewed S2 wall height (176 px L walls)
## and its connected planes, so S3 is held to the same silhouette and light.

const FIXTURE := preload("res://tools/tests/CitySceneDepthFixture.gd")
const ROOF_SHADER := preload("res://scenes/world/buildings/roof.gdshader")
const WORLD_COVER := preload("res://core/systems/world/visibility/WorldCover.gd")
# Independently derived: footprint inset10, eroded north by facade_depth148.
# RoofPoly is then positioned28px north; this literal is in its local space.
const S2_VISIBLE := [Vector2(202,778),Vector2(394,778),Vector2(394,586),Vector2(886,586),Vector2(886,930),Vector2(202,930)]
var _passes := 0
var _failures := 0
var _white: ImageTexture


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if ok: _passes += 1
	else:
		_failures += 1
		push_error(label)


func _roof_planes(host: Polygon2D) -> Array[Polygon2D]:
	var result: Array[Polygon2D] = []
	for node: Node in host.find_children("*","Polygon2D",true,false):
		var plane := node as Polygon2D
		var material := plane.material as ShaderMaterial
		if plane.texture != null and material != null and material.shader == ROOF_SHADER:
			result.append(plane)
	return result


func _host_points(host: Polygon2D, plane: Polygon2D) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in plane.polygon: result.append(host.to_local(plane.to_global(point)))
	return result


func _white_input(host: Polygon2D) -> void:
	var all: Array[Polygon2D] = [host]
	all.append_array(_roof_planes(host))
	for plane: Polygon2D in all:
		plane.texture = _white
		plane.color = Color(1,1,1,plane.color.a)
		var material := plane.material as ShaderMaterial
		material.set_shader_parameter("material_contrast",1.0)
		material.set_shader_parameter("ridge_light",0.0)
	for node: Node in host.find_children("*","Node2D",true,false):
		if node.has_meta(&"city_chimney"): (node as CanvasItem).hide()


func _pixels(view: SubViewport) -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()


func _luma(pixels: Image, point: Vector2i) -> float:
	var color := pixels.get_pixelv(point)
	return color.r*0.2126+color.g*0.7152+color.b*0.0722


func _test_segment(segment: int) -> void:
	Global.attempt_segment = segment
	var view := SubViewport.new()
	view.size = Vector2i(1024,1024)
	view.transparent_bg = true
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var chunk := Node2D.new()
	view.add_child(chunk)
	var fixture := FIXTURE.create(chunk)
	var roof := fixture.roof as RoofOverlay
	var host := roof.get_node("RoofPoly") as Polygon2D
	var kit := fixture.kit as Node2D
	kit.hide()
	var literal := PackedVector2Array(S2_VISIBLE)
	_check(Geometry2D.clip_polygons(host.polygon,literal).is_empty() and Geometry2D.clip_polygons(literal,host.polygon).is_empty(),"S%d preserves the hand-derived original visible roof silhouette" % segment)
	_check(roof.footprint_outline_px == PackedVector2Array(FIXTURE.BED_OUTLINE),"S%d retains the actual physical footprint source" % segment)
	var planes := _roof_planes(host)
	_check(planes.size() >= 2,"actual S%d L roof supplies connected renderable main/front planes" % segment)
	var gap_count := 0
	var outside_count := 0
	var overlap_count := 0
	for y in range(589,939,19):
		for x in range(205,900,17):
			var point := Vector2(x,y)
			var inside := Geometry2D.is_point_in_polygon(point,literal)
			var covers := 0
			for plane: Polygon2D in planes:
				if Geometry2D.is_point_in_polygon(point,_host_points(host,plane)): covers += 1
			if inside and covers == 0: gap_count += 1
			if not inside and covers > 0: outside_count += 1
			if covers > 1: overlap_count += 1
	_check(gap_count == 0,"actual connected roof planes cover the full visible L without gaps; gaps=%d" % gap_count)
	_check(outside_count == 0,"actual connected roof planes never fill outside the original L/notch; outside=%d" % outside_count)
	_check(overlap_count == 0,"main/front roof lighting planes do not overlap and double-shade; overlaps=%d" % overlap_count)
	_white_input(host)
	var pixels := await _pixels(view)
	_check(pixels != null and pixels.get_pixel(500,650).a > 0.98 and pixels.get_pixel(800,650).a > 0.98,"S%d native samples hit the actual opaque main roof, not empty background" % segment)
	if pixels != null:
		var west := _luma(pixels,Vector2i(500,650))
		var east := _luma(pixels,Vector2i(800,650))
		_check(east > west+0.10,"S%d main L wing has its own northeast-lit east slope; west=%.3f east=%.3f" % [segment,west,east])
		var north := _luma(pixels,Vector2i(300,780))
		var south := _luma(pixels,Vector2i(300,870))
		_check(north > south+0.10,"S%d short front L wing has its own north/south roof planes; north=%.3f south=%.3f" % [segment,north,south])
	if segment == 2:
		var cover := WORLD_COVER.get_for(chunk)
		cover.call("refresh",chunk,true)
		_check(float(cover.call("strength_at",Vector2(600,650),500.0)) > 0.98,"connected opaque roof retains actual shared cover strength")
		roof._set_alpha(0.5)
		cover.call("refresh",chunk,true)
		pixels = await _pixels(view)
		_check(absf(pixels.get_pixel(500,650).a-0.5) < 0.02 and absf(pixels.get_pixel(800,650).a-0.5) < 0.02 and absf(pixels.get_pixel(300,870).a-0.5) < 0.02,"fractional roof cutaway renders each point once, without parent/child double compositing")
		_check(absf(pixels.get_pixel(883,650).a-0.5) < 0.02 and absf(pixels.get_pixel(600,899).a-0.5) < 0.02 and absf(pixels.get_pixel(883,899).a-0.5) < 0.02,"fractional fascia and its corner preserve the same single roof opacity")
		_check(absf(float(cover.call("strength_at",Vector2(600,650),500.0))-0.5) < 0.02,"fractional visible roof alpha matches shared coverage strength")
		roof._set_alpha(0.0)
		cover.call("refresh",chunk,true)
		_check(is_zero_approx(float(kit.get("_facade_alpha"))),"actual roof alpha callback still opens its matching facade")
		_check(is_zero_approx(float(cover.call("strength_at",Vector2(600,650),500.0))),"actual cutaway clears shared coverage for the complete roof")
		pixels = await _pixels(view)
		_check(pixels.get_pixel(500,650).a < 0.01 and pixels.get_pixel(800,650).a < 0.01 and pixels.get_pixel(300,870).a < 0.01,"all actual connected roof planes disappear with the parent cutaway")
		roof._set_alpha(1.0)
		cover.call("refresh",chunk,true)
		_check(is_equal_approx(float(kit.get("_facade_alpha")),1.0) and float(cover.call("strength_at",Vector2(600,650),500.0)) > 0.98,"actual exit restoration returns facade callback and opaque roof coverage")
	pixels = null
	fixture.clear()
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.queue_free()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CityIrregularRoofPlaneRenderTest requires native Compatibility RGBA rendering")
		get_tree().quit(2)
		return
	var old_segment := Global.attempt_segment
	var white_image := Image.create(2,2,false,Image.FORMAT_RGBA8)
	white_image.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(white_image)
	white_image = null
	await _test_segment(2)
	await _test_segment(3)
	_white = null
	Global.attempt_segment = old_segment
	print("CityIrregularRoofPlaneRenderTest: %d passed, %d failed" % [_passes,_failures])
	get_tree().quit(1 if _failures > 0 else 0)
