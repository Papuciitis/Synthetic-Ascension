extends RefCounted
class_name EnemyBomber

var _owner: EnemyActor = null
var _exploded: bool = false

func setup(owner: EnemyActor) -> void:
	_owner = owner

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
	if dist <= spec.explode_trigger_distance:
		# Route proximity detonation through the normal lifecycle so the Bomber
		# emits its kill event and rolls the same rewards as every other enemy.
		var source: Node = _owner.get_tree().get_first_node_in_group("player")
		_owner.take_damage(maxf(1.0, _owner.hp), source)
		return Vector2.ZERO

	return to_player * spd

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
