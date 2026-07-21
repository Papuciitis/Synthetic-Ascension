extends ColorRect

## Simple "dungeon vision" overlay.
## - Darkens the whole screen.
## - Cuts a soft circle around the player/camera center.
##
## This is intentionally NOT an occlusion / line-of-sight system yet.
## It's meant to give the classic roguelike readability (walls pop, ground calms down)
## while we keep collisions/debug visuals untouched.

@export var enabled: bool = true

@export_group("Look")
@export_range(0.0, 1.0, 0.01) var darkness: float = 0.68
@export_range(64.0, 1400.0, 1.0) var light_radius_px: float = 430.0
@export_range(0.0, 900.0, 1.0) var light_softness_px: float = 220.0
@export_range(0.0, 1.0, 0.01) var vignette_strength: float = 0.22

@export_group("Tint")
@export var shadow_tint: Color = Color(0.0, 0.0, 0.0, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_uniforms()


func _process(_dt: float) -> void:
	# We keep the light center at the viewport center on purpose.
	# Player camera is centered 99% of the time; if you later add camera limits,
	# we can switch to world->screen conversion.
	_update_uniforms()


func _update_uniforms() -> void:
	visible = enabled
	if not visible:
		return

	var mat := material as ShaderMaterial
	if mat == null:
		return

	# Shadow alpha comes from `darkness`; RGB comes from `shadow_tint`.
	mat.set_shader_parameter("shadow_color", Color(shadow_tint.r, shadow_tint.g, shadow_tint.b, darkness))
	mat.set_shader_parameter("radius_px", light_radius_px)
	mat.set_shader_parameter("softness_px", light_softness_px)
	mat.set_shader_parameter("vignette_strength", vignette_strength)
