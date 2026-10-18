extends Node2D
## Finite cosmetic aftermath. Damage remains in the separately owned hazard.
const Scope = preload("res://scenes/world/bosses/BossAttackScope.gd")
const SLAM = preload("res://scenes/world/bosses/art/vfx/slam_fracture_v1.png")
const SHOCK = preload("res://scenes/world/bosses/art/vfx/shock_crackle_v1.png")
const MINE = preload("res://scenes/world/bosses/art/vfx/mine_sigil_v1.png")
## A rush's cosmetic stop: the braced-footing ripple, unlike any damage art.
const SKID = preload("res://assets/textures/vfx/encounters/pulse_ripple_v1.png")
const SKID_CONTENT_RADIUS := 562.741948

var duration := 0.42
var _origin := Vector2.ZERO
var _radius := 90.0
var _kind: StringName = &"slam"
var _elapsed := 0.0
var _sprite: Sprite2D

func setup(world_pos: Vector2, radius: float, kind: StringName, seconds: float = 0.42) -> void:
	_origin = world_pos
	_radius = maxf(0.0, radius)
	_kind = kind
	duration = maxf(0.05, seconds)
	_elapsed = 0.0
	if is_node_ready():
		global_position = _origin
		_configure()

func _ready() -> void:
	top_level = true
	global_position = _origin
	z_as_relative = false
	z_index = 1
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_sprite = Sprite2D.new()
	_sprite.name = "ImpactArtwork"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)
	_configure()

func _configure() -> void:
	var content_radius := 594.427876
	_sprite.texture = SLAM
	if _kind == &"shock":
		_sprite.texture = SHOCK
		content_radius = 542.347214
	elif _kind == &"mine":
		_sprite.texture = MINE
		content_radius = 575.500217
	elif _kind == &"skid":
		_sprite.texture = SKID
		content_radius = SKID_CONTENT_RADIUS
	_sprite.scale = Vector2.ONE * _radius / content_radius
	_update_art()

func _process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	if not Scope.is_valid_attack(self):
		cancel_attack()
		return
	if get_tree().paused:
		return
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return
	_update_art()

func _update_art() -> void:
	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	# Stone remains still; the energy's finite fade supplies its dissipation.
	var alpha := pow(1.0 - progress, 1.3 if _kind == &"slam" else 2.0)
	_sprite.modulate = Color(1, 1, 1, AccessibilityPresentation.current_flash_alpha(alpha))

func cancel_attack() -> void:
	visible = false
	queue_free()
