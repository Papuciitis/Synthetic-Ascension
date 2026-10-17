extends Node2D
## A persistent sector bound assembled from the authored raster sprites: the
## engraved boundary seal, the slam fracture identity and a danger wash, each
## clipped to the circular sector the attack's damage polygon covers, with
## its two radial edges. Like BossGroundWarning it owns no damage, and the
## controlling brain drives its progress on the gameplay clock.

const Scope = preload("res://scenes/world/bosses/BossAttackScope.gd")
const MASK_SHADER = preload("res://scenes/world/bosses/boss_sector_mask.gdshader")
const SEAL_TEXTURE = preload("res://scenes/world/bosses/art/vfx/hazard_seal_v1.png")
const FRACTURE_TEXTURE = preload("res://scenes/world/bosses/art/vfx/slam_fracture_v1.png")
const EDGE_TEXTURE = preload("res://scenes/world/bosses/art/vfx/arcane_beam_body.tres")
# Measured content radii of the unchanged sources (BossGroundWarning).
const SEAL_CONTENT_RADIUS := 570.1
const FRACTURE_CONTENT_RADIUS := 594.427876
const WARNING_COLOR := Color(1.0, 0.40, 0.20, 0.78)

var _world_origin := Vector2.ZERO
var _facing := 0.0
var _radius := 125.0
var _half_angle := 1.3
var _material: ShaderMaterial
var _fill: Sprite2D
var _identity: Sprite2D
var _seal: Sprite2D
var _edges: Array[Sprite2D] = []


func setup(world_pos: Vector2, facing: float, radius: float, half_angle: float) -> void:
	_world_origin = world_pos
	_facing = facing
	_radius = maxf(radius, 1.0)
	_half_angle = clampf(half_angle, 0.0, PI)
	if is_node_ready():
		_configure()


func _ready() -> void:
	top_level = true
	z_index = -1
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_material = ShaderMaterial.new()
	_material.shader = MASK_SHADER
	_fill = _sprite("Fill", VfxKit.texture("disc"), _material)
	_identity = _sprite("AttackIdentity", FRACTURE_TEXTURE, _material)
	_seal = _sprite("Boundary", SEAL_TEXTURE, _material)
	for index in range(2):
		_edges.append(_sprite("Edge%d" % index, EDGE_TEXTURE, null))
	_configure()


func _sprite(label: String, texture: Texture2D, material_value: Material) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = label
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.material = material_value
	add_child(sprite)
	return sprite


func _configure() -> void:
	global_position = _world_origin
	rotation = _facing
	_material.set_shader_parameter("half_angle", _half_angle)
	_fill.scale = Vector2.ONE * _radius / VfxKit.DISC_HALF
	_identity.scale = Vector2.ONE * _radius / FRACTURE_CONTENT_RADIUS
	_seal.scale = Vector2.ONE * _radius / SEAL_CONTENT_RADIUS
	for index in range(2):
		var tip := Vector2.from_angle(_half_angle if index == 0 else -_half_angle) * _radius
		var edge := _edges[index]
		edge.position = tip * 0.5
		edge.rotation = tip.angle()
		edge.scale = Vector2(_radius / float(EDGE_TEXTURE.get_width()), 3.0 / float(EDGE_TEXTURE.get_height()))
	set_progress(0.0)


## Same reading as a circular warning: essential bounds stay legible with
## flashes off; the wash and the identity art carry the rising threat.
func set_progress(value: float, active: bool = false) -> void:
	if _seal == null:
		return
	var progress := clampf(value, 0.0, 1.0)
	var bound := WARNING_COLOR
	bound.a = lerpf(0.65, 0.95, progress)
	_seal.modulate = bound
	for edge in _edges:
		edge.modulate = bound
	var wash := WARNING_COLOR
	wash.a = AccessibilityPresentation.current_flash_alpha(0.18 if active else lerpf(0.08, 0.16, progress))
	_fill.modulate = wash
	_identity.modulate = Color(1, 1, 1, maxf(0.32, AccessibilityPresentation.current_flash_alpha(0.82 if active else lerpf(0.32, 0.70, progress))))


func _process(_delta: float) -> void:
	if not Scope.is_valid_attack(self):
		cancel_attack()


func cancel_attack() -> void:
	visible = false
	queue_free()
