extends Control
## A frozen printed leaf: flat paper joins a short cylindrical fold, then its back.
## The bend travels from the outer edge to the gutter without stretching the sheet.
const COLUMNS := 40
const ROWS := 4
const BEND_SPAN := 0.42
const LIFT_PROJECTION := 0.10
var progress := 1.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var direction := 1:
	set(value):
		direction = -1 if value < 0 else 1
		queue_redraw()
var source_texture: Texture2D:
	set(value):
		source_texture = value
		queue_redraw()
var back_texture: Texture2D:
	set(value):
		back_texture = value
		queue_redraw()
var paper_texture: Texture2D
var _strip_meshes: Array[ArrayMesh] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)

# Integral of the unit tangent (cos(theta), sin(theta)). Inside the bend theta
# advances linearly through PI, giving an actual constant-radius cylinder.
func _bend_integral(distance: float) -> Vector2:
	if distance <= 0.0:
		return Vector2(distance, 0.0)
	if distance >= BEND_SPAN:
		return Vector2(BEND_SPAN - distance, 2.0 * BEND_SPAN / PI)
	var theta := distance * PI / BEND_SPAN
	return Vector2(sin(theta), 1.0 - cos(theta)) * BEND_SPAN / PI

func _column_parameters(fold_start: float) -> PackedFloat32Array:
	var values: Array[float] = []
	for column: int in range(COLUMNS + 1):
		values.append(float(column) / COLUMNS)
	# Split exactly at both cylinder tangencies and its edge-on line. No strip
	# can contain both visible faces, even when the fold falls between columns.
	for boundary: float in [fold_start, fold_start + BEND_SPAN * 0.5, fold_start + BEND_SPAN]:
		if boundary <= 0.00001 or boundary >= 0.99999:
			continue
		var found := false
		for value: float in values:
			if absf(value - boundary) < 0.00001:
				found = true
		if not found:
			values.append(boundary)
	values.sort()
	return PackedFloat32Array(values)

func mesh_geometry(at: float = progress, toward: int = direction) -> Dictionary:
	var t := clampf(at, 0.0, 1.0)
	var sign_x := -1.0 if toward < 0 else 1.0
	var fold_start := 1.0 - t * (1.0 + BEND_SPAN)
	var hinge := Vector2(size.x * (0.5 + sign_x * 0.005 * cos(t * PI)), size.y * 0.08)
	var width := size.x * 0.415
	var height := size.y * 0.84
	var origin := _bend_integral(-fold_start)
	var parameters := _column_parameters(fold_start)
	var count := parameters.size()
	var vertices := PackedVector2Array()
	var surface := PackedVector3Array()
	var front_uvs := PackedVector2Array()
	var back_uvs := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for row: int in range(ROWS + 1):
		var v := float(row) / ROWS
		for u: float in parameters:
			var cross_section := (_bend_integral(u - fold_start) - origin) * width
			var physical := Vector3(hinge.x + sign_x * cross_section.x, hinge.y + v * height, cross_section.y)
			# A slight overhead view makes the lifted fold visible while all
			# frozen lettering remains attached to its original paper position.
			vertices.append(Vector2(physical.x, physical.y - physical.z * LIFT_PROJECTION))
			surface.append(physical)
			front_uvs.append(Vector2(u if toward > 0 else 1.0 - u, v))
			back_uvs.append(Vector2(1.0 - u if toward > 0 else u, v))
			var theta := clampf((u - fold_start) / BEND_SPAN, 0.0, 1.0) * PI
			uvs.append(front_uvs[-1] if theta <= PI * 0.5 else back_uvs[-1])
			var fold_shade := pow(sin(theta), 1.5)
			var shade := 1.0 - 0.38 * fold_shade
			colors.append(Color(shade, shade, shade, 1.0))
	var strips: Array[Dictionary] = []
	for column: int in range(count - 1):
		var midpoint := (parameters[column] + parameters[column + 1]) * 0.5
		var theta := clampf((midpoint - fold_start) / BEND_SPAN, 0.0, 1.0) * PI
		var strip_indices := PackedInt32Array()
		for row: int in range(ROWS):
			var a := row * count + column
			var b := a + 1
			var c := a + count
			strip_indices.append_array(PackedInt32Array([a, c, b, b, c, c + 1]))
		indices.append_array(strip_indices)
		strips.append({"column": column, "front": theta < PI * 0.5, "depth": (surface[column].z + surface[column + 1].z) * 0.5, "indices": strip_indices})
	# The lifted return face hides paper beneath it. Canvas meshes have no
	# depth buffer, so painter ordering is explicit rather than index-order luck.
	strips.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.depth < b.depth if not is_equal_approx(a.depth, b.depth) else a.column < b.column)
	var end_section := (_bend_integral(1.0 - fold_start) - origin) * width
	var flat_fraction := clampf(fold_start, 0.0, 1.0) + 1.0 - clampf(fold_start + BEND_SPAN, 0.0, 1.0)
	return {"vertices": vertices, "surface_vertices": surface, "parameters": parameters,
		"column_count": count, "front_uvs": front_uvs, "back_uvs": back_uvs,
		"uvs": uvs, "colors": colors, "indices": indices, "strips": strips,
		"flat_fraction": flat_fraction, "edge_position": Vector2(hinge.x + sign_x * end_section.x, hinge.y - end_section.y * LIFT_PROJECTION)}

func face_texture(at: float = progress) -> Texture2D:
	# Retained for callers asking for the predominant face. Drawing below uses
	# each strip's own physical facing, never a page-wide midpoint texture swap.
	if at > 0.5:
		return back_texture if back_texture != null else paper_texture
	return source_texture

func _draw() -> void:
	_strip_meshes.clear()
	if progress >= 1.0 or source_texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var geometry := mesh_geometry()
	var vertices: PackedVector2Array = geometry.vertices
	var surface: PackedVector3Array = geometry.surface_vertices
	var shadow_texture := paper_texture if paper_texture != null else source_texture
	# The cast shadow follows the same alpha silhouette as the paper. It grows
	# with actual lift and stays below every printed face, including the curl.
	if progress > 0.0 and shadow_texture != null:
		var shadow_vertices := PackedVector2Array()
		var shadow_colors := PackedColorArray()
		var turn_lift := sin(progress * PI)
		for index: int in vertices.size():
			var lift := surface[index].z
			shadow_vertices.append(vertices[index] + Vector2(direction * lift * 0.045, lift * 0.15 + turn_lift * 2.0))
			var alpha := turn_lift * (0.08 + 0.14 * clampf(lift / (size.x * 0.12), 0.0, 1.0))
			shadow_colors.append(Color(0.15, 0.09, 0.035, alpha))
		var shadow_uvs: PackedVector2Array = geometry.front_uvs.duplicate()
		if direction < 0:
			for index: int in shadow_uvs.size():
				shadow_uvs[index].x = 1.0 - shadow_uvs[index].x
		_draw_surface(_to_3d(shadow_vertices), shadow_uvs, shadow_colors, geometry.indices, shadow_texture)
	var back_uvs: PackedVector2Array = geometry.back_uvs
	if back_texture == null and direction > 0:
		# Blank fallback is the native right leaf, not a captured left page.
		back_uvs = back_uvs.duplicate()
		for index: int in back_uvs.size():
			back_uvs[index].x = 1.0 - back_uvs[index].x
	# Strips keep their painter order. Consecutive strips showing the same face
	# share one mesh (the same triangles in the same order), so a turn draws a
	# few meshes a frame instead of one per strip, each with every vertex.
	var vertices_3d := _to_3d(vertices)
	var run_front := true
	var run_indices := PackedInt32Array()
	for strip: Dictionary in geometry.strips:
		var front: bool = strip.front
		if not run_indices.is_empty() and front != run_front:
			_draw_face(vertices_3d, run_front, geometry.front_uvs, back_uvs, geometry.colors, run_indices)
			run_indices = PackedInt32Array()
		run_front = front
		run_indices.append_array(strip.indices)
	if not run_indices.is_empty():
		_draw_face(vertices_3d, run_front, geometry.front_uvs, back_uvs, geometry.colors, run_indices)

func _draw_face(vertices_3d: PackedVector3Array, front: bool, front_uvs: PackedVector2Array, back_uvs: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var texture := source_texture if front else (back_texture if back_texture != null else paper_texture)
	if texture == null:
		return
	_draw_surface(vertices_3d, front_uvs if front else back_uvs, colors, indices, texture)

static func _to_3d(vertices: PackedVector2Array) -> PackedVector3Array:
	var vertices_3d := PackedVector3Array()
	vertices_3d.resize(vertices.size())
	for index: int in vertices.size():
		vertices_3d[index] = Vector3(vertices[index].x, vertices[index].y, 0.0)
	return vertices_3d

func _draw_surface(vertices_3d: PackedVector3Array, face_uvs: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array, face: Texture2D) -> void:
	var texture := face
	var uvs := face_uvs.duplicate()
	# Canvas mesh UVs need AtlasTexture's native region applied explicitly.
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		for index: int in uvs.size():
			uvs[index] = (atlas.region.position + uvs[index] * atlas.region.size) / atlas.atlas.get_size()
		texture = atlas.atlas
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices_3d
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_strip_meshes.append(mesh)
	draw_mesh(mesh, texture)
