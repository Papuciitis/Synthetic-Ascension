extends RefCounted
## Live texture descriptors for the bounded foreground class. Consumers cache
## shared texture images; describing a sprite only reads geometry and state.

const GROUP := &"foreground_occluders"
const GROUND_CONTACT := &"foreground_ground_contact"

static func register(sprite: Sprite2D, ground_parent_local: Vector2) -> void:
	if not is_instance_valid(sprite):
		return
	sprite.set_meta(GROUND_CONTACT, ground_parent_local)
	sprite.add_to_group(GROUP)

static func describe(sprite: Sprite2D) -> Dictionary:
	if not is_instance_valid(sprite) or not sprite.is_inside_tree() or not sprite.is_visible_in_tree():
		return {}
	if sprite.texture == null or not sprite.has_meta(GROUND_CONTACT):
		return {}
	var parent := sprite.get_parent() as CanvasItem
	if parent == null:
		return {}
	var strength := sprite.self_modulate.a
	var item: CanvasItem = sprite
	while item != null:
		if item.is_queued_for_deletion():
			return {}
		strength *= item.modulate.a
		if item.top_level:
			break
		item = item.get_parent() as CanvasItem
	strength = clampf(strength, 0.0, 1.0)
	if strength <= 0.0 or is_zero_approx(sprite.global_transform.determinant()):
		return {}
	var texture := sprite.texture
	var source := sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, texture.get_size())
	source.size /= Vector2(sprite.hframes, sprite.vframes)
	source.position += Vector2(sprite.frame_coords) * source.size
	if not source.has_area():
		return {}
	# AtlasTexture.get_image() returns the cropped region without its logical
	# transparent margins. Clip the draw to the actual artwork, then express
	# source_rect in that cropped image's coordinates for the shared GPU cache.
	var image_origin := Vector2.ZERO
	var image_size := texture.get_size()
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		if atlas.atlas == null:
			return {}
		image_origin = atlas.margin.position
		image_size = atlas.region.size.floor()
		if image_size.x == 0.0:
			image_size.x = atlas.atlas.get_width()
		if image_size.y == 0.0:
			image_size.y = atlas.atlas.get_height()
	var clipped := source.intersection(Rect2(image_origin, image_size))
	if not clipped.has_area():
		return {}
	var inset := clipped.position - source.position
	if sprite.flip_h:
		inset.x = source.size.x - inset.x - clipped.size.x
	if sprite.flip_v:
		inset.y = source.size.y - inset.y - clipped.size.y
	# get_rect's offset includes the viewport's current pixel-snap setting.
	var draw_rect := Rect2(sprite.get_rect().position + inset, clipped.size)
	var inverse_size := Vector2.ONE / draw_rect.size
	var local_to_uv := Transform2D(Vector2(inverse_size.x, 0), Vector2(0, inverse_size.y), -draw_rect.position * inverse_size)
	if sprite.flip_h:
		local_to_uv.x.x *= -1.0
		local_to_uv.origin.x = 1.0 - local_to_uv.origin.x
	if sprite.flip_v:
		local_to_uv.y.y *= -1.0
		local_to_uv.origin.y = 1.0 - local_to_uv.origin.y
	var transform := sprite.global_transform
	var bounds := Rect2(transform * draw_rect.position, Vector2.ZERO)
	for corner: Vector2 in [Vector2(draw_rect.end.x, draw_rect.position.y), draw_rect.end, Vector2(draw_rect.position.x, draw_rect.end.y)]:
		bounds = bounds.expand(transform * corner)
	var ground_parent_local: Vector2 = sprite.get_meta(GROUND_CONTACT)
	return {
		"owner": weakref(sprite),
		"texture": texture,
		"world_to_uv": local_to_uv * transform.affine_inverse(),
		"source_rect": Rect2(clipped.position - image_origin, clipped.size),
		"front_y": (parent.get_global_transform() * ground_parent_local).y,
		"strength": strength,
		"bounds": bounds,
	}
