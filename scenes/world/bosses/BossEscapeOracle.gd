extends RefCounted
## Walk-out check for a committed boss pattern (boss overhaul proposal,
## acceptance check 3: every composed pattern keeps a reachable route at
## ordinary movement speed). A pattern is a list of timed hazards. The check
## asks whether a player who keeps their current motion for REACTION seconds
## and then walks in a straight line avoids all of them. Main-boss controllers
## only commit a pattern that passes from where the player stands.
##
## The walk is one any player can make: the eight directions a keyboard gives
## (a pad can take them too), at the speed the player can keep up, capped at
## the BASE_SPEED the tells were tuned for (walking_speed). While a dash or a
## shove carries the player faster than it walks, nothing is certified. The
## player is its real collision geometry, turned the way the player turns:
## facing its current motion (or its last facing) while reacting, then its
## walk. The Hurtbox square answers area hazards; the body capsule, physical
## rush contact. Linear motion is solved exactly in the player's own frame;
## sectors and beams are sampled with their polygon and a margin covering the
## motion between samples, so a "safe" verdict is never optimistic.

## player_base_stats.tres move_speed: the baseline human melee walk.
const BASE_SPEED := 100.0
const REACTION := 0.15
const DIRECTIONS := 8
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


## The player's real shapes, facing and motion, read from a player node
## (Hurtbox child, CollisionShape2D capsule, rotation, velocity); production
## defaults for whatever is absent.
static func player_shape(player: Node) -> Dictionary:
	var shape := {"hurtbox_half": DEFAULT_HURTBOX_HALF, "body_radius": DEFAULT_BODY_RADIUS, "body_half_segment": DEFAULT_BODY_HALF_SEGMENT, "rotation": 0.0, "velocity": Vector2.ZERO}
	if player == null:
		return shape
	if player is Node2D:
		shape["rotation"] = (player as Node2D).global_rotation
	if player is CharacterBody2D:
		shape["velocity"] = (player as CharacterBody2D).velocity
	# How fast the player is walking now, boosts included: motion beyond it is
	# a dash or a shove, not a walk it keeps up.
	if player.has_method("get_effective_move_speed"):
		shape["move_speed"] = float(player.call("get_effective_move_speed"))
	if "speed" in player:
		shape["move_speed"] = maxf(float(shape.get("move_speed", 0.0)), float(player.get("speed")))
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


## The walk the check grants this player: the lower of its stat speed (race,
## style, flat equipment) and its effective speed (equipment and build
## multipliers, such as a cursed ring or a weapon's burst), never above
## BASE_SPEED. A boost that may end mid-pattern does not count; a slow does,
## so the boss waits rather than certify a walk the player cannot make.
static func walking_speed(player: Node) -> float:
	if player == null or not "speed" in player:
		return BASE_SPEED
	var sustained := float(player.get("speed"))
	if player.has_method("get_effective_move_speed"):
		sustained = minf(sustained, float(player.call("get_effective_move_speed")))
	return clampf(sustained, 1.0, BASE_SPEED)


## How far the player's body reaches across its route: the capsule lies
## crosswise to the walk, so a planted body must clear its half length.
static func walking_clearance(shape: Dictionary) -> float:
	return float(shape.get("body_radius", DEFAULT_BODY_RADIUS)) + float(shape.get("body_half_segment", DEFAULT_BODY_HALF_SEGMENT))


## The radius a walk's world corridor is checked with: the capsule's radius
## less 2 px, so a player already touching a wall (it rests about 25 px from
## it) can still walk along it or away; walk_clear's sweep adds its 1 px
## margin.
static func corridor_radius(shape: Dictionary) -> float:
	return maxf(1.0, float(shape.get("body_radius", DEFAULT_BODY_RADIUS)) - 2.0)


## The first straight walk (Vector2.ZERO: standing still) that avoids every
## hazard, or null. `blockers` are planted bodies the player cannot cross:
## {center, radius}. `path_clear` (optional) validates a walk against the
## world: (from: Vector2, to: Vector2) -> bool.
static func escape_route(start: Vector2, plan: Array, shape: Dictionary = {}, blockers: Array = [], path_clear: Callable = Callable(), speed: float = BASE_SPEED) -> Variant:
	var hurtbox_half: Vector2 = shape.get("hurtbox_half", DEFAULT_HURTBOX_HALF)
	var body_radius := float(shape.get("body_radius", DEFAULT_BODY_RADIUS))
	var body_half_segment := float(shape.get("body_half_segment", DEFAULT_BODY_HALF_SEGMENT))
	var facing := float(shape.get("rotation", 0.0))
	var drift: Vector2 = shape.get("velocity", Vector2.ZERO)
	# A dash or a shove is not a walk the player keeps up through the
	# reaction, and where it ends is not known here: nothing is certified
	# until it is over (the controller tries again shortly).
	if drift.length() > maxf(float(shape.get("move_speed", speed)), speed) * 1.25:
		return null
	# A body the player already touches stops the part of its motion that
	# pushes into it: the player slides along it.
	for blocker: Dictionary in blockers:
		var outward: Vector2 = start - (blocker["center"] as Vector2)
		if outward.length() < float(blocker["radius"]) + body_radius + body_half_segment - 0.5 and not outward.is_zero_approx():
			var normal := outward.normalized()
			if drift.dot(normal) < 0.0:
				drift -= normal * drift.dot(normal)
	var horizon := 0.0
	for hazard: Dictionary in plan:
		horizon = maxf(horizon, float(hazard["to"]))
	var candidates: Array[Vector2] = [Vector2.ZERO]
	for index in range(DIRECTIONS):
		candidates.append(Vector2.RIGHT.rotated(TAU * float(index) / float(DIRECTIONS)))
	for direction in candidates:
		var walk := direction * speed
		var reacting_facing := drift.angle() if not drift.is_zero_approx() else facing
		var motion := {"start": start, "drift": drift, "walk": walk, "reacting_facing": reacting_facing, "walking_facing": direction.angle() if not direction.is_zero_approx() else reacting_facing}
		if not _walk_allowed(motion, horizon, blockers, body_radius + body_half_segment):
			continue
		var safe := true
		for hazard: Dictionary in plan:
			if _hits(motion, hazard, hurtbox_half, body_radius, body_half_segment):
				safe = false
				break
		# World queries are the expensive part: only for walks that already
		# avoid every hazard.
		if safe and _route_clear(motion, horizon, path_clear):
			return direction
	return null


## The world corridors of the route as it bends: the reaction's drift, then
## the walk. A route that stays where it stands needs none.
static func _route_clear(motion: Dictionary, horizon: float, path_clear: Callable) -> bool:
	if not path_clear.is_valid():
		return true
	var start: Vector2 = motion["start"]
	var turn := position_at(motion, REACTION)
	if not turn.is_equal_approx(start) and not bool(path_clear.call(start, turn)):
		return false
	var end := position_at(motion, maxf(horizon, REACTION))
	return end.is_equal_approx(turn) or bool(path_clear.call(turn, end))


static func has_escape(start: Vector2, plan: Array, shape: Dictionary = {}, blockers: Array = [], path_clear: Callable = Callable(), speed: float = BASE_SPEED) -> bool:
	return escape_route(start, plan, shape, blockers, path_clear, speed) != null


## Where the walk stands `t` seconds after commitment: carried by its current
## motion until REACTION, then walking.
static func position_at(motion: Dictionary, t: float) -> Vector2:
	var start: Vector2 = motion["start"]
	var drift: Vector2 = motion["drift"]
	if t <= REACTION:
		return start + drift * maxf(t, 0.0)
	var walk: Vector2 = motion["walk"]
	return start + drift * REACTION + walk * (t - REACTION)


static func _facing_at(motion: Dictionary, t: float) -> float:
	return float(motion["reacting_facing"] if t < REACTION else motion["walking_facing"])


static func _walk_allowed(motion: Dictionary, horizon: float, blockers: Array, clearance: float) -> bool:
	var start: Vector2 = motion["start"]
	var walk: Vector2 = motion["walk"]
	var turn := position_at(motion, REACTION)
	var end := position_at(motion, maxf(horizon, REACTION))
	for blocker: Dictionary in blockers:
		var center: Vector2 = blocker["center"]
		var reach := float(blocker["radius"]) + clearance
		# A player already in contact may step away or along the body, never
		# into it; anyone else may not pass through it.
		if start.distance_to(center) < reach - 0.5:
			if walk.dot(center - start) > 0.0:
				return false
			continue
		if _segment_point_distance(start, turn, center) < reach - 0.5 or _segment_point_distance(turn, end, center) < reach - 0.5:
			return false
	return true


static func _hits(motion: Dictionary, hazard: Dictionary, hurtbox_half: Vector2, body_radius: float, body_half_segment: float) -> bool:
	var from := float(hazard["from"])
	var to := float(hazard["to"])
	if to < from:
		return false
	var body := bool(hazard.get("body", false))
	match StringName(hazard["kind"]):
		&"circle":
			return _linear_contact(motion, from, to, hazard["center"], Vector2.ZERO, float(hazard["radius"]), body, hurtbox_half, body_radius, body_half_segment)
		&"sweep":
			var a: Vector2 = hazard["a"]
			var b: Vector2 = hazard["b"]
			return _linear_contact(motion, from, to, a, (b - a) / maxf(to - from, 0.0001), float(hazard["radius"]), body, hurtbox_half, body_radius, body_half_segment)
		&"bolt":
			return _linear_contact(motion, from, to, hazard["origin"], hazard["velocity"], float(hazard["radius"]), body, hurtbox_half, body_radius, body_half_segment)
		&"sector":
			var polygon := sector_polygon(hazard["center"], float(hazard["facing"]), float(hazard["radius"]), float(hazard["half_angle"]))
			var pad := _fastest(motion) * SAMPLE * 0.5
			return _sampled_overlap(motion, from, to, func(_t: float) -> PackedVector2Array: return polygon, hurtbox_half + Vector2(pad, pad))
		&"beam":
			var origin: Vector2 = hazard["origin"]
			var length := float(hazard["length"])
			var width := float(hazard["width"])
			var angle_from := float(hazard["angle_from"])
			var angle_to := float(hazard["angle_to"])
			var duration := maxf(to - from, 0.0001)
			# Both the beam's tip and the walk move between samples.
			var pad := (absf(angle_to - angle_from) / duration * length + _fastest(motion)) * SAMPLE * 0.5
			var shape := func(t: float) -> PackedVector2Array:
				return beam_polygon(origin, lerpf(angle_from, angle_to, clampf((t - from) / duration, 0.0, 1.0)), length, width)
			return _sampled_overlap(motion, from, to, shape, hurtbox_half + Vector2(pad, pad))
	return false


static func _fastest(motion: Dictionary) -> float:
	return maxf((motion["walk"] as Vector2).length(), (motion["drift"] as Vector2).length())


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
## player's own turned frame the hazard traces a segment per motion piece
## (reacting, then walking), and the player is a fixed shape.
static func _linear_contact(motion: Dictionary, from: float, to: float, origin: Vector2, mover_velocity: Vector2, radius: float, body: bool, hurtbox_half: Vector2, body_radius: float, body_half_segment: float) -> bool:
	var pieces: Array[Vector2] = []
	if from < REACTION:
		pieces.append(Vector2(from, minf(to, REACTION)))
	if to > REACTION:
		pieces.append(Vector2(maxf(from, REACTION), to))
	for piece in pieces:
		var turn := -_facing_at(motion, piece.x)
		var a := ((origin + mover_velocity * (piece.x - from)) - position_at(motion, piece.x)).rotated(turn)
		var b := ((origin + mover_velocity * (piece.y - from)) - position_at(motion, piece.y)).rotated(turn)
		if body:
			# The capsule's half-segment runs along the player's local y.
			var top := Vector2(0.0, -body_half_segment)
			var bottom := Vector2(0.0, body_half_segment)
			if _segment_segment_distance(a, b, top, bottom) <= radius + body_radius:
				return true
		elif _segment_box_distance(a, b, hurtbox_half) <= radius:
			return true
	return false


static func _sampled_overlap(motion: Dictionary, from: float, to: float, polygon_at: Callable, half: Vector2) -> bool:
	var t := from
	while true:
		var center := position_at(motion, t)
		var facing := _facing_at(motion, t)
		var box := PackedVector2Array()
		for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
			box.append(center + (corner as Vector2).rotated(facing))
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
