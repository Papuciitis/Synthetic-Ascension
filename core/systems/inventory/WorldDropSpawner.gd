extends Node2D
class_name WorldDropSpawner

@export var pickup_scene: PackedScene

@export var scatter_radius: float = 50.0          # random spread around the drop point
@export var throw_towards_mouse: float = 100.0    # base distance away from player in mouse direction
@export var min_drop_distance: float = 60.0       # NEVER drop closer than this to player

@export var dropped_pickup_delay: float = 1.2     # dropped items can't be picked instantly

# Throw feel
@export var throw_anim_time: float = 0.18
@export var throw_arc_height: float = 28.0
@export var land_bounce_scale: float = 1.12
@export var land_bounce_time: float = 0.06

var _router: InventoryRouter = null

# /root/InvRouter is one project-wide autoload with several consumers - this
# spawner and the HUD both bind to it in _ready() from the same scene - so its
# absence used to be reported once per consumer. The report lives here once and
# every consumer routes through it.
static var _warned_missing_router: bool = false


## Reports the missing autoload for whichever consumer notices first.
## Returns true when this call is the one that emitted.
static func warn_missing_inventory_router(consumer: String) -> bool:
	if _warned_missing_router:
		return false
	_warned_missing_router = true
	push_warning(
		"[WorldDropSpawner] inventory router missing: /root/InvRouter not found; world drops and bag routing are disabled (first consumer=%s)"
		% consumer
	)
	return true


func _ready() -> void:
	_router = get_node_or_null("/root/InvRouter") as InventoryRouter
	if _router == null:
		warn_missing_inventory_router("WorldDropSpawner")
		return

	if not _router.dropped_to_world.is_connected(_on_router_dropped_to_world):
		_router.dropped_to_world.connect(_on_router_dropped_to_world)


func _on_router_dropped_to_world(inst: ItemInstance, _world_pos: Vector2) -> void:
	spawn_protected(inst)


func spawn_protected(inst: ItemInstance) -> bool:
	if inst == null or inst.data == null:
		return false
	if pickup_scene == null:
		push_warning("[WorldDropSpawner] pickup_scene is null")
		return false

	var pickup := pickup_scene.instantiate() as ItemPickup
	if pickup == null:
		push_warning("[WorldDropSpawner] pickup_scene root is not ItemPickup")
		return false

	# Set instance before adding so ItemPickup draws correct icon immediately
	pickup.item_instance = inst
	pickup.persistent_world_drop = true

	# Make dropped items take longer to be pickable
	pickup.pickup_delay = dropped_pickup_delay
	pickup.drop_pickup_delay = dropped_pickup_delay

	add_child(pickup)

	# --- player position (ROBUST: by group, no NodePath dependency) ---
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var player_pos: Vector2 = (player.global_position if player != null else global_position)

	# --- direction: player -> mouse (fallback if mouse is basically on player) ---
	var dir: Vector2 = get_global_mouse_position() - player_pos
	if dir.length() < 0.001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()

	# --- base drop point: start at player, then "throw" towards mouse ---
	var base_pos: Vector2 = player_pos
	if throw_towards_mouse > 0.0:
		base_pos += dir * throw_towards_mouse

	# --- scatter around base point ---
	var ang: float = randf() * TAU
	var rad: float = randf() * scatter_radius
	var final_pos: Vector2 = base_pos + Vector2(cos(ang), sin(ang)) * rad

	# --- clamp: never allow too close to player ---
	var v: Vector2 = final_pos - player_pos
	var d: float = v.length()
	if d < min_drop_distance:
		if d < 0.001:
			v = dir
		else:
			v = v / d
		final_pos = player_pos + v * min_drop_distance

	# Spawn at player, then throw to final_pos (VFX owns the animation)
	pickup.play_throw(player_pos, final_pos, throw_anim_time, throw_arc_height, land_bounce_scale, land_bounce_time)
	return true
