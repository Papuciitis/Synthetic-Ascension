extends Area2D
class_name EnemyProjectile

var shooter: Node = null
var velocity: Vector2 = Vector2.ZERO
var damage: float = 5.0
var lifetime: float = 3.0

# Visual style
@export var trail_width: float = 2.8
@export var trail_alpha: float = 0.55
@export var tail_len_min: float = 14.0
@export var tail_len_max: float = 42.0

@export var color_core: Color = Color(0.95, 0.98, 1.0, 1.0)
@export var color_glow: Color = Color(0.25, 0.65, 1.0, 0.60)

static var _shared_additive: CanvasItemMaterial = null

var _life_left: float = 0.0
var _pooled: bool = false

func set_style(enemy_id: StringName) -> void:
	match enemy_id:
		&"enemy_spitter":
			color_core = Color(0.75, 1.00, 0.25, 1.0)
			color_glow = Color(0.10, 0.80, 0.25, 0.65)
			trail_width = 3.0
			trail_alpha = 0.60
		&"enemy_herald":
			# weird “unstable-y stable” magic: violet + ember
			color_core = Color(1.00, 0.70, 0.35, 1.0)
			color_glow = Color(0.78, 0.22, 1.00, 0.70)
			trail_width = 2.6
			trail_alpha = 0.62
		_:
			pass

	# tint sprite if it exists
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr != null:
		spr.modulate = Color(color_core.r, color_core.g, color_core.b, 1.0)

	queue_redraw()

# shooter_in is optional so old calls still work
func setup(dir: Vector2, speed: float, dmg: float, life: float, shooter_in: Node = null) -> void:
	shooter = shooter_in
	velocity = dir.normalized() * speed
	damage = dmg
	lifetime = life
	_life_left = life
	if velocity.length_squared() > 0.001:
		rotation = velocity.angle()
	queue_redraw()

func _ready() -> void:
	add_to_group("enemy_projectile")
	_pooled = has_meta("__pool_key")

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	# Shared additive material
	var pm := get_node_or_null("/root/PoolManager")
	if pm != null and is_instance_valid(pm) and pm.has_method("get_additive_material"):
		material = pm.call("get_additive_material")
	else:
		if _shared_additive == null:
			_shared_additive = CanvasItemMaterial.new()
			_shared_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = _shared_additive

	set_process(true)

func _on_pool_obtain() -> void:
	_pooled = true
	_life_left = lifetime
	if "monitoring" in self:
		monitoring = true
	if "monitorable" in self:
		monitorable = true
	set_process(true)

func _on_pool_recycle() -> void:
	shooter = null
	velocity = Vector2.ZERO
	damage = 0.0
	_life_left = 0.0

func _process(delta: float) -> void:
	global_position += velocity * delta
	_life_left -= delta
	if _life_left <= 0.0:
		_despawn()
		return

	# face travel direction so our tail draw is stable (no redraw needed)
	if velocity.length_squared() > 0.001:
		rotation = velocity.angle()

func _draw() -> void:
	# local X axis is forward because we rotate above
	var spd: float = velocity.length()
	var t: float = clampf(spd / 320.0, 0.0, 1.0)
	var tail_len: float = lerpf(tail_len_min, tail_len_max, t)

	var a: float = trail_alpha
	var back := Vector2.LEFT * tail_len

	# glow underlay (wide)
	draw_line(Vector2.ZERO, back, Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * a), trail_width * 3.2, true)

	# core
	draw_line(Vector2.ZERO, back, Color(color_core.r, color_core.g, color_core.b, a), trail_width, true)

	# head dot
	draw_circle(Vector2.ZERO, maxf(2.0, trail_width * 0.75), Color(color_core.r, color_core.g, color_core.b, 0.9))

func _on_area_entered(a: Area2D) -> void:
	if a != null and a.is_in_group("player_hurtbox"):
		var p: Node = get_tree().get_first_node_in_group("player")
		if p != null and p.has_method("take_damage"):
			p.call("take_damage", damage, self)
		_despawn()

func _on_body_entered(b: Node) -> void:
	# Ignore the shooter and other enemies (so we don't despawn instantly)
	if b == shooter:
		return
	if b != null and b.is_in_group("enemies"):
		return
	if b != null and b.is_in_group("player"):
		# We want to damage via Hurtbox (Area), not body
		return

	# Later we'll handle walls/cover here
	_despawn()

func _despawn() -> void:
	var pm := get_node_or_null("/root/PoolManager")
	if pm != null and is_instance_valid(pm) and _pooled and pm.has_method("recycle"):
		pm.call("recycle", self)
	else:
		queue_free()
