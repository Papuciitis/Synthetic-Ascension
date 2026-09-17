extends Node2D
class_name ManifestationShardProjectile

## A shard thrown out of the shared Manifestation orbit (Vector Halo's payoff).
##
## Self-contained on purpose: it carries its own procedural visual and damages
## straight through EnemyCombat, so a launched halo does not depend on which
## weapon the player happens to be holding or on any bullet scene's layers.

## At launch speed a single radius test per physics frame can step clean over a
## small enemy on a long frame, so the step is sub-sampled at this spacing.
const SUBSTEP_LENGTH: float = 24.0

var damage: float = 10.0
var speed: float = 1180.0
var max_life: float = 0.85
var hit_radius: float = 20.0
var max_hits: int = 3
var tint: Color = Color(0.72, 0.95, 1.0)
var source: Node = null

var _velocity: Vector2 = Vector2.RIGHT
var _life: float = 0.0
var _spin: float = 0.0
var _hits: Array[int] = []
var _sweep: Array[int] = []
var _chunk_manager: ChunkManager = null


## Call before adding to the tree; tune `speed`/`max_life`/`max_hits` first.
func launch(direction: Vector2, p_damage: float, p_source: Node) -> void:
	var facing := direction if direction.length_squared() > 0.0001 else Vector2.RIGHT
	facing = facing.normalized()
	_velocity = facing * speed
	damage = p_damage
	source = p_source
	rotation = facing.angle()


func _ready() -> void:
	z_as_relative = false
	z_index = 4072
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_chunk_manager = get_tree().get_first_node_in_group(&"chunk_manager") as ChunkManager
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= max_life:
		queue_free()
		return

	_spin += delta * 26.0
	var from := global_position
	var to := from + _velocity * delta
	if _blocked_by_world(from, to):
		queue_free()
		return

	var steps := maxi(1, int(ceil(from.distance_to(to) / SUBSTEP_LENGTH)))
	for i in range(1, steps + 1):
		if _sweep_at(from.lerp(to, float(i) / float(steps))):
			return

	global_position = to
	queue_redraw()


## Returns true when the shard is spent and has freed itself.
func _sweep_at(point: Vector2) -> bool:
	if EnemyCombat == null:
		return false
	EnemyCombat.gather_in_radius(point, hit_radius, _sweep)
	for handle in _sweep:
		if _hits.has(handle):
			continue
		EnemyCombat.apply_damage(handle, damage, 1, source)
		_hits.append(handle)
		if _hits.size() >= max_hits:
			global_position = point
			queue_free()
			return true
	return false


func _blocked_by_world(from: Vector2, to: Vector2) -> bool:
	if _chunk_manager == null or not is_instance_valid(_chunk_manager):
		_chunk_manager = get_tree().get_first_node_in_group(&"chunk_manager") as ChunkManager
	if _chunk_manager == null:
		return false
	return _chunk_manager.projectile_hit_t(from, to, 5.0) >= 0.0


func _draw() -> void:
	var fade := clampf(1.0 - _life / maxf(max_life, 0.001), 0.0, 1.0)
	fade = 0.35 + 0.65 * fade
	var glow := Color(tint.r, tint.g, tint.b, 0.32 * fade)
	draw_line(Vector2(-36.0, 0.0), Vector2(6.0, 0.0), glow, 7.0, true)
	draw_circle(Vector2.ZERO, 10.0, glow)
	var flick := 0.85 + 0.15 * sin(_spin)
	draw_colored_polygon(PackedVector2Array([
		Vector2(13.0, 0.0),
		Vector2(-5.0, -4.4 * flick),
		Vector2(-11.0, 0.0),
		Vector2(-5.0, 4.4 * flick),
	]), Color(1.0, 1.0, 1.0, 0.95 * fade))
