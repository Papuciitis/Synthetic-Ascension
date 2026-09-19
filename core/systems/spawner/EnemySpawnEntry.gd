@tool
extends Resource
class_name EnemySpawnEntry

@export var enemy_scene: PackedScene
@export var weight: float = 1.0

@export var start_time: float = 0.0
## Earliest Threat Director phase this entry may spawn in (recon,
## disturbance, ascension, collapse); empty = any. Roster audit E2: unlock
## by where the run is, not by seconds since the spawner started.
@export var min_phase: StringName = &""
@export var end_time: float = -1.0 # -1 = never ends

@export var count_min: int = 1
@export var count_max: int = 1

# Per-type alive cap (0 = no cap)
@export var max_alive: int = 0

# Per-entry elite chance (0..1). Added on top of spawner global bonus.
@export_range(0.0, 1.0, 0.001) var elite_chance: float = 0.0

func is_active(t: float) -> bool:
	if enemy_scene == null:
		return false
	if weight <= 0.0:
		return false
	if t < start_time:
		return false
	if end_time >= 0.0 and t > end_time:
		return false
	return true
