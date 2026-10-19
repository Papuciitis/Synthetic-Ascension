extends RefCounted
## Roof-only per-pixel silhouette. Sprite animation, hurt tint and indoor
## cutaways keep their owners; no actor depth or physical geometry changes.

const MAX_TRIANGLES := 32
const SHADER := preload("res://core/actors/player/player_roof_occlusion.gdshader")
var _material: ShaderMaterial
var _triangles: Array[PackedVector2Array] = []
var _strengths := PackedFloat32Array()
var _last_count := 0

func configure(body: AnimatedSprite2D, head: AnimatedSprite2D) -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	body.material = _material
	head.material = _material

func update(view: Node2D, feet: Vector2, sprite_bounds: Rect2) -> void:
	_triangles.clear()
	_strengths.clear()
	for node: Node in view.get_tree().get_nodes_in_group(&"roof_occluders"):
		var roof := node as RoofOverlay
		if roof == null or not roof.is_visible_in_tree() or roof._inside_count > 0: continue
		var poly := roof.get_node("RoofPoly") as Polygon2D
		var strength := poly.modulate.a
		if strength < 0.01 or roof.footprint_outline_px.is_empty(): continue
		var footprint := Rect2(roof.to_global(roof.footprint_outline_px[0]), Vector2.ZERO)
		for point: Vector2 in roof.footprint_outline_px: footprint = footprint.expand(roof.to_global(point))
		# A character standing in front of a building must stay in front.
		if feet.y >= footprint.end.y or not footprint.grow(180).intersects(sprite_bounds): continue
		var regions := _behind_regions(roof, feet.y)
		var projection := poly.global_position - roof.global_position
		_append(poly, sprite_bounds, strength, regions, projection)
		for child: Node in poly.find_children("*", "Polygon2D", true, false):
			if child.has_meta(&"city_roof_form"):
				var shift := projection + poly.global_transform.basis_xform(Vector2(0, -float(child.get_meta(&"city_roof_lift", 0.0))))
				_append(child as Polygon2D, sprite_bounds, strength, regions, shift)
	if _triangles.is_empty():
		if _last_count > 0: _material.set_shader_parameter("triangle_count", 0)
		_last_count = 0
		return
	var ab := PackedVector4Array()
	var ca := PackedVector4Array()
	ab.resize(MAX_TRIANGLES)
	ca.resize(MAX_TRIANGLES)
	for index in _triangles.size():
		var points := _triangles[index]
		ab[index] = Vector4(points[0].x, points[0].y, points[1].x, points[1].y)
		ca[index] = Vector4(points[2].x, points[2].y, _strengths[index], 0)
	_material.set_shader_parameter("triangle_count", _triangles.size())
	_material.set_shader_parameter("triangle_ab", ab)
	_material.set_shader_parameter("triangle_ca", ca)
	_last_count = _triangles.size()

func _behind_regions(roof: RoofOverlay, feet_y: float) -> Array[Rect2]:
	# Partition the real footprint into vertical filled spans. Each span's
	# own south edge determines depth, including L recesses and courtyards.
	var points := PackedVector2Array()
	var xs: Array[float] = []
	for point: Vector2 in roof.footprint_outline_px:
		var world := roof.to_global(point)
		points.append(world)
		if not xs.has(world.x): xs.append(world.x)
	xs.sort()
	var regions: Array[Rect2] = []
	for index in range(xs.size()-1):
		var x := (xs[index] + xs[index+1]) * 0.5
		var ys: Array[float] = []
		for edge in points.size():
			var a := points[edge]
			var b := points[(edge+1) % points.size()]
			if is_equal_approx(a.x, b.x) or x < minf(a.x,b.x) or x >= maxf(a.x,b.x): continue
			ys.append(lerpf(a.y,b.y,(x-a.x)/(b.x-a.x)))
		ys.sort()
		for pair in range(0, ys.size()-1, 2):
			if feet_y >= ys[pair+1]: continue
			regions.append(Rect2(xs[index],ys[pair],xs[index+1]-xs[index],ys[pair+1]-ys[pair]))
	return regions

func _append(poly: Polygon2D, bounds: Rect2, strength: float, regions: Array[Rect2], projection: Vector2) -> void:
	if not poly.is_visible_in_tree() or _triangles.size() >= MAX_TRIANGLES: return
	var points := PackedVector2Array()
	for point: Vector2 in poly.polygon: points.append(poly.to_global(point))
	for region: Rect2 in regions:
		var area := Rect2(region.position + projection, region.size)
		if not area.intersects(bounds): continue
		var rectangle := PackedVector2Array([area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)])
		for part: PackedVector2Array in Geometry2D.intersect_polygons(points,rectangle):
			_append_triangles(part,bounds,strength)

func _append_triangles(points: PackedVector2Array, bounds: Rect2, strength: float) -> void:
	var indices := Geometry2D.triangulate_polygon(points)
	for index in range(0, indices.size(), 3):
		if _triangles.size() >= MAX_TRIANGLES: return
		var triangle := PackedVector2Array([points[indices[index]], points[indices[index+1]], points[indices[index+2]]])
		var area := Rect2(triangle[0], Vector2.ZERO).expand(triangle[1]).expand(triangle[2])
		if not area.intersects(bounds): continue
		_triangles.append(triangle)
		_strengths.append(strength)
		if _triangles.size() >= MAX_TRIANGLES: return

func strength_at(point: Vector2) -> float:
	var strength := 0.0
	for index in _triangles.size():
		if Geometry2D.is_point_in_polygon(point, _triangles[index]):
			strength = maxf(strength, _strengths[index])
	return strength
