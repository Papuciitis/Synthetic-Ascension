extends RoofOverlay
## A streamed piece of one complete roof wing. All pieces resolve occupancy
## against the same complete wing coverage, including the first reload frame.

const SLATE := preload("res://assets/world/city_block/slate.png")
var coverage_world: Array[Rect2] = []
var _player: Node2D

func _init() -> void:
	var polygon := Polygon2D.new()
	polygon.name = "RoofPoly"
	add_child(polygon)
	var edge := Line2D.new()
	edge.name = "FrontEdge"
	add_child(edge)
	set_process(false)

func configure_slice(wing: Rect2, clip: Rect2, coverage: Array[Rect2], lift: float, clay: bool = false, holes: Array[Rect2] = [], raised: float = 0.0, stone: Texture2D = null) -> void:
	coverage_world = coverage
	add_to_group(&"roof_occluders")
	var visible_roof := Rect2(wing.position+Vector2(12,lift),wing.size-Vector2(24,lift+14))
	var total_lift := lift+raised
	var render_clip := Rect2(clip.position+Vector2(0,total_lift),clip.size)
	var outline := PackedVector2Array([visible_roof.position,Vector2(visible_roof.end.x,visible_roof.position.y),visible_roof.end,Vector2(visible_roof.position.x,visible_roof.end.y)])
	var tip := Vector2(visible_roof.get_center().x,visible_roof.end.y-44)
	if raised > 0:
		outline = PackedVector2Array([outline[0],outline[1],outline[2],tip,outline[3]])
	footprint_outline_px = PackedVector2Array([wing.position,Vector2(wing.end.x,wing.position.y),wing.end,Vector2(wing.position.x,wing.end.y)])
	var clip_points := PackedVector2Array([render_clip.position,Vector2(render_clip.end.x,render_clip.position.y),render_clip.end,Vector2(render_clip.position.x,render_clip.end.y)])
	var pieces := Geometry2D.intersect_polygons(outline,clip_points)
	for hole: Rect2 in holes:
		var cut := Rect2(hole.position+Vector2(0,total_lift),hole.size)
		var next: Array[PackedVector2Array] = []
		for piece: PackedVector2Array in pieces:
			next.append_array(Geometry2D.clip_polygons(piece,PackedVector2Array([cut.position,Vector2(cut.end.x,cut.position.y),cut.end,Vector2(cut.position.x,cut.end.y)])))
		pieces = next
	_poly.polygon = pieces[0] if not pieces.is_empty() else PackedVector2Array()
	_poly.position = Vector2(0,-total_lift)
	_poly.z_index = ROOF_Z
	_poly.texture = preload("res://assets/world/city_block/clay.png") if clay else SLATE
	_poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_poly.texture_scale = Vector2.ONE*3.2
	_poly.color = Color(0.87,0.94,0.99)
	var material := ShaderMaterial.new()
	material.shader = ROOF_SHADER
	material.set_shader_parameter("bounds",Vector4(visible_roof.position.x,visible_roof.position.y,visible_roof.end.x,visible_roof.end.y))
	material.set_shader_parameter("gable",1.0)
	material.set_shader_parameter("ridge_along_x",1.0 if wing.size.x > wing.size.y else 0.0)
	material.set_shader_parameter("material_contrast",0.30)
	material.set_shader_parameter("material_mid",Vector3(0.43,0.28,0.21) if clay else Vector3(0.25,0.31,0.34))
	material.set_shader_parameter("ridge_light",0.16)
	_poly.material = material
	for index in range(1,pieces.size()):
		var continuation := Polygon2D.new()
		continuation.polygon = pieces[index]
		continuation.texture = _poly.texture
		continuation.texture_repeat = _poly.texture_repeat
		continuation.texture_scale = _poly.texture_scale
		continuation.color = _poly.color
		continuation.material = material
		continuation.set_meta(&"city_roof_form",&"dungeon_continuation")
		_poly.add_child(continuation)
	if raised > 0:
		# The cap is actually raised in projection. Its masonry return fades
		# with the roof and participates in the same actor-occlusion contract.
		var face := Rect2(visible_roof.position.x,visible_roof.end.y,visible_roof.size.x,total_lift)
		_add_raised_face(PackedVector2Array([face.position,Vector2(face.end.x,face.position.y),face.end,Vector2(face.position.x,face.end.y)]),render_clip,face,stone,holes,total_lift)
		_add_raised_face(PackedVector2Array([Vector2(face.position.x,face.position.y),tip,Vector2(face.end.x,face.position.y)]),render_clip,face,stone,holes,total_lift)
	_edge.visible = false
	_sync_occupancy(true)
	set_process(true)

func _add_raised_face(points: PackedVector2Array, clip: Rect2, area: Rect2, stone: Texture2D, holes: Array[Rect2], total_lift: float) -> void:
	var clip_points := PackedVector2Array([clip.position,Vector2(clip.end.x,clip.position.y),clip.end,Vector2(clip.position.x,clip.end.y)])
	var pieces := Geometry2D.intersect_polygons(points,clip_points)
	for hole: Rect2 in holes:
		var cut := Rect2(hole.position+Vector2(0,total_lift),hole.size)
		var next: Array[PackedVector2Array] = []
		for piece: PackedVector2Array in pieces:
			next.append_array(Geometry2D.clip_polygons(piece,PackedVector2Array([cut.position,Vector2(cut.end.x,cut.position.y),cut.end,Vector2(cut.position.x,cut.end.y)])))
		pieces = next
	for piece: PackedVector2Array in pieces:
		var face := Polygon2D.new()
		face.polygon = piece
		face.color = Color("b6b69c") if stone == null else Color.WHITE
		if stone != null:
			face.texture = stone
			face.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			var uv := PackedVector2Array()
			for point: Vector2 in piece: uv.append(Vector2(64,128)+(point-Vector2(area.position.x,area.position.y-44))*(414.0/maxf(1,area.size.y+44)))
			face.uv = uv
		face.set_meta(&"city_roof_form",&"dungeon_gatehouse_return")
		face.set_meta(&"roof_occlusion_full_form",true)
		_poly.add_child(face)

func _process(_delta: float) -> void:
	_sync_occupancy(false)

func _sync_occupancy(initial: bool) -> void:
	if not is_instance_valid(_player): _player = get_tree().get_first_node_in_group(&"player") as Node2D
	var inside := 0
	if _player != null:
		for rect: Rect2 in coverage_world:
			if rect.has_point(_player.global_position): inside = 1; break
	if initial:
		_inside_count = inside
		_set_alpha(0.0 if inside else 1.0)
	elif inside != _inside_count:
		_inside_count = inside
		_update_target()
