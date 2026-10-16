extends Node2D
## Finite, non-damaging arrival destination. Callers own the release clock and
## bind this cue to their AttackScope; it never decides when an actor spawns.

const Scope := preload("res://scenes/world/bosses/BossAttackScope.gd")
const BLINK := preload("res://scenes/world/bosses/art/vfx/blink_arrival_v1.png")
const RUNNER := preload("res://scenes/world/bosses/art/vfx/runner_arrival_v1.png")
const BLINK_CONTENT_RADIUS := 582.7061866841642
const RUNNER_CONTENT_RADIUS := 588.2401720385985

var _world_origin := Vector2.ZERO
var _radius := 62.0
var _duration := 0.8
var _elapsed := 0.0
var _kind: StringName = &"blink"
var _sprite: Sprite2D

func setup(world_pos: Vector2, radius: float, duration: float, kind: StringName) -> void:
	_world_origin = world_pos
	_radius = maxf(radius, 1.0)
	_duration = maxf(duration, 0.05)
	_kind = &"summon" if kind == &"summon" else &"blink"
	_elapsed = 0.0
	if is_node_ready():
		_configure()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(false)
	set_physics_process(true)
	top_level = true
	_sprite = Sprite2D.new()
	_sprite.name = "Arrival"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.z_index = 1
	add_child(_sprite)
	_configure()

func _configure() -> void:
	global_position = _world_origin
	_sprite.texture = RUNNER if _kind == &"summon" else BLINK
	var painted_radius := RUNNER_CONTENT_RADIUS if _kind == &"summon" else BLINK_CONTENT_RADIUS
	_sprite.scale = Vector2.ONE * _radius / painted_radius
	set_progress(_elapsed / _duration)

func set_progress(value: float) -> void:
	if _sprite == null:
		return
	# A stable destination remains legible under Reduced Motion / flash Off.
	# Progress changes opacity, never the committed position or footprint.
	var alpha := lerpf(0.60, 0.95, clampf(value, 0.0, 1.0))
	_sprite.modulate = Color(1.0, 1.0, 1.0, alpha)

func _process(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if not Scope.is_valid_attack(self):
		cancel_attack()
		return
	if get_tree().paused:
		return
	_elapsed += delta
	if _elapsed >= _duration:
		cancel_attack()
		return
	set_progress(_elapsed / _duration)

func cancel_attack() -> void:
	visible = false
	set_process(false)
	set_physics_process(false)
	queue_free()
