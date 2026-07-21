extends Node2D
class_name MagicMissileProjectile

@export var speed: float = 950.0
@export var turn_rate: float = 12.0
@export var max_life: float = 2.0
@export var hit_radius: float = 16.0

@export var trail_max_points: int = 12
@export var trail_point_spacing: float = 10.0

var target: Node2D = null
var damage: float = 10.0

var _vel: Vector2 = Vector2.RIGHT
var _life: float = 0.0

var _trail_pts: PackedVector2Array = PackedVector2Array()
var _trail_line: Line2D = null
var _body: Polygon2D = null
var _pooled: bool = false

func setup(p_target: Node2D, p_damage: float, start_dir: Vector2) -> void:
	target = p_target
	damage = p_damage
	var d := start_dir if start_dir != Vector2.ZERO else Vector2.RIGHT
	_vel = d.normalized() * speed
	_life = 0.0
	_trail_pts = PackedVector2Array()
	_add_trail_point(global_position)

func _ready() -> void:
	_pooled = has_meta("__pool_key")
	set_physics_process(true)
	_ensure_visuals()

func _on_pool_obtain() -> void:
	_pooled = true
	set_physics_process(true)
	_ensure_visuals()
	_life = 0.0
	_trail_pts = PackedVector2Array()

func _on_pool_recycle() -> void:
	target = null
	damage = 0.0
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

	if target == null or not is_instance_valid(target):
		_despawn()
		return

	var to_t: Vector2 = (target.global_position - global_position).normalized()
	if to_t != Vector2.ZERO:
		var desired: Vector2 = to_t * speed
		_vel = _vel.lerp(desired, clampf(turn_rate * dt, 0.0, 1.0))

	global_position += _vel * dt
	rotation = _vel.angle()

	# Trail update only when moved enough
	_add_trail_point(global_position)

	if _trail_line != null:
		_trail_line.points = _trail_pts

	if global_position.distance_squared_to(target.global_position) <= hit_radius * hit_radius:
		if target.has_method("take_damage"):
			target.call("take_damage", damage)
		_despawn()

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
