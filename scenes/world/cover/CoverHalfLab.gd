extends StaticBody2D
class_name CoverHalfLab

const VISUALS := preload("res://core/systems/world/WorldCoverVisuals.gd")
const _CATALOG_INDEX := [4, 5, 0, 1, 3, 2, 6]

# Lab-friendly half cover props (avoid statues/ritual vibe)
const PROP_TEX: Array[Texture2D] = [
	preload("res://assets/world/props/prop_table_long_01.png"),
	preload("res://assets/world/props/prop_table_small_01.png"),
	preload("res://assets/world/props/prop_crate_01.png"),
	preload("res://assets/world/props/prop_crate_rot_01.png"),
	preload("res://assets/world/props/prop_rubble_small_01.png"),
	preload("res://assets/world/props/prop_rubble_big_01.png"),
	preload("res://assets/world/props/prop_broken_pillar_01.png"),
]

func _ready() -> void:
	add_to_group(&"cover_half")
	_apply()
	_register_projectile_geometry()

func _exit_tree() -> void:
	_unregister_projectile_geometry()

func _register_projectile_geometry() -> void:
	var manager: Node = get_tree().get_first_node_in_group(&"chunk_manager")
	if manager != null and manager.has_method("register_projectile_blocker_world"):
		manager.call("register_projectile_blocker_world", global_position, WorldBlockerGeometry.pack(WorldBlockerGeometry.Kind.HALF_COVER), get_instance_id())

func _unregister_projectile_geometry() -> void:
	if not is_inside_tree():
		return
	var manager: Node = get_tree().get_first_node_in_group(&"chunk_manager")
	if manager != null and manager.has_method("unregister_projectile_blocker_world"):
		manager.call("unregister_projectile_blocker_world", global_position, get_instance_id())

func _apply() -> void:
	_apply_default_collision()
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return

	var variant := half_variant(global_position)
	VISUALS.apply(self, spr, ChunkBlockVisualCatalog.half_texture(variant), ChunkBlockVisualCatalog.half_rotation(variant))


## Preserve both original lab RNG draws, translating only the texture role.
## The same packed result feeds authored batches and standalone scenes.
static func half_variant(world_position: Vector2) -> int:
	var rng := RandomNumberGenerator.new()
	var sx := int(floor(world_position.x))
	var sy := int(floor(world_position.y))
	rng.seed = int((sx * 73856093) ^ (sy * 19349663) ^ 0x6C4B1AB)
	var texture_index := rng.randi_range(0, PROP_TEX.size() - 1)
	var quarter_turn := rng.randi_range(0, 3)
	return int(_CATALOG_INDEX[texture_index]) | (quarter_turn << 3)

func _apply_default_collision() -> void:
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return
	var circle: CircleShape2D = collision.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		collision.shape = circle
	circle.radius = WorldBlockerGeometry.HALF_COVER_RADIUS
	collision.disabled = false
