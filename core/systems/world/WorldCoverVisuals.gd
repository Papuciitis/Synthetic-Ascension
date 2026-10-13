extends RefCounted
## Native sprites for cover outside a world batch. Sprite2D already maps
## AtlasTexture UV; the shared shadow material keeps its full-region default.

const DEPTH := preload("res://core/systems/world/WorldDepthStyle.gd")
static var _cast_material: ShaderMaterial


static func apply(body: Node2D, sprite: Sprite2D, texture: Texture2D, rotation: float) -> void:
	var shadow := body.get_node_or_null("Shadow") as Sprite2D
	if body.has_meta(&"_visual_external"):
		sprite.texture = null
		if shadow != null:
			shadow.texture = null
		return
	sprite.texture = texture
	sprite.scale = ChunkBlockVisualCatalog.cell_scale(texture)
	sprite.position = Vector2.ZERO
	sprite.rotation = rotation
	sprite.z_index = ChunkBlockVisualCatalog.PROP_Z
	var upright := texture is AtlasTexture
	if upright:
		sprite.rotation = 0.0
		sprite.position.y = -float(texture.get_height()) * sprite.scale.y * 0.5
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	if shadow == null:
		return
	shadow.texture = texture
	shadow.texture_filter = sprite.texture_filter
	shadow.texture_repeat = sprite.texture_repeat
	shadow.centered = sprite.centered
	shadow.offset = sprite.offset
	shadow.flip_h = sprite.flip_h
	shadow.flip_v = sprite.flip_v
	shadow.z_index = DEPTH.SHADOW_Z
	if upright:
		shadow.transform = DEPTH.project_transform(sprite.transform, Vector2.ZERO)
		if _cast_material == null:
			_cast_material = ShaderMaterial.new()
			_cast_material.shader = DEPTH.SHADOW_SHADER
			_cast_material.set_shader_parameter("texture_region", Vector4(0, 0, 1, 1))
			_cast_material.set_shader_parameter("shadow_color", DEPTH.SHADOW_COLOR)
		shadow.material = _cast_material
		shadow.modulate = Color.WHITE
	else:
		shadow.transform = sprite.transform
		shadow.position += DEPTH.offset_for_height(8.0)
		shadow.material = null
		shadow.modulate = ChunkBlockRenderer.SHADOW_COLOR
