extends RefCounted
class_name EnemyBomber

var _owner: EnemyActor = null
var _exploded: bool = false

## A fuse between "close enough" and the blast (audit 2026-10-04, change 7).
## Detonation at the trigger distance used to be instant, so the hazard ring
## never had time to say anything. Inside it the fuse burns FUSE_TIME while
## the bomber keeps closing at FUSE_MOVE_MUL speed and the ring blinks hot;
## then it goes off where it stands. Killing it still detonates it at once.
const FUSE_TIME: float = 0.35
const FUSE_MOVE_MUL: float = 0.4
var _fuse_left: float = -1.0

func setup(owner: EnemyActor) -> void:
	_owner = owner
	_exploded = false
	_fuse_left = -1.0

	# Add a persistent hazard ring so player reads explosion radius
	if _owner == null or _owner.spec == null:
		return
	if _owner.spec.id != &"enemy_bomber":
		return

	# prevent duplicates
	for c in _owner.get_children():
		if c is VFX_BomberHazardRing:
			return

	var ring: VFX_BomberHazardRing = VFX_BomberHazardRing.new()
	ring.setup(_owner)
	_owner.add_child(ring)

func brain(to_player: Vector2, dist: float, spd: float) -> Vector2:
	if _owner == null or _owner.spec == null:
		return to_player * spd

	var spec: EnemySpec = _owner.spec
	if _fuse_left < 0.0 and dist <= spec.explode_trigger_distance:
		_fuse_left = FUSE_TIME
	if _fuse_left >= 0.0:
		# Near the player the brain runs every physics tick (LOD tier 0), so the
		# tick's own delta is the fuse's clock.
		_fuse_left -= _owner.get_physics_process_delta_time()
		if _fuse_left <= 0.0:
			_detonate()
			return Vector2.ZERO
		return to_player * spd * FUSE_MOVE_MUL

	return to_player * spd


## 0 before the fuse is lit, rising to 1 as it burns down.
func fuse_progress() -> float:
	if _fuse_left < 0.0:
		return 0.0
	return clampf(1.0 - _fuse_left / FUSE_TIME, 0.0, 1.0)


func is_fuse_lit() -> bool:
	return _fuse_left >= 0.0 and not _exploded


func _detonate() -> void:
	# Route proximity detonation through the normal lifecycle so the Bomber
	# emits its kill event and rolls the same rewards as every other enemy.
	var source: Node = _owner.get_tree().get_first_node_in_group("player")
	_owner.take_damage(maxf(1.0, _owner.hp), source)

func explode_now() -> void:
	if _exploded or _owner == null:
		return
	_exploded = true
	if _owner.spec == null:
		_owner.queue_free()
		return

	var r: float = _owner.spec.explode_radius
	var dmg: float = _owner.spec.explode_damage

	var ps: Array = _owner.get_tree().get_nodes_in_group("player")
	for p in ps:
		var p2: Node2D = p as Node2D
		if p2 != null and p2.global_position.distance_to(_owner.global_position) <= r:
			if p.has_method("take_damage"):
				p.call("take_damage", dmg, _owner)

	_owner.queue_free()
