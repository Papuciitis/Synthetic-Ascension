extends RefCounted
## Walk-out check for a committed boss pattern (boss overhaul proposal,
## acceptance check 3: every composed pattern keeps a reachable route at
## ordinary movement speed). A pattern is a list of timed hazards. The check
## asks whether a player who reacts after REACTION seconds and then walks in a
## straight line at BASE_SPEED avoids all of them. Main-boss controllers only
## commit a pattern that passes from where the player stands.
##
## The player is its real collision geometry: the axis-aligned Hurtbox square
## for area hazards and the upright body capsule for physical rush contact.
## Linear motion is solved exactly in the player's frame; sectors and beams
## are sampled with their polygon and a margin covering the motion between
## samples, so a "safe" verdict is never optimistic.

## player_base_stats.tres move_speed: the baseline human melee walk.
const BASE_SPEED := 100.0
const REACTION := 0.15
const DIRECTIONS := 16
## Sampling step for the hazards that are not solved exactly.
const SAMPLE := 1.0 / 60.0
## Production player shapes (player.tscn): Hurtbox 70 x 70, body capsule
## radius 25 / height 58 (a 4 px straight half-segment).
const DEFAULT_HURTBOX_HALF := Vector2(35.0, 35.0)
const DEFAULT_BODY_RADIUS := 25.0
const DEFAULT_BODY_HALF_SEGMENT := 4.0

## Hazards (times are seconds after commitment):
##   {kind: &"circle", center, radius, from, to}
##   {kind: &"sector", center, facing, radius, half_angle, from, to}
##   {kind: &"sweep",  a, b, radius, from, to}      a body moving a -> b
##   {kind: &"bolt",   origin, velocity, radius, from, to}
##   {kind: &"beam",   origin, angle_from, angle_to, length, width, from, to}
## `body: true` tests the body capsule (physical contact) instead of the
## Hurtbox square.


## The player's real shapes, read from a player node (Hurtbox child and the
## CollisionShape2D capsule); production defaults when a shape is absent.
static func player_shape(player: Node) -> Dictionary:
	var shape := {"hurtbox_half": DEFAULT_HURTBOX_HALF, "body_radius": DEFAULT_BODY_RADIUS, "body_half_segment": DEFAULT_BODY_HALF_SEGMENT}
	if player == null:
		return shape
	var hurtbox := player.get_node_or_null("Hurtbox")
	if hurtbox != null:
		for child in hurtbox.get_children():
			if child is CollisionShape2D and not child.disabled and child.shape is RectangleShape2D:
				shape["hurtbox_half"] = (child.shape as RectangleShape2D).size * 0.5 * (child as CollisionShape2D).global_scale.abs()
				break
	var body := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body != null and body.shape is CapsuleShape2D:
		var capsule := body.shape as CapsuleShape2D
		shape["body_radius"] = capsule.radius
		shape["body_half_segment"] = maxf(0.0, capsule.height * 0.5 - capsule.radius)
	return shape


## The first straight walk (Vector2.ZERO: standing still) that avoids every
## hazard, or null. `blockers` are planted bodies the player cannot cross:
## {center, radius}. `path_clear` (optional) validates a walk against the
## world: (from: Vector2, to: Vector2) -> bool.
static func escape_route(start: Vector2, plan: Array, shape: Dictionary = {}, blockers: Array = [], path_clear: Callable = Callable(), speed: float = BASE_SPEED) -> Variant:
	var hurtbox_half: Vector2 = shape.get("hurtbox_half", DEFAULT_HURTBOX_HALF)
	var body_radius := float(shape.get("body_radius", DEFAULT_BODY_RADIUS))
	var body_half_segment := float(shape.get("body_half_segment", DEFAULT_BODY_HALF_SEGMENT))
	var horizon := 0.0
	for hazard: Dictionary in plan:
		horizon = maxf(horizon, float(hazard["to"]))
	var candidates: Array[Vector2] = [Vector2.ZERO]
	for index in range(DIRECTIONS):
		candidates.append(Vector2.RIGHT.rotated(TAU * float(index) / float(DIRECTIONS)))
	for direction in candidates:
		var velocity := direction * speed
		if not _walk_allowed(start, velocity, horizon, blockers, body_radius):
			continue
		var safe := true
		for hazard: Dictionary in plan:
			if _hits(start, velocity, hazard, hurtbox_half, body_radius, body_half_segment):
				safe = false
				break
		# World queries are the expensive part: only for walks that already
		# avoid every hazard.
		if safe and (velocity.is_zero_approx() or not path_clear.is_valid() or bool(path_clear.call(start, position_at(start, velocity, horizon)))):
			return direction
	return null


static func has_escape(start: Vector2, plan: Array, shape: Dictionary = {}, blockers: Array = [], path_clear: Callable = Callable(), speed: float = BASE_SPEED) -> bool:
	return escape_route(start, plan, shape, blockers, path_clear, speed) != null


## Where the walk stands `t` seconds after commitment.
static func position_at(start: Vector2, velocity: Vector2, t: float) -> Vector2:
	return start + velocity * maxf(0.0, t - REACTION)


static func _walk_allowed(start: Vector2, velocity: Vector2, horizon: float, blockers: Array, body_radius: float) -> bool:
	if velocity.is_zero_approx():
		return true
	var end := position_at(start, velocity, horizon)
	for blocker: Dictionary in blockers:
		var center: Vector2 = blocker["center"]
		var reach := float(blocker["radius"]) + body_radius
		# A player already in contact may step away or along the body, never
		# into it; anyone else may not pass through it.
		if start.distance_to(center) < reach - 0.5:
			if velocity.dot(center - start) > 0.0:
				return false
			continue
		if _segment_point_distance(start, end, center) < reach - 0.5:
			return false
	return true


static func _hits(start: Vector2, velocity: Vector2, hazard: Dictionary, hurtbox_half: Vector2, body_radius: float, body_half_segment: float) -> bool:
	var from := float(hazard["from"])
	var to := float(hazard["to"])
	if to < from:
		return false
	var body := bool(hazard.get("body", false))
	match StringName(hazard["kind"]):
		&"circle":
			return _linear_contact(start, velocity, from, to, hazard["center"], Vector2.ZERO, float(hazard["radius"]), body, hurtbox_half, body_radius, body_half_segment)
		&"sweep":
			var a: Vector2 = hazard["a"]
			var b: Vector2 = hazard["b"]
			return _linear_contact(start, velocity, from, to, a, (b - a) / maxf(to - from, 0.0001), float(hazard["radius"]), body, hurtbox_half, body_radius, body_half_segment)
		&"bolt":
			return _linear_contact(start, velocity, from, to, hazard["origin"], hazard["velocity"], float(hazard["radius"]), body, hurtbox_half, body_radius, body_half_segment)
		&"sector":
			var polygon := sector_polygon(hazard["center"], float(hazard["facing"]), float(hazard["radius"]), float(hazard["half_angle"]))
			var pad := velocity.length() * SAMPLE * 0.5
			return _sampled_overlap(start, velocity, from, to, func(_t: float) -> PackedVector2Array: return polygon, hurtbox_half + Vector2(pad, pad))
		&"beam":
			var origin: Vector2 = hazard["origin"]
			var length := float(hazard["length"])
			var width := float(hazard["width"])
			var angle_from := float(hazard["angle_from"])
			var angle_to := float(hazard["angle_to"])
			var duration := maxf(to - from, 0.0001)
			# Both the beam's tip and the walk move between samples.
			var pad := (absf(angle_to - angle_from) / duration * length + velocity.length()) * SAMPLE * 0.5
			var shape := func(t: float) -> PackedVector2Array:
				return beam_polygon(origin, lerpf(angle_from, angle_to, clampf((t - from) / duration, 0.0, 1.0)), length, width)
			return _sampled_overlap(start, velocity, from, to, shape, hurtbox_half + Vector2(pad, pad))
	return false


## The same filled sector a sector hazard's damage polygon uses.
static func sector_polygon(center: Vector2, facing: float, radius: float, half_angle: float, arc_points: int = 12) -> PackedVector2Array:
	var points := PackedVector2Array([center])
	for index in range(arc_points + 1):
		var angle := facing - half_angle + 2.0 * half_angle * float(index) / float(arc_points)
		points.append(center + Vector2.from_angle(angle) * radius)
	return points


static func beam_polygon(origin: Vector2, angle: float, length: float, width: float) -> PackedVector2Array:
	var along := Vector2.from_angle(angle)
	var across := along.orthogonal() * width * 0.5
	return PackedVector2Array([origin + across, origin + along * length + across, origin + along * length - across, origin - across])


## A hazard point moving from `origin` (at `from`) with constant velocity,
## reaching `radius` around it, against the moving player: exact. In the
## player's frame the hazard traces a segment per motion piece (standing
## before REACTION, walking after), and the player is a fixed shape.
static func _linear_contact(start: Vector2, velocity: Vector2, from: float, to: float, origin: Vector2, mover_velocity: Vector2, radius: float, body: bool, hurtbox_half: Vector2, body_radius: float, body_half_segment: float) -> bool:
	var pieces: Array[Vector2] = []
	if from < REACTION:
		pieces.append(Vector2(from, minf(to, REACTION)))
	if to > REACTION:
		pieces.append(Vector2(maxf(from, REACTION), to))
	for piece in pieces:
		var a := (origin + mover_velocity * (piece.x - from)) - position_at(start, velocity, piece.x)
		var b := (origin + mover_velocity * (piece.y - from)) - position_at(start, velocity, piece.y)
		if body:
			# Upright capsule: a vertical half-segment swept by its radius.
			var top := Vector2(0.0, -body_half_segment)
			var bottom := Vector2(0.0, body_half_segment)
			if _segment_segment_distance(a, b, top, bottom) <= radius + body_radius:
				return true
		elif _segment_box_distance(a, b, hurtbox_half) <= radius:
			return true
	return false


static func _sampled_overlap(start: Vector2, velocity: Vector2, from: float, to: float, polygon_at: Callable, half: Vector2) -> bool:
	var t := from
	while true:
		var center := position_at(start, velocity, t)
		var box := PackedVector2Array([center + Vector2(-half.x, -half.y), center + Vector2(half.x, -half.y), center + Vector2(half.x, half.y), center + Vector2(-half.x, half.y)])
		if not Geometry2D.intersect_polygons(polygon_at.call(t) as PackedVector2Array, box).is_empty():
			return true
		if t >= to:
			break
		t = minf(t + SAMPLE, to)
	return false


static func _segment_point_distance(a: Vector2, b: Vector2, point: Vector2) -> float:
	return Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point)


static func _segment_segment_distance(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	var closest := Geometry2D.get_closest_points_between_segments(a, b, c, d)
	return closest[0].distance_to(closest[1])


## Distance from a segment to the origin-centred box with these half extents.
static func _segment_box_distance(a: Vector2, b: Vector2, half: Vector2) -> float:
	if _point_in_box(a, half) or _point_in_box(b, half):
		return 0.0
	var corners := [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]
	var best := INF
	for index in range(4):
		var c: Vector2 = corners[index]
		var d: Vector2 = corners[(index + 1) % 4]
		if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
			return 0.0
		best = minf(best, _segment_segment_distance(a, b, c, d))
	return best


static func _point_in_box(point: Vector2, half: Vector2) -> bool:
	return absf(point.x) <= half.x and absf(point.y) <= half.y
