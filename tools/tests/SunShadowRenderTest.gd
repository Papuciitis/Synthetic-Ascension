extends Node2D
## Native contract for the shared multiplicative sun shade (WorldDepthStyle).
## A cast must multiply any ground by one ratio, feather through vertex alpha,
## keep the cutaway's modulate residual, follow a theme's shade uniform, and
## the production bed home's soft cast must darken real ground only where the
## ground-footprint caster reaches, and its garden (soil, herbs and the herb
## bed) must take the same shade whatever order the kit added it in.
## Headless runs skip the rendered checks.

const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")
const FIXTURE := preload("res://tools/tests/CitySceneDepthFixture.gd")
const DRESSING := preload("res://scenes/world/buildings/CityFrontageDressing.gd")
var _passes := 0
var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("PASS: ",label)
	else:
		_failures += 1
		push_error("FAIL: "+label)


func _run() -> void:
	DEPTH.reset_light()
	_check(DEPTH.sun_shade().is_equal_approx(DEPTH.SUN_SHADE),"shared shade starts at clear daylight")
	_check(DEPTH.building_shadow_offset(208.0).length() > DEPTH.offset_for_height(126.0).length()*1.3,"a 208 px wall casts far longer than the old fixed 126 px house")
	DEPTH.length_scale = 0.65
	var short := DEPTH.building_shadow_offset(208.0)
	DEPTH.length_scale = 1.0
	_check(short.length() < DEPTH.building_shadow_offset(208.0).length() and short.normalized().is_equal_approx(DEPTH.SHADOW_DIRECTION.normalized()),"theme length scales the cast without turning the sun")
	if DisplayServer.get_name() != "headless":
		await _check_rendered_ratio()
		await _check_rendered_kit()
		await _check_rendered_garden()
	DEPTH.reset_light()
	print("SunShadowRenderTest: %d passed, %d failed" % [_passes,_failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _view(size: Vector2i, center: Vector2) -> Array:
	var view := SubViewport.new()
	view.size = size
	view.world_2d = World2D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var world := Node2D.new()
	view.add_child(world)
	var camera := Camera2D.new()
	camera.position = center
	world.add_child(camera)
	camera.make_current()
	return [view,world]


func _ground(world: Node2D, area: Rect2, value: float) -> void:
	var ground := ColorRect.new()
	ground.position = area.position
	ground.size = area.size
	ground.color = Color(value,value,value)
	ground.z_index = -100
	world.add_child(ground)


func _cast(world: Node2D, faces: Array, alphas: Array, modulate_alpha: float = 1.0) -> Polygon2D:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var indices: Array[PackedInt32Array] = []
	for face_index in faces.size():
		var face := PackedInt32Array()
		var face_points: PackedVector2Array = faces[face_index]
		var face_alphas: PackedFloat32Array = alphas[face_index]
		for index in face_points.size():
			face.append(points.size())
			points.append(face_points[index])
			colors.append(Color(1,1,1,face_alphas[index]))
		indices.append(face)
	var cast := Polygon2D.new()
	cast.polygon = points
	cast.polygons = indices
	cast.vertex_colors = colors
	cast.material = DEPTH.SUN_SHADOW_MATERIAL
	cast.z_index = -90
	cast.modulate.a = modulate_alpha
	world.add_child(cast)
	return cast


func _pixel(view: SubViewport, image: Image, world_point: Vector2) -> Color:
	return image.get_pixelv(Vector2i(view.get_canvas_transform()*world_point))


func _near(actual: Color, expected: Color, tolerance: float = 0.02) -> bool:
	return absf(actual.r-expected.r) <= tolerance and absf(actual.g-expected.g) <= tolerance and absf(actual.b-expected.b) <= tolerance


func _check_rendered_ratio() -> void:
	var made := _view(Vector2i(320,128),Vector2(160,64))
	var view: SubViewport = made[0]
	var world: Node2D = made[1]
	_ground(world,Rect2(0,0,160,128),0.5)
	_ground(world,Rect2(160,0,160,128),0.25)
	# Core + feathered band, then the same cast at cutaway's residual alpha.
	var core := PackedVector2Array([Vector2(10,10),Vector2(60,10),Vector2(60,118),Vector2(10,118)])
	var band := PackedVector2Array([Vector2(60,10),Vector2(100,10),Vector2(100,118),Vector2(60,118)])
	_cast(world,[core,band],[PackedFloat32Array([1,1,1,1]),PackedFloat32Array([1,0,0,1])])
	var dark := PackedVector2Array([Vector2(170,10),Vector2(220,10),Vector2(220,118),Vector2(170,118)])
	_cast(world,[dark],[PackedFloat32Array([1,1,1,1])])
	var faded := PackedVector2Array([Vector2(110,10),Vector2(150,10),Vector2(150,118),Vector2(110,118)])
	_cast(world,[faded],[PackedFloat32Array([1,1,1,1])],0.65)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	var shade := DEPTH.SUN_SHADE
	_check(_near(_pixel(view,image,Vector2(30,64)),Color(0.5*shade.r,0.5*shade.g,0.5*shade.b)),"a full cast multiplies mid ground by the shared shade; got %s" % str(_pixel(view,image,Vector2(30,64))))
	_check(_near(_pixel(view,image,Vector2(195,64)),Color(0.25*shade.r,0.25*shade.g,0.25*shade.b)),"the same cast darkens darker ground by the same ratio, not toward a fixed colour")
	var mid := 0.5*(1.0+shade.r)*0.5
	_check(absf(_pixel(view,image,Vector2(80,64)).r-mid) < 0.03,"the penumbra band fades through vertex alpha; got %.3f want %.3f" % [_pixel(view,image,Vector2(80,64)).r,mid])
	_check(_near(_pixel(view,image,Vector2(104,64)),Color(0.5,0.5,0.5),0.01),"outside the cast the ground is untouched")
	var residual := lerpf(1.0,shade.r,0.65)*0.5
	_check(absf(_pixel(view,image,Vector2(130,64)).r-residual) < 0.02,"cutaway modulate keeps the residual cast; got %.3f want %.3f" % [_pixel(view,image,Vector2(130,64)).r,residual])
	var overcast := Color(0.80,0.83,0.86)
	DEPTH.set_sun_shade(overcast)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	image = view.get_texture().get_image()
	_check(_near(_pixel(view,image,Vector2(30,64)),Color(0.5*overcast.r,0.5*overcast.g,0.5*overcast.b)),"a theme's shade reaches every cast through the one shared uniform")
	DEPTH.reset_light()
	view.queue_free()
	await get_tree().process_frame


func _check_rendered_kit() -> void:
	var previous := Global.attempt_segment
	Global.attempt_segment = 2
	var made := _view(Vector2i(512,320),Vector2(300,980))
	var view: SubViewport = made[0]
	var world: Node2D = made[1]
	_ground(world,Rect2(-200,500,1300,800),0.5)
	var bed := FIXTURE.create(world)
	var kit := bed.kit as Node2D
	var placed: Array[Rect2i] = [FIXTURE.BED_RECT]
	kit.call(&"trim_paving",placed,64)
	# Hide the house's own upright layers so only ground receivers remain.
	for child: Node in kit.get_children():
		if child is CanvasItem and not child.has_meta(&"city_sun_shadow") and not child.has_meta(&"city_contact_shade"): (child as CanvasItem).visible = false
	(bed.roof as Node2D).visible = false
	kit.set_process(false)
	kit.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	var shade := DEPTH.SUN_SHADE
	var cast := _pixel(view,image,Vector2(150,1050))
	_check(_near(cast,Color(0.5*shade.r,0.5*shade.g,0.5*shade.b),0.03),"the production bed home's cast multiplies real ground by the shared shade; got %s" % str(cast))
	_check(_near(_pixel(view,image,Vector2(150,880)),Color(0.5,0.5,0.5),0.01),"ground beside the raised roof, north of the wall base, stays sunlit")
	var base := _pixel(view,image,Vector2(300,1080)).r
	var open := _pixel(view,image,Vector2(300,1130)).r
	_check(base < open-0.02,"wall-base contact deepens the cast at the south wall foot; base=%.3f open=%.3f" % [base,open])
	view.queue_free()
	await get_tree().process_frame
	Global.attempt_segment = previous


## Review 2026-10-21: an isolated kit (trimmed alone) kept its cast early in
## its child order and its garden soil drew over the multiplied shade. The
## garden must take the shade ratio with every kit layer visible.
func _check_rendered_garden() -> void:
	var previous := Global.attempt_segment
	Global.attempt_segment = 2
	var made := _view(Vector2i(512,320),Vector2(300,1080))
	var view: SubViewport = made[0]
	var world: Node2D = made[1]
	_ground(world,Rect2(-200,700,1300,700),0.5)
	var bed := FIXTURE.create(world)
	var kit := bed.kit as Node2D
	var placed: Array[Rect2i] = [FIXTURE.BED_RECT]
	kit.call(&"trim_paving",placed,64)
	# The household's flat kitchen bed is laid by CityFrontageDressing (a
	# garden_bed prop under the DomesticGarden node) and draws beneath the
	# shared shade layer, so inside the cast it must take the same shade.
	var garden := kit.get_node_or_null(^"DomesticGarden") as Node2D
	var soil: Sprite2D = null
	if garden != null:
		for prop: Node in garden.get_children():
			if prop is Sprite2D and prop.get_meta(&"city_dressing_prop",&"") == &"garden_bed": soil = prop
	_check(soil != null,"the recorded bed home keeps its kitchen garden bed")
	if soil == null:
		view.queue_free()
		Global.attempt_segment = previous
		return
	# Only the building's cast is toggled: the kitchen bed stands at the wall
	# foot, inside the wall-contact band, which stays on in both frames.
	var shades: Array[CanvasItem] = []
	var cores: Array[PackedVector2Array] = []
	for child: Node in kit.get_children():
		if child is Polygon2D and child.has_meta(&"city_sun_shadow") and (child as Polygon2D).texture == null:
			shades.append(child as CanvasItem)
		if child is Polygon2D and child.has_meta(&"city_sun_shadow") and (child as Polygon2D).texture == null:
			var cast := child as Polygon2D
			for face_value: Variant in cast.polygons:
				var face := PackedVector2Array()
				var full := true
				for index: int in (face_value as PackedInt32Array):
					face.append(cast.polygon[index])
					full = full and cast.vertex_colors[index].a > 0.999
				if full: cores.append(face)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var shaded := view.get_texture().get_image()
	for shade: CanvasItem in shades: shade.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var open := view.get_texture().get_image()
	var source: Rect2 = DRESSING.PROPS[&"garden_bed"].rect
	var half := soil.texture.get_size()*0.5
	var top_left := garden.position+soil.position+(source.position-half)*soil.scale
	var bottom_right := garden.position+soil.position+(source.end-half)*soil.scale
	# The painted bed's inner soil, clear of its stone edging.
	var inner := Rect2(top_left,bottom_right-top_left).grow(-6.0)
	var outline := PackedVector2Array([inner.position,Vector2(inner.end.x,inner.position.y),inner.end,Vector2(inner.position.x,inner.end.y)])
	var shade := DEPTH.SUN_SHADE
	var samples := 0
	var matched := 0
	var ratios: Array[float] = []
	for y in range(int(inner.position.y),int(inner.end.y),2):
		for x in range(int(inner.position.x),int(inner.end.x),3):
			var at := Vector2(x+0.5,y+0.5)
			if not Geometry2D.is_point_in_polygon(at,outline): continue
			var inside := false
			for core: PackedVector2Array in cores:
				if Geometry2D.is_point_in_polygon(at,core): inside = true
			if not inside: continue
			var lit := _pixel(view,open,at)
			if lit.g < 0.12: continue
			var dark := _pixel(view,shaded,at)
			samples += 1
			var ratio := Vector3(dark.r/maxf(lit.r,0.001),dark.g/maxf(lit.g,0.001),dark.b/maxf(lit.b,0.001))
			ratios.append(ratio.y)
			if absf(ratio.x-shade.r) < 0.06 and absf(ratio.y-shade.g) < 0.06 and absf(ratio.z-shade.b) < 0.06: matched += 1
	ratios.sort()
	var median := ratios[ratios.size()/2] if not ratios.is_empty() else 1.0
	_check(samples >= 40,"the garden inside the bed home's cast core is sampled; samples=%d" % samples)
	_check(matched >= int(samples*0.95),"the kitchen bed inside the cast takes the shared shade; matched=%d/%d median_g=%.3f want %.3f" % [matched,samples,median,shade.g])
	view.queue_free()
	await get_tree().process_frame
	Global.attempt_segment = previous
