extends Area2D
class_name BossSectorStrike
## A one-shot circular-sector strike (the main Bulldozer's Sweeping Cleave).
## Its collision polygon is BossEscapeOracle.sector_polygon, so the warned
## bound, the walk-out check and the damage share one geometry. Like
## DamageCircle it is configured before activation, checks the real Hurtbox
## once on its first physics tick, strikes each Hurtbox at most once and shows
## its footprint for its whole damaging life.

const Scope = preload("res://scenes/world/bosses/BossAttackScope.gd")
const Oracle = preload("res://scenes/world/bosses/BossEscapeOracle.gd")
const SectorWarning = preload("res://scenes/world/bosses/BossSectorWarning.gd")

var damage := 16.0
var lifetime := 0.18
var source: Node = null
var _world_origin := Vector2.ZERO
var _facing := 0.0
var _radius := 125.0
var _half_angle := 1.3
var _remaining := 0.18
var _checked_initial_overlap := false
var _damaged_hurtboxes: Dictionary = {}
var _shape: CollisionShape2D
var _footprint: Node2D


func setup(world_pos: Vector2, facing: float, radius: float, half_angle: float, dmg: float, life: float, src: Node = null) -> void:
	_world_origin = world_pos
	_facing = facing
	_radius = maxf(radius, 1.0)
	_half_angle = clampf(half_angle, 0.0, PI * 0.5)
	damage = dmg
	lifetime = life
	_remaining = life
	source = src


func _ready() -> void:
	top_level = true
	global_position = _world_origin
	_shape = CollisionShape2D.new()
	var polygon := ConvexPolygonShape2D.new()
	# Convex for any half angle up to 90 degrees; the strike is clamped so.
	polygon.points = Oracle.sector_polygon(Vector2.ZERO, _facing, _radius, _half_angle)
	_shape.shape = polygon
	add_child(_shape)
	_footprint = SectorWarning.new()
	_footprint.name = "Footprint"
	_footprint.setup(_world_origin, _facing, _radius, _half_angle)
	add_child(_footprint)
	_footprint.set_process(false)
	_footprint.set_progress(1.0, true)
	# One blow per Hurtbox: leaving and re-entering earns no second.
	area_entered.connect(_on_area_entered)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if not _attack_is_valid():
		cancel_attack()
		return
	if not _checked_initial_overlap:
		_checked_initial_overlap = true
		_check_overlap_now()
	_remaining -= delta
	if _remaining <= 0.0:
		queue_free()


func _check_overlap_now() -> void:
	if is_queued_for_deletion() or _shape == null or _shape.shape == null:
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape.shape
	query.transform = _shape.global_transform
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = [get_rid()]
	for overlap in get_world_2d().direct_space_state.intersect_shape(query, 32):
		_on_area_entered(overlap.get("collider") as Area2D)


func _on_area_entered(area: Area2D) -> void:
	if get_tree().paused or not _attack_is_valid() or is_queued_for_deletion():
		return
	if area == null or not area.is_in_group("player_hurtbox") or _damaged_hurtboxes.has(area.get_instance_id()):
		return
	_damaged_hurtboxes[area.get_instance_id()] = true
	var target := area.get_parent()
	if target != null and target.has_method("take_damage"):
		target.call("take_damage", damage, source)


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
