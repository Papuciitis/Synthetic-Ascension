extends RefCounted
class_name WorldBlockerGeometry

## Authoritative, intentionally simple collision geometry for grid blockers.
## Player/world bodies and the batched projectile simulation use the same
## dimensions instead of treating an occupied 64 px cell as a solid square.

enum Kind { SOLID_CELL, WALL, WINDOW, FENCE, HALF_COVER }

const N: int = 1
const E: int = 2
const S: int = 4
const W: int = 8

const WALL_THICKNESS: float = 24.0
const WALL_HALF_LENGTH: float = 32.0
const FENCE_THICKNESS: float = 14.0
const FENCE_HALF_LENGTH: float = 32.0
const WALL_POST_SIZE: float = 24.0
const FENCE_POST_SIZE: float = 18.0
const HALF_COVER_RADIUS: float = 16.0

static func pack(kind: int, connections_mask: int = 0) -> int:
	return (kind & 0xFF) | ((connections_mask & 0xFF) << 8)

static func kind_of(descriptor: int) -> int:
	return descriptor & 0xFF

static func mask_of(descriptor: int) -> int:
	return (descriptor >> 8) & 0xFF

static func swept_hit_t(descriptor: int, cell_center: Vector2, from_pos: Vector2, to_pos: Vector2, projectile_radius: float, cell_size: float) -> float:
	var kind: int = kind_of(descriptor)
	var mask: int = mask_of(descriptor)
	if kind == Kind.WINDOW:
		return -1.0
	if kind == Kind.SOLID_CELL:
		return _segment_rect_t(from_pos, to_pos, cell_center, Vector2(cell_size, cell_size), projectile_radius)
	if kind == Kind.HALF_COVER:
		return _segment_circle_t(from_pos, to_pos, cell_center, HALF_COVER_RADIUS + projectile_radius)
	if kind == Kind.FENCE:
		return _fence_hit_t(mask, cell_center, from_pos, to_pos, projectile_radius)
	return _wall_hit_t(mask, cell_center, from_pos, to_pos, projectile_radius)

static func _wall_hit_t(mask: int, center: Vector2, from_pos: Vector2, to_pos: Vector2, radius: float) -> float:
	if mask == 0:
		return _segment_rect_t(from_pos, to_pos, center, Vector2(WALL_POST_SIZE, WALL_POST_SIZE), radius)
	var best: float = 2.0
	if (mask & N) != 0:
		best = minf(best, _positive_t(_segment_rect_t(from_pos, to_pos, center + Vector2(0.0, -16.0), Vector2(WALL_THICKNESS, WALL_HALF_LENGTH), radius)))
	if (mask & E) != 0:
		best = minf(best, _positive_t(_segment_rect_t(from_pos, to_pos, center + Vector2(16.0, 0.0), Vector2(WALL_HALF_LENGTH, WALL_THICKNESS), radius)))
	if (mask & S) != 0:
		best = minf(best, _positive_t(_segment_rect_t(from_pos, to_pos, center + Vector2(0.0, 16.0), Vector2(WALL_THICKNESS, WALL_HALF_LENGTH), radius)))
	if (mask & W) != 0:
		best = minf(best, _positive_t(_segment_rect_t(from_pos, to_pos, center + Vector2(-16.0, 0.0), Vector2(WALL_HALF_LENGTH, WALL_THICKNESS), radius)))
	return best if best <= 1.0 else -1.0

static func _fence_hit_t(mask: int, center: Vector2, from_pos: Vector2, to_pos: Vector2, radius: float) -> float:
	var supported: bool = mask == (N | S) or mask == (E | W) or mask == (N | E) or mask == (N | W) or mask == (S | E) or mask == (S | W)
	if not supported:
		return _segment_rect_t(from_pos, to_pos, center, Vector2(FENCE_POST_SIZE, FENCE_POST_SIZE), radius)
	var best: float = 2.0
	if (mask & N) != 0:
		best = minf(best, _positive_t(_segment_rect_t(from_pos, to_pos, center + Vector2(0.0, -16.0), Vector2(FENCE_THICKNESS, FENCE_HALF_LENGTH), radius)))
	if (mask & E) != 0:
		best = minf(best, _positive_t(_segment_rect_t(from_pos, to_pos, center + Vector2(16.0, 0.0), Vector2(FENCE_HALF_LENGTH, FENCE_THICKNESS), radius)))
	if (mask & S) != 0:
		best = minf(best, _positive_t(_segment_rect_t(from_pos, to_pos, center + Vector2(0.0, 16.0), Vector2(FENCE_THICKNESS, FENCE_HALF_LENGTH), radius)))
	if (mask & W) != 0:
		best = minf(best, _positive_t(_segment_rect_t(from_pos, to_pos, center + Vector2(-16.0, 0.0), Vector2(FENCE_HALF_LENGTH, FENCE_THICKNESS), radius)))
	return best if best <= 1.0 else -1.0

static func _positive_t(value: float) -> float:
	return value if value >= 0.0 else 2.0

static func _segment_circle_t(from_pos: Vector2, to_pos: Vector2, center: Vector2, radius: float) -> float:
	var segment: Vector2 = to_pos - from_pos
	var a: float = segment.length_squared()
	var offset: Vector2 = from_pos - center
	var c: float = offset.length_squared() - radius * radius
	if c <= 0.0:
		return 0.0
	if a <= 0.000001:
		return -1.0
	var b: float = 2.0 * offset.dot(segment)
	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var hit_t: float = (-b - sqrt(discriminant)) / (2.0 * a)
	return hit_t if hit_t >= 0.0 and hit_t <= 1.0 else -1.0

static func _segment_rect_t(from_pos: Vector2, to_pos: Vector2, center: Vector2, size: Vector2, radius: float) -> float:
	var half: Vector2 = size * 0.5 + Vector2(radius, radius)
	var local_from: Vector2 = from_pos - center
	var delta: Vector2 = to_pos - from_pos
	var enter: float = 0.0
	var leave: float = 1.0
	if not _clip_axis(local_from.x, delta.x, -half.x, half.x, enter, leave):
		return -1.0
	var x_values: Vector2 = _axis_interval(local_from.x, delta.x, -half.x, half.x)
	if x_values.x > x_values.y:
		return -1.0
	enter = maxf(enter, x_values.x)
	leave = minf(leave, x_values.y)
	var y_values: Vector2 = _axis_interval(local_from.y, delta.y, -half.y, half.y)
	if y_values.x > y_values.y:
		return -1.0
	enter = maxf(enter, y_values.x)
	leave = minf(leave, y_values.y)
	return enter if enter <= leave and leave >= 0.0 and enter <= 1.0 else -1.0

static func _clip_axis(origin: float, delta: float, minimum: float, maximum: float, _enter: float, _leave: float) -> bool:
	return not (absf(delta) <= 0.000001 and (origin < minimum or origin > maximum))

static func _axis_interval(origin: float, delta: float, minimum: float, maximum: float) -> Vector2:
	if absf(delta) <= 0.000001:
		return Vector2(0.0, 1.0) if origin >= minimum and origin <= maximum else Vector2(2.0, -1.0)
	var first: float = (minimum - origin) / delta
	var second: float = (maximum - origin) / delta
	return Vector2(minf(first, second), maxf(first, second))
