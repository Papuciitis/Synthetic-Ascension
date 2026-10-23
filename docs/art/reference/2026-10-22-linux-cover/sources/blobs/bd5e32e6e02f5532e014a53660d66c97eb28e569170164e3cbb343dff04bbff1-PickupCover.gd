extends RefCounted
## The icon's owner keeps gameplay, transforms, eligibility and modulation.
## Only otherwise unowned materials receive the shared cover presentation.

const SHADER := preload("res://core/systems/world/visibility/pickup_cover.gdshader")
const WORLD_COVER := preload("res://core/systems/world/visibility/WorldCover.gd")

var _owner: WeakRef
var _material: ShaderMaterial
var _world_cover: Node


func configure(owner: Node2D, icon: Sprite2D, duplicate_glow: Sprite2D = null) -> void:
	var surfaces: Array[Sprite2D] = []
	for sprite: Sprite2D in [icon, duplicate_glow]:
		if sprite != null and sprite.material == null and not sprite.use_parent_material:
			surfaces.append(sprite)
	if owner == null or surfaces.is_empty():
		return
	_owner = weakref(owner)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("world_cover_feet_y", owner.global_position.y)
	for sprite: Sprite2D in surfaces:
		sprite.material = _material


func update() -> void:
	if _owner == null or _material == null:
		return
	var owner := _owner.get_ref() as Node2D
	if owner == null or not owner.is_inside_tree() or owner.is_queued_for_deletion():
		return
	if not is_instance_valid(_world_cover):
		_world_cover = WORLD_COVER.get_for(owner)
		_world_cover.call("bind_material", _material)
	_world_cover.call("refresh", owner)
	_material.set_shader_parameter("world_cover_feet_y", owner.global_position.y)
