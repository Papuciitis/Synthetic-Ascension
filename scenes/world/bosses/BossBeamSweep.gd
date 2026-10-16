extends Node2D
class_name BossBeamSweep

const Scope = preload("res://scenes/world/bosses/BossAttackScope.gd")
const GroundWarning = preload("res://scenes/world/bosses/BossGroundWarning.gd")

@export var telegraph_time: float = 0.55
@export var sweep_time: float = 1.15
@export var width: float = 34.0
@export var length: float = 680.0
@export var damage: float = 16.0

@export var telegraph_scene: PackedScene = preload("res://assets/vfx/world/sets/conduit/VFX_ExplosiveT.tscn")
@export var damage_tick: float = 0.20

@onready var area: Area2D = $Area
@onready var shape: CollisionShape2D = $Area/CollisionShape2D

var source: Node = null
var _t: float = 0.0
var _phase: int = 0 # 0 telegraph, 1 sweep
var _a0: float = 0.0
var _a1: float = 0.0
var _tick: float = 0.0
var _configured := false
var _world_origin := Vector2.ZERO
var _warning

func setup(world_pos: Vector2, a0: float, a1: float, src: Node) -> void:
	_world_origin = world_pos
	_configured = true
	_a0 = a0
	_a1 = a1
	source = src
	_t = 0.0
	_phase = 0
	_tick = 0.0
	if is_node_ready():
		global_position = world_pos
		_configure_geometry()

func _ready() -> void:
	top_level = true
	if _configured:
		global_position = _world_origin
	_configure_geometry()
	set_process(true)


func _configure_geometry() -> void:
	if shape == null:
		return
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(maxf(0.0, length), maxf(0.0, width))
	shape.shape = rectangle
	shape.position = Vector2(length * 0.5, 0.0)
	rotation = _a0
	if not is_instance_valid(_warning):
		_warning = GroundWarning.new()
		_warning.name = "SweepWarning"
		add_child(_warning)
	_warning.configure_beam(length, width)
	_warning.set_progress(0.0)

func _process(delta: float) -> void:
	# A cast interruption queues this channel for deletion before the frame's
	# remaining callbacks. Do not release sound or active art in that interval.
	if is_queued_for_deletion():
		return
	if not _attack_is_valid():
		cancel_attack()
		return
	if get_tree().paused:
		return
	_t += delta

	if _phase == 0:
		if _t < maxf(0.0, telegraph_time):
			_warning.set_progress(_t / maxf(0.001, telegraph_time))
			return
		_phase = 1
		SfxManager.play_2d(&"boss_beam_release", global_position)
		_t = maxf(0.0, _t - maxf(0.0, telegraph_time))
		_tick = _t
	else:
		_tick += delta

	# Sweep
	var k := clampf(_t / maxf(sweep_time, 0.001), 0.0, 1.0)
	rotation = lerpf(_a0, _a1, k)
	_warning.set_progress(k, true)

	if _tick >= maxf(0.001, damage_tick):
		# Query the actual Hurtbox against this frame's rotated rectangle.
		# Cached Area enter/exit signals can lag the displayed sweep angle.
		if _damage_player():
			_tick = 0.0

	if _t >= sweep_time:
		queue_free()

func _damage_player() -> bool:
	if get_tree().paused or not _attack_is_valid() or is_queued_for_deletion() or shape == null:
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape.shape
	query.transform = shape.global_transform
	query.collision_mask = area.collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = [area.get_rid()]
	for overlap in get_world_2d().direct_space_state.intersect_shape(query, 32):
		var hurtbox := overlap.get("collider") as Area2D
		if hurtbox == null or not hurtbox.is_in_group(&"player_hurtbox"):
			continue
		var player := hurtbox.get_parent()
		if player != null and player.has_method("take_damage"):
			player.call("take_damage", damage, source if is_instance_valid(source) else self)
			return true
	return false


func _attack_is_valid() -> bool:
	if not Scope.is_valid_attack(self):
		return false
	if source == null:
		return true
	return is_instance_valid(source) and source.is_inside_tree() and not source.is_queued_for_deletion() and not ("dead" in source and bool(source.get("dead")))


func cancel_attack() -> void:
	set_process(false)
	visible = false
	queue_free()
