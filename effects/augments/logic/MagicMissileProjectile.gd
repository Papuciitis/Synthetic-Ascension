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

## Choir of Needles: on its hit this missile splits into `split_count`
## shards at `split_mul` of its damage, each seeking a different enemy
## within SPLIT_SEEK. Shards never split again.
const SPLIT_SEEK := 420.0
var split_count: int = 0
var split_mul: float = 0.6
var _split_scene: PackedScene = null


func set_split(count: int, scene: PackedScene, mul: float) -> void:
	split_count = maxi(0, count)
	_split_scene = scene
	split_mul = mul

var _vel: Vector2 = Vector2.RIGHT
var _life: float = 0.0

var _trail_pts: PackedVector2Array = PackedVector2Array()
var _trail_line: Line2D = null
var _body: Node2D = null  # the missile sprite, or the polygon fallback without the art
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
	split_count = 0
	_split_scene = null
	_vel = Vector2.ZERO
	_life = 0.0
	_trail_pts = PackedVector2Array()
	if _trail_line != null:
		_trail_line.points = PackedVector2Array()

func _ensure_visuals() -> void:
	# Body
	# Pixel-art kit (Batch D, 2026-09-27): the missile sprite replaces the
	# code-built triangle. Its tip points along +X as the polygon's did, so the
	# node's own rotation (set from the velocity each step) aims it; the scale
	# makes it ~14 px long and the offset puts the sprite's content centre on
	# the origin. Without the art the polygon stays as the fallback.
	_body = get_node_or_null("Body") as Node2D
	if _body == null:
		var missile := VfxKit.texture("missile")
		if missile != null:
			var sprite := Sprite2D.new()
			sprite.name = "Body"
			sprite.texture = missile
			sprite.offset = missile.get_size() * 0.5 - VfxKit.MISSILE_CENTER
			sprite.scale = Vector2.ONE * (14.0 / VfxKit.MISSILE_LENGTH)
			_body = sprite
		else:
			var polygon := Polygon2D.new()
			polygon.name = "Body"
			polygon.polygon = PackedVector2Array([Vector2(12, 0), Vector2(-8, -5), Vector2(-8, 5)])
			polygon.color = Color(1, 1, 1, 1)
			_body = polygon
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
		# Pixel-art kit (Batch D, 2026-09-27): the streak sprite stretched along
		# the trail. Its bright end is the RIGHT of the texture, which STRETCH
		# puts at the LAST point, and _add_trail_point appends the newest
		# position last, so the bright end rides on the missile. Without the
		# art the plain 2 px line stays.
		var streak := VfxKit.texture("streak")
		if streak != null:
			_trail_line.texture = streak
			_trail_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
			_trail_line.width = 6.0
		add_child(_trail_line)

	# Shared additive material if available: the trail keeps it; the body
	# sprite carries its own light and blends normally.
	var pm := get_node_or_null("/root/PoolManager")
	if pm != null and is_instance_valid(pm) and pm.has_method("get_additive_material"):
		_trail_line.material = pm.call("get_additive_material")
	elif _trail_line.material == null:
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_trail_line.material = additive
	material = null  # pixel-art kit (Batch D): the sprite blends normally
	if _body is Sprite2D:
		_body.material = null
	else:
		_body.material = _trail_line.material

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
		EnemyCombat.apply_damage(hit_handle, damage, 1, source, BalanceAttribution.provenance("augment:magic_missile", "augment:magic_missile:missile", "augment"))
		if split_count > 0:
			_split(hit_handle, global_position)
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

func _split(struck: int, at: Vector2) -> void:
	if _split_scene == null or not is_inside_tree():
		return
	var nearby: Array[int] = []
	EnemyCombat.gather_in_radius(at, SPLIT_SEEK, nearby, struck)
	nearby.sort_custom(func(a: int, b: int) -> bool:
		return at.distance_squared_to(EnemyCombat.position_for_handle(a)) < at.distance_squared_to(EnemyCombat.position_for_handle(b)))
	var shards := mini(split_count, nearby.size())
	var parent := get_tree().current_scene
	var pm := get_node_or_null("/root/PoolManager")
	for i in range(shards):
		var shard: Node = null
		if pm != null and is_instance_valid(pm) and pm.has_method("obtain"):
			shard = pm.call("obtain", _split_scene, parent) as Node
		else:
			shard = _split_scene.instantiate()
		var shard_2d := shard as Node2D
		if shard_2d == null:
			continue
		if shard_2d.get_parent() == null:
			parent.add_child(shard_2d)
		shard_2d.global_position = at
		var dir := (EnemyCombat.position_for_handle(nearby[i]) - at).normalized().rotated(randf_range(-0.6, 0.6))
		if shard_2d.has_method("setup_handle"):
			shard_2d.call("setup_handle", nearby[i], damage * split_mul, dir, source)
		if shard_2d.has_method("set_split"):
			shard_2d.call("set_split", 0, null, split_mul)


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
