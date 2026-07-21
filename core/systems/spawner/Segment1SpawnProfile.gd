extends RefCounted
class_name Segment1SpawnProfile

## Single tuning point for the handcrafted tutorial's ambient pressure.
## Segment 1 never unlocks enemies from elapsed scene time. Level1Builder moves
## this profile forward only when the player reaches an authored milestone.

enum Stage {
	BEFORE_SYNTHESIS,
	INITIAL_CONTAINMENT,
	ARCHIVE,
	COURTYARD,
	SERVICE,
	OUTER_APPROACH,
	EXIT_RITE,
}

const GRUNT := preload("res://scenes/world/enemies/EnemyGrunt.tscn")
const RUNNER := preload("res://scenes/world/enemies/EnemyRunner.tscn")
const ORBITER := preload("res://scenes/world/enemies/EnemyOrbiter.tscn")
const SPITTER := preload("res://scenes/world/enemies/EnemySpitter.tscn")
const CHARGER := preload("res://scenes/world/enemies/EnemyCharger.tscn")
const BOMBER := preload("res://scenes/world/enemies/EnemyBomber.tscn")

# interval, alive cap, batch, roster, grace, allow Threat/elite scaling.
const STAGES: Array[Dictionary] = [
	{"interval": 999.0, "cap": 0, "batch": 0, "roster": [], "grace": 0.0, "threat": false},
	{"interval": 4.6, "cap": 4, "batch": 1, "roster": [GRUNT], "grace": 2.0, "threat": false},
	{"interval": 3.8, "cap": 6, "batch": 1, "roster": [GRUNT, RUNNER], "grace": 1.25, "threat": false},
	{"interval": 3.25, "cap": 8, "batch": 1, "roster": [GRUNT, RUNNER, ORBITER], "grace": 1.5, "threat": false},
	{"interval": 2.8, "cap": 11, "batch": 1, "roster": [GRUNT, RUNNER, ORBITER, SPITTER, CHARGER], "grace": 1.5, "threat": false},
	{"interval": 2.15, "cap": 15, "batch": 2, "roster": [GRUNT, RUNNER, ORBITER, SPITTER, CHARGER, BOMBER], "grace": 1.0, "threat": true},
	{"interval": 1.35, "cap": 20, "batch": 2, "roster": [GRUNT, RUNNER, ORBITER, SPITTER, CHARGER, BOMBER], "grace": 0.25, "threat": true},
]

static func settings(stage: int) -> Dictionary:
	return STAGES[clampi(stage, 0, STAGES.size() - 1)]

