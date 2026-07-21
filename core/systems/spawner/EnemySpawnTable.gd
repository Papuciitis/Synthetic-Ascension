@tool
extends Resource
class_name EnemySpawnTable

@export var entries: Array[EnemySpawnEntry] = []
@export var max_alive_total: int = 180

func pick(t: float, rng: RandomNumberGenerator) -> EnemySpawnEntry:
	var active: Array[EnemySpawnEntry] = []
	var total: float = 0.0

	for e in entries:
		if e != null and e.is_active(t):
			active.append(e)
			total += e.weight

	if active.is_empty() or total <= 0.0:
		return null

	var roll: float = rng.randf() * total
	var acc: float = 0.0
	for e in active:
		acc += e.weight
		if roll <= acc:
			return e

	return active[active.size() - 1]

func get_max_alive_total() -> int:
	return max_alive_total
