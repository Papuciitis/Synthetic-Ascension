extends Node2D
## Actual roof mesh UVs and native source-Y calibration expose tile courses
## which continue through a turned ridge despite the new light-plane axis.

const FIXTURE := preload("res://tools/tests/CitySceneDepthFixture.gd")
const ROOF_SHADER := preload("res://scenes/world/buildings/roof.gdshader")
const CLAY := "res://assets/world/city_block/clay.png"
var _passes := 0
var _failures := 0
var _calibration: ImageTexture


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if ok: _passes += 1
	else:
		_failures += 1
		push_error(label)


func _roof_meshes(host: Polygon2D) -> Array[Polygon2D]:
	var result: Array[Polygon2D] = [host]
	for node: Node in host.find_children("*","Polygon2D",true,false):
		var mesh := node as Polygon2D
		var material := mesh.material as ShaderMaterial
		if mesh.texture != null and material != null and material.shader == ROOF_SHADER: result.append(mesh)
	return result


func _at(meshes: Array[Polygon2D], point: Vector2) -> Polygon2D:
	for mesh: Polygon2D in meshes:
		var material := mesh.material as ShaderMaterial
		if mesh.color.a > 0.98 and float(material.get_shader_parameter("gable")) > 0.5 and Geometry2D.is_point_in_polygon(mesh.to_local(point),mesh.polygon): return mesh
	return null


## Independently recover actual source-texel affine mapping from mesh data.
## Empty Polygon2D.uv uses its local polygon coordinates (existing default).
func _uv_basis(mesh: Polygon2D) -> Transform2D:
	var points := mesh.polygon
	var uv := mesh.uv if mesh.uv.size() == points.size() else points
	for first in range(1,points.size()-1):
		for second in range(first+1,points.size()):
			var spatial := Transform2D(points[first]-points[0],points[second]-points[0],points[0])
			if absf(spatial.determinant()) < 0.001: continue
			var source := Transform2D(uv[first]-uv[0],uv[second]-uv[0],uv[0])
			return source*spatial.affine_inverse()*mesh.global_transform.affine_inverse()
	return Transform2D.IDENTITY


func _variation(pixels: Image, origin: Vector2i) -> Vector2:
	var result := Vector2.ZERO
	for y in range(origin.y,origin.y+31):
		for x in range(origin.x,origin.x+31):
			var value := pixels.get_pixel(x,y).r
			result.x += absf(value-pixels.get_pixel(x+1,y).r)
			result.y += absf(value-pixels.get_pixel(x,y+1).r)
	return result/(31.0*31.0)


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
	var host := (fixture.roof as RoofOverlay).get_node("RoofPoly") as Polygon2D
	(fixture.kit as CanvasItem).hide()
	var meshes := _roof_meshes(host)
	var main := _at(meshes,Vector2(700,650))
	var front := _at(meshes,Vector2(280,800))
	_check(main != null and front != null,"S%d probe selects actual opaque production roof meshes" % segment)
	if main != null and front != null:
		_check(main.texture.resource_path == CLAY and front.texture.resource_path == CLAY,"S%d both wings retain the original clay source resource" % segment)
		var main_basis := _uv_basis(main)
		var front_basis := _uv_basis(front)
		var main_density := Vector2(main_basis.x.length()/main.texture_scale.x,main_basis.y.length()/main.texture_scale.y)
		var front_density := Vector2(front_basis.x.length()/front.texture_scale.x,front_basis.y.length()/front.texture_scale.y)
		_check(absf(main_density.x-main_density.y) < 0.001 and absf(front_density.x-front_density.y) < 0.001 and main_density.x > 0.0,"S%d real mesh UVs retain isotropic nonzero texel density" % segment)
		_check(absf(main_density.x-front_density.x) < 0.001 and main.texture_scale.is_equal_approx(front.texture_scale),"S%d turning a wing preserves the original attached wing's texel density" % segment)
		if segment == 2:
			_check(absf(main_basis.x.y) > absf(main_basis.x.x)*4.0 and absf(main_basis.y.x) > absf(main_basis.y.y)*4.0,"NS main roof maps source barrel Y across world X instead of down its ridge")
		_check(absf(front_basis.y.y) > absf(front_basis.y.x)*4.0 and absf(front_basis.x.x) > absf(front_basis.x.y)*4.0,"S%d EW/front roof preserves its original source-Y downslope mapping" % segment)
	# Source-Y bands isolate actual texture direction while leaving every
	# production polygon, UV, texture scale and draw-alpha unchanged.
	for mesh: Polygon2D in meshes:
		mesh.texture = _calibration
		mesh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mesh.color = Color(1,1,1,mesh.color.a)
		var material := mesh.material as ShaderMaterial
		material.set_shader_parameter("material_contrast",1.0)
		material.set_shader_parameter("gable",0.0)
		material.set_shader_parameter("eave_px",0.01)
	for node: Node in host.find_children("*","Node2D",true,false):
		if node.has_meta(&"city_chimney"): (node as CanvasItem).hide()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var pixels := view.get_texture().get_image()
	_check(pixels != null and pixels.get_pixel(700,650).a > 0.98 and pixels.get_pixel(280,800).a > 0.98,"S%d native directional samples hit visible opaque roof" % segment)
	if pixels != null:
		var main_variation := _variation(pixels,Vector2i(700,640))
		var front_variation := _variation(pixels,Vector2i(275,790))
		if segment == 2:
			_check(main_variation.x > 0.001 and main_variation.y < 0.001,"native NS main roof source-Y variation runs across X; xy="+str(main_variation))
		else:
			_check(main_variation.y > 0.001 and main_variation.x < 0.001,"S3 native original tile direction stays unchanged; xy="+str(main_variation))
		_check(front_variation.y > 0.001 and front_variation.x < 0.001,"S%d native EW/front roof retains source-Y variation along Y; xy=" % segment+str(front_variation))
		print("CityIrregularRoofTextureRenderTest S%d actual variation main=%s front=%s" % [segment,str(main_variation),str(front_variation)])
	pixels = null
	fixture.clear()
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.queue_free()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CityIrregularRoofTextureRenderTest requires native Compatibility rendering")
		get_tree().quit(2)
		return
	AudioManager.stop_all(true)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var previous_segment := Global.attempt_segment
	var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
	for y in 128:
		var value := float(y%64)/63.0
		for x in 128: image.set_pixel(x,y,Color(value,value,value,1))
	_calibration = ImageTexture.create_from_image(image)
	image = null
	await _test_segment(2)
	await _test_segment(3)
	_calibration = null
	Global.attempt_segment = previous_segment
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("CityIrregularRoofTextureRenderTest: %d passed, %d failed" % [_passes,_failures])
	get_tree().quit(1 if _failures > 0 else 0)
