extends Control
## Two RGBA faces (paper and captured print) on one curved turning sheet.
const COLUMNS := 16
const ROWS := 4
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
var _mesh: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)

func mesh_geometry(at: float = progress, toward: int = direction) -> Dictionary:
	var t := clampf(at, 0.0, 1.0)
	var sign_x := -1.0 if toward < 0 else 1.0
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	# A leaf starts at its own paper edge, crosses the narrow binding gutter,
	# then settles at the opposite paper edge without a visible capture jump.
	var hinge := Vector2(size.x * (0.5 + sign_x * 0.005 * cos(t * PI)), size.y * 0.08)
	var width := size.x * 0.415
	var height := size.y * 0.84
	var bend := sin(t * PI)
	for row: int in range(ROWS + 1):
		var v := float(row) / ROWS
		for column: int in range(COLUMNS + 1):
			var u := float(column) / COLUMNS
			# Every strip shares the same face sign. Curvature changes its
			# spacing and bow, never reverses front print before edge-on.
			var reach := cos(t * PI) * width * (u + 0.10 * bend * sin(u * PI))
			var bow := bend * u * (1.0 - u) * height * 0.12
			vertices.append(hinge + Vector2(sign_x * reach, v * height + bow * (v * 2.0 - 1.0)))
			var flip_u := toward < 0
			if t > 0.5:
				flip_u = not flip_u
			uvs.append(Vector2(1.0 - u if flip_u else u, v))
			var shade := 1.0 - bend * (0.08 + 0.16 * sin(u * PI))
			colors.append(Color(shade, shade, shade, 1.0))
	for row: int in range(ROWS):
		for column: int in range(COLUMNS):
			var a := row * (COLUMNS + 1) + column
			var b := a + 1
			var c := a + COLUMNS + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, c + 1]))
	return {"vertices": vertices, "uvs": uvs, "colors": colors, "indices": indices}

func face_texture(at: float = progress) -> Texture2D:
	if at > 0.5:
		# If an incoming page has not been supplied, show opaque blank paper.
		# The departing page's print belongs only on its original front face.
		return back_texture if back_texture != null else paper_texture
	return source_texture

func _draw() -> void:
	var texture := face_texture()
	if progress >= 1.0 or texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var geometry := mesh_geometry()
	var vertices_2d: PackedVector2Array = geometry.vertices
	var vertices_3d := PackedVector3Array()
	for vertex: Vector2 in vertices_2d:
		vertices_3d.append(Vector3(vertex.x, vertex.y, 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices_3d
	var uvs: PackedVector2Array = geometry.uvs
	if progress > 0.5 and back_texture == null and direction > 0:
		# The fallback is the native right leaf, rather than a left-side capture.
		for index: int in uvs.size():
			uvs[index].x = 1.0 - uvs[index].x
	# Mesh drawing uses the backing RID; unlike draw_texture_rect it does not
	# apply AtlasTexture's region to UVs for us.
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		var texture_size := atlas.atlas.get_size()
		for index: int in uvs.size():
			uvs[index] = (atlas.region.position + uvs[index] * atlas.region.size) / texture_size
		texture = atlas.atlas
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = geometry.colors
	arrays[Mesh.ARRAY_INDEX] = geometry.indices
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	draw_mesh(_mesh, texture)
