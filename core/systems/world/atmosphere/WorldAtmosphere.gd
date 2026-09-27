extends Node2D
class_name WorldAtmosphere

## A camera-following multiply pass over the world (2026-09-27 world look
## pass). Runs had no light at all - every screen was evenly lit edge to edge,
## which is a large part of why they read flat next to the reference. This is
## one quad: a warm grade plus a vignette centred toward the top-right light.
## It sits above the world and its VFX but on the world canvas, so the HUD's
## CanvasLayers are untouched.

const SHADER := preload("res://core/systems/world/atmosphere/world_atmosphere.gdshader")
const Z := 1400

var _rect: ColorRect
var _material: ShaderMaterial


func _init() -> void:
	name = "WorldAtmosphere"
	z_index = Z
	z_as_relative = false
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.name = "Grade"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	add_child(_rect)


func get_shader_material() -> ShaderMaterial:
	return _material


func _process(_delta: float) -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var camera := viewport.get_camera_2d()
	var size := viewport.get_visible_rect().size
	var centre := Vector2.ZERO
	var zoom := Vector2.ONE
	if camera != null:
		centre = camera.get_screen_center_position()
		zoom = camera.zoom
	var world_size := size / Vector2(maxf(zoom.x, 0.001), maxf(zoom.y, 0.001))
	# A small margin so camera shake never shows an ungraded edge.
	var margin := world_size * 0.05
	global_position = centre - world_size * 0.5 - margin
	_rect.size = world_size + margin * 2.0
	_material.set_shader_parameter("aspect", world_size.x / maxf(1.0, world_size.y))
