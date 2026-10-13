extends RefCounted
## MultiMeshInstance2D uses an AtlasTexture's full RID. Remap its region once
## per shared material, keeping the source pixels and the batching unchanged.

const REGION_SHADER := preload("res://core/systems/world/world_dressing_region.gdshader")
const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")


static func base_texture(texture: Texture2D) -> Texture2D:
	return (texture as AtlasTexture).atlas if texture is AtlasTexture else texture


static func texture_region(texture: Texture2D) -> Vector4:
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		var size := atlas.atlas.get_size()
		return Vector4(atlas.region.position.x / size.x, atlas.region.position.y / size.y, atlas.region.size.x / size.x, atlas.region.size.y / size.y)
	return Vector4(0, 0, 1, 1)


static func visual_material(texture: Texture2D) -> ShaderMaterial:
	if not texture is AtlasTexture:
		return null
	var material := ShaderMaterial.new()
	material.shader = REGION_SHADER
	material.set_shader_parameter("texture_region", texture_region(texture))
	return material


static func shadow_material(texture: Texture2D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = DEPTH.SHADOW_SHADER
	material.set_shader_parameter("texture_region", texture_region(texture))
	material.set_shader_parameter("shadow_color", DEPTH.SHADOW_COLOR)
	return material
