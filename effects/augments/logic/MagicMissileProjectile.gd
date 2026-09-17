extends Node2D
class_name MagicMissileProjectile

@export var speed: float = 950.0
@export var turn_rate: float = 12.0
@export var max_life: float = 2.0
@export var hit_radius: float = 16.0

@export var trail_max_points: int = 12
@export var trail_point_spacing: float = 10.0

var target_handle: int = EnemyWorldTypes.INVALID_HANDLE
var damage: float = 10.0
var source: Node = null

var _vel: Vector2 = Vector2.RIGHT
var _life: float = 0.0

var _trail_pts: PackedVector2Array = PackedVector2Array()
var _trail_line: Line2D = null
var _body: Polygon2D = null
var _pooled: bool = false
var _chunk_manager: ChunkManager = null

func setup(p_target: Node2D, p_damage: float, start_dir: Vector2) -> void:
	target_handle = EnemyCombat.handle_for_actor(p_target)
	damage = p_damage
	_setup_motion(start_dir)


func setup_handle(handle: int, p_damage: float, start_dir: Vector2, p_source: Node = null) -> void:
	target_handle = handle
	damage = p_damage
	source = p_source
	_setup_motion(start_dir)


func _setup_motion(start_dir: Vector2) -> void:
	var d := start_dir if start_dir != Vector2.ZERO else Vector2.RIGHT
	_vel = d.normalized() * speed
	_life = 0.0
	_trail_pts = PackedVector2Array()
	_add_trail_point(global_position)

func _ready() -> void:
	_pooled = has_meta("__pool_key")
	_chunk_manager = get_tree().get_first_node_in_group(&"chunk_manager") as ChunkManager
	set_physics_process(true)
	_ensure_visuals()

func _on_pool_obtain() -> void:
	_pooled = true
	set_physics_process(true)
	_ensure_visuals()
	_life = 0.0
	_trail_pts = PackedVector2Array()

func _on_pool_recycle() -> void:
	target_handle = EnemyWorldTypes.INVALID_HANDLE
	damage = 0.0
	source = null
	_vel = Vector2.ZERO
	_life = 0.0
	_trail_pts = PackedVector2Array()
	if _trail_line != null:
		_trail_line.points = PackedVector2Array()

func _ensure_visuals() -> void:
	# Body
	_body = get_node_or_null("Body") as Polygon2D
	if _body == null:
		_body = Polygon2D.new()
		_body.name = "Body"
		_body.polygon = PackedVector2Array([Vector2(12, 0), Vector2(-8, -5), Vector2(-8, 5)])
		_body.color = Color(1, 1, 1, 1)
		add_child(_body)

	# Trail (world-space)
	_trail_line = get_node_or_null("Trail") as Line2D
	if _trail_line == null:
		_trail_line = Line2D.new()
		_trail_line.name = "Trail"
		_trail_line.width = 2.0
		_trail_line.default_color = Color(1, 1, 1, 0.55)
		_trail_line.antialiased = true
		_trail_line.set_as_top_level(true) # points in global space
		add_child(_trail_line)

	# Shared additive material if available
	var pm := get_node_or_null("/root/PoolManager")
	if pm != null and is_instance_valid(pm) and pm.has_method("get_additive_material"):
		material = pm.call("get_additive_material")
		_trail_line.material = material
		_body.material = material
	else:
		if material == null:
			material = CanvasItemMaterial.new()
			(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_trail_line.material = material
		_body.material = material

func _physics_process(dt: float) -> void:
	_life += dt
	if _life >= max_life:
		_despawn()
		return

	if not EnemyWorld.is_valid_handle(target_handle) or EnemyWorld.is_dying(target_handle):
		_despawn()
		return
	var target_position := EnemyCombat.position_for_handle(target_handle)

	var to_t: Vector2 = (target_position - global_position).normalized()
	if to_t != Vector2.ZERO:
		var desired: Vector2 = to_t * speed
		_vel = _vel.lerp(desired, clampf(turn_rate * dt, 0.0, 1.0))

	var old_pos: Vector2 = global_position
	var new_pos: Vector2 = old_pos + _vel * dt
	var world_hit_t := _world_hit_t(old_pos, new_pos)
	var hit_handle := EnemyCombat.first_enemy_on_segment(old_pos, new_pos, hit_radius)
	var enemy_hit_t := EnemyCombat.last_segment_hit_t()
	if (
		hit_handle != EnemyWorldTypes.INVALID_HANDLE
		and enemy_hit_t >= 0.0
		and (world_hit_t < 0.0 or enemy_hit_t <= world_hit_t)
	):
		EnemyCombat.apply_damage(hit_handle, damage, 1, source)
		_despawn()
		return
	if world_hit_t >= 0.0:
		_despawn()
		return
	global_position = new_pos
	rotation = _vel.angle()

	# Trail update only when moved enough
	_add_trail_point(global_position)

	if _trail_line != null:
		_trail_line.points = _trail_pts

func _hits_world(from_pos: Vector2, to_pos: Vector2) -> bool:
	return _world_hit_t(from_pos, to_pos) >= 0.0


func _world_hit_t(from_pos: Vector2, to_pos: Vector2) -> float:
	if _chunk_manager == null or not is_instance_valid(_chunk_manager):
		_chunk_manager = get_tree().get_first_node_in_group(&"chunk_manager") as ChunkManager
	return _chunk_manager.projectile_hit_t(from_pos, to_pos, 5.0) if _chunk_manager != null else -1.0

func _add_trail_point(p: Vector2) -> void:
	if _trail_pts.is_empty():
		_trail_pts.append(p)
		return
	if _trail_pts[_trail_pts.size() - 1].distance_squared_to(p) < trail_point_spacing * trail_point_spacing:
		return
	_trail_pts.append(p)
	if _trail_pts.size() > maxi(2, trail_max_points):
		_trail_pts.remove_at(0)

func _despawn() -> void:
	var pm := get_node_or_null("/root/PoolManager")
	if pm != null and is_instance_valid(pm) and _pooled and pm.has_method("recycle"):
		pm.call("recycle", self)
	else:
		queue_free()
