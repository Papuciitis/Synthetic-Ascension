extends RefCounted
## One fixed top-right light for the painted world. Upright art projects onto
## the ground southwest from its feet; no live lights or occluders are needed.

const SHADOW_DIRECTION := Vector2(-0.72, 0.50)
const SHADOW_COLOR := Color(0.018, 0.024, 0.032, 0.32)
const SHADOW_Z := -7
const SHADOW_SHADER := preload("res://core/systems/world/actor_cast_shadow.gdshader")


static func projection_at(feet: Vector2) -> Transform2D:
	var projection := Transform2D(Vector2.RIGHT, -SHADOW_DIRECTION, Vector2.ZERO)
	projection.origin = feet - projection.basis_xform(feet)
	return projection


static func project_transform(visual_transform: Transform2D, feet: Vector2) -> Transform2D:
	return projection_at(feet) * visual_transform


static func offset_for_height(height_px: float) -> Vector2:
	return SHADOW_DIRECTION * maxf(0.0, height_px)
