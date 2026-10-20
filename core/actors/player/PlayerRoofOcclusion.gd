extends RefCounted
## Shared per-pixel roof/foreground silhouette. Sprite animation, hurt tint
## and indoor cutaways keep their owners. Legacy actor-local roof probes are
## computed only when diagnostics request them; rendering has no32-triangle cap.

const MAX_TRIANGLES := 32
const SHADER := preload("res://core/actors/player/player_roof_occlusion.gdshader")
var _material: ShaderMaterial
var _triangles: Array[PackedVector2Array] = []
var _strengths := PackedFloat32Array()
var _probe_view: WeakRef
var _probe_feet := Vector2.ZERO
var _probe_bounds := Rect2()
var _probe_dirty := true
var _world_cover: Node

func configure(body: AnimatedSprite2D, head: AnimatedSprite2D) -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	body.material = _material
	head.material = _material

func update(view: Node2D, feet: Vector2, sprite_bounds: Rect2) -> void:
	# Keep the established roof probes while sharing view-wide roof/foreground
	# coverage with batch and pickup consumers. Actor feet remain this visual's
	# measured origin; CharacterBody position is not its ground anchor.
	if not is_instance_valid(_world_cover):
		var script: GDScript = load("res://core/systems/world/visibility/WorldCover.gd")
		_world_cover = script.call("get_for",view)
		_world_cover.call("bind_material",_material)
	_world_cover.call("refresh",view)
	_material.set_shader_parameter("world_cover_feet_y",feet.y)
	_probe_view = weakref(view)
	_probe_feet = feet
	_probe_bounds = sprite_bounds
	_probe_dirty = true
	_triangles.clear()
	_strengths.clear()

func _refresh_roof_diagnostics() -> void:
	if not _probe_dirty or _probe_view == null:
		return
	_probe_dirty = false
	var view := _probe_view.get_ref() as Node2D
	if view == null or not view.is_inside_tree():
		return
	var feet := _probe_feet
	var sprite_bounds := _probe_bounds
	_triangles.clear()
	_strengths.clear()
	for node: Node in view.get_tree().get_nodes_in_group(&"roof_occluders"):
		var roof := node as RoofOverlay
		if roof == null or not roof.is_visible_in_tree() or roof._inside_count > 0: continue
		var poly := roof.get_node("RoofPoly") as Polygon2D
		var strength := float(_world_cover.call("_effective_alpha",poly))
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
				if child.get_meta(&"roof_occlusion_full_form",false):
					# A raised upright return reaches from the projected eave back
					# to its real ground contact. Re-shifting the footprint by roof
					# height would discard its lower face. These explicitly tagged
					# forms already clip doors/chunks and belong to a rectangular
					# wing; the roof's real front-edge check above still applies.
					if not child.is_visible_in_tree(): continue
					var points := PackedVector2Array()
					for point: Vector2 in (child as Polygon2D).polygon: points.append((child as Polygon2D).to_global(point))
					_append_triangles(points,sprite_bounds,strength)
					continue
				var shift := projection + poly.global_transform.basis_xform(Vector2(0, -float(child.get_meta(&"city_roof_lift", 0.0))))
				_append(child as Polygon2D, sprite_bounds, strength, regions, shift)

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
	_refresh_roof_diagnostics()
	var strength := 0.0
	for index in _triangles.size():
		if Geometry2D.is_point_in_polygon(point, _triangles[index]):
			strength = maxf(strength, _strengths[index])
	return strength
