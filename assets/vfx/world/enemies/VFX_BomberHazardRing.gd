extends Node2D
class_name VFX_BomberHazardRing

@export var base_alpha: float = 0.38
@export var hot_alpha: float = 0.95
@export var line_width: float = 3.0
@export var glow_width: float = 10.0
@export var dash_count: int = 18
@export var dash_gap: float = 0.25

@export var color_core: Color = Color(1.00, 0.35, 0.20, 1.0)
@export var color_glow: Color = Color(1.00, 0.15, 0.85, 0.60)

var _enemy: EnemyActor = null
var _r: float = 96.0
var _t: float = 0.0
var _perimeter: Sprite2D
var _fuse_core: Sprite2D

const PERIMETER_PATH := "res://assets/textures/vfx/encounters/bomber_perimeter_v1.png"
const PERIMETER_CONTENT_RADIUS := 564.820768
const BLAST_PATH := "res://assets/textures/vfx/encounters/bomber_blast_v1.png"
const BLAST_CONTENT_RADIUS := 534.266319

# Distant warnings are hidden; the actual danger boundary never shrinks.
const DRAW_MAX_PLAYER_DIST := 1200.0

func setup(e: EnemyActor) -> void:
	_enemy = e
	if _enemy != null and _enemy.spec != null:
		_r = maxf(_enemy.spec.explode_radius, 8.0)
	_t = 0.0
	_update_sprites()

func _ready() -> void:
	# As child of enemy: local position is fine
	position = Vector2.ZERO
	z_index = -1
	process_mode = Node.PROCESS_MODE_PAUSABLE
	material = null
	_perimeter = Sprite2D.new()
	_perimeter.name = "BlastPerimeter"
	_perimeter.texture = load(PERIMETER_PATH) as Texture2D if ResourceLoader.exists(PERIMETER_PATH) else null
	_perimeter.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_perimeter)
	_fuse_core = Sprite2D.new()
	_fuse_core.name = "FuseEmbers"
	_fuse_core.texture = load(BLAST_PATH) as Texture2D if ResourceLoader.exists(BLAST_PATH) else null
	_fuse_core.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Live enemies render through the z=10 proxy. Keep the lit fuse above
	# that body while the blast perimeter remains on the ground behind it.
	_fuse_core.z_as_relative = false
	_fuse_core.z_index = 11
	_fuse_core.position = Vector2(0.0, -20.0)
	_fuse_core.scale = Vector2.ONE * minf(18.0, _r * 0.2) / BLAST_CONTENT_RADIUS
	add_child(_fuse_core)
	set_process(true)
	_update_sprites()

func _process(dt: float) -> void:
	if is_inside_tree() and get_tree().paused:
		return
	_t += dt
	if _enemy == null or not is_instance_valid(_enemy) or _enemy.dead:
		queue_free()
		return
	var player := _enemy.player
	if player == null or not is_instance_valid(player):
		visible = false
		return
	var dist_sq := _enemy.global_position.distance_squared_to(player.global_position)
	if dist_sq > DRAW_MAX_PLAYER_DIST * DRAW_MAX_PLAYER_DIST:
		if visible:
			visible = false
		return
	if not visible:
		visible = true
	_update_sprites()


func _update_sprites() -> void:
	if _perimeter == null or _enemy == null or not is_instance_valid(_enemy):
		return
	var bomber: EnemyBomber = _enemy.get("_bomber") as EnemyBomber
	var lit := bomber != null and bomber.is_fuse_lit()
	var progress := bomber.fuse_progress() if lit else 0.0
	# The perimeter always marks the damage edge; only brightness changes.
	_perimeter.scale = Vector2.ONE * _r / PERIMETER_CONTENT_RADIUS
	_perimeter.rotation = 0.0
	var alpha := lerpf(maxf(base_alpha, 0.25), hot_alpha, 0.25 + 0.75 * progress) if lit else maxf(base_alpha, 0.25)
	_perimeter.modulate = Color(1.0, 1.0, 1.0, alpha)
	_fuse_core.visible = lit
	var reduced := bool(SettingsManager.get_value(&"accessibility", &"reduced_motion", false))
	_fuse_core.rotation = 0.0 if reduced else _t * 0.35
	_fuse_core.modulate = Color(1.0, 1.0, 1.0, AccessibilityPresentation.current_flash_alpha(0.3 + 0.5 * progress))
