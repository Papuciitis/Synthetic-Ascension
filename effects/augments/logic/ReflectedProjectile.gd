extends Node2D
class_name ReflectedProjectile

@export var speed: float = 1100.0
@export var max_life: float = 1.25
@export var hit_radius: float = 14.0

# visuals
@export var tail_len_min: float = 18.0
@export var tail_len_max: float = 60.0
@export var bolt_segments: int = 10
@export var bolt_amp: float = 3.5
@export var glow_w: float = 14.0
@export var core_w: float = 3.0

@export var color_core: Color = Color(1.0, 0.70, 0.35, 1.0)
@export var color_glow: Color = Color(0.78, 0.22, 1.00, 0.75)

var damage: float = 10.0
var source: Node = null

var _vel: Vector2 = Vector2.RIGHT
var _life: float = 0.0
var _t: float = 0.0
var _pooled: bool = false
var _redraw_accum: float = 0.0
var _chunk_manager: ChunkManager = null

func setup(p_dir: Vector2, p_damage: float, p_source: Node) -> void:
	var d := p_dir
	if d == Vector2.ZERO:
		d = Vector2.RIGHT
	_vel = d.normalized() * speed
	damage = p_damage
	source = p_source
	_life = 0.0
	_t = 0.0

func _ready() -> void:
	_pooled = has_meta("__pool_key")
	_chunk_manager = get_tree().get_first_node_in_group(&"chunk_manager") as ChunkManager

	var pm := get_node_or_null("/root/PoolManager")
	if pm != null and is_instance_valid(pm) and pm.has_method("get_additive_material"):
		material = pm.call("get_additive_material")
	else:
		material = CanvasItemMaterial.new()
		(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	set_process(true)
	queue_redraw()

func _process(dt: float) -> void:
	_life += dt
	_t += dt
	if _life >= max_life:
		_despawn()
		return

	var old_pos: Vector2 = global_position
	var new_pos: Vector2 = old_pos + _vel * dt
	if _hits_world(old_pos, new_pos):
		_despawn()
		return
	global_position = new_pos
	rotation = _vel.angle()

	# Collision: use EnemyIndex spatial hash when available
	var hit: Node2D = null
	var ei := get_node_or_null("/root/EnemyIndex")
	if ei != null and is_instance_valid(ei) and ei.has_method("first_in_radius"):
		hit = ei.call("first_in_radius", global_position, hit_radius, null) as Node2D
	else:
		var r2: float = hit_radius * hit_radius
		for n in get_tree().get_nodes_in_group("enemies"):
			var e: Node2D = n as Node2D
			if e == null or not is_instance_valid(e):
				continue
			if global_position.distance_squared_to(e.global_position) <= r2:
				hit = e
				break

	if hit != null and is_instance_valid(hit):
		if hit.has_method("take_damage"):
			hit.call("take_damage", damage, source)
		_despawn()
		return

	# Animated bolt: redraw at ~30fps instead of every frame
	_redraw_accum += dt
	if _redraw_accum >= (1.0 / 30.0):
		_redraw_accum = 0.0
		queue_redraw()

func _hits_world(from_pos: Vector2, to_pos: Vector2) -> bool:
	if _chunk_manager == null or not is_instance_valid(_chunk_manager):
		_chunk_manager = get_tree().get_first_node_in_group(&"chunk_manager") as ChunkManager
	return _chunk_manager != null and _chunk_manager.projectile_hit_t(from_pos, to_pos, 4.0) >= 0.0

func _draw() -> void:
	var p: float = clampf(_life / maxf(max_life, 0.001), 0.0, 1.0)
	var fade: float = 1.0 - p
	fade = fade * fade

	var spd: float = _vel.length()
	var t_spd: float = clampf(spd / 1100.0, 0.0, 1.0)
	var tail_len: float = lerpf(tail_len_min, tail_len_max, t_spd)

	# electric bolt polyline (local X forward; we draw backwards)
	var seg: int = maxi(6, bolt_segments)
	var pts := PackedVector2Array()
	pts.resize(seg + 1)

	for i in range(seg + 1):
		var u: float = float(i) / float(seg)
		var x: float = -tail_len * u
		var wobble: float = sin(u * 9.0 + _t * 30.0) * bolt_amp * (1.0 - u)
		var wobble2: float = sin(u * 5.0 - _t * 24.0) * (bolt_amp * 0.65) * (1.0 - u)
		pts[i] = Vector2(x, wobble + wobble2)

	draw_polyline(pts, Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * fade), glow_w, true)
	draw_polyline(pts, Color(color_core.r, color_core.g, color_core.b, color_core.a * fade), core_w, true)

	# head
	draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1, 0.25 * fade))
	draw_circle(Vector2.ZERO, 2.2, Color(color_core.r, color_core.g, color_core.b, 0.95 * fade))

func _despawn() -> void:
	var pm := get_node_or_null("/root/PoolManager")
	if pm != null and is_instance_valid(pm) and _pooled and pm.has_method("recycle"):
		pm.call("recycle", self)
	else:
		queue_free()
