extends RefCounted
class_name BossArenaSpace

## Boss courts share one spatial contract with generation and event placement.
## The clear court includes room around the current attacks; ordinary district
## streets remain open for entry, retreat and returning to the fight.
const MINIBOSS_SIDE_CELLS := 20
const BOSS_SIDE_CELLS := 28

static func is_boss_role(role: StringName) -> bool:
	return role == &"miniboss_arena" or role == &"boss_arena"

static func clear_rect(role: StringName, cells_per_chunk: int) -> Rect2i:
	if not is_boss_role(role) or cells_per_chunk <= 4:
		return Rect2i()
	var wanted := MINIBOSS_SIDE_CELLS if role == &"miniboss_arena" else BOSS_SIDE_CELLS
	var side := mini(wanted, cells_per_chunk - 4)
	var origin := floori(float(cells_per_chunk - side) * 0.5)
	return Rect2i(origin, origin, side, side)

static func anchor_world(world_position: Vector2, chunk_size_px: int) -> Vector2:
	if chunk_size_px <= 0:
		return world_position
	var chunk := Vector2(floorf(world_position.x / float(chunk_size_px)), floorf(world_position.y / float(chunk_size_px)))
	return (chunk + Vector2(0.5, 0.5)) * float(chunk_size_px)
