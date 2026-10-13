extends RefCounted

const ART := preload("res://core/systems/world/WorldArt.gd")
const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")
const MATERIALS := preload("res://core/systems/world/WorldDressingMaterials.gd")

## Chunk-owned batches: unloading a chunk releases its dressing, and the
## renderer can cull each small batch independently. No texture readbacks,
## resized atlases, per-plant nodes, collision, or frame processing.
static func add_to_chunk(chunk: Node2D, placements: Array[Dictionary], cell_size: int, tint: Color) -> void:
	if placements.is_empty():
		return
	var root := Node2D.new()
	root.name = "FoliageBatches"
	chunk.add_child(root)
	var by_species: Dictionary = {}
	for placement in placements:
		var species := int(placement.species)
		if not by_species.has(species): by_species[species] = []
		(by_species[species] as Array).append(placement)
	for species in by_species:
		var texture: Texture2D = ART.vegetation_texture(species)
		if texture == null:
			continue
		var members: Array = by_species[species]
		var mesh := QuadMesh.new()
		mesh.size = Vector2(float(cell_size), float(cell_size) * float(texture.get_height()) / maxf(1.0, float(texture.get_width())))
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.use_colors = true
		multimesh.mesh = mesh
		multimesh.instance_count = members.size()
		var shadow_mesh := MultiMesh.new()
		shadow_mesh.transform_format = MultiMesh.TRANSFORM_2D
		shadow_mesh.use_colors = true
		shadow_mesh.mesh = mesh
		shadow_mesh.instance_count = members.size()
		for index in range(members.size()):
			var placement: Dictionary = members[index]
			var at := (Vector2(placement.cell) + Vector2(0.5, 0.5)) * float(cell_size)
			var scale_value := float(placement.scale)
			# QuadMesh UVs are Y-up; compensate so trees keep their authored orientation.
			var centre := at - Vector2(0, mesh.size.y * scale_value * 0.5)
			var transform := Transform2D(0.0, centre).scaled_local(Vector2(scale_value, -scale_value))
			multimesh.set_instance_transform_2d(index, transform)
			multimesh.set_instance_color(index, Color(tint.r, tint.g, tint.b, float(placement.alpha)))
			shadow_mesh.set_instance_transform_2d(index, DEPTH.project_transform(transform, at))
			shadow_mesh.set_instance_color(index, Color(1, 1, 1, float(placement.alpha)))
		for pair in [[multimesh, -85, "Plants"], [shadow_mesh, -86, "Shadows"]]:
			var node := MultiMeshInstance2D.new()
			node.name = "%s_%d" % [pair[2], species]
			node.z_index = pair[1]
			node.multimesh = pair[0]
			node.texture = MATERIALS.base_texture(texture)
			node.material = MATERIALS.visual_material(texture) if pair[2] == "Plants" else MATERIALS.shadow_material(texture)
			node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			root.add_child(node)
