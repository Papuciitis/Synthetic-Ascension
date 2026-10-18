extends Sprite2D
## A snapshot of the defeated raster form. No collision, damage or reward
## ownership; survives its actor just long enough to give the death weight.
const DISSOLVE := preload("res://scenes/world/bosses/boss_defeat.gdshader")
var _snapshot := Transform2D.IDENTITY
var _elapsed := 0.0
var _duration := 0.75

func setup(source: Sprite2D, tank: bool) -> void:
	texture = source.texture
	centered = source.centered
	offset = source.offset
	_snapshot = source.global_transform
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = DISSOLVE
	(material as ShaderMaterial).set_shader_parameter("ash_color", Color(0.9, 0.39, 0.12) if tank else Color(0.56, 0.33, 0.82))

func _ready() -> void:
	name = "BossDefeatAfterimage"
	add_to_group(&"boss_defeat_afterimage")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	top_level = true
	global_transform = _snapshot
	z_index = 2

func _process(delta: float) -> void:
	_elapsed += delta
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)
	if progress >= 1.0:
		queue_free()
		return
	var reduced := bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))
	# Drift and collapse are small and cosmetic. Reduced Motion retains only
	# the finite fade, keeping the fallen form at its exact world transform.
	global_transform = _snapshot
	if not reduced:
		global_position += Vector2(0, -5.0 * progress)
		global_scale *= Vector2(1.0 + progress * 0.025, 1.0 - progress * 0.045)
	var shader := material as ShaderMaterial
	shader.set_shader_parameter("dissolve", -0.16 + progress * 1.4 if not reduced else -0.16)
	modulate.a = pow(1.0 - progress, 0.65 if not reduced else 1.1)
