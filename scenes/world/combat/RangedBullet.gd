extends Area2D
class_name RangedBullet

@export var speed: float = 700.0
@export var max_range: float = 520.0
@export var damage: float = 10.0

# Trail tuning
@export var trail_width: float = 3.2
@export var trail_alpha: float = 0.18
@export var trail_glow_mul: float = 0.35
@export var trail_max_points: int = 9
@export var trail_point_spacing: float = 18.0
@export var trail_fade_time: float = 0.12

# Bullet body visuals (NEW)
@export var body_len: float = 18.0
@export var body_width: float = 4.0
@export var body_glow_width: float = 9.0
@export var body_core: Color = Color(0.92, 0.98, 1.0, 0.95)
@export var body_glow: Color = Color(0.25, 0.65, 1.0, 0.35)
@export var use_sprite_if_present: bool = true
@export var sprite_tint: Color = Color(0.75, 0.95, 1.0, 1.0)

# VFX (optional)
@export var vfx_hit_spokes_scene: PackedScene
@export var trail_enabled: bool = true

var source: Node = null
var velocity: Vector2 = Vector2.ZERO

var _start_pos: Vector2
var _hit: bool = false
var _pooled: bool = false
var _chunk_manager: ChunkManager = null

func _ready() -> void:
	_start_pos = global_position
	_chunk_manager = get_tree().get_first_node_in_group(&"chunk_manager") as ChunkManager
	area_entered.connect(_on_area_entered)
	set_physics_process(true)

	# additive material (shared if PoolManager is enabled)
	_pooled = has_meta("__pool_key")
	var pm := get_node_or_null("/root/PoolManager")
	if pm != null and is_instance_valid(pm) and pm.has_method("get_additive_material"):
		material = pm.call("get_additive_material")
	else:
		material = CanvasItemMaterial.new()
		(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_apply_visual_pose()
	_setup_sprite()

	# Trail: now drawn inline (no extra node per bullet)

	queue_redraw()

func _setup_sprite() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return

	if use_sprite_if_present and spr.texture != null:
		spr.modulate = sprite_tint
		spr.scale = Vector2(1.0, 1.0)
	else:
		# hide it if it's empty or you don't want it
		spr.visible = false

func _exit_tree() -> void:
	pass

func _stop_trail() -> void:
	pass

func _physics_process(delta: float) -> void:
	if _hit:
		return
	var old_pos: Vector2 = global_position
	var new_pos: Vector2 = old_pos + velocity * delta
	var projectile_radius := maxf(2.0, body_width * 0.5)
	var world_hit_t := _world_hit_t(old_pos, new_pos, projectile_radius)
	var enemy_handle := EnemyCombat.first_enemy_on_segment(old_pos, new_pos, projectile_radius)
	var enemy_hit_t := EnemyCombat.last_segment_hit_t()
	if (
		enemy_handle != EnemyWorldTypes.INVALID_HANDLE
		and enemy_hit_t >= 0.0
		and (world_hit_t < 0.0 or enemy_hit_t <= world_hit_t)
	):
		_hit_handle(enemy_handle, old_pos.lerp(new_pos, enemy_hit_t))
		return
	if world_hit_t >= 0.0:
		_despawn()
		return
	global_position = new_pos
	_apply_visual_pose()

	if max_range > 0.0:
		var d2 := _start_pos.distance_squared_to(global_position)
		if d2 >= max_range * max_range:
			_despawn()

func _hits_world(from_pos: Vector2, to_pos: Vector2, radius: float) -> bool:
	return _world_hit_t(from_pos, to_pos, radius) >= 0.0


func _world_hit_t(from_pos: Vector2, to_pos: Vector2, radius: float) -> float:
	if _chunk_manager == null or not is_instance_valid(_chunk_manager):
		_chunk_manager = get_tree().get_first_node_in_group(&"chunk_manager") as ChunkManager
	return _chunk_manager.projectile_hit_t(from_pos, to_pos, radius) if _chunk_manager != null else -1.0

func _apply_visual_pose() -> void:
	if velocity.length_squared() > 0.001:
		rotation = velocity.angle()

func _despawn() -> void:
	var pm := get_node_or_null("/root/PoolManager")
	if pm != null and is_instance_valid(pm) and _pooled and pm.has_method("recycle"):
		pm.call("recycle", self)
	else:
		queue_free()

func _draw() -> void:
	# Inline tail (cheap): draw backward along -X (node rotation points it toward travel)
	var spd: float = velocity.length()
	var speed_t: float = clampf(spd / 900.0, 0.0, 1.0)
	var tail_len: float = lerpf(18.0, 58.0, speed_t)

	var back := Vector2.LEFT * tail_len
	var a: float = trail_alpha

	if trail_enabled:
		if trail_glow_mul > 0.0:
			draw_line(Vector2.ZERO, back, Color(body_glow.r, body_glow.g, body_glow.b, body_glow.a * a * trail_glow_mul), trail_width * 2.2, true)
		draw_line(Vector2.ZERO, back, Color(body_core.r, body_core.g, body_core.b, a), trail_width, true)

	# draw a small bolt along +X (node rotation points it toward travel)
	var half := body_len * 0.5
	var p0 := Vector2(-half * 0.35, 0.0)
	var p1 := Vector2(+half * 0.65, 0.0)

	draw_line(p0, p1, Color(body_glow.r, body_glow.g, body_glow.b, body_glow.a), body_glow_width, true)
	draw_line(p0, p1, Color(body_core.r, body_core.g, body_core.b, body_core.a), body_width, true)

	# tiny head dot
	draw_circle(p1, maxf(2.0, body_width * 0.55), Color(1, 1, 1, 0.35))

func _on_area_entered(area: Area2D) -> void:
	if _hit:
		return

	if area.is_in_group("enemy_hitbox"):
		var enemy := area.get_parent()
		var handle := EnemyCombat.handle_for_actor(enemy)
		if handle != EnemyWorldTypes.INVALID_HANDLE:
			_hit_handle(handle, area.global_position)
			return
		_hit = true
		if enemy != null and enemy.is_in_group("enemies") and enemy.has_method("take_damage"):
			enemy.call("take_damage", damage, source)
		_spawn_hit_vfx(area.global_position)
		_despawn()


func _hit_handle(handle: int, hit_position: Vector2) -> void:
	if _hit:
		return
	_hit = true
	EnemyCombat.apply_damage(handle, damage, 1, source)
	_spawn_hit_vfx(hit_position)
	_despawn()


func _spawn_hit_vfx(hit_position: Vector2) -> void:
	if vfx_hit_spokes_scene == null:
		return
	var v: Node = vfx_hit_spokes_scene.instantiate()
	get_tree().current_scene.add_child(v)
	if v.has_method("setup"):
		v.call("setup", hit_position)


func _apply_burn_dot(enemy: Node) -> void:
	if enemy == null:
		return
	if not has_meta("burn_duration"):
		return
	var duration_v: Variant = get_meta("burn_duration")
	var tick_v: Variant = get_meta("burn_tick")
	var stacks_v: Variant = get_meta("burn_stacks")
	var mult_v: Variant = get_meta("burn_tick_mult")

	var duration: float = float(duration_v)
	var tick: float = float(tick_v)
	var stacks: int = int(stacks_v)
	var mult: float = float(mult_v)
	if duration <= 0.0 or tick <= 0.0 or stacks <= 0:
		return

	var dmg_per_tick_per_stack: float = maxf(0.05, damage * mult)

	var dot: BurnDot = null
	var existing: Node = enemy.get_node_or_null("BurnDot")
	if existing != null:
		dot = existing as BurnDot
	if dot == null:
		dot = BurnDot.new()
		dot.name = "BurnDot"
		enemy.add_child(dot)
	# Burn refreshes duration and can raise stacks
	dot.setup(enemy, source, stacks, duration, tick, dmg_per_tick_per_stack)
