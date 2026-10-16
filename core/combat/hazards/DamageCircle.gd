extends Area2D
class_name DamageCircle

const Scope = preload("res://scenes/world/bosses/BossAttackScope.gd")
const GroundWarning = preload("res://scenes/world/bosses/BossGroundWarning.gd")

@export var radius: float = 64.0
@export var damage: float = 10.0
@export var lifetime: float = 0.20
@export var hit_once: bool = true
@export var show_footprint: bool = false

var source: Node = null
var _hit: bool = false
var _remaining := 0.0
var _configured := false
var _world_origin := Vector2.ZERO
var _checked_initial_overlap := false
var _damaged_hurtboxes: Dictionary = {}
var _footprint

@onready var shape: CollisionShape2D = $CollisionShape2D

func setup(world_pos: Vector2, radius_px: float, dmg: float, life: float, src: Node = null) -> void:
	_world_origin = world_pos
	_configured = true
	radius = maxf(0.0, radius_px)
	damage = dmg
	lifetime = life
	source = src
	_remaining = lifetime
	_hit = false
	_checked_initial_overlap = false
	_damaged_hurtboxes.clear()
	if is_node_ready():
		global_position = world_pos
		_configure_geometry()

func _ready() -> void:
	if _configured:
		global_position = _world_origin
	_remaining = lifetime
	_configure_geometry()

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not area_exited.is_connected(_on_area_exited):
		area_exited.connect(_on_area_exited)
	# Contact starts on the physics clock, after a legacy add-then-setup caller
	# has supplied its real position. Never hit at the scene's default origin.
	set_physics_process(true)


func _configure_geometry() -> void:
	if shape != null:
		var circle := CircleShape2D.new()
		circle.radius = maxf(0.0, radius)
		shape.shape = circle
	if show_footprint or has_meta(Scope.SCOPE_META):
		if not is_instance_valid(_footprint):
			_footprint = GroundWarning.new()
			add_child(_footprint)
		_footprint.configure_circle(radius)
		_footprint.set_progress(1.0, true)
	elif is_instance_valid(_footprint):
		_footprint.queue_free()
		_footprint = null


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if not _attack_is_valid():
		cancel_attack()
		return
	if not _checked_initial_overlap:
		_checked_initial_overlap = true
		_check_overlap_now()
	if lifetime > 0.0:
		_remaining -= delta
		if _remaining <= 0.0:
			queue_free()

func _check_overlap_now() -> void:
	if is_queued_for_deletion() or not _attack_is_valid() or shape == null or shape.shape == null:
		return
	var world := get_world_2d()
	if world == null:
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape.shape
	query.transform = shape.global_transform
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = [get_rid()]
	for overlap in world.direct_space_state.intersect_shape(query, 32):
		var hurtbox := overlap.get("collider") as Area2D
		_on_area_entered(hurtbox)

func _on_area_entered(a: Area2D) -> void:
	if get_tree().paused or not _attack_is_valid() or is_queued_for_deletion():
		return
	if a == null or not a.is_in_group("player_hurtbox"):
		return
	if _damaged_hurtboxes.has(a.get_instance_id()):
		return
	_damaged_hurtboxes[a.get_instance_id()] = true
	var p := a.get_parent()
	if p != null:
		_apply_damage(p)


func _on_area_exited(a: Area2D) -> void:
	if is_instance_valid(a):
		_damaged_hurtboxes.erase(a.get_instance_id())


func _apply_damage(p: Node) -> void:
	if get_tree().paused or not _attack_is_valid() or is_queued_for_deletion():
		return
	if hit_once and _hit:
		return
	_hit = true
	if p.has_method("take_damage"):
		p.call("take_damage", damage, source)
	if hit_once:
		queue_free()


func _attack_is_valid() -> bool:
	if not Scope.is_valid_attack(self):
		return false
	if source == null:
		return true
	return is_instance_valid(source) and source.is_inside_tree() and not source.is_queued_for_deletion() and not ("dead" in source and bool(source.get("dead")))


func cancel_attack() -> void:
	set_physics_process(false)
	visible = false
	queue_free()
