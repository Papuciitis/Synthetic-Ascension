extends Area2D

@export var speed: float = 500.0
@export var damage: float = 10.0
@export var lifetime: float = 2.0

var velocity: Vector2 = Vector2.ZERO
var source: Node = null

var _life_left: float = -1.0
var _pooled: bool = false

func _ready() -> void:
	add_to_group("player_projectile")

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	_life_left = lifetime
	_pooled = has_meta("__pool_key")
	set_physics_process(true)

func _on_pool_obtain() -> void:
	# PoolManager calls this when the node is re-used.
	_pooled = true
	_life_left = lifetime
	if "monitoring" in self:
		monitoring = true
	if "monitorable" in self:
		monitorable = true

func _on_pool_recycle() -> void:
	# Reset any runtime state that could leak between uses.
	velocity = Vector2.ZERO
	source = null
	_life_left = -1.0

func _physics_process(delta: float) -> void:
	if _life_left < 0.0:
		_life_left = lifetime

	global_position += velocity * delta

	_life_left -= delta
	if _life_left <= 0.0:
		_despawn()

func _on_area_entered(area: Area2D) -> void:
	# If enemy has a Hitbox, we can go to its parent (Enemy)
	if area != null and area.is_in_group("enemy_hitbox"):
		var enemy := area.get_parent()
		if enemy != null and enemy.is_in_group("enemies") and enemy.has_method("take_damage"):
			enemy.call("take_damage", damage, source)
		_despawn()

func _despawn() -> void:
	# Prefer pooling if available
	var pm := get_node_or_null("/root/PoolManager")
	if pm != null and is_instance_valid(pm) and _pooled and pm.has_method("recycle"):
		pm.call("recycle", self)
	else:
		queue_free()
