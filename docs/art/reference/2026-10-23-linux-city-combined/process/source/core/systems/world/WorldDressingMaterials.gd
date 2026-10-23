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


## A material depends only on its region (the batch supplies the texture), so
## one is shared per region: chunk loads stop allocating a material per
## species, and equal materials keep batching together.
static var _visual_by_region: Dictionary = {}
static var _shadow_by_region: Dictionary = {}


static func visual_material(texture: Texture2D) -> ShaderMaterial:
	if not texture is AtlasTexture:
		return null
	var region := texture_region(texture)
	var material := _visual_by_region.get(region) as ShaderMaterial
	if material == null:
		material = ShaderMaterial.new()
		material.shader = REGION_SHADER
		material.set_shader_parameter("texture_region", region)
		_visual_by_region[region] = material
	return material


static func shadow_material(texture: Texture2D) -> ShaderMaterial:
	var region := texture_region(texture)
	var material := _shadow_by_region.get(region) as ShaderMaterial
	if material == null:
		material = ShaderMaterial.new()
		material.shader = DEPTH.SHADOW_SHADER
		material.set_shader_parameter("texture_region", region)
		material.set_shader_parameter("shadow_color", DEPTH.SHADOW_COLOR)
		_shadow_by_region[region] = material
	return material


## Application shutdown (Global._exit_tree): RID-backed statics go while the
## rendering servers are still whole.
static func release_static_caches() -> void:
	_visual_by_region.clear()
	_shadow_by_region.clear()
