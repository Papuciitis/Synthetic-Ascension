extends RefCounted
class_name EnemySenses

var _enemy: EnemyActor = null

# cached exclude list (to avoid rebuilding arrays every ray)
var _exclude: Array[RID] = []
var _cached_enemy_iid: int = 0
var _cached_hitbox_iid: int = 0
var _cached_player_iid: int = 0
var _cached_player_hb_iid: int = 0

# cached node refs (avoid get_node_or_null every call)
var _hitbox: Area2D = null
var _player: Node2D = null
var _player_hurtbox: Area2D = null

# cached query params (avoid allocating per call)
var _ray_params := PhysicsRayQueryParameters2D.new()
var _point_params := PhysicsPointQueryParameters2D.new()


func setup(enemy: EnemyActor) -> void:
	_enemy = enemy
	_exclude.clear()

	_cached_enemy_iid = 0
	_cached_hitbox_iid = 0
	_cached_player_iid = 0
	_cached_player_hb_iid = 0

	_hitbox = null
	_player = null
	_player_hurtbox = null


func cover_mask() -> int:
	# IMPORTANT: matches your rule:
	# tactical_cover_mask == 0 -> treat as NO-COVER WORLD (LOS always true)
	if _enemy == null or not is_instance_valid(_enemy):
		return 0
	if _enemy.spec == null:
		return 0
	return int(_enemy.spec.tactical_cover_mask)


func _rebuild_exclude_if_needed() -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		_exclude.clear()
		_cached_enemy_iid = 0
		_cached_hitbox_iid = 0
		_cached_player_iid = 0
		_cached_player_hb_iid = 0
		_hitbox = null
		_player = null
		_player_hurtbox = null
		return

	var enemy_iid: int = _enemy.get_instance_id()

	# Resolve hitbox ONLY when needed
	if _hitbox == null or not is_instance_valid(_hitbox):
		_hitbox = _enemy.get_node_or_null("Hitbox") as Area2D
	var hb_iid: int = (_hitbox.get_instance_id() if _hitbox != null else 0)

	# Resolve player ONLY when needed
	var p: Node2D = (_enemy.player if _enemy.player != null and is_instance_valid(_enemy.player) else null)
	if p != _player:
		_player = p
		_player_hurtbox = null # refresh hurtbox on player change
	if _player != null and (_player_hurtbox == null or not is_instance_valid(_player_hurtbox)):
		_player_hurtbox = _player.get_node_or_null("Hurtbox") as Area2D

	var player_iid: int = (_player.get_instance_id() if _player != null else 0)
	var phb_iid: int = (_player_hurtbox.get_instance_id() if _player_hurtbox != null else 0)

	# If nothing changed and exclude list is already valid, keep it.
	if enemy_iid == _cached_enemy_iid \
	and hb_iid == _cached_hitbox_iid \
	and player_iid == _cached_player_iid \
	and phb_iid == _cached_player_hb_iid \
	and not _exclude.is_empty():
		return

	_cached_enemy_iid = enemy_iid
	_cached_hitbox_iid = hb_iid
	_cached_player_iid = player_iid
	_cached_player_hb_iid = phb_iid

	_exclude.clear()

	# exclude self body
	_exclude.append(_enemy.get_rid())

	# exclude own hitbox
	if _hitbox != null:
		_exclude.append(_hitbox.get_rid())

	# exclude player body + hurtbox
	if _player != null:
		if _player is CollisionObject2D:
			_exclude.append((_player as CollisionObject2D).get_rid())
		if _player_hurtbox != null:
			_exclude.append(_player_hurtbox.get_rid())


func get_exclude_rids() -> Array[RID]:
	_rebuild_exclude_if_needed()
	return _exclude


func has_los_to_player() -> bool:
	if _enemy == null or not is_instance_valid(_enemy):
		return false
	if _enemy.player == null or not is_instance_valid(_enemy.player):
		return false

	var mask: int = cover_mask()
	if mask == 0:
		return true

	var w: World2D = _enemy.get_world_2d()
	if w == null:
		return true

	var space: PhysicsDirectSpaceState2D = w.direct_space_state

	_ray_params.from = _enemy.global_position
	_ray_params.to = _enemy.player.global_position
	_ray_params.collision_mask = mask
	_ray_params.exclude = get_exclude_rids()
	_ray_params.collide_with_bodies = true
	_ray_params.collide_with_areas = true
	_ray_params.hit_from_inside = true

	return space.intersect_ray(_ray_params).is_empty()


func ray_clear(a: Vector2, b: Vector2) -> bool:
	var mask: int = cover_mask()
	if mask == 0:
		return true

	var w: World2D = _enemy.get_world_2d()
	if w == null:
		return true

	var space: PhysicsDirectSpaceState2D = w.direct_space_state

	_ray_params.from = a
	_ray_params.to = b
	_ray_params.collision_mask = mask
	_ray_params.exclude = get_exclude_rids()
	_ray_params.collide_with_bodies = true
	_ray_params.collide_with_areas = true
	_ray_params.hit_from_inside = true

	return space.intersect_ray(_ray_params).is_empty()


func point_blocked(p: Vector2) -> bool:
	var mask: int = cover_mask()
	if mask == 0:
		return false

	var w: World2D = _enemy.get_world_2d()
	if w == null:
		return false

	var space: PhysicsDirectSpaceState2D = w.direct_space_state

	_point_params.position = p
	_point_params.collision_mask = mask
	_point_params.exclude = get_exclude_rids()
	_point_params.collide_with_bodies = true
	_point_params.collide_with_areas = true

	var hits: Array = space.intersect_point(_point_params, 1)
	return not hits.is_empty()
