extends RefCounted
## Conservative placement against live physics and loaded procedural space.
## Actor origins, collision shapes and hurtboxes supply the real clearances.
const WORLD_MASK := 1793 # World + full/window/half cover; excludes actors.
## How far a mine pattern's escape corridor must stay open.
const MINE_CORRIDOR := 240.0

static func body_radius(actor: Node2D) -> float:
	var body := actor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	return _shape_radius(body, actor.global_position) if body != null else 25.0

static func player_clearance(player: Node2D) -> float:
	var result := body_radius(player)
	var hurtbox := player.get_node_or_null("Hurtbox")
	if hurtbox != null:
		for child in hurtbox.get_children():
			if child is CollisionShape2D and not child.disabled:
				result = maxf(result, _shape_radius(child, player.global_position))
	return result

static func _shape_radius(collider: CollisionShape2D, origin: Vector2) -> float:
	if collider == null or collider.shape == null:
		return 0.0
	var bounds := collider.shape.get_rect()
	var radius := 0.0
	for corner in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
		radius = maxf(radius, collider.to_global(corner).distance_to(origin))
	# The circle's bounding-box corners are outside the actual circle.
	if collider.shape is CircleShape2D:
		return collider.global_position.distance_to(origin) + collider.shape.radius * maxf(absf(collider.global_scale.x), absf(collider.global_scale.y))
	return radius

static func _within_leash(actor: Node2D, point: Vector2, radius: float) -> bool:
	if not actor.has_meta(&"boss_home_pos"):
		return true
	return point.distance_to(actor.get_meta(&"boss_home_pos")) + radius <= float(actor.get_meta(&"boss_leash_radius", 750.0))

static func _loaded_space(actor: Node2D, point: Vector2, radius: float) -> bool:
	var manager := actor.get_tree().get_first_node_in_group(&"chunk_manager")
	if manager == null:
		return true # Isolated physics fixtures have no procedural world.
	for i in range(9):
		var sample := point if i == 0 else point + Vector2.RIGHT.rotated(TAU * float(i - 1) / 8.0) * radius
		if not manager.is_cell_walkable(manager.world_to_cell(sample)):
			return false
	return true

static func disc_clear(actor: Node2D, point: Vector2, radius: float) -> bool:
	if not _within_leash(actor, point, radius) or not _loaded_space(actor, point, radius):
		return false
	var shape := CircleShape2D.new()
	shape.radius = maxf(radius, 1.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = WORLD_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = 1.0
	return actor.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

static func corridor_clear(actor: Node2D, start: Vector2, end: Vector2, radius: float) -> bool:
	var steps := maxi(1, ceili(start.distance_to(end) / 32.0))
	for i in range(steps + 1):
		if not _loaded_space(actor, start.lerp(end, float(i) / float(steps)), radius):
			return false
	var shape := CircleShape2D.new()
	shape.radius = maxf(1.0, radius)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, start)
	query.motion = end - start
	query.collision_mask = WORLD_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.margin = 1.0
	var space := actor.get_world_2d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	var motion := space.cast_motion(query)
	if motion.size() < 2 or motion[0] < 0.9999:
		return false
	query.transform.origin = end
	query.motion = Vector2.ZERO
	return space.intersect_shape(query, 1).is_empty()

static func blink_valid(actor: CharacterBody2D, player: Node2D, point: Vector2, mines: Array) -> bool:
	var radius := body_radius(actor)
	var clearance := player_clearance(player)
	if point.distance_to(player.global_position) < radius + clearance + 24.0:
		return false
	if not _within_leash(actor, point, radius) or not _loaded_space(actor, point, radius):
		return false
	var body := actor.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body == null or body.shape == null:
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body.shape
	query.transform = body.global_transform
	query.transform.origin += point - actor.global_position
	query.collision_mask = actor.collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [actor.get_rid()]
	query.margin = 2.0
	if not actor.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	if not corridor_clear(actor, player.global_position, point, clearance + 8.0):
		return false
	for mine in mines:
		if Geometry2D.get_closest_point_to_segment(mine.global_position, player.global_position, point).distance_to(mine.global_position) <= mine.radius + maxf(radius, clearance) + 8.0:
			return false
	return true

## Choosing a mine pattern, its corridor must not lead into the boss's own
## body: it may start beside it, never close on it. Checked when the pattern
## is chosen; the boss may move during the tell like any body.
static func corridor_avoids_body(actor: Node2D, player: Node2D, center: Vector2, escape: Vector2) -> bool:
	var to_boss := actor.global_position - center
	var boss := actor.global_position
	# Away from the body or alongside it (a sideways corridor's dot may come
	# out a hair either side of zero from the rotation that built it).
	if escape.dot(to_boss) <= 0.001 * to_boss.length():
		return true
	var nearest := Geometry2D.get_closest_point_to_segment(boss, center, center + escape * MINE_CORRIDOR)
	return nearest.distance_to(boss) > body_radius(actor) + player_clearance(player) + 8.0

static func mine_pattern_valid(actor: Node2D, player: Node2D, center: Vector2, points: PackedVector2Array, escape: Vector2, radius: float, mines: Array) -> bool:
	var clearance := player_clearance(player) + 8.0
	var end := center + escape * MINE_CORRIDOR
	if not corridor_clear(actor, center, end, clearance):
		return false
	for point in points:
		if not disc_clear(actor, point, radius):
			return false
		if Geometry2D.get_closest_point_to_segment(point, center, end).distance_to(point) <= radius + clearance:
			return false
	for mine in mines:
		if Geometry2D.get_closest_point_to_segment(mine.global_position, center, end).distance_to(mine.global_position) <= mine.radius + clearance:
			return false
	return true
